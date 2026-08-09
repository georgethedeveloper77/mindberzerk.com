import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../bridge/recovery_api.g.dart';
import '../../../core/format.dart';
import '../../../core/messenger/g_message.dart';
import '../../../core/messenger/g_messenger.dart';
import '../../../ui/g_bubble.dart';
import '../../recovery/category_page.dart';
import '../../recovery/state/recovery_providers.dart';

/// Six tiles covering every entry point.
///
/// Each one is a KIND, searched across every source. A tile mapped onto a single
/// source shows nothing whenever the findings happen to live somewhere else,
/// which on a phone with an empty trash and a full thumbnail cache is always.
/// Where an item came from is a fidelity stamp on the row, not a route.
class CategoryGrid extends ConsumerWidget {
  const CategoryGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;
    final RecoverySummary? summary = ref.watch(prescanProvider).value;

    String? caption(int? count, String noun) {
      if (summary == null || count == null || count == 0) return null;
      return '${GFormat.count(count)} $noun';
    }

    final List<_Tile> tiles = <_Tile>[
      _Tile(
        label: 'Photos',
        icon: Icons.photo_outlined,
        tint: t.photo,
        kind: 'image',
        // Thumbnail cache entries are images too, and on most devices they are
        // the bulk of what is findable. Counting them here rather than hiding
        // them under Other is what makes this tile agree with the hero.
        caption: caption(
          (summary?.imageCount ?? 0) + (summary?.otherCount ?? 0),
          'found',
        ),
      ),
      _Tile(
        label: 'Video',
        icon: Icons.play_circle_outline,
        tint: t.video,
        kind: 'video',
        caption: caption(summary?.videoCount, 'found'),
      ),
      _Tile(
        label: 'Audio',
        icon: Icons.graphic_eq_rounded,
        tint: t.audio,
        kind: 'audio',
        caption: caption(summary?.audioCount, 'found'),
      ),
      _Tile(
        label: 'Docs',
        icon: Icons.description_outlined,
        tint: t.docs,
        kind: 'document',
        caption: caption(summary?.documentCount, 'found'),
      ),
      _Tile(
        label: 'Previews',
        icon: Icons.grain_rounded,
        tint: t.apps,
        sourceIds: const <String>['thumbnails'],
        caption: caption(summary?.otherCount, 'cached'),
      ),
      const _Tile(
        label: 'Messages',
        icon: Icons.forum_outlined,
        tint: null,
      ),
    ];

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: GSpace.sm + 1,
      mainAxisSpacing: GSpace.sm + 1,
      childAspectRatio: 0.86,
      children: <Widget>[
        for (final _Tile tile in tiles)
          GBubble(
            label: tile.label,
            icon: tile.icon,
            tint: tile.tint ?? t.chat,
            caption: tile.caption,
            onTap: () {
              if (tile.kind == null && tile.sourceIds == null) {
                GMessenger.show(
                  context,
                  GMessage('Deleted messages arrive in version 1.1'),
                );
                return;
              }
              Navigator.of(context).push(
                CategoryPage.route(
                  title: tile.label,
                  kind: tile.kind,
                  sourceIds: tile.sourceIds ?? kAllSourceIds,
                ),
              );
            },
          ),
      ],
    );
  }
}

class _Tile {
  const _Tile({
    required this.label,
    required this.icon,
    required this.tint,
    this.kind,
    this.sourceIds,
    this.caption,
  });

  final String label;
  final IconData icon;
  final Color? tint;
  final String? kind;
  final List<String>? sourceIds;
  final String? caption;
}
