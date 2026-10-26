import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../design/meridian.dart';
import '../design/meridian_widgets.dart';
import '../history/stats_widgets.dart' show formatDuration;
import '../history/usage.dart';
import '../home/connect_card.dart' show formatBytes;
import '../i18n/strings.g.dart';
import '../tools/security_check.dart';
import '../tools/security_tab.dart' show scoreLabel;
import '../tools/tool_widgets.dart';
import '../tools/tools_providers.dart';
import 'alert_watcher.dart' show weekStart;
import 'alerts.dart';
import 'alerts_screen.dart' show alertLook;

/// One week, put together from what the phone already keeps: protected
/// time and data, the security score, alerts, and speed tests.
@immutable
class WeekReport {
  const WeekReport({
    required this.start,
    required this.days,
    required this.seconds,
    required this.bytes,
    required this.lastWeekSeconds,
    this.topServer,
    this.topServerSeconds = 0,
    this.score,
    this.scoreChange,
    this.alerts = const {},
    this.bestDown,
  });

  final DateTime start;

  /// Protected seconds per day, Monday first.
  final List<int> days;
  final int seconds;
  final int bytes;
  final int lastWeekSeconds;
  final String? topServer;
  final int topServerSeconds;
  final int? score;
  final int? scoreChange;
  final Map<AlertKind, int> alerts;
  final double? bestDown;
}

WeekReport buildReport({
  required DateTime start,
  required Map<String, UsageDay> usage,
  required Map<String, List<(DateTime, int)>> trend,
  required List<Alert> alerts,
  required List<SpeedResult> speeds,
}) {
  final end = start.add(const Duration(days: 7));
  final days = [for (var i = 0; i < 7; i++) usage[dayKey(start.add(Duration(days: i)))] ?? const UsageDay()];
  final before = [for (var i = 1; i <= 7; i++) usage[dayKey(start.subtract(Duration(days: i)))] ?? const UsageDay()];

  // The server used longest this week.
  final byServer = <String, (String, int)>{};
  for (final d in days) {
    for (final e in d.servers.entries) {
      final had = byServer[e.key]?.$2 ?? 0;
      byServer[e.key] = (e.value.name, had + e.value.seconds);
    }
  }
  final top = byServer.values.fold<(String, int)?>(null, (best, s) => best == null || s.$2 > best.$2 ? s : best);

  // The network with the most score points this week.
  List<(DateTime, int)> inWeek(List<(DateTime, int)> pts) =>
      pts.where((p) => !p.$1.isBefore(start) && p.$1.isBefore(end)).toList();
  final scored = trend.values.map(inWeek).where((p) => p.isNotEmpty).toList()..sort((a, b) => b.length.compareTo(a.length));
  final points = scored.firstOrNull;

  final weekAlerts = alerts.where((a) => !a.at.isBefore(start) && a.at.isBefore(end));
  final direct = speeds.where((s) => !s.viaVpn && !s.at.isBefore(start) && s.at.isBefore(end));

  return WeekReport(
    start: start,
    days: [for (final d in days) d.seconds],
    seconds: days.fold(0, (n, d) => n + d.seconds),
    bytes: days.fold(0, (n, d) => n + d.bytes),
    lastWeekSeconds: before.fold(0, (n, d) => n + d.seconds),
    topServer: top?.$1,
    topServerSeconds: top?.$2 ?? 0,
    score: points?.last.$2,
    scoreChange: points == null || points.length < 2 ? null : points.last.$2 - points.first.$2,
    alerts: {
      for (final k in AlertKind.values)
        if (k != AlertKind.report && weekAlerts.any((a) => a.kind == k)) k: weekAlerts.where((a) => a.kind == k).length,
    },
    bestDown: direct.isEmpty ? null : direct.map((s) => s.down).reduce((a, b) => a > b ? a : b),
  );
}

/// The weekly report: last full week, or this week so far when the phone
/// has nothing from last week. Shareable as an image.
class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  final _capture = GlobalKey();
  bool _sharing = false;

  Future<void> _share(WeekReport r) async {
    final boundary = _capture.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null || _sharing) return;
    setState(() => _sharing = true);
    try {
      final image = await boundary.toImage(pixelRatio: 3);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) return;
      await SharePlus.instance.share(ShareParams(
        files: [XFile.fromData(png.buffer.asUint8List(), mimeType: 'image/png', name: 'g-vpn-week.png')],
        text: t.report.shareText,
      ));
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final usage = ref.watch(usageProvider).value ?? const <String, UsageDay>{};
    final trend = ref.watch(securityTrendProvider).value ?? const <String, List<(DateTime, int)>>{};
    final alerts = ref.watch(alertsProvider).value?.items ?? const <Alert>[];
    final speeds = ref.watch(speedHistoryProvider).value ?? const <SpeedResult>[];

    final thisWeek = weekStart(DateTime.now());
    final lastWeek = thisWeek.subtract(const Duration(days: 7));
    var report = buildReport(start: lastWeek, usage: usage, trend: trend, alerts: alerts, speeds: speeds);
    final partial = report.seconds == 0;
    if (partial) report = buildReport(start: thisWeek, usage: usage, trend: trend, alerts: alerts, speeds: speeds);

    return ToolPage(
      title: t.report.title,
      icon: Icons.insert_chart_outlined_rounded,
      color: m.brand,
      action: FilledButton.icon(
        onPressed: _sharing ? null : () => _share(report),
        icon: const Icon(Icons.ios_share_rounded),
        label: Text(t.report.share),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
      ),
      children: [
        RepaintBoundary(
          key: _capture,
          child: Container(
            color: m.bg,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: _ReportBody(report: report, partial: partial),
          ),
        ),
      ],
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.report, required this.partial});

  final WeekReport report;
  final bool partial;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final r = report;
    final loc = MaterialLocalizations.of(context);
    final range = '${loc.formatShortMonthDay(r.start)} – ${loc.formatShortMonthDay(r.start.add(const Duration(days: 6)))}';
    final more = r.seconds - r.lastWeekSeconds;
    final headline = (r.scoreChange ?? 0) > 0
        ? t.report.safer
        : more > 0 && r.lastWeekSeconds > 0
            ? t.report.moreProtected
            : t.report.yourWeek;
    final maxDay = r.days.fold<int>(1, (a, b) => a > b ? a : b);
    const weekdays = [DateTime.monday, DateTime.tuesday, DateTime.wednesday, DateTime.thursday, DateTime.friday, DateTime.saturday, DateTime.sunday];
    final dayLetters = [for (final d in weekdays) loc.narrowWeekdays[d % 7]];

    Widget tile(String label, String value, {String? note, Color? tone}) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: m.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: m.line)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .5, color: m.muted)),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value, style: m.monoStyle(size: 22, color: m.text)),
                ),
                if (note != null) Text(note, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: tone ?? m.muted)),
              ],
            ),
          ),
        );

    final (scoreWord, scoreTone) = r.score == null ? (null, m.muted) : scoreLabel(r.score!, m);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(partial ? t.report.soFar(range: range) : range, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: m.muted)),
        const SizedBox(height: 2),
        Text(headline, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -.5, color: m.text)),
        const SizedBox(height: 14),
        Row(children: [
          tile(
            t.report.protected,
            formatDuration(r.seconds),
            note: r.lastWeekSeconds == 0
                ? null
                : more >= 0
                    ? t.report.moreThan(d: formatDuration(more))
                    : t.report.lessThan(d: formatDuration(-more)),
            tone: more >= 0 ? m.good : m.muted,
          ),
          const SizedBox(width: 8),
          tile(t.report.data, formatBytes(r.bytes)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          tile(
            t.report.security,
            r.score == null ? '--' : '${r.score}',
            note: r.score == null
                ? t.report.noScore
                : r.scoreChange == null || r.scoreChange == 0
                    ? scoreWord
                    : '${r.scoreChange! > 0 ? '+' : ''}${r.scoreChange} · $scoreWord',
            tone: scoreTone,
          ),
          const SizedBox(width: 8),
          tile(t.report.speed, r.bestDown == null ? '--' : '${r.bestDown!.toStringAsFixed(r.bestDown! >= 100 ? 0 : 1)} ${t.speed.mbps}',
              note: r.bestDown == null ? t.report.noTest : t.report.bestDirect),
        ]),
        const SizedBox(height: 12),
        MerCard(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.report.protectedTime, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: .8, color: m.muted)),
              const SizedBox(height: 10),
              SizedBox(
                height: 92,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < 7; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              height: 4 + 66 * r.days[i] / maxDay,
                              decoration: BoxDecoration(
                                color: r.days[i] == maxDay && maxDay > 1 ? m.brand : m.brand.withValues(alpha: .35),
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(dayLetters[i], style: TextStyle(fontSize: 10, color: m.muted)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        MerCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final (i, (icon, tone, title, sub)) in [
                for (final e in r.alerts.entries)
                  (alertLook(e.key, m).$1, alertLook(e.key, m).$2, _alertLine(e.key, e.value), ''),
                if (r.topServer != null)
                  (Icons.star_outline_rounded, m.good, t.report.mostUsed(name: r.topServer!),
                      formatDuration(r.topServerSeconds)),
                if (r.alerts.isEmpty && r.topServer == null) (Icons.check_rounded, m.good, t.report.quiet, ''),
              ].indexed) ...[
                if (i > 0) Divider(height: 1, color: m.line),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  child: Row(children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(color: tone.withValues(alpha: .16), borderRadius: BorderRadius.circular(11)),
                      child: Icon(icon, size: 16, color: tone),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: m.text)),
                        if (sub.isNotEmpty) Text(sub, style: TextStyle(fontSize: 12, color: m.muted)),
                      ]),
                    ),
                  ]),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/brand/gvpn_mark.png', width: 16, height: 16),
            const SizedBox(width: 6),
            Text('G VPN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: m.muted)),
          ],
        ),
      ],
    );
  }
}

String _alertLine(AlertKind k, int n) => switch (k) {
      AlertKind.newDevice => t.report.newDevices(n: n),
      AlertKind.openWifi => t.report.openWifi(n: n),
      AlertKind.blocked => t.report.blocked(n: n),
      AlertKind.breach => t.report.breaches(n: n),
      AlertKind.report => '',
    };
