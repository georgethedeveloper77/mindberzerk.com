/// WHERE A THEME'S FILES LIVE.
///
/// A bundled theme's wallpaper is `assets/themes/ubuntu-24-04/wall.jpg` and is
/// opened with [AssetImage]. A downloaded theme's wallpaper is a real file in
/// app-private storage and must be opened with [FileImage]. Same field in
/// `theme.json`, same string, two completely different ways to reach it.
///
/// This is the half of the render bridge that is easy to forget, because it
/// fails SILENTLY and in the least helpful way possible: `AssetImage('wall.jpg')`
/// on an installed theme throws inside the image pipeline, Flutter logs it once,
/// and the user sees a black rectangle where their paid distro's wallpaper
/// should be. No exception reaches the widget, nothing reaches Crashlytics, and
/// the bug reads as "the pack didn't download".
///
/// ─── FLAT FILENAMES, AND WHY THE SPLIT IS NOT PARANOIA ──────────────────────
///
/// Installed pack files are BARE FILENAMES by construction: `PackPaths`
/// refuses a name containing a separator, so a pack cannot lay out
/// subdirectories on device. A theme.json authored against the bundled layout
/// may still say `"wallpapers/dawn.jpg"`, and the same authored theme has to
/// work in both places. So the last path segment is taken and the rest is
/// dropped, which is both the correct join and, for free, the reason a
/// `../../` can never come out of here.
library;

import 'dart:io';

import 'package:flutter/widgets.dart';

@immutable
class ThemeSource {
  /// Ships inside the APK. Paths in `theme.json` are asset-bundle paths as
  /// authored.
  const ThemeSource.bundled() : dir = null;

  /// Downloaded and installed. [dir] is the absolute pack directory that
  /// `installedPackDir` handed back.
  const ThemeSource.installed(String this.dir);

  /// null for bundled. Absolute directory for installed.
  final String? dir;

  bool get isBundled => dir == null;

  /// Resolve one theme-relative path to something that can actually be opened.
  ThemeAsset asset(String path) {
    final d = dir;
    if (d == null) return ThemeAsset._(path: path, isFile: false);

    final name = path.split('/').last;
    // A path that is nothing but separators. Not reachable from a sane pack,
    // but the alternative is handing FileImage the pack directory itself.
    if (name.isEmpty) return ThemeAsset._(path: path, isFile: false);

    return ThemeAsset._(path: '$d/$name', isFile: true);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is ThemeSource && other.dir == dir);

  @override
  int get hashCode => dir.hashCode;

  @override
  String toString() => dir == null ? 'ThemeSource.bundled' : 'ThemeSource($dir)';
}

/// One resolved asset: a path plus the knowledge of how to open it.
@immutable
class ThemeAsset {
  const ThemeAsset._({required this.path, required this.isFile});

  /// An asset-bundle path when [isFile] is false, an absolute file path when
  /// it is true.
  final String path;

  final bool isFile;

  /// The provider to hand to [Image], [DecorationImage], etc.
  ///
  /// THE ONE PLACE that decides between the two. Every call site that currently
  /// writes `AssetImage(spec.wallpapers.first)` becomes
  /// `spec.source.asset(spec.wallpapers.first).image`, and installed themes
  /// start rendering with no further thought at that site.
  ImageProvider get image =>
      isFile ? FileImage(File(path)) : AssetImage(path);

  /// Cheap existence check for the file case, so a missing wallpaper can fall
  /// back to the palette gradient rather than painting a hole.
  ///
  /// Synchronous, so call it when a theme RESOLVES (once per switch), never in
  /// a build method. Bundled assets always report true: the bundle cannot be
  /// probed synchronously and a missing bundled asset is a broken APK, which is
  /// a build-time problem, not a runtime one.
  bool get existsSync => !isFile || File(path).existsSync();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ThemeAsset && other.path == path && other.isFile == isFile);

  @override
  int get hashCode => Object.hash(path, isFile);
}
