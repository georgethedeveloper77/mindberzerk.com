import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../bridge/recovery_api.g.dart';
import '../../core/format.dart';
import '../../core/messenger/g_message.dart';
import '../../core/messenger/g_messenger.dart';
import '../../ui/g_app_bar.dart';
import '../../ui/g_badge.dart';
import '../../ui/g_bar.dart';
import '../../ui/g_button.dart';
import '../review/review_page.dart';
import '../review/state/review_providers.dart';
import 'state/recovery_providers.dart';
import '../viewer/media_viewer.dart';
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
  }) =>
      MaterialPageRoute<void>(
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
  bool _grid = true;

  @override
  void initState() {
    super.initState();
    // A category opened from home has never been scanned, so the native index
    // is empty and the list would be too. `ensure` scans only the sources that
    // have not been walked yet, which is what makes the SECOND category open
    // work: checking whether any scan had run would see the first one's summary
    // and skip.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(scanControllerProvider.notifier).ensure(widget.query.sourceIds);
    });
  }

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    final AsyncValue<List<RecoverableItem>> async =
        ref.watch(recoveryItemsProvider(widget.query));
    final ScanProgress? progress = ref.watch(scanProgressProvider).value;
    final Set<String> selected = ref.watch(selectionProvider);
    final AsyncValue<RecoverySummary?> scan = ref.watch(scanControllerProvider);

    final List<RecoverableItem> items = async.value ?? const <RecoverableItem>[];
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
                subtitle: items.isEmpty
                    ? null
                    : '${GFormat.count(items.length)} found',
                leading: GIconButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.of(context).pop(),
                ),
                actions: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(right: GSpace.sm),
                    child: GIconButton(
                      icon: _grid
                          ? Icons.view_list_rounded
                          : Icons.grid_view_rounded,
                      onTap: () => setState(() => _grid = !_grid),
                    ),
                  ),
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
                  GIconButton(
                    icon: Icons.refresh_rounded,
                    onTap: () => ref
                        .read(scanControllerProvider.notifier)
                        .run(widget.query.sourceIds),
                  ),
                ],
              ),
            ),
            if (scan.isLoading && progress != null && !progress.done)
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
                      fraction: progress.total > 0
                          ? progress.scanned / progress.total
                          : null,
                      colour: t.accent,
                    ),
                    const SizedBox(height: GSpace.sm),
                    Text(
                      // A real entry count. Results are already usable, which is
                      // the one thing the category's dominant app gets right.
                      '${GFormat.count(progress.found)} found in '
                      '${GFormat.count(progress.scanned)} of '
                      '${GFormat.count(progress.total)} entries',
                      style: GType.monoSmall.copyWith(color: t.dim),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: items.isEmpty
                  ? _Empty(scanning: scan.isLoading)
                  : _grid
                      ? GridView.builder(
                          padding: const EdgeInsets.fromLTRB(
                            GSpace.gutter,
                            0,
                            GSpace.gutter,
                            120,
                          ),
                          // A fixed EXTENT, not a fixed column count. Three
                          // columns look right at 360 dp and absurd on a
                          // foldable, and this keeps the tile size stable
                          // across both.
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 128,
                            crossAxisSpacing: 6,
                            mainAxisSpacing: 6,
                          ),
                          itemCount: items.length,
                          itemBuilder: (BuildContext context, int index) {
                            final RecoverableItem item = items[index];
                            return ItemGridTile(
                              item: item,
                              selected: selected.contains(item.itemId),
                              // Tap views, long press selects, and once
                              // anything is selected tap selects too. Standard
                              // gallery behaviour, and it is what stops the
                              // most common action on a photo grid, looking at
                              // a photo, from being unreachable.
                              onTap: () => selected.isEmpty
                                  ? _open(context, items, index)
                                  : ref
                                      .read(selectionProvider.notifier)
                                      .toggle(item.itemId),
                              onLongPress: () => ref
                                  .read(selectionProvider.notifier)
                                  .toggle(item.itemId),
                            );
                          },
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(
                            GSpace.gutter,
                            0,
                            GSpace.gutter,
                            120,
                          ),
                          itemCount: items.length,
                          itemBuilder: (BuildContext context, int index) {
                            final RecoverableItem item = items[index];
                            return ItemRow(
                              item: item,
                              selected: selected.contains(item.itemId),
                              onTap: () => selected.isEmpty
                                  ? _open(context, items, index)
                                  : ref
                                      .read(selectionProvider.notifier)
                                      .toggle(item.itemId),
                              onLongPress: () => ref
                                  .read(selectionProvider.notifier)
                                  .toggle(item.itemId),
                            );
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
                        kind: GButtonKind.danger,
                        onPressed: () => _act(chosen, purge: true),
                      ),
                    ),
                    const SizedBox(width: GSpace.md - 2),
                    Expanded(
                      child: GButton(
                        // Save, not Restore, when the selection is status
                        // media. Restoring something that was never deleted is
                        // nonsense, and the button has to say what it does.
                        label:
                            '${_verb(items, chosen)} ${chosen.length}',
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

  void _open(
    BuildContext context,
    List<RecoverableItem> items,
    int index,
  ) {
    final List<RecoverableItem> viewable =
        items.where(_reviewable).toList();
    final int start = viewable.indexOf(items[index]);
    if (start < 0) return;
    Navigator.of(context)
        .push(MediaViewer.route(items: viewable, index: start));
  }

  /// "Save" when everything selected is status media, "Restore" otherwise.
  static String _verb(List<RecoverableItem> items, List<String> chosen) {
    final Set<String> ids = chosen.toSet();
    final Iterable<RecoverableItem> picked =
        items.where((RecoverableItem item) => ids.contains(item.itemId));
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
    ref.invalidate(recoveryItemsProvider);
    ref.invalidate(prescanProvider);
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.scanning});

  final bool scanning;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: GSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            GBadge(label: scanning ? 'Scanning' : 'Nothing here'),
            const SizedBox(height: GSpace.md),
            Text(
              scanning
                  ? 'Looking through this source'
                  // Not an apology and not a sad face. On a phone with an empty
                  // trash this is the correct answer, and saying so plainly is
                  // more useful than an illustration.
                  : 'Nothing recoverable in this source. That is a real answer, '
                      'not a failed scan.',
              textAlign: TextAlign.center,
              style: GType.bodySmall.copyWith(color: t.muted),
            ),
          ],
        ),
      ),
    );
  }
}
