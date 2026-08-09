import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../bridge/recovery_api.g.dart';
import '../../../core/format.dart';
import '../../../ui/g_badge.dart';
import '../../../ui/g_card.dart';
import '../../../ui/g_thumbnail.dart';
import '../state/recovery_providers.dart';

/// One file, in a list. Shared by search and by the category view.
class ItemRow extends StatelessWidget {
  const ItemRow({
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

  /// True for anything that was never deleted. Restore is meaningless for these
  /// and the row says so rather than offering an action that would do nothing.
  bool get _isLive => item.sourceId == 'live_files';

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    return Padding(
      padding: const EdgeInsets.only(bottom: GSpace.sm),
      child: GCard(
        onTap: onTap,
        onLongPress: onLongPress,
        borderColour: selected ? t.accent : null,
        padding: const EdgeInsets.symmetric(
          horizontal: GSpace.md,
          vertical: GSpace.sm + 3,
        ),
        child: Row(
          children: <Widget>[
            _Thumb(item: item),
            const SizedBox(width: GSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GType.body.copyWith(
                      color: t.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _facts(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GType.monoSmall.copyWith(color: t.dim),
                  ),
                ],
              ),
            ),
            const SizedBox(width: GSpace.sm),
            _stamp(),
          ],
        ),
      ),
    );
  }

  String _facts() {
    final List<String> parts = <String>[
      if (item.origin != null) item.origin!,
      if (item.relativePath != null)
        item.relativePath!.replaceAll(RegExp(r'/$'), ''),
      GFormat.bytes(item.sizeBytes),
      if (item.expiresInDays != null)
        item.expiresInDays == 0
            ? 'expires today'
            : '${item.expiresInDays} days left',
    ];
    return parts.join(' / ');
  }

  Widget _stamp() {
    if (_isLive) return GBadge(label: 'On device');
    // Status first, because it changes what the ACTION means, not just what
    // quality to expect. A status was never deleted; it is on a 24 hour timer.
    if (item.role == 'status') return GBadge.partial('Status');
    if (item.fidelity == 'preview') return GBadge.partial('Preview');
    return GBadge.full('Restore');
  }
}

/// A real preview at list size.
///
/// 128 px, not 512. A row is 38 logical pixels, so even on a 3x screen 128 is
/// more than enough, and the difference is what keeps a list of three hundred
/// items from decoding sixteen times more bitmap than it can show. GThumbnail
/// falls back to a kind glyph for anything with no preview.
class _Thumb extends ConsumerWidget {
  const _Thumb({required this.item});

  final RecoverableItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: 38,
      height: 38,
      child: GThumbnail(
        itemId: item.itemId,
        bridge: ref.watch(recoveryBridgeProvider),
        kind: item.kind,
        maxPixels: 128,
        radius: GRadius.glyph,
      ),
    );
  }
}
