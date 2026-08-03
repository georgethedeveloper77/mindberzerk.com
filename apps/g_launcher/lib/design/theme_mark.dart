/// A distro's brand mark, drawn from a RESOLVED [ThemeAsset].
///
/// ─── WHY THIS IS A WIDGET AND NOT FOUR COPIES OF FOUR BRANCHES ──────────────
///
/// Drawing a theme's logo means answering four questions, and every reader was
/// answering them separately:
///
///   1. is there artwork at all, or does this fall back
///   2. is it an SVG or a raster
///   3. is it bundled in the APK or a file inside an installed pack
///   4. is it painted as authored or knocked out to one colour
///
/// Question 3 is the one that kept being missed. `AssetImage` on an installed
/// pack's bare `logo_dark.webp` throws inside the image pipeline, Flutter logs
/// it once, and the user sees nothing where the mark should be: no exception
/// reaches the widget, nothing reaches Crashlytics, and the bug reads as "the
/// pack did not download". `_Strip` in wallpaper_screen.dart carries the same
/// scar for wallpapers; the splash carried it; `LauncherBrandIcon` and the Aqua
/// menu bar carried it after that.
///
/// [ThemeSpec.logoAsset] removes the chance to get 3 wrong by never handing out
/// a string. This removes the chance to get 1, 2 and 4 inconsistent, which is
/// the other half: before it, the splash tinted on every surface, the drawer
/// tinted only on dark ones, and the Aqua bar tinted always, so the same
/// artwork appeared as three different marks in one app.
///
/// ─── THE TINT, AND WHY EVERY THEME MARK NOW PASSES null ─────────────────────
///
/// [tint] null means "as authored", and that is what all three readers of a
/// THEME's logo pass. srcIn keeps the artwork's alpha and replaces every opaque
/// pixel, so tinting Ubuntu's mark to `onDark` turned an orange disc with white
/// friends inside it into one white circle, on the splash, in the dock and in
/// the drawer at once.
///
/// The argument for tinting was that a coloured mark can go muddy on dark
/// chrome. It contradicts the reason [ThemeLogo] is a PAIR: the dark variant is
/// already artwork authored for a dark surface, so knocking it out discards
/// exactly what the second variant exists to preserve. A pack shipping a mark
/// that cannot read on its own has shipped the wrong file.
///
/// The parameter stays, and stays the caller's, because the FALLBACKS use it:
/// the Mindhunter mark and the Aqua menu glyph are single monochrome shapes
/// that have to read on every distro, and those are tinted on purpose. What
/// must not happen is each caller deciding by accident, which is how the same
/// artwork came to appear as three different marks in one app.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../engine/theme_source.dart';

class ThemeMark extends StatelessWidget {
  const ThemeMark({
    super.key,
    required this.asset,
    required this.size,
    this.tint,
    this.fallback,
  });

  /// From [ThemeSpec.logoAsset]. Null means the theme ships no logo.
  final ThemeAsset? asset;

  final double size;

  /// Knock the artwork out to this colour, or null to paint it as authored.
  final Color? tint;

  /// Drawn when there is no artwork, or when the file is missing.
  ///
  /// NOT size-constrained, deliberately. The splash falls back to the distro's
  /// name in its display font, which is wider than the mark it replaces, and
  /// clipping it to a square would trade one invisible mark for another.
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    final a = asset;
    if (a == null) return fallback ?? const SizedBox.shrink();

    // Read off the RESOLVED path, which for an installed pack is absolute and
    // for a bundled theme is the authored asset path. Both end in the same
    // filename, so this is the same answer either way.
    if (a.path.toLowerCase().endsWith('.svg')) {
      final filter =
          tint == null ? null : ColorFilter.mode(tint!, BlendMode.srcIn);

      // flutter_svg has no entry point taking an ImageProvider, so this is the
      // one place in the app where the file/asset split is spelled out twice.
      return SizedBox(
        width: size,
        height: size,
        child: a.isFile
            ? SvgPicture.file(
                File(a.path),
                width: size,
                height: size,
                colorFilter: filter,
              )
            : SvgPicture.asset(
                a.path,
                width: size,
                height: size,
                colorFilter: filter,
              ),
      );
    }

    // ONE `Image`, taking the provider. `ThemeAsset.image` is the single place
    // that decides between FileImage and AssetImage, so raster artwork needs no
    // branch here and cannot drift from the rest of the app.
    return Image(
      image: a.image,
      width: size,
      height: size,
      color: tint,
      // Ignored when color is null, which is what leaves authored artwork
      // untouched.
      colorBlendMode: BlendMode.srcIn,
      filterQuality: FilterQuality.medium,
      // A pack whose files were swept, or a bundled path that no longer
      // exists. Landing on the fallback means the worst case is a plainer
      // surface rather than an empty one.
      errorBuilder: (_, __, ___) => fallback ?? const SizedBox.shrink(),
    );
  }
}
