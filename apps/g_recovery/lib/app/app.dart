import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g_recovery/app/shell.dart';

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

/// The languages Flutter itself can dress, out of the ones this app offers.
///
/// ─── ASKED, NOT ASSERTED ─────────────────────────────────────────────────────
///
/// GStrings covers the words this app wrote. It does not cover the text
/// selection menu, the date picker, the scrollbar semantics or the dozen other
/// strings that live inside the framework, and those come from
/// flutter_localizations, which supports its own list of languages and not
/// necessarily ours. Hausa is the current example.
///
/// Naming a locale here that the delegates cannot serve is not a soft failure.
/// Localizations finds no MaterialLocalizations for it and the first Material
/// widget to ask throws. So the list is built by asking each delegate, which
/// also means it grows by itself as Flutter adds languages, with no edit here.
///
/// A language that misses this list still works: the app's own copy is in that
/// language and the framework's own strings fall back to English. That is the
/// same partial translation the picker already warns about.
final List<Locale> gSupportedLocales = <Locale>[
  for (final GLanguage language in GLanguage.all)
    if (_dressable(Locale(language.code))) Locale(language.code),
];

bool _dressable(Locale locale) =>
    GlobalMaterialLocalizations.delegate.isSupported(locale) &&
    GlobalWidgetsLocalizations.delegate.isSupported(locale) &&
    GlobalCupertinoLocalizations.delegate.isSupported(locale);

class GRecoveryApp extends ConsumerWidget {
  const GRecoveryApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GThemeState theme = ref.watch(gThemeProvider);
    final String code = ref.watch(gLocaleProvider);

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
      title: context.s('G Recovery'),
      debugShowCheckedModeBanner: false,
      theme: buildGTheme(lightTokens),
      darkTheme: buildGTheme(darkTokens),
      themeMode: theme.mode,
      themeAnimationDuration: GMotion.normal,
      themeAnimationCurve: GMotion.enter,
      // The choice made in the picker, not the one the phone was set to.
      //
      // Passing this overrides the system locale list entirely, which is the
      // point: someone whose phone is in French and who chose Kiswahili in this
      // app gets Kiswahili, and the framework's own strings follow rather than
      // staying French. An unsupported code resolves back to English for the
      // framework only, and never throws, because gSupportedLocales was built
      // by asking.
      locale: Locale(code),
      supportedLocales: gSupportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // ABOVE the routes, not inside a screen.
      //
      // Mounted here so every page, dialog and sheet in the app sees the same
      // table, and so choosing a language rebuilds all of them at once rather
      // than screen by screen as each happens to rebuild.
      //
      // While the pack loads, English. The alternative is a blank frame on
      // every cold start to save one frame of the wrong language.
      //
      // ─── THE DIRECTION IS SET HERE, NOT INFERRED ─────────────────────────
      //
      // WidgetsApp already derives a direction from the resolved locale, and
      // for Arabic and Urdu it derives the right one. This states it anyway,
      // because the two can disagree: a right to left language that the
      // framework cannot dress resolves to English, and the app would then
      // render its own right to left words in a left to right layout. One
      // provider owns the answer and nothing below tests a language code
      // against a list of its own.
      builder: (BuildContext context, Widget? child) => Directionality(
        textDirection: ref.watch(gDirectionProvider),
        child: GStringsScope(
          strings:
              ref.watch(gStringsProvider).value ?? const GStrings.english(),
          child: child ?? const SizedBox.shrink(),
        ),
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
