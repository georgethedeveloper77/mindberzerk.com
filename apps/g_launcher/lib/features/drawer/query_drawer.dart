import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/components/anchored_menu.dart';
import '../../engine/effective_theme.dart';
import '../../platform/launcher_api.g.dart';
import '../../data/usage/usage_repository.dart';
import '../home/workspaces/workspace_controller.dart';
import '../palette/palette_controller.dart';
import 'app_icon.dart';
import 'drawer_actions.dart';
import 'drawer_items.dart';
import 'package:g_launcher/i18n/i18n.dart';

/// Pop's launcher: a line you type into.
///
/// ─── THE SIXTH, AND THE ONLY ONE THAT IS NOT A SURFACE ──────────────────────
///
/// The five before it arrange apps: a rail beside a list, three columns, two
/// tiers, a paged card, a column with a strip. This one does not arrange
/// anything, because it assumes you already know what you want and the job is
/// to get out of the way while you say it.
///
/// That is why the field is at the TOP and open on arrival rather than waiting
/// to be tapped. Every other drawer here opens showing apps and offers a search
/// field as an alternative route; this opens showing nothing and the field is
/// the only route. A grid underneath would contradict the whole idea.
///
/// ─── AND IT SHOWS SOMETHING BEFORE YOU TYPE ─────────────────────────────────
///
/// Not apps: the ones you use most. An empty panel under a cursor is correct
/// and unhelpful, and Pop's own launcher fills that space with recent items.
/// `frequentAppsProvider` already computes this for Kickoff's Frequent tab, so
/// the ranking is the same ranking rather than a second opinion.
///
/// ─── AND THE MATCHING IS THE PALETTE'S, NOT A NEW ONE ───────────────────────
///
/// [paletteQueryProvider] and [paletteResultsProvider] drive this, which is
/// what `tiling_launcher` already does for rofi and dmenu. That buys the whole
/// contract for nothing: the same `fuzzy.dart` DP, hidden apps already excluded,
/// and frecency breaking ties because `Fuzzy.rank` is stable over a usage-sorted
/// list.
///
/// Writing a second matcher here would have been the obvious move and the wrong
/// one. Two rankers means typing `ph` gives one answer in the palette and
/// another in this launcher, and neither is wrong enough to notice.
///
/// ─── THE NUMBERS ON THE RIGHT ARE HONEST, NOT DECORATION ────────────────────
///
/// A desktop launcher lets you press 2 to run the second result. A phone has no
/// number row in view while a soft keyboard is up, so a numeral rendered as a
/// keyboard hint would be a lie about a key that is not there. They are drawn
/// as ORDINALS instead, which is what they actually are on this device: the
/// second result, tappable like the first.
class QueryDrawer extends ConsumerStatefulWidget {
  const QueryDrawer({super.key, required this.theme});

  final EffectiveTheme theme;

  @override
  ConsumerState<QueryDrawer> createState() => _QueryDrawerState();
}

class _QueryDrawerState extends ConsumerState<QueryDrawer> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  /// How many results the line shows.
  ///
  /// Pop's shows eight. More than that and the list stops being something you
  /// scan and becomes something you scroll, which is the grid this drawer
  /// exists to replace.
  static const _limit = 8;

  @override
  void initState() {
    super.initState();
    // OPEN ON ARRIVAL. The field is the only way through this drawer, so
    // landing on it with the keyboard down would mean every launch starts with
    // a tap that has no alternative. Post-frame because the route is still
    // animating in and a focus request mid-transition is dropped.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final query = ref.watch(paletteQueryProvider);
    final items = ref.watch(drawerItemsProvider(theme));

    final apps = <AppEntry>[
      for (final i in items)
        if (i is AppDrawerItem) i.entry,
    ];

    final List<AppEntry> results;
    if (query.trim().isEmpty) {
      // The frequent run, through the same provider Kickoff's tab uses, so the
      // two cannot disagree about what "most used" means.
      final byKey = {for (final a in apps) a.componentKey: a};
      results = [
        for (final k in ref.watch(frequentAppsProvider))
          if (byKey[k] != null) byKey[k]!,
      ].take(_limit).toList();
    } else {
      results = [
        for (final r in ref.watch(paletteResultsProvider(theme)))
          r.item,
      ].take(_limit).toList();
    }

    final palette = theme.palette;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => closeApps(ref),
            child: const SizedBox.expand(),
          ),
        ),
        Positioned(
          left: 14,
          right: 14,
          // NEAR THE TOP, not centred and not at the foot. Pop's drops from the
          // top edge, and on a phone it is also the only position that keeps
          // the results visible above a soft keyboard.
          top: MediaQuery.viewPaddingOf(context).top + 30,
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: palette.bgBottom
                    .withValues(alpha: 0.985 * theme.drawerOpacity),
                borderRadius: BorderRadius.circular(8),
                // The accent, at full strength. This is the one drawer with a
                // coloured border, and it is doing work: a line with no frame
                // on a dark wallpaper has no edges at all.
                border: Border.all(
                  color: palette.accent.withValues(alpha: 0.55),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 34,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Field(
                    theme: theme,
                    controller: _controller,
                    focus: _focus,
                    onChanged: (v) =>
                        ref.read(paletteQueryProvider.notifier).state = v,
                    onSubmit: () {
                      if (results.isEmpty) return;
                      HapticFeedback.lightImpact();
                      launchDrawerApp(ref, results.first);
                    },
                  ),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: palette.onDark.withValues(alpha: 0.10),
                  ),
                  if (results.isEmpty)
                    _Empty(theme: theme, query: query)
                  else
                    for (var i = 0; i < results.length; i++)
                      _Result(
                        theme: theme,
                        entry: results[i],
                        ordinal: i + 1,
                        selected: i == 0,
                      ),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: palette.onDark.withValues(alpha: 0.10),
                  ),
                  _Foot(
                    theme: theme,
                    shown: results.length,
                    total: apps.length,
                    searching: query.trim().isNotEmpty,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The line itself.
class _Field extends StatelessWidget {
  const _Field({
    required this.theme,
    required this.controller,
    required this.focus,
    required this.onChanged,
    required this.onSubmit,
  });

  final EffectiveTheme theme;
  final TextEditingController controller;
  final FocusNode focus;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final palette = theme.palette;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          // The prompt, in MONO and in the accent. A launcher that is a command
          // line should look like one, and this is the cheapest way to say so
          // that survives any wallpaper behind it.
          Text(
            '>',
            style: TextStyle(
              fontFamily: theme.typography.mono,
              fontSize: 13 * theme.textScale,
              fontWeight: FontWeight.w700,
              color: palette.accent,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focus,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.go,
              onChanged: onChanged,
              onSubmitted: (_) => onSubmit(),
              style: TextStyle(
                fontFamily: theme.typography.mono,
                fontSize: 13 * theme.textScale,
                color: palette.onDark,
              ),
              cursorColor: palette.accent,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: context.t('drawer.typeToRun'),
                hintStyle: TextStyle(
                  fontFamily: theme.typography.mono,
                  fontSize: 13 * theme.textScale,
                  color: palette.onDark.withValues(alpha: 0.35),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One ranked result.
class _Result extends ConsumerWidget {
  const _Result({
    required this.theme,
    required this.entry,
    required this.ordinal,
    required this.selected,
  });

  final EffectiveTheme theme;
  final AppEntry entry;
  final int ordinal;

  /// The top hit. Enter runs this one, so it is painted like a selection.
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = theme.palette;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact();
        launchDrawerApp(ref, entry);
      },
      onLongPress: () => showDrawerAppMenu(
        context,
        ref,
        theme,
        entry,
        anchor: AnchoredMenu.anchorOf(context),
      ),
      child: Container(
        color: selected
            ? palette.accent.withValues(alpha: 0.22)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          children: [
            AppIcon(entry: entry, size: 19),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                entry.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: theme.typography.display,
                  fontSize: 11.5 * theme.textScale,
                  color: palette.onDark,
                ),
              ),
            ),
            // AN ORDINAL, not a keyboard hint. See the class doc: a soft
            // keyboard has no number row in view, so "2" as a shortcut would
            // promise a key that is not there. This says which result it is.
            Text(
              '$ordinal',
              style: TextStyle(
                fontFamily: theme.typography.mono,
                fontSize: 9 * theme.textScale,
                color: palette.onDark.withValues(alpha: 0.32),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.theme, required this.query});

  final EffectiveTheme theme;
  final String query;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: Text(
          // Two different silences. Nothing typed and nothing frequent yet is a
          // fresh install; something typed and nothing found is a miss, and
          // telling them apart is the difference between "start typing" and
          // "that is not here".
          query.trim().isEmpty
              ? context.t('drawer.typeToRun')
              : context.t('drawer.noMatches'),
          style: TextStyle(
            fontFamily: theme.typography.mono,
            fontSize: 10.5 * theme.textScale,
            color: theme.palette.onDark.withValues(alpha: 0.35),
          ),
        ),
      ),
    );
  }
}

/// The count and the two keys that exist.
class _Foot extends StatelessWidget {
  const _Foot({
    required this.theme,
    required this.shown,
    required this.total,
    required this.searching,
  });

  final EffectiveTheme theme;
  final int shown;
  final int total;
  final bool searching;

  @override
  Widget build(BuildContext context) {
    // `n of total` while searching, because that is the number that tells you
    // whether to keep typing. Before a query it would read as "8 of 248 apps
    // shown", which is not what the frequent run is.
    final label = searching
        ? context.t('drawer.nOfTotal', {'n': '$shown', 'total': '$total'})
        : context.t('drawer.mostUsed');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: theme.typography.mono,
                fontSize: 8.5 * theme.textScale,
                color: theme.palette.onDark.withValues(alpha: 0.32),
              ),
            ),
          ),
          Text(
            context.t('drawer.enterToRun'),
            style: TextStyle(
              fontFamily: theme.typography.mono,
              fontSize: 8.5 * theme.textScale,
              color: theme.palette.onDark.withValues(alpha: 0.32),
            ),
          ),
        ],
      ),
    );
  }
}
