import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g_launcher/i18n/i18n.dart';

import '../../../data/prefs/home_layout.dart';
import '../../../design/components/anchored_menu.dart';
import '../../../design/liquid_glass.dart';
import '../../../engine/theme_spec.dart' show ThemePalette;
import '../../dock/aqua_dock_metrics.dart';
import '../../dock/dock_extent.dart';
import '../../dock/dock_motion.dart';
import '../../drawer/drawer_drag.dart';
import '../gnome/gnome_dock.dart' show DockEntry;
import '../workspaces/edge_paging.dart' show homeDragActiveProvider;

/// The magnifying dock.
///
/// Geometry comes entirely from [AquaDockMetrics], which is pure functions with
/// no Flutter imports and its own unit tests. This widget is paint plus one
/// piece of state: where the finger is. Keeping the math out of here is what
/// lets the clipping behaviour be tested across every app count and every touch
/// position without a device, which is the only practical way to be sure a
/// magnifying dock never overflows its own bounds.
///
/// [DockEntry] is reused from the GNOME dock rather than redeclared. It is
/// already presentation-free — it holds a Widget, not a component key — so both
/// docks can render the same entries. It arguably belongs in `features/dock/`
/// now that two shells use it; moving it would touch the GNOME dock's golden
/// tests, so it stays put and is imported.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// WHY Listener AND NOT GestureDetector.
///
/// Magnification is not a gesture. It is a continuous visual response to where
/// a pointer happens to be, and it must not compete in the gesture arena — a
/// horizontal drag across the dock would otherwise be contested by the shell's
/// swipe handlers, and whichever won, the other would feel broken.
///
/// [Listener] sits below the arena entirely: it sees every pointer event
/// regardless of who eventually claims the gesture. With `behavior: opaque` the
/// dock also absorbs those pointers so they never reach the desktop underneath.
/// Taps stay on the individual slots, where a normal GestureDetector is exactly
/// right, because a tap IS a gesture.
///
/// The shell additionally places this dock OUTSIDE its GestureLayer, so a scrub
/// along the dock cannot register as a desktop swipe at all.
/// ─────────────────────────────────────────────────────────────────────────────
/// How this dock sits. See [ThemeLayout.dockStyle].
enum AquaDockStyle {
  /// Plank: on the bottom edge, square-topped, no swell. elementary.
  flat,

  /// Deepin's fashion dock: off the edge, fully rounded, translucent, no swell.
  floating,

  /// The Mac: off the edge AND swelling under the finger. What this dock has
  /// always drawn, and therefore the engine default.
  magnified;

  /// Unknown values answer [magnified], the same drop-not-fatal contract every
  /// other parse in the engine keeps. `LayoutResolver` has already narrowed
  /// this to the three, so a stranger here means a build older than the theme.
  static AquaDockStyle parse(String raw) => switch (raw) {
        'flat' => AquaDockStyle.flat,
        'floating' => AquaDockStyle.floating,
        _ => AquaDockStyle.magnified,
      };

  /// Does the pointer change the LAYOUT, not just the paint?
  ///
  /// The two quiet styles do not merely look different, they stop listening.
  /// Without this the handlers would still run and the slots would still
  /// resize, so a flat plank would shuffle its icons under a finger that was
  /// trying to drag one, and nothing on screen would explain why.
  /// ─── MOVED TO `AquaDock._swells` ───────────────────────────────────────
  ///
  /// Kept as a getter rather than deleted because the answer is still true of
  /// the VALUE: a pack authoring `magnified` does magnify, since the resolver
  /// seeds `dockHover` from it. What changed is who asks. The dock reads the
  /// hover field, so a user who turns magnification off on a Deepin pack gets a
  /// dock that still sits the way Deepin's does.
  @Deprecated('Read EffectiveTheme.dockHover; see AquaDock.hover.')
  bool get swells => this == AquaDockStyle.magnified;
}

/// Where a drop on the dock lands, among the entries it was NOT holding.
///
/// [order] is the dock's visible entries with the dragged one already taken
/// out, and [gap] is the index in that list the arrival goes in front of
/// (`order.length` for the end). Ids, not prefs indices, for the reason
/// `HomeLayout.reorderDockKeys` gives: the dock draws a filtered view.
typedef DockDropAt = void Function(
  DrawerDrag drag,
  List<String> order,
  int gap,
);

class AquaDock extends StatefulWidget {
  const AquaDock({
    super.key,
    required this.entries,
    required this.palette,
    required this.style,
    required this.hover,
    required this.press,
    required this.onLaunchpad,
    this.opacity = 1.0,
    this.onDropAt,
    this.onDropOnto,
    this.onFull,
    this.onRemove,
    this.capacity = AquaDockMetrics.maxApps,
    this.folders = false,
    this.editing = false,
    this.tray,
    this.trayWidth = 0,
    this.glass = false,
    this.glassDark = false,
    this.launcherSlot = true,
    this.restSlot,
    this.restSpacing,
  });

  /// The home screen's icon size, which makes this a PHONE dock; null keeps
  /// the Mac's 46dp dock.
  ///
  /// ─── A PHONE'S DOCK IS THE HOME GRID'S LAST ROW ───────────────────────
  ///
  /// On a phone the dock icons are the home icons: the same size, sitting in
  /// the same columns, on a plate that runs edge to edge inside the grid's
  /// own margins. No running dots, no Mac swell, icons centred in the plate
  /// with even glass above and below. Fewer than a full row sit centred at
  /// the same spacing, the way a phone dock of three looks.
  final double? restSlot;

  /// The gap between two dock icons in a phone dock: the home grid's column
  /// pitch less one icon, so a full dock lines up with the columns above it.
  final double? restSpacing;

  /// The dock's own tray, drawn after a divider at the right end: Deepin's
  /// fashion dock, which carries the status a desktop with no top bar has
  /// nowhere else to put. Null for a dock without one.
  ///
  /// ─── AND THE LAUNCHER MOVES TO THE FRONT ───────────────────────────────
  ///
  /// A dock with a tray is a taskbar-dock, and on those the launcher leads:
  /// Deepin's is its first icon. A Mac keeps Launchpad and Trash at the far
  /// end, which is where the tray now sits, so the two cannot share it.
  final Widget? tray;

  /// The tray's width, so the slots are laid out in what is left rather than
  /// measured twice.
  final double trayWidth;

  /// Draw the panel as Liquid Glass. See `EffectiveTheme.glass`.
  final bool glass;

  /// The smoked glass of the Dark looks.
  final bool glassDark;

  /// Whether the dock ends with the all-apps button. False on a phone-style
  /// dock, which holds apps only. See `ThemeLayout.dockLauncher`.
  final bool launcherSlot;

  final List<DockEntry> entries;
  final ThemePalette palette;

  /// How this dock sits. See [AquaDockStyle].
  final AquaDockStyle style;

  /// How it responds to a finger, from `EffectiveTheme.dockHover`.
  ///
  /// ─── THE SWELL LEFT [style] ────────────────────────────────────────────
  ///
  /// `AquaDockStyle.magnified` meant two things at once: a corner radius and a
  /// swell. The radius is a way of SITTING and stays on the style; the swell is
  /// a RESPONSE and is one of seven now, so it moved to its own field.
  ///
  /// A pack that authored `dockStyle: "magnified"` still magnifies, because the
  /// resolver seeds this from that value. Nothing republishes.
  final String hover;

  /// What a slot does when it is tapped, from `EffectiveTheme.dockPress`.
  final String press;

  /// How solid the dock is, from `EffectiveTheme.dockOpacity`.
  ///
  /// Same multiply-into-the-authored-alpha rule as the GNOME dock, so an Aqua
  /// palette that authors its own translucency keeps it.
  final double opacity;

  /// Launchpad's own slot, pinned at the right end past a separator: the
  /// position a Mac keeps Trash in, and the one place in the dock that is not
  /// an app.
  final VoidCallback onLaunchpad;

  /// Something dropped into a GAP: an arrival from another surface, or one of
  /// this dock's own entries moved along it.
  ///
  /// ─── REORDER LIVES HERE NOW ────────────────────────────────────────────
  ///
  /// The old note on this dock said ordering had nowhere to draw a caret,
  /// because slots are positioned by index inside a Stack. That is exactly
  /// what makes a GAP cheap: lay the run out with one extra slot, leave that
  /// slot empty, and every other icon slides aside to show where the drop
  /// lands. No caret, the way a phone's dock does it.
  ///
  /// Null on a shell that does not accept drops, and that is also how the dock
  /// refuses one: the target never accepts, nothing parts, and the drag
  /// returns to where it started.
  final DockDropAt? onDropAt;

  /// An app held on the CENTRE of entry `ontoId` long enough to arm a folder.
  /// Only consulted when [folders] is on.
  final void Function(DrawerDrag drag, String ontoId)? onDropOnto;

  /// A new arrival let go over a dock that has no room for it. The dock shakes
  /// on its own; this is for the message.
  final VoidCallback? onFull;

  /// The edit-mode badge on an entry was tapped.
  final void Function(DockEntry entry, Rect? anchor)? onRemove;

  /// How many entries the dock holds. A gap only opens while there is room,
  /// or for one of the dock's own entries, which frees its slot as it lifts.
  final int capacity;

  /// Whether a held centre makes a folder, and folders may be dropped in.
  /// See `ThemeLayout.dockFolders`.
  final bool folders;

  /// Edit mode: every entry jiggles and carries the remove badge, like the
  /// home grid above it.
  final bool editing;

  @override
  State<AquaDock> createState() => _AquaDockState();
}

class _AquaDockState extends State<AquaDock> with TickerProviderStateMixin {
  /// Where the finger is along the dock, or null for at-rest.
  ///
  /// Local state on purpose. This changes on every pointer move, and lifting it
  /// into Riverpod would rebuild the whole shell at touch frequency to animate
  /// six icons. Nothing outside this widget needs to know.
  double? _focus;

  /// The panel's own left edge in global coordinates, so pointer positions can
  /// be converted into the dock-local space the metrics expect.
  final _panelKey = GlobalKey();

  /// The run the slots sit in, for converting a drag's pointer to slot space.
  final _runKey = GlobalKey();

  /// The same wobble the home grid draws, on its own ticker. One ticker for
  /// the whole dock, phase from each slot's index, for the grid's reason.
  late final AnimationController _jiggle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  );

  /// The refusal: a short shake when a full dock is offered one more.
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );

  // ─── DRAG STATE ─────────────────────────────────────────────────────────
  //
  // `DragTarget.onMove` reports where the dragged FEEDBACK is, and the
  // grid's folders anchor their feedback to the child rather than to the
  // pointer, so that offset is not the finger. A global pointer route reads
  // the finger itself, for every surface the drag could have started on.

  /// The last pointer position anywhere on screen.
  Offset? _pointer;

  /// The id of one of THIS dock's entries while it is being dragged.
  String? _lifted;

  /// Where that entry sat when it lifted, so a cancelled drag puts it back
  /// from there rather than flying in from a corner.
  AquaSlot? _liftedFrom;

  /// A drag is over the dock.
  bool _over = false;

  /// Where the drag would land among the entries it is not, or null.
  int? _gap;

  /// The entry whose centre the finger is over, or null.
  String? _onto;

  /// The finger has stayed on [_onto] long enough to make a folder.
  bool _armed = false;

  Timer? _arm;

  /// The run width from the last layout, and the app slots laid out in it,
  /// for hit-testing a drag between frames.
  double _available = 0;
  double _rest = AquaDockMetrics.baseSlot;
  double _spacing = AquaDockMetrics.gap;
  bool _phone = false;

  /// Slots in the run right now: the entries left, plus the gap if open.
  int appCount(bool gapOn) => _others.length + (gapOn ? 1 : 0);

  /// The gap between two slots for a run of [count].
  ///
  /// ─── A PHONE DOCK KEEPS THE HOME'S PITCH ──────────────────────────────
  ///
  /// Its icons sit at the home grid's column pitch ([AquaDock.restSpacing]),
  /// whatever their number, centred. Spreading three apps across the plate
  /// read as a big dock with small icons far apart; the icons themselves are
  /// what grow (see `iconFillProvider`), not the gaps.
  double _spacingFor(int count) => _phone
      ? (widget.restSpacing ?? AquaDockMetrics.gap)
      : AquaDockMetrics.gap;
  List<(String, AquaSlot)> _shown = const [];

  @override
  void initState() {
    super.initState();
    GestureBinding.instance.pointerRouter.addGlobalRoute(_track);
    _syncJiggle();
  }

  @override
  void didUpdateWidget(AquaDock old) {
    super.didUpdateWidget(old);
    if (old.editing != widget.editing) _syncJiggle();
  }

  @override
  void dispose() {
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_track);
    _arm?.cancel();
    _jiggle.dispose();
    _shake.dispose();
    super.dispose();
  }

  void _track(PointerEvent e) {
    if (e is PointerMoveEvent || e is PointerDownEvent) _pointer = e.position;
  }

  void _syncJiggle() {
    if (widget.editing && !_jiggle.isAnimating) {
      _jiggle.repeat(reverse: true);
    } else if (!widget.editing && _jiggle.isAnimating) {
      _jiggle
        ..stop()
        ..value = 0;
    }
  }

  void _setFocusFrom(Offset globalPosition) {
    final box = _panelKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(globalPosition);
    setState(() => _focus = local.dx - _padding);
  }

  void _clearFocus() {
    if (_focus == null) return;
    setState(() => _focus = null);
  }

  /// Panel padding, subtracted so the metrics see a run starting at zero.
  static const _padding = 8.0;

  /// The panel's hairline. Counted in its width, see where the panel is built.
  static const _border = 1.0;

  /// A phone dock's side margin: the home grid's own padding, so the plate's
  /// edges line up with the grid's.
  static const _phoneMargin = 12.0;

  /// How long a finger rests on an icon's centre before a folder is armed.
  static const _armDelay = Duration(milliseconds: 450);

  /// How close to a centre counts as ON the icon rather than beside it, as a
  /// share of the slot. Inside this the gap stays put; outside it the gap
  /// follows the finger.
  static const _centreShare = 0.28;

  /// Does this dock's row swell under the finger?
  bool get _swells => widget.hover == 'magnify';

  /// Is a drag in progress on, or from, this dock?
  bool get _dragging => _lifted != null || _over;

  /// The entries a drop is placed among: everything but the lifted one.
  List<DockEntry> get _others => [
        for (final e in widget.entries)
          if (e.id != _lifted) e,
      ];

  /// Room for one more: always for the dock's own entry, which freed a slot.
  bool _roomFor(DrawerDrag drag) =>
      drag.from == DragOrigin.dock || _others.length < widget.capacity;

  bool _accepts(DrawerDrag drag) =>
      widget.onDropAt != null &&
      switch (drag) {
        AppDrag() => true,
        FolderDrag() => widget.folders,
      };

  int get _launcherCount => widget.launcherSlot ? 1 : 0;
  bool get _launcherFirst => widget.tray != null && widget.launcherSlot;

  /// Layout slot of app position [i] (the launcher may lead).
  int _slotIndex(int i) => _launcherFirst ? i + 1 : i;

  void _clearOnto() {
    _arm?.cancel();
    _onto = null;
    _armed = false;
  }

  void _resetDrag() {
    _clearOnto();
    _over = false;
    _gap = null;
  }

  /// The drag moved over the dock. Decide between a gap and a folder.
  void _hover(DrawerDrag drag) {
    final box = _runKey.currentContext?.findRenderObject() as RenderBox?;
    final p = _pointer;
    if (box == null || p == null || !box.hasSize) return;
    final x = box.globalToLocal(p).dx;
    final others = _others;
    final draggedId = switch (drag) {
      AppDrag(:final componentKey) => componentKey,
      FolderDrag(:final folderId) => HomeLayout.dockFolderKey(folderId),
    };

    // ─── ON A CENTRE: THE FOLDER, AND THE GAP HOLDS STILL ──────────────
    //
    // Checked against the slots as they are drawn RIGHT NOW, gap included.
    // Recomputing the gap while the finger sits on an icon would slide that
    // icon out from under it, and the arm timer would never get to fire.
    if (widget.folders && drag is AppDrag) {
      String? onto;
      for (final (id, s) in _shown) {
        if (id != draggedId && (x - s.center).abs() < s.size * _centreShare) {
          onto = id;
        }
      }
      if (onto != null) {
        if (onto != _onto) {
          setState(() {
            _clearOnto();
            _onto = onto;
          });
          _arm = Timer(_armDelay, () {
            if (!mounted || _onto != onto) return;
            HapticFeedback.selectionClick();
            setState(() => _armed = true);
          });
        }
        return;
      }
    }

    int? gap;
    if (_roomFor(drag)) {
      final n = others.length + 1;
      final slots = AquaDockMetrics.layout(
        count: n + _launcherCount,
        available: _available,
        restSize: _rest,
        spacing: _spacingFor(n),
      );
      var best = double.infinity;
      for (var i = 0; i < n; i++) {
        final d = (slots[_slotIndex(i)].center - x).abs();
        if (d < best) {
          best = d;
          gap = i;
        }
      }
    }
    if (gap != _gap || _onto != null) {
      setState(() {
        _clearOnto();
        _gap = gap;
      });
    }
  }

  void _drop(DrawerDrag drag) {
    final order = [for (final e in _others) e.id];
    final onto = _onto;
    final armed = _armed;
    final gap = _gap;
    final room = _roomFor(drag);
    setState(_resetDrag);

    HapticFeedback.mediumImpact();
    if (onto != null && armed) {
      widget.onDropOnto?.call(drag, onto);
    } else if (gap != null) {
      widget.onDropAt?.call(drag, order, gap);
    } else if (!room) {
      _shake.forward(from: 0);
      widget.onFull?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final onDark = palette.onDark;
    final style = widget.style;
    final others = _others;
    final gapOn = _over && _gap != null;

    return LayoutBuilder(
      builder: (context, constraints) {
        // The dock never spans the full width. A Mac's floats, with desktop
        // visible either side, and a phone dock that touches both edges reads as
        // a navigation bar rather than as a dock.
        // A phone dock's RUN is the home grid's row exactly (the plate's
        // hairline sits just outside it), so a full dock lands in the grid's
        // columns to the pixel. See [AquaDock.restSlot].
        final phone = widget.restSlot != null;
        final whole = phone
            ? constraints.maxWidth - _phoneMargin * 2
            : (constraints.maxWidth * 0.92) - _padding * 2;
        final hasTray = widget.tray != null;
        final available = hasTray ? whole - widget.trayWidth : whole;
        _available = available;

        final rest = widget.restSlot ?? AquaDockMetrics.baseSlot;
        final perSlot = widget.capacity + _launcherCount;
        _rest = rest;
        _phone = phone && perSlot > 0;
        _spacing = _spacingFor(appCount(gapOn));

        final appSlots = appCount(gapOn);
        final slots = AquaDockMetrics.layout(
          count: appSlots + _launcherCount,
          available: available,
          restSize: _rest,
          spacing: _spacing,
          // NULL while a drag is on: a swelling run would carry every icon
          // away from the gap the finger is opening. Otherwise null for the
          // styles that do not swell, so every slot is at its resting size.
          focus: _swells && !_dragging ? _focus : null,
        );

        // Where each remaining entry sits, the gap skipped over.
        final shown = <(String, AquaSlot)>[
          for (var k = 0; k < others.length; k++)
            (
              others[k].id,
              slots[_slotIndex(gapOn && k >= _gap! ? k + 1 : k)],
            ),
        ];
        _shown = shown;

        // An empty dock still draws its plate while something is held over
        // it, so there is a place to drop the first app.
        final restSize = AquaDockMetrics.baseSlotFor(
          count: 1,
          available: available,
          restSize: _rest,
          spacing: _spacing,
        );
        final tallest = slots.isEmpty
            ? restSize
            : slots.map((s) => s.size).reduce((a, b) => a > b ? a : b);
        if (slots.isEmpty && !_dragging && widget.onDropAt == null) {
          return const SizedBox.shrink();
        }

        // A phone plate: the icon, with a phone's band of glass above and
        // below. The icon's art fills its box (`iconFillProvider`), so this
        // is real glass, not a margin inside the icon.
        final vPad = phone ? 12.0 : _padding;

        // ONE radius, used by the clip AND the decoration below. A phone
        // dock is a deep rounded plate, close to the pill of the search
        // button above it but not quite one.
        final radius = phone
            ? BorderRadius.circular((tallest + vPad * 2) * 0.4)
            : switch (style) {
              // Plank meets the bottom edge, so its lower corners are not corners
              // at all. Rounding them would draw a gap that is not there.
              AquaDockStyle.flat => BorderRadius.vertical(
                  top: Radius.circular(tallest * 0.22),
                ),
              // Deepin's is rounder than a Mac's: fashion mode is a pill on the
              // wallpaper, and that extra radius is most of what tells the two
              // apart at a glance.
              AquaDockStyle.floating => BorderRadius.circular(tallest * 0.42),
              AquaDockStyle.magnified => BorderRadius.circular(tallest * 0.28),
              };

        // A sliding slot animates; a swelling one must track the finger
        // frame for frame, so it does not.
        final slide = _swells && !_dragging
            ? Duration.zero
            : const Duration(milliseconds: 220);

        final children = <Widget>[
          for (var k = 0; k < others.length; k++)
            _positioned(
              key: ValueKey(others[k].id),
              slot: shown[k].$2,
              tallest: tallest,
              duration: slide,
              child: _slot(others[k], shown[k].$2, k, palette),
            ),
          // ─── THE LIFTED ENTRY STAYS MOUNTED ─────────────────────────────
          //
          // Its LongPressDraggable owns the drag in flight, and removing it
          // from the tree would orphan the drag's end callbacks. Offstage keeps
          // the element alive while the run closes up around it.
          //
          // SAME widget types as a visible slot, all the way down, with only
          // `offstage` flipped: a different type under the same key would
          // replace the element and take the drag with it.
          for (final e in widget.entries)
            if (e.id == _lifted)
              _positioned(
                key: ValueKey(e.id),
                slot: _liftedFrom ?? AquaSlot(center: 0, size: restSize),
                tallest: tallest,
                duration: Duration.zero,
                offstage: true,
                child: _slot(
                  e,
                  _liftedFrom ?? AquaSlot(center: 0, size: restSize),
                  0,
                  palette,
                ),
              ),
          if (widget.launcherSlot)
            _positioned(
              key: const ValueKey('\u0000launcher'),
              slot: slots[_launcherFirst ? 0 : slots.length - 1],
              tallest: tallest,
              duration: slide,
              child: _LaunchpadSlot(
                size: slots[_launcherFirst ? 0 : slots.length - 1].size,
                onDark: onDark,
                onTap: widget.onLaunchpad,
              ),
            ),
        ];

        // ─── THE SWELL IS WHY THIS ONE HAS TO BE MEASURED ────────────────
        //
        // `AquaDockMetrics.reserve` is computed at the BASE slot, and a
        // magnified dock is taller than that while a finger is on it. The
        // constant is the only one of the two that can under-reserve, which
        // puts the desktop's bottom row behind a lifted icon.
        return DragTarget<DrawerDrag>(
          onWillAcceptWithDetails: (d) {
            final ok = _accepts(d.data);
            if (ok && !_over) setState(() => _over = true);
            return ok;
          },
          onMove: (d) {
            if (_accepts(d.data)) _hover(d.data);
          },
          onLeave: (_) => setState(_resetDrag),
          onAcceptWithDetails: (d) => _drop(d.data),
          builder: (context, candidate, __) => DockExtentProbe(
            vertical: false,
            child: Center(
              child: AnimatedBuilder(
                animation: _shake,
                builder: (context, child) {
                  final t = _shake.value;
                  final dx = t == 0 || t == 1
                      ? 0.0
                      : math.sin(t * math.pi * 4) * 7 * (1 - t);
                  return Transform.translate(
                    offset: Offset(dx, 0),
                    child: child,
                  );
                },
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  // Silent unless this dock swells. A flat plank that still
                  // tracked the pointer would resize its slots invisibly and
                  // fight every drag that started on it.
                  onPointerDown:
                      _swells ? (e) => _setFocusFrom(e.position) : null,
                  onPointerMove:
                      _swells ? (e) => _setFocusFrom(e.position) : null,
                  onPointerUp: _swells ? (_) => _clearFocus() : null,
                  onPointerCancel: _swells ? (_) => _clearFocus() : null,
                  child: ClipRRect(
                    borderRadius: radius,
                    child: BackdropFilter(
                      // The single most expensive thing on this desktop, and
                      // the one that makes it read as Aqua. If it janks on a
                      // budget phone, measure here first.
                      filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                      child: Container(
                        key: _panelKey,
                        // The border is INSIDE this width: Container adds a
                        // decoration's border to its padding, so leaving it out
                        // took two pixels from the row and overflowed it.
                        width: phone
                            ? whole + _border * 2
                            : whole + _padding * 2 + _border * 2,
                        padding: phone
                            ? EdgeInsets.symmetric(vertical: vPad)
                            : const EdgeInsets.all(_padding),
                        decoration: widget.glass
                            ? BoxDecoration(
                                gradient:
                                    LiquidGlass.fill(dark: widget.glassDark),
                                border: Border.all(
                                  color: LiquidGlass.edge,
                                  width: _border,
                                ),
                                borderRadius: radius,
                              )
                            : BoxDecoration(
                                color: palette.dock.withValues(
                                  alpha: palette.dock.a * widget.opacity,
                                ),
                                border: Border.all(
                                  color: onDark.withValues(alpha: 0.14),
                                  width: _border,
                                ),
                                borderRadius: radius,
                              ),
                        foregroundDecoration:
                            widget.glass ? LiquidGlass.rim(radius) : null,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              key: _runKey,
                              width: available,
                              height: tallest,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: children,
                              ),
                            ),
                            if (hasTray)
                              SizedBox(
                                width: widget.trayWidth,
                                height: tallest,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 1,
                                      height: tallest * 0.6,
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                      ),
                                      color: onDark.withValues(alpha: 0.25),
                                    ),
                                    Expanded(child: widget.tray!),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// One app or folder slot: motion, press, the wobble and the badge.
  Widget _slot(DockEntry entry, AquaSlot slot, int index, ThemePalette palette) {
    final focus = _focus;
    Widget view = _AquaSlotView(
      entry: entry,
      size: slot.size,
      accent: palette.accent,
      editing: widget.editing,
      dots: widget.restSlot == null,
      target: _onto == entry.id,
      armed: _onto == entry.id && _armed,
      onLift: () => setState(() {
        _lifted = entry.id;
        _liftedFrom = slot;
      }),
      onSettle: () {
        if (_lifted == entry.id) setState(() => _lifted = null);
      },
    );

    if (widget.editing) {
      view = _wobble(index, view);
      if (widget.onRemove != null) {
        view = _Badge(
          size: slot.size,
          palette: palette,
          onTap: (anchor) => widget.onRemove!(entry, anchor),
          minus: widget.restSlot != null,
          child: view,
        );
      }
    }

    return DockSlotMotion(
      // ─── MAGNIFY IS ALREADY DONE HERE ────────────────────────────────
      //
      // `AquaDockMetrics.layout` resizes the SLOT and conserves the run's
      // total width, which is a better magnify than a scale transform and is
      // covered by its own tests. Passing `none` for that mode leaves it
      // alone; the other six have no layout equivalent and come from here.
      mode: _swells || _dragging ? 'none' : widget.hover,
      focus: focus == null
          ? null
          : DockFocus(
              position: focus,
              spread: AquaDockMetrics.spreadSlots * slot.size,
            ),
      centre: slot.center,
      slotSize: slot.size,
      vertical: false,
      child: DockPressMotion(
        mode: widget.press,
        focus: focus == null
            ? null
            : DockFocus(
                position: focus,
                spread: AquaDockMetrics.spreadSlots * slot.size,
                // This dock tracks its own pointer, and it only sets `_focus`
                // while one is down.
                pressed: true,
              ),
        centre: slot.center,
        vertical: false,
        child: view,
      ),
    );
  }

  /// The home grid's wobble: a triangle wave, odd slots half a cycle out.
  Widget _wobble(int index, Widget child) => AnimatedBuilder(
        animation: _jiggle,
        builder: (context, c) {
          final t = (_jiggle.value + (index.isEven ? 0.0 : 0.5)) % 1.0;
          return Transform.rotate(
            angle: (t < 0.5 ? t * 2 - 0.5 : 1.5 - t * 2) * 0.024,
            child: c,
          );
        },
        child: child,
      );

  /// Slots are BOTTOM-ALIGNED, not centred. A magnified icon on a Mac grows
  /// upward out of the dock while its feet stay on the same line; centring it
  /// would make the whole row appear to breathe in and out, which looks like a
  /// rendering bug rather than like magnification.
  Widget _positioned({
    required Key key,
    required AquaSlot slot,
    required double tallest,
    required Duration duration,
    required Widget child,
    bool offstage = false,
  }) {
    return AnimatedPositioned(
      key: key,
      duration: duration,
      curve: Curves.easeOutCubic,
      left: slot.center - slot.size / 2,
      top: tallest - slot.size,
      width: slot.size,
      height: slot.size,
      child: Offstage(offstage: offstage, child: child),
    );
  }
}

/// The edit-mode badge, the home grid's `_Removable` at dock scale.
class _Badge extends StatelessWidget {
  const _Badge({
    required this.size,
    required this.palette,
    required this.onTap,
    required this.child,
    this.minus = false,
  });

  /// A phone's badge is a minus; a desktop's is a cross.
  final bool minus;

  final double size;
  final ThemePalette palette;
  final void Function(Rect? anchor) onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final badge = (size * 0.38).clamp(16.0, 22.0);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(child: child),
        Positioned(
          top: -badge * 0.25,
          left: -badge * 0.25,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.selectionClick();
              onTap(AnchoredMenu.anchorOf(context));
            },
            child: Container(
              width: badge,
              height: badge,
              decoration: BoxDecoration(
                color: palette.onDark,
                shape: BoxShape.circle,
              ),
              child: Icon(
                minus ? Icons.remove : Icons.close,
                size: badge * 0.62,
                color: palette.bar,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AquaSlotView extends ConsumerWidget {
  const _AquaSlotView({
    required this.entry,
    required this.size,
    required this.accent,
    required this.editing,
    required this.dots,
    required this.target,
    required this.armed,
    required this.onLift,
    required this.onSettle,
  });

  final DockEntry entry;
  final double size;
  final Color accent;

  /// Edit mode. A tap does nothing there: the home screen is being arranged.
  final bool editing;

  /// The running-dot row under the icon. A Mac's; a phone dock has none, and
  /// the icon takes the whole slot.
  final bool dots;

  /// A drag is resting on this slot's centre.
  final bool target;

  /// ...long enough that letting go makes, or fills, a folder.
  final bool armed;

  /// This slot's own drag began, and ended or was cancelled.
  final VoidCallback onLift;
  final VoidCallback onSettle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final core = Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          child: AnimatedScale(
            // The target lifts toward the finger; armed, it lifts further, the
            // way a phone says "let go and these two become a folder".
            scale: armed ? 1.18 : (target ? 1.06 : 1.0),
            duration: const Duration(milliseconds: 160),
            child: FittedBox(
              // The icon widget was built at the dock's peak glyph size;
              // FittedBox scales it to whatever the layout asked for this
              // frame. Rebuilding an AppIcon at a new pixel size on every
              // pointer move would re-cross the platform channel sixty times a
              // second, which is the whole reason the icon cache exists.
              fit: BoxFit.contain,
              child: entry.icon,
            ),
          ),
        ),
        // A Mac marks a running app with a dot beneath it. Android has no
        // public "is this running" API, so this lights only for what we
        // actually know.
        if (dots)
          SizedBox(
            height: 5,
            child: entry.isRunning
                ? Center(
                    child: Container(
                      width: 3.5,
                      height: 3.5,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  )
                : null,
          ),
      ],
    );

    // ─── A SOURCE, LIKE EVERY OTHER DOCK ────────────────────────────────
    //
    // `entry.id` is the dock key: the component key for an app, the
    // `folder:<id>` entry for a folder. The payload is the matching drag type,
    // so the grid can tell a folder arriving from the dock from an app.
    final folderId = entry.folderId;
    final DrawerDrag data = folderId != null
        ? FolderDrag(folderId, from: DragOrigin.dock)
        : AppDrag(entry.id, from: DragOrigin.dock);

    void settle() {
      ref.read(dockDragActiveProvider.notifier).set(false);
      ref.read(homeDragActiveProvider.notifier).set(false);
      onSettle();
    }

    return Semantics(
      button: true,
      label: entry.label,
      child: LongPressDraggable<DrawerDrag>(
        data: data,
        // The swell carries each icon's drop target with it, so it stands down
        // for the drag. See `dockDragActiveProvider`.
        onDragStarted: () {
          HapticFeedback.mediumImpact();
          ref.read(dockDragActiveProvider.notifier).set(true);
          ref.read(homeDragActiveProvider.notifier).set(true);
          onLift();
        },
        onDragEnd: (_) => settle(),
        onDraggableCanceled: (_, __) => settle(),
        dragAnchorStrategy: pointerDragAnchorStrategy,
        // CENTRED on the finger, as the home grid's feedback is, at the
        // resting size rather than whatever a swell made it this frame.
        feedback: FractionalTranslation(
          translation: const Offset(-0.5, -0.5),
          child: Material(
            color: Colors.transparent,
            child: Opacity(
              opacity: 0.9,
              child: SizedBox(
                width: size * 1.15,
                height: size * 1.15,
                child: FittedBox(child: entry.icon),
              ),
            ),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.25, child: core),
        child: GestureDetector(
          onTap: editing ? null : entry.onTap,
          // Same measured rect as the GNOME slot. The draggable above consumes
          // the long press, so this fires only on a hold that never travelled.
          onLongPress: entry.onLongPress == null
              ? null
              : () => entry.onLongPress!(AnchoredMenu.anchorOf(context)),
          behavior: HitTestBehavior.opaque,
          child: core,
        ),
      ),
    );
  }
}

/// Launchpad's slot: the grid glyph on a translucent plate, past the separator.
class _LaunchpadSlot extends StatelessWidget {
  const _LaunchpadSlot({
    required this.size,
    required this.onDark,
    required this.onTap,
  });

  final double size;
  final Color onDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: context.t('home.launchpad'),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: onDark.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(size * 0.24),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.grid_view_rounded,
                  // Tracks the slot, so the glyph swells with everything else.
                  size: size * 0.5,
                  color: onDark,
                ),
              ),
            ),
            const SizedBox(height: 5),
          ],
        ),
      ),
    );
  }
}
