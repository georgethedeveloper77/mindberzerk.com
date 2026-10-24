import 'package:flutter/material.dart';

import 'meridian.dart';

/// A country flag from the bundled set (flag-icons, MIT), by ISO code.
/// Unknown codes show a neutral tile rather than a broken image.
class CountryFlag extends StatelessWidget {
  const CountryFlag(this.code, {super.key, this.width = 28});

  final String code;
  final double width;

  @override
  Widget build(BuildContext context) {
    final h = width * .75;
    return Container(
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: context.mer.line),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.asset(
          'assets/flags/${code.toLowerCase()}.png',
          width: width,
          height: h,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(width: width, height: h, color: context.mer.surface2),
        ),
      ),
    );
  }
}
