/// Where `settings` and `themes` actually go.
///
/// ─── WHY THIS IS A FILE AND NOT A METHOD ON THE ADAPTER ─────────────────────
///
/// Opening a page needs a BuildContext, and an adapter has none. So the view
/// supplies the navigation, `GshShell` takes it as a REQUIRED parameter, and
/// wiring the terminal without one is a compile error rather than four commands
/// that quietly stop working.
///
/// This is also the only file in the terminal that knows a route exists.
library;

import 'package:flutter/material.dart';

import '../../../engine/effective_theme.dart';
import '../../settings/settings_screen.dart';
import '../../themes/themes_screen.dart';
import '../adapter/launcher_term_host.dart';
import '../term_host.dart';

/// The opener to hand to [GshShell].
///
/// Captures the shell's own context, which outlives every command the user
/// types, because the terminal is the page doing the pushing.
TermPageOpener launcherPages(BuildContext context, EffectiveTheme theme) {
  return (TermLauncherPage page) async {
    switch (page) {
      case TermLauncherPage.settings:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SettingsScreen(theme: theme),
          ),
        );
        return const TermOutcome.ok();

      case TermLauncherPage.themes:
        // No theme argument: ThemesScreen reads the active one itself, the same
        // way the settings row that opens it does.
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const ThemesScreen()),
        );
        return const TermOutcome.ok();

      // ─── NOT REACHABLE YET, AND NOT GUESSED ───────────────────────────
      //
      // Wallpaper and icon packs are not top-level screens. They live inside
      // `appearanceSection`, which is pushed by `_openSection`, and that is
      // private to settings_screen.dart. Opening them needs either that helper
      // made public or the section's own screen, and inventing a class name
      // here would be a route that compiles and then throws.
      //
      // Nothing is lost meanwhile: `wall` and `icons` are new commands, not
      // ones the terminal already had. They are listed in
      // LauncherTermHost.unwired, so they never appear in the ? sheet or the
      // match rows, and typing one explains itself.
      case TermLauncherPage.wallpaper:
      case TermLauncherPage.icons:
        return const TermOutcome.failed(
          'the wallpaper and icon pickers live inside Settings, Appearance',
        );
    }
  };
}
