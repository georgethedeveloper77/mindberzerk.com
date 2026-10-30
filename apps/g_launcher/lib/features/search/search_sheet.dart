import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g_launcher/i18n/i18n.dart';

import '../../data/prefs/query_learning.dart';
import '../../design/components/anchored_menu.dart';
import '../../engine/effective_theme.dart';
import '../../platform/launcher_api.g.dart';
import '../drawer/app_icon.dart';
import '../drawer/drawer_actions.dart';
import '../drawer/drawer_items.dart';
import '../command/command_rows.dart';
import '../command/command_router.dart';
import '../command/search_settings.dart';
import '../palette/palette_controller.dart';

/// Search, as a sheet from the top edge.
///
/// ─── A ROUTE THAT REPLACED THE SCREEN, FOR A THING THAT SHOULD NOT ──────────
///
/// Seven drawers open search with the same line: a `MaterialPageRoute` to
/// `SearchPage`. That is a whole screen, and it is the wrong shape for what
/// searching actually is here. You are not going somewhere; you are narrowing
/// what is already in front of you, and the wallpaper and the dock going away
/// while you type says otherwise.
///
/// So this is a sheet: opaque enough to read, over a scrim, with everything
/// underneath still there. Tap the scrim, swipe it up, or press back.
///
/// ─── FROM THE TOP, WHICH IS NOT WHERE SHEETS USUALLY COME FROM ──────────────
///
/// A bottom sheet would be under the keyboard the moment it opens, which is
/// where a search field must never be. Dropping from the top edge puts the
/// field above the results and the results above the keyboard, and that is the
/// only arrangement where all three are visible at once on a phone.
///
/// ─── AND IT SHARES THE PALETTE'S RANKING ────────────────────────────────────
///
/// [paletteQueryProvider] and [paletteResultsProvider], which rofi, dmenu, the
/// TUI shell and Pop's query line already use. Same fuzzy match, hidden apps
/// already excluded, ties already broken by frecency. A second ranker here
/// would mean typing `wha` gives one answer in the palette and another in
/// search, and neither wrong enough to notice.
Future<void> showSearchSheet(
  BuildContext context,
  EffectiveTheme theme, {
  String? initialQuery,
}) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      // TRANSPARENT and not opaque, which is the whole difference from the
      // route this replaces: the drawer underneath keeps painting, so the
      // wallpaper, the dock and the bubbles are all still there.
      opaque: false,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      transitionDuration: const Duration(milliseconds: 190),
      reverseTransitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (_, __, ___) =>
          _SearchSheet(theme: theme, initialQuery: initialQuery),
      transitionsBuilder: (_, anim, __, child) {
        final curve = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curve,
          child: SlideTransition(
            // Down from above the edge. A sheet that faded in place would give
            // no sense of where it came from or where a swipe should send it.
            position: Tween(
              begin: const Offset(0, -0.06),
              end: Offset.zero,
            ).animate(curve),
            child: child,
          ),
        );
      },
    ),
  );
}

class _SearchSheet extends ConsumerStatefulWidget {
  const _SearchSheet({required this.theme, this.initialQuery});

  final EffectiveTheme theme;

  /// What a keyboard typed on the bare desktop before this opened.
  final String? initialQuery;

  @override
  ConsumerState<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends ConsumerState<_SearchSheet> {
  final _controller = TextEditingController();
  late final _focus = FocusNode(onKeyEvent: _onKey);

  /// The row the arrow keys picked, or null for the default (the top app,
  /// else the top command). Cleared whenever the query changes, so Enter
  /// always means the best answer to what was just typed.
  int? _picked;
  int _default = 0;

  int get _selected => _picked ?? _default;

  /// Rows on screen in order, rebuilt each frame by build, for the keys.
  List<VoidCallback> _rowActions = const [];

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final n = _rowActions.length;
    if (n == 0) return KeyEventResult.ignored;
    if (e.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() => _picked = (_selected + 1) % n);
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() => _picked = (_selected - 1 + n) % n);
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Enough to fill the space above a keyboard and no more. Past this the sheet
  /// is taller than the gap and the last hits are behind the keys.
  static const _limit = 8;

  @override
  void initState() {
    super.initState();
    // CLEARED on open, not carried. The palette query is shared with rofi and
    // the TUI, so arriving with someone else's half-typed word in the field
    // would be a search you did not start.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final seed = widget.initialQuery ?? '';
      _controller.value = TextEditingValue(
        text: seed,
        selection: TextSelection.collapsed(offset: seed.length),
      );
      ref.read(paletteQueryProvider.notifier).state = seed;
      _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _run(AppEntry entry) {
    HapticFeedback.lightImpact();
    ref
        .read(queryLearningProvider.notifier)
        .record(ref.read(paletteQueryProvider), entry.componentKey);
    // POP FIRST. Launching leaves the app, and a sheet still mounted behind a
    // departing activity is what you come back to. `drawer_actions` and the
    // desktop menu both pop before they act, for the same reason.
    Navigator.of(context).pop();
    launchDrawerApp(ref, entry);
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final palette = theme.palette;
    final query = ref.watch(paletteQueryProvider);

    final results = [
      for (final r in ref.watch(paletteResultsProvider(theme))) r.item,
    ].take(_limit).toList();

    final route = ref.watchRoute(query);
    final rowStyle = CommandRowStyle(
      text: palette.onDark,
      muted: palette.onDark.withValues(alpha: 0.5),
      accent: palette.accent,
      fontFamily: theme.typography.display,
      monoFamily: theme.typography.mono,
      scale: theme.textScale,
    );

    void fill(String v) {
      _controller.value = TextEditingValue(
        text: v,
        selection: TextSelection.collapsed(offset: v.length),
      );
      ref.read(paletteQueryProvider.notifier).state = v;
    }

    Future<void> activate(CommandHit hit) async {
      // Captured before the await, so the pop never reads a context that may
      // have gone away while the URL opened.
      final nav = Navigator.of(context);
      final close = await activateCommandHit(
        context,
        ref,
        hit,
        query: query,
        fillQuery: fill,
      );
      if (close && mounted) nav.pop();
    }

    // Every selectable row in screen order: command answers, then apps.
    final showApps = !(results.isEmpty && route.searchApps);
    _rowActions = [
      for (final hit in route.hits) () => activate(hit),
      if (showApps)
        for (final e in results) () => _run(e),
    ];
    _default = results.isNotEmpty && route.searchApps ? route.hits.length : 0;
    final sel =
        _rowActions.isEmpty ? -1 : _selected.clamp(0, _rowActions.length - 1);

    final cats = CategorySet.forTheme(theme);
    final top = MediaQuery.viewPaddingOf(context).top;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // The scrim is the route's barrier, so a tap anywhere off the sheet
          // dismisses without this widget owning a gesture.
          Positioned(
            left: 8,
            right: 8,
            top: top + 8,
            child: _Dismissible(
              onDismissed: () => Navigator.of(context).pop(),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  decoration: BoxDecoration(
                    color: palette.bgBottom.withValues(alpha: 0.98),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: palette.onDark.withValues(alpha: 0.12),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.55),
                        blurRadius: 40,
                        offset: const Offset(0, 18),
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
                        onChanged: (v) {
                          _picked = null;
                          ref.read(paletteQueryProvider.notifier).state = v;
                        },
                        // Enter: the highlighted row. By default that is the
                        // top app, unless there is none or the query is an
                        // explicit mode, in which case the top command.
                        onSubmit: () {
                          if (sel >= 0) _rowActions[sel]();
                        },
                      ),
                      if (query.trim().isNotEmpty) ...[
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: palette.onDark.withValues(alpha: 0.10),
                        ),
                        for (var h = 0; h < route.hits.length; h++)
                          ColoredBox(
                            color: h == sel
                                ? palette.accent.withValues(alpha: 0.18)
                                : Colors.transparent,
                            child: CommandHitRow(
                              hit: route.hits[h],
                              style: rowStyle,
                              onTap: () => activate(route.hits[h]),
                              onBang: (b) => fill('!${b.key} '),
                            ),
                          ),
                        if (results.isEmpty && route.searchApps) ...[
                          if (route.hits.isEmpty) _Empty(theme: theme),
                          CommandFallbackRows(
                            query: query,
                            style: rowStyle,
                            onOpened: () {
                              if (mounted) Navigator.of(context).pop();
                            },
                          ),
                        ] else
                          for (var i = 0; i < results.length; i++)
                            _Hit(
                              theme: theme,
                              entry: results[i],
                              // THE CATEGORY IT LIVES IN, not a match score.
                              // On a product whose drawer is categories, this
                              // answers the question a flat list leaves open:
                              // where will this be when I come back for it
                              // without typing.
                              //
                              // `nameFor` is one call per app and the same rule
                              // the Library files by, so the label cannot
                              // disagree with the bubble.
                              category: cats.nameFor(results[i]),
                              first: route.hits.length + i == sel,
                              onTap: () => _run(results[i]),
                            ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Swipe the sheet up to dismiss.
///
/// A drag rather than `Dismissible`, which wants a key and a direction and
/// animates the child off its own axis. This only has to notice an upward
/// flick and pop; the route's reverse transition does the moving.
class _Dismissible extends StatelessWidget {
  const _Dismissible({required this.onDismissed, required this.child});

  final VoidCallback onDismissed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onVerticalDragEnd: (d) {
        // Negative is upward. The threshold is a flick, not a nudge: a slow
        // drag while reaching for the field should not close it.
        if ((d.primaryVelocity ?? 0) < -320) onDismissed();
      },
      child: child,
    );
  }
}

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
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      child: Row(
        children: [
          Icon(
            Icons.search,
            size: 17,
            color: palette.onDark.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 10),
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
                fontFamily: theme.typography.display,
                fontSize: 14 * theme.textScale,
                color: palette.onDark,
              ),
              cursorColor: palette.accent,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: context.t('drawer.searchApps'),
                hintStyle: TextStyle(
                  fontFamily: theme.typography.display,
                  fontSize: 14 * theme.textScale,
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

class _Hit extends ConsumerWidget {
  const _Hit({
    required this.theme,
    required this.entry,
    required this.category,
    required this.first,
    required this.onTap,
  });

  final EffectiveTheme theme;
  final AppEntry entry;
  final String? category;

  /// The top hit. Enter runs this one, so it is painted like a selection.
  final bool first;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = theme.palette;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: () => showDrawerAppMenu(
        context,
        ref,
        theme,
        entry,
        anchor: AnchoredMenu.anchorOf(context),
      ),
      child: Container(
        color:
            first ? palette.accent.withValues(alpha: 0.18) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        child: Row(
          children: [
            AppIcon(entry: entry, size: 26),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    entry.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: theme.typography.display,
                      fontSize: 13 * theme.textScale,
                      color: palette.onDark,
                    ),
                  ),
                  if (category != null)
                    Text(
                      context.t('search.inCategory', {'name': category!}),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: theme.typography.display,
                        fontSize: 9.5 * theme.textScale,
                        color: palette.onDark.withValues(alpha: 0.42),
                      ),
                    ),
                ],
              ),
            ),
            if (first)
              Text(
                context.t('drawer.enterToRun'),
                style: TextStyle(
                  fontFamily: theme.typography.mono,
                  fontSize: 8.5 * theme.textScale,
                  color: palette.onDark.withValues(alpha: 0.35),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.theme});

  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Text(
          context.t('drawer.noMatches'),
          style: TextStyle(
            fontFamily: theme.typography.display,
            fontSize: 12 * theme.textScale,
            color: theme.palette.onDark.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}
