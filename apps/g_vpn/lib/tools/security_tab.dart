import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/meridian.dart';
import '../design/meridian_widgets.dart';
import '../i18n/strings.g.dart';
import '../vpn/tunnel_store.dart';
import '../vpn/vpn_controller.dart';
import 'devices_screen.dart';
import 'ports_screen.dart';
import 'router_screen.dart';
import 'security_check.dart';
import 'tool_widgets.dart';

/// Good, Fair or At risk, and its colour.
(String, Color) scoreLabel(int score, Meridian m) => score >= 80
    ? (t.security.good, m.good)
    : score >= 55
        ? (t.security.fair, m.warn)
        : (t.security.atRisk, m.bad);

/// "72 · Good", for the hub's app bar.
class ScoreChip extends StatelessWidget {
  const ScoreChip({super.key, required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = scoreLabel(score, context.mer);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: tone.withValues(alpha: .14), borderRadius: BorderRadius.circular(999)),
      child: Text('$score · $label', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: tone)),
    );
  }
}

/// The network's security: a score, how it moved this week, and every
/// check with what to do about it.
class SecurityTab extends ConsumerWidget {
  const SecurityTab({super.key, required this.openDevices});

  /// Switches the hub to its Devices tab.
  final VoidCallback openDevices;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.mer;
    final report = ref.watch(securityReportProvider);
    final snoozed = ref.watch(snoozeProvider).value ?? const <String, DateTime>{};
    final network = ref.watch(deviceScanProvider).network;
    final trend = ref.watch(securityTrendProvider).value?[network ?? 'lan'] ?? const <(DateTime, int)>[];

    return switch (report) {
      AsyncData(:final value) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _Score(report: value),
            if (trend.length >= 2) ...[const SizedBox(height: 14), _Trend(points: trend)],
            const SizedBox(height: 14),
            _Checks(
              checks: value.checks.where((c) => !snoozed.containsKey(c.id) || c.tone == CheckTone.good).toList(),
              openDevices: openDevices,
            ),
            if (value.checks.any((c) => snoozed.containsKey(c.id) && c.tone != CheckTone.good)) ...[
              ToolHeading(t.security.snoozed),
              _Checks(
                checks: value.checks.where((c) => snoozed.containsKey(c.id) && c.tone != CheckTone.good).toList(),
                openDevices: openDevices,
                snoozed: true,
              ),
            ],
          ],
        ),
      AsyncError(:final error) => Padding(
          padding: const EdgeInsets.all(20),
          child: Text('$error', style: TextStyle(color: m.bad)),
        ),
      _ => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            CircularProgressIndicator(color: m.good),
            const SizedBox(height: 14),
            Text(t.security.checking, style: TextStyle(fontSize: 14, color: m.muted)),
          ]),
        ),
    };
  }
}

class _Score extends StatelessWidget {
  const _Score({required this.report});

  final SecurityReport report;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final (label, tone) = scoreLabel(report.score, m);
    final filled = (report.score / 20).ceil().clamp(1, 5);
    const steps = [0, 1, 2, 3, 4];
    Color stepColor(int i) => switch (i) { 0 => m.bad, 1 || 2 => m.warn, _ => m.good };
    final time = TimeOfDay.fromDateTime(report.at).format(context);
    return Row(
      children: [
        Text('${report.score}', style: m.monoStyle(size: 60, weight: FontWeight.w500, color: m.text)),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: tone)),
              Text(
                report.toFix == 0 ? t.security.allClear : t.security.toFix(n: report.toFix),
                style: TextStyle(fontSize: 13, color: m.muted),
              ),
              Text(t.security.checked(time: time), style: TextStyle(fontSize: 12, color: m.muted)),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (final i in steps) ...[
                    if (i > 0) const SizedBox(width: 4),
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        height: 10,
                        decoration: BoxDecoration(
                          color: i < filled ? stepColor(i) : m.surface2,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The score day by day, with how much it moved.
class _Trend extends StatelessWidget {
  const _Trend({required this.points});

  final List<(DateTime, int)> points;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final delta = points.last.$2 - points.first.$2;
    final tone = delta >= 0 ? m.good : m.bad;
    return MerCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(t.security.trend,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: .8, color: m.muted)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: tone.withValues(alpha: .14), borderRadius: BorderRadius.circular(999)),
                child: Text(delta >= 0 ? '+$delta' : '$delta', style: m.monoStyle(size: 12, color: tone)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 56,
            width: double.infinity,
            child: CustomPaint(painter: _TrendPainter(points: [for (final p in points) p.$2], color: tone, m: m)),
          ),
        ],
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({required this.points, required this.color, required this.m});

  final List<int> points;
  final Color color;
  final Meridian m;

  @override
  void paint(Canvas canvas, Size size) {
    final lo = (points.reduce((a, b) => a < b ? a : b) - 5).clamp(0, 100);
    final hi = (points.reduce((a, b) => a > b ? a : b) + 5).clamp(0, 100);
    final span = (hi - lo).clamp(1, 100);
    Offset at(int i) => Offset(
          4 + (size.width - 8) * i / (points.length - 1),
          size.height - 4 - (size.height - 8) * (points[i] - lo) / span,
        );
    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(at(i).dx, at(i).dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
    canvas.drawCircle(at(points.length - 1), 4.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TrendPainter old) => old.points != points || old.color != color;
}

class _Checks extends ConsumerWidget {
  const _Checks({required this.checks, required this.openDevices, this.snoozed = false});

  final List<SecurityCheck> checks;
  final VoidCallback openDevices;
  final bool snoozed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.mer;
    final choice = ref.watch(tunnelsProvider).value?.choice;

    void act(SecurityCheck c) {
      void push(Widget screen) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
      switch (c.action) {
        case CheckAction.review:
          push(const RouterScreen());
        case CheckAction.ports:
          push(PortsScreen(host: c.target));
        case CheckAction.confirm:
          openDevices();
        case CheckAction.scan:
          openDevices();
          ref.read(deviceScanProvider.notifier).scan();
        case CheckAction.look:
          final d = ref.read(deviceScanProvider).devices.where((d) => d.ip == c.target).firstOrNull;
          if (d != null) push(DeviceScreen(device: d, isNew: false, network: ref.read(deviceScanProvider).network));
        case CheckAction.connect:
          if (choice != null) ref.read(vpnProvider.notifier).connect(choice);
        case CheckAction.none:
          break;
      }
    }

    String? label(CheckAction a) => switch (a) {
          CheckAction.review => t.security.review,
          CheckAction.ports => t.security.review,
          CheckAction.confirm => t.security.confirmGo,
          CheckAction.scan => t.security.scanGo,
          CheckAction.look => t.security.look,
          CheckAction.connect => choice == null ? null : t.security.connectGo,
          CheckAction.none => null,
        };

    return MerCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final (i, c) in checks.indexed) ...[
            if (i > 0) Divider(height: 1, color: m.line),
            Opacity(
              opacity: snoozed ? .6 : 1,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                child: Row(
                  children: [
                    Builder(builder: (_) {
                      final tone = switch (c.tone) { CheckTone.good => m.good, CheckTone.warn => m.warn, CheckTone.bad => m.bad };
                      return Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(color: tone.withValues(alpha: .16), borderRadius: BorderRadius.circular(11)),
                        child: Icon(c.tone == CheckTone.good ? Icons.check_rounded : Icons.warning_amber_rounded, size: 18, color: tone),
                      );
                    }),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: m.text)),
                          Text(c.detail, style: TextStyle(fontSize: 12, color: m.muted)),
                        ],
                      ),
                    ),
                    if (label(c.action) case final text?)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: TextButton(
                          onPressed: () => act(c),
                          style: TextButton.styleFrom(
                            foregroundColor: c.tone == CheckTone.bad ? m.bad : c.tone == CheckTone.warn ? m.warn : m.good,
                            backgroundColor: (c.tone == CheckTone.bad ? m.bad : c.tone == CheckTone.warn ? m.warn : m.good)
                                .withValues(alpha: .14),
                            minimumSize: const Size(0, 40),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                            textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                          ),
                          child: Text(text),
                        ),
                      ),
                    if (c.tone != CheckTone.good)
                      IconButton(
                        tooltip: snoozed ? t.security.unsnooze : t.security.remindLater,
                        onPressed: () => snoozed
                            ? ref.read(snoozeProvider.notifier).wake(c.id)
                            : ref.read(snoozeProvider.notifier).snooze(c.id),
                        icon: Icon(snoozed ? Icons.alarm_on_rounded : Icons.schedule_rounded, size: 20, color: m.muted),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
