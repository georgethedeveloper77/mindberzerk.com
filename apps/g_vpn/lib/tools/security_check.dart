import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g_network/g_network.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../i18n/strings.g.dart';
import '../vpn/vpn_api.g.dart';
import '../vpn/vpn_controller.dart';
import 'device_memory.dart';
import 'devices_screen.dart';
import 'discovery.dart';
import 'network_screen.dart' show liveSnapshotProvider;
import 'probe.dart';
import 'upnp.dart';

enum CheckTone { good, warn, bad }

/// What tapping a check's button does.
enum CheckAction { none, review, ports, confirm, scan, look, connect }

/// One finding about this network.
@immutable
class SecurityCheck {
  const SecurityCheck({
    required this.id,
    required this.tone,
    required this.title,
    required this.detail,
    this.action = CheckAction.none,
    this.target,
  });

  /// Stable, for snoozing ("upnp", "ports", ...).
  final String id;
  final CheckTone tone;
  final String title;
  final String detail;
  final CheckAction action;

  /// The address the action is about (a camera, the router).
  final String? target;
}

@immutable
class SecurityReport {
  const SecurityReport({required this.checks, required this.score, required this.at});

  final List<SecurityCheck> checks;

  /// 0 to 100.
  final int score;
  final DateTime at;

  int get toFix => checks.where((c) => c.tone != CheckTone.good).length;
}

/// Points each finding costs: a problem 20, something to look at 8.
int scoreOf(List<SecurityCheck> checks) {
  var score = 100;
  for (final c in checks) {
    score -= switch (c.tone) { CheckTone.bad => 20, CheckTone.warn => 8, CheckTone.good => 0 };
  }
  return score.clamp(0, 100);
}

/// Ports that should never answer on a home router.
const _riskyRouterPorts = {21: 'FTP', 23: 'Telnet', 445: 'SMB', 3389: 'RDP', 5900: 'VNC'};

/// True when the resolver answers a name that cannot exist: some providers
/// and routers rewrite unknown names to their own pages (and ads).
Future<bool> dnsRedirects() async {
  final probe = 'gvpn-${math.Random().nextInt(1 << 30)}-check.invalid';
  try {
    final found = await InternetAddress.lookup(probe).timeout(const Duration(seconds: 3));
    return found.isNotEmpty;
  } on Object {
    return false;
  }
}

/// Runs every check for the network the phone is on. Re-runs when the
/// device scan, the device memory or the tunnel changes.
final securityReportProvider = FutureProvider.autoDispose<SecurityReport>((ref) async {
  final snap = await ref.watch(liveSnapshotProvider.future);
  // Only a finished scan matters here, not every step of its progress.
  ref.watch(deviceScanProvider.select((s) => (s.finished, s.devices.length, s.network)));
  final scan = ref.read(deviceScanProvider);
  final mem = await ref.watch(deviceMemoryProvider.future);
  final vpnOn = ref.watch(vpnProvider.select((s) => s.phase)) == VpnPhase.on;
  final api = ref.read(vpnApiProvider);
  final wifi = snap.transport == Transport.wifi;
  final gateway = snap.gateway;

  // The slow ones together: router, router ports, DNS, nearby networks.
  final results = await Future.wait<Object?>([
    if (wifi)
      () async {
        try {
          return await checkUpnp();
        } on Object {
          return null;
        }
      }()
    else
      Future<Object?>.value(null),
    gateway == null
        ? Future.value(const <int>[])
        : pooled(_riskyRouterPorts.keys.toList(), 5, (p) async => await isOpen(gateway, p) ? p : null)
            .then((open) => open.whereType<int>().toList()),
    vpnOn ? Future.value(false) : dnsRedirects(),
    if (wifi)
      () async {
        try {
          return await api.wifiNamesAllowed() ? await api.scanWifi() : null;
        } on Object {
          return null;
        }
      }()
    else
      Future<Object?>.value(null),
  ]);
  final upnp = results[0] as UpnpReport?;
  final riskyPorts = results[1] as List<int>;
  final redirects = results[2] as bool;
  final nearby = results[3] as List<WifiAccessPoint>?;

  final checks = <SecurityCheck>[];

  if (wifi) {
    final (tone, title, detail) = switch (snap.wifiSecurity) {
      WifiSecurity.open => (CheckTone.bad, t.security.wifiOpen, t.security.wifiOpenDetail),
      WifiSecurity.wep => (CheckTone.bad, t.security.wifiWep, t.security.wifiWepDetail),
      WifiSecurity.owe => (CheckTone.warn, t.security.wifiOwe, t.security.wifiOweDetail),
      WifiSecurity.wpa3 => (CheckTone.good, t.security.wifiSecure, 'WPA3'),
      WifiSecurity.wpa2 => (CheckTone.good, t.security.wifiSecure, 'WPA2'),
      WifiSecurity.enterprise => (CheckTone.good, t.security.wifiSecure, t.scan.enterprise),
      _ => (CheckTone.warn, t.security.wifiUnknown, t.security.wifiUnknownDetail),
    };
    checks.add(SecurityCheck(id: 'wifi', tone: tone, title: title, detail: detail));

    // WPS on this network, read from the nearby scan.
    final mine = nearby?.where((n) => n.ssid == snap.ssid && n.ssid.isNotEmpty).toList() ?? const [];
    if (mine.any((n) => n.security.split('+').contains('WPS'))) {
      checks.add(SecurityCheck(id: 'wps', tone: CheckTone.warn, title: t.security.wps, detail: t.security.wpsDetail));
    }
  }

  if (upnp != null) {
    checks.add(!upnp.enabled
        ? SecurityCheck(id: 'upnp', tone: CheckTone.good, title: t.security.upnpOff, detail: t.security.upnpOffDetail)
        : SecurityCheck(
            id: 'upnp',
            tone: CheckTone.warn,
            title: t.security.upnpOn,
            detail: upnp.mappings.isEmpty ? t.security.upnpOnDetail : t.security.upnpOpened(n: upnp.mappings.length),
            action: CheckAction.review,
          ));
  }

  if (gateway != null) {
    checks.add(riskyPorts.isEmpty
        ? SecurityCheck(
            id: 'ports',
            tone: CheckTone.good,
            title: t.security.portsOk,
            detail: t.security.portsChecked(n: _riskyRouterPorts.length),
          )
        : SecurityCheck(
            id: 'ports',
            tone: CheckTone.bad,
            title: t.security.portsRisky,
            detail: [for (final p in riskyPorts) '$p ${_riskyRouterPorts[p]}'].join(' · '),
            action: CheckAction.ports,
            target: gateway,
          ));
  }

  if (wifi) {
    if (!scan.finished) {
      checks.add(SecurityCheck(
        id: 'devices',
        tone: CheckTone.warn,
        title: t.security.scanFirst,
        detail: t.security.scanFirstDetail,
        action: CheckAction.scan,
      ));
    } else {
      final network = scan.network;
      String key(String ip) => deviceKey(network, ip);
      final others = scan.devices.where((d) => !d.isSelf && !d.isRouter).toList();
      final notMine = others.where((d) => mem.mine[key(d.ip)] == false).length;
      final unconfirmed = others.where((d) => mem.mine[key(d.ip)] == null).length;
      if (notMine > 0) {
        checks.add(SecurityCheck(
          id: 'devices',
          tone: CheckTone.bad,
          title: t.security.notMine(n: notMine),
          detail: t.security.notMineDetail,
          action: CheckAction.confirm,
        ));
      } else if (unconfirmed > 0) {
        checks.add(SecurityCheck(
          id: 'devices',
          tone: CheckTone.warn,
          title: t.security.confirm(n: unconfirmed),
          detail: t.security.confirmDetail,
          action: CheckAction.confirm,
        ));
      } else {
        checks.add(SecurityCheck(id: 'devices', tone: CheckTone.good, title: t.security.devicesOk, detail: t.security.devicesOkDetail));
      }
      // A camera nobody has claimed is worth a look.
      for (final d in others.where((d) => kindOf(d, mem, network) == DeviceKind.camera && mem.mine[key(d.ip)] != true)) {
        checks.add(SecurityCheck(
          id: 'camera:${d.ip}',
          tone: CheckTone.warn,
          title: t.security.camera,
          detail: d.name ?? d.ip,
          action: CheckAction.look,
          target: d.ip,
        ));
      }
    }
  }

  if (!vpnOn) {
    checks.add(redirects
        ? SecurityCheck(id: 'dns', tone: CheckTone.bad, title: t.security.dnsHijack, detail: t.security.dnsHijackDetail)
        : SecurityCheck(id: 'dns', tone: CheckTone.good, title: t.security.dnsOk, detail: t.security.dnsOkDetail));
  }

  checks.add(vpnOn
      ? SecurityCheck(id: 'vpn', tone: CheckTone.good, title: t.security.vpnOn, detail: t.security.vpnOnDetail)
      : SecurityCheck(
          id: 'vpn',
          tone: CheckTone.bad,
          title: t.security.vpnOff,
          detail: t.security.vpnOffDetail,
          action: CheckAction.connect,
        ));

  // Worst first, so what to fix leads.
  checks.sort((a, b) => b.tone.index.compareTo(a.tone.index));
  final report = SecurityReport(checks: checks, score: scoreOf(checks), at: DateTime.now());
  if (wifi) await ref.read(securityTrendProvider.notifier).record(snap.ssid, report.score);
  return report;
});

// ── Snoozes ─────────────────────────────────────────────────────────────

final snoozeProvider = AsyncNotifierProvider<Snoozes, Map<String, DateTime>>(Snoozes.new);

/// Checks the user asked to be reminded about later: they drop to the
/// bottom for a week. They still count in the score: a snooze is a
/// reminder, not a fix.
class Snoozes extends AsyncNotifier<Map<String, DateTime>> {
  static const _key = 'gvpn.security.snoozes.v1';

  @override
  Future<Map<String, DateTime>> build() async {
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    if (raw == null) return const {};
    try {
      final now = DateTime.now();
      return {
        for (final e in (jsonDecode(raw) as Map).entries)
          if (e.value is int && DateTime.fromMillisecondsSinceEpoch(e.value as int).isAfter(now))
            '${e.key}': DateTime.fromMillisecondsSinceEpoch(e.value as int),
      };
    } on FormatException {
      return const {};
    }
  }

  Future<void> snooze(String id) => _save({...state.value ?? const {}, id: DateTime.now().add(const Duration(days: 7))});

  Future<void> wake(String id) => _save({...state.value ?? const {}}..remove(id));

  Future<void> _save(Map<String, DateTime> next) async {
    state = AsyncData(next);
    await (await SharedPreferences.getInstance())
        .setString(_key, jsonEncode({for (final e in next.entries) e.key: e.value.millisecondsSinceEpoch}));
  }
}

// ── Trend ───────────────────────────────────────────────────────────────

final securityTrendProvider = AsyncNotifierProvider<SecurityTrend, Map<String, List<(DateTime, int)>>>(SecurityTrend.new);

/// One score a day per network, for the last two weeks.
class SecurityTrend extends AsyncNotifier<Map<String, List<(DateTime, int)>>> {
  static const _key = 'gvpn.security.trend.v1';

  @override
  Future<Map<String, List<(DateTime, int)>>> build() async {
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    if (raw == null) return const {};
    try {
      return {
        for (final e in (jsonDecode(raw) as Map).entries)
          '${e.key}': [
            for (final p in e.value as List)
              if (p is List && p.length == 2) (DateTime.fromMillisecondsSinceEpoch(p[0] as int), p[1] as int),
          ],
      };
    } on Object {
      return const {};
    }
  }

  Future<void> record(String? network, int score) async {
    final all = {...await future};
    final key = network ?? 'lan';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final list = [
      for (final p in all[key] ?? const <(DateTime, int)>[])
        if (p.$1 != today && now.difference(p.$1).inDays < 14) p,
      (today, score),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    all[key] = list;
    state = AsyncData(all);
    await (await SharedPreferences.getInstance()).setString(
      _key,
      jsonEncode({for (final e in all.entries) e.key: [for (final p in e.value) [p.$1.millisecondsSinceEpoch, p.$2]]}),
    );
  }
}
