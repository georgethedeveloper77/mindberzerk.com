import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../design/branded_message.dart';
import '../../engine/effective_theme.dart';
import '../desklets/desklet_edit.dart';
import '../drawer/drawer_state.dart';
import 'accessibility_disclosure.dart';
import 'gesture_actions.dart';
import '../home/workspaces/workspace_overview.dart';

/// Temporarily reveals the dock. Auto-hides — a dock summoned by a gesture that
/// then sticks around forever is just a dock.
final dockRevealedProvider = StateProvider<bool>((ref) => false);

/// Wraps the workspace and turns touches into bound actions.
///
/// Sits BEHIND the icons: HitTestBehavior.translucent means an icon tap still
/// reaches the icon. A gesture layer that swallows taps is the fastest way to
/// make a launcher feel broken.
///
/// **This layer no longer detects vertical drags. At all.** The workspaces
/// PageView is vertical now, and Flutter's gesture arena would make this layer
/// and the PageView compete for every vertical drag — the winner depends on
/// timing and which recognizer claims first, i.e. it works in testing and loses
/// in the field. So vertical is ceded wholesale: the PageView owns it, and the
/// two vertical bindings (swipeUp/swipeDown) are unbound in defaultGestures.
///
/// twoFingerSwipeDown is also dormant on this shell for the same reason — it
/// was detected inside the vertical handler. It stays in the enum (other shells
/// without a vertical pager can use it), and quick settings remains reachable:
/// bind it to swipeLeft, or via the shade.
class GestureLayer extends ConsumerStatefulWidget {
  const GestureLayer({
    super.key,
    required this.theme,
    required this.child,
  });

  final EffectiveTheme theme;
  final Widget child;

  @override
  ConsumerState<GestureLayer> createState() => _GestureLayerState();
}

class _GestureLayerState extends ConsumerState<GestureLayer> {
  Timer? _dockHide;

  @override
  void dispose() {
    _dockHide?.cancel();
    super.dispose();
  }

  Future<void> _fire(Gesture gesture) async {
    final binding = bindingFor(widget.theme, gesture);

    final ok = await runGesture(
      ref,
      binding,
      onActivities: () =>
          ref.read(activitiesOpenProvider.notifier).state = true,
      onShowDock: _revealDock,
      onSearch: () => ref.read(activitiesOpenProvider.notifier).state = true,
    );

    // ─── THE JUST-IN-TIME DISCLOSURE ────────────────────────────────────
    //
    // Failed AND it needed the service means the user has never turned it on,
    // or has turned it back off. This used to show a one-line message pointing
    // at Settings, which left them tapping at a dead gesture and, at best,
    // hunting for a screen.
    //
    // It is now the moment Play's policy is actually written around: the user
    // has just asked for a capability, the reason for the permission is
    // therefore obvious and concrete, and the disclosure appears before any
    // request is made. `requestGestureService` shows the full-screen consent
    // and only opens Android's settings on an explicit Continue.
    //
    // NOT a nag: this fires when a gesture the user deliberately bound was
    // deliberately triggered. It cannot appear unprompted, and declining costs
    // one tap and is remembered by the simple fact that nothing changed.
    if (!ok && binding.action.needsService && mounted) {
      await requestGestureService(context, ref);
    }

    // ─── THE ONE FAILURE THAT HAS TO SPEAK ──────────────────────────────
    //
    // Every other unbound or dead gesture is correctly silent: nothing was
    // promised. This one was. The user went into Settings and deliberately
    // bound a gesture to their assistant, and on a phone with no assistant
    // installed, a de-Googled ROM or some budget builds, both intents fail and
    // the gesture would do nothing forever with no way to find out why.
    //
    // Not a nag. It cannot appear unless the user bound it and then performed
    // it, and it says what is wrong rather than pointing at a settings screen
    // that cannot fix it.
    if (!ok && binding.action == GestureAction.assistant && mounted) {
      context.showMessage('No voice assistant is set up on this phone');
    }
  }

  void _revealDock() {
    ref.read(dockRevealedProvider.notifier).state = true;
    _dockHide?.cancel();
    _dockHide = Timer(const Duration(seconds: 3), () {
      if (mounted) ref.read(dockRevealedProvider.notifier).state = false;
    });
  }

  /// The last reported pinch factor, read once at end.
  ///
  /// Held on the State rather than derived in `onScaleEnd`, because
  /// [ScaleEndDetails] carries velocity and pointer count and NOT the scale
  /// that was reached. Reading `details.scale` there does not compile, and
  /// acting on every `onScaleUpdate` instead would fire the overview halfway
  /// through a squeeze that the user was still deciding about.
  double _lastScale = 1;

  @override
  Widget build(BuildContext context) {
    // ─── THE SWIPE LAYER STANDS DOWN WHILE THE DESKTOP IS EDITED ───────────
    //
    // This layer's horizontal drag recognizer declares at the ordinary touch
    // slop, roughly 18 logical pixels on one axis. A tile drag has to clear
    // considerably more than that before its own recognizer can claim the
    // pointer. The arena therefore handed EVERY sideways drag to this layer,
    // and dragging a widget left or right did not move the widget at all: it
    // fired swipeLeft or swipeRight and opened the drawer.
    //
    // That is the same class of problem the class comment above already
    // describes for the vertical axis, where the fix was to cede the axis
    // outright. The horizontal axis cannot be ceded permanently, because the
    // drawer lives on it. So it is ceded for the duration of edit mode, which
    // is exactly as long as something else needs it.
    //
    // NULL CALLBACKS, not an early return of the child.
    //
    // The only way to lose an arena is not to enter it, and a recognizer that
    // returns early from its handler has still won: the gesture stays stolen
    // and merely stops doing anything visible, which is strictly worse. But
    // returning `widget.child` here would change the SHAPE of the tree, and
    // this layer wraps the workspace PageView. A shape change unmounts it, a
    // remounted PageView is a brand new PageController, and the desktop would
    // silently jump back to workspace one every time edit mode toggled. That is
    // the identical failure home_screen documents at length under
    // skipLoadingOnReload.
    //
    // GestureDetector builds a recognizer only for each NON-NULL callback, so
    // nulling them registers nothing and competes for nothing, while the tree
    // keeps exactly the shape it had.
    final editing = ref.watch(deskletEditProvider).active;

    return Stack(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          // HORIZONTAL only. Vertical drags fall straight through to the
          // workspaces PageView underneath — see the class comment.
          onHorizontalDragEnd: editing ? null : (details) {
            final v = details.primaryVelocity ?? 0;
            // 300 px/s: below that it is a hesitant touch, not a fling. Too low
            // and every wobble fires a gesture.
            if (v.abs() < 300) return;

            if (v > 0) {
              _fire(Gesture.swipeRight);
            } else {
              _fire(Gesture.swipeLeft);
            }
          },
          onDoubleTap: editing ? null : () => _fire(Gesture.doubleTapHome),
          child: widget.child,
        ),

        // ─── PINCH IN FOR THE OVERVIEW, ON ITS OWN DETECTOR ──────────────
        //
        // It cannot join the detector above. Flutter asserts when a single
        // GestureDetector declares both a scale callback and a horizontal or
        // vertical drag callback, because a one-finger scale IS a pan and the
        // two recognizers would claim the same pointer.
        //
        // ─── AND WHY IT IS SAFE TO ADD HERE AT ALL ───────────────────────
        //
        // This layer wraps the workspace PageView, and the file's own header
        // says at length what happens when a recognizer up here competes with a
        // scrollable down there: the arena hands it every drag and the thing
        // underneath stops working. A ScaleGestureRecognizer does not have that
        // problem for one reason only, which is that it does not accept the
        // arena until a SECOND pointer arrives. One finger never reaches this;
        // the pager keeps every swipe it has today.
        //
        // The scale is read at END rather than continuously, so a two-finger
        // rest or a small wobble does nothing. Below 0.75 is a deliberate
        // squeeze; a pinch out is left alone because there is nothing above the
        // desktop to zoom into.
        //
        // Nulled during edit mode like everything else here, and refused again
        // inside `open()`, because a drag in progress must not be zoomed away
        // from. Two guards rather than one: this one keeps the recognizer out
        // of the arena, and that one is the rule.
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onScaleEnd: editing
              ? null
              : (details) {
                  if (details.pointerCount > 0) return;
                  if (_lastScale >= 0.75) return;
                  ref.read(workspaceOverviewProvider.notifier).open();
                },
          onScaleUpdate: editing ? null : (d) => _lastScale = d.scale,
        ),

        // The v1 gesture, preserved. A narrow strip, not the whole left half —
        // wide enough to hit reliably, narrow enough not to steal drags from
        // the dock's icons.
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: 20,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onDoubleTap:
                editing ? null : () => _fire(Gesture.doubleTapLeftEdge),
          ),
        ),
      ],
    );
  }
}
