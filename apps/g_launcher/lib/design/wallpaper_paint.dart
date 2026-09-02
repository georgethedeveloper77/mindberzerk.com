import 'package:flutter/material.dart';

import '../engine/theme_spec.dart';
import '../engine/wallpaper_framing.dart';
import 'device_metrics.dart';

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

  /// The fit the framing actually names, before any guard.
  BoxFit get _authoredFit => switch (framing.resolvedFit) {
        'fill' => BoxFit.fill,
        'contain' => BoxFit.contain,
        // Actual size. Nothing scales it but the zoom below, which is the whole
        // meaning of the fit.
        'center' => BoxFit.none,
        _ => BoxFit.cover,
      };

  /// ─── THE GUARD: `fill` ONLY MEANS ANYTHING IN A BOX SHAPED LIKE THE PHONE ─
  ///
  /// `fill` is the default fit and its docblock is precise about what it buys:
  /// the image maps onto exactly this screen, nothing is cropped, nothing is
  /// guessed. It also names the cost, that aspect is not preserved. Both halves
  /// are true of a box that IS the screen, and neither is true of one that is
  /// not.
  ///
  /// The storefront proved it. A card's picture band was 328 x 152, an aspect
  /// of 2.16 against a device's 0.462, and it painted the user's own wallpaper
  /// with their own resolved framing. `fill` did exactly what it promises and
  /// stretched a portrait photograph across a landscape box by a factor of 4.7.
  /// Nothing was misconfigured anywhere in that chain. The framing was correct
  /// for the phone and was handed to something that was not the phone.
  ///
  /// So a box that is materially the wrong shape gets `cover` instead. Cropping
  /// is a smaller lie than distortion: a crop shows less of a true picture, a
  /// stretch shows all of a false one, and only one of those is a thing anybody
  /// notices on their own wallpaper.
  ///
  /// ─── HERE RATHER THAN IN DevicePreview, ON PURPOSE ──────────────────────
  ///
  /// The docblock above is the argument. Framing became one widget rather than
  /// a `DecorationImage` per caller because four call sites is four chances to
  /// drop part of the setting. A guard living one level up in `DevicePreview`
  /// would protect that widget's callers and nobody else, and the next thing
  /// to paint a wallpaper outside it would reintroduce this with nothing left
  /// to catch it.
  ///
  /// ─── IT IS INERT WHERE IT MATTERS MOST ─────────────────────────────────
  ///
  /// The framing screen draws this at `StackFit.expand` inside a
  /// `ThemedScaffold` with no app bar, so its canvas is the window and its
  /// aspect is the device's by construction. The one screen whose whole job is
  /// showing the exact truth never degrades, and that is the property that
  /// makes this safe to apply everywhere else.
  BoxFit _guardedFit(BuildContext context, BoxConstraints c) {
    // An unbounded height is the absence of an answer rather than evidence of a
    // wrong shape, and `boxMatchesDevice` reads it as a match, so the authored
    // fit survives a constraint this cannot interrogate.
    final boxAspect = c.maxWidth / c.maxHeight;
    return boxMatchesDevice(context, boxAspect) ? BoxFit.fill : BoxFit.cover;
  }

  @override
  Widget build(BuildContext context) {
    // ── THE LayoutBuilder IS ONLY ON THE ARM THAT NEEDS IT ────────────────
    //
    // `fill` is the default, so this is the common path. The three other fits
    // cannot be degraded by anything and get exactly the widget tree they had
    // before this guard existed: a `contain` in a settings row does not gain a
    // relayout boundary to answer a question about a fit it is not using.
    if (framing.resolvedFit != 'fill') return _paint(_authoredFit);

    return LayoutBuilder(
      builder: (context, c) => _paint(_guardedFit(context, c)),
    );
  }

  Widget _paint(BoxFit fit) {
    final align = Alignment(
      framing.focalX * 2 - 1,
      framing.focalY * 2 - 1,
    );

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
