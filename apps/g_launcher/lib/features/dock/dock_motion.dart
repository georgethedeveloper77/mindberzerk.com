/// The seven hover motions, in one place, for every surface that holds slots.
///
/// ─── SEVEN ARMS ONCE, NOT THREE HERE AND SEVEN THERE ───────────────────────
///
/// The obvious build puts the modes each dock can manage into that dock.
/// `AquaDock` already swells, so it would take magnify and the four that are
/// variations on it; `GnomeDock` tracks no pointer at all, so it would take
/// none. The settings sheet then offers seven modes of which four do nothing on
/// Ubuntu, and a setting that silently does nothing is worse than one that is
/// absent. That is the `dockReveal` failure exactly: a value the list admits
/// and the reader ignores, sitting behind a dock that looks like it works.
///
/// So the motion is a widget rather than a capability. A surface wraps each
/// slot in one and reports where the finger is; every mode then works on every
/// surface by construction, and an eighth is one arm in one file.
///
/// ─── IT MOVES ICONS, NOT LAYOUT ────────────────────────────────────────────
///
/// Five of the seven are pure transforms and cost the row nothing. Two are not:
/// `part` slides neighbours aside and `arc` bows the row, and both are done here
/// as TRANSLATIONS of the icon rather than as changes to the slot's box. The
/// row's geometry is therefore untouched, which is what lets the same widget sit
/// inside `AquaDock`'s Stack, `GnomeDock`'s Flex and the panel task strip's
/// ListView without any of them knowing.
///
/// `AquaDock` keeps its own swell on top of this: `AquaDockMetrics.layout`
/// resizes the slot itself and conserves total width, which is a better
/// magnify than a scale transform and is already tested. This widget's
/// `magnify` arm is for the surfaces that have no such layout, and it is
/// deliberately the same curve so the two do not read as different animations.
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'aqua_dock_metrics.dart' show AquaDockMetrics;

/// Is a slot being dragged right now, anywhere?
///
/// ─── MOTION AND DRAG CANNOT SHARE A POINTER ────────────────────────────────
///
/// Flutter transforms HIT TESTING along with the paint, so an icon that has
/// been moved by [DockSlotMotion] has moved its drop target with it. During a
/// drag that means the targets slide away from the finger: `part` pushes
/// neighbours 14dp aside as you pass them, `magnify` shifts every icon it
/// touches, and whether a drop lands depends on the mode and where in the row
/// you are. That is the "works, then sometimes it does not" that reordering
/// started doing.
///
/// So the two are mutually exclusive. A drag turns the motion off for its whole
/// duration, and the dock goes still, which is also what a dock being
/// rearranged should look like.
///
/// A provider rather than a parameter, because the flag is set by a SLOT and
/// read by a TRACKER several widgets above it, on three different surfaces.
/// Threading it would mean every dock knowing which of its children might start
/// a drag.
final dockDragActiveProvider =
    NotifierProvider<DockDragActive, bool>(DockDragActive.new);

class DockDragActive extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool v) {
    if (state == v) return;
    state = v;
  }
}

/// Where the finger is, along the run of a dock.
///
/// Null is NOT the same as zero. Zero is a finger at the leading edge; null is
/// no finger at all, and every mode rests. Conflating them is how a dock ends
/// up permanently magnifying its first icon.
class DockFocus {
  const DockFocus({
    required this.position,
    required this.spread,
    this.pressed = false,
  });

  /// Is the finger DOWN, as opposed to merely over the dock?
  ///
  /// ─── THE PRESS AXIS NEEDED NO NEW PLUMBING ─────────────────────────────
  ///
  /// A tracker that already reports where the finger is knows when it went
  /// down: the same `onPointerDown` that starts the hover starts this. Adding a
  /// second tracker for presses would mean two widgets fighting over the same
  /// pointer stream, and the press one would be the one that lost a gesture to
  /// a drag.
  ///
  /// It also gives `wave` for free. That mode cascades outward from the icon
  /// that was tapped, and "which icon was tapped" is just the focus position at
  /// the moment this turned true, which every slot can already measure its
  /// distance from.
  final bool pressed;

  /// The finger's offset along the run, in the same coordinate space the slot
  /// centres use.
  final double position;

  /// How far the influence reaches, in the same units. Roughly two slots either
  /// side reads as a dock responding; much more and the whole row moves as one
  /// piece, which reads as the dock sliding rather than the icons reacting.
  final double spread;
}

/// Applies the active hover motion to one slot.
///
/// [centre] is this slot's own position along the run. The widget computes its
/// distance from the focus itself rather than taking a precomputed factor, so a
/// surface only has to report ONE number per frame instead of one per slot.
class DockSlotMotion extends StatelessWidget {
  const DockSlotMotion({
    super.key,
    required this.mode,
    required this.focus,
    required this.centre,
    required this.slotSize,
    required this.vertical,
    required this.child,
  });

  /// One of the ids in `dockHoverModes`. An unknown value rests, the same
  /// drop-not-fatal contract every free-form read in the theme layer keeps.
  final String mode;

  final DockFocus? focus;
  final double centre;
  final double slotSize;

  /// True on a left or right dock, where the run is vertical. Every motion that
  /// has a direction has to turn with it: a `part` that always pushed sideways
  /// would slide icons out of a 48dp-wide column.
  final bool vertical;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // ─── THE TREE SHAPE MUST NOT DEPEND ON THE FOCUS ──────────────────────
    //
    // This used to `return child` when there was no finger and a wrapped tree
    // when there was. The moment a finger landed, the slot gained a `Transform`
    // above it, Flutter rebuilt that subtree, and the gesture recognizer inside
    // the slot was disposed HALFWAY THROUGH the gesture it was recognising. The
    // tap never completed, so no app would open while any motion was on.
    //
    // Nothing about the motion caused it; the same bug would have appeared with
    // an empty transform. So every mode below now returns the same shape at
    // rest as it does under a finger, and rest is expressed as identity values
    // rather than as an absent widget.
    //
    // `mode` is exempt, because it changes only when a user picks a different
    // one in Settings, which is not during a gesture.
    if (mode == 'none') return child;

    final f = focus;

    // Signed distance, normalised to the spread. The SIGN is what tells `part`
    // and `tilt` which way to move; the magnitude drives everything else.
    // With no finger the slot is pinned at the far edge, where every curve
    // below evaluates to rest.
    final signed =
        f == null ? 1.0 : ((centre - f.position) / f.spread).clamp(-1.0, 1.0);

    // The same raised cosine the Aqua dock magnifies on, for the reason its own
    // doc gives: flat at both ends, so there is no corner at the peak and it
    // settles to exactly zero at the edge rather than twitching forever.
    final t = f == null ? 0.0 : AquaDockMetrics.falloff(signed.abs());

    // Whether this slot is the one under the finger. A third of the spread
    // rather than the nearest centre, because on a packed dock two slots can be
    // nearly equidistant and `lift` would flicker between them.
    //
    // Expressed as 0 or 1 rather than a bool so it can be multiplied into the
    // same expressions everything else uses, which is what keeps the two
    // branches one shape.
    final focused = (f != null && signed.abs() < 0.35) ? 1.0 : 0.0;

    var scale = 1.0;
    var along = 0.0;
    var across = 0.0;
    var turn = 0.0;
    var tiltBy = 0.0;
    var opacity = 1.0;

    switch (mode) {
      // Neighbours scale on the falloff and rise together. This is the Aqua
      // dock's own behaviour, reproduced as a transform for the surfaces whose
      // layout cannot resize a slot.
      case 'magnify':
        scale = 1 + 0.35 * t;
        across = -14 * t;

      // Only the focused icon moves, and it moves a fixed amount rather than a
      // falloff one: the point of this mode is that it is crisp, and a lift
      // that eases in as the finger approaches is just a shallow magnify.
      case 'lift':
        scale = 1 + 0.10 * focused;
        across = -12 * focused;

      // Rotation toward the finger, in the run's own axis. A left dock rotates
      // about X, a bottom dock about Y, or the icons would appear to lean out
      // of the screen rather than toward the thumb.
      case 'tilt':
        tiltBy = -0.35 * signed * t;
        scale = 1 + 0.12 * t;
        across = -7 * t;

      // Neighbours slide away ALONG the run to clear space. The focused slot
      // grows into the gap they leave; anything past the spread is already at
      // zero and does not move.
      case 'part':
        scale = 1 + 0.14 * focused;
        along = 14 * t * signed.sign * (1 - focused);

      // Everything but the focus dims. No geometry moves far, which makes this
      // the one mode that is safe at any density.
      case 'focus':
        opacity = f == null ? 1.0 : 0.45 + 0.55 * t;
        scale = 1 + 0.14 * t;

      // The row bows: neighbours rise on the falloff AND rotate slightly away
      // from the centre, so the line of icons reads as a shallow arc rather
      // than as a bump.
      case 'arc':
        turn = (vertical ? -0.14 : 0.14) * signed * t;
        scale = 1 + 0.20 * t;
        across = -20 * t;

      // A pack written against a newer build. Drop-not-fatal, like every other
      // free-form read in the theme layer: it rests rather than throwing, and
      // it rests in the same shape so it cannot break a gesture either.
      default:
        break;
    }

    final offset = vertical ? Offset(across, along) : Offset(along, across);

    return Opacity(
      opacity: opacity,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          // Perspective, needed only by `tilt`, and harmless at zero.
          ..setEntry(3, 2, 0.0015)
          // `translateByDouble` and `scaleByDouble`, not `translate` and
          // `scale`: the untyped forms are deprecated in this vector_math and
          // resolve their arguments at runtime.
          ..translateByDouble(offset.dx, offset.dy, 0, 1)
          ..rotateZ(turn)
          ..rotateY(vertical ? 0 : tiltBy)
          ..rotateX(vertical ? tiltBy : 0)
          ..scaleByDouble(scale, scale, 1, 1),
        child: child,
      ),
    );
  }

}

/// Tracks a finger along a dock and reports it as a [DockFocus].
///
/// ─── WHY THIS IS NOT IN EACH DOCK ──────────────────────────────────────────
///
/// `AquaDock` already has it: `_setFocusFrom`, `_clearFocus`, a `Listener` and
/// four handlers. `GnomeDock` has none, and the panel task strip has none.
/// Writing it twice more is three copies of the same four handlers, and the
/// third would be the one that forgets `onPointerCancel` and leaves the dock
/// magnified after a call comes in.
///
/// Rest is reported as null rather than as a position off the end, so a surface
/// cannot accidentally treat "no finger" as "finger at zero".
class DockFocusTracker extends ConsumerStatefulWidget {
  const DockFocusTracker({
    super.key,
    required this.enabled,
    required this.vertical,
    required this.spread,
    required this.builder,
  });

  /// False for `none`, and for a surface that cannot use it. A tracker that
  /// followed the pointer for a dock drawing no motion would set state sixty
  /// times a second to change nothing, and would fight every drag that started
  /// on the dock.
  final bool enabled;

  final bool vertical;

  /// How far the motion reaches. Passed in because it is a function of slot
  /// size, which the surface knows and this does not.
  final double spread;

  final Widget Function(BuildContext context, DockFocus? focus) builder;

  @override
  ConsumerState<DockFocusTracker> createState() => _DockFocusTrackerState();
}

class _DockFocusTrackerState extends ConsumerState<DockFocusTracker> {
  double? _at;
  bool _down = false;

  void _set(Offset global) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final local = box.globalToLocal(global);
    final v = widget.vertical ? local.dy : local.dx;
    if (_at != null && (_at! - v).abs() < 0.5) return;
    setState(() => _at = v);
  }

  void _clear() {
    if (_at == null && !_down) return;
    setState(() {
      _at = null;
      _down = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // ─── A DRAG WINS ──────────────────────────────────────────────────────
    //
    // Reported as REST, not merely frozen, so every slot returns to its resting
    // transform and its drop target goes back to where the icon is drawn. A
    // frozen focus would leave the targets wherever they had drifted to at the
    // moment the drag began, which is the same bug standing still.
    //
    // The Listener also goes, so the drag's own pointer stream is not shared
    // with a widget that would rebuild the dock on every move of it.
    final dragging = ref.watch(dockDragActiveProvider);

    if (!widget.enabled || dragging) return widget.builder(context, null);

    return Listener(
      // TRANSLUCENT, not opaque. The slots underneath still need their taps,
      // their long presses and their drags; this only watches.
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) {
        setState(() => _down = true);
        _set(e.position);
      },
      onPointerMove: (e) => _set(e.position),
      onPointerUp: (_) => _clear(),
      // The one every hand-rolled version forgets. A cancel arrives when a
      // drag is claimed by something else or a call comes in, and without it
      // the dock stays magnified until the next touch.
      onPointerCancel: (_) => _clear(),
      child: widget.builder(
        context,
        _at == null
            ? null
            : DockFocus(
                position: _at!,
                spread: widget.spread,
                pressed: _down,
              ),
      ),
    );
  }
}

/// The ten press motions, driven by the same focus the hover modes use.
///
/// ─── WHY A SECOND WIDGET AND NOT TEN MORE ARMS IN THE FIRST ────────────────
///
/// Hover is a pure function of where the finger is: give it a position and it
/// returns a transform, with no memory. Press is not. Half of these have a
/// RELEASE phase that outlives the finger, so this one owns an
/// `AnimationController` and [DockSlotMotion] stays stateless.
///
/// Keeping them apart also keeps them composable. A dock that magnifies on
/// hover and squashes on press is two widgets nested, not twenty combinations
/// enumerated, which is what a single widget answering both axes would have
/// become.
///
/// ─── EVERY MODE PLAYS ON RELEASE, NOT ON DOWN ──────────────────────────────
///
/// A motion that fires the instant a finger lands fires on every scroll that
/// happens to start on the dock, and on the first half of every long press that
/// was going to open a menu. Playing on release means the gesture has finished
/// and the app is launching, which is what these animations are ABOUT.
///
/// `sink` is the exception and is deliberately the default: it tracks the
/// finger down and back up, because it is feedback rather than celebration.
class DockPressMotion extends StatefulWidget {
  const DockPressMotion({
    super.key,
    required this.mode,
    required this.focus,
    required this.centre,
    required this.vertical,
    required this.child,
  });

  /// One of the ids in `dockPressModes`. Unknown values rest.
  final String mode;

  final DockFocus? focus;

  /// This slot's position along the run, the same number [DockSlotMotion]
  /// takes. Used to tell whether this is the slot being pressed, and for
  /// `wave`, how far the cascade has to travel to reach it.
  final double centre;

  final bool vertical;
  final Widget child;

  @override
  State<DockPressMotion> createState() => _DockPressMotionState();
}

class _DockPressMotionState extends State<DockPressMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  /// How far this slot was from the press, 0 at the pressed icon and 1 at the
  /// edge of the spread. Captured at the moment of the press rather than read
  /// live, because the finger moves during the release and `wave` has to keep
  /// cascading outward from where the tap actually happened.
  double _distance = 0;
  bool _wasPressed = false;

  @override
  void initState() {
    super.initState();

    // ─── BUILT HERE, NOT AS `late final _c = AnimationController(...)` ─────
    //
    // That form constructs on FIRST ACCESS. `sink` returns from `build` before
    // ever touching the controller, so on the default mode the first access was
    // `_c.dispose()`: a controller created during teardown, calling
    // `createTicker` on an element that has already been deactivated.
    // `TickerMode` does an inherited lookup there and Flutter asserts.
    //
    // It fired only on the one mode nobody changes, which is why the other
    // nine never showed it. With `SingleTickerProviderStateMixin`, a lazily
    // created controller is a bug whenever any build path can skip it, because
    // `dispose` always reaches for it.
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// True while the finger is down on THIS slot.
  bool get _holding {
    final f = widget.focus;
    if (f == null || !f.pressed) return false;
    return (widget.centre - f.position).abs() < f.spread * 0.35;
  }

  @override
  void didUpdateWidget(DockPressMotion old) {
    super.didUpdateWidget(old);

    final f = widget.focus;
    final pressed = f != null && f.pressed;

    if (pressed && !_wasPressed) {
      // Captured ONCE, on the edge. Reading it every frame would let a finger
      // that slides during the press rewrite which icon the wave came from.
      _distance =
          ((widget.centre - f.position).abs() / f.spread).clamp(0.0, 1.0);
    }

    // The release IS the trigger. `pressed` going false with a finger that was
    // on this dock is a tap completing, which is when an app opens.
    if (_wasPressed && !pressed && widget.mode != 'sink') {
      _play();
    }
    _wasPressed = pressed;
  }

  Future<void> _play() async {
    // `wave` reaches the far end of the dock about a fifth of a second after
    // the icon that was tapped. Long enough to read as a cascade, short enough
    // that the last icon is still moving while the app is opening.
    if (widget.mode == 'wave' && _distance > 0) {
      await Future<void>.delayed(
        Duration(milliseconds: (_distance * 220).round()),
      );
      if (!mounted) return;
    }

    _c
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    final mode = widget.mode;
    if (mode == 'none') return widget.child;

    // Feedback rather than celebration: this one follows the finger, so it is
    // driven by the held state and not by the controller.
    if (mode == 'sink') {
      return AnimatedScale(
        scale: _holding ? 0.88 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      );
    }

    // ─── NO EARLY RETURN, AND NONE INSIDE THE BUILDER EITHER ─────────────
    //
    // This used to skip the `AnimatedBuilder` for a slot that was not being
    // pressed, so the tree gained and lost a widget exactly as a finger
    // arrived. That rebuilt the slot underneath its own gesture and the tap
    // never completed. Returning a bare child from INSIDE the builder has the
    // same effect one level down: the slot is reparented and its recognizer
    // goes with it.
    //
    // So the shape is fixed and rest is expressed as identity values. The
    // builder is cheap at rest, because an idle controller notifies nobody.
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        // Does this slot take part? `wave` moves every slot in range; the rest
        // move only the one that was tapped. Read as a NUMBER so it multiplies
        // into the expressions below rather than choosing a subtree.
        final mine =
            (mode == 'wave' ? _distance < 1.0 : _holding || _c.isAnimating)
                ? 1.0
                : 0.0;

        final t = _c.value * mine;

        // A half-sine: zero at both ends, one in the middle. Every mode below
        // is "go away from rest and come back", and writing that curve once
        // means none of them can forget to return.
        final swing = math.sin(math.pi * t) * mine;

        var sx = 1.0;
        var sy = 1.0;
        var across = 0.0;
        var turnY = 0.0;
        var turnZ = 0.0;
        var opacity = 1.0;

        switch (mode) {
          // Two hops, the second smaller, which is what a bouncing object does
          // and what the eye expects.
          case 'bounce':
            across = -14 * math.sin(math.pi * t * 2).abs() * (1 - t * 0.65);
          case 'jelly':
            sx = 1 + 0.22 * swing;
            sy = 1 - 0.18 * swing;
          case 'pop':
            sx = sy = 1 + 0.28 * swing;
          case 'flip':
            turnY = 2 * math.pi * t;
          case 'swing':
            // Anchored at the BASE by [_alignment], not the centre: a pendulum
            // pivots where it hangs from, and rotating about the middle reads
            // as a wobble.
            turnZ = 0.30 * math.sin(math.pi * t * 3) * (1 - t) * mine;
          // Nothing moves. The whole point of this one is that it is the mode
          // for somebody who finds motion distracting but still wants an
          // acknowledgement.
          case 'pulse':
            opacity = 1 - 0.35 * swing;
          case 'ripple':
            sx = sy = 1 + 0.10 * swing;
          case 'wave':
            across = -10 * swing;
          // The icon leaves. It rises and fades as the app takes the screen, so
          // the launcher appears to hand off rather than to disappear.
          case 'launch':
            opacity = 1 - t;
            across = -26 * t;
          default:
            break;
        }

        final offset =
            widget.vertical ? Offset(across, 0) : Offset(0, across);

        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform(
            alignment: _alignment,
            transform: Matrix4.identity()
              // Perspective, needed only by `flip`, harmless at zero.
              ..setEntry(3, 2, 0.0015)
              ..translateByDouble(offset.dx, offset.dy, 0, 1)
              ..rotateZ(turnZ)
              ..rotateY(turnY)
              ..scaleByDouble(sx, sy, 1, 1),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }

  /// Where the transform pivots.
  ///
  /// Constant for a given mode, so it can differ between them without ever
  /// changing during a gesture. Only `swing` wants anything but the centre.
  Alignment get _alignment =>
      widget.mode == 'swing' ? Alignment.bottomCenter : Alignment.center;

}
