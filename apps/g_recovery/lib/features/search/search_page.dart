import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../bridge/recovery_api.g.dart';
import '../../core/format.dart';
import '../../core/messenger/g_message.dart';
import '../../core/messenger/g_messenger.dart';
import '../../ui/g_badge.dart';
import '../../ui/g_button.dart';
import '../../ui/g_card.dart';
import '../../ui/g_chip.dart';
import '../../ui/g_stat.dart';
import '../recovery/state/recovery_providers.dart';
import '../recovery/widgets/item_row.dart';
import '../viewer/media_viewer.dart';
import 'state/search_providers.dart';
import '../../core/i18n/g_strings.dart';

/// Unified search across deleted and present files.
///
/// One field, one list, two sections. The user who cannot remember whether they
/// deleted the file does not have to pick a tab before they can look for it,
/// which is the actual state most people are in when they open a recovery app.
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  static Route<void> route() => MaterialPageRoute<void>(
    builder: (BuildContext context) => const SearchPage(),
  );

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller.text = ref.read(searchQueryProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focus.requestFocus();
      // Cleared on the way IN, not on the way out.
      //
      // Selection is app wide, so a leftover from a category page would arm a
      // restore bar here over items that are not in this list. Clearing on
      // dispose looked like the same fix and was not: ref is unusable once the
      // element is deactivated, and no amount of deferring the write helps
      // because the read happens first. Every page that uses the selection
      // clearing it as it opens makes a stale one impossible to observe.
      ref.read(selectionProvider.notifier).clear();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// 220 ms.
  ///
  /// Long enough that a normal typing speed produces one query per word rather
  /// than one per letter, short enough that it still feels like it is keeping
  /// up. Without it every keystroke starts a MediaStore query on the platform
  /// thread and the field stutters on a budget device.
  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () {
      ref.read(searchQueryProvider.notifier).set(value);
      ref.read(recentSearchesProvider.notifier).remember(value);
    });
  }

  /// Opens the viewer on a list, positioned at the row that was tapped.
  ///
  /// Only things with a preview go into the deck. A document has nothing to
  /// look at, so tapping one does nothing rather than opening a page of grey.
  void _open(List<RecoverableItem> list, int index) {
    final List<RecoverableItem> viewable = list.where(_viewable).toList();
    final int start = viewable.indexOf(list[index]);
    if (start < 0) return;
    // rootNavigator, because the viewer is the one screen that must cover the
    // bottom bar. Everything else belongs inside its tab's stack.
    Navigator.of(
      context,
      rootNavigator: true,
    ).push(MediaViewer.route(items: viewable, index: start));
  }

  static bool _viewable(RecoverableItem item) =>
      item.kind == 'image' || item.kind == 'video';

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

    // The first failure is reported verbatim. The statuses differ because the
    // user's next action differs, and collapsing them into "some items failed"
    // throws that away.
    GMessenger.show(
      context,
      problem == null
          ? GMessage.success(purge ? '$ok deleted' : '$ok restored')
          : GMessage.warning('$ok done. ${problem.detail}'),
    );

    ref.read(selectionProvider.notifier).clear();
    ref.invalidate(searchResultsProvider);
    ref.invalidate(prescanProvider);
  }

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    final String query = ref.watch(searchQueryProvider);
    final AsyncValue<List<RecoverableItem>> async = ref.watch(
      searchResultsProvider,
    );
    final SearchGroups groups = ref.watch(searchGroupsProvider);
    final List<String> recent = ref.watch(recentSearchesProvider);
    final Set<String> selected = ref.watch(selectionProvider);

    // Only deleted results can be acted on. Native resolves a restore through
    // the scan index, and a live file is deliberately never registered there,
    // so asking would come back notFound. Restoring something that was never
    // deleted is nonsense anyway.
    final List<String> chosen = groups.deleted
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
              padding: const EdgeInsets.fromLTRB(
                GSpace.gutter,
                GSpace.sm,
                GSpace.gutter,
                GSpace.md,
              ),
              child: Row(
                children: <Widget>[
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.only(right: GSpace.md),
                      child: Icon(
                        Icons.arrow_back_rounded,
                        color: t.muted,
                        size: 20,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: t.panel,
                        borderRadius: GRadius.all(GRadius.button + 2),
                        border: Border.all(color: t.accent),
                      ),
                      child: Row(
                        children: <Widget>[
                          Text(
                            '/',
                            style: GType.monoNumber.copyWith(
                              color: t.accentText,
                            ),
                          ),
                          const SizedBox(width: GSpace.md - 2),
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              focusNode: _focus,
                              onChanged: _onChanged,
                              textInputAction: TextInputAction.search,
                              cursorColor: t.accent,
                              style: GType.body.copyWith(color: t.text),
                              decoration: InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                hintText: 'Name, app, or file type',
                                hintStyle: GType.body.copyWith(color: t.dim),
                              ),
                            ),
                          ),
                          if (query.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _controller.clear();
                                ref.read(searchQueryProvider.notifier).clear();
                              },
                              child: Icon(
                                Icons.close_rounded,
                                size: 17,
                                color: t.dim,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (chosen.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  GSpace.gutter,
                  0,
                  GSpace.gutter,
                  GSpace.md,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: GButton(
                        label: 'Delete ${chosen.length}',
                        icon: Icons.delete_forever_rounded,
                        kind: GButtonKind.danger,
                        onPressed: () => _act(chosen, purge: true),
                      ),
                    ),
                    const SizedBox(width: GSpace.md - 2),
                    Expanded(
                      child: GButton(
                        // Save, not Restore, when everything picked is status
                        // media. The file was never deleted, so restoring it is
                        // a word that describes nothing.
                        label:
                            '${_verb(groups.deleted, chosen)} '
                            '${chosen.length}',
                        icon: Icons.restore_rounded,
                        onPressed: () => _act(chosen, purge: false),
                      ),
                    ),
                  ],
                ),
              ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  GSpace.gutter,
                  0,
                  GSpace.gutter,
                  GSpace.xl,
                ),
                children: <Widget>[
                  if (query.trim().length < 2) ...<Widget>[
                    if (recent.isNotEmpty) ...<Widget>[
                      GOverline('Recent'),
                      const SizedBox(height: GSpace.sm + 1),
                      Wrap(
                        spacing: GSpace.sm,
                        runSpacing: GSpace.sm,
                        children: <Widget>[
                          for (final String term in recent)
                            GChip(
                              label: term,
                              onTap: () {
                                _controller.text = term;
                                ref
                                    .read(searchQueryProvider.notifier)
                                    .set(term);
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: GSpace.lg),
                    ],
                    Text(
                      context.s(
                        'Type at least two letters. Searches your deleted files '
                        'and the ones still on the device at the same time.',
                      ),
                      style: GType.bodySmall.copyWith(color: t.dim),
                    ),
                  ] else if (async.isLoading && groups.isEmpty) ...<Widget>[
                    Text(
                      context.s('Searching'),
                      style: GType.bodySmall.copyWith(color: t.muted),
                    ),
                  ] else if (groups.isEmpty) ...<Widget>[
                    GCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            context.s('Nothing matched'),
                            style: GType.heading.copyWith(color: t.text),
                          ),
                          const SizedBox(height: GSpace.sm - 2),
                          Text(
                            // The honest empty state. Saying why beats an
                            // illustration of a magnifying glass.
                            context.s(
                              'Only files still on the device and files sitting '
                              'in a trash folder can be searched. Anything erased '
                              'outside a trash folder leaves no name behind.',
                            ),
                            style: GType.bodySmall.copyWith(color: t.muted),
                          ),
                        ],
                      ),
                    ),
                  ] else ...<Widget>[
                    if (groups.deleted.isNotEmpty) ...<Widget>[
                      GOverline(
                        'Deleted, restorable',
                        trailing: GStat(
                          label: '',
                          value: GFormat.count(groups.deleted.length),
                          align: CrossAxisAlignment.end,
                        ),
                      ),
                      const SizedBox(height: GSpace.sm + 1),
                      for (int i = 0; i < groups.deleted.length; i++)
                        ItemRow(
                          item: groups.deleted[i],
                          selected: selected.contains(groups.deleted[i].itemId),
                          // Tap views, long press selects, and once anything is
                          // selected tap selects too. Same gesture grammar as
                          // the category grid, because a user who learned it
                          // there should not have to learn it again here.
                          onTap: () => selected.isEmpty
                              ? _open(groups.deleted, i)
                              : ref
                                    .read(selectionProvider.notifier)
                                    .toggle(groups.deleted[i].itemId),
                          onLongPress: () => ref
                              .read(selectionProvider.notifier)
                              .toggle(groups.deleted[i].itemId),
                        ),
                      const SizedBox(height: GSpace.lg),
                    ],
                    if (groups.live.isNotEmpty) ...<Widget>[
                      GOverline(
                        'Still on the device',
                        trailing: GBadge(label: context.s('Not deleted')),
                      ),
                      const SizedBox(height: GSpace.sm + 1),
                      // No selection on live files. The row opens and that is
                      // all it can honestly offer.
                      for (int i = 0; i < groups.live.length; i++)
                        ItemRow(
                          item: groups.live[i],
                          onTap: () => _open(groups.live, i),
                        ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
