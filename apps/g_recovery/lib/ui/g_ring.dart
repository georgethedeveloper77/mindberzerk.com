import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/theme/tokens.dart';

@immutable
class GRingSegment {
  const GRingSegment({required this.fraction, required this.colour});

  /// Share of the whole ring, 0 to 1. Segments are drawn in order and the
  /// remainder is left as track.
  final double fraction;
  final Color colour;
}

/// Segmented storage donut. Used on home and on the storage tab.
class GRing extends StatelessWidget {
  const GRing({
    required this.segments,
    super.key,
    this.size = 112,
    this.thickness = 13,
    this.centreTop,
    this.centreBottom,
  });

  final List<GRingSegment> segments;
  final double size;
  final double thickness;
  final String? centreTop;
  final String? centreBottom;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GRingPainter(
          segments: segments,
          track: t.panelHigh,
          thickness: thickness,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (centreTop != null)
                Text(
                  centreTop!,
                  style: GType.monoNumber.copyWith(
                    color: t.text,
                    fontSize: size * 0.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (centreBottom != null)
                Text(
                  centreBottom!,
                  style: GType.monoSmall.copyWith(color: t.muted),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GRingPainter extends CustomPainter {
  const _GRingPainter({
    required this.segments,
    required this.track,
    required this.thickness,
  });

  final List<GRingSegment> segments;
  final Color track;
  final double thickness;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final double radius = (math.min(size.width, size.height) - thickness) / 2;
    final Rect arcRect = Rect.fromCircle(
      center: rect.center,
      radius: radius,
    );

    final Paint base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..color = track;
    canvas.drawArc(arcRect, 0, math.pi * 2, false, base);

    double start = -math.pi / 2;
    for (final GRingSegment segment in segments) {
      final double sweep = math.pi * 2 * segment.fraction.clamp(0.0, 1.0);
      if (sweep <= 0) continue;
      final Paint paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..color = segment.colour;
      canvas.drawArc(arcRect, start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_GRingPainter oldDelegate) =>
      oldDelegate.track != track ||
      oldDelegate.thickness != thickness ||
      oldDelegate.segments != segments;
}
