import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../vpn/config_rules.dart';
import '../vpn/tunnel_store.dart';
import '../vpn/vpn_api.g.dart';
import '../vpn/vpn_controller.dart';

enum AutoConnectChoice { off, open, any }

class RulesState {
  const RulesState({
    this.excluded = const {},
    this.shield = true,
    this.autoConnect = AutoConnectChoice.off,
  });

  /// Package names that bypass the tunnel.
  final Set<String> excluded;
  final bool shield;
  final AutoConnectChoice autoConnect;

  RulesState copyWith({Set<String>? excluded, bool? shield, AutoConnectChoice? autoConnect}) =>
      RulesState(
        excluded: excluded ?? this.excluded,
        shield: shield ?? this.shield,
        autoConnect: autoConnect ?? this.autoConnect,
      );

  /// The exact text handed to the backend, here and in auto-connect.
  String render(SavedTunnel tunnel) => applyRules(
        tunnel.configText,
        excludedApps: excluded,
        dns: shield ? shieldResolvers : null,
      );

  Map<String, Object> toJson() => {
        'excluded': excluded.toList(),
        'shield': shield,
        'autoConnect': autoConnect.name,
      };

  static RulesState fromJson(Object? json) {
    if (json is! Map) return const RulesState();
    final excluded = json['excluded'];
    final auto = json['autoConnect'];
    return RulesState(
      excluded: excluded is List ? excluded.whereType<String>().toSet() : const {},
      shield: json['shield'] is bool ? json['shield'] as bool : true,
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

  Future<void> setShield(bool on) async => _save((await future).copyWith(shield: on), reconnect: true);

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
