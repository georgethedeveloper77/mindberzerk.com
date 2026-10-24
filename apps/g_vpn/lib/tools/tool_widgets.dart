import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/list_ui.dart';
import '../design/meridian.dart';

/// A tool screen: plain app bar, scrolling body, optional pinned action.
class ToolPage extends StatelessWidget {
  const ToolPage({super.key, required this.title, required this.children, this.action, this.info});

  final String title;
  final List<Widget> children;

  /// What the tool does and how, behind the app bar's "i".
  final String? info;

  /// Pinned under the content (Start, Scan, Send...).
  final Widget? action;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(title),
          centerTitle: false,
          actions: [if (info != null) InfoAction(title: title, body: info!)],
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: children),
            ),
            if (action != null)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: SizedBox(width: double.infinity, child: action),
                ),
              ),
          ],
        ),
      );
}

/// Section heading in the tools index.
class ToolSection extends StatelessWidget {
  const ToolSection(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 6),
        child: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: context.mer.text)),
      );
}

/// One tool in the index: icon square, name, one line on what it is for.
class ToolRow extends StatelessWidget {
  const ToolRow({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Meridian.rTile),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: m.text)),
                  const SizedBox(height: 2),
                  Text(description, style: TextStyle(fontSize: 13, height: 1.35, color: m.muted)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 10, left: 6),
              child: Icon(Icons.chevron_right_rounded, color: m.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// A row of headline numbers (Latency | Download | Upload).
class StatStrip extends StatelessWidget {
  const StatStrip({super.key, required this.stats});

  final List<(String label, String value, Color? color)> stats;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    return Row(
      children: [
        for (final (i, s) in stats.indexed) ...[
          if (i > 0) Container(width: 1, height: 34, color: m.line),
          Expanded(
            child: Column(
              children: [
                Text(s.$1, style: TextStyle(fontSize: 12, color: m.muted)),
                const SizedBox(height: 2),
                Text(s.$2, style: m.monoStyle(size: 16, weight: FontWeight.w600, color: s.$3 ?? m.text)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// A plain line chart: one or more series over a shared, auto-scaled axis,
/// with faint guide lines. Null values are gaps (a lost ping).
class LineChartView extends StatelessWidget {
  const LineChartView({super.key, required this.series, this.height = 140, this.unit = ''});

  final List<(List<double?> values, Color color)> series;
  final double height;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _LinePainter(series: series, m: m, unit: unit)),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({required this.series, required this.m, required this.unit});

  final List<(List<double?> values, Color color)> series;
  final Meridian m;
  final String unit;

  @override
  void paint(Canvas canvas, Size size) {
    final all = [for (final s in series) ...s.$1.whereType<double>()];
    final top = _niceMax(all.isEmpty ? 1 : all.reduce(math.max));
    const labelW = 40.0;
    final plot = Rect.fromLTWH(0, 6, size.width - labelW, size.height - 12);

    final guide = Paint()
      ..color = m.line
      ..strokeWidth = 1;
    final label = TextStyle(fontSize: 10, color: m.muted, fontFamily: Meridian.mono);
    for (var i = 0; i <= 3; i++) {
      final y = plot.bottom - plot.height * i / 3;
      _dashed(canvas, Offset(plot.left, y), Offset(plot.right, y), guide);
      final tp = TextPainter(
        text: TextSpan(text: '${(top * i / 3).round()}$unit', style: label),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(plot.right + 6, y - tp.height / 2));
    }

    final count = series.fold<int>(0, (n, s) => math.max(n, s.$1.length));
    if (count < 2) return;
    for (final (values, color) in series) {
      final path = Path();
      var started = false;
      for (var i = 0; i < values.length; i++) {
        final v = values[i];
        if (v == null) {
          started = false;
          continue;
        }
        final p = Offset(plot.left + plot.width * i / (count - 1), plot.bottom - plot.height * (v / top).clamp(0, 1));
        if (started) {
          path.lineTo(p.dx, p.dy);
        } else {
          path.moveTo(p.dx, p.dy);
          started = true;
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  static double _niceMax(double v) {
    for (final step in const <double>[5, 10, 20, 50, 100, 200, 250, 500, 1000, 2000]) {
      if (v <= step) return step;
    }
    return (v / 1000).ceil() * 1000;
  }

  static void _dashed(Canvas c, Offset a, Offset b, Paint p) {
    const dash = 4.0, gap = 4.0;
    final total = (b - a).distance;
    final dir = (b - a) / total;
    for (var d = 0.0; d < total; d += dash + gap) {
      c.drawLine(a + dir * d, a + dir * math.min(d + dash, total), p);
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) => true;
}

/// Neutral card used inside tool pages.
class ToolCard extends StatelessWidget {
  const ToolCard({super.key, required this.child, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    return Material(
      color: m.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Meridian.rCard),
        side: BorderSide(color: m.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Local-network tools need the VPN off: with it on, the phone's traffic
/// (and so the probes) leaves through the tunnel instead of the Wi-Fi.
class LanVpnNotice extends StatelessWidget {
  const LanVpnNotice({super.key, required this.vpnOn});

  final bool vpnOn;

  @override
  Widget build(BuildContext context) {
    if (!vpnOn) return const SizedBox.shrink();
    final m = context.mer;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: m.warnSoft, borderRadius: BorderRadius.circular(Meridian.rChip)),
      child: Text(
        'VPN is on. Disconnect for an accurate result.',
        style: TextStyle(color: m.warn, fontSize: 13, height: 1.4, fontWeight: FontWeight.w600),
      ),
    );
  }
}
