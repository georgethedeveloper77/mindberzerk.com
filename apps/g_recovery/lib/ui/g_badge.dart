import 'package:flutter/material.dart';

import '../app/theme/tokens.dart';

/// The fidelity stamp. This is the app's signature element: every recovery
/// source, every restored file, and every message attachment carries one, so
/// the user always knows what quality they are getting before they act.
///
/// The tone values map to the pack schema's `fidelity` field, which is why they
/// are named after data rather than after colours.
enum GBadgeTone { full, partial, none, live, pro }

class GBadge extends StatelessWidget {
  const GBadge({required this.label, super.key, this.tone = GBadgeTone.none});

  const GBadge.full(String label, {Key? key})
    : this(label: label, key: key, tone: GBadgeTone.full);

  const GBadge.partial(String label, {Key? key})
    : this(label: label, key: key, tone: GBadgeTone.partial);

  const GBadge.live(String label, {Key? key})
    : this(label: label, key: key, tone: GBadgeTone.live);

  final String label;
  final GBadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    final Color colour;
    final bool filled;
    switch (tone) {
      case GBadgeTone.full:
        colour = t.success;
        filled = true;
      case GBadgeTone.partial:
        colour = t.warning;
        filled = true;
      case GBadgeTone.none:
        colour = t.dim;
        filled = false;
      case GBadgeTone.live:
        colour = t.video;
        filled = true;
      case GBadgeTone.pro:
        colour = t.accentText;
        filled = true;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? colour.withValues(alpha: 0.11) : null,
        borderRadius: GRadius.all(7),
        border: Border.all(
          color: filled ? colour.withValues(alpha: 0.38) : t.lineStrong,
        ),
      ),
      child: Text(
        label.toUpperCase(),
        style: GType.badge.copyWith(color: colour),
      ),
    );
  }
}
