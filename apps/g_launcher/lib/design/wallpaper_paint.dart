import 'package:flutter/material.dart';

import '../engine/theme_spec.dart';
import '../engine/wallpaper_framing.dart';

/// Draws a wallpaper the way the phone will draw it.
///
/// ─── WHY THIS IS ONE WIDGET AND NOT A `DecorationImage` PER CALLER ──────────
///
/// Framing is a fact with four parts, and three of them are easy to leave out
/// of a `DecorationImage`: it takes a `fit` and an `alignment` but has nowhere
/// to put a zoom, and it has no opinion about what colour the bars are. So the
/// obvious implementation drops the zoom silently and letterboxes to whatever
/// the parent happens to be, and the preview on the settings page and the
/// wallpaper on the phone disagree in exactly the case the framing screen
/// exists to fix.
///
/// The same drift had already happened three times in this area with the SOURCE
/// string, which is why `encodeWallpaperFor` and `wallpaperImageFor` are single
/// functions rather than four inline branches. This is the same lesson applied
/// to the painting rather than the path.
///
/// ─── THE ARITHMETIC MATCHES NATIVE ON PURPOSE ───────────────────────────────
///
/// [WallpaperFraming.focalX] is 0 to 1 across the bitmap and Flutter's
/// [Alignment] is -1 to 1 across the box. They are the same fact, converted in
/// one line, so `WallpaperController.cropHint` and this widget cannot come to
/// different conclusions about where the subject is without somebody editing
/// that line.
class WallpaperPaint extends StatelessWidget {
  const WallpaperPaint({
    super.key,
    required this.image,
    required this.palette,
    this.framing = const WallpaperFraming(),
  });

  /// Null draws the palette alone, which is the right answer for a theme with
  /// no wallpaper and for a photo whose file has gone.
  final ImageProvider? image;

  /// The bars 'contain' and 'center' leave wear this theme's background,
  /// because that is the colour native fills them with: the Dart side passes
  /// `palette.bgTop` as `letterboxColor` on every apply. A preview showing
  /// black bars over a distro that letterboxes in aubergine would be a picture
  /// of a phone nobody has.
  final ThemePalette palette;

  final WallpaperFraming framing;

  @override
  Widget build(BuildContext context) {
    final align = Alignment(
      framing.focalX * 2 - 1,
      framing.focalY * 2 - 1,
    );

    final fit = switch (framing.resolvedFit) {
      'fill' => BoxFit.fill,
      'contain' => BoxFit.contain,
      // Actual size. Nothing scales it but the zoom below, which is the whole
      // meaning of the fit.
      'center' => BoxFit.none,
      _ => BoxFit.cover,
    };

    return ColoredBox(
      color: palette.bgTop,
      child: ClipRect(
        child: image == null
            ? const SizedBox.expand()
            : Transform.scale(
                scale: framing.zoom,
                alignment: align,
                child: Image(
                  image: image!,
                  fit: fit,
                  alignment: align,
                  width: double.infinity,
                  height: double.infinity,
                  // A swept pack or a deleted photo. Draw the palette rather
                  // than Flutter's exception box: every caller here is showing
                  // a picture inside a settings page, where a red error panel
                  // tells the reader nothing they can act on and looks like the
                  // page itself has broken.
                  errorBuilder: (context, error, stack) =>
                      ColoredBox(color: palette.bgTop),
                ),
              ),
      ),
    );
  }
}
