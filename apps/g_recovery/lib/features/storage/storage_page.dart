import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g_recovery/ui/g_stat.dart';

import '../../app/theme/category_colors.dart';
import '../../app/theme/tokens.dart';
import '../../bridge/apps_api.g.dart';
import '../../bridge/apps_bridge.dart';
import '../../bridge/compare_bridge.dart';
import '../../bridge/compress_api.g.dart';
import '../../bridge/compress_bridge.dart';
import '../../bridge/recovery_api.g.dart';
import '../../bridge/server_api.g.dart';
import '../../bridge/server_bridge.dart';
import '../../bridge/storage_api.g.dart';
import '../../core/format.dart';
import '../../ui/art/escape_art.dart';
import '../../ui/g_app_bar.dart';
import '../../ui/g_card.dart';
import '../../ui/g_empty_state.dart';
import '../../ui/g_sheet.dart';
import '../apps/apps_page.dart';
import '../recovery/state/recovery_providers.dart';
import '../server/server_page.dart';
import 'browse/browse_page.dart';
import 'compare/blur_review_page.dart';
import 'compare/compare_review_page.dart';
import 'compress/compress_page.dart';
import 'model/storage_view.dart';
import 'state/storage_breakdown.dart';
import 'state/storage_files.dart';
import 'state/storage_providers.dart';
import 'storage_files_page.dart';
import 'widgets/g_bar_chart.dart';
import 'widgets/reclaim_grid.dart';
import 'widgets/storage_ledger.dart';
import 'widgets/treemap.dart';

class StoragePage extends ConsumerWidget {
  const StoragePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;
    final StorageOverview? overview = ref.watch(storageOverviewProvider).value;
    final StorageBreakdown? breakdown = ref.watch(storageBreakdownProvider);
    final DateTime? fills = ref.watch(fillForecastProvider);
    final RecoveryAccess? access = ref.watch(recoveryAccessProvider).value;
    final ServerConfig? server = ref.watch(serverConfigProvider).value;

    final bool blind = access != null && !access.allFilesAccess;

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

        // ─── THE NUMBER, AND THE BAR ────────────────────────────────────────
        //
        // The filter chips used to sit here. Filters belong on a list someone
        // is reading, not on a summary: they pushed the answer below the fold
        // and duplicated the sort control every detail page now has.
        if (overview != null) _Headline(overview: overview),

        if (overview == null)
          GCard(
            child: Text(
              'Reading storage',
              style: GType.bodySmall.copyWith(color: t.muted),
            ),
          )
        else if (blind)
          // The tab cannot work at all without the grant, so it says that once
          // and stops rather than drawing six sections of almost nothing.
          Padding(
            padding: const EdgeInsets.only(top: GSpace.lg),
            child: GEmptyState(
              shape: EscapeShape.photos,
              title: 'Only what this app made is visible',
              body:
                  'File access is off, so everything else on the phone is '
                  'there and cannot be examined.',
              actionLabel: 'Turn on file access',
              onAction: () async {
                await ref.read(recoveryBridgeProvider).requestAllFilesAccess();
                ref.invalidate(recoveryAccessProvider);
              },
            ),
          )
        else ...<Widget>[
          // ─── WHERE IT WENT ────────────────────────────────────────────────
          if (breakdown != null) ...<Widget>[
            const SizedBox(height: GSpace.md - 1),
            GOverline('Where it went'),
            const SizedBox(height: GSpace.sm + 1),
            GCard(
              child: StorageLedger(
                breakdown: breakdown,
                onOpen: (StorageBucket bucket) => Navigator.of(context).push(
                  StorageFilesPage.route(
                    StorageScope(title: bucket.label, kind: bucket.id),
                  ),
                ),
              ),
            ),
          ],

          if (fills != null) ...<Widget>[
            const SizedBox(height: GSpace.md - 1),
            _Forecast(at: fills),
          ],

          // ─── WORTH A LOOK ─────────────────────────────────────────────────
          const SizedBox(height: GSpace.lg),
          GOverline('Worth a look'),
          const SizedBox(height: GSpace.sm + 1),
          ReclaimGrid(
            actions: ref.watch(reclaimActionsProvider),
            onOpen: (ReclaimAction action) =>
                _openReclaim(context, ref, action),
          ),
          const SizedBox(height: GSpace.sm),
          Text(
            'One scan answers duplicates, similar photos and blurred. It reads '
            'every photo once.',
            style: GType.micro.copyWith(color: t.dim),
          ),

          // ─── MAKE THINGS SMALLER ──────────────────────────────────────────
          //
          // Directly under Worth a look, and that is a change from where this
          // sat. It used to be below By year, six sections down, which put the
          // only other way of getting space back nowhere near the first one.
          //
          // Not above Where it went, which was the earlier proposal: the
          // breakdown is genuinely the second thing a person wants after the
          // headline, and an action ahead of the explanation reads as a pitch.
          const SizedBox(height: GSpace.lg),
          GOverline('Make things smaller'),
          const SizedBox(height: GSpace.sm + 1),
          const _CompressLine(),

          // ─── WHERE IT LIVES ───────────────────────────────────────────────
          const SizedBox(height: GSpace.lg),
          _FoldersCard(overview: overview),

          // ─── BY YEAR ──────────────────────────────────────────────────────
          if (overview.ages.isNotEmpty) ...<Widget>[
            const SizedBox(height: GSpace.md - 1),
            GOverline('By year'),
            const SizedBox(height: GSpace.sm + 1),
            GCard(
              child: GBarChart(
                data: <GBarDatum>[
                  // Oldest first, so it reads left to right like every other
                  // timeline in this app.
                  for (final AgeBucket bucket
                      in List<AgeBucket>.of(overview.ages)..sort(
                        (AgeBucket a, AgeBucket b) => a.year.compareTo(b.year),
                      ))
                    GBarDatum(
                      label: "'${bucket.year % 100}",
                      value: bucket.totalBytes.toDouble(),
                      colour: t.accent,
                    ),
                ],
              ),
            ),
          ],

          // ─── VOLUMES ──────────────────────────────────────────────────────
          const _Volumes(),

          // ─── APPS ─────────────────────────────────────────────────────────
          //
          // The largest number on this screen finally broken down. It sits
          // under the gap it explains rather than at the top, because a person
          // opens Storage about their own files first.
          const SizedBox(height: GSpace.lg),
          GOverline('Apps'),
          const SizedBox(height: GSpace.sm + 1),
          const _AppsLine(),

          // ─── ELSEWHERE ────────────────────────────────────────────────────
          //
          // The machine you back up to is part of "where your storage is", and
          // it was reachable only from More.
          if (server != null) ...<Widget>[
            const SizedBox(height: GSpace.lg),
            GOverline('Elsewhere'),
            const SizedBox(height: GSpace.sm + 1),
            _Line(
              hue: t.chat,
              icon: Icons.dns_outlined,
              title: server.label,
              detail: 'Files copied to a machine you own',
              onTap: () => Navigator.of(context).push(ServerPage.route()),
            ),
          ],

          // ─── BROWSE ───────────────────────────────────────────────────────
          const SizedBox(height: GSpace.lg),
          GOverline('Browse'),
          const SizedBox(height: GSpace.sm + 1),
          _Line(
            hue: t.photo,
            icon: Icons.folder_open_rounded,
            title: 'All folders',
            detail: 'Every folder on this phone, explained',
            onTap: () => Navigator.of(context).push(BrowsePage.route()),
          ),

          const SizedBox(height: GSpace.lg),
          GestureDetector(
            onTap: () => _explainGap(context),
            behavior: HitTestBehavior.opaque,
            child: Text(
              // One line and a tap, rather than the paragraph that was here.
              'Why apps and system cannot be broken down',
              textAlign: TextAlign.center,
              style: GType.micro.copyWith(color: t.accentText),
            ),
          ),
        ],
      ],
    );
  }

  void _openReclaim(BuildContext context, WidgetRef ref, ReclaimAction action) {
    // The three comparison cards share one scan. Tapping any of them before it
    // has run starts it, rather than each launching its own walk over the same
    // photos.
    const Set<String> compared = <String>{'duplicates', 'similar', 'blurred'};

    if (compared.contains(action.id)) {
      if (!action.ready) {
        ref.read(compareProvider.notifier).run();
        return;
      }
      Navigator.of(context).push(
        action.id == 'blurred'
            ? BlurReviewPage.route()
            : CompareReviewPage.route(
                action.id == 'duplicates' ? 'exact' : 'similar',
              ),
      );
      return;
    }
    if (action.id == 'large') {
      Navigator.of(context).push(StorageFilesPage.route(kLargeFilesScope));
      return;
    }
    Navigator.of(context).push(StorageFilesPage.route(kStaleScope));
  }

  void _explainGap(BuildContext context) {
    final GTokens t = context.g;
    showGSheet(
      context: context,
      title: 'Apps and system',
      children: <Widget>[
        Text(
          'These figures come from the Android media index, which covers your '
          'own files and nothing else.',
          style: GType.bodySmall.copyWith(color: t.muted),
        ),
        const GSheetHeading('What is in the gap'),
        const GSheetPoint(text: 'The operating system itself.'),
        const GSheetPoint(
          text: 'Every app, and the private data each one keeps.',
        ),
        const GSheetPoint(
          text:
              'None of it can be listed by any app, including this one, so it '
              'is shown as a single figure rather than guessed at.',
        ),
      ],
    );
  }
}

/// One number, one bar.
///
/// Replaces the volume card. The bar carries the same colours as the ledger
/// below it, so the two read as one statement rather than two.
class _Headline extends StatelessWidget {
  const _Headline({required this.overview});

  final StorageOverview overview;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    final int total = overview.volume.totalBytes;
    final int free = overview.volume.freeBytes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text(
              GFormat.bytes(overview.volume.usedBytes),
              style: GType.display.copyWith(color: t.text, fontSize: 34),
            ),
            const SizedBox(width: GSpace.sm),
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text(
                'of ${GFormat.bytes(total)}',
                style: GType.monoSmall.copyWith(color: t.muted),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text(
                '${GFormat.bytes(free)} free',
                style: GType.monoSmall.copyWith(color: t.success),
              ),
            ),
          ],
        ),
        const SizedBox(height: GSpace.md - 2),
        ClipRRect(
          borderRadius: GRadius.all(6),
          child: SizedBox(
            height: 10,
            child: Row(
              children: <Widget>[
                for (final KindUsage kind in overview.kinds)
                  if (kind.totalBytes > 0)
                    Expanded(
                      flex: (kind.totalBytes ~/ 1048576).clamp(1, 1 << 30),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 2),
                        child: ColoredBox(color: categoryTint(t, kind.kind)),
                      ),
                    ),
                // The unaccounted gap, in dim. It is most of the bar on a real
                // phone and it is not a category, so it takes the one colour
                // that means nothing.
                Expanded(
                  // indexedBytes, not accountedBytes. The schema calls it
                  // what it is: the total MediaStore actually indexed.
                  flex:
                      ((overview.volume.usedBytes - overview.indexedBytes) ~/
                              1048576)
                          .clamp(1, 1 << 30),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 2),
                    child: ColoredBox(color: t.dim),
                  ),
                ),
                Expanded(
                  flex: (free ~/ 1048576).clamp(1, 1 << 30),
                  child: ColoredBox(color: t.panelAlt),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A single tappable line, for the sections that are one row.
/// THE COMPRESS ENTRY, IN THE TWO STATES IT HAS.
///
/// ─── IT NEVER SCANS TO FILL ITSELF IN ────────────────────────────────────────
///
/// Same rule as the attention strip on Home. Measuring a saving means actually
/// re-encoding, which is minutes of work and hundreds of megabytes of decoding,
/// and a storage tab that started doing that because someone opened it would be
/// unforgivable.
///
/// ─── BUT IT IS NOT EMPTY BEFORE THE SCAN EITHER ──────────────────────────────
///
/// Counting the screenshots and adding up their bytes is one MediaStore query.
/// So the row can say "1,204 screenshots, 8.7 GB" the moment the tab opens,
/// which is a true statement about the phone rather than an invitation with no
/// content. What it will not say is how much of that comes back, because
/// nothing has measured that yet.
class _CompressLine extends ConsumerWidget {
  const _CompressLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;
    final CompressSummary? summary = ref.watch(compressSummaryProvider).value;

    final int shots = summary?.screenshotCount ?? 0;
    final int photos = summary?.photoCount ?? 0;
    final int bytes =
        (summary?.screenshotBytes ?? 0) + (summary?.photoBytes ?? 0);

    // Nothing over the floor at all. Absent rather than a row reading zero,
    // which is the same rule the attention strip follows.
    if (summary != null && shots == 0 && photos == 0) {
      return const SizedBox.shrink();
    }

    return _Line(
      hue: t.photo,
      icon: Icons.compress_rounded,
      title: 'Make files smaller',
      detail: summary == null
          ? 'Same picture, smaller file'
          : '${_parts(shots, photos)} taking ${GFormat.bytes(bytes)}',
      onTap: () => Navigator.of(context).push(CompressPage.route()),
    );
  }

  /// Only the categories that exist, named in plain words.
  ///
  /// A phone with no screenshots should not read "0 screenshots and 3,880
  /// photos". An absent count is an absent phrase, which is the same treatment
  /// nullable stats get everywhere else in this app.
  static String _parts(int shots, int photos) {
    final List<String> parts = <String>[
      if (shots > 0) '${GFormat.count(shots)} screenshots',
      if (photos > 0) '${GFormat.count(photos)} photos',
    ];
    return parts.join(' and ');
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.hue,
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
  });

  final Color hue;
  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    return GCard(
      onTap: onTap,
      child: Row(
        children: <Widget>[
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: hue.withValues(alpha: 0.18),
              borderRadius: GRadius.all(11),
            ),
            child: Icon(icon, size: 17, color: hue),
          ),
          const SizedBox(width: GSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: GType.body.copyWith(color: t.text)),
                Text(detail, style: GType.micro.copyWith(color: t.muted)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, size: 19, color: t.dim),
        ],
      ),
    );
  }
}

/// When the disk runs out, if nothing changes.
///
/// The one number on this screen the OS cannot show, because it needs a history
/// and Settings keeps none. Four samples over four days before it says anything,
/// and it refuses to project past two years, since "full in 2031" reads as a
/// joke rather than a warning.
class _Forecast extends StatelessWidget {
  const _Forecast({required this.at});

  final DateTime at;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    final int days = at.difference(DateTime.now()).inDays;
    final bool soon = days <= 30;

    return GCard(
      child: Row(
        children: <Widget>[
          Icon(
            Icons.schedule_rounded,
            size: 19,
            color: soon ? t.warning : t.accentText,
          ),
          const SizedBox(width: GSpace.md),
          Expanded(
            child: Text(
              days <= 0
                  ? 'At this rate, storage is about to run out.'
                  : 'At this rate, storage fills in about '
                        '${GFormat.count(days)} days.',
              style: GType.bodySmall.copyWith(color: t.text),
            ),
          ),
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
            // A page, not the shared filter. Setting the tab's own filter from
            // here changed the screen underneath the user and left it changed
            // when they came back.
            onTap: (FolderUsage folder) => Navigator.of(context).push(
              StorageFilesPage.route(
                StorageScope(title: folder.label, folderPrefix: folder.path),
              ),
            ),
          ),
          const SizedBox(height: GSpace.sm),
          Text(
            'Tap a folder to see only its files',
            style: GType.micro.copyWith(color: t.dim),
          ),
        ],
      ),
    );
  }
}

/// Apps, as one line that knows whether it can answer.
///
/// Three states, and the middle one matters: usage access is off by default and
/// is granted on a settings screen, so the row says what it needs rather than
/// showing a zero.
class _AppsLine extends ConsumerWidget {
  const _AppsLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;
    final AppsState? state = ref.watch(appsStateProvider).value;

    if (state == null) {
      return _Line(
        hue: t.dim,
        icon: Icons.apps_rounded,
        title: 'Apps',
        detail: 'Reading',
        onTap: () {},
      );
    }

    if (!state.usageAccess) {
      return _Line(
        hue: t.audio,
        icon: Icons.apps_rounded,
        title: 'Apps and their caches',
        detail: 'Needs usage access to read sizes',
        onTap: () => Navigator.of(context).push(AppsPage.route()),
      );
    }

    return _Line(
      hue: t.audio,
      icon: Icons.apps_rounded,
      title: '${GFormat.count(state.count)} apps',
      detail:
          '${GFormat.bytes(state.totalBytes)} in total, '
          '${GFormat.bytes(state.cacheBytes)} of it cache',
      onTap: () => Navigator.of(context).push(AppsPage.route()),
    );
  }
}

/// Cards, drives and internal storage.
///
/// ─── HIDDEN ON A PHONE WITH ONE VOLUME ───────────────────────────────────────
///
/// Which is most phones. A section headed VOLUMES containing a single row that
/// repeats the number already at the top of the screen is noise, so it appears
/// only when there is genuinely more than one place for files to be.
class _Volumes extends ConsumerWidget {
  const _Volumes();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<VolumeEntry> volumes =
        ref.watch(volumesProvider).value ?? const <VolumeEntry>[];

    if (volumes.length < 2) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: GSpace.lg),
        GOverline('Volumes'),
        const SizedBox(height: GSpace.sm + 1),
        GCard(
          padding: const EdgeInsets.symmetric(horizontal: GSpace.md),
          child: Column(
            children: <Widget>[
              for (int i = 0; i < volumes.length; i++)
                _VolumeRow(
                  volume: volumes[i],
                  last: i == volumes.length - 1,
                  onTap: volumes[i].path == null
                      ? null
                      : () => Navigator.of(context).push(
                          BrowsePage.route(
                            path: volumes[i].path,
                            title: volumes[i].label,
                          ),
                        ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VolumeRow extends StatelessWidget {
  const _VolumeRow({
    required this.volume,
    required this.last,
    required this.onTap,
  });

  final VolumeEntry volume;
  final bool last;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    final int used = volume.totalBytes - volume.freeBytes;
    final double share = volume.totalBytes <= 0 ? 0 : used / volume.totalBytes;

    return Container(
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: t.line)),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: GSpace.md - 2),
            child: Row(
              children: <Widget>[
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: (volume.removable ? t.docs : t.chat).withValues(
                      alpha: 0.18,
                    ),
                    borderRadius: GRadius.all(11),
                  ),
                  child: Icon(
                    volume.removable
                        ? Icons.sd_card_outlined
                        : Icons.smartphone_rounded,
                    size: 17,
                    color: volume.removable ? t.docs : t.chat,
                  ),
                ),
                const SizedBox(width: GSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        volume.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GType.body.copyWith(color: t.text),
                      ),
                      Text(
                        '${(share * 100).round()}% used',
                        style: GType.micro.copyWith(color: t.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: GSpace.sm),
                Text(
                  '${GFormat.bytes(volume.freeBytes)} free',
                  style: GType.monoSmall.copyWith(color: t.success),
                ),
                if (onTap != null) ...<Widget>[
                  const SizedBox(width: GSpace.xs),
                  Icon(Icons.chevron_right_rounded, size: 18, color: t.dim),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
