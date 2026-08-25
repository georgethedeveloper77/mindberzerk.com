import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'bootstrap.dart';
import 'core/crash.dart';
import 'core/exit_info.dart';
import 'core/freeze_watchdog.dart';
import 'data/prefs/prefs_repository.dart';
import 'engine/font_catalogue.dart';
import 'firebase_options.dart';
import 'i18n/i18n.dart';

Future<void> main() async {
  bootstrap();

  await _initFirebase();

  _registerFontLicences();

  // Resolved before the first frame so the shell never renders with defaults
  // and then flickers into the user's real settings a frame later.
  final sharedPrefs = await SharedPreferences.getInstance();

  // Language is resolved here for the same reason: the saved locale (or the
  // device match) plus its strings are loaded before the first frame, so the
  // installer's first screen is already in the right language rather than
  // flashing English and then swapping.
  final initialI18n = await loadInitialI18n();

  runApp(
    ProviderScope(
      overrides: [
        prefsStoreProvider.overrideWithValue(SharedPrefsStore(sharedPrefs)),
        i18nProvider.overrideWith(() => I18nController(initialI18n)),
      ],
      child: const GLauncherApp(),
    ),
  );
}

/// Brings up Firebase, and REFUSES to let it take the launcher down with it.
///
/// Without this call `FirebaseAnalytics.instance` throws "No Firebase App
/// '[DEFAULT]' has been created" on first use. Analytics wraps its own calls in
/// a catch, so the result was not a crash — it was worse: every event silently
/// discarded, and a dashboard reading zero that looks exactly like a product
/// nobody uses.
///
/// The try/catch here is the opposite concern. This is the HOME SCREEN: if
/// Google Play Services is missing, disabled, or the device is a de-Googled ROM
/// (which is squarely in the audience for a Linux-desktop launcher), Firebase
/// init fails — and a phone that cannot reach its home screen because telemetry
/// would not start is a bricked phone. Analytics is optional; the desktop is not.
/// Crashlytics is enabled INSIDE the try, on the success path only, and that
/// placement is the whole point. `Crash.record` is called from an error handler;
/// if it reached an uninitialised Firebase it would throw from inside the code
/// that exists to handle throwing, and the second exception is the one that
/// takes the launcher down. On the exact devices this catch was written for.
///
/// `Crash.installEarly()` has already been running since `bootstrap()`, so
/// anything that failed on the way here is buffered and gets flushed by
/// `enable()` rather than lost.
Future<void> _initFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await Crash.enable();

    // WHY THE PREVIOUS PROCESS DIED, and why this is not part of the watchdog.
    //
    // The watchdog below catches a launcher that stalls and recovers. It cannot
    // catch one that is KILLED, because the kill takes the isolate and its
    // timer with it. The system keeps that record instead, and this is the one
    // call that reads it. Six LOW_MEMORY exits in fourteen hours produced no
    // Crashlytics report of any kind before this line existed.
    //
    // NOT awaited, deliberately. It is a platform round trip plus a handful of
    // `recordError` calls, and every millisecond between here and `runApp` is a
    // millisecond of blank screen after a home press. Nothing downstream reads
    // its result.
    unawaited(ExitInfo.reportPending());

    // Only once there is somewhere to send its findings. Started earlier it
    // would just buffer reports about a startup that has not finished.
    FreezeWatchdog.start();
  } catch (e) {
    debugPrint('Firebase init failed; analytics disabled for this run ($e)');
  }
}

/// The Ubuntu Font Licence 1.0 permits redistribution inside an app, and this
/// is the condition: the licence ships with the fonts. Registering it here puts
/// it in `showLicensePage()`, which is the standard place a reviewer looks.
///
/// Note the contrast with debt item 8 in the handoff — the *typeface* is safe to
/// bundle; the Ubuntu wallpapers and the Yaru icon set are a separate question
/// and are not settled by this.
///
/// ─── AND THE FAMILIES THE USER FETCHES ──────────────────────────────────────
///
/// A family chosen in Settings arrives from the Play Services font provider,
/// which hands over font bytes and no licence text at all. The obligation does
/// not arrive with them: OFL and Apache-2.0 both require the notice to travel
/// with the font, and this app renders its whole interface in whatever the user
/// picked.
///
/// So the three texts ship in the APK and the catalogue says which one each
/// family carries. Registering ALL THREE unconditionally rather than only the
/// ones actually loaded is a deliberate simplification: the alternative is
/// threading the live font choice into a licence callback that runs long after
/// it was made, to save a few kilobytes on a page almost nobody opens. The
/// families list on each entry is what makes the page honest about scope.
///
/// Lazy: the callback only runs if someone opens the licence page.
void _registerFontLicences() {
  LicenseRegistry.addLicense(() async* {
    final ubuntu =
        await rootBundle.loadString('assets/fonts/UBUNTU-FONT-LICENCE-1.0.txt');
    yield LicenseEntryWithLineBreaks(const ['Ubuntu', 'UbuntuMono'], ubuntu);

    // Read from the catalogue rather than hardcoded, so adding a family to
    // assets/fonts/catalogue.json cannot leave its licence unlisted.
    final catalogue = await FontCatalogue.load();
    for (final licence in const ['ofl', 'apache']) {
      final families = catalogue.families
          .where((e) => e.licence == licence)
          .map((e) => e.family)
          .toList(growable: false);
      if (families.isEmpty) continue;

      try {
        final text = await rootBundle
            .loadString('assets/fonts/licences/$licence.txt');
        yield LicenseEntryWithLineBreaks(families, text);
      } catch (e) {
        // A missing licence file must not take the licence PAGE down, which is
        // the one screen a reviewer is guaranteed to open.
        debugPrint('Licence text $licence.txt missing: $e');
      }
    }
  });
}

/// Debug-only guard against the silent-fallback bug.
///
/// If the family name in pubspec.yaml does not byte-for-byte match the one in
/// theme.json, Flutter does not warn — it quietly renders Roboto, and you ship a
/// "faithful Ubuntu theme" in Google's typeface. Authenticity is the entire
/// differentiator, so this failure has to be loud.
///
/// Call from a shell's initState during bring-up, then delete it.
void debugAssertFontsLoaded() {
  assert(() {
    for (final family in const ['Ubuntu', 'UbuntuMono']) {
      final styled = (TextPainter(
        text: TextSpan(text: 'MWil1', style: TextStyle(fontFamily: family)),
        textDirection: TextDirection.ltr,
      )..layout())
          .width;
      final roboto = (TextPainter(
        text: const TextSpan(text: 'MWil1'),
        textDirection: TextDirection.ltr,
      )..layout())
          .width;
      if (styled == roboto) {
        debugPrint(
          '⚠️  Font "$family" measured identically to the default — it is very '
          'likely NOT loaded. Check the fonts: block in pubspec.yaml and that '
          'the family string matches theme.json exactly.',
        );
      }
    }
    return true;
  }());
}
