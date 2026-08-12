import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/category_colors.dart';
import '../../../app/theme/tokens.dart';
import '../../../bridge/messages_api.g.dart';
import '../../../bridge/recovery_api.g.dart';
import '../../../bridge/recovery_bridge.dart';
import '../../../core/format.dart';
import '../../../ui/art/tile_motifs.dart';
import '../../../ui/g_thumbnail.dart';
import '../../messages/messages_page.dart';
import '../../messages/state/messages_providers.dart';
import '../../recovery/category_page.dart';
import '../../recovery/state/recovery_providers.dart';

/// THE MOSAIC. WHAT HAS BEEN DELETED, SIZED BY HOW MUCH OF IT THERE IS.
///
/// ─── RANK, NOT PROPORTION ────────────────────────────────────────────────────
///
/// Sorted by count, the largest category takes the full width, the next two take
/// half each, and the rest take quarters. Sizing tiles in true proportion
/// collapses on a real phone: photos are eighty percent of almost every library,
/// so one tile would eat the screen and five would become bands too thin to hold
/// a number.
///
/// Rank keeps the ordering honest and the layout legible at every data shape,
/// and the geometry only moves when the ORDER changes, which is rare. A grid
/// that reshuffled itself every time a file was restored would be unreadable
/// for a different reason.
///
/// ─── BY COUNT, BECAUSE BYTES PER KIND DO NOT EXIST ───────────────────────────
///
/// RecoverySummary carries imageCount, videoCount and the rest, and one total
/// byte figure for everything. There is no per kind size to rank on without a
/// second native call, so the tiles show counts and the hero keeps the total.
/// Ranking by count is also closer to what a person is looking for: eight
/// hundred photographs matters more than one large video.
///
/// ─── A TILE SHOWS ITS CONTENTS, OR DRAWS ITS MOTIF ───────────────────────────
///
/// With something in it, thumbnails bleed in from the right under a gradient, so
/// the tile is a window into what is behind it rather than a label for it. With
/// nothing, it draws the category's own motif, which tile_motifs.dart has been
/// able to do since it was written and has never been asked to.
class CategoryGrid extends ConsumerWidget {
  const CategoryGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    context.g;
    final RecoverySummary? summary = ref.watch(prescanProvider).value;
    final MessageCapture? capture = ref.watch(messageCaptureProvider).value;

    final List<_Category> all = <_Category>[
      _Category(
        label: 'Photos',
        // Thumbnail cache entries are images too, and on most devices they are
        // the bulk of what is findable. Counting them here rather than hiding
        // them under Other is what makes this tile agree with the hero.
        count: (summary?.imageCount ?? 0) + (summary?.otherCount ?? 0),
        icon: Icons.photo_outlined,
        motifKey: 'image',
        kind: 'image',
      ),
      _Category(
        label: 'Video',
        count: summary?.videoCount ?? 0,
        icon: Icons.play_circle_outline,
        motifKey: 'video',
        kind: 'video',
      ),
      _Category(
        label: 'Messages',
        // ─── A NUMBER, LIKE EVERY OTHER TILE ────────────────────────────────
        //
        // This said "Archive" where the others say a count. On a quarter tile
        // that word wraps to two lines and breaks the column, which is what the
        // overflow was, and it also made the one tile that could not be ranked
        // the one tile that read differently.
        //
        // Not from the prescan: the archive is its own store, and it is the
        // only category here whose contents were never deleted from a
        // filesystem. It still has a count, and the count is the honest thing
        // to show.
        count: capture?.messageCount ?? 0,
        icon: Icons.forum_outlined,
        motifKey: 'messages',
        messages: true,
      ),
      _Category(
        label: 'Docs',
        count: summary?.documentCount ?? 0,
        icon: Icons.description_outlined,
        motifKey: 'document',
        kind: 'document',
      ),
      _Category(
        label: 'Audio',
        count: summary?.audioCount ?? 0,
        icon: Icons.graphic_eq_rounded,
        motifKey: 'audio',
        kind: 'audio',
      ),
      _Category(
        label: 'Previews',
        count: summary?.otherCount ?? 0,
        icon: Icons.grain_rounded,
        motifKey: 'thumbnails',
        sourceIds: const <String>['thumbnails'],
      ),
    ];

    // Sorted, then handed fixed shapes. A category with nothing keeps its place
    // in the tail rather than disappearing: zero is a real answer and a tile
    // that vanishes teaches people this app cannot recover that kind of file.
    final List<_Category> ranked = List<_Category>.of(all)
      ..sort((_Category a, _Category b) => b.count.compareTo(a.count));

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        const double gap = GSpace.sm;
        final double quarter = (box.maxWidth - gap * 3) / 4;
        final double half = quarter * 2 + gap;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: <Widget>[
            for (int i = 0; i < ranked.length; i++)
              SizedBox(
                width: _widthFor(i, box.maxWidth, half, quarter),
                height: _heightFor(i),
                child: _Tile(
                  category: ranked[i],
                  // Only the two largest shapes get thumbnails. Six decodes on
                  // the launch screen is a cost worth paying; twenty four is
                  // not, and at quarter size a thumbnail is a smear anyway.
                  previews: i < 2 ? 3 : 0,
                  large: i == 0,
                ),
              ),
          ],
        );
      },
    );
  }

  static double _widthFor(int i, double full, double half, double quarter) {
    if (i == 0) return full;
    if (i <= 2) return half;
    return quarter;
  }

  static double _heightFor(int i) {
    if (i == 0) return 148;
    if (i <= 2) return 116;
    return 84;
  }
}

class _Category {
  const _Category({
    required this.label,
    required this.count,
    required this.icon,
    required this.motifKey,
    this.kind,
    this.sourceIds,
    this.messages = false,
  });

  final String label;
  final int count;
  final IconData icon;

  /// The key motifFor understands, and the key categoryTint understands. One
  /// string rather than two, so a tile cannot end up with the wrong hue behind
  /// the right drawing.
  final String motifKey;

  final String? kind;
  final List<String>? sourceIds;
  final bool messages;
}

class _Tile extends ConsumerWidget {
  const _Tile({
    required this.category,
    required this.previews,
    required this.large,
  });

  final _Category category;
  final int previews;
  final bool large;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;
    final Color tint = categoryTint(t, category.motifKey);
    final bool any = category.count > 0;

    return Material(
      color: const Color(0x00000000),
      child: InkWell(
        borderRadius: GRadius.all(GRadius.card),
        onTap: () => _open(context),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: GRadius.all(GRadius.card),
            border: Border.all(
              color: any ? tint.withValues(alpha: 0.30) : t.line,
            ),
            gradient: any
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      tint.withValues(alpha: 0.17),
                      tint.withValues(alpha: 0.03),
                    ],
                  )
                : null,
            color: any ? null : t.panel,
          ),
          child: ClipRRect(
            borderRadius: GRadius.all(GRadius.card),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                if (previews > 0 && any)
                  _Peek(category: category, count: previews, tint: tint)
                else
                  _Motif(motifKey: category.motifKey, tint: any ? tint : t.dim),

                Padding(
                  padding: const EdgeInsets.all(GSpace.md - 1),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(category.icon, size: 17, color: any ? tint : t.dim),
                      const Spacer(),
                      Text(
                        GFormat.count(category.count),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: (large ? GType.monoNumber : GType.monoSmall)
                            .copyWith(
                              color: any ? t.text : t.dim,
                              fontSize: large ? 21 : 15,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        category.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GType.micro.copyWith(color: t.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context) {
    if (category.messages) {
      Navigator.of(context).push(MessagesPage.route());
      return;
    }
    Navigator.of(context).push(
      CategoryPage.route(
        title: category.label,
        kind: category.kind,
        sourceIds: category.sourceIds ?? kAllSourceIds,
      ),
    );
  }
}

/// Real thumbnails, bleeding in from the right under a gradient.
///
/// ─── THE GRADIENT IS THE LOAD BEARING PART ───────────────────────────────────
///
/// Without it a white shirt in a photograph lands under the count and the number
/// becomes unreadable, on exactly the phones that have the most to recover. It
/// runs from the tile's own background so the left third is always flat.
class _Peek extends ConsumerWidget {
  const _Peek({
    required this.category,
    required this.count,
    required this.tint,
  });

  final _Category category;
  final int count;
  final Color tint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;
    final RecoveryBridge bridge = ref.watch(recoveryBridgeProvider);

    // The same family key the category page uses, so this is shared work rather
    // than a second query: opening the tile afterwards is then instant.
    final List<RecoverableItem> items =
        ref
            .watch(
              recoveryItemsProvider(
                RecoveryQuery(
                  sourceIds: category.sourceIds ?? kAllSourceIds,
                  kind: category.kind,
                ),
              ),
            )
            .value ??
        const <RecoverableItem>[];

    if (items.isEmpty) {
      return _Motif(motifKey: category.motifKey, tint: tint);
    }

    final List<RecoverableItem> shown = items.take(count).toList();

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            for (int i = shown.length - 1; i >= 0; i--)
              Expanded(
                flex: i == 0 ? 34 : (i == 1 ? 26 : 18),
                child: Opacity(
                  // Falling off to the right, so the strip reads as a stack
                  // continuing past the edge rather than as three pictures.
                  opacity: i == 0 ? 0.9 : (i == 1 ? 0.6 : 0.35),
                  child: GThumbnail(
                    itemId: shown[i].itemId,
                    bridge: bridge,
                    kind: shown[i].kind,
                    maxPixels: 128,
                    radius: 0,
                  ),
                ),
              ),
            const Spacer(flex: 22),
          ],
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: const <double>[0, 0.34, 0.62, 1],
              colors: <Color>[
                t.panel,
                t.panel,
                t.panel.withValues(alpha: 0.86),
                t.panel.withValues(alpha: 0.30),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The category's own drawing, faint, behind everything.
///
/// tile_motifs.dart has drawn all six of these since it was written, and its own
/// header calls them the thing behind the number. Nothing had ever called it.
class _Motif extends StatelessWidget {
  const _Motif({required this.motifKey, required this.tint});

  final String motifKey;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    // ─── FAINT, AND IT WAS NOT ─────────────────────────────────────────────
    //
    // At a tenth it stopped being a texture and became a picture: on an empty
    // phone the drawing read as the content of the tile rather than as the
    // backdrop to a number, and the zero was the quietest thing on it.
    //
    // A watermark has to lose to its own foreground. Four percent is visible on
    // a dark panel and never competes.
    final TileMotif? motif = motifFor(motifKey, tint.withValues(alpha: 0.04));
    if (motif == null) return const SizedBox.shrink();

    return Padding(
      // Inset from the corner rather than bled off it, so the shape reads as
      // deliberate rather than as a drawing that did not fit.
      padding: const EdgeInsets.all(GSpace.sm),
      child: Align(
        alignment: Alignment.bottomRight,
        child: FractionallySizedBox(
          widthFactor: 0.46,
          heightFactor: 0.62,
          child: CustomPaint(painter: motif),
        ),
      ),
    );
  }
}
