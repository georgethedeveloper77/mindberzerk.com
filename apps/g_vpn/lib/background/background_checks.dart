import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:g_network/g_network.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../alerts/alerts.dart';
import '../breaches/breaches.dart';
import '../i18n/strings.g.dart';
import '../tools/lan.dart';

/// When the background checks last ran, for Alerts › settings.
const backgroundLastRunKey = 'gvpn.background.last_run.v1';

const _channel = MethodChannel('com.mindberzerk.gvpn/background');

/// Started by Android's WorkManager (ChecksWorker.kt) every few hours, in
/// its own Flutter engine, with no screen. Runs the checks the user left on
/// in Alerts, then tells the worker it is done.
@pragma('vm:entry-point')
Future<void> backgroundMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  LocaleSettings.useDeviceLocale();
  try {
    await runBackgroundChecks().timeout(const Duration(minutes: 3));
  } on Object {
    // A failed run costs one round; the next comes in a few hours.
  } finally {
    try {
      await _channel.invokeMethod<void>('done');
    } on Object {
      // The worker stops on its own timeout.
    }
  }
}

Future<void> runBackgroundChecks() async {
  final state = await AlertsStore.load();
  if (state.enabled.contains(AlertKind.breach)) await checkNewBreaches();
  if (state.enabled.contains(AlertKind.newDevice)) await checkNewDevices();
  await (await SharedPreferences.getInstance()).setInt(backgroundLastRunKey, DateTime.now().millisecondsSinceEpoch);
}

/// Big breaches (a million accounts or more) published since the last
/// look. The first look only remembers where the catalogue stands.
Future<void> checkNewBreaches() async {
  const seenKey = 'gvpn.breaches.seen.v1';
  final prefs = await SharedPreferences.getInstance();
  final list = await BreachCatalogue.load(force: true);
  if (list.isEmpty) return;
  final seen = DateTime.tryParse(prefs.getString(seenKey) ?? '');
  await prefs.setString(seenKey, list.first.addedDate.toIso8601String());
  if (seen == null) return;
  for (final b in list.where((b) => b.addedDate.isAfter(seen) && b.pwnCount >= 1000000).take(3)) {
    final alert = await AlertsStore.add(
      AlertKind.breach,
      title: t.alerts.breachTitle(name: b.title),
      body: [t.breaches.accounts(n: b.pwnCount, count: compactCount(b.pwnCount)), ...b.dataClasses.take(2)].join(' · '),
      route: '/breach:${b.name}',
      once: 'breach:${b.name}',
      onceFor: const Duration(days: 365),
    );
    if (alert != null) await AlertsBridge.notify(alert);
  }
}

/// New devices on a Wi-Fi the user has scanned before (their own, not a
/// cafe's), compared with that last scan. Skipped through the VPN, which
/// hides the local network.
Future<void> checkNewDevices() async {
  final snap = await NetworkInfoProbe().snapshot();
  final network = snap.ssid;
  if (snap.transport != Transport.wifi || snap.vpnActive || network == null) return;
  final base = subnetBase(snap.gateway, snap.addresses);
  if (base == null) return;
  final prefs = await SharedPreferences.getInstance();
  final key = 'gvpn.lan_seen.$base';
  final seen = prefs.getStringList(key);
  if (seen == null) return;
  final self = snap.addresses.where((a) => a.startsWith('$base.')).firstOrNull;
  final devices = await scanLan(base: base, gateway: snap.gateway, selfIp: self);
  final now = [for (final d in devices) d.ip];
  await prefs.setStringList(key, now);
  final fresh = devices.where((d) => !seen.contains(d.ip)).toList();
  if (fresh.isEmpty) return;
  final alert = await AlertsStore.add(
    AlertKind.newDevice,
    title: t.alerts.newDeviceTitle(n: fresh.length, network: network),
    body: [for (final d in fresh.take(3)) d.name ?? d.ip].join(', '),
    route: '/hub',
  );
  if (alert != null) await AlertsBridge.notify(alert);
}
