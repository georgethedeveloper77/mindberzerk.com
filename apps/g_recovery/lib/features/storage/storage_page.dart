import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/shell.dart';
import '../../app/theme/tokens.dart';
import '../../bridge/storage_api.g.dart';
import '../../core/format.dart';
import '../../core/messenger/g_message.dart';
import '../../core/messenger/g_messenger.dart';
import '../../ui/g_app_bar.dart';
import '../../ui/g_badge.dart';
import '../../ui/g_button.dart';
import '../../ui/g_card.dart';
import '../../ui/g_chip.dart';
import '../../ui/g_ring.dart';
import '../../ui/g_stat.dart';
import 'state/storage_providers.dart';
import 'widgets/age_histogram.dart';
import 'widgets/treemap.dart';

class StoragePage extends ConsumerWidget {
  const StoragePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;
    final StorageOverview? overview = ref.watch(storageOverviewProvider).value;
    final StorageFilter filter = ref.watch(storageFilterProvider);
    final StorageQueryResult? result = ref.watch(storageQueryProvider).value;

    return GPageBody(
      children: <Widget>[
        GAppBar(
          title: 'Storage',
          actions: <Widget>[
            GIconButton(
              icon: Icons.refresh_rounded,
              onTap: () => ref.invalidate(storageOverviewProvider),
            ),
          ],
        ),

        const _Filters(),
        const SizedBox(height: GSpace.md - 1),

        if (result != null) _QueryCard(result: result),
        if (result != null) const SizedBox(height: GSpace.md - 1),

        if (overview == null)
          GCard(
            child: Text(
              'Reading storage',
              style: GType.bodySmall.copyWith(color: t.muted),
            ),
          )
        else ...<Widget>[
          _VolumeCard(overview: overview),
          const SizedBox(height: GSpace.md - 1),
          if (result == null) ...<Widget>[
            _FoldersCard(overview: overview),
            const SizedBox(height: GSpace.md - 1),
            _AgesCard(buckets: overview.ages),
          ],
        ],

        if (filter.isEmpty) ...<Widget>[
          const SizedBox(height: GSpace.lg),
          Text(
            // The honest limit, stated once. Phase 7's Learn section expands on
            // it; here it stops the numbers looking wrong.
            'Counts come from the Android media index, which covers your files '
            'but not app code or private app data. The gap is shown above as '
            'System and apps.',
            textAlign: TextAlign.center,
            style: GType.micro.copyWith(color: t.dim),
          ),
        ],
      ],
    );
  }
}

class _Filters extends ConsumerWidget {
  const _Filters();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final StorageFilter filter = ref.watch(storageFilterProvider);
    final StorageFilterController controller = ref.read(
      storageFilterProvider.notifier,
    );

    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: <Widget>[
          for (final (String kind, String label) in const <(String, String)>[
            ('video', 'Video'),
            ('image', 'Photos'),
            ('audio', 'Audio'),
            ('document', 'Docs'),
          ])
            Padding(
              padding: const EdgeInsets.only(right: GSpace.sm - 2),
              child: GChip(
                label: label,
                selected: filter.kinds.contains(kind),
                onTap: () => controller.toggleKind(kind),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: GSpace.sm - 2),
            child: GChip(
              label: 'Over 100 MB',
              selected: filter.minBytes != null,
              onTap: () => controller.set(
                filter.minBytes == null
                    ? filter.copyWith(minBytes: 100 * 1000 * 1000)
                    : filter.copyWith(clearMinBytes: true),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: GSpace.sm - 2),
            child: GChip(
              label: 'Over 6 months',
              selected: filter.olderThanDays != null,
              onTap: () => controller.set(
                filter.olderThanDays == null
                    ? filter.copyWith(olderThanDays: 182)
                    : filter.copyWith(clearOlderThan: true),
              ),
            ),
          ),
          if (!filter.isEmpty) GChip(label: 'Clear', onTap: controller.clear),
        ],
      ),
    );
  }
}

/// The ring, plus the honest gap.
class _VolumeCard extends ConsumerWidget {
  const _VolumeCard({required this.overview});

  final StorageOverview overview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;
    final VolumeInfo volume = overview.volume;
    final DateTime? forecast = ref.watch(fillForecastProvider);
    if (volume.totalBytes <= 0) return const SizedBox.shrink();

    Color tint(String kind) => switch (kind) {
      'video' => t.video,
      'image' => t.photo,
      'audio' => t.audio,
      'document' => t.docs,
      _ => t.apps,
    };

    // Everything the media index cannot see: the OS, app code, app private
    // data. Shown as its own segment because folding it into a category is how
    // a cleaner app invents "1.2 GB of junk" that it then offers to remove.
    final int unaccounted = (volume.usedBytes - overview.indexedBytes).clamp(
      0,
      volume.usedBytes,
    );

    return GCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              GRing(
                size: 104,
                thickness: 12,
                centreTop: GFormat.percent(
                  volume.usedBytes / volume.totalBytes,
                ),
                centreBottom: 'used',
                segments: <GRingSegment>[
                  for (final KindUsage kind in overview.kinds)
                    GRingSegment(
                      fraction: kind.totalBytes / volume.totalBytes,
                      colour: tint(kind.kind),
                    ),
                  GRingSegment(
                    fraction: unaccounted / volume.totalBytes,
                    colour: t.panelHigh,
                  ),
                ],
              ),
              const SizedBox(width: GSpace.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${GFormat.bytes(volume.freeBytes)} free',
                      style: GType.heading.copyWith(color: t.text),
                    ),
                    Text(
                      'of ${GFormat.bytes(volume.totalBytes)}',
                      style: GType.monoSmall.copyWith(color: t.muted),
                    ),
                    const SizedBox(height: GSpace.md),
                    for (final KindUsage kind in overview.kinds.take(4))
                      _Legend(
                        colour: tint(kind.kind),
                        label: _kindLabel(kind.kind),
                        value: GFormat.bytes(kind.totalBytes),
                      ),
                    _Legend(
                      colour: t.panelHigh,
                      label: 'System and apps',
                      value: GFormat.bytes(unaccounted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // The forecast row is ABSENT until there is real history, rather than
          // showing a guess from two samples an hour apart.
          if (forecast != null) ...<Widget>[
            const GCardDivider(),
            Row(
              children: <Widget>[
                GBadge.partial('Forecast'),
                const SizedBox(width: GSpace.sm),
                Expanded(
                  child: Text(
                    'Full around ${forecast.day}/${forecast.month} at this rate',
                    style: GType.bodySmall.copyWith(color: t.muted),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _kindLabel(String kind) => switch (kind) {
    'image' => 'Photos',
    'video' => 'Video',
    'audio' => 'Audio',
    'document' => 'Documents',
    _ => 'Other files',
  };
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.colour,
    required this.label,
    required this.value,
  });

  final Color colour;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: <Widget>[
          Container(width: 9, height: 9, color: colour),
          const SizedBox(width: GSpace.sm),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GType.bodySmall.copyWith(color: t.muted, fontSize: 12),
            ),
          ),
          Text(value, style: GType.monoSmall.copyWith(color: t.text)),
        ],
      ),
    );
  }
}

class _FoldersCard extends ConsumerWidget {
  const _FoldersCard({required this.overview});

  final StorageOverview overview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;
    if (overview.folders.isEmpty) return const SizedBox.shrink();
    return GCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          GOverline('Where it lives'),
          const SizedBox(height: GSpace.md),
          FolderTreemap(
            folders: overview.folders,
            onTap: (FolderUsage folder) => ref
                .read(storageFilterProvider.notifier)
                .set(
                  ref
                      .read(storageFilterProvider)
                      .copyWith(folderPrefix: folder.path),
                ),
          ),
          const SizedBox(height: GSpace.sm),
          Text(
            'Tap a folder to filter by it',
            style: GType.micro.copyWith(color: t.dim),
          ),
        ],
      ),
    );
  }
}

class _AgesCard extends StatelessWidget {
  const _AgesCard({required this.buckets});

  final List<AgeBucket> buckets;

  @override
  Widget build(BuildContext context) {
    if (buckets.isEmpty) return const SizedBox.shrink();
    return GCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          GOverline('By year'),
          const SizedBox(height: GSpace.md),
          AgeHistogram(buckets: buckets),
        ],
      ),
    );
  }
}

/// The answer to a filter: one big number, a shape, and an action.
class _QueryCard extends ConsumerWidget {
  const _QueryCard({required this.result});

  final StorageQueryResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;

    return GCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                GFormat.bytes(result.matchBytes),
                style: GType.monoDisplay.copyWith(color: t.text),
              ),
              const SizedBox(width: GSpace.sm),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'across ${GFormat.count(result.matchCount)} files',
                  style: GType.monoSmall.copyWith(color: t.muted),
                ),
              ),
            ],
          ),
          if (result.folders.isNotEmpty) ...<Widget>[
            const GCardDivider(),
            GOverline('Where it lives'),
            const SizedBox(height: GSpace.md),
            FolderTreemap(folders: result.folders, height: 130),
          ],
          if (result.ages.isNotEmpty) ...<Widget>[
            const GCardDivider(),
            GOverline('By year'),
            const SizedBox(height: GSpace.md),
            AgeHistogram(buckets: result.ages, height: 46),
          ],
          const SizedBox(height: GSpace.lg),
          Row(
            children: <Widget>[
              Expanded(
                child: GStat(
                  label: 'Shown',
                  value: GFormat.count(result.files.length),
                ),
              ),
              Expanded(
                child: GButton(
                  label: 'Move ${GFormat.count(result.files.length)} to trash',
                  onPressed: result.files.isEmpty
                      ? null
                      : () => _trash(context, ref),
                ),
              ),
            ],
          ),
          const SizedBox(height: GSpace.sm),
          Text(
            // Not delete. The default action is reversible for thirty days and
            // the copy has to say which one it is.
            'Moved files go to the Android trash and can be restored from the '
            'Recover screen for 30 days.',
            style: GType.micro.copyWith(color: t.dim),
          ),
        ],
      ),
    );
  }

  Future<void> _trash(BuildContext context, WidgetRef ref) async {
    final List<String> ids = result.files
        .map((StorageFile file) => file.fileId)
        .toList();
    final List<StorageOutcome> outcomes = await ref
        .read(storageBridgeProvider)
        .remove(ids);
    if (!context.mounted) return;

    final int ok = outcomes
        .where((StorageOutcome outcome) => outcome.status == 'trashed')
        .length;
    StorageOutcome? problem;
    for (final StorageOutcome outcome in outcomes) {
      if (outcome.status != 'trashed') {
        problem = outcome;
        break;
      }
    }

    GMessenger.show(
      context,
      problem == null
          ? GMessage.success('$ok moved to trash')
          : GMessage.warning('$ok moved. ${problem.detail}'),
    );
    ref.invalidate(storageOverviewProvider);
    ref.invalidate(storageQueryProvider);
  }
}
