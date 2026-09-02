/// WHERE A THEME'S FILES LIVE.
///
/// A bundled theme's wallpaper is a file in the asset bundle and is opened with
/// [AssetImage]. A downloaded theme's wallpaper is a real file in app-private
/// storage and must be opened with [FileImage]. Same field in `theme.json`,
/// same string, two completely different ways to reach it.
///
/// This is the half of the render bridge that is easy to forget, because it
/// fails SILENTLY and in the least helpful way possible: `AssetImage('wall.jpg')`
/// on an installed theme throws inside the image pipeline, Flutter logs it once,
/// and the user sees a black rectangle where their paid distro's wallpaper
/// should be. No exception reaches the widget, nothing reaches Crashlytics, and
/// the bug reads as "the pack didn't download".
///
/// ─── ONE AUTHORED theme.json, RESOLVED TWO WAYS ─────────────────────────────
///
/// This used to flatten in ONE direction only. An installed pack's files are
/// bare filenames by construction — `PackPaths` refuses a name containing a
/// separator — so [ThemeSource.installed] takes the last path segment and joins
/// it to the pack directory. A BUNDLED path was returned unchanged, which
/// silently required the bundled `theme.json` to carry a full asset-bundle path
/// while the CDN copy of the same distro carried a bare name.
///
/// Two files, differing only in the SHAPE of every path in them, that are
/// otherwise supposed to be the same file. They stopped being the same file:
/// the CDN copy of `ubuntu-24-04` was pasted over the bundled one, every
/// wallpaper became a bare name, and `AssetImage('numbat_color.webp')` resolved
/// to nothing on every fresh install. Worse than a black rectangle, because the
/// launcher runs TRANSPARENT over the system wallpaper: the seed in
/// `effective_theme` encoded that bare name as `file://numbat_color.webp`,
/// native refused it, `applied` came back false, so `wallpaperAppliedForKey`
/// was correctly never written and the whole branch re-ran on every resolve,
/// forever, over whatever wallpaper happened to already be on the phone.
///
/// So bundled now flattens too, in the mirror direction: a bare name is joined
/// to `assets/themes/<themeId>/`. One authored `theme.json` is now genuinely
/// correct in both places, which is what the rest of this file already assumed.
///
/// This requires the bundled layout to be FLAT, matching a pack's. It was
/// `assets/themes/<id>/wallpapers/<file>`; the `wallpapers/` level is gone and
/// the `pubspec.yaml` entries went with it. A path that still arrives fully
/// qualified (`assets/…`) is passed through untouched, so a theme.json authored
/// against the old layout keeps working.
library;

import 'dart:io';

import 'package:flutter/widgets.dart';

@immutable
class ThemeSource {
  /// Ships inside the APK, under `assets/themes/[themeId]/`.
  ///
  /// The id is REQUIRED, and that is the whole change: resolving a bare name
  /// needs to know which theme's directory it is bare relative to, and this is
  /// the only object that could ever know.
  const ThemeSource.bundled(String this.themeId) : dir = null;

  /// Downloaded and installed. [dir] is the absolute pack directory that
  /// `installedPackDir` handed back.
  const ThemeSource.installed(String this.dir) : themeId = null;

  /// PEEKED: the pack's `theme.json` arrived, and nothing else did.
  ///
  /// ─── WHY THIS IS NOT [bundled] ──────────────────────────────────────────
  ///
  /// `theme_peek` used to leave a peeked spec carrying the default bundled
  /// source, and its own docblock warned at length that asking such a spec for
  /// a wallpaper produced an `AssetImage` for a file that does not exist. That
  /// was survivable only because every renderer reads `PeekedTheme.assetsOnDisk`
  /// instead of trusting the spec — a flag and a source saying opposite things,
  /// with a comment holding them together.
  ///
  /// Now that bundled RESOLVES, leaving peek on it would be worse: a peeked
  /// Kali would confidently name `assets/themes/kali-2024/wall.webp`, which is
  /// a plausible path in a directory that was never in the APK. This member
  /// says the honest thing instead — the files are not reachable from here —
  /// and [ThemeAsset.exists] reports false for everything it hands out, so a
  /// renderer that forgets the flag degrades to the fallback rather than to a
  /// hole.
  const ThemeSource.remote()
      : dir = null,
        themeId = null;

  /// null for bundled and remote. Absolute directory for installed.
  final String? dir;

  /// null for installed and remote. The theme id for bundled.
  final String? themeId;

  bool get isBundled => themeId != null;

  bool get isInstalled => dir != null;

  /// Resolve one theme-relative path to something that can actually be opened.
  ///
  /// FLAT EITHER WAY. An authored `wallpapers/dawn.jpg` and an authored
  /// `dawn.jpg` land on the same file in both locations, because a pack cannot
  /// lay out subdirectories on device and the bundled tree now mirrors that.
  /// Taking the last segment is both the correct join and, for free, the reason
  /// a `../../` can never come out of here.
  ThemeAsset asset(String path) {
    final d = dir;
    if (d != null) {
      final name = path.split('/').last;
      // A path that is nothing but separators. Not reachable from a sane pack,
      // but the alternative is handing FileImage the pack directory itself.
      if (name.isEmpty) return ThemeAsset._(path: path, isFile: false);
      return ThemeAsset._(path: '$d/$name', isFile: true);
    }

    final id = themeId;
    // Remote: nothing on this device backs this string. Handed back as-is so
    // callers keep a usable path for logs and keys, with `exists` false.
    if (id == null) {
      return ThemeAsset._(path: path, isFile: false, reachable: false);
    }

    // Already fully qualified. A theme.json authored against the old nested
    // layout, or anything else naming a real bundle key, is left alone.
    if (path.startsWith('assets/')) {
      return ThemeAsset._(path: path, isFile: false);
    }

    final name = path.split('/').last;
    if (name.isEmpty) return ThemeAsset._(path: path, isFile: false);
    return ThemeAsset._(path: 'assets/themes/$id/$name', isFile: false);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ThemeSource && other.dir == dir && other.themeId == themeId);

  @override
  int get hashCode => Object.hash(dir, themeId);

  @override
  String toString() => switch ((dir, themeId)) {
        (final d?, _) => 'ThemeSource.installed($d)',
        (_, final t?) => 'ThemeSource.bundled($t)',
        _ => 'ThemeSource.remote',
      };
}

/// One resolved asset: a path plus the knowledge of how to open it.
@immutable
class ThemeAsset {
  const ThemeAsset._({
    required this.path,
    required this.isFile,
    this.reachable = true,
  });

  /// An asset-bundle path when [isFile] is false, an absolute file path when
  /// it is true.
  final String path;

  final bool isFile;

  /// False only for [ThemeSource.remote], where the string names a file that is
  /// not on this device at all. Kept separate from [existsSync] because that
  /// one asks a question of the filesystem and this one is already known.
  final bool reachable;

  /// The provider to hand to [Image], [DecorationImage], etc.
  ///
  /// THE ONE PLACE that decides between the two. Every call site that currently
  /// writes `AssetImage(spec.wallpapers.first)` becomes
  /// `spec.source.asset(spec.wallpapers.first).image`, and installed themes
  /// start rendering with no further thought at that site.
  ImageProvider get image =>
      isFile ? FileImage(File(path)) : AssetImage(path);

  /// Cheap existence check, so a missing wallpaper can fall back to the palette
  /// gradient rather than painting a hole.
  ///
  /// Synchronous, so call it when a theme RESOLVES (once per switch), never in
  /// a build method. Bundled assets report true: the bundle cannot be probed
  /// synchronously and a missing bundled asset is a broken build, which is a
  /// build-time problem rather than a runtime one. A REMOTE asset reports
  /// false, because that one is known without asking.
  bool get existsSync {
    if (!reachable) return false;
    return !isFile || File(path).existsSync();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ThemeAsset &&
          other.path == path &&
          other.isFile == isFile &&
          other.reachable == reachable);

  @override
  int get hashCode => Object.hash(path, isFile, reachable);
}
