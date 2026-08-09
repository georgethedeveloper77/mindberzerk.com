import 'package:flutter/material.dart';

import '../app/theme/tokens.dart';

/// The rounded G mark. Appears in the app bar, in every branded message, and in
/// onboarding. Placeholder glyph for now: swap the child for the real logo
/// asset when the new icon lands, and every use site updates at once.
class GLogoMark extends StatelessWidget {
  const GLogoMark({super.key, this.size = 34, this.background});

  final double size;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    final Color fill = background ?? t.accent;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: GRadius.all(size * 0.34),
      ),
      child: Text(
        'G',
        style: GType.heading.copyWith(
          color: t.onAccent,
          fontSize: size * 0.44,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}
