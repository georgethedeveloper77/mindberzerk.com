import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/content/content_store.dart';
import '../core/i18n/g_strings.dart';
import '../features/learn/state/learn_providers.dart';
import '../features/onboarding/onboarding_page.dart';
import '../features/onboarding/state/onboarding_providers.dart';
import '../features/recovery/state/recovery_providers.dart';
import 'splash_screen.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';
import 'theme/tokens.dart';

class GRecoveryApp extends ConsumerWidget {
  const GRecoveryApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GThemeState theme = ref.watch(gThemeProvider);

    // Both themes are rebuilt when the accent changes, not just the active one.
    // Otherwise switching accent in dark mode leaves a stale light theme that
    // reappears the moment the system flips at sunrise.
    final GTokens darkTokens = GTokens.dark(theme.accent);
    final GTokens lightTokens = GTokens.light(theme.accent);

    final Brightness platform = MediaQuery.platformBrightnessOf(context);
    final bool resolvedDark = switch (theme.mode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system => platform == Brightness.dark,
    };
    SystemChrome.setSystemUIOverlayStyle(
      gSystemOverlay(resolvedDark ? darkTokens : lightTokens),
    );

    return MaterialApp(
      title: 'G Recovery',
      debugShowCheckedModeBanner: false,
      theme: buildGTheme(lightTokens),
      darkTheme: buildGTheme(darkTokens),
      themeMode: theme.mode,
      themeAnimationDuration: GMotion.normal,
      themeAnimationCurve: GMotion.enter,
      // ABOVE the routes, not inside a screen.
      //
      // Mounted here so every page, dialog and sheet in the app sees the same
      // table, and so choosing a language rebuilds all of them at once rather
      // than screen by screen as each happens to rebuild.
      //
      // While the pack loads, English. The alternative is a blank frame on
      // every cold start to save one frame of the wrong language.
      builder: (BuildContext context, Widget? child) => GStringsScope(
        strings: ref.watch(gStringsProvider).value ?? const GStrings.english(),
        child: child ?? const SizedBox.shrink(),
      ),
      home: const _RootGate(),
    );
  }
}

/// Onboarding or the shell, decided on the first frame.
///
/// The flag is read synchronously from the injected prefs store, so there is no
/// moment where the shell paints and then swaps to onboarding. That flash is
/// what makes a first launch look broken on a slow device.
class _RootGate extends ConsumerStatefulWidget {
  const _RootGate();

  @override
  ConsumerState<_RootGate> createState() => _RootGateState();
}

class _RootGateState extends ConsumerState<_RootGate> {
  /// Whether the splash has had its two seconds.
  ///
  /// ─── ONCE PER PROCESS, NOT ONCE PER LAUNCH ───────────────────────────────
  ///
  /// State on the gate rather than a stored flag, so it plays when the app is
  /// cold started and never again while it stays in memory. A splash that
  /// replayed every time someone switched back from the camera would be the
  /// most irritating thing in the app.
  bool _splashDone = false;

  @override
  void initState() {
    super.initState();
    // One content sync per launch, fired and forgotten.
    //
    // Nothing waits on it. The app is fully usable on its bundled content, and
    // blocking a screen on a network call would trade a working app for a
    // marginally fresher one. The post frame callback is not optional: reading
    // a provider during initState writes to the container while the first frame
    // is still being built.
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncContent());
  }

  Future<void> _syncContent() async {
    final result = await ref.read(contentSyncProvider.future);
    if (!mounted || result == null || !result.changed) return;
    // Only invalidate when something actually landed. Invalidating on every
    // launch would re-read and re-push the trashmap for no reason, and on a
    // budget device that is a visible hitch on the screen the user is looking
    // at.
    ref.invalidate(trashMapReadyProvider);
    ref.invalidate(learnBookProvider);
  }

  @override
  Widget build(BuildContext context) {
    // The splash sits in front of BOTH, deliberately.
    //
    // Onboarding opens on its own animation, and cutting straight from a cold
    // start into that gives two animations back to back with no beat between
    // them. The splash is also where the theme resolves, so the first thing
    // drawn is already in the user's accent rather than flipping a frame later.
    if (!_splashDone) {
      return SplashScreen(
        onDone: () {
          if (mounted) setState(() => _splashDone = true);
        },
      );
    }

    final bool done = ref.watch(onboardingDoneProvider);
    return done ? const GShell() : const OnboardingPage();
  }
}
