import 'package:flutter/material.dart';

/// A number that counts up to itself, once.
///
/// Applied to the headline figures at the top of a page, never to a label or a
/// row. A count that ticks is a count being taken; a screen where every number
/// ticks is a fruit machine.
///
/// ─── THE FORMATTER IS PASSED IN ──────────────────────────────────────────────
///
/// Because the intermediate values have to be formatted the same way as the
/// final one. Counting to a byte figure by interpolating the STRING would be
/// nonsense, so this interpolates the number and hands each step to the same
/// formatter that would have produced the static version.
///
/// ─── IT DOES NOT REPLAY ──────────────────────────────────────────────────────
///
/// TweenAnimationBuilder animates when the tween's end changes, so a rebuild
/// with the same value does nothing and a genuinely new figure counts from the
/// old one to the new. That is the correct behaviour in both cases and it is why
/// this is not an AnimationController.
///
/// ─── IT FORCES TABULAR FIGURES ───────────────────────────────────────────────
///
/// Proportional digits have different widths, so a figure counting from 0 to
/// 128.4 GB changes width roughly forty times on the way up and drags whatever
/// sits beside it back and forth. Every mono style in the ramp already asks for
/// the feature; a caller that hands in a sans style would not, and that caller
/// is the reason this is applied here rather than trusted.
class GCountUp extends StatelessWidget {
  const GCountUp({
    required this.value,
    required this.format,
    required this.style,
    super.key,
    this.duration = const Duration(milliseconds: 850),
  });

  final num value;

  /// Applied to every frame, so 2.4 GB counts through 0.3 GB and 1.7 GB rather
  /// than through a meaningless run of digits.
  final String Function(num) format;

  final TextStyle style;
  final Duration duration;

  /// Respects a style that already asked for features of its own. Overwriting
  /// the list would drop small caps or slashed zero from a caller that wanted
  /// them, so this only fills the gap.
  TextStyle get _steady => style.fontFeatures == null
      ? style.copyWith(
          fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
        )
      : style;

  @override
  Widget build(BuildContext context) {
    final TextStyle steady = _steady;

    if (MediaQuery.disableAnimationsOf(context)) {
      return Text(
        format(value),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: steady,
      );
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double shown, Widget? child) => Text(
        format(shown),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: steady,
      ),
    );
  }
}
