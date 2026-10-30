/// A ring stroked in a distro's signature gradient.
///
/// Garuda's fastfetch preset shows a logo image instead of ASCII art, and the
/// Dr460nized mark is a neon ring. A brand image is not ours to ship, so the
/// desklet draws the ring itself from `ThemeSpec.accentGradient`: the colours
/// are the distro's, the shape is generic.
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

class GradientRing extends StatelessWidget {
  const GradientRing({
    super.key,
    required this.size,
    required this.colors,
  });

  final double size;

  /// Two or three stops. The sweep closes back on the first so the ring has
  /// no seam.
  final List<Color> colors;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: CustomPaint(
          size: Size.square(size),
          painter: _RingPainter(colors),
        ),
      );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.colors);

  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.16;
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..shader = SweepGradient(
        colors: [...colors, colors.first],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(rect);
    canvas.drawCircle(rect.center, (size.width - stroke) / 2, paint);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.colors != colors;
}
