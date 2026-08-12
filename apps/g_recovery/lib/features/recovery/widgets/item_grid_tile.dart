import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../bridge/recovery_api.g.dart';
import '../../../core/format.dart';
import '../../../ui/g_thumbnail.dart';
import '../state/recovery_providers.dart';

/// One cell of the grid, and the shape every grid in the app shares.
///
/// Four fixed positions: a stamp top left, a selection ring top right, the size
/// bottom right, and the picture filling the rest. Only the STAMP changes
/// meaning between screens. In recovery it is the deadline; where a find is not
/// full quality it says so instead; in storage there is nothing to stamp.
///
/// Carries far less text than the row, deliberately. A name and a size do not
/// fit under a 110 px square without becoming unreadable, and the reason to be
/// in grid mode is to recognise a photo by looking at it.
class ItemGridTile extends ConsumerWidget {
  const ItemGridTile({
    required this.item,
    super.key,
    this.selected = false,
    this.selecting = false,
    this.onTap,
    this.onLongPress,
  });

  final RecoverableItem item;
  final bool selected;

  /// True when anything at all is selected.
  ///
  /// Every tile then shows an empty ring, not just the chosen ones. Without it
  /// the only way to discover that a second tap adds to the selection is to
  /// guess, and the ring is the affordance that says tapping now picks.
  final bool selecting;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Under three days is the amber case.
  ///
  /// The one moment this app is entitled to raise its voice, and it earns it
  /// because the file genuinely disappears. Everything else on this screen stays
  /// quiet so that this reads as information rather than decoration.
  static const int _urgentDays = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;
    final int? days = item.expiresInDays;
    final bool urgent = days != null && days <= _urgentDays;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          GThumbnail(
            itemId: item.itemId,
            bridge: ref.watch(recoveryBridgeProvider),
            kind: item.kind,
            // 256, not 512. A tile is about 110 logical pixels, so even at 3x
            // this is generous, and a grid of ninety 512 px decodes is four
            // times the bitmap memory for no visible gain.
            maxPixels: 256,
            radius: GRadius.tile,
          ),

          Positioned(left: 5, top: 5, child: _stamp(t, days, urgent)),

          Positioned(
            right: 5,
            bottom: 4,
            child: Text(
              GFormat.bytes(item.sizeBytes),
              style: GType.monoSmall.copyWith(
                color: t.text,
                fontSize: 9.5,
                shadows: <Shadow>[Shadow(color: t.scrim, blurRadius: 4)],
              ),
            ),
          ),

          if (selecting)
            Positioned(
              right: 5,
              top: 5,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: selected ? t.accent : t.scrim,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? t.accent : t.text.withValues(alpha: 0.8),
                    width: 1.5,
                  ),
                ),
                child: selected
                    ? Icon(Icons.check_rounded, size: 12, color: t.onAccent)
                    : null,
              ),
            ),

          if (selected)
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: t.accent.withValues(alpha: 0.24),
                  borderRadius: GRadius.all(GRadius.tile),
                  border: Border.all(color: t.accent, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Precedence, and it is not arbitrary.
  ///
  /// Status first, because a status was never deleted and calling it anything
  /// else is the mistake this whole distinction exists to prevent. Then preview,
  /// because knowing you are getting a thumbnail back matters more than knowing
  /// when it expires. Only then the countdown.
  Widget _stamp(GTokens t, int? days, bool urgent) {
    String label;
    Color tone;
    Color background;

    if (item.role == 'status') {
      label = 'STATUS';
      tone = t.chat;
      background = t.scrim;
    } else if (item.fidelity == 'preview') {
      label = 'PRV';
      tone = t.warning;
      background = t.scrim;
    } else if (days == null) {
      return const SizedBox.shrink();
    } else if (urgent) {
      // Spelled out, because "2d" beside a photo of someone's child is not
      // enough for a person to understand they have two days.
      label = days <= 0 ? 'Today' : '${days}d left';
      tone = t.onAccent;
      background = t.warning;
    } else {
      label = '${days}d';
      tone = t.text;
      background = t.scrim;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: GRadius.all(5),
      ),
      child: Text(label, style: GType.badge.copyWith(color: tone, fontSize: 8)),
    );
  }
}
