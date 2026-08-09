import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/content/content_store.dart';
import '../features/learn/state/learn_providers.dart';
import '../features/onboarding/onboarding_page.dart';
import '../features/recovery/state/recovery_providers.dart';
import '../features/onboarding/state/onboarding_providers.dart';
import 'shell.dart';
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

    final Brightness platform =
        MediaQuery.platformBrightnessOf(context);
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
    final bool done = ref.watch(onboardingDoneProvider);
    return done ? const GShell() : const OnboardingPage();
  }
}
