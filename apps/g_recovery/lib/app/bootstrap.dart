import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/prefs/prefs_store.dart';
import 'app.dart';

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

  return ProviderScope(
    overrides: <Override>[
      prefsStoreProvider.overrideWithValue(PrefsStore(prefs)),
    ],
    child: const GRecoveryApp(),
  );
}
