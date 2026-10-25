import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../design/countries.dart';
import 'community_server.dart';
import 'wg_config.dart';

/// A WireGuard config the user imported ("Your Server").
class SavedTunnel {
  const SavedTunnel({
    required this.id,
    required this.name,
    required this.configText,
    this.lastUsed,
  });

  final String id;
  final String name;

  /// When the user last chose this server; null until first use.
  final DateTime? lastUsed;

  /// The raw wg-quick text, private key included. Phase 1 keeps it in app
  /// preferences with cloud backup disabled in the manifest; it moves to
  /// Keystore-backed encryption before public release.
  final String configText;

  WgSummary get summary => parseWgConfig(configText);

  Map<String, Object> toJson() => {
        'id': id,
        'name': name,
        'config': configText,
        if (lastUsed != null) 'lastUsed': lastUsed!.millisecondsSinceEpoch,
      };

  SavedTunnel copyWith({String? name, DateTime? lastUsed}) =>
      SavedTunnel(id: id, name: name ?? this.name, configText: configText, lastUsed: lastUsed ?? this.lastUsed);

  static SavedTunnel? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'], name = json['name'], config = json['config'];
    if (id is! String || name is! String || config is! String) return null;
    final used = json['lastUsed'];
    return SavedTunnel(
      id: id,
      name: name,
      configText: config,
      lastUsed: used is int ? DateTime.fromMillisecondsSinceEpoch(used) : null,
    );
  }
}

/// A name for an imported config: its "# Name = ..." line (G Servers write
/// one), else the server's address. Null when neither is readable.
String? suggestServerName(String configText) {
  final named = RegExp(r'^\s*#\s*Name\s*=\s*(.+?)\s*$', multiLine: true).firstMatch(configText)?.group(1);
  if (named != null && named.isNotEmpty) return named;
  try {
    final endpoint = parseWgConfig(configText.trim()).endpoint;
    final host = endpoint.contains(']') ? endpoint.split(']').first.replaceFirst('[', '') : endpoint.split(':').first;
    return host.isEmpty ? null : host;
  } on Object {
    return null;
  }
}

/// What the connect button will connect to: one of the user's own WireGuard
/// servers, or a Community (OpenVPN) server.
sealed class ServerChoice {
  const ServerChoice();

  /// Stable id. Community ids carry a "c:" prefix so the two never collide.
  String get id;
  String get name;

  /// ISO country, for the flag. Null for the user's own servers.
  String? get countryCode => null;
}

final class OwnServer extends ServerChoice {
  const OwnServer(this.tunnel);

  final SavedTunnel tunnel;

  @override
  String get id => tunnel.id;

  @override
  String get name => tunnel.name;
}

final class CommunityChoice extends ServerChoice {
  const CommunityChoice(this.server);

  final CommunityServer server;

  @override
  String get id => '$communityPrefix${server.id}';

  @override
  String get name => countryName(server.countryCode, server.country);

  @override
  String? get countryCode => server.countryCode;
}

const communityPrefix = 'c:';

/// G Server connections: a WireGuard config made for this phone by the
/// G Servers broker, kept apart from the user's own servers.
const gserverPrefix = 'g:';

class TunnelsState {
  const TunnelsState({required this.tunnels, required this.selectedId, this.community, this.gserver});

  final List<SavedTunnel> tunnels;
  final String? selectedId;

  /// The Community server last picked, kept as a snapshot so Home can show
  /// it without the network.
  final CommunityServer? community;

  /// The G Server last connected to (its config was made for this phone).
  final SavedTunnel? gserver;

  bool get _gserverSelected => gserver != null && selectedId == gserver!.id;

  bool get _communitySelected =>
      community != null && selectedId == '$communityPrefix${community!.id}';

  ServerChoice? get choice {
    if (_communitySelected) return CommunityChoice(community!);
    if (_gserverSelected) return OwnServer(gserver!);
    final t = selected;
    return t == null ? null : OwnServer(t);
  }

  /// The selected WireGuard server, or null when a Community server is
  /// selected. Auto-connect runs on WireGuard servers only.
  SavedTunnel? get selected {
    if (_communitySelected) return null;
    if (_gserverSelected) return gserver;
    for (final t in tunnels) {
      if (t.id == selectedId) return t;
    }
    return tunnels.isEmpty ? null : tunnels.first;
  }
}

final tunnelsProvider =
    AsyncNotifierProvider<TunnelsController, TunnelsState>(TunnelsController.new);

class TunnelsController extends AsyncNotifier<TunnelsState> {
  static const _tunnelsKey = 'gvpn.tunnels.v1';
  static const _selectedKey = 'gvpn.selected.v1';
  static const _communityKey = 'gvpn.community.v1';
  static const _gserverKey = 'gvpn.gserver.v1';

  @override
  Future<TunnelsState> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_tunnelsKey);
    final tunnels = <SavedTunnel>[];
    if (raw != null) {
      // A corrupt entry is skipped, not fatal: losing one server beats losing
      // the whole list to a single bad row.
      try {
        for (final item in jsonDecode(raw) as List) {
          final t = SavedTunnel.fromJson(item);
          if (t != null) tunnels.add(t);
        }
      } on FormatException {
        tunnels.clear();
      }
    }
    CommunityServer? community;
    final rawCommunity = prefs.getString(_communityKey);
    if (rawCommunity != null) {
      try {
        community = CommunityServer.fromJson(jsonDecode(rawCommunity));
      } on FormatException {
        community = null;
      }
    }
    SavedTunnel? gserver;
    final rawG = prefs.getString(_gserverKey);
    if (rawG != null) {
      try {
        gserver = SavedTunnel.fromJson(jsonDecode(rawG));
      } on FormatException {
        gserver = null;
      }
    }
    return TunnelsState(
      tunnels: tunnels,
      selectedId: prefs.getString(_selectedKey),
      community: community,
      gserver: gserver,
    );
  }

  /// Validates and saves an import. Returns a person-readable error, or null.
  Future<String?> add({required String name, required String configText}) async {
    final text = configText.trim();
    try {
      parseWgConfig(text);
    } on WgConfigException catch (e) {
      return e.message;
    }
    final current = await future;
    final tunnel = SavedTunnel(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.trim().isEmpty ? 'My server' : name.trim(),
      configText: text,
    );
    await _persist(TunnelsState(
      tunnels: [...current.tunnels, tunnel],
      selectedId: tunnel.id,
      community: current.community,
      gserver: current.gserver,
    ));
    return null;
  }

  Future<void> remove(String id) async {
    final current = await future;
    final remaining = current.tunnels.where((t) => t.id != id).toList();
    await _persist(TunnelsState(
      tunnels: remaining,
      selectedId: current.selectedId == id ? null : current.selectedId,
      community: current.community,
      gserver: current.gserver,
    ));
  }

  /// Selecting is choosing to use it, so it also stamps "last used".
  Future<void> select(String id) async {
    final current = await future;
    final now = DateTime.now();
    await _persist(TunnelsState(
      tunnels: [for (final t in current.tunnels) t.id == id ? t.copyWith(lastUsed: now) : t],
      selectedId: id,
      community: current.community,
      gserver: current.gserver,
    ));
  }

  Future<void> rename(String id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final current = await future;
    await _persist(TunnelsState(
      tunnels: [for (final t in current.tunnels) t.id == id ? t.copyWith(name: trimmed) : t],
      selectedId: current.selectedId,
      community: current.community,
      gserver: current.gserver,
    ));
  }

  Future<void> selectCommunity(CommunityServer server) async {
    final current = await future;
    await _persist(TunnelsState(
      tunnels: current.tunnels,
      selectedId: '$communityPrefix${server.id}',
      community: server,
    ));
  }

  /// Selects a G Server connection made for this phone.
  Future<void> selectGServer(SavedTunnel tunnel) async {
    final current = await future;
    await _persist(TunnelsState(
      tunnels: current.tunnels,
      selectedId: tunnel.id,
      community: current.community,
      gserver: tunnel.copyWith(lastUsed: DateTime.now()),
    ));
  }

  Future<void> _persist(TunnelsState next) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _tunnelsKey,
      jsonEncode(next.tunnels.map((t) => t.toJson()).toList()),
    );
    final community = next.community;
    if (community != null) await prefs.setString(_communityKey, jsonEncode(community.toJson()));
    final gserver = next.gserver;
    if (gserver != null) await prefs.setString(_gserverKey, jsonEncode(gserver.toJson()));
    final selectedId = next.selectedId;
    if (selectedId == null) {
      await prefs.remove(_selectedKey);
    } else {
      await prefs.setString(_selectedKey, selectedId);
    }
    state = AsyncData(next);
  }
}
