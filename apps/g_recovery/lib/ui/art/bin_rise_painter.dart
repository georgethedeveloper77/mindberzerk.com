import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';

/// The onboarding and home hero: file cards drifting up out of an open bin.
///
/// Drawn rather than shipped as an asset so it recolours with the theme and the
/// accent for free, and costs nothing in APK size. The Lottie version animates
/// the same composition, so this reads as the first frame rather than as a
/// different picture.
class BinRisePainter extends CustomPainter {
  const BinRisePainter({
    required this.tokens,
    this.progress = 0,
  });

  final GTokens tokens;

  /// 0 to 1. Static in Phase 1, driven by the Lottie controller later.
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final double unit = size.height / 132;
    final Offset origin = Offset(size.width * 0.5, size.height);

    _bubbles(canvas, size, unit);
    _card(canvas, origin, unit, dx: -1.05, dy: -0.66, angle: -0.21,
        colours: <Color>[tokens.photo, tokens.chat]);
    _card(canvas, origin, unit, dx: 1.02, dy: -0.72, angle: 0.19,
        colours: <Color>[tokens.video, tokens.docs]);
    _card(canvas, origin, unit, dx: -0.02, dy: -0.94, angle: -0.05,
        colours: <Color>[tokens.audio, tokens.apps]);
    _bin(canvas, origin, unit);
  }

  void _bubbles(Canvas canvas, Size size, double unit) {
    final List<(double, double, double, Color)> dots =
        <(double, double, double, Color)>[
      (0.16, 0.22, 4, tokens.photo),
      (0.86, 0.28, 5, tokens.video),
      (0.80, 0.82, 3.5, tokens.docs),
      (0.12, 0.72, 4.5, tokens.accent),
    ];
    for (final (double fx, double fy, double r, Color c) in dots) {
      final Paint paint = Paint()..color = c.withValues(alpha: 0.42);
      canvas.drawCircle(
        Offset(size.width * fx, size.height * fy),
        r * unit * 0.9,
        paint,
      );
    }
  }

  void _card(
    Canvas canvas,
    Offset origin,
    double unit, {
    required double dx,
    required double dy,
    required double angle,
    required List<Color> colours,
  }) {
    final double w = 30 * unit;
    final double h = 37 * unit;
    final Offset centre = origin + Offset(dx * 26 * unit, dy * 62 * unit);

    canvas.save();
    canvas.translate(centre.dx, centre.dy);
    canvas.rotate(angle);

    final Rect rect = Rect.fromCenter(center: Offset.zero, width: w, height: h);
    final RRect rrect = RRect.fromRectAndRadius(rect, Radius.circular(6 * unit));
    final Paint fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colours,
      ).createShader(rect);
    canvas.drawRRect(rrect, fill);

    final Paint rule = Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(rect.left + 5 * unit, rect.top + 9 * unit, 16 * unit, 3 * unit),
        Radius.circular(1.5 * unit),
      ),
      rule,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(rect.left + 5 * unit, rect.top + 16 * unit, 20 * unit, 3 * unit),
        Radius.circular(1.5 * unit),
      ),
      Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.3),
    );
    canvas.restore();
  }

  void _bin(Canvas canvas, Offset origin, double unit) {
    final Paint body = Paint()..color = tokens.panelAlt;
    final Paint edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, 1.2 * unit)
      ..color = tokens.lineStrong;

    final double top = origin.dy - 54 * unit;
    final double halfTop = 24 * unit;
    final double halfBottom = 19 * unit;
    final double bottom = origin.dy - 8 * unit;

    final Path path = Path()
      ..moveTo(origin.dx - halfTop, top)
      ..lineTo(origin.dx + halfTop, top)
      ..lineTo(origin.dx + halfBottom, bottom)
      ..lineTo(origin.dx - halfBottom, bottom)
      ..close();
    canvas.drawPath(path, body);
    canvas.drawPath(path, edge);

    final RRect lid = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(origin.dx, top - 4 * unit),
        width: 58 * unit,
        height: 9 * unit,
      ),
      Radius.circular(4.5 * unit),
    );
    canvas.drawRRect(lid, Paint()..color = tokens.panelHigh);
    canvas.drawRRect(lid, edge);

    final Paint rib = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.4 * unit
      ..strokeCap = StrokeCap.round
      ..color = tokens.lineStrong;
    for (final double offset in <double>[-11, 0, 11]) {
      canvas.drawLine(
        Offset(origin.dx + offset * unit, top + 10 * unit),
        Offset(origin.dx + offset * unit, bottom - 6 * unit),
        rib,
      );
    }
  }

  @override
  bool shouldRepaint(BinRisePainter oldDelegate) =>
      oldDelegate.tokens != tokens || oldDelegate.progress != progress;
}
