import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../bridge/recovery_api.g.dart';
import '../../../core/format.dart';
import '../../../ui/g_thumbnail.dart';
import '../state/recovery_providers.dart';

/// A square tile for the grid view.
///
/// Carries far less text than the row: a name and a size do not fit under a
/// 110 px square without becoming unreadable, and the reason to be in grid mode
/// is to recognise a photo by looking at it. Size sits on the image, expiry
/// only when it is urgent.
class ItemGridTile extends ConsumerWidget {
  const ItemGridTile({
    required this.item,
    super.key,
    this.selected = false,
    this.onTap,
    this.onLongPress,
  });

  final RecoverableItem item;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;
    final bool expiring =
        item.expiresInDays != null && item.expiresInDays! <= 2;

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
          Positioned(
            left: 5,
            right: 5,
            bottom: 4,
            child: Row(
              children: <Widget>[
                Text(
                  GFormat.bytes(item.sizeBytes),
                  style: GType.monoSmall.copyWith(
                    color: t.text,
                    fontSize: 9.5,
                    shadows: <Shadow>[
                      Shadow(color: t.scrim, blurRadius: 4),
                    ],
                  ),
                ),
                const Spacer(),
                if (expiring)
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: t.danger,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
          if (item.role == 'status' || item.fidelity == 'preview')
            Positioned(
              left: 5,
              top: 5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: t.scrim,
                  borderRadius: GRadius.all(5),
                ),
                child: Text(
                  item.role == 'status' ? 'STATUS' : 'PRV',
                  style: GType.badge.copyWith(
                    color: item.role == 'status' ? t.chat : t.warning,
                    fontSize: 8,
                  ),
                ),
              ),
            ),
          if (selected)
            DecoratedBox(
              decoration: BoxDecoration(
                color: t.accent.withValues(alpha: 0.24),
                borderRadius: GRadius.all(GRadius.tile),
                border: Border.all(color: t.accent, width: 2),
              ),
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: t.accent,
                      borderRadius: GRadius.all(6),
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      size: 13,
                      color: t.onAccent,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
