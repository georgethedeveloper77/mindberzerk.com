import 'package:flutter/material.dart';

import 'chrome_theme.dart';

/// A slider tracked in the distro accent. For corner-radius, icon-scale, text
/// scale — the continuous settings.
///
/// Wraps a Material [Slider] in an explicit [SliderTheme] so no colour leaks
/// from the host theme. [label] shows above the thumb while dragging when
/// [divisions] is set.
class ThemedSlider extends StatelessWidget {
  const ThemedSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0.0,
    this.max = 1.0,
    this.divisions,
    this.label,
  });

  final double value;
  final ValueChanged<double>? onChanged;
  final double min;
  final double max;
  final int? divisions;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    final c = d.colors;
    return SliderTheme(
      data: SliderThemeData(
        activeTrackColor: c.accent,
        inactiveTrackColor: c.lineStrong,
        thumbColor: c.accent,
        overlayColor: c.accent.withValues(alpha: 0.16),
        valueIndicatorColor: c.surfaceAlt,
        valueIndicatorTextStyle: d.text.value,
        trackHeight: 3,
      ),
      child: Slider(
        value: value,
        onChanged: onChanged,
        min: min,
        max: max,
        divisions: divisions,
        label: label,
      ),
    );
  }
}
