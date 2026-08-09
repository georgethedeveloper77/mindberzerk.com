import 'package:flutter/material.dart';

import '../app/theme/tokens.dart';

class GChip extends StatelessWidget {
  const GChip({
    required this.label,
    super.key,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    final BorderRadius radius = GRadius.all(GRadius.chip);

    return Material(
      color: selected ? t.accent : const Color(0x00000000),
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: selected ? const Color(0x00000000) : t.lineStrong,
            ),
          ),
          child: Text(
            label,
            style: GType.label.copyWith(
              color: selected ? t.onAccent : t.muted,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
