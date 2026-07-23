import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/prefs/desklet_layout.dart';
import '../../data/prefs/launcher_prefs.dart';
import '../../data/prefs/prefs_repository.dart';
import '../../design/branded_message.dart';
import '../../engine/effective_theme.dart';
// `show ThemePalette` is MANDATORY here, not tidiness: DockSide is declared in
// BOTH theme_spec.dart and dock_metrics.dart, and an unrestricted import of
// theme_spec into a file that also sees dock metrics is an ambiguous-import
// error that reads as if neither declaration exists.
import '../../engine/theme_spec.dart' show ThemePalette;
import '../../platform/launcher_api.g.dart' as api;
import 'desklet_edit.dart';

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
      cols: widget.theme.cols,
      rows: widget.theme.rows,
    );

    // Identity, not equality. The engine returns the SAME object on refusal,
    // which is the cheapest possible signal and the reason every refusal path
    // in DeskletLayout is written to return `p` rather than a copy.
    if (identical(after, before)) {
      HapticFeedback.heavyImpact();
      context.showMessage('No room there');
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
      cols: widget.theme.cols,
      rows: widget.theme.rows,
    );

    // A resize that only hit the kind's ceiling is NOT a failure — the engine
    // clamped it and the tile stops growing, which is what a handle should do.
    // Only a collision comes back identical, and only that is worth saying.
    if (identical(after, before)) {
      HapticFeedback.heavyImpact();
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

    return Transform.translate(
      offset: _drag,
      child: SizedBox(
        width: w,
        height: h,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
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
              Positioned(
                left: -10,
                top: -10,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    ref.read(deskletEditProvider.notifier).select(null);
                    // A hosted AppWidget owns a native allocation; release it or
                    // it leaks for the life of the install. Other kinds are pure
                    // Dart and have nothing to free.
                    if (_d.kind == 'appwidget') {
                      final id = _d.config['widgetId'];
                      if (id is int) {
                        api.LauncherHostApi().removeWidget(id);
                      }
                    }
                    _edit((prefs) => DeskletLayout.remove(prefs, _d.id));
                  },
                  child: _Handle(palette: p, icon: Icons.close, danger: true),
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
        boxShadow: lifted
            ? [
                BoxShadow(
                  color: palette.bgBottom.withValues(alpha: 0.5),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
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
  });

  final ThemePalette palette;
  final IconData icon;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: danger ? palette.bar : palette.accent,
        shape: BoxShape.circle,
        border: Border.all(color: palette.onDark.withValues(alpha: 0.5)),
      ),
      child: Icon(icon, size: 14, color: palette.onDark),
    );
  }
}
