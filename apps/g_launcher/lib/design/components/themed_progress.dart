import 'package:flutter/material.dart';

import 'chrome_theme.dart';

/// Loading indicators in the distro accent. Circular for spot loads, linear for
/// determinate/indeterminate bars (theme downloads land here in Phase C).
///
/// Named constructors instead of a bool flag so call sites read as
/// `ThemedProgress.circular()` — clearer than `ThemedProgress(linear: false)`.
class ThemedProgress extends StatelessWidget {
  const ThemedProgress.circular({super.key, this.size = 24, this.strokeWidth = 2.5})
      : _linear = false,
        value = null;

  /// [value] null = indeterminate; 0..1 = determinate (download progress).
  const ThemedProgress.linear({super.key, this.value})
      : _linear = true,
        size = 0,
        strokeWidth = 0;

  final bool _linear;
  final double size;
  final double strokeWidth;
  final double? value;

  @override
  Widget build(BuildContext context) {
    final c = ChromeScope.of(context).colors;
    if (_linear) {
      return LinearProgressIndicator(
        value: value,
        color: c.accent,
        backgroundColor: c.lineStrong,
        minHeight: 3,
      );
    }
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        color: c.accent,
        // A faint track ring so the spinner reads on any surface.
        backgroundColor: c.line,
      ),
    );
  }
}
