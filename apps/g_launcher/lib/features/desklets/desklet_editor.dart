import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/prefs/desklet_layout.dart';
import '../../data/prefs/launcher_prefs.dart';
import '../../data/prefs/prefs_repository.dart';
import '../../design/branded_message.dart';
import '../../engine/effective_theme.dart';
import 'package:g_launcher/i18n/i18n.dart';
// `show ThemePalette` is MANDATORY here, not tidiness: DockSide is declared in
// BOTH theme_spec.dart and dock_metrics.dart, and an unrestricted import of
// theme_spec into a file that also sees dock metrics is an ambiguous-import
// error that reads as if neither declaration exists.
import '../../engine/theme_spec.dart' show ThemePalette;
import 'desklet_edit.dart';
import 'desklet_menu.dart';

/// One desklet, while the desktop is being edited. PHASE D4.
///
/// ─── THE PURE ENGINE DRIVES THE UI, NOT THE OTHER WAY ROUND ─────────────────
///
/// Nothing here decides whether a move or a resize is legal. Every gesture
/// converts pixels to CELLS, calls `DeskletLayout`, and compares the result by
/// identity: unchanged prefs means the engine refused, and the tile springs
/// back to where it was. That is why the engine returns `p` on refusal rather
/// than throwing, and it is why the drag preview is local state rather than a
/// write — a refused drop must leave no trace.
///
/// The alternative (let the widget decide, then persist) would give you two
/// implementations of the collision rules that agree until they do not, and the
/// disagreement would only be visible as a desktop that does not match itself.
///
/// ─── SNAP ON DROP, FREE WHILE DRAGGING ──────────────────────────────────────
///
/// The tile follows the finger continuously and lands on a cell. Snapping DURING
/// the drag makes a phone-sized grid feel like it is fighting you, because the
/// cells are large relative to the movement; snapping only on release keeps the
/// tile under the thumb the whole way and still guarantees a legal position.
class EditableDesklet extends ConsumerStatefulWidget {
  const EditableDesklet({
    super.key,
    required this.theme,
    required this.desklet,
    required this.cellW,
    required this.cellH,
    required this.child,
  });

  final EffectiveTheme theme;
  final Desklet desklet;
  final double cellW;
  final double cellH;
  final Widget child;

  @override
  ConsumerState<EditableDesklet> createState() => _EditableDeskletState();
}

class _EditableDeskletState extends ConsumerState<EditableDesklet> {
  /// Live pixel offset while a move drag is in flight. Never persisted.
  Offset _drag = Offset.zero;

  /// Live pixel growth while a resize drag is in flight.
  Size _grow = Size.zero;

  bool _moving = false;
  bool _resizing = false;

  Desklet get _d => widget.desklet;

  void _edit(LauncherPrefs Function(LauncherPrefs) f) {
    ref.read(prefsProvider(widget.theme.spec.id).notifier).edit(f);
  }

  // ── move ──────────────────────────────────────────────────────────────────

  void _moveEnd() {
    // Round rather than floor: a tile dragged 60% of a cell should land in the
    // next one. Flooring makes every drag feel like it fell short.
    final dc = (_drag.dx / widget.cellW).round();
    final dr = (_drag.dy / widget.cellH).round();

    setState(() {
      _drag = Offset.zero;
      _moving = false;
    });

    if (dc == 0 && dr == 0) return;

    final before = ref.read(prefsProvider(widget.theme.spec.id)).value;
    if (before == null) return;

    final after = DeskletLayout.move(
      before,
      id: _d.id,
      toPage: _d.page,
      toCol: _d.col + dc,
      toRow: _d.row + dr,
      cols: widget.theme.deskletCols,
      rows: widget.theme.deskletRows,
    );

    // Identity, not equality. The engine returns the SAME object on refusal,
    // which is the cheapest possible signal and the reason every refusal path
    // in DeskletLayout is written to return `p` rather than a copy.
    if (identical(after, before)) {
      HapticFeedback.heavyImpact();
      context.showMessage(context.t('desklets.noRoomThere'));
      return;
    }

    HapticFeedback.selectionClick();
    _edit((_) => after);
  }

  // ── resize ────────────────────────────────────────────────────────────────

  void _resizeEnd() {
    final dx = (_grow.width / widget.cellW).round();
    final dy = (_grow.height / widget.cellH).round();

    setState(() {
      _grow = Size.zero;
      _resizing = false;
    });

    if (dx == 0 && dy == 0) return;

    final before = ref.read(prefsProvider(widget.theme.spec.id)).value;
    if (before == null) return;

    final after = DeskletLayout.resize(
      before,
      id: _d.id,
      spanX: _d.spanX + dx,
      spanY: _d.spanY + dy,
      cols: widget.theme.deskletCols,
      rows: widget.theme.deskletRows,
    );

    // A resize that only hit the kind's ceiling is NOT a failure — the engine
    // clamped it and the tile stops growing, which is what a handle should do.
    // Only a collision comes back identical.
    //
    // AND IT NOW SAYS SO. This buzzed and returned in silence, so a widget that
    // would not grow because a neighbour was in the way was indistinguishable
    // from a resize handle that does not work, which is precisely how the
    // feature gets reported as broken. The move path has said "No room there"
    // all along; there was no reason for this one to stay quiet.
    if (identical(after, before)) {
      HapticFeedback.heavyImpact();
      if (mounted) context.showMessage(context.t('desklets.noRoomToGrow'));
      return;
    }

    HapticFeedback.selectionClick();
    _edit((_) => after);
  }

  @override
  Widget build(BuildContext context) {
    final edit = ref.watch(deskletEditProvider);
    final selected = edit.selected == _d.id;
    final p = widget.theme.palette;

    final w = _d.spanX * widget.cellW + _grow.width;
    final h = _d.spanY * widget.cellH + _grow.height;

    // The span this resize WOULD commit, by the same rounding `_resizeEnd`
    // uses. Derived from that one arithmetic rather than re-guessed, so the
    // number on screen and the number stored can never disagree; a chip that
    // says 4 x 3 and commits 4 x 4 is worse than no chip.
    final pendingX = _d.spanX + (_grow.width / widget.cellW).round();
    final pendingY = _d.spanY + (_grow.height / widget.cellH).round();
    // `_resizing`, the existing flag set on pan start, not `_grow != zero`:
    // the latter is false for the first few pixels of a drag, so the chip would
    // appear late and flicker at the moment the user most needs it.

    return Transform.translate(
      offset: _drag,
      child: SizedBox(
        width: w,
        height: h,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (_resizing)
              // ─── THE SIZE CHIP ────────────────────────────────────────
              //
              // Resize was a corner handle and a rectangle that grew, with
              // nothing saying where the boundary between one span and the next
              // fell. On the fine grid a cell is 42 by 47, so the difference
              // between committing 4 and committing 5 is a thumb's width and
              // entirely invisible.
              //
              // Below the tile rather than inside it: a widget being resized is
              // the thing you are looking at, and a label over its middle
              // covers exactly what you are judging.
              Positioned(
                left: 0,
                bottom: -26,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: p.bgBottom.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    child: Text(
                      '$pendingX x $pendingY',
                      style: TextStyle(
                        color: p.onDark,
                        fontSize: 11,
                        fontFamily: widget.theme.typography.mono,
                      ),
                    ),
                  ),
                ),
              ),
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => ref
                    .read(deskletEditProvider.notifier)
                    .select(selected ? null : _d.id),
                // Pan and not a long-press-drag: the long press already
                // happened, on the desktop, to get here. Requiring a second one
                // to pick a tile up would feel like the edit mode had not
                // actually started.
                onPanStart: (_) {
                  HapticFeedback.selectionClick();
                  ref.read(deskletEditProvider.notifier).select(_d.id);
                  setState(() => _moving = true);
                },
                onPanUpdate: (e) => setState(() => _drag += e.delta),
                onPanEnd: (_) => _moveEnd(),
                // A cancelled pan must not leave the tile stranded off-grid.
                onPanCancel: () => setState(() {
                  _drag = Offset.zero;
                  _moving = false;
                }),
                child: _Frame(
                  palette: p,
                  selected: selected,
                  lifted: _moving || _resizing,
                  // IGNORE POINTERS ON THE TILE CONTENT WHILE EDITING.
                  //
                  // EditableDesklet only ever renders in edit mode, so the tile
                  // itself must not be interactive here — the editor owns tap
                  // (select), pan (move) and the handles. Without this a hosted
                  // AppWidget (an AndroidView / PlatformView) claims the touch
                  // and eats the drag, so you cannot move a widget around the
                  // screen; a note or search tile would also swallow the tap
                  // that is meant to select it. Ignoring pointers on the child
                  // hands every gesture to the surrounding GestureDetector and
                  // the handles, which is exactly what edit mode wants.
                  child: IgnorePointer(child: widget.child),
                ),
              ),
            ),

            // Handles only on the selected tile. Showing them on every desklet
            // at once turns an eight-tile desktop into a field of targets, and
            // the remove badges become easy to hit by accident.
            if (selected) ...[
              Positioned(
                right: -10,
                bottom: -10,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (_) => setState(() => _resizing = true),
                  onPanUpdate: (e) => setState(() {
                    _grow = Size(
                      _grow.width + e.delta.dx,
                      _grow.height + e.delta.dy,
                    );
                  }),
                  onPanEnd: (_) => _resizeEnd(),
                  onPanCancel: () => setState(() {
                    _grow = Size.zero;
                    _resizing = false;
                  }),
                  child: _Handle(palette: p, icon: Icons.open_in_full),
                ),
              ),

              // ── A HANDLE FOR MOVING, NOT ONLY THE WHOLE TILE ──────────
              //
              // Panning the tile itself already moves it, and it still does;
              // this changes nothing about that path. But an invisible
              // affordance is one nobody finds: the tile shows a resize handle
              // and a remove badge, so a user reasonably concludes that
              // resizing and removing are what a selected tile offers, and
              // reaches for the long-press menu to move. The menu row had to
              // be renamed to "Move or resize" for exactly this reason, which
              // was a missing word standing in for a missing control.
              //
              // Top-right, so the three sit at three corners and none of them
              // overlaps another's touch target. It drives the SAME
              // _drag/_moveEnd path as the tile, so there is one move
              // implementation and the grid snapping cannot diverge between
              // them.
              Positioned(
                right: -10,
                top: -10,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (_) {
                    HapticFeedback.selectionClick();
                    setState(() => _moving = true);
                  },
                  onPanUpdate: (e) => setState(() => _drag += e.delta),
                  onPanEnd: (_) => _moveEnd(),
                  onPanCancel: () => setState(() {
                    _drag = Offset.zero;
                    _moving = false;
                  }),
                  child: _Handle(palette: p, icon: Icons.open_with),
                ),
              ),

              Positioned(
                left: -10,
                top: -10,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  // One removal, shared with the long-press menu.
                  //
                  // A hosted AppWidget owns a native allocation that has to be
                  // released or it leaks for the life of the install, and that
                  // knowledge used to live only here, in the badge that was
                  // then the only way to remove anything. Now that the menu can
                  // remove too, two copies of "remember to free the native
                  // thing" is one copy too many.
                  onTap: () => removeDesklet(ref, widget.theme, _d),
                  child: _Handle(
                    palette: p,
                    icon: Icons.close,
                    danger: true,
                    size: _Handle.remove,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The dashed-ish outline that says "this is movable".
class _Frame extends StatelessWidget {
  const _Frame({
    required this.palette,
    required this.selected,
    required this.lifted,
    required this.child,
  });

  final ThemePalette palette;
  final bool selected;
  final bool lifted;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      decoration: BoxDecoration(
        // The theme's accent, so edit mode looks like Ubuntu's edit mode under
        // Ubuntu and Breeze's under KDE. A fixed blue here would be the one
        // place the whole app forgot it was a distro.
        color: palette.onDark.withValues(alpha: lifted ? 0.14 : 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected
              ? palette.accent
              : palette.onDark.withValues(alpha: 0.28),
          width: selected ? 1.6 : 1,
        ),
        // A SHADOW IS NOT A SURFACE, so it does not follow the palette into
        // light mode. This was the theme's own background at half alpha, which
        // reads as a deep aubergine drop under a dark desktop and as nothing at
        // all under a light one: a lifted tile stopped looking lifted the
        // moment the palette went pale. Shadows are dark everywhere, on every
        // desktop, because they are absence of light rather than a colour.
        boxShadow: lifted
            ? const [
                BoxShadow(
                  color: Color(0x66000000), // theme-exempt: a shadow is not a surface
                  blurRadius: 18,
                  offset: Offset(0, 6),
                ),
              ]
            : null,
      ),
      // The desklet keeps rendering underneath. Editing a live clock rather
      // than a grey placeholder is what makes the layout decision an informed
      // one — you are arranging the thing, not a box labelled with its name.
      child: IgnorePointer(child: child),
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle({
    required this.palette,
    required this.icon,
    this.danger = false,
    this.size = _base,
  });

  /// The move and resize handles. 28 rather than the old 26 so the pair reads
  /// as a set with the larger remove badge beside them.
  static const _base = 28.0;

  /// Remove is BIGGER, and deliberately the odd one out.
  ///
  /// It sits at a corner, half of it outside the tile, and it is the only
  /// destructive control on the desktop. At 26 with a 14dp glyph it was under
  /// the 48dp Material minimum by a wide margin and the most-missed target on
  /// the screen. Bigger also reads as more consequential, which is honest: the
  /// other two rearrange, this one deletes.
  static const remove = 34.0;

  final ThemePalette palette;
  final IconData icon;
  final bool danger;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: danger ? palette.bar : palette.accent,
        shape: BoxShape.circle,
        border: Border.all(color: palette.onDark.withValues(alpha: 0.5)),
      ),
      // Derived rather than a second constant, so a handle cannot be resized
      // without its glyph following.
      child: Icon(icon, size: size * 0.53, color: palette.onDark),
    );
  }
}
