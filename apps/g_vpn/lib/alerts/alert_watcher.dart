import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../background/background_checks.dart';
import '../breaches/breaches.dart';
import '../breaches/breaches_screen.dart';
import '../history/usage.dart';
import '../home/home_scan.dart';
import '../i18n/strings.g.dart';
import '../tools/devices_screen.dart';
import '../tools/status_screen.dart';
import 'alerts.dart';
import 'alerts_screen.dart';
import 'report_screen.dart';

/// Monday 00:00 of the week [d] is in.
DateTime weekStart(DateTime d) {
  final day = DateTime(d.year, d.month, d.day);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

/// Watched by the shell: turns what the app notices into alerts. Joining
/// an open Wi-Fi goes to the inbox (Auto-connect already notifies about it
/// from Android itself); a finished week becomes the weekly report.
final alertWatcherProvider = Provider<void>((ref) {
  // An open or weak Wi-Fi, without the VPN covering it.
  ref.listen(networkScanProvider, (_, next) {
    final scan = next.value;
    final chip = scan?.chips.firstOrNull;
    final name = scan?.name;
    if (scan == null || chip == null || name == null || chip.tone != Tone.bad) return;
    ref.read(alertsProvider.notifier).add(
          AlertKind.openWifi,
          title: t.alerts.openWifiTitle(name: name),
          body: t.alerts.openWifiBody,
          route: '/hub',
          once: 'wifi:$name',
        );
  });

  // The weekly report, once the week is over and there is something in it.
  Future<void> report() async {
    final usage = await ref.read(usageProvider.future);
    final last = weekStart(DateTime.now()).subtract(const Duration(days: 7));
    final days = [for (var i = 0; i < 7; i++) usage[dayKey(last.add(Duration(days: i)))]].whereType<UsageDay>();
    if (days.every((d) => d.seconds == 0)) return;
    await ref.read(alertsProvider.notifier).add(
          AlertKind.report,
          title: t.alerts.reportTitle,
          body: t.alerts.reportBody(hours: (days.fold<int>(0, (n, d) => n + d.seconds) / 3600).toStringAsFixed(1)),
          route: '/report',
          notify: true,
          once: 'report:${dayKey(last)}',
          onceFor: const Duration(days: 30),
        );
  }

  // Breaches are also checked while the app is open, so a phone that
  // Android rarely wakes in the background still hears about big ones.
  Future<void> breaches() async {
    if ((await ref.read(alertsProvider.future)).enabled.contains(AlertKind.breach)) {
      await checkNewBreaches();
      await ref.read(alertsProvider.notifier).reload();
    }
  }

  final timer = Timer(const Duration(seconds: 6), () {
    report();
    breaches();
  });
  final daily = Timer.periodic(const Duration(hours: 6), (_) {
    report();
    breaches();
  });
  ref.onDispose(() {
    timer.cancel();
    daily.cancel();
  });
});

/// Opens the screen an alert points at.
Future<void> openAlertRoute(BuildContext context, String? route) async {
  if (route != null && route.startsWith('/breach:')) {
    final name = route.substring('/breach:'.length);
    final b = (await BreachCatalogue.cached()).where((b) => b.name == name).firstOrNull;
    if (!context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => b == null ? const BreachesScreen() : BreachScreen(breach: b),
    ));
    return;
  }
  final screen = switch (route) {
    '/breaches' => const BreachesScreen(),
    '/report' => const ReportScreen(),
    '/hub' => const DevicesScreen(),
    '/status' => const StatusScreen(),
    '/alerts' => const AlertsScreen(),
    _ => null,
  };
  if (screen != null) Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
}

/// Opens the app where a tapped notification points, if it did.
Future<void> takeAlertRoute(BuildContext context) async {
  final route = await AlertsBridge.launchRoute();
  if (route != null && context.mounted) openAlertRoute(context, route);
}
