import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/components/anchored_menu.dart';
import '../../engine/effective_theme.dart';
import '../../platform/launcher_api.g.dart';
import '../drawer/app_icon.dart';
import '../drawer/drawer_actions.dart';
import '../drawer/drawer_items.dart';
import '../palette/palette_controller.dart';
import 'package:g_launcher/i18n/i18n.dart';

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
Future<void> showSearchSheet(BuildContext context, EffectiveTheme theme) {
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
      pageBuilder: (_, __, ___) => _SearchSheet(theme: theme),
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
  const _SearchSheet({required this.theme});

  final EffectiveTheme theme;

  @override
  ConsumerState<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends ConsumerState<_SearchSheet> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

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
      ref.read(paletteQueryProvider.notifier).state = '';
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
                        onChanged: (v) =>
                            ref.read(paletteQueryProvider.notifier).state = v,
                        onSubmit: () {
                          if (results.isNotEmpty) _run(results.first);
                        },
                      ),
                      if (query.trim().isNotEmpty) ...[
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: palette.onDark.withValues(alpha: 0.10),
                        ),
                        if (results.isEmpty)
                          _Empty(theme: theme)
                        else
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
                              first: i == 0,
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
        color: first
            ? palette.accent.withValues(alpha: 0.18)
            : Colors.transparent,
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
