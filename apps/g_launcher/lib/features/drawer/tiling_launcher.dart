import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/components/anchored_menu.dart';
import '../../engine/effective_theme.dart';
import '../../platform/launcher_api.g.dart';
import '../palette/fuzzy.dart';
import '../palette/palette_controller.dart';
import 'app_icon.dart';
import 'drawer_actions.dart';
import 'drawer_items.dart';
import '../home/workspaces/workspace_controller.dart';

/// The tiling WM's launcher, in two shapes.
///
/// A tiling desktop has no dock and no icon grid: you hit a keybind, something
/// appears, you type two letters, you press enter. That something is the entire
/// app-launching surface, which is why this looks nothing like the GNOME grid or
/// the Kickoff menu even though all three read the same [drawerItemsProvider].
///
/// ─── WHY THERE ARE TWO, AND WHY IT IS NOT A SECOND WIDGET ───────────────────
///
/// Arch and EndeavourOS are both tiling distros, so `shell_drawer.dart` sends
/// both here and both drew the identical centred card. Two paid products whose
/// only difference was the accent colour. That is not a bug in this file; it is
/// the file being asked to describe two desktops with one shape.
///
/// [EffectiveTheme.tilingLauncher] chooses:
///
///  - **rofi**: a centred card with an accent border, icons, a ranked list and
///    a footer hint. Unchanged, and still the default, so no distro moves until
///    its theme.json says so. EndeavourOS's community edition ships rofi in
///    drun mode and its whole look is soft and purple, so this is its shape.
///  - **dmenu**: one line across the top edge. Prompt, input, then the matches
///    running horizontally beside it with the top hit inverted. No icons, no
///    card, no border, no scrim, no footer. Arch's shape, and the most austere
///    thing in the catalogue.
///
/// A branch rather than a second class because everything BEHIND the shape is
/// shared and must stay shared: the matcher, the item list, the empty-query
/// fallback, the submit contract, the long-press menu, the query cleanup on
/// dispose. Two widgets would each own a copy of all of that and the copies
/// would drift, which is exactly what happened to the folder overlay.
///
/// **Ranking is the terminal's, not the drawer's.** Typing runs through
/// [paletteResultsProvider] — the same `fuzzy.dart` DP that backs the TUI shell's
/// command line, with its 18 tests and its match-index highlighting. A tiling
/// launcher and a terminal prompt want identical behaviour ("two letters, top
/// hit, enter"), so they share one matcher rather than growing a second,
/// slightly-different one.
///
/// With an EMPTY query it falls back to the full drawer list, so folders and the
/// launcher-owned entries stay reachable here too — the fuzzy matcher ranks
/// installed apps, and a folder is not one. Typing narrows to apps, exactly as
/// rofi's drun mode does.
class TilingLauncher extends ConsumerStatefulWidget {
  const TilingLauncher({super.key, required this.theme});

  final EffectiveTheme theme;

  @override
  ConsumerState<TilingLauncher> createState() => _TilingLauncherState();
}

class _TilingLauncherState extends ConsumerState<TilingLauncher> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    // The prompt IS the surface. A launcher you have to tap to focus wastes the
    // keystroke that opened it.
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    // Leave no query behind: reopening should start empty, not mid-search.
    Future.microtask(
      () => ref.read(paletteQueryProvider.notifier).state = '',
    );
    super.dispose();
  }

  void _submit() {
    // launchTopMatch owns the "is there a hit?" decision, same as the terminal.
    if (launchTopMatch(ref, widget.theme)) {
      _controller.clear();
      ref.read(paletteQueryProvider.notifier).state = '';
    }
    // No toast on an empty match list. Someone mid-typo does not need to be
    // told they are mid-typo.
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final query = ref.watch(paletteQueryProvider);
    final results = ref.watch(paletteResultsProvider(theme));
    final items = ref.watch(drawerItemsProvider(theme));

    final palette = theme.palette;
    final mono = theme.typography.mono ?? 'UbuntuMono';

    if (theme.tilingLauncher == 'dmenu') {
      return Stack(
        children: [
          // ─── NO SCRIM ────────────────────────────────────────────────
          //
          // dmenu does not dim anything. It replaces the top line of the
          // screen and leaves everything else exactly as it was, which is
          // most of why it reads as austere rather than as a dialog. The
          // catcher is still full-screen and still opaque to hit testing,
          // because a tap off the bar has to dismiss; it simply paints
          // nothing.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => closeApps(ref),
              child: const SizedBox.expand(),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            // Top edge, so the keyboard never covers it and viewInsets never
            // enter into the layout. The rofi card has to dodge the keyboard;
            // this one is above it by construction.
            child: SafeArea(
              bottom: false,
              child: _DmenuBar(
                theme: theme,
                mono: mono,
                controller: _controller,
                focus: _focus,
                query: query,
                results: results,
                items: items,
                onChanged: (v) =>
                    ref.read(paletteQueryProvider.notifier).state = v,
                onSubmit: _submit,
              ),
            ),
          ),
        ],
      );
    }

    return Stack(
      children: [
        // Tap outside to dismiss, the way rofi does. The box is a floating
        // window over the desktop, not a full-screen page, so the area around it
        // has to be live.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            // [closeApps], not the flag: on a distro whose app list is a
            // page there is no overlay to hide, and clearing a flag that is
            // already false would leave the tap doing nothing at all.
            onTap: () => closeApps(ref),
            child: ColoredBox(
              // A scrim, not an opaque fill: a tiling WM dims what is behind the
              // launcher rather than hiding it.
              color: Colors.black.withValues(alpha: 0.45),
            ),
          ),
        ),
        Center(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420, maxHeight: 460),
              child: Container(
                decoration: BoxDecoration(
                  // The rofi box itself. The black scrim above is deliberately
                  // NOT scaled: it is the dimming of the desktop behind, not a
                  // surface of ours, and fading it with this setting would make
                  // a translucent launcher unreadable over a bright wallpaper.
                  color: palette.bar.withValues(alpha: 0.98 * theme.drawerOpacity),
                  // Tiling WMs draw a hard accent border round the focused
                  // window. That border is the whole aesthetic; do not round it
                  // away.
                  border: Border.all(color: palette.accent, width: 1.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Prompt(
                      theme: theme,
                      controller: _controller,
                      focus: _focus,
                      mono: mono,
                      onChanged: (v) =>
                          ref.read(paletteQueryProvider.notifier).state = v,
                      onSubmit: _submit,
                    ),
                    Container(
                      height: 1,
                      color: palette.onDark.withValues(alpha: 0.12),
                    ),
                    Flexible(
                      child: query.isEmpty
                          ? _AllList(theme: theme, items: items, mono: mono)
                          : _Results(
                              theme: theme,
                              results: results,
                              mono: mono,
                            ),
                    ),
                    _Hint(
                      theme: theme,
                      mono: mono,
                      count:
                          query.isEmpty ? items.length : results.length,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// dmenu: one line across the top of the screen.
///
/// ─── WHAT MAKES IT NOT A SMALLER ROFI ───────────────────────────────────────
///
/// The temptation is to reuse the card and shrink it, and that produces a small
/// card, not dmenu. Four things have to go, and each of them is one of the
/// reasons the two distros currently look alike:
///
///   1. **The list runs SIDEWAYS.** dmenu's matches sit on the same line as the
///      input, running off the right edge. A vertical result list is rofi's
///      whole silhouette, and keeping it would keep the resemblance whatever
///      else changed.
///   2. **No icons.** dmenu reads lines of text and has no idea what an app is.
///      This is also the single biggest visual difference on a phone, where an
///      icon is the largest thing in any row.
///   3. **No border, no radius, no card.** A bar, edge to edge, in the panel's
///      own colour.
///   4. **The selection is INVERTED**, not washed. dmenu paints the selected
///      item's background in the accent and its text in the background colour.
///      A 0.18 accent wash is the card's idiom; a solid block is this one's.
///
/// The footer goes too. A count and a key hint are rofi affordances; dmenu tells
/// you nothing, which is the joke and also the aesthetic.
class _DmenuBar extends StatelessWidget {
  const _DmenuBar({
    required this.theme,
    required this.mono,
    required this.controller,
    required this.focus,
    required this.query,
    required this.results,
    required this.items,
    required this.onChanged,
    required this.onSubmit,
  });

  final EffectiveTheme theme;
  final String mono;
  final TextEditingController controller;
  final FocusNode focus;
  final String query;
  final List<Ranked<AppEntry>> results;
  final List<DrawerItem> items;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;

  /// How wide the typing area is before the matches start.
  ///
  /// A FIXED width, which is the honest phone translation of dmenu's layout: on
  /// a desktop the input grows to the first item and the items follow it, and a
  /// growing input on a 360dp screen would shove every match off the edge after
  /// four characters. Fixed means the matches never move while you type, which
  /// is what makes the top hit tappable mid-word.
  static const _inputWidth = 132.0;

  /// The bar's height, FIXED rather than grown from its contents.
  ///
  /// ─── A HORIZONTAL LIST HAS NO HEIGHT TO GIVE ────────────────────────────
  ///
  /// This was vertical padding around a Row, which works everywhere except
  /// here: the bar is `Positioned` at the top edge, so its height constraint
  /// is `0 <= h <= Infinity`, and the matches strip inside it is a
  /// horizontally scrolling ListView. A horizontal list sizes to its
  /// constraint on the cross axis and has no intrinsic height of its own, so
  /// with an unbounded parent nothing in the subtree is ever laid out and the
  /// first paint asserts `hasSize`.
  ///
  /// One number fixes it and is also the correct design: dmenu is exactly one
  /// line tall, and a bar that grew with its contents would be a bar whose
  /// height depended on which app you had typed towards.
  static const _height = 42.0;

  @override
  Widget build(BuildContext context) {
    final palette = theme.palette;

    return Container(
      // No border and no radius. See the class doc: this is a bar, not a card.
      color: palette.bar.withValues(alpha: 0.98 * theme.drawerOpacity),
      height: _height,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          Text(
            // dmenu's prompt is whatever the script passed it, and on a
            // distro shell that is the distro. One more thing that separates
            // two tiling distros at a glance.
            //
            // FIRST WORD ONLY, lowercased: 'arch', not 'arch linux'. The
            // prompt, the input and the matches share one 360dp line, and a
            // two-word prompt eats the space the matches need to be tappable.
            theme.spec.name.split(' ').first.toLowerCase(),
            style: TextStyle(
              fontFamily: mono,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: palette.accent,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: _inputWidth,
            child: TextField(
              controller: controller,
              focusNode: focus,
              autofocus: true,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.none,
              textInputAction: TextInputAction.go,
              cursorColor: palette.accent,
              // A BLOCK cursor, the width of a character cell, with square
              // ends. Same choice the rofi prompt makes and for the same
              // reason, and it matters more here where there is no other
              // ornament to say this is a terminal's cousin.
              cursorWidth: 8,
              cursorRadius: Radius.zero,
              style: TextStyle(
                fontFamily: mono,
                fontSize: 13,
                color: palette.onDark,
              ),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: onChanged,
              onSubmitted: (_) => onSubmit(),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(child: _DmenuItems(
            theme: theme,
            mono: mono,
            query: query,
            results: results,
            items: items,
          )),
        ],
      ),
    );
  }
}

/// The matches, running sideways.
///
/// Empty query falls back to the full drawer list exactly as the card does, so
/// folders and the launcher-owned entries stay reachable here too. The item
/// SOURCE is shared with rofi on purpose; only the row is different.
class _DmenuItems extends ConsumerStatefulWidget {
  const _DmenuItems({
    required this.theme,
    required this.mono,
    required this.query,
    required this.results,
    required this.items,
  });

  final EffectiveTheme theme;
  final String mono;
  final String query;
  final List<Ranked<AppEntry>> results;
  final List<DrawerItem> items;

  @override
  ConsumerState<_DmenuItems> createState() => _DmenuItemsState();
}

class _DmenuItemsState extends ConsumerState<_DmenuItems> {
  /// ─── THE MARKERS, AND WHY THE SELECTION DOES NOT MOVE ─────────────────
  ///
  /// Real dmenu draws `<` and `>` when there are more matches than fit, and
  /// that is all it draws: the inverted item stays the top hit no matter what
  /// is on screen, because the inversion is a PROMISE ABOUT WHAT ENTER RUNS.
  ///
  /// The tempting phone version is selection-follows-scroll, so whatever sits
  /// under the input's right edge becomes selected. It reads well and it makes
  /// Enter unpredictable: the target moves while you are still typing, and a
  /// stray horizontal drag mid-type launches something you did not choose.
  /// Launching is the one gesture in this launcher with no undo.
  ///
  /// So the markers answer the question the scroll actually raises, which is
  /// "is there more over there", and answer nothing else.
  final _controller = ScrollController();

  /// Is there content off the leading and trailing edges?
  ///
  /// Both start false and are corrected after the first layout: a controller
  /// has no `position` until it is attached, so asking during build throws.
  bool _more = false;
  bool _before = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_sync);
    // POST-FRAME, because the very first build has no attached position and
    // the common case is exactly the one that matters: a full strip that has
    // never been scrolled still needs its trailing marker.
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void didUpdateWidget(_DmenuItems old) {
    super.didUpdateWidget(old);
    // The list changes on every keystroke, so the extent changes with it.
    // Without this, typing from four matches down to one leaves the trailing
    // marker pointing at nothing.
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  void _sync() {
    if (!mounted || !_controller.hasClients) return;
    final p = _controller.position;
    final more = p.pixels < p.maxScrollExtent - 0.5;
    final before = p.pixels > 0.5;
    if (more != _more || before != _before) {
      setState(() {
        _more = more;
        _before = before;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// One edge glyph, or nothing.
  Widget _marker(String glyph, bool show) => SizedBox(
        width: 11,
        child: show
            ? Text(
                glyph,
                style: TextStyle(
                  fontFamily: widget.mono,
                  fontSize: 13,
                  color: widget.theme.palette.accent.withValues(alpha: 0.75),
                ),
              )
            : null,
      );

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final mono = widget.mono;
    final query = widget.query;
    final results = widget.results;
    final items = widget.items;

    if (query.isNotEmpty) {
      if (results.isEmpty) {
        return Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'no match',
            style: TextStyle(
              fontFamily: mono,
              fontSize: 13,
              color: theme.palette.onDark.withValues(alpha: 0.35),
            ),
          ),
        );
      }

      // Twenty rather than the card's ten. A horizontal strip costs one line
      // whatever is on it, so the reason to cut the list short does not apply:
      // there is no scrolling past anything, only sideways along it.
      final shown = results.take(20).toList();

      return _framed(ListView.builder(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        itemCount: shown.length,
        itemBuilder: (context, i) {
          final entry = shown[i].item;
          return _DmenuItem(
            theme: theme,
            mono: mono,
            // NOT highlighted per character. The card highlights matched
            // letters in the accent, which is rofi showing its work; dmenu
            // marks the SELECTION and nothing else, and running both idioms
            // at once would put two kinds of accent text on one line.
            label: entry.label,
            selected: i == 0,
            onTap: () {
              launchDrawerApp(ref, entry);
              ref.read(paletteQueryProvider.notifier).state = '';
            },
            onLongPress: (rowContext) => showDrawerAppMenu(
              rowContext,
              ref,
              theme,
              entry,
              anchor: AnchoredMenu.anchorOf(rowContext),
            ),
          );
        },
      ));
    }

    return _framed(ListView.builder(
      controller: _controller,
      scrollDirection: Axis.horizontal,
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        return _DmenuItem(
          theme: theme,
          mono: mono,
          label: item.label,
          // NOTHING is selected with an empty query. Enter runs the top match
          // and there is no match yet, so inverting the first item would
          // promise a binding that `launchTopMatch` will refuse.
          selected: false,
          onTap: () => activateDrawerItem(context, ref, theme, item),
          onLongPress: switch (item) {
            AppDrawerItem(:final entry) => (rowContext) => showDrawerAppMenu(
                  rowContext,
                  ref,
                  theme,
                  entry,
                  anchor: AnchoredMenu.anchorOf(rowContext),
                ),
            final FolderDrawerItem f => (rowContext) => drawerFolderSettings(
                  rowContext,
                  ref,
                  theme,
                  f,
                  anchor: AnchoredMenu.anchorOf(rowContext),
                ),
            LauncherSettingsItem() ||
            DeviceSettingsItem() ||
            TerminalDrawerItem() =>
              null,
          },
        );
      },
    ));
  }

  /// The strip with its edge markers, if there is anything past either edge.
  ///
  /// A Row rather than a Stack: the glyphs take their 11dp out of the strip's
  /// width instead of floating over the last match, so a marker never covers
  /// the label it is telling you about.
  Widget _framed(Widget list) => Row(
        children: [
          _marker('<', _before),
          Expanded(child: list),
          _marker('>', _more),
        ],
      );
}

/// One inline match. Selected means INVERTED, which is dmenu's SchemeSel.
class _DmenuItem extends StatelessWidget {
  const _DmenuItem({
    required this.theme,
    required this.mono,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  final EffectiveTheme theme;
  final String mono;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Called with THIS ROW's context, not the list builder's.
  ///
  /// `ListView.builder` hands its `itemBuilder` a context whose nearest render
  /// object is the `RenderSliverList`, so a closure that captured it and asked
  /// [AnchoredMenu.anchorOf] for a rect threw. Handing the row's own context
  /// back up is what makes the menu open beside the row rather than centred.
  final void Function(BuildContext context)? onLongPress;

  @override
  Widget build(BuildContext context) {
    final palette = theme.palette;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      onLongPress: onLongPress == null ? null : () => onLongPress!(context),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        // Square, deliberately. A radius here would be the one rounded thing
        // on a distro whose whole authored identity is that nothing is rounded.
        color: selected ? palette.accent : Colors.transparent,
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: mono,
            fontSize: 13,
            // The BAR colour on the accent block, not white: inverting means
            // swapping the two, and a white-on-accent label would read as a
            // button rather than as a selected line.
            color: selected ? palette.bar : palette.onDark,
          ),
        ),
      ),
    );
  }
}

/// `❯ ` plus the input. Mono, because a tiling WM's launcher is a terminal's
/// cousin and the theme already carries the font.
class _Prompt extends StatelessWidget {
  const _Prompt({
    required this.theme,
    required this.controller,
    required this.focus,
    required this.mono,
    required this.onChanged,
    required this.onSubmit,
  });

  final EffectiveTheme theme;
  final TextEditingController controller;
  final FocusNode focus;
  final String mono;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final palette = theme.palette;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          Text(
            '❯',
            style: TextStyle(
              fontFamily: mono,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: palette.accent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focus,
              autofocus: true,
              autocorrect: false,
              enableSuggestions: false,
              // A launcher that autocapitalises fights every package name.
              textCapitalization: TextCapitalization.none,
              textInputAction: TextInputAction.go,
              cursorColor: palette.accent,
              cursorWidth: 8,
              cursorRadius: Radius.zero,
              style: TextStyle(
                fontFamily: mono,
                fontSize: 15,
                color: palette.onDark,
              ),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: 'run',
                hintStyle: TextStyle(
                  fontFamily: mono,
                  fontSize: 15,
                  color: palette.onDark.withValues(alpha: 0.35),
                ),
              ),
              onChanged: onChanged,
              onSubmitted: (_) => onSubmit(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fuzzy hits. Top match takes the accent wash and the `↵`, so enter is
/// obviously bound to what you are looking at.
class _Results extends ConsumerWidget {
  const _Results({
    required this.theme,
    required this.results,
    required this.mono,
  });

  final EffectiveTheme theme;
  final List<Ranked<AppEntry>> results;
  final String mono;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 22),
        child: Text(
          'no matches',
          style: TextStyle(
            fontFamily: mono,
            fontSize: 12.5,
            color: theme.palette.onDark.withValues(alpha: 0.45),
          ),
        ),
      );
    }

    // Ten is plenty. If the right app isn't in the top ten, the answer is
    // another keystroke, not more scrolling.
    final shown = results.take(10).toList();

    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: shown.length,
      itemBuilder: (context, i) {
        final ranked = shown[i];
        final entry = ranked.item;
        final isTop = i == 0;

        return _Line(
          theme: theme,
          mono: mono,
          isTop: isTop,
          icon: AppIcon(entry: entry, size: theme.iconSizeDp * 0.5),
          label: _Highlighted(
            theme: theme,
            mono: mono,
            text: entry.label,
            indices: ranked.match.indices,
          ),
          onTap: () {
            launchDrawerApp(ref, entry);
            ref.read(paletteQueryProvider.notifier).state = '';
          },
          onLongPress: (rowContext) => showDrawerAppMenu(
              rowContext, ref, theme, entry,
              anchor: AnchoredMenu.anchorOf(rowContext)),
        );
      },
    );
  }
}

/// The empty-query view: everything, in drawer order. Folders and the
/// launcher-owned entries live here — the fuzzy matcher ranks installed apps,
/// so this is the one view that can show the rest.
class _AllList extends ConsumerWidget {
  const _AllList({
    required this.theme,
    required this.items,
    required this.mono,
  });

  final EffectiveTheme theme;
  final List<DrawerItem> items;
  final String mono;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = theme.iconSizeDp * 0.5;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];

        return _Line(
          theme: theme,
          mono: mono,
          isTop: false,
          icon: SizedBox(
            width: size,
            height: size,
            child: switch (item) {
              AppDrawerItem(:final entry) => AppIcon(entry: entry, size: size),
              FolderDrawerItem() => Icon(
                  Icons.folder_outlined,
                  size: size * 0.9,
                  color: theme.palette.accent,
                ),
              LauncherSettingsItem() =>
                LauncherBrandIcon(theme: theme, size: size),
              DeviceSettingsItem() => Icon(
                  Icons.settings,
                  size: size * 0.85,
                  color: theme.palette.onDark,
                ),
              TerminalDrawerItem() => Icon(
                  Icons.terminal,
                  size: size * 0.85,
                  color: theme.palette.onDark,
                ),
            },
          ),
          label: Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: mono,
              fontSize: 13,
              color: theme.palette.onDark,
            ),
          ),
          onTap: () => activateDrawerItem(context, ref, theme, item),
          onLongPress: switch (item) {
            AppDrawerItem(:final entry) => (rowContext) =>
                showDrawerAppMenu(rowContext, ref, theme, entry,
                anchor: AnchoredMenu.anchorOf(rowContext)),
            final FolderDrawerItem f => (rowContext) =>
                drawerFolderSettings(rowContext, ref, theme, f,
                anchor: AnchoredMenu.anchorOf(rowContext)),
            LauncherSettingsItem() ||
            DeviceSettingsItem() ||
            TerminalDrawerItem() =>
              null,
          },
        );
      },
    );
  }
}

/// One row of the list, shared by both views so they cannot drift apart.
class _Line extends StatelessWidget {
  const _Line({
    required this.theme,
    required this.mono,
    required this.isTop,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.onLongPress,
  });

  final EffectiveTheme theme;
  final String mono;
  final bool isTop;
  final Widget icon;
  final Widget label;
  final VoidCallback onTap;
  /// Called with THIS ROW's context. See [_DmenuItem.onLongPress]: the same
  /// sliver-context trap applies to every row a `ListView.builder` makes, and
  /// this list is vertical rather than horizontal, which changes nothing about
  /// it.
  final void Function(BuildContext context)? onLongPress;

  @override
  Widget build(BuildContext context) {
    final palette = theme.palette;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      onLongPress: onLongPress == null ? null : () => onLongPress!(context),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: isTop
              ? palette.accent.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Row(
          children: [
            icon,
            const SizedBox(width: 10),
            Expanded(child: label),
            if (isTop)
              Text(
                '↵',
                style: TextStyle(
                  fontFamily: mono,
                  fontSize: 14,
                  color: palette.accent,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Paints the matched characters in the accent, bold.
///
/// This is the payoff for `FuzzyMatch.indices`, and it doubles as the feature's
/// own debug view: if the highlight looks wrong, the RANKING is wrong, and you
/// can see it without a print statement.
class _Highlighted extends StatelessWidget {
  const _Highlighted({
    required this.theme,
    required this.mono,
    required this.text,
    required this.indices,
  });

  final EffectiveTheme theme;
  final String mono;
  final String text;
  final List<int> indices;

  @override
  Widget build(BuildContext context) {
    final hit = indices.toSet();
    final palette = theme.palette;

    return Text.rich(
      TextSpan(
        children: [
          for (var i = 0; i < text.length; i++)
            TextSpan(
              text: text[i],
              style: hit.contains(i)
                  ? TextStyle(
                      color: palette.accent,
                      fontWeight: FontWeight.w700,
                    )
                  : TextStyle(color: palette.onDark),
            ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontFamily: mono, fontSize: 13),
    );
  }
}

/// waybar-style footer: a count and the key hints, in the bar's own idiom.
class _Hint extends StatelessWidget {
  const _Hint({
    required this.theme,
    required this.mono,
    required this.count,
  });

  final EffectiveTheme theme;
  final String mono;
  final int count;

  @override
  Widget build(BuildContext context) {
    final ink = theme.palette.onDark.withValues(alpha: 0.45);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 7, 12, 9),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.palette.onDark.withValues(alpha: 0.12)),
        ),
      ),
      child: Text(
        '$count · ↵ runs the top match',
        style: TextStyle(fontFamily: mono, fontSize: 11, color: ink),
      ),
    );
  }
}
