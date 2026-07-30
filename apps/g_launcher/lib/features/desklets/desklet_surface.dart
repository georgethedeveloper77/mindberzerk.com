import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/prefs/desklet_layout.dart';
import '../../data/prefs/launcher_prefs.dart';
import '../../engine/desklet_skin.dart';
import '../../engine/effective_theme.dart';
import 'desklet_edit.dart';
import 'desklet_editor.dart';
import 'desklet_picker.dart';
import 'kinds/clock_desklet.dart';
import 'kinds/appwidget_desklet.dart';
import 'kinds/control_desklets.dart';
import 'kinds/glance_desklet.dart';
import 'kinds/pane_desklets.dart';
import 'kinds/stat_desklets.dart';

/// Turn one stored placement into a widget. PHASE D3.
///
/// The ONLY exhaustive switch over kinds in the app. Adding a desklet means a
/// case here and a file under `kinds/`, and nothing else — no registration, no
/// per-shell branch, no theme edit required for it to render somewhere.
///
/// An unknown kind returns null rather than throwing. [DeskletLayout.renderable]
/// has already filtered those out, so reaching this is a defensive floor rather
/// than a live path, but the floor matters: a CDN pack can ship a kind this
/// build has never heard of, and the correct answer is an empty cell, not a
/// crashed home screen.
Widget? buildDesklet(
  EffectiveTheme theme,
  Desklet desklet,
  DeskletSkin skin,
) {
  return switch (desklet.kind) {
    'glance' => GlanceDesklet(theme: theme, desklet: desklet, skin: skin),
    'appwidget' =>
      AppWidgetDesklet(theme: theme, desklet: desklet, skin: skin),
    'clock' => ClockDesklet(theme: theme, desklet: desklet, skin: skin),
    'monitor' => MonitorDesklet(theme: theme, desklet: desklet, skin: skin),
    'fastfetch' => FastfetchDesklet(theme: theme, desklet: desklet, skin: skin),
    'network' => NetworkDesklet(theme: theme, desklet: desklet, skin: skin),
    'storage' => StorageDesklet(theme: theme, desklet: desklet, skin: skin),
    'battery' => BatteryDesklet(theme: theme, desklet: desklet, skin: skin),
    'notes' => NotesDesklet(theme: theme, desklet: desklet, skin: skin),
    'search' => SearchDesklet(theme: theme, desklet: desklet, skin: skin),
    // Pane-only kinds. DeskletLayout.renderable already keeps these off a
    // graphical desktop, so reaching them here means the pane asked.
    'free' => FreeDesklet(theme: theme, desklet: desklet, skin: skin),
    'df' => DfDesklet(theme: theme, desklet: desklet, skin: skin),
    'ls' => LsDesklet(theme: theme, desklet: desklet, skin: skin),
    'uptime' => UptimeDesklet(theme: theme, desklet: desklet, skin: skin),
    _ => null,
  };
}

/// The desktop grid for ONE workspace.
///
/// Dropped into the `itemBuilder` of the vertical PageView that every graphical
/// shell already has, which is why this phase needed no shell rewrite: those
/// builders returned `SizedBox.expand()` and now return this. The wallpaper is
/// still drawn by WindowManager beneath Flutter; this paints on top of nothing.
///
/// ─── WHY A LAYOUTBUILDER AND NOT A GRIDVIEW ─────────────────────────────────
///
/// The placements are absolute rectangles in cell coordinates, not a flow. A
/// GridView would reflow them and a Wrap would reorder them, and both would
/// silently disagree with the pure engine that decided where things go —
/// producing a desktop that does not match what `DeskletLayout` believes, which
/// is the worst kind of bug because both halves look correct in isolation.
class DeskletSurfaceView extends ConsumerWidget {
  const DeskletSurfaceView({
    super.key,
    required this.theme,
    required this.page,
  });

  final EffectiveTheme theme;
  final int page;

  /// Breathing room around each tile so two neighbours do not touch.
  static const double gutter = 6;

  /// The desktop grid is inset from the screen edges: a desklet flush against
  /// the bezel reads as a bug, and the dock and top bar need clearance.
  static const EdgeInsets margin = EdgeInsets.fromLTRB(14, 14, 14, 14);

  /// Roughly how big one cell is, for callers that must size something BEFORE
  /// this widget has laid out.
  ///
  /// ─── WHY THIS EXISTS ──────────────────────────────────────────────────
  ///
  /// The picker has to turn a widget provider's requested footprint in dp into
  /// a span in cells, and it was dividing by a hardcoded 70. A real row on a
  /// 4 by 5 grid is about 140dp tall, so every hosted widget was seeded at
  /// twice the rows it asked for: a weather strip that wants 74dp got two rows
  /// and 280dp, which is most of why third-party widgets look stretched and
  /// wrong on this launcher.
  ///
  /// An ESTIMATE, and honest about it. The real cell comes from the workspace
  /// canvas's own constraints, which nothing outside the build can see; this
  /// approximates the same arithmetic from the window. It is used to choose an
  /// initial span, never to lay anything out, so being a few dp off costs
  /// nothing and being 70 against 140 cost a great deal.
  static ({double w, double h}) estimateCell(
    BuildContext context,
    EffectiveTheme theme,
  ) {
    final size = MediaQuery.sizeOf(context);
    final insets = MediaQuery.viewPaddingOf(context);

    final w = size.width - margin.horizontal - insets.horizontal;
    final h = size.height - margin.vertical - insets.vertical;

    final cols = theme.deskletCols < 1 ? 1 : theme.deskletCols;
    final rows = theme.deskletRows < 1 ? 1 : theme.deskletRows;

    return (
      w: w <= 0 ? 70 : w / cols,
      h: h <= 0 ? 70 : h / rows,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = DeskletLayout.renderable(theme.prefs, page);
    final editing = ref.watch(deskletEditProvider).active;

    // An EMPTY page still needs a surface while editing, or there is nowhere to
    // tap to add the first desklet. Outside edit mode it stays a genuinely
    // empty desktop, which is the authentic reading.
    if (items.isEmpty && !editing) return const SizedBox.expand();

    // The FINE grid, not the icon grid. See EffectiveTheme.deskletCols.
    final cols = theme.deskletCols;
    final rows = theme.deskletRows;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Safe-area aware: the top bar and the gesture pill both eat into the
        // usable desktop, and a clock under the status bar is not a desktop.
        final insets = MediaQuery.viewPaddingOf(context);
        final usable = EdgeInsets.only(
          left: margin.left + insets.left,
          right: margin.right + insets.right,
          top: margin.top + insets.top,
          bottom: margin.bottom + insets.bottom,
        );

        final w = constraints.maxWidth - usable.horizontal;
        final h = constraints.maxHeight - usable.vertical;
        if (w <= 0 || h <= 0) return const SizedBox.expand();

        final cellW = w / cols;
        final cellH = h / rows;

        return Padding(
          padding: usable,
          child: Stack(
            children: [
              // The empty-cell grid sits UNDERNEATH the tiles, so a tap that
              // lands on a desklet reaches the desklet and only a tap on real
              // empty space opens the picker. Ordering, not hit-test tricks.
              if (editing)
                Positioned.fill(
                  child: _EmptyCells(
                    theme: theme,
                    page: page,
                    cols: cols,
                    rows: rows,
                    cellW: cellW,
                    cellH: cellH,
                  ),
                ),
              for (final d in items)
                Positioned(
                  left: d.col * cellW,
                  top: d.row * cellH,
                  // While editing, the tile sizes ITSELF (it grows live under a
                  // resize drag), so the Positioned must not also constrain it.
                  width: editing ? null : d.spanX * cellW,
                  height: editing ? null : d.spanY * cellH,
                  child: editing
                      ? EditableDesklet(
                          theme: theme,
                          desklet: d,
                          cellW: cellW,
                          cellH: cellH,
                          child: Padding(
                            padding: const EdgeInsets.all(gutter / 2),
                            child: _Tile(theme: theme, desklet: d),
                          ),
                        )
                      : _ResizableTile(theme: theme, desklet: d),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// A desklet at rest, that a long press turns into an editable one. PHASE D4+.
///
/// ─── HOLD-TO-RESIZE WITHOUT A MENU ──────────────────────────────────────────
///
/// The whole resize machinery already exists ([EditableDesklet] draws the
/// handle and drives the tested [DeskletLayout.resize]); the only thing missing
/// was a way to reach it from the desktop other than the long-press MENU's
/// Widgets action. So a held press on the tile itself enters edit mode and
/// selects THIS tile, which is exactly the state in which its resize handle is
/// already showing. One gesture, no sheet, and everything downstream is the
/// path the Add button already used.
///
/// [HitTestBehavior.translucent] so a desklet that owns an `onTap` — the note
/// opens its editor, the search tile opens the drawer — keeps it. A long press
/// and a tap are different gestures; the inner tap wins its arena and this wins
/// the long-press arena, so neither eats the other.
///
/// The edit-mode EXIT is the system BACK gesture (handled shell-side), so
/// entering edit mode from here always has a way back out.
class _ResizableTile extends ConsumerWidget {
  const _ResizableTile({required this.theme, required this.desklet});

  final EffectiveTheme theme;
  final Desklet desklet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPress: () {
        HapticFeedback.mediumImpact();
        final edit = ref.read(deskletEditProvider.notifier);
        edit.enter();
        edit.select(desklet.id);
      },
      child: Padding(
        padding: const EdgeInsets.all(DeskletSurfaceView.gutter / 2),
        child: _Tile(theme: theme, desklet: desklet),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.theme, required this.desklet});

  final EffectiveTheme theme;
  final Desklet desklet;

  @override
  Widget build(BuildContext context) {
    final skin = theme.spec.desklets.skinFor(theme.shell, desklet.kind);
    final child = buildDesklet(theme, desklet, skin);
    if (child == null) return const SizedBox.shrink();

    // ─── A HOSTED WIDGET FILLS ITS CELL; IT IS NOT SCALE-TO-FIT ──────────────
    //
    // Every DRAWN desklet is authored at a natural size, so the FittedBox below
    // measures it UNBOUNDED and scales the result to fit. A hosted AppWidget is
    // a PlatformView with no intrinsic size: handed unbounded constraints, its
    // `SizedBox.expand` expands into infinity and asserts. So it takes the
    // bounded cell directly, which is also the correct behaviour — a widget
    // should occupy the rectangle you gave it, not be shrunk to its content.
    if (desklet.kind == 'appwidget') {
      return SizedBox.expand(child: child);
    }

    // FittedBox rather than a scroll view or a clip.
    //
    // A desklet is authored at a size the skin chose; the cell it lands in
    // depends on the theme's grid and the phone's screen. Scaling DOWN when it
    // does not fit keeps a 56px GNOME clock legible on a 4-column grid and on a
    // 6-column one, where clipping would behead it and scrolling would put a
    // scrollbar on a wallpaper. Scale down only: blowing a small tile up to
    // fill a large cell would make a 1x1 note look like a poster.
    return Align(
      alignment: _alignFor(skin),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: _alignFor(skin),
        child: child,
      ),
    );
  }

  /// Bare desklets hang off the top-left the way a desktop widget does; boxed
  /// ones centre in their cell, because a card with dead space on one side
  /// reads as a layout mistake rather than a choice.
  static Alignment _alignFor(DeskletSkin skin) =>
      switch (skin.surface) {
        DeskletSurface.bare => Alignment.topLeft,
        DeskletSurface.terminal => Alignment.topLeft,
        DeskletSurface.card => Alignment.center,
        DeskletSurface.panel => Alignment.center,
      };
}

/// The PANE surface: the terminal shell's desklets, as scrollback.
///
/// Not a grid, and not a grid with different paint. A terminal has no desktop
/// to position things on; it has a column of output that stays until you clear
/// it. So `col`, `row`, `spanX` and `spanY` are IGNORED here and list order is
/// the layout — precisely the way `prefs.dockSide` is ignored under the Aqua
/// shell. The record is shared; the renderer is not.
///
/// Drop into the TUI shell's ListView between the fastfetch header and the
/// prompt, so a desklet reads as something you ran a moment ago.
class DeskletPane extends ConsumerWidget {
  const DeskletPane({super.key, required this.theme, required this.page});

  final EffectiveTheme theme;
  final int page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // pane: true, which also admits the pane-only kinds (`free`, `df`) that a
    // graphical desktop correctly refuses to draw.
    final items = DeskletLayout.renderable(theme.prefs, page, pane: true);
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final d in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: buildDesklet(
                  theme,
                  d,
                  theme.spec.desklets.skinFor(theme.shell, d.kind),
                ) ??
                const SizedBox.shrink(),
          ),
      ],
    );
  }
}

/// The tap-to-add grid, drawn only in edit mode.
///
/// Every cell is a target, including ones already covered by a desklet — the
/// covered ones are simply behind it in the Stack and never receive the tap.
/// Testing occupancy here as well would duplicate `DeskletLayout.at` for no
/// gain, and the two copies would eventually disagree.
class _EmptyCells extends ConsumerWidget {
  const _EmptyCells({
    required this.theme,
    required this.page,
    required this.cols,
    required this.rows,
    required this.cellW,
    required this.cellH,
  });

  final EffectiveTheme theme;
  final int page;
  final int cols;
  final int rows;
  final double cellW;
  final double cellH;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ink = theme.palette.onDark;

    return Stack(
      children: [
        for (var r = 0; r < rows; r++)
          for (var c = 0; c < cols; c++)
            Positioned(
              left: c * cellW,
              top: r * cellH,
              width: cellW,
              height: cellH,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => showDeskletPicker(
                  context,
                  ref,
                  theme,
                  page: page,
                  col: c,
                  row: r,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: ink.withValues(alpha: 0.13),
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.add,
                        size: 16,
                        color: ink.withValues(alpha: 0.22),
                      ),
                    ),
                  ),
                ),
              ),
            ),
      ],
    );
  }
}
