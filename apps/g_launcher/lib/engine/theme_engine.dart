import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/prefs/prefs_repository.dart';
import '../platform/pack_api.g.dart';
import 'theme_registry.dart';
import 'theme_source.dart';
import 'theme_spec.dart';

/// ─── THE minAppVersion CHECK USED TO LIVE HERE, AS A HARDCODED 6 ───────────
///
/// `const _appVersionCode = 6` sat above this line while `pubspec.yaml` said
/// `6.0.0+7` and `PackVerifier` read the real number off `PackageManager`. Two
/// owners for one value, already one apart, and 6.1.0 would have made it two.
///
/// It is DELETED rather than synced, because the check could only ever be
/// wrong in one direction:
///
///   INSTALLED PACKS  cannot reach disk without `PackVerifier.verifyManifest`
///                    approving their minAppVersion against the REAL
///                    versionCode. Re-checking here against a copy that drifts
///                    downward can only refuse a pack the device already
///                    verified, install and hold — and it refuses it silently,
///                    falling back to Ubuntu with nothing logged.
///   BUNDLED THEMES   ship inside this exact APK, so their minAppVersion cannot
///                    exceed the build containing them. The check was
///                    unreachable, and a genuinely malformed bundled theme
///                    still falls through on a parse failure below.
///
/// One number, one owner, and the owner is the one that reads it from the
/// system rather than from a constant somebody has to remember to bump.

/// The one native handle. Instantiated once rather than per resolve: Pigeon's
/// generated class is a thin wrapper over a channel, but a new one per theme
/// switch is a new codec instance for no reason.
final _packApi = PackHostApi();

/// The active theme's SPEC: the distro's defaults, before user overrides.
///
/// Nothing renders from this directly. Shells watch effectiveThemeProvider,
/// which merges this with LauncherPrefs. Reading the spec straight from a widget
/// is how a setting silently stops working in one place.
///
/// ─── THE RENDER BRIDGE ──────────────────────────────────────────────────────
///
/// This provider used to know exactly one way to find a theme: open a bundled
/// asset. That was correct while every theme shipped in the APK, and it quietly
/// became the reason the entire publishing pipeline had no effect on a phone.
/// A pack could be authored in the panel, signed, uploaded, downloaded,
/// verified and installed, and this function would still hand back Ubuntu,
/// because an installed pack is not an asset and nothing here looked on disk.
///
/// Resolution, in order, with a GUARANTEED landing:
///   1. the selection, if it names a BUNDLED theme (free tier, always present);
///   2. otherwise the selection as an INSTALLED pack on disk;
///   3. otherwise bundled Ubuntu, which always exists and always fits.
///
/// Bundled is checked FIRST, not last. A bundled id can never also be installed
/// (bundled implies free, and free packs are not sold or downloaded), so the
/// ordering costs nothing — and it means the overwhelmingly common case, a user
/// on one of the three free distros, never makes a platform call at all.
///
/// A too-new or corrupt theme falls BACK rather than throwing, at every step.
/// The registry's rule is absolute: the launcher must ALWAYS render. A user with
/// a broken home screen has a bricked phone, and that is true whether the theme
/// broke because a CDN pack was malformed or because they downgraded the app.
final activeThemeSpecProvider = FutureProvider<ThemeSpec>((ref) async {
  // Watching (not reading) is the whole point: change the selection and this
  // provider re-runs, effectiveThemeProvider rebuilds on top of it, and the
  // live desktop repaints.
  final selectedId = await ref.watch(selectedThemeIdProvider.future);

  // 1. A bundled selection. Straight out of the APK, no platform call.
  if (selectedId != null && bundledThemes.containsKey(selectedId)) {
    final bundled = await _loadAsset(bundledThemes[selectedId]!.assetPath);
    if (bundled != null) return bundled;
    // A bundled theme that fails to parse is a broken APK, but it is not worth
    // black-screening over when Ubuntu is sitting right there. Fall through.
  }

  // 2. An installed pack. Also covers a selection this build has never heard
  //    of: an id from a newer catalogue simply is not on disk, and falls
  //    through to Ubuntu the same way a typo would.
  if (selectedId != null && selectedId.isNotEmpty) {
    final installed = await _loadInstalled(selectedId);
    if (installed != null) return installed;
    // Still falls through to Ubuntu when nothing is installed under this id —
    // a stale selection, a pack the user removed, or an id from a newer
    // catalogue this build has never seen.
    //
    // A minAppVersion MISS IS NOT AN ERROR, and it is now caught in the one
    // place that knows the real versionCode: `PackVerifier` refuses the pack at
    // install, `PackDownloader` reports `AppTooOld`, and the storefront card
    // says "needs a newer version of G Launcher" instead of a download that
    // silently produces nothing.
  }

  // 3. Guaranteed fallback. Bundled Ubuntu is in the APK and targets this
  //    build by construction, so this is the floor.
  final ubuntu = await _loadAsset(bundledAssetFor(fallbackThemeId));
  if (ubuntu != null) return ubuntu;

  // 4. Ubuntu itself failed to parse. That's a broken APK, not a runtime state
  //    we can recover from by swapping themes. Fail loudly so it's caught in
  //    dev, not shipped.
  throw StateError(
    'Bundled Ubuntu theme failed to load: the APK asset is missing or corrupt.',
  );
});

/// Load and parse a bundled theme.json. Returns null on ANY failure (missing
/// asset, malformed JSON, unexpected shape) so the caller falls back instead of
/// throwing on the home screen.
Future<ThemeSpec?> _loadAsset(String assetPath) async {
  try {
    final raw = await rootBundle.loadString(assetPath);
    return ThemeSpec.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  } catch (_) {
    return null;
  }
}

/// Load an installed pack's theme.json off disk, tagged with where it lives.
///
/// The directory is fetched FIRST and is the short-circuit: it is a path lookup
/// rather than a file read, so the common "this id is not installed" case costs
/// nothing. It is also what makes `ThemeSource.installed` constructible, which
/// is what makes the theme's wallpapers and logo resolve to a `FileImage`
/// instead of an `AssetImage` pointing at nothing.
///
/// Every failure is null: not installed, files swept, half-written JSON, or the
/// platform channel not implemented at all (which is exactly the state of a
/// widget test, and a home screen that cannot be tested is a home screen nobody
/// tests).
Future<ThemeSpec?> _loadInstalled(String themeId) async {
  try {
    final dir = await _packApi.installedPackDir(themeId);
    if (dir == null || dir.isEmpty) return null;

    final raw = await _packApi.readInstalledTheme(themeId);
    if (raw == null || raw.isEmpty) return null;

    final spec = ThemeSpec.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    return spec.withSource(ThemeSource.installed(dir));
  } catch (_) {
    return null;
  }
}
