import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analytics/events.dart';
import '../i18n/strings.g.dart';
import '../rules/rules_store.dart';
import '../servers/community.dart';
import 'config_rules.dart';
import 'tunnel_store.dart';
import 'vpn_api.g.dart';

enum VpnPhase { off, connecting, on, disconnecting }

@immutable
class VpnState {
  const VpnState({
    this.phase = VpnPhase.off,
    this.rxBytes = 0,
    this.txBytes = 0,
    this.connectedAt,
    this.tunnelId,
    this.error,
    this.reconnecting = false,
    this.pausedUntil,
  });

  final VpnPhase phase;
  final int rxBytes;
  final int txBytes;
  final DateTime? connectedAt;

  /// Which server is up (a [ServerChoice.id]). Null when off, or when the
  /// tunnel was found already up after a restart and we cannot know which.
  final String? tunnelId;

  /// The last failure, written for a person. Cleared by the next attempt.
  final String? error;

  /// On, but re-establishing after a network change or sleep.
  final bool reconnecting;

  /// Paused from the notification: the tunnel is stopped until this time,
  /// then reconnects to the same server. The session still counts as "on".
  final DateTime? pausedUntil;

  VpnState copyWith({
    VpnPhase? phase,
    int? rxBytes,
    int? txBytes,
    DateTime? connectedAt,
    String? tunnelId,
    String? error,
    bool? reconnecting,
  }) =>
      VpnState(
        phase: phase ?? this.phase,
        rxBytes: rxBytes ?? this.rxBytes,
        txBytes: txBytes ?? this.txBytes,
        connectedAt: connectedAt ?? this.connectedAt,
        tunnelId: tunnelId ?? this.tunnelId,
        error: error ?? this.error,
        reconnecting: reconnecting ?? this.reconnecting,
      );
}

final vpnApiProvider = Provider<VpnHostApi>((ref) => VpnHostApi());

final vpnProvider = NotifierProvider<VpnController, VpnState>(VpnController.new);

/// Owns the tunnel lifecycle and the live byte counters.
///
/// BATTERY: the status poll runs only while the tunnel is up AND the app is in
/// the foreground. Nothing ticks while the app is backgrounded; the counters
/// catch up on the first poll after resume. This is the lesson from the
/// launcher A/B work: a timer that never stops is the cheapest drain to ship.
class VpnController extends Notifier<VpnState> {
  static const _pollEvery = Duration(seconds: 1);

  Timer? _poll;
  AppLifecycleListener? _lifecycle;
  bool _foreground = true;

  VpnHostApi get _api => ref.read(vpnApiProvider);

  @override
  VpnState build() {
    _lifecycle = AppLifecycleListener(
      onResume: () {
        _foreground = true;
        unawaited(_refresh());
      },
      onPause: () {
        _foreground = false;
        _syncPolling();
      },
    );
    ref.onDispose(() {
      _poll?.cancel();
      _lifecycle?.dispose();
    });
    // The tunnel can outlive the UI (activity recreated, app reopened from the
    // notification), so ask the backend instead of assuming "off".
    Future.microtask(_refresh);
    // An OpenVPN tunnel lives in its own process; after a cold start its state
    // reaches this process a moment later, so look once more.
    Future.delayed(const Duration(milliseconds: 1500), _refresh);
    return const VpnState();
  }

  Future<void> connect(ServerChoice choice) async {
    if (state.phase == VpnPhase.connecting || state.phase == VpnPhase.disconnecting) {
      return;
    }
    state = VpnState(phase: VpnPhase.connecting, tunnelId: choice.id);
    // For the admin's analytics: what kind of connection, never where to.
    final (kind, protocol, country) = switch (choice) {
      OwnServer(:final tunnel) => (tunnel.id.startsWith(gserverPrefix) ? 'gserver' : 'own', 'wireguard', null),
      CommunityChoice(:final server) => ('free', server.sstpHost != null ? 'sstp' : 'openvpn', server.countryCode),
    };
    try {
      final allowed = await _api.prepare();
      if (!allowed) {
        state = VpnState(error: t.errors.notAuthorized);
        Events.connectFailed(kind: kind, protocol: protocol, code: 'not_authorized');
        return;
      }
      // App rules and Shield DNS are layered on here, the same for both
      // engines; saved configs are never rewritten.
      final rules = await ref.read(rulesProvider.future);
      switch (choice) {
        case OwnServer(:final tunnel):
          await _api.connect(rules.render(tunnel), choice.name);
        // SSTP when the server offers it: no config download, VPN Gate's
        // public login. OpenVPN remains for servers without SSTP.
        case CommunityChoice(:final server) when server.sstpHost != null:
          await _api.connectSstp(
            SstpOptions(
              host: server.sstpHost!,
              port: server.sstpPort ?? 443,
              username: 'vpn',
              password: 'vpn',
              name: choice.name,
              excludedApps: rules.excluded.toList(),
              dnsServers: rules.shield ? shieldResolvers : const [],
            ),
          );
        case CommunityChoice(:final server):
          final String config;
          try {
            config = await fetchCommunityConfig(server.id);
          } on Exception {
            state = VpnState(error: t.errors.downloadFailed);
            Events.connectFailed(kind: kind, protocol: protocol, code: 'download');
            return;
          }
          await _api.connectOpenVpn(
            config,
            OpenVpnOptions(
              name: choice.name,
              excludedApps: rules.excluded.toList(),
              dnsServers: rules.shield ? shieldResolvers : const [],
            ),
          );
      }
      state = VpnState(
        phase: VpnPhase.on,
        connectedAt: DateTime.now(),
        tunnelId: choice.id,
      );
      _syncPolling();
      Events.connected(kind: kind, protocol: protocol, serverCountry: country);
    } on PlatformException catch (e) {
      state = VpnState(error: _describe(e, community: choice is CommunityChoice));
      Events.connectFailed(kind: kind, protocol: protocol, code: e.code);
    }
  }

  /// Stops the tunnel for [minutes]; it reconnects to the same server after.
  Future<void> pause(int minutes) async {
    if (state.phase != VpnPhase.on) return;
    await _api.pause(minutes);
    await Future<void>.delayed(const Duration(milliseconds: 600), _refresh);
  }

  /// Ends a pause now.
  Future<void> resume() async {
    if (state.pausedUntil == null) return;
    await _api.resume();
    await Future<void>.delayed(const Duration(seconds: 2), _refresh);
  }

  Future<void> disconnect() async {
    if (state.phase != VpnPhase.on) return;
    state = state.copyWith(phase: VpnPhase.disconnecting);
    try {
      await _api.disconnect();
    } on PlatformException catch (e) {
      state = state.copyWith(phase: VpnPhase.on, error: _describe(e));
      return;
    }
    state = const VpnState();
    _syncPolling();
  }

  /// Re-applies rules to the running tunnel: down, then up on the same
  /// server. A second or two without the tunnel, which the rules screen says.
  Future<void> reconnect() async {
    if (state.phase != VpnPhase.on) return;
    final choice = (await ref.read(tunnelsProvider.future)).choice;
    if (choice == null) return;
    await disconnect();
    await connect(choice);
  }

  Future<void> _refresh() async {
    final TunnelStatus status;
    try {
      status = await _api.status();
    } on PlatformException {
      return;
    }
    final paused = status.phase == TunnelPhase.paused;
    final up = status.phase == TunnelPhase.up || status.phase == TunnelPhase.reconnecting || paused;
    final reconnecting = status.phase == TunnelPhase.reconnecting;
    final busy = state.phase == VpnPhase.connecting || state.phase == VpnPhase.disconnecting;
    if (busy) return;

    if (up) {
      state = VpnState(
        phase: VpnPhase.on,
        rxBytes: paused ? state.rxBytes : status.rxBytes,
        txBytes: paused ? state.txBytes : status.txBytes,
        connectedAt: state.connectedAt ?? DateTime.now(),
        tunnelId: state.tunnelId,
        reconnecting: reconnecting,
        pausedUntil: paused ? DateTime.fromMillisecondsSinceEpoch(status.pausedUntilMs) : null,
      );
    } else if (state.phase == VpnPhase.on) {
      // Stopped from the notification or Quick Settings: the user's choice.
      // Otherwise it dropped underneath us (another VPN app, revoked
      // consent), and that is worth saying.
      state = status.stoppedByUser
          ? const VpnState()
          : VpnState(error: t.errors.turnedOff);
    }
    _syncPolling();
  }

  void _syncPolling() {
    final shouldPoll = _foreground && state.phase == VpnPhase.on;
    if (shouldPoll && _poll == null) {
      _poll = Timer.periodic(_pollEvery, (_) => _refresh());
    } else if (!shouldPoll) {
      _poll?.cancel();
      _poll = null;
    }
  }

  static String _describe(PlatformException e, {bool community = false}) {
    // Community servers are volunteers' machines that come and go, so their
    // failures point the user at another server rather than at their phone.
    final tryAnother = community ? ' ${t.errors.tryAnother}' : '';
    return switch (e.code) {
      'bad_config' => t.errors.badConfig(error: e.message ?? ''),
      'not_authorized' => t.errors.notAuthorized,
      'busy' => t.errors.busy,
      'timeout' => t.errors.timeout + tryAnother,
      'auth_failed' => t.errors.refused + tryAnother,
      'cancelled' || 'replaced' => t.errors.cancelled,
      _ => t.errors.failed(error: _sentence(e.message ?? e.code)) + tryAnother,
    };
  }

  static String _sentence(String s) {
    final trimmed = s.trim();
    return trimmed.endsWith('.') ? trimmed : '$trimmed.';
  }
}
