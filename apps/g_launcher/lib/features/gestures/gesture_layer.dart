import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../design/branded_message.dart';
import '../../engine/effective_theme.dart';
import '../drawer/drawer_state.dart';
import 'gesture_actions.dart';

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
    final binding = bindingFor(widget.theme.prefs, gesture);

    final ok = await runGesture(
      ref,
      binding,
      onActivities: () =>
          ref.read(activitiesOpenProvider.notifier).state = true,
      onShowDock: _revealDock,
      onSearch: () => ref.read(activitiesOpenProvider.notifier).state = true,
    );

    // Failed AND it needed the service -> the user turned it off (or never
    // turned it on). Say so once, here, rather than letting them tap at a dead
    // gesture and conclude the launcher is broken.
    if (!ok && binding.action.needsService && mounted) {
      context.showMessage(
        'Enable gestures in Settings to use this',
        tone: MessageTone.warning,
        duration: const Duration(seconds: 2),
      );
    }
  }

  void _revealDock() {
    ref.read(dockRevealedProvider.notifier).state = true;
    _dockHide?.cancel();
    _dockHide = Timer(const Duration(seconds: 3), () {
      if (mounted) ref.read(dockRevealedProvider.notifier).state = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          // HORIZONTAL only. Vertical drags fall straight through to the
          // workspaces PageView underneath — see the class comment.
          onHorizontalDragEnd: (details) {
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
          onDoubleTap: () => _fire(Gesture.doubleTapHome),
          child: widget.child,
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
            onDoubleTap: () => _fire(Gesture.doubleTapLeftEdge),
          ),
        ),
      ],
    );
  }
}
