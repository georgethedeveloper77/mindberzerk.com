import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/prefs/prefs_repository.dart';
import 'theme_registry.dart';
import 'theme_spec.dart';

/// versionCode of this build. A theme whose `minAppVersion` exceeds it targets
/// features this APK does not have, so it must not load.
const _appVersionCode = 6;

/// The active theme's SPEC: the distro's defaults, before user overrides.
///
/// Nothing renders from this directly. Shells watch effectiveThemeProvider,
/// which merges this with LauncherPrefs. Reading the spec straight from a widget
/// is how a setting silently stops working in one place.
///
/// Resolution, in order, with a GUARANTEED landing:
///   1. the user's selected theme, if it loads and targets this build;
///   2. otherwise bundled Ubuntu, which always exists and always fits.
///
/// A too-new or corrupt theme falls BACK rather than throwing. The old code
/// threw on a minAppVersion miss, which would black-screen the home after a
/// downgrade or a bad CDN pack. The registry's rule is the opposite: the
/// launcher must ALWAYS render, so a bad theme silently becomes Ubuntu.
final activeThemeSpecProvider = FutureProvider<ThemeSpec>((ref) async {
  // Watching (not reading) is the whole point: change the selection and this
  // provider re-runs, effectiveThemeProvider rebuilds on top of it, and the
  // live desktop repaints.
  final selectedId = await ref.watch(selectedThemeIdProvider.future);

  // 1. The selection. `bundledAssetFor` already resolves an unknown/null id to
  //    Ubuntu, so a stale or typo'd selection can't get past the version gate
  //    as anything but Ubuntu.
  final selected = await _load(bundledAssetFor(selectedId));
  if (selected != null && selected.minAppVersion <= _appVersionCode) {
    return selected;
  }

  // 2. Guaranteed fallback. Bundled Ubuntu is in the APK and targets this
  //    build by construction, so this is the floor.
  final ubuntu = await _load(bundledAssetFor(fallbackThemeId));
  if (ubuntu != null) return ubuntu;

  // 3. Ubuntu itself failed to parse. That's a broken APK, not a runtime state
  //    we can recover from by swapping themes. Fail loudly so it's caught in
  //    dev, not shipped.
  throw StateError(
    'Bundled Ubuntu theme failed to load: the APK asset is missing or corrupt.',
  );
});

/// Load and parse a bundled theme.json. Returns null on ANY failure (missing
/// asset, malformed JSON, unexpected shape) so the caller falls back instead of
/// throwing on the home screen.
Future<ThemeSpec?> _load(String assetPath) async {
  try {
    final raw = await rootBundle.loadString(assetPath);
    return ThemeSpec.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  } catch (_) {
    return null;
  }
}
