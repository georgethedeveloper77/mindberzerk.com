import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'bootstrap.dart';
import 'data/prefs/prefs_repository.dart';
import 'firebase_options.dart';

Future<void> main() async {
  bootstrap();

  await _initFirebase();

  _registerFontLicences();

  // Resolved before the first frame so the shell never renders with defaults
  // and then flickers into the user's real settings a frame later.
  final sharedPrefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        prefsStoreProvider.overrideWithValue(SharedPrefsStore(sharedPrefs)),
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
Future<void> _initFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
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
/// Lazy: the callback only runs if someone opens the licence page.
void _registerFontLicences() {
  LicenseRegistry.addLicense(() async* {
    final licence =
        await rootBundle.loadString('assets/fonts/UBUNTU-FONT-LICENCE-1.0.txt');
    yield LicenseEntryWithLineBreaks(const ['Ubuntu', 'UbuntuMono'], licence);
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
