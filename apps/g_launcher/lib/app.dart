import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/prefs/setup_state.dart';
import 'design/theme.dart';
import 'features/home/home_screen.dart';
import 'features/setup/setup_screen.dart';

class GLauncherApp extends StatelessWidget {
  const GLauncherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'G Launcher',
      debugShowCheckedModeBanner: false,

      // House theme. This is for Settings / Themes / dialogs ONLY — the desktop
      // shells do not use it. They are painted from the active ThemeSpec.
      //
      // The copyWith is the third leg of wallpaper transparency, and the one
      // that is pure Dart. Even with a translucent window (styles.xml) and a
      // translucent Flutter surface (BackgroundMode.transparent), Material
      // paints scaffoldBackgroundColor and canvasColor on top and you get an
      // opaque desktop anyway. The wallpaper is behind THREE opaque layers by
      // default; all three have to be cleared.
      //
      // Every shell Scaffold must ALSO pass backgroundColor: Colors.transparent
      // — Scaffold reads the theme value at construction, and any screen that
      // hardcodes a colour re-introduces the bug locally.
      theme: buildGTheme().copyWith(
        scaffoldBackgroundColor: Colors.transparent,
        canvasColor: Colors.transparent,
      ),
      home: const _Root(),
    );
  }
}

/// Initial setup, or the desktop.
///
/// The gate lives here rather than inside HomeScreen deliberately. Setup ending
/// must MOUNT HomeScreen fresh, because that first mount is what plays the boot
/// for the theme just chosen (see `_maybeAutoBoot`). If setup were a screen
/// pushed over an already-running HomeScreen, popping it would reveal a desktop
/// that had booted before the user picked anything.
///
/// While the flag resolves, render nothing rather than a spinner. It is one
/// SharedPreferences read on an already-warmed engine, so it lands within a
/// frame or two — and a launcher that flashes a progress indicator before the
/// home screen feels broken, which is the same call home_screen makes for the
/// theme itself.
class _Root extends ConsumerWidget {
  const _Root();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final done = ref.watch(setupCompletedProvider);

    return done.when(
      loading: () => const SizedBox.shrink(),
      // A failed read must not strand the user in a wizard they cannot leave.
      // Assume set-up and let them reach Settings.
      error: (_, __) => const HomeScreen(),
      data: (complete) => complete ? const HomeScreen() : const SetupScreen(),
    );
  }
}
