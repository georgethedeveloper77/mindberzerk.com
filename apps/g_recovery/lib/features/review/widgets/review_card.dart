import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../../../bridge/recovery_api.g.dart';
import '../../../bridge/recovery_bridge.dart';
import '../../../core/format.dart';
import '../../../ui/g_badge.dart';
import '../../../ui/g_thumbnail.dart';

/// One card in the swipe deck.
///
/// [offset] and [tilt] are driven by the parent so the deck can animate a fling
/// without this widget owning any gesture state. Keeping the card dumb is what
/// lets the card behind it be the same widget at a different scale.
class ReviewCard extends StatelessWidget {
  const ReviewCard({
    required this.item,
    required this.bridge,
    super.key,
    this.offset = Offset.zero,
    this.tilt = 0,
    this.onOpen,
  });

  final RecoverableItem item;
  final RecoveryBridge bridge;
  final Offset offset;
  final double tilt;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    return Transform.translate(
      offset: offset,
      child: Transform.rotate(
        angle: tilt,
        child: GestureDetector(
          // Tap to open a zoom viewer, NOT pinch to zoom in place.
          //
          // A scale gesture and a horizontal drag on the same surface fight each
          // other: every two finger pinch begins as a pan and the deck starts
          // flinging the card away mid zoom. Separating them costs one tap and
          // removes an entire class of misfires.
          onTap: onOpen,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: GRadius.all(GRadius.sheet),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: t.scrim,
                  blurRadius: 40,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: GRadius.all(GRadius.sheet),
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  GThumbnail(
                    itemId: item.itemId,
                    bridge: bridge,
                    kind: item.kind,
                    // 1024 for the card, 512 everywhere else. The card fills the
                    // screen, so 512 is visibly soft on a 1080p panel, and this
                    // is the only place large enough to justify four times the
                    // bytes.
                    maxPixels: 1024,
                    radius: GRadius.sheet,
                  ),
                  if (item.kind == 'video')
                    Center(
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: t.scrim,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: t.text,
                          size: 30,
                        ),
                      ),
                    ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _Meta(item: item),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.item});

  final RecoverableItem item;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 30, 15, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[t.scrim.withValues(alpha: 0), t.scrim],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (item.fidelity == 'preview')
                GBadge.partial('Preview only')
              else
                GBadge.full('Full quality'),
              if (item.expiresInDays != null) ...<Widget>[
                const SizedBox(width: GSpace.sm),
                GBadge(
                  label: item.expiresInDays == 0
                      ? 'Expires today'
                      : '${item.expiresInDays} days left',
                ),
              ],
            ],
          ),
          const SizedBox(height: GSpace.sm + 2),
          Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GType.monoNumber.copyWith(color: t.text),
          ),
          const SizedBox(height: GSpace.xs + 2),
          Text(
            <String>[
              GFormat.bytes(item.sizeBytes),
              if (item.width != null && item.height != null)
                '${item.width} x ${item.height}',
              if (item.relativePath != null)
                item.relativePath!.replaceAll(RegExp(r'/$'), ''),
            ].join('  /  '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GType.monoSmall.copyWith(color: t.muted),
          ),
        ],
      ),
    );
  }
}

/// The BIN or KEEP stamp that fades in as the card is dragged.
class ReviewStamp extends StatelessWidget {
  const ReviewStamp({
    required this.label,
    required this.colour,
    required this.opacity,
    required this.alignLeft,
    super.key,
  });

  final String label;
  final Color colour;
  final double opacity;
  final bool alignLeft;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    return Align(
      alignment: alignLeft ? Alignment.topLeft : Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.rotate(
            angle: alignLeft ? -0.16 : 0.16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: t.scrim,
                borderRadius: GRadius.all(GRadius.tile),
                border: Border.all(color: colour, width: 2),
              ),
              child: Text(
                label,
                style: GType.monoNumber.copyWith(
                  color: colour,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
