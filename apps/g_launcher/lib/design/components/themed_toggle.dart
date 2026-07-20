import 'package:flutter/material.dart';

import 'chrome_theme.dart';

/// A switch, coloured from the chrome. Active track = the distro accent, so a
/// toggle turned on reads as "on-brand green" under Fedora and "Ubuntu orange"
/// under Ubuntu with no per-theme code.
///
/// Drop it straight into a [ThemedListRow]'s `trailing`.
class ThemedToggle extends StatelessWidget {
  const ThemedToggle({super.key, required this.value, required this.onChanged});

  final bool value;

  /// Null disables the control (greyed), matching [ThemedListRow.enabled].
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = ChromeScope.of(context).colors;
    return Switch(
      value: value,
      onChanged: onChanged,
      // Explicit colours on every state so the switch never falls through to
      // the host ThemeData.
      activeColor: c.onAccent, // thumb when on
      activeTrackColor: c.accent,
      inactiveThumbColor: c.textMuted,
      inactiveTrackColor: c.surfaceAlt,
      trackOutlineColor: WidgetStatePropertyAll(c.lineStrong),
      trackOutlineWidth: const WidgetStatePropertyAll(0.5),
    );
  }
}
