import 'package:flutter/material.dart';

/// Seam for the Lottie art.
///
/// Phase 1 renders a painter. Phase 4 swaps the body of this widget for a
/// Lottie.asset call and keeps the painter as the fallback, so no call site
/// changes when the animation lands. Two reasons the fallback stays permanent:
/// budget Transsion devices drop frames on heavy Lottie JSON, and a failed
/// asset load must degrade to art rather than to a blank rectangle.
class GArtSlot extends StatelessWidget {
  const GArtSlot({
    required this.painter,
    super.key,
    this.height = 132,
    this.semanticsLabel,
  });

  final CustomPainter painter;
  final double height;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final Widget art = SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: painter),
    );
    if (semanticsLabel == null) return art;
    return Semantics(label: semanticsLabel, child: art);
  }
}
