import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../bridge/recovery_api.g.dart';
import '../../../core/format.dart';
import '../../../ui/art/bin_rise_painter.dart';
import '../../../ui/art/g_art_slot.dart';
import '../../../ui/g_badge.dart';
import '../../../ui/g_button.dart';
import '../../../ui/g_card.dart';
import '../../recovery/category_page.dart';
import '../../recovery/state/recovery_providers.dart';

/// The one number the whole app is built around, with a deadline under it.
///
/// Laid out as a Row, not a Stack with a Positioned overlay. The overlay
/// version looked right until the subtitle wrapped to two lines and ran
/// straight through the illustration, which is the failure mode of every
/// hard coded inset: it is invisible until the content is real.
class HeroCard extends ConsumerWidget {
  const HeroCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;
    final RecoverySummary? summary = ref.watch(prescanProvider).value;

    return GCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(GSpace.lg - 1, GSpace.lg, 0, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'RECOVERABLE NOW',
                        style: GType.overline.copyWith(color: t.dim),
                      ),
                      const SizedBox(height: GSpace.sm),
                      Text(
                        summary == null
                            ? '  '
                            : GFormat.count(summary.totalItems),
                        style: GType.monoDisplay.copyWith(color: t.text),
                      ),
                      const SizedBox(height: GSpace.xs),
                      Text(
                        _subtitle(summary),
                        style: GType.monoSmall.copyWith(
                          color: summary == null ? t.dim : t.success,
                        ),
                      ),
                    ],
                  ),
                ),
                // Fixed width, so the art can never encroach on the text no
                // matter how the numbers wrap.
                SizedBox(
                  width: 124,
                  child: GArtSlot(
                    painter: BinRisePainter(tokens: t),
                    height: 124,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              GSpace.lg - 1,
              GSpace.md,
              GSpace.lg - 1,
              GSpace.lg - 1,
            ),
            child: Column(
              children: <Widget>[
                if (summary != null && summary.partial) ...<Widget>[
                  Row(
                    children: <Widget>[
                      GBadge.partial('Floor, not a total'),
                      const SizedBox(width: GSpace.sm),
                      Expanded(
                        child: Text(
                          'Counted without file access',
                          style: GType.micro.copyWith(color: t.dim),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: GSpace.md),
                ],
                GButton(
                  label: 'Review and restore',
                  onPressed: summary == null || summary.totalItems == 0
                      ? null
                      : () => Navigator.of(context).push(
                            CategoryPage.route(title: 'Everything'),
                          ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _subtitle(RecoverySummary? summary) {
    if (summary == null) return 'Checking your device';
    if (summary.totalItems == 0) {
      // Not a failure and not an empty state to apologise for. On a phone with
      // nothing in the trash this is the correct, good answer.
      return 'Nothing waiting.\nYour trash is clear.';
    }
    final String size = GFormat.bytes(summary.totalBytes);
    if (summary.expiringSoonItems > 0) {
      return '$size\n${summary.expiringSoonItems} expire within 48 hours';
    }
    // Two lines on purpose. One long line wraps unpredictably next to the art
    // and the break lands mid phrase.
    return '$size\nup to 30 days to act';
  }
}
