import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../vpn/config_rules.dart';
import '../vpn/tunnel_store.dart';
import '../vpn/vpn_api.g.dart';
import '../vpn/vpn_controller.dart';

enum AutoConnectChoice { off, open, any }

/// How Shield filters lookups while connected. None of them blocks ads:
/// Play's VPN policy forbids it.
enum ShieldLevel {
  off,

  /// Quad9: malware and phishing.
  malware,

  /// Cloudflare for Families: malware and adult sites.
  family,

  /// The user's own resolvers.
  custom,
}

/// What a preset changes for one connection, on top of the Rules.
class RulesOverride {
  const RulesOverride({this.shield, this.allApps = false});

  /// Null keeps the Rules' level.
  final ShieldLevel? shield;

  /// Sends every app through the VPN, ignoring Apps direct.
  final bool allApps;

  RulesState applyTo(RulesState rules) => rules.copyWith(
        shieldLevel: shield ?? rules.shieldLevel,
        excluded: allApps ? const <String>{} : rules.excluded,
      );
}

class RulesState {
  const RulesState({
    this.excluded = const {},
    this.shieldLevel = ShieldLevel.malware,
    this.lastOnLevel = ShieldLevel.malware,
    this.customDns = const [],
    this.autoConnect = AutoConnectChoice.off,
  });

  /// Package names that bypass the tunnel.
  final Set<String> excluded;
  final ShieldLevel shieldLevel;

  /// The level the on/off switch returns to.
  final ShieldLevel lastOnLevel;

  /// Resolvers for [ShieldLevel.custom].
  final List<String> customDns;
  final AutoConnectChoice autoConnect;

  bool get shield => shieldLevel != ShieldLevel.off;

  /// The resolvers this level puts in the tunnel; empty keeps the server's.
  List<String> get dnsServers => switch (shieldLevel) {
        ShieldLevel.off => const [],
        ShieldLevel.malware => shieldResolvers,
        ShieldLevel.family => familyResolvers,
        ShieldLevel.custom => customDns.isEmpty ? shieldResolvers : customDns,
      };

  RulesState copyWith({
    Set<String>? excluded,
    ShieldLevel? shieldLevel,
    ShieldLevel? lastOnLevel,
    List<String>? customDns,
    AutoConnectChoice? autoConnect,
  }) =>
      RulesState(
        excluded: excluded ?? this.excluded,
        shieldLevel: shieldLevel ?? this.shieldLevel,
        lastOnLevel: lastOnLevel ?? this.lastOnLevel,
        customDns: customDns ?? this.customDns,
        autoConnect: autoConnect ?? this.autoConnect,
      );

  /// The exact text handed to the backend, here and in auto-connect.
  String render(SavedTunnel tunnel) => applyRules(
        tunnel.configText,
        excludedApps: excluded,
        dns: dnsServers.isEmpty ? null : dnsServers,
      );

  Map<String, Object> toJson() => {
        'excluded': excluded.toList(),
        'shieldLevel': shieldLevel.name,
        'lastOnLevel': lastOnLevel.name,
        'customDns': customDns,
        'autoConnect': autoConnect.name,
      };

  static ShieldLevel? _level(Object? name) => ShieldLevel.values.where((l) => l.name == name).firstOrNull;

  static RulesState fromJson(Object? json) {
    if (json is! Map) return const RulesState();
    final excluded = json['excluded'];
    final auto = json['autoConnect'];
    final custom = json['customDns'];
    // Before levels, Shield was a plain switch.
    final legacy = json['shield'] is bool ? (json['shield'] as bool ? ShieldLevel.malware : ShieldLevel.off) : null;
    return RulesState(
      excluded: excluded is List ? excluded.whereType<String>().toSet() : const {},
      shieldLevel: _level(json['shieldLevel']) ?? legacy ?? ShieldLevel.malware,
      lastOnLevel: _level(json['lastOnLevel']) ?? ShieldLevel.malware,
      customDns: custom is List ? custom.whereType<String>().toList() : const [],
      autoConnect: AutoConnectChoice.values.firstWhere(
        (c) => c.name == auto,
        orElse: () => AutoConnectChoice.off,
      ),
    );
  }
}

final rulesProvider = AsyncNotifierProvider<RulesController, RulesState>(RulesController.new);

class RulesController extends AsyncNotifier<RulesState> {
  static const _key = 'gvpn.rules.v1';

  @override
  Future<RulesState> build() async {
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    if (raw == null) return const RulesState();
    try {
      return RulesState.fromJson(jsonDecode(raw));
    } on FormatException {
      return const RulesState();
    }
  }

  Future<void> setExcluded(Set<String> excluded) async =>
      _save((await future).copyWith(excluded: excluded), reconnect: true);

  /// The quick switch: off, or back to the last level that was on.
  Future<void> setShield(bool on) async {
    final current = await future;
    await _save(current.copyWith(shieldLevel: on ? current.lastOnLevel : ShieldLevel.off), reconnect: true);
  }

  Future<void> setShieldLevel(ShieldLevel level, {List<String>? customDns}) async {
    final current = await future;
    await _save(
      current.copyWith(
        shieldLevel: level,
        lastOnLevel: level == ShieldLevel.off ? current.lastOnLevel : level,
        customDns: customDns,
      ),
      reconnect: true,
    );
  }

  Future<void> setAutoConnect(AutoConnectChoice choice) async =>
      _save((await future).copyWith(autoConnect: choice), reconnect: false);

  /// App and DNS rules are baked into the tunnel at connect time, so a change
  /// while connected needs a quick reconnect to take effect.
  Future<void> _save(RulesState next, {required bool reconnect}) async {
    await (await SharedPreferences.getInstance()).setString(_key, jsonEncode(next.toJson()));
    state = AsyncData(next);
    if (reconnect && ref.read(vpnProvider).phase == VpnPhase.on) {
      unawaited(ref.read(vpnProvider.notifier).reconnect());
    }
  }
}

/// Keeps the native auto-connect registration in step with the selected
/// server and the rules. Watched once from the home screen.
final autoConnectSyncProvider = Provider<void>((ref) {
  final rules = ref.watch(rulesProvider).value;
  final tunnels = ref.watch(tunnelsProvider).value;
  if (rules == null || tunnels == null) return;

  final tunnel = tunnels.selected;
  if (tunnel == null) {
    unawaited(ref.read(vpnApiProvider).setAutoConnect(null).catchError((Object _) {}));
    return;
  }
  final settings = switch (rules.autoConnect) {
    AutoConnectChoice.off => null,
    AutoConnectChoice.open => AutoConnectSettings(configText: rules.render(tunnel), mode: AutoConnectMode.open),
    AutoConnectChoice.any => AutoConnectSettings(configText: rules.render(tunnel), mode: AutoConnectMode.any),
  };
  unawaited(ref.read(vpnApiProvider).setAutoConnect(settings).catchError((Object _) {}));
});
