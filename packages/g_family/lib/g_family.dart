/// Links the Mindberzerk apps: G VPN's status and controls, for G Launcher's
/// desklet and G Recovery's cards.
///
/// ```dart
/// final status = await GVpn.status();
/// GVpn.watch().listen((s) => setState(() => _vpn = s));
/// if (status.state == GVpnState.off) await GVpn.connect();
/// ```
library;

import 'package:flutter/services.dart';

enum GVpnState {
  /// G VPN is not on this phone: show "Get G VPN".
  notInstalled,

  /// Installed, but this app may not read it: an older Android, an app
  /// installed before G VPN, or a signing key not on G VPN's list. Tapping
  /// should open G VPN.
  unavailable,
  off,
  connecting,
  on,
  reconnecting,
  paused,
}

class GVpnStatus {
  const GVpnStatus(this.state, {this.label, this.pausedUntil});

  final GVpnState state;

  /// The server's name ("Japan", "Home router") while connected or paused.
  final String? label;

  /// When a pause ends.
  final DateTime? pausedUntil;

  bool get protected => state == GVpnState.on || state == GVpnState.reconnecting;

  static GVpnStatus _from(Object? raw) {
    final m = raw is Map ? raw : const {};
    final state = GVpnState.values.firstWhere((s) => s.name == m['state'], orElse: () => GVpnState.unavailable);
    final until = m['pausedUntil'];
    return GVpnStatus(
      state,
      label: m['label'] as String?,
      pausedUntil: until is int && until > 0 ? DateTime.fromMillisecondsSinceEpoch(until) : null,
    );
  }
}

abstract final class GVpn {
  static const _calls = MethodChannel('com.mindberzerk.g_family');
  static const _changes = EventChannel('com.mindberzerk.g_family/changes');

  /// The current status, read once.
  static Future<GVpnStatus> status() async => GVpnStatus._from(await _calls.invokeMethod<Object?>('status'));

  /// The status now, then on every change, for as long as it is listened to.
  static Stream<GVpnStatus> watch() => _changes.receiveBroadcastStream().map(GVpnStatus._from);

  /// Connects to the last server. G VPN opens itself instead when it first
  /// needs Android's VPN permission or a server choice.
  static Future<void> connect() => _calls.invokeMethod<void>('control', 'com.mindberzerk.gvpn.action.CONNECT');

  static Future<void> disconnect() => _calls.invokeMethod<void>('control', 'com.mindberzerk.gvpn.action.DISCONNECT');

  /// Stops the VPN for [minutes], then reconnects to the same server.
  static Future<void> pause(int minutes) =>
      _calls.invokeMethod<void>('pause', minutes);

  /// Opens G VPN, or its Play Store page when it is not installed.
  /// [referrer] tags the install with the app that sent it.
  static Future<void> open({String referrer = 'g_family'}) => _calls.invokeMethod<void>('open', referrer);
}
