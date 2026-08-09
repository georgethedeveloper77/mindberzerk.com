import 'package:flutter/material.dart';

import '../app/theme/tokens.dart';
import '../ui/g_badge.dart';
import '../ui/g_card.dart';

/// Marks a tab that a later phase fills in.
///
/// Deliberately not an empty state and not a spinner. A tab that looks broken
/// during development gets shipped broken; a tab that names its own phase does
/// not. Every one of these is deleted by the phase it names.
class PlaceholderPanel extends StatelessWidget {
  const PlaceholderPanel({
    required this.phase,
    required this.title,
    required this.detail,
    super.key,
  });

  final String phase;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    return GCard(
      tint: t.accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          GBadge.partial(phase),
          const SizedBox(height: GSpace.md),
          Text(title, style: GType.heading.copyWith(color: t.text)),
          const SizedBox(height: GSpace.sm - 2),
          Text(detail, style: GType.bodySmall.copyWith(color: t.muted)),
        ],
      ),
    );
  }
}
