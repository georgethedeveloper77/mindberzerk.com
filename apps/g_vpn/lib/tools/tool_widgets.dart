import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/list_ui.dart';
import '../design/meridian.dart';

/// A tool screen: app bar with the tool's coloured mark, scrolling body,
/// optional pinned action in the tool's colour.
class ToolPage extends StatelessWidget {
  const ToolPage({
    super.key,
    required this.title,
    required this.children,
    this.action,
    this.info,
    this.icon,
    this.color,
    this.actions = const [],
  });

  final String title;
  final List<Widget> children;

  /// What the tool does and how, behind the app bar's "i".
  final String? info;

  /// Pinned under the content (Start, Scan, Send...).
  final Widget? action;

  /// The tool's mark beside the title, as in the Tools tab.
  final IconData? icon;

  /// The tool's colour: its mark, and its main button.
  final Color? color;

  /// Extra app bar buttons, before the "i".
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final tone = color;
    Widget? pinned = action;
    if (pinned != null && tone != null) {
      // Filled and outlined buttons take the tool's colour.
      final theme = Theme.of(context);
      pinned = Theme(
        data: theme.copyWith(colorScheme: theme.colorScheme.copyWith(primary: tone, onPrimary: m.bg)),
        child: pinned,
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: icon == null ? Text(title) : ToolTitle(title: title, icon: icon!, color: tone ?? m.brand),
        centerTitle: false,
        actions: [...actions, if (info != null) InfoAction(title: title, body: info!, icon: icon, color: tone)],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: children),
          ),
          if (pinned != null)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: SizedBox(width: double.infinity, child: pinned),
              ),
            ),
        ],
      ),
    );
  }
}

/// A tool's title with its coloured mark.
class ToolTitle extends StatelessWidget {
  const ToolTitle({super.key, required this.title, required this.icon, required this.color});

  final String title;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: color.withValues(alpha: .16), borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Flexible(child: Text(title, overflow: TextOverflow.fade, softWrap: false)),
        ],
      );
}

/// A small capitals heading between a tool page's blocks.
class ToolHeading extends StatelessWidget {
  const ToolHeading(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 0, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(text.toUpperCase(),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: .8, color: m.muted)),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// A labelled figure in a small tile: "PING / 14 ms".
class MetricTile extends StatelessWidget {
  const MetricTile({super.key, required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      decoration: BoxDecoration(
        color: m.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: m.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              maxLines: 1, softWrap: false, overflow: TextOverflow.fade,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .5, color: m.muted)),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: m.monoStyle(size: 17, color: color ?? m.text)),
          ),
        ],
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


/// Asks for one line of text. The field's controller lives and dies with
/// the dialog, so it is never disposed while the dialog animates out (which
/// broke the build when the keyboard was up).
Future<String?> askText(
  BuildContext context, {
  required String title,
  required String action,
  String initial = '',
  String? hint,
  TextInputType? keyboard,
}) =>
    showDialog<String>(
      context: context,
      builder: (_) => _AskText(title: title, action: action, initial: initial, hint: hint, keyboard: keyboard),
    );

class _AskText extends StatefulWidget {
  const _AskText({required this.title, required this.action, required this.initial, this.hint, this.keyboard});

  final String title;
  final String action;
  final String initial;
  final String? hint;
  final TextInputType? keyboard;

  @override
  State<_AskText> createState() => _AskTextState();
}

class _AskTextState extends State<_AskText> {
  late final _field = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: TextField(
          controller: _field,
          autofocus: true,
          keyboardType: widget.keyboard,
          textCapitalization: widget.keyboard == null ? TextCapitalization.sentences : TextCapitalization.none,
          decoration: InputDecoration(hintText: widget.hint),
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(onPressed: () => Navigator.pop(context, _field.text.trim()), child: Text(widget.action)),
        ],
      );
}
