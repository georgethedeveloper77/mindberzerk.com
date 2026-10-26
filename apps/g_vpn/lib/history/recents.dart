import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../map/map_data.dart';
import '../servers/community.dart';
import '../vpn/community_server.dart';
import '../vpn/tunnel_store.dart';
import '../vpn/vpn_controller.dart';

enum RecentKind { free, own, gserver }

/// A server the user connected to, as Home's Recent row shows it.
class RecentServer {
  const RecentServer({
    required this.id,
    required this.kind,
    required this.name,
    required this.at,
    this.country,
    this.server,
  });

  /// The [ServerChoice.id] it was connected with.
  final String id;
  final RecentKind kind;
  final String name;

  /// ISO alpha-2 when known.
  final String? country;

  /// Free servers only: the listing as it was, so the row can show it
  /// without the network.
  final CommunityServer? server;

  final DateTime at;

  /// A snapshot of [choice], or null for a kind we do not keep.
  static RecentServer from(ServerChoice choice, DateTime at) => switch (choice) {
        CommunityChoice(:final server) => RecentServer(
            id: choice.id,
            kind: RecentKind.free,
            name: choice.name,
            country: server.countryCode.toUpperCase(),
            server: server,
            at: at,
          ),
        OwnServer(:final tunnel) => RecentServer(
            id: choice.id,
            kind: tunnel.id.startsWith(gserverPrefix) ? RecentKind.gserver : RecentKind.own,
            name: choice.name,
            at: at,
          ),
      };

  Map<String, Object> toJson() => {
        'id': id,
        'kind': kind.name,
        'name': name,
        'at': at.millisecondsSinceEpoch,
        if (country != null) 'country': country!,
        if (server != null) 'server': server!.toJson(),
      };

  static RecentServer? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'], name = json['name'], at = json['at'];
    final kind = RecentKind.values.where((k) => k.name == json['kind']).firstOrNull;
    if (id is! String || name is! String || at is! int || kind == null) return null;
    return RecentServer(
      id: id,
      kind: kind,
      name: name,
      at: DateTime.fromMillisecondsSinceEpoch(at),
      country: json['country'] is String ? json['country'] as String : null,
      server: CommunityServer.fromJson(json['server']),
    );
  }
}

final recentsProvider = AsyncNotifierProvider<RecentsController, List<RecentServer>>(RecentsController.new);

/// The last few servers used, newest first, kept on this phone.
class RecentsController extends AsyncNotifier<List<RecentServer>> {
  static const _key = 'gvpn.recents.v1';
  static const _keep = 12;

  @override
  Future<List<RecentServer>> build() async {
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    if (raw == null) return const [];
    try {
      return (jsonDecode(raw) as List).map(RecentServer.fromJson).whereType<RecentServer>().toList();
    } on FormatException {
      return const [];
    }
  }

  /// Free servers come and go by the hour, so they are remembered by
  /// country: Japan once, however many Japanese servers were used.
  static String _place(RecentServer r) => r.kind == RecentKind.free && r.country != null ? 'free:${r.country}' : r.id;

  /// Puts [choice] first, once.
  Future<void> record(ServerChoice choice) async {
    final entry = RecentServer.from(choice, DateTime.now());
    final current = await future;
    final next = [entry, ...current.where((r) => _place(r) != _place(entry))].take(_keep).toList();
    state = AsyncData(next);
    await (await SharedPreferences.getInstance()).setString(_key, jsonEncode([for (final r in next) r.toJson()]));
  }
}

/// The recents that can still be connected to: free countries that still
/// have a server, the user's servers still saved, and the G Server this
/// phone is registered with.
final usableRecentsProvider = Provider<List<(RecentServer, ServerChoice)>>((ref) {
  final recents = ref.watch(recentsProvider).value ?? const <RecentServer>[];
  final tunnels = ref.watch(tunnelsProvider).value;
  final listed = {for (final s in ref.watch(communityProvider).value?.servers ?? const <CommunityServer>[]) s.id: s};
  return [
    for (final r in recents)
      if (_choiceFor(r, tunnels, listed) case final choice?) (r, choice),
  ];
});

ServerChoice? _choiceFor(RecentServer r, TunnelsState? tunnels, Map<String, CommunityServer> listed) {
  switch (r.kind) {
    case RecentKind.free:
      // The same server if it is still listed, else the best one now in
      // the same country; before the list loads, the one remembered.
      final fresh = listed[r.id.substring(communityPrefix.length)] ??
          listed.values.where((s) => s.countryCode.toUpperCase() == r.country).firstOrNull;
      if (fresh != null) return CommunityChoice(fresh);
      return listed.isEmpty && r.server != null ? CommunityChoice(r.server!) : null;
    case RecentKind.own:
      final tunnel = tunnels?.tunnels.where((t) => t.id == r.id).firstOrNull;
      return tunnel == null ? null : OwnServer(tunnel);
    case RecentKind.gserver:
      final g = tunnels?.gserver;
      return g == null || g.id != r.id ? null : OwnServer(g);
  }
}

/// Connects to a recent server, switching over if another is up. Reads
/// everything before the first await, like the map's connect.
Future<void> connectRecent(WidgetRef ref, ServerChoice choice) async {
  if (choice case CommunityChoice(:final server)) return connectCommunity(ref, server);
  final tunnels = ref.read(tunnelsProvider.notifier);
  final vpn = ref.read(vpnProvider.notifier);
  final current = ref.read(vpnProvider);
  if (current.phase == VpnPhase.on && current.tunnelId == choice.id) return;
  if (choice case OwnServer(:final tunnel)) {
    if (tunnel.id.startsWith(gserverPrefix)) {
      await tunnels.selectGServer(tunnel);
    } else {
      await tunnels.select(tunnel.id);
    }
  }
  if (current.phase == VpnPhase.on) await vpn.disconnect();
  await vpn.connect(choice);
}
