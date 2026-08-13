import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../bridge/recovery_api.g.dart';
import '../../../ui/g_thumbnail.dart';
import '../state/recovery_providers.dart';

/// One cell of the grid, and the shape every grid in the app shares.
///
/// ─── TWO AXES, TWO CHANNELS ──────────────────────────────────────────────────
///
/// There used to be one stamp with a precedence: role, then fidelity, then
/// expiry. Its own comment defended putting fidelity ahead of the countdown,
/// and that defence assumed the two compete. They do not. A preview that
/// expires in two days is both, and under the old rule it showed PRV and the
/// deadline never appeared. A status that was preview only showed STATUS and
/// hid the rest. The one moment this app says it is entitled to raise its voice
/// was being silenced by a three letter abbreviation.
///
/// So the facts are separated by kind rather than ranked:
///
///   FIDELITY is a property of the picture, so it is drawn on the picture. A
///   preview only file sits inset in a mat, because that is literally what it
///   is: a thumbnail in a frame rather than the file. It reads at 110 dp with
///   no words at all, which is what PRV was failing to do.
///
///   TIME keeps the badge, alone, so the badge always means one thing.
///
///   ROLE is a small glyph, bottom left, because where a file came from is
///   context and not a warning.
///
/// ─── AND THE SIZE IS GONE ────────────────────────────────────────────────────
///
/// Twelve size labels a screen is texture, not information, and it was fighting
/// the badge on a tile that is mostly photograph. It moves to the row, where
/// there is room for it and where a person is actually comparing.
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

  /// Past this the countdown is not news.
  ///
  /// Android keeps a trashed file for thirty days, so every item has a number
  /// and stamping all of them would put a badge on every tile in the grid. A
  /// month away is not a fact anybody is acting on today.
  static const int _worthStamping = 30;

  /// The mat, in logical pixels.
  ///
  /// Four, not two. Two reads as a rendering seam; four reads as a frame, which
  /// is the entire point of the treatment.
  static const double _mat = 4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;
    final int? days = item.expiresInDays;
    final bool urgent = days != null && days <= _urgentDays;
    final bool preview = item.fidelity == 'preview';
    final String? stamp = _stamp(days, urgent);

    // NOT DESATURATED, and that was a real decision. Draining the colour out of
    // a preview would mark it more strongly and would work against the only
    // reason to be in grid mode, which is recognising a photograph by looking
    // at it. The frame says enough.
    final Widget picture = GThumbnail(
      itemId: item.itemId,
      bridge: ref.watch(recoveryBridgeProvider),
      kind: item.kind,
      // 256, not 512. A tile is about 110 logical pixels, so even at 3x
      // this is generous, and a grid of ninety 512 px decodes is four
      // times the bitmap memory for no visible gain.
      maxPixels: 256,
      radius: preview ? 6 : GRadius.tile,
    );

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (preview)
            Container(
              padding: const EdgeInsets.all(_mat),
              decoration: BoxDecoration(
                color: t.panelAlt,
                borderRadius: GRadius.all(GRadius.tile),
                border: Border.all(color: t.line),
              ),
              child: picture,
            )
          else
            picture,

          if (preview)
            Positioned(
              right: 5,
              bottom: 5,
              child: Container(
                width: 16,
                height: 16,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: t.scrim,
                  borderRadius: GRadius.all(5),
                ),
                child: Icon(Icons.image_outlined, size: 10, color: t.muted),
              ),
            ),

          if (stamp != null)
            Positioned(
              left: 5,
              top: 5,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: urgent ? t.warning : t.scrim,
                  borderRadius: GRadius.all(5),
                ),
                child: Text(
                  stamp,
                  style: GType.badge.copyWith(
                    color: urgent ? t.onAccent : t.text,
                    // 9.5, not 8. Eight points of letterspaced uppercase on a
                    // photograph is below the point where anyone reads it, and
                    // this line is the one that prevents a loss.
                    fontSize: 9.5,
                  ),
                ),
              ),
            ),

          // Where it came from, as a glyph. A status was never deleted by
          // anyone, which is the distinction this carries, and it no longer
          // costs the tile its deadline to say so.
          if (item.role == 'status')
            Positioned(
              left: 5,
              bottom: 5,
              child: Container(
                width: 17,
                height: 17,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: t.scrim,
                  borderRadius: GRadius.all(5),
                ),
                child: Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 10,
                  color: t.chat,
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

  /// The deadline, in words, or null when there is nothing to say.
  ///
  /// Spelled out rather than abbreviated. "2d" beside a photo of someone's
  /// child is not enough for a person to understand they have two days, and
  /// "26d" was shorthand for a fact nobody was going to act on this week
  /// anyway.
  String? _stamp(int? days, bool urgent) {
    if (days == null || days > _worthStamping) return null;
    if (days <= 0) return 'Today';
    if (urgent) return days == 1 ? '1 day left' : '$days days left';
    return '$days days';
  }
}
