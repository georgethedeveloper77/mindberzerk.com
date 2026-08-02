import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/prefs/desklet_layout.dart';
import '../../data/prefs/launcher_prefs.dart';
import '../../engine/desklet_skin.dart';
import '../../engine/effective_theme.dart';
import 'desklet_edit.dart';
import 'desklet_settings.dart';
import 'desklet_editor.dart';
import 'desklet_picker.dart';
import 'kinds/clock_desklet.dart';
import 'kinds/appwidget_desklet.dart';
import 'kinds/control_desklets.dart';
import 'kinds/glance_desklet.dart';
import 'kinds/pane_desklets.dart';
import 'kinds/stack_desklet.dart';
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
    // The builder is handed back to the stack so it can draw its members
    // without importing this file, which would be a cycle.
    'stack' => StackDesklet(
        theme: theme,
        desklet: desklet,
        skin: skin,
        build: buildDesklet,
      ),
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

  /// The desktop grid's inset from the screen edges.
  ///
  /// ─── 6, NOT 14, AND THE REASON CHANGED UNDER IT ─────────────────────────
  ///
  /// It was 14 because "a desklet flush against the bezel reads as a bug, and
  /// the dock and top bar need clearance". The first half still holds and is
  /// why this is not zero. The second half stopped being true: panels are
  /// siblings of the workspace now and take their own space out of it, and the
  /// dock is positioned inside this surface's own box. Neither needs a gutter
  /// paid for by every desklet on every edge.
  ///
  /// 14 on each side is 28dp of a 384dp screen, most of a cell on the fine
  /// grid, and it is why a widget sized to fill the width still stopped short
  /// of it.
  static const EdgeInsets margin = EdgeInsets.all(6);

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
              // ─── ONE WIDGET IN BOTH STATES ────────────────────────
              //
              // This used to pick between `_ResizableTile` at rest and
              // `EditableDesklet` while editing. That conditional is what made
              // hold-to-move impossible: a hold entered edit mode, edit mode
              // rebuilt this list, the swap unmounted the widget the finger was
              // on, and the drag died at the moment it should have begun. No
              // amount of gesture tuning inside either widget could have fixed
              // it, because the widget doing the listening ceased to exist.
              //
              // The KEY matters as much as the merge. Without it these are
              // positional children, so removing a desklet would shift every
              // later tile's state onto its neighbour: the tile you were
              // dragging keeps its drag offset and the wrong desklet inherits
              // it. Keyed by id, state follows the desklet it belongs to.
              for (final d in items)
                Positioned(
                  key: ValueKey(d.id),
                  left: d.col * cellW,
                  top: d.row * cellH,
                  // The tile sizes ITSELF in both states now, because it grows
                  // live under a resize drag and the Positioned must not fight
                  // that. At rest it computes exactly the span this used to
                  // pass down, so nothing about the resting layout changed.
                  child: EditableDesklet(
                    theme: theme,
                    desklet: d,
                    cellW: cellW,
                    cellH: cellH,
                    editing: editing,
                    child: Padding(
                      padding: const EdgeInsets.all(gutter / 2),
                      child: _Tile(theme: theme, desklet: d),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.theme, required this.desklet});

  final EffectiveTheme theme;
  final Desklet desklet;

  @override
  Widget build(BuildContext context) {
    // ─── THE DISTRO'S SKIN, THEN THE PERSON'S ─────────────────────────────
    //
    // Same merge order as every other preference in the app: the distro
    // provides the default and the user beats it. `mergedWith` inherits any key
    // the override does not carry, so a widget with nothing set renders exactly
    // as it did before per-widget settings existed.
    final skin = theme.spec.desklets
        .skinFor(theme.shell, desklet.kind)
        .mergedWith(skinOverridesFor(desklet));
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
    // A STACK IS THE SAME CASE, for a different reason. It is a PageView, and a
    // PageView cannot lay out with unbounded height: measured inside the
    // FittedBox below it asserts before it ever paints. It also WANTS the whole
    // rectangle, since its members are drawn into the stack's footprint rather
    // than at their own natural sizes.
    if (desklet.kind == 'appwidget' || desklet.kind == 'stack') {
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
/// The grid, while editing.
///
/// ─── WHY THIS IS PAINTED AND NOT 120 WIDGETS ────────────────────────────────
///
/// It used to build a rounded, bordered box with a plus icon in EVERY cell.
/// Twenty of those on the old 4 by 5 grid reads fine. The desklet grid is 8 by
/// 15 now, so the same code draws a hundred and twenty: a wall of plus signs
/// dense enough to hide the desktop under it, and a hundred and twenty widgets
/// rebuilt on every edit-mode frame.
///
/// So the grid is one painted layer of hairlines and the taps go through a
/// single detector that works out which cell was hit from the coordinates. Same
/// behaviour, two widgets instead of a hundred and twenty, and a grid that
/// reads as a guide rather than as a form to fill in.
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

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // ─── AN OUTSIDE TAP WHILE EDITING ONE TILE MEANS "DONE" ───────────
      //
      // This opened the picker unconditionally, which made edit mode leak in
      // the most irritating way available: you select a widget, adjust it,
      // touch anywhere off it to finish, and the launcher offers to add a
      // SECOND widget at the cell you happened to hit. Every OS widget editor
      // treats an outside tap as commit-and-exit, and so does this now.
      //
      // "Commit" needs no write. A move or a resize already persisted through
      // DeskletLayout on drop; the pending state this leaves is nothing but the
      // handles being drawn. So exiting IS the commit, and there is no
      // half-applied geometry for this path to flush.
      //
      // The split is on SELECTION, not on edit mode. Nothing selected is the
      // arrange posture you enter from the desktop menu's Widgets action, where
      // tapping a cell to place something there is the entire purpose of the
      // grid being drawn. Collapsing both states onto one behaviour would fix
      // this annoyance by deleting a feature.
      onTapUp: (d) {
        if (ref.read(deskletEditProvider).selected != null) {
          HapticFeedback.selectionClick();
          ref.read(deskletEditProvider.notifier).exit();
          return;
        }

        // Which cell, from where the tap landed. `placeAt` already refuses an
        // occupied cell and the caller falls back to the packer, so an occupied
        // hit is handled and does not need excluding here.
        final c = (d.localPosition.dx / cellW).floor().clamp(0, cols - 1);
        final r = (d.localPosition.dy / cellH).floor().clamp(0, rows - 1);
        showDeskletPicker(context, ref, theme, page: page, col: c, row: r);
      },
      child: CustomPaint(
        size: Size.infinite,
        painter: _GridPainter(
          cols: cols,
          rows: rows,
          cellW: cellW,
          cellH: cellH,
          color: ink.withValues(alpha: 0.10),
        ),
      ),
    );
  }
}

/// Hairlines on the cell boundaries. INTERIOR ONLY: a line around the whole
/// workspace would read as a frame the desktop does not have.
class _GridPainter extends CustomPainter {
  const _GridPainter({
    required this.cols,
    required this.rows,
    required this.cellW,
    required this.cellH,
    required this.color,
  });

  final int cols;
  final int rows;
  final double cellW;
  final double cellH;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    for (var c = 1; c < cols; c++) {
      final x = c * cellW;
      canvas.drawLine(Offset(x, 0), Offset(x, rows * cellH), paint);
    }
    for (var r = 1; r < rows; r++) {
      final y = r * cellH;
      canvas.drawLine(Offset(0, y), Offset(cols * cellW, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.cols != cols ||
      old.rows != rows ||
      old.cellW != cellW ||
      old.cellH != cellH ||
      old.color != color;
}
