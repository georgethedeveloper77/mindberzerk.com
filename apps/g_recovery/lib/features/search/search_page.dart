import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../bridge/recovery_api.g.dart';
import '../../core/format.dart';
import '../../ui/g_badge.dart';
import '../../ui/g_card.dart';
import '../../ui/g_chip.dart';
import '../../ui/g_stat.dart';
import '../recovery/widgets/item_row.dart';
import 'state/search_providers.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
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

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    final String query = ref.watch(searchQueryProvider);
    final AsyncValue<List<RecoverableItem>> async =
        ref.watch(searchResultsProvider);
    final SearchGroups groups = ref.watch(searchGroupsProvider);
    final List<String> recent = ref.watch(recentSearchesProvider);

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
                                ref.read(searchQueryProvider.notifier).set(term);
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: GSpace.lg),
                    ],
                    Text(
                      'Type at least two letters. Searches your deleted files '
                      'and the ones still on the device at the same time.',
                      style: GType.bodySmall.copyWith(color: t.dim),
                    ),
                  ] else if (async.isLoading && groups.isEmpty) ...<Widget>[
                    Text(
                      'Searching',
                      style: GType.bodySmall.copyWith(color: t.muted),
                    ),
                  ] else if (groups.isEmpty) ...<Widget>[
                    GCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Nothing matched',
                            style: GType.heading.copyWith(color: t.text),
                          ),
                          const SizedBox(height: GSpace.sm - 2),
                          Text(
                            // The honest empty state. Saying why beats an
                            // illustration of a magnifying glass.
                            'Only files still on the device and files sitting '
                            'in a trash folder can be searched. Anything erased '
                            'outside a trash folder leaves no name behind.',
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
                      for (final RecoverableItem item in groups.deleted)
                        ItemRow(item: item),
                      const SizedBox(height: GSpace.lg),
                    ],
                    if (groups.live.isNotEmpty) ...<Widget>[
                      GOverline(
                        'Still on the device',
                        trailing: GBadge(label: 'Not deleted'),
                      ),
                      const SizedBox(height: GSpace.sm + 1),
                      for (final RecoverableItem item in groups.live)
                        ItemRow(item: item),
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
