import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../bridge/recovery_api.g.dart';
import '../../core/date_groups.dart';
import '../../core/format.dart';
import '../../core/messenger/g_message.dart';
import '../../core/messenger/g_messenger.dart';
import '../../ui/g_app_bar.dart';
import '../../ui/g_bar.dart';
import '../../ui/g_button.dart';
import '../../ui/g_empty_state.dart';
import '../../ui/g_group_header.dart';
import '../../ui/g_sheet.dart';
import '../../ui/g_sort.dart';
import '../../ui/g_view_switch.dart';
import '../review/review_page.dart';
import '../review/state/review_providers.dart';
import '../viewer/media_viewer.dart';
import 'state/recovery_providers.dart';
import 'widgets/item_grid_tile.dart';
import 'widgets/item_row.dart';

/// One source, browsable and restorable.
///
/// Replaces the Phase 3 proving surface, which is deleted with this phase.
class CategoryPage extends ConsumerStatefulWidget {
  const CategoryPage({required this.query, required this.title, super.key});

  final RecoveryQuery query;
  final String title;

  static Route<void> route({
    required String title,
    String? kind,
    List<String> sourceIds = kAllSourceIds,
  }) => MaterialPageRoute<void>(
    builder: (BuildContext context) => CategoryPage(
      title: title,
      query: RecoveryQuery(sourceIds: sourceIds, kind: kind),
    ),
  );

  @override
  ConsumerState<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends ConsumerState<CategoryPage> {
  /// Grid or list.
  ///
  /// Local state, not a preference, and that is a considered choice: the right
  /// view depends on WHAT is being looked at, not on who is looking. Photos
  /// want a grid, documents want names. Persisting it would force the wrong
  /// view on the next category the user opens.

  @override
  void initState() {
    super.initState();
    // A category opened from home has never been scanned, so the native index
    // is empty and the list would be too. `ensure` scans only the sources that
    // have not been walked yet, which is what makes the SECOND category open
    // work: checking whether any scan had run would see the first one's summary
    // and skip.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Cleared on the way IN. Selection is app wide, so one left behind by
      // search or by another category would arm the action bar here over items
      // that are not in this list. Clearing on dispose is the version that
      // crashes: ref is unusable once the element is deactivated.
      ref.read(selectionProvider.notifier).clear();
      ref.read(scanControllerProvider.notifier).ensure(widget.query.sourceIds);
    });
  }

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    final AsyncValue<List<RecoverableItem>> async = ref.watch(
      recoveryItemsProvider(widget.query),
    );
    final ScanProgress? progress = ref.watch(scanProgressProvider).value;
    final Set<String> selected = ref.watch(selectionProvider);
    final AsyncValue<RecoverySummary?> scan = ref.watch(scanControllerProvider);
    final GViewMode mode = ref.watch(gViewModeProvider);
    final GSortMode sort = ref.watch(gSortProvider);

    // WATCHED, not merely invalidated.
    //
    // The whole phone scan runs in a service that outlives this engine, so it
    // reports through a polled provider rather than through scanProgressProvider.
    // Two places started that scan and nothing on this screen listened, so the
    // button looked broken: it really was scanning, and the page had no way to
    // say so.
    final bool deepScanning =
        ref.watch(backgroundScanProvider).value?.running ?? false;

    // The service populates the native index while this page is open, so the
    // list has to be asked again once it stops. Without this the scan finishes
    // into an empty screen.
    ref.listen<AsyncValue<BackgroundScanState?>>(backgroundScanProvider, (
      AsyncValue<BackgroundScanState?>? previous,
      AsyncValue<BackgroundScanState?> next,
    ) {
      final bool was = previous?.value?.running ?? false;
      final bool now = next.value?.running ?? false;
      if (was && !now) ref.invalidate(recoveryItemsProvider);
    });

    final bool busy = scan.isLoading || deepScanning;

    final List<RecoverableItem> items =
        async.value ?? const <RecoverableItem>[];
    final List<String> chosen = items
        .map((RecoverableItem item) => item.itemId)
        .where(selected.contains)
        .toList();

    return Scaffold(
      backgroundColor: t.ink,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: GSpace.gutter),
              child: GAppBar(
                title: widget.title,
                leading: GIconButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.of(context).pop(),
                ),
                // TWO GLYPHS AT MOST, and both act on the screen rather than on
                // how it is laid out. Everything else moved down. The title had
                // roughly 80 dp before this and "Everything" was breaking in
                // the middle of a word.
                actions: <Widget>[
                  // Review is only offered when there is something to review
                  // AND at least one item can actually be drawn. A swipe deck
                  // of grey document glyphs is worse than a list.
                  if (items.any(_reviewable))
                    Padding(
                      padding: const EdgeInsets.only(right: GSpace.sm),
                      child: GIconButton(
                        icon: Icons.swipe_rounded,
                        tone: t.accentText,
                        onTap: () {
                          ref
                              .read(reviewProvider.notifier)
                              .start(items.where(_reviewable).toList());
                          Navigator.of(context).push(ReviewPage.route());
                        },
                      ),
                    ),
                  // Stays in the title row rather than in the controls below,
                  // because the controls only appear once there is a list and
                  // an empty screen is exactly when someone reaches for rescan.
                  GIconButton(
                    icon: Icons.refresh_rounded,
                    onTap: () => ref
                        .read(scanControllerProvider.notifier)
                        .run(widget.query.sourceIds),
                  ),
                ],
                below: items.isEmpty
                    ? null
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _Facts(items: items),
                          const SizedBox(height: GSpace.md),
                          Row(
                            children: <Widget>[
                              // Recovery gets one order storage cannot have:
                              // soonest to be lost. It is the only sort in the
                              // app that can prevent a loss rather than merely
                              // find something.
                              const GSortButton(allowExpiring: true),
                              const Spacer(),
                              const GViewSwitch(),
                            ],
                          ),
                        ],
                      ),
              ),
            ),
            if (busy && (deepScanning || (progress != null && !progress.done)))
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  GSpace.gutter,
                  0,
                  GSpace.gutter,
                  GSpace.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    GBar(
                      // Null is indeterminate, and that is the truthful value
                      // here. The service reports whether it is running; a
                      // fraction invented from nothing would be a progress bar
                      // that lies about how far along it is.
                      fraction: deepScanning
                          ? null
                          : progress!.total > 0
                          ? progress.scanned / progress.total
                          : null,
                      colour: t.accent,
                    ),
                    const SizedBox(height: GSpace.sm),
                    Text(
                      deepScanning
                          ? 'Walking every folder on this phone'
                          // A real entry count. Results are already usable,
                          // which is the one thing the category's dominant app
                          // gets right.
                          : '${GFormat.count(progress!.found)} found in '
                                '${GFormat.count(progress.scanned)} of '
                                '${GFormat.count(progress.total)} entries',
                      style: GType.monoSmall.copyWith(color: t.dim),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: items.isEmpty
                  ? GEmptyState(
                      shape: shapeForKind(widget.query.kind),
                      title: busy ? 'Looking' : 'Nothing deleted here',
                      // ONE sentence. The three reasons an empty grid can
                      // happen used to be a paragraph on this screen; they are
                      // in the sheet now, where someone who wants them can ask.
                      body: deepScanning
                          ? 'Walking folders that counting cannot reach'
                          : scan.isLoading
                          ? 'Working through this source'
                          : 'That is a real answer, not a failed scan.',
                      actionLabel: busy ? null : 'Scan my phone',
                      onAction: busy
                          ? null
                          : () async {
                              await ref
                                  .read(recoveryBridgeProvider)
                                  .startBackgroundScan();
                              ref.invalidate(backgroundScanProvider);
                            },
                      onExplain: () => _explainEmpty(context),
                    )
                  : _Grouped(
                      groups: _grouped(_ordered(items, sort), sort),
                      all: _ordered(items, sort),
                      mode: mode,
                      sort: sort,
                      selected: selected,
                      onOpen: (RecoverableItem item) =>
                          _open(context, items, items.indexOf(item)),
                      onToggle: (String id) =>
                          ref.read(selectionProvider.notifier).toggle(id),
                      onToggleGroup: (List<String> ids) {
                        final SelectionController controller = ref.read(
                          selectionProvider.notifier,
                        );
                        final bool all = ids.every(selected.contains);
                        for (final String id in ids) {
                          final bool has = selected.contains(id);
                          if (all == has) controller.toggle(id);
                        }
                      },
                    ),
            ),
            if (chosen.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  GSpace.gutter,
                  0,
                  GSpace.gutter,
                  GSpace.lg,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: GButton(
                        label: 'Delete ${chosen.length}',
                        icon: Icons.delete_forever_rounded,
                        kind: GButtonKind.danger,
                        onPressed: () => _confirmDelete(chosen),
                      ),
                    ),
                    const SizedBox(width: GSpace.md - 2),
                    Expanded(
                      child: GButton(
                        // Save, not Restore, when the selection is status
                        // media. Restoring something that was never deleted is
                        // nonsense, and the button has to say what it does.
                        label: '${_verb(items, chosen)} ${chosen.length}',
                        icon: Icons.restore_rounded,
                        onPressed: () => _act(chosen, purge: false),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _open(BuildContext context, List<RecoverableItem> items, int index) {
    final List<RecoverableItem> viewable = items.where(_reviewable).toList();
    final int start = viewable.indexOf(items[index]);
    if (start < 0) return;
    // rootNavigator, because the viewer is the one screen that must cover the
    // bottom bar. Everything else belongs inside its tab's stack.
    Navigator.of(
      context,
      rootNavigator: true,
    ).push(MediaViewer.route(items: viewable, index: start));
  }

  /// "Save" when everything selected is status media, "Restore" otherwise.
  static String _verb(List<RecoverableItem> items, List<String> chosen) {
    final Set<String> ids = chosen.toSet();
    final Iterable<RecoverableItem> picked = items.where(
      (RecoverableItem item) => ids.contains(item.itemId),
    );
    if (picked.isEmpty) return 'Restore';
    return picked.every((RecoverableItem item) => item.role == 'status')
        ? 'Save'
        : 'Restore';
  }

  /// Only things with a preview. Audio and documents belong in the list, where
  /// a name and a size are the whole story, not in a deck built around looking
  /// at a picture.
  static bool _reviewable(RecoverableItem item) =>
      item.kind == 'image' || item.kind == 'video';

  /// Why the grid is empty, and the one thing that can change the answer.
  ///
  /// The action is the same call the empty state's own button makes. Two
  /// buttons on one screen that both promise a scan must run the same scan.
  void _explainEmpty(BuildContext context) {
    showGSheet(
      context: context,
      title: 'Why this is empty',
      action: GSheetAction(
        label: 'Run a full scan',
        detail: 'Walks folders that counting cannot reach. Takes a few minutes.',
        onTap: () async {
          await ref.read(recoveryBridgeProvider).startBackgroundScan();
          ref.invalidate(backgroundScanProvider);
        },
      ),
      footnote: 'IF THAT FINDS NOTHING',
      children: const <Widget>[
        GSheetPoint(text: 'Nothing of this kind was deleted recently.'),
        GSheetPoint(
          text: 'Or it was deleted outside a bin, by a cleaner app or a file '
              'manager, and nothing kept a copy.',
        ),
      ],
    );
  }

  /// SORTED IN DART, unlike storage, and the difference is worth knowing.
  ///
  /// Storage sends the order to native because its query is capped at 400 rows
  /// out of a library of thousands, so ordering afterwards would sort the page
  /// rather than the phone. Recovery items are already fully in memory: the scan
  /// index holds every find and the provider returns all of them, so ordering
  /// here sorts everything there is.
  ///
  /// If the per source cap ever starts biting on a phone with an enormous trash,
  /// this becomes wrong in exactly the way the storage version would have been,
  /// and it moves native.
  static List<RecoverableItem> _ordered(
    List<RecoverableItem> items,
    GSortMode sort,
  ) {
    final List<RecoverableItem> out = List<RecoverableItem>.of(items);
    switch (sort) {
      case GSortMode.newest:
        out.sort(
          (RecoverableItem a, RecoverableItem b) =>
              (b.dateDeletedMillis ?? 0).compareTo(a.dateDeletedMillis ?? 0),
        );
      case GSortMode.oldest:
        out.sort(
          (RecoverableItem a, RecoverableItem b) =>
              (a.dateDeletedMillis ?? 0).compareTo(b.dateDeletedMillis ?? 0),
        );
      case GSortMode.largest:
        out.sort(
          (RecoverableItem a, RecoverableItem b) =>
              b.sizeBytes.compareTo(a.sizeBytes),
        );
      case GSortMode.smallest:
        out.sort(
          (RecoverableItem a, RecoverableItem b) =>
              a.sizeBytes.compareTo(b.sizeBytes),
        );
      case GSortMode.name:
        out.sort(
          (RecoverableItem a, RecoverableItem b) =>
              a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      case GSortMode.expiring:
        // No expiry sorts LAST, not first. A null is not urgent, and treating
        // it as zero days would put every thumbnail cache entry above the photo
        // that really does vanish on Thursday.
        out.sort((RecoverableItem a, RecoverableItem b) {
          final int left = a.expiresInDays ?? 1 << 30;
          final int right = b.expiresInDays ?? 1 << 30;
          return left.compareTo(right);
        });
    }
    return out;
  }

  /// Days always, ordered by date or by size depending on the sort.
  static List<DateGroup<RecoverableItem>> _grouped(
    List<RecoverableItem> items,
    GSortMode sort,
  ) {
    final List<DateGroup<RecoverableItem>> groups =
        groupByDate<RecoverableItem>(
          items,
          dateOf: (RecoverableItem item) => item.dateDeletedMillis,
          sizeOf: (RecoverableItem item) => item.sizeBytes,
          prefix: 'Deleted',
        );

    // Under a size sort the days are ranked by their largest file rather than
    // by date. Same rule as the storage grid, so the two pages behave alike.
    if (!sort.ranksGroups) return groups;
    return rankGroupsBySize<RecoverableItem>(
      groups,
      smallestFirst: sort == GSortMode.smallest,
    );
  }

  /// The one irreversible action in the app, and until now the cheapest.
  ///
  /// Restoring a file can be undone by deleting it again. Purging empties the
  /// trash, and the only copy the user had is gone for good. It had one tap and
  /// no question, which made it easier to destroy files than to recover them.
  Future<void> _confirmDelete(List<String> itemIds) async {
    final GTokens t = context.g;
    final bool? go = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: t.panel,
        shape: RoundedRectangleBorder(borderRadius: GRadius.all(GRadius.card)),
        title: Text(
          'Delete ${GFormat.count(itemIds.length)} permanently',
          style: GType.title.copyWith(color: t.text),
        ),
        content: Text(
          // States the consequence, not the mechanism. "Are you sure" asks a
          // question the user cannot answer without knowing what happens next.
          'These leave the trash for good. This app cannot bring them back '
          'afterwards, and neither can anything else.',
          style: GType.bodySmall.copyWith(color: t.muted),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Keep', style: GType.label.copyWith(color: t.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Delete', style: GType.label.copyWith(color: t.danger)),
          ),
        ],
      ),
    );

    if (go != true || !mounted) return;
    await _act(itemIds, purge: true);
  }

  Future<void> _act(List<String> itemIds, {required bool purge}) async {
    final List<RestoreOutcome> outcomes = purge
        ? await ref.read(recoveryBridgeProvider).purge(itemIds)
        : await ref.read(recoveryBridgeProvider).restore(itemIds);
    if (!mounted) return;

    final int ok = outcomes
        .where((RestoreOutcome outcome) => outcome.status == 'restored')
        .length;
    RestoreOutcome? problem;
    for (final RestoreOutcome outcome in outcomes) {
      if (outcome.status != 'restored') {
        problem = outcome;
        break;
      }
    }

    // The first non-success is reported verbatim. The statuses were designed to
    // be different because the user's next action differs, and collapsing them
    // into "some items failed" throws that away.
    GMessenger.show(
      context,
      problem == null
          ? GMessage.success(purge ? '$ok deleted' : '$ok restored')
          : GMessage.warning('$ok done. ${problem.detail}'),
    );

    ref.read(selectionProvider.notifier).clear();

    // forget() BEFORE the invalidations, and it is not optional.
    //
    // The controller still lists these sources as scanned, so `ensure` would
    // decline to walk them again and the next open would show a list built
    // before the restore happened.
    //
    // It takes no argument and clears ALL sources, which is deliberate on its
    // part: a restore moves files between sources, so forgetting only the one
    // being viewed would leave the others holding rows that have moved.
    ref.read(scanControllerProvider.notifier).forget();
    ref.invalidate(recoveryItemsProvider);
    ref.invalidate(prescanProvider);
  }
}

/// WHAT IS ACTUALLY IN HERE, above the grid.
///
/// The header was a title and the word "found" beside a number. Everything else
/// a person wants before they start tapping was somewhere else or nowhere: how
/// much space this is, how far back it goes, and how much of it is about to
/// expire.
///
/// Derived from the list on screen, never from the summary. The summary counts
/// what a scan found; this list is what survived the query and the four hundred
/// item cap, and a header that disagrees with the grid under it is worse than no
/// header at all.
/// THE NUMBERS, AS A SENTENCE RATHER THAN THREE COLUMNS.
///
/// ─── THE THIRD COLUMN WAS DOING THE TILE'S JOB ───────────────────────────────
///
/// It showed expiring, else preview only, else the span: three unrelated facts
/// sharing one slot behind a precedence, two of them amber. On the screen this
/// replaces, "400 preview only" sat in exactly the position and colour that
/// "12 expiring soon" would have taken, meaning something entirely different.
/// A person could not tell whether the amber number was good news or bad.
///
/// Prose has no fixed number of slots, so nothing has to lose. The deadline and
/// the preview count can both be present, in the order they matter, and each
/// one says what it means for the person rather than naming a category.
class _Facts extends StatelessWidget {
  const _Facts({required this.items});

  final List<RecoverableItem> items;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    int recoverable = 0;
    int expiring = 0;
    int preview = 0;
    int? oldest;
    int? newest;

    for (final RecoverableItem item in items) {
      final int? days = item.expiresInDays;
      if (days != null && days <= 3) expiring++;

      // COUNTED SEPARATELY, and the headline only adds up the first kind. A
      // preview's size is the size of a thumbnail, so folding it into a figure
      // labelled "can be recovered" would be counting bytes that no restore
      // will ever produce. Small in practice and wrong in principle.
      if (item.fidelity == 'preview') {
        preview++;
      } else {
        recoverable += item.sizeBytes;
      }

      final int? at = item.dateDeletedMillis;
      if (at == null || at <= 0) continue;
      if (oldest == null || at < oldest) oldest = at;
      if (newest == null || at > newest) newest = at;
    }

    // A phone whose finds are all previews would otherwise open on 0 B under
    // the words "can be recovered", which is true, useless, and reads as a
    // broken screen. The count is the honest headline in that case.
    final bool anyBytes = recoverable > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: <Widget>[
            Text(
              anyBytes
                  ? GFormat.bytes(recoverable)
                  : GFormat.count(items.length),
              style: GType.monoNumber.copyWith(color: t.text, fontSize: 26),
            ),
            const SizedBox(width: GSpace.sm + 1),
            Expanded(
              child: Text(
                anyBytes
                    ? 'can be recovered, from '
                          '${GFormat.count(items.length)} items'
                    : items.length == 1
                    ? 'item found'
                    : 'items found',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GType.bodySmall.copyWith(color: t.muted),
              ),
            ),
          ],
        ),

        // Amber, and the only amber on the screen. It is the one fact here that
        // is about to stop being true.
        if (expiring > 0)
          Padding(
            padding: const EdgeInsets.only(top: GSpace.xs + 1),
            child: Text(
              expiring == 1
                  ? 'One leaves the trash within three days.'
                  : '${GFormat.count(expiring)} leave the trash within three '
                        'days.',
              style: GType.micro.copyWith(color: t.warning, fontSize: 12.5),
            ),
          ),

        // Muted, because it is permanent. Four hundred files that will never be
        // anything more than a thumbnail is a fact about this phone, not a
        // warning, and colouring it as one taught people to ignore the colour.
        if (preview > 0)
          Padding(
            padding: const EdgeInsets.only(top: GSpace.xs + 1),
            child: Text(
              '${GFormat.count(preview)} of those are previews only, so only '
              'the thumbnail comes back.',
              style: GType.micro.copyWith(color: t.muted, fontSize: 12.5),
            ),
          ),

        // Only when there is nothing more pressing to say. How far back a list
        // reaches is interesting; it is never urgent.
        if (expiring == 0 && preview == 0 && oldest != null && newest != null)
          Padding(
            padding: const EdgeInsets.only(top: GSpace.xs + 1),
            child: Text(
              'Reaching back ${_span(oldest, newest)}.',
              style: GType.micro.copyWith(color: t.muted, fontSize: 12.5),
            ),
          ),
      ],
    );
  }

  /// How far back this list reaches, in the coarsest unit that still says
  /// something. "43 days" is a fact; "6 weeks" is the same fact a person can
  /// picture.
  static String _span(int oldest, int newest) {
    final int days = DateTime.fromMillisecondsSinceEpoch(
      newest,
    ).difference(DateTime.fromMillisecondsSinceEpoch(oldest)).inDays;
    if (days <= 1) return 'to today';
    if (days < 14) return '$days days';
    if (days < 60) return '${(days / 7).round()} weeks';
    return '${(days / 30).round()} months';
  }
}

/// The grid, cut into days.
///
/// A CustomScrollView rather than a ListView of sections, because a pinned
/// sliver header is the only thing that survives being scrolled past. Successive
/// pinned headers push each other out, which is what makes a long grid readable
/// and what a header built as an ordinary list item can never do.
///
/// One code path serves both view modes. List mode groups identically, because a
/// documents category is unreadable as squares but is not thereby exempt from
/// needing to know which day it is looking at.
class _Grouped extends StatelessWidget {
  const _Grouped({
    required this.groups,
    required this.all,
    required this.mode,
    required this.sort,
    required this.selected,
    required this.onOpen,
    required this.onToggle,
    required this.onToggleGroup,
  });

  final List<DateGroup<RecoverableItem>> groups;

  /// The flat list, for the viewer. A deck that stopped at the end of a day
  /// would strand the user mid swipe for a reason they cannot see.
  final List<RecoverableItem> all;

  final GViewMode mode;
  final GSortMode sort;
  final Set<String> selected;
  final void Function(RecoverableItem) onOpen;
  final void Function(String) onToggle;

  /// Takes a whole day, or gives it back. Adds when any are missing, clears
  /// only when all of them were already picked, which is what a person means by
  /// tapping it twice.
  final void Function(List<String>) onToggleGroup;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    final bool selecting = selected.isNotEmpty;

    return CustomScrollView(
      slivers: <Widget>[
        for (final DateGroup<RecoverableItem> group in groups) ...<Widget>[
          SliverPersistentHeader(
            pinned: true,
            delegate: GGroupHeader(
              label: group.label,
              meta:
                  '${GFormat.count(group.count)}  ·  '
                  '${GFormat.bytes(group.bytes)}',
              tokens: t,
              muted: !group.dated,
              // Only once something is selected. Offering a select all before
              // the user has expressed any intent puts a destructive shortcut on
              // a browsing screen.
              selected: selecting
                  ? group.items.every(
                      (RecoverableItem item) => selected.contains(item.itemId),
                    )
                  : null,
              onToggleAll: selecting
                  ? () => onToggleGroup(
                      group.items
                          .map((RecoverableItem item) => item.itemId)
                          .toList(),
                    )
                  : null,
            ),
          ),
          if (mode == GViewMode.grid)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: GSpace.gutter),
              sliver: SliverGrid(
                // A fixed EXTENT, not a fixed column count. Three columns look
                // right at 360 dp and absurd on a foldable, and this keeps the
                // tile size stable across both.
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 128,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                ),
                delegate: SliverChildBuilderDelegate((
                  BuildContext context,
                  int index,
                ) {
                  final RecoverableItem item = group.items[index];
                  return ItemGridTile(
                    item: item,
                    selected: selected.contains(item.itemId),
                    selecting: selecting,
                    // Tap views, long press selects, and once anything is
                    // selected tap selects too. Standard gallery behaviour,
                    // and it is what stops the most common action on a photo
                    // grid, looking at a photo, from being unreachable.
                    onTap: () =>
                        selecting ? onToggle(item.itemId) : onOpen(item),
                    onLongPress: () => onToggle(item.itemId),
                  );
                }, childCount: group.items.length),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: GSpace.gutter),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((
                  BuildContext context,
                  int index,
                ) {
                  final RecoverableItem item = group.items[index];
                  return ItemRow(
                    item: item,
                    selected: selected.contains(item.itemId),
                    detailed: mode == GViewMode.details,
                    onTap: () =>
                        selecting ? onToggle(item.itemId) : onOpen(item),
                    onLongPress: () => onToggle(item.itemId),
                  );
                }, childCount: group.items.length),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: GSpace.md)),
        ],
        // Clears the action bar, which floats over the last row.
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }
}
