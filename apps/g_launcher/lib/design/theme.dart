import 'package:flutter/material.dart';

import 'tokens/colors.dart';

export 'tokens/colors.dart';
export 'tokens/radii.dart';
export 'tokens/spacing.dart';
export 'tokens/typography.dart';

/// House ThemeData — applies to Settings, Themes, dialogs.
/// The desktop shells do NOT use this; they are painted from a ThemeSpec.
ThemeData buildGTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: GColors.bg,
    colorScheme: base.colorScheme.copyWith(
      surface: GColors.surface,
      primary: GColors.accent,
      error: GColors.danger,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: GColors.text,
      displayColor: GColors.text,
    ),
    dividerColor: GColors.line,
    // InkRipple, not InkSparkle: the sparkle splash is shader-based and can
    // cost a frame on first touch on a budget device.
    splashFactory: InkRipple.splashFactory,
  );
}
