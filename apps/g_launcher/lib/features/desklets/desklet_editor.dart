import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/prefs/desklet_layout.dart';
import '../../data/prefs/launcher_prefs.dart';
import '../../data/prefs/prefs_repository.dart';
import '../../design/branded_message.dart';
import '../../engine/effective_theme.dart';
import '../../engine/widget_span.dart';
import 'package:g_launcher/i18n/i18n.dart';
// `show ThemePalette` is MANDATORY here, not tidiness: DockSide is declared in
// BOTH theme_spec.dart and dock_metrics.dart, and an unrestricted import of
// theme_spec into a file that also sees dock metrics is an ambiguous-import
// error that reads as if neither declaration exists.
import '../../engine/theme_spec.dart' show ThemePalette;
import 'desklet_cell.dart';
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
    required this.editing,
    required this.child,
  });

  final EffectiveTheme theme;
  final Desklet desklet;
  final double cellW;
  final double cellH;

  /// Whether the desktop is in edit mode.
  ///
  /// ─── ONE WIDGET FOR BOTH STATES, AND THAT IS THE WHOLE FIX ──────────────
  ///
  /// The surface used to swap between `_ResizableTile` at rest and this while
  /// editing. That swap is why hold-to-move could not work: a long press on a
  /// tile entered edit mode, edit mode rebuilt the surface, the swap unmounted
  /// the widget the finger was pressing, and the gesture died with it. The
  /// user's thumb was still down, and nothing was listening any more.
  ///
  /// So the tile no longer changes identity. Edit mode changes what it DRAWS,
  /// the drag survives across the transition, and a hold flows straight into a
  /// move the way it does on every other launcher.
  final bool editing;

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

  /// Held-down state for the remove badge.
  ///
  /// Move and resize get theirs free from `_moving` and `_resizing`, which are
  /// already set on pan start. Remove is a plain tap and had nothing equivalent,
  /// so it is the one handle that needed a flag of its own to light up. Without
  /// it, the destructive control would be the only one on the tile that gives no
  /// feedback before it fires.
  bool _removeDown = false;

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

  // ── hold to move ──────────────────────────────────────────────────────────
  //
  // ─── WHY THIS IS A LONG PRESS AND NOT A PAN ───────────────────────────────
  //
  // Moving a tile used to be `onPanStart` / `onPanUpdate`, and it felt dead for
  // three compounding reasons, none of which was fixable by tuning a number.
  //
  //  1. PAN SLOP. A PanGestureRecognizer does not fire until the finger has
  //     travelled kPanSlop, which is DOUBLE the ordinary touch slop, about 36
  //     logical pixels. So the tile sat perfectly still through the first third
  //     of an inch of movement and then jumped to catch up. That reads as lag
  //     even though nothing is slow.
  //
  //  2. THE HORIZONTAL SWIPE WON FIRST. GestureLayer wraps the whole desktop in
  //     a HorizontalDragGestureRecognizer, which declares at the ordinary 18px
  //     slop, on the horizontal axis, well before pan reaches 36 in any
  //     direction. Dragging a widget sideways therefore did not move the widget
  //     at all; it fired the swipe gesture. That one is fixed in gesture_layer.
  //
  //  3. THE DESKTOP LONG PRESS WON THE HOLD. The shell wraps the pager in a
  //     long press for the desktop menu. Holding a tile handed the arena to
  //     that recognizer, and pan, having lost, then ignored the drag entirely.
  //
  // A long press with move updates sidesteps all three. It claims the arena on
  // the hold, so nothing else can take the drag off it; and once won, its move
  // updates carry NO slop whatsoever, so the tile tracks from the first pixel.
  //
  // 300ms rather than the 500 default. Long enough not to trip on a scroll that
  // starts over a tile, short enough that the pick-up feels like a response
  // instead of a wait.
  static const _holdToLift = Duration(milliseconds: 300);

  /// How far the finger must travel for a hold to count as a MOVE rather than
  /// as a request for the menu.
  ///
  /// A hold that never moves is the menu gesture and always was. Without a
  /// threshold, the two would be the same gesture and the tiny tremor in any
  /// real thumb would decide which one you got.
  static const _dragThreshold = 8.0;

  void _liftStart(LongPressStartDetails _) {
    // A handle already owns this pointer. Handles sit at the tile's corners and
    // tuck INSIDE it when the tile is against an edge, so the two hit areas can
    // genuinely overlap; without this, holding the resize handle for 300ms
    // would start a move as well.
    if (_resizing) return;

    HapticFeedback.mediumImpact();
    setState(() {
      _moving = true;
      _drag = Offset.zero;
    });
  }

  void _liftMove(LongPressMoveUpdateDetails e) {
    if (!_moving) return;
    // ABSOLUTE, not accumulated deltas. offsetFromOrigin is measured from where
    // the press began, so a dropped frame cannot leave the tile permanently
    // offset from the finger the way a running sum of deltas can.
    setState(() => _drag = e.offsetFromOrigin);
  }

  void _liftEnd(LongPressEndDetails _) {
    if (!_moving) return;

    // A hold that went nowhere is the MENU, which is what a hold has always
    // meant on this desktop. Everything the menu offers (settings, stack,
    // remove) is still exactly one hold away, and now a hold that keeps moving
    // is a move instead of a dead gesture.
    if (_drag.distance < _dragThreshold) {
      setState(() {
        _drag = Offset.zero;
        _moving = false;
      });
      _openMenu();
      return;
    }

    _moveEnd();

    // Committed a move, so the desktop is being arranged: turn edit mode on and
    // select this tile, which is the state where its handles are showing. Done
    // AFTER the commit, so entering edit mode cannot rebuild anything out from
    // under the write.
    final edit = ref.read(deskletEditProvider.notifier);
    if (!widget.editing) edit.enter();
    edit.select(_d.id);
  }

  void _liftCancel() {
    if (!_moving) return;
    setState(() {
      _drag = Offset.zero;
      _moving = false;
    });
  }

  void _openMenu() {
    // The tile's own rectangle, so the menu opens beside it rather than at the
    // bottom of the screen. Measured at press time because the tile moves
    // whenever the grid reflows.
    final box = context.findRenderObject() as RenderBox?;
    final anchor =
        (box != null && box.hasSize) ? box.localToGlobal(Offset.zero) & box.size : null;
    showDeskletMenu(context, ref, widget.theme, _d, anchor: anchor);
  }

  // ── resize ────────────────────────────────────────────────────────────────

  /// May this tile be resized at all?
  ///
  /// True for everything except a hosted AppWidget whose provider declared
  /// RESIZE_NONE on BOTH axes. Our own desklets have no such concept: their
  /// limits come from the kind and every kind is resizable within them.
  ///
  /// Reads `resizeMode` straight from config rather than through the resolver,
  /// because it needs no cell and must answer during a build where the measured
  /// cell may not be published yet. Absent config reads as 0, which would say
  /// "not resizable" for the wrong reason, so the bare absence of the key is
  /// treated as permissive: a placement written before the version-2 reset
  /// cannot exist, but a hand-authored starter desktop can.
  bool get _canResize {
    if (_d.kind != 'appwidget') return true;
    final raw = _d.config[WidgetConfigKeys.resizeMode];
    if (raw == null) return true;
    final mode = (raw as num).toInt();
    return WidgetResize.canResizeX(mode) || WidgetResize.canResizeY(mode);
  }

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

    // ─── A HOSTED WIDGET'S OWN LIMITS, BEFORE THE ENGINE'S ────────────────
    //
    // `DeskletKinds.appWidget` declares a deliberately generous range because
    // it is one kind standing in for every widget on the phone. The real floor
    // and ceiling are per PROVIDER: `minResizeWidthDp` is where a widget starts
    // clipping its own layout, and `resizeMode` says whether an axis may be
    // dragged at all.
    //
    // Pre-clamping here rather than only inside `DeskletLayout.resize` is not
    // duplication, it is what keeps the message below honest. A drag that hits
    // the provider's ceiling comes back with an unchanged span, which is
    // indistinguishable from a collision at the call site; reporting "no room"
    // for a widget that simply cannot get any bigger would be a lie, and the
    // handle stopping is already the correct feedback. Same reasoning the kind
    // ceiling has always had, extended to the provider.
    //
    // The cell arrives from `deskletCellProvider` and NOT from
    // DeskletSurfaceView: the surface imports this file, so reaching back for
    // its constant would close an import cycle. The measured cell is published
    // precisely so readers on this side of that arrow can have it.
    final cell = ref.read(deskletCellProvider);
    if (_d.kind == 'appwidget' && cell != null) {
      final limits = WidgetSpanResolver.resolve(
        WidgetSpanResolver.footprintFromConfig(_d.config),
        cell: cell,
        colFactor: DeskletLayout.colFactor,
        rowFactor: DeskletLayout.rowFactor,
      );
      final wantX = (_d.spanX + dx).clamp(limits.minSpanX, limits.maxSpanX);
      final wantY = (_d.spanY + dy).clamp(limits.minSpanY, limits.maxSpanY);
      if (wantX == _d.spanX && wantY == _d.spanY) {
        // Already at its own edge. Record that a person chose this size
        // anyway, so the automatic re-derive stops overruling them later, and
        // let the handle's refusal to grow be the whole message.
        final marked = DeskletLayout.resize(
          before,
          id: _d.id,
          spanX: _d.spanX,
          spanY: _d.spanY,
          cols: widget.theme.deskletCols,
          rows: widget.theme.deskletRows,
          cell: cell,
          byUser: true,
        );
        HapticFeedback.selectionClick();
        if (!identical(marked, before)) _edit((_) => marked);
        return;
      }
    }

    final after = DeskletLayout.resize(
      before,
      id: _d.id,
      spanX: _d.spanX + dx,
      spanY: _d.spanY + dy,
      cols: widget.theme.deskletCols,
      rows: widget.theme.deskletRows,
      // Both optional and both additive. `cell` lets the engine enforce the
      // provider's limits as well as the kind's; `byUser` records that a person
      // chose this size, which is what stops `reflowWidgets` re-deriving over
      // it the next time the grid changes. Folded into this one call so a
      // resize is a single write rather than two.
      cell: cell,
      byUser: true,
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
              child: RawGestureDetector(
                // TRANSLUCENT, so a tile that owns an onTap keeps it while the
                // desktop is at rest: the note opens its editor, the search
                // tile opens the drawer. Only edit mode takes those away, via
                // the IgnorePointer below.
                behavior: HitTestBehavior.translucent,
                // ─── RAW, BECAUSE THE DELAY IS THE POINT ──────────────
                //
                // GestureDetector.onLongPress hardcodes the 500ms default and
                // gives no way to shorten it. A pick-up that takes half a
                // second is the single largest part of what "not responsive"
                // meant here, so the recognizer is built directly.
                gestures: <Type, GestureRecognizerFactory>{
                  LongPressGestureRecognizer:
                      GestureRecognizerFactoryWithHandlers<
                          LongPressGestureRecognizer>(
                    () => LongPressGestureRecognizer(duration: _holdToLift),
                    (r) => r
                      ..onLongPressStart = _liftStart
                      ..onLongPressMoveUpdate = _liftMove
                      ..onLongPressEnd = _liftEnd
                      ..onLongPressCancel = _liftCancel,
                  ),
                  // Tap only means something while editing, where it selects
                  // and deselects. At rest the tile's own children own their
                  // taps, and registering a competing recognizer here would
                  // make a note take two taps to open.
                  if (widget.editing)
                    TapGestureRecognizer:
                        GestureRecognizerFactoryWithHandlers<
                            TapGestureRecognizer>(
                      () => TapGestureRecognizer(),
                      (r) => r.onTap = () => ref
                          .read(deskletEditProvider.notifier)
                          .select(selected ? null : _d.id),
                    ),
                },
                child: _Frame(
                  palette: p,
                  editing: widget.editing,
                  selected: selected,
                  lifted: _moving || _resizing,
                  // IGNORE POINTERS ON THE TILE CONTENT WHILE EDITING.
                  //
                  // In edit mode the tile itself must not be interactive: the
                  // editor owns tap (select), hold (move) and the handles.
                  // Without this a hosted AppWidget (an AndroidView, so a
                  // PlatformView) claims the touch and eats the drag, so you
                  // cannot move a widget around the screen; a note or search
                  // tile would also swallow the tap that is meant to select it.
                  //
                  // CONDITIONAL now, where it used to be unconditional, because
                  // this widget renders at rest too. Ignoring pointers all the
                  // time would make every interactive desklet permanently dead.
                  child: widget.editing
                      ? IgnorePointer(child: widget.child)
                      : widget.child,
                ),
              ),
            ),

            // ─── HANDLES SIT WHERE THERE IS ROOM FOR THEM ──────────────
            //
            // The three corners used to be hardcoded: remove top-left, move
            // top-right, resize bottom-right, each at -10 so half the badge
            // hangs outside the tile. That is correct for a tile in the middle
            // of the grid and wrong for every tile against an edge, where the
            // overhanging half lands off the workspace and the handle becomes
            // unhittable. The bottom row and the first column are exactly where
            // a clock or a monitor tends to live, so the broken case was the
            // common one.
            //
            // So the corners are RESOLVED per tile. Each handle carries a
            // preference order, they are allocated in turn, and a corner that
            // would clip is skipped in favour of the next free one. Move now
            // prefers bottom-left, which is the reachable corner on a phone and
            // leaves the top of the tile clear to read while you drag it.
            //
            // A tile that fills the whole grid clips all four, so the resolver
            // cannot fall back forever: the last resort tucks the handle INSIDE
            // the tile edge instead of outside it. Slightly cramped and always
            // reachable beats correctly placed and off the screen.
            if (widget.editing && selected) ...[
              for (final placed in _resolveHandles(
                _d,
                cols: widget.theme.deskletCols,
                rows: widget.theme.deskletRows,
              ).entries)
                // ─── NO HANDLE ON A WIDGET THAT CANNOT BE RESIZED ────────
                //
                // `resizeMode` of RESIZE_NONE is a real declaration and a
                // handful of widgets make it. Offering the handle anyway means
                // a drag that visibly grows the tile and then snaps entirely
                // back on release, which reads as a broken control rather than
                // an enforced limit. Nothing to grab is the honest answer.
                //
                // Only the resize role is filtered. Move and remove stay: a
                // fixed-size widget can still be repositioned and deleted.
                if (!(placed.key == _HandleRole.resize && !_canResize))
                  (switch (placed.key) {
                  // ─── A LISTENER, NOT A PAN RECOGNIZER ─────────────
                  //
                  // Same complaint as the move drag and a worse version of it:
                  // kPanSlop meant the corner had to travel about 36 logical
                  // pixels before the tile grew by a single cell, on a grid
                  // whose cells are roughly 42 by 47. So the first cell of
                  // every resize was free and invisible, and the handle felt
                  // stuck to the tile.
                  //
                  // A handle is a dedicated target with nothing to disambiguate
                  // against, so there is nothing for an arena to decide and a
                  // raw Listener is the honest tool: it tracks from the first
                  // pixel of movement, with no threshold at all.
                  //
                  // Safe here only because the two recognizers that used to
                  // steal this pointer are now gone: the desktop long press is
                  // not built in edit mode, and GestureLayer stands down. A
                  // Listener does not enter the arena, so it cannot defend
                  // itself against either.
                  _HandleRole.resize => _positioned(
                      placed.value,
                      child: Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: (_) {
                          HapticFeedback.selectionClick();
                          setState(() => _resizing = true);
                        },
                        onPointerMove: (e) => setState(() {
                          _grow = Size(
                            _grow.width + e.delta.dx,
                            _grow.height + e.delta.dy,
                          );
                        }),
                        onPointerUp: (_) => _resizeEnd(),
                        onPointerCancel: (_) => setState(() {
                          _grow = Size.zero;
                          _resizing = false;
                        }),
                        child: _Handle(
                          palette: p,
                          icon: Icons.open_in_full,
                          // The flag the resize drag already sets. A handle
                          // that lights up while it is doing its job is the
                          // whole feedback story: you can see WHICH control
                          // your thumb captured, which matters most on a small
                          // tile where three of them sit within a thumb-width.
                          active: _resizing,
                        ),
                      ),
                    ),

                  // ── A HANDLE FOR MOVING, NOT ONLY THE WHOLE TILE ────
                  //
                  // Panning the tile itself already moves it, and it still
                  // does; this changes nothing about that path. But an
                  // invisible affordance is one nobody finds: the tile shows a
                  // resize handle and a remove badge, so a user reasonably
                  // concludes that resizing and removing are what a selected
                  // tile offers, and reaches for the long-press menu to move.
                  //
                  // It drives the SAME _drag/_moveEnd path as the tile, so
                  // there is one move implementation and the grid snapping
                  // cannot diverge between them.
                  _HandleRole.move => _positioned(
                      placed.value,
                      child: Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: (_) {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _moving = true;
                            _drag = Offset.zero;
                          });
                        },
                        onPointerMove: (e) => setState(() => _drag += e.delta),
                        onPointerUp: (_) => _moveEnd(),
                        onPointerCancel: (_) => setState(() {
                          _drag = Offset.zero;
                          _moving = false;
                        }),
                        child: _Handle(
                          palette: p,
                          icon: Icons.open_with,
                          active: _moving,
                        ),
                      ),
                    ),

                  _HandleRole.remove => _positioned(
                      placed.value,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        // Down and up drive the highlight; the tap itself still
                        // does the work. Cancel is handled too, or a touch that
                        // slides off the badge would leave it lit forever on a
                        // control that never fired.
                        onTapDown: (_) => setState(() => _removeDown = true),
                        onTapCancel: () => setState(() => _removeDown = false),
                        // One removal, shared with the long-press menu.
                        //
                        // A hosted AppWidget owns a native allocation that has
                        // to be released or it leaks for the life of the
                        // install, and that knowledge used to live only here,
                        // in the badge that was then the only way to remove
                        // anything. Now that the menu can remove too, two
                        // copies of "remember to free the native thing" is one
                        // copy too many.
                        onTap: () {
                          setState(() => _removeDown = false);
                          removeDesklet(ref, widget.theme, _d);
                        },
                        child: _Handle(
                          palette: p,
                          icon: Icons.close,
                          danger: true,
                          size: _Handle.remove,
                          active: _removeDown,
                        ),
                      ),
                    ),
                }),
            ],
          ],
        ),
      ),
    );
  }
}

/// The four places a handle can sit.
enum _Corner { topLeft, topRight, bottomLeft, bottomRight }

/// The three handles a selected tile carries.
enum _HandleRole { remove, resize, move }

/// Where one handle ended up: which corner, and whether it had to tuck inside
/// the tile because that corner sits against the edge of the workspace.
typedef _Placement = ({_Corner corner, bool inset});

/// Which corners would push a handle off the workspace.
///
/// A handle overhangs its corner by [_overhang], so a tile in the first column
/// cannot carry one on its left and a tile on the last row cannot carry one
/// below. Computed in CELLS rather than pixels: the tile's own geometry already
/// knows whether it is against an edge, and asking the render box would mean
/// measuring during layout to decide what to lay out.
Set<_Corner> _clippedCorners(Desklet d, {required int cols, required int rows}) {
  final atLeft = d.col <= 0;
  final atTop = d.row <= 0;
  final atRight = d.col + d.spanX >= cols;
  final atBottom = d.row + d.spanY >= rows;

  return {
    if (atLeft || atTop) _Corner.topLeft,
    if (atRight || atTop) _Corner.topRight,
    if (atLeft || atBottom) _Corner.bottomLeft,
    if (atRight || atBottom) _Corner.bottomRight,
  };
}

/// Hand each handle a corner.
///
/// ─── THE ORDER OF THE PREFERENCES IS THE DESIGN ─────────────────────────────
///
/// Move starts BOTTOM-LEFT: it is the corner a thumb reaches without covering
/// the tile, and dragging from the bottom of something you are positioning
/// leaves the thing itself visible above your hand. Resize keeps bottom-right,
/// where dragging away from the origin grows the tile, which is the only corner
/// where the gesture and the result point the same way. Remove keeps top-left,
/// furthest from both.
///
/// Allocation runs remove, then resize, then move. Remove goes first because it
/// is the one handle that must never be hard to hit or easy to hit by accident,
/// so it should not inherit whatever is left over. On a tile with room, the
/// three land on their preferred corners and the fourth stays empty.
///
/// A clipped corner is SKIPPED, not reassigned to a neighbour that is also
/// clipped: the fallback walks the whole preference list. When every corner
/// clips, which is a tile spanning the entire grid, the last resort keeps the
/// preferred corner and marks it inset so the caller draws it inside the tile
/// rather than off the screen.
Map<_HandleRole, _Placement> _resolveHandles(
  Desklet d, {
  required int cols,
  required int rows,
}) {
  const preferences = <_HandleRole, List<_Corner>>{
    _HandleRole.remove: [
      _Corner.topLeft,
      _Corner.topRight,
      _Corner.bottomLeft,
      _Corner.bottomRight,
    ],
    _HandleRole.resize: [
      _Corner.bottomRight,
      _Corner.topRight,
      _Corner.bottomLeft,
      _Corner.topLeft,
    ],
    _HandleRole.move: [
      _Corner.bottomLeft,
      _Corner.topRight,
      _Corner.topLeft,
      _Corner.bottomRight,
    ],
  };

  final clipped = _clippedCorners(d, cols: cols, rows: rows);
  final taken = <_Corner>{};
  final out = <_HandleRole, _Placement>{};

  for (final role in _HandleRole.values) {
    final wanted = preferences[role]!;

    _Corner? corner;
    var inset = false;

    // First choice: free, and far enough from the edge to hang outside.
    for (final c in wanted) {
      if (!taken.contains(c) && !clipped.contains(c)) {
        corner = c;
        break;
      }
    }

    // Second choice: free, but against an edge, so it tucks inside instead.
    if (corner == null) {
      inset = true;
      for (final c in wanted) {
        if (!taken.contains(c)) {
          corner = c;
          break;
        }
      }
    }

    // Cannot happen with three handles and four corners. The floor is here so
    // that a fourth handle added later lands on its own preferred corner
    // rather than throwing on a null.
    corner ??= wanted.first;

    taken.add(corner);
    out[role] = (corner: corner, inset: inset);
  }

  return out;
}

/// How far a handle hangs past the tile's corner. Half of it outside is what
/// makes it read as attached to the tile rather than drawn on top of it.
const double _overhang = -10;

/// Where it sits instead when that corner is against the workspace edge. A
/// small positive inset, so the badge lands just inside the tile's own border.
const double _tuck = 2;

Positioned _positioned(_Placement at, {required Widget child}) {
  final o = at.inset ? _tuck : _overhang;

  return switch (at.corner) {
    _Corner.topLeft => Positioned(left: o, top: o, child: child),
    _Corner.topRight => Positioned(right: o, top: o, child: child),
    _Corner.bottomLeft => Positioned(left: o, bottom: o, child: child),
    _Corner.bottomRight => Positioned(right: o, bottom: o, child: child),
  };
}

/// The dashed-ish outline that says "this is movable".
class _Frame extends StatelessWidget {
  const _Frame({
    required this.palette,
    required this.editing,
    required this.selected,
    required this.lifted,
    required this.child,
  });

  final ThemePalette palette;

  /// Draw the edit chrome at all.
  ///
  /// This widget renders at rest now, so the outline and the wash have to be
  /// able to switch off. What stays on in both states is the LIFT: a tile held
  /// and dragged on a desktop that is not yet in edit mode still has to look
  /// picked up, and the shadow is what says so before any outline appears.
  final bool editing;

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
        color: palette.onDark.withValues(
          alpha: editing
              ? (lifted ? 0.14 : 0.06)
              // At rest the tile paints nothing of its own, except while it is
              // actually being carried.
              : (lifted ? 0.14 : 0),
        ),
        borderRadius: BorderRadius.circular(10),
        border: editing
            ? Border.all(
                color: selected
                    ? palette.accent
                    : palette.onDark.withValues(alpha: 0.28),
                width: selected ? 1.6 : 1,
              )
            : null,
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
      // one: you are arranging the thing, not a box labelled with its name.
      //
      // NO IgnorePointer here any more. It moved up to the caller, which is the
      // only place that knows whether the desktop is being edited; leaving it
      // here would have made every interactive desklet dead at rest, since this
      // frame now draws in both states.
      child: child,
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle({
    required this.palette,
    required this.icon,
    this.danger = false,
    this.size = _base,
    this.active = false,
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

  /// Held down, or driving a live drag.
  ///
  /// ─── WHY A HANDLE HAS TO ANSWER BACK ────────────────────────────────────
  ///
  /// Three targets sit within a thumb-width of each other on a small tile, and
  /// two of them are drags whose first few pixels look identical to a missed
  /// touch. So a press that captured nothing and a press that captured the
  /// wrong control were indistinguishable until something moved, by which point
  /// the mistake is already made and one of these controls deletes the widget.
  ///
  /// Lighting the captured one says WHICH action is now in progress before it
  /// has visibly done anything, which is the whole request: the handles should
  /// communicate the action the user is about to take.
  final bool active;

  @override
  Widget build(BuildContext context) {
    final base = danger ? palette.bar : palette.accent;

    // Toward the palette's own foreground rather than toward white: a fixed
    // white lift reads as a different material on a light-chrome distro, where
    // onDark resolves to something dark and the handle would flash pale against
    // its own theme.
    final fill = active ? Color.lerp(base, palette.onDark, 0.26)! : base;

    return AnimatedScale(
      scale: active ? 1.15 : 1,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: fill,
          shape: BoxShape.circle,
          border: Border.all(
            color: palette.onDark.withValues(alpha: active ? 0.9 : 0.5),
            width: active ? 2 : 1,
          ),
          // A SHADOW IS NOT A SURFACE, so it does not follow the palette into
          // light mode, for the same reason _Frame's does not. Shadows are dark
          // on every desktop because they are absence of light, not a colour.
          boxShadow: active
              ? const [
                  BoxShadow(
                    color: Color(0x59000000), // theme-exempt: a shadow is not a surface
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ]
              : null,
        ),
        // Derived rather than a second constant, so a handle cannot be resized
        // without its glyph following.
        child: Icon(icon, size: size * 0.53, color: palette.onDark),
      ),
    );
  }
}
