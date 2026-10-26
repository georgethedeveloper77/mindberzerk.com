import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'i18n/strings.g.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Edge to edge on every Android version, as Android 15 does by default:
  // the app draws behind clear system bars and every screen keeps its
  // content clear of them with SafeArea.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarContrastEnforced: false,
  ));
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Debug crashes stay local; only release builds report.
  final crashlytics = FirebaseCrashlytics.instance;
  await crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);

  // Framework errors (build, layout, paint) and uncaught async errors both
  // reach Crashlytics, so a broken release is visible within minutes.
  FlutterError.onError = crashlytics.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    crashlytics.recordError(error, stack, fatal: true);
    return true;
  };

  // Both bundled faces are OFL, which asks for the licence to travel with
  // the font; this lists them under Settings, Licences.
  LicenseRegistry.addLicense(() async* {
    for (final (name, file) in const [
      ('Plus Jakarta Sans', 'PlusJakartaSans-OFL.txt'),
      ('Geist Mono', 'Geist-OFL.txt'),
    ]) {
      yield LicenseEntryWithLineBreaks([name], await rootBundle.loadString('assets/fonts/licences/$file'));
    }
    // Credits for the data behind the maps and checks, kept here rather
    // than on the screens themselves.
    yield const LicenseEntryWithLineBreaks(
      ['Have I Been Pwned'],
      'Password checks use Pwned Passwords by Troy Hunt (haveibeenpwned.com). Data breaches come from the '
          'Have I Been Pwned breach catalogue (haveibeenpwned.com), licensed under CC BY 4.0.',
    );
    yield const LicenseEntryWithLineBreaks(
      ['OONI'],
      "What's blocked shows, for the user's country, results from the Open Observatory of Network Interference "
          '(ooni.org), published as open data under its terms.',
    );
    yield const LicenseEntryWithLineBreaks(
      ['Natural Earth'],
      'Country outlines from Natural Earth (naturalearthdata.com), in the public domain.',
    );
  });

  // Strings follow the phone's language; English when it has no file.
  LocaleSettings.useDeviceLocale();
  runApp(ProviderScope(child: TranslationProvider(child: const GVpnApp())));
}
