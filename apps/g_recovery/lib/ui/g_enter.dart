import 'package:flutter/material.dart';

/// Fades and lifts a child into place, once.
///
/// Lifted out of the home mosaic because every list in this app wants it and
/// none of them should reimplement it. A page whose rows arrive in order reads
/// as assembled; the same page appearing whole reads as a screenshot.
///
/// ─── ONCE IS THE WHOLE POINT ─────────────────────────────────────────────────
///
/// The shell keeps pages mounted, so an animation driven by rebuild replays
/// every time the user comes back to a tab, which stops reading as motion and
/// starts reading as a stutter. TweenAnimationBuilder runs when the widget is
/// first built and never again for the same tween, which is exactly the
/// behaviour wanted and the reason this is not an AnimationController.
class GEnter extends StatelessWidget {
  const GEnter({
    required this.index,
    required this.child,
    super.key,
    this.step = const Duration(milliseconds: 55),
    this.travel = 14,
  });

  /// Position in the sequence. Rows use their list index; a mosaic uses its
  /// slot, which is why this is a parameter and not derived from anything.
  final int index;

  final Widget child;

  /// Gap between neighbours. Slower than about 80 ms reads as loading, faster
  /// than about 35 stops reading as a sequence at all.
  final Duration step;

  /// How far the child rises. Small on purpose: this is a settling motion, not
  /// an entrance from off screen.
  final double travel;

  /// Nothing after this position is staggered.
  ///
  /// A list of two hundred rows would otherwise put the last one nearly a minute
  /// out. Beyond the first screenful the delay is capped, so anything scrolled
  /// into view is already in place.
  static const int _maxStagger = 12;

  @override
  Widget build(BuildContext context) {
    // Reduce motion gets the finished state, immediately. Nothing here carries
    // information, so there is nothing to lose by skipping it.
    if (MediaQuery.disableAnimationsOf(context)) return child;

    final int slot = index < _maxStagger ? index : _maxStagger;
    final int delay = step.inMilliseconds * slot;
    const int span = 380;
    final int total = span + step.inMilliseconds * _maxStagger;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(delay / total, 1, curve: Curves.easeOutCubic),
      builder: (BuildContext context, double value, Widget? built) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, travel * (1 - value)),
          child: built,
        ),
      ),
      child: child,
    );
  }
}
