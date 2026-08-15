import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_info.dart';
import '../core/logging.dart';
import '../core/prefs/prefs_keys.dart';
import '../core/prefs/prefs_store.dart';
import 'app.dart';
import 'theme/theme_controller.dart';
import 'theme/tokens.dart';

/// How long the splash will wait for a font file.
///
/// Two seconds is long enough for a cached face to resolve off disk on a slow
/// device and short enough that a phone with no signal is not held at a blank
/// screen. On timeout the app paints in the platform face and swaps when the
/// download lands, which is a visible reflow but a rare one: it happens on the
/// first launch after choosing a face and never again.
const Duration _fontWarmup = Duration(seconds: 2);

/// Resolves everything the first frame needs, then hands back the root widget.
///
/// SharedPreferences is awaited here on purpose. Reading it asynchronously
/// inside the widget tree means the app paints one frame with the default theme
/// and then snaps to the user's choice, which reads as a bug on a slow device.
Future<Widget> bootstrapGRecovery() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final PrefsStore store = PrefsStore(prefs);

  // The same read the theme controller will do a moment later, done early
  // because the typeface has to be resolved before anything measures a line of
  // text. The controller repeats it rather than receiving it, so there is one
  // decoder for this blob and not two.
  final GThemeState theme = GThemeState.fromJson(
    store.readJson(GPrefsKeys.theme),
  );
  GType.install(theme.typeface);

  // Started here and awaited below, so it runs alongside the font warmup
  // rather than after it. The warmup is network bound and this is a single
  // binder call, and putting them in sequence would add the cheap one to the
  // launch time of the expensive one for nothing.
  final Future<GAppInfo> pendingInfo = GAppInfo.read();
  await _warmFonts(theme);
  final GAppInfo appInfo = await pendingInfo;

  return ProviderScope(
    overrides: <Override>[
      prefsStoreProvider.overrideWithValue(store),
      gAppInfoProvider.overrideWithValue(appInfo),
    ],
    child: const GRecoveryApp(),
  );
}

/// Waits for the chosen face to be loadable, within reason.
///
/// GType.install has already asked google_fonts for every style in the ramp,
/// which is what puts the download in flight. This awaits that, so the splash
/// is drawn in the face the user chose rather than in the platform default
/// followed by a jump.
///
/// The System face asks for nothing, so this returns immediately and the
/// default install pays no launch cost at all.
Future<void> _warmFonts(GThemeState theme) async {
  if (theme.typeface.isSystem) return;
  try {
    await GoogleFonts.pendingFonts().timeout(_fontWarmup);
  } on Object catch (cause) {
    // Never fatal. A font that cannot be fetched is a cosmetic loss, and
    // holding the launch on it would turn a bad connection into a broken app.
    GLog.w('typeface warmup did not finish', scope: 'boot', cause: cause);
  }
}
