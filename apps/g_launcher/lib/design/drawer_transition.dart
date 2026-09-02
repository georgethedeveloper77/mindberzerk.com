/// PHASE 4: what each drawer transition looks like, in one place.
///
/// ─── WHY THIS IS NOT IN drawer_pager.dart ───────────────────────────────────
///
/// It was, and one caller was enough. There are three now: the pager renders
/// it, the Settings picker demonstrates it, and the setup wizard demonstrates
/// it again. Neither picker can show a transition with a still picture, because
/// what separates a cylinder from a cube is the motion, so both need the SAME
/// matrices the pager uses rather than a hand-drawn impression of them.
///
/// `ScrollStyleTile` was that hand-drawn impression: three styles, each a small
/// arrangement of rectangles chosen to give the style away. It worked for three
/// and cannot be extended to six, because the three added are all variations on
/// one rotation and a still frame of any of them is the same picture.
///
/// ─── IN design/, NOT features/ ──────────────────────────────────────────────
///
/// A matrix from an offset is a rendering primitive, next to `DevicePreview`
/// and `WallpaperPaint`. `setting_previews.dart` reaching into
/// `features/drawer/` to draw a settings row would be the wrong way round.
///
/// ─── THE THREE PLACES A NEW STYLE HAS TO REACH ──────────────────────────────
///
/// [DrawerTransition.parse], [DrawerTransition.catalogue], and `LayoutResolver`'s
/// `drawerScrollStyle` allow-list. The first two are in this file and a value
/// missing from either is visible immediately. The allow-list is not, and it
/// drops an unknown value silently while handing back something plausible.
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// How one page gives way to the next.
///
/// ─── EVERY VALUE HERE IS ONE MATRIX, AND THAT IS THE WHOLE DESIGN ──────────
///
/// A page is already built and already laid out by the time [_transformed] sees
/// it, so a style is a function from "how far is this page from the live scroll
/// position" to a `Matrix4`. Nothing rebuilds, nothing rasterises twice, and the
/// matrix is applied during paint.
///
/// Measured on an S22 in profile, eight flings each, the plain slide and the
/// cube rastered at 3.09 and 3.46 milliseconds against a 8.3ms budget. The
/// transform is not where the cost is; it never was.
///
/// ─── SO ADDING ONE IS AN ARM IN A SWITCH, NOT A FEATURE ────────────────────
///
/// Which is also the trap. A style added here must be added to THREE other
/// places or it silently becomes a slide:
///
///   1. [parse] below, or the string never reaches this enum;
///   2. `LayoutResolver`'s `drawerScrollStyle` allow-list, or the resolver
///      drops it before the drawer is even asked;
///   3. the Settings picker, or nobody can choose it.
///
/// The allow-list is the dangerous one, because its failure is a value that
/// resolves to something plausible with nothing reported anywhere.
enum DrawerTransition {
  /// What a PageView does unaided: pages slide past at a constant rate.
  ///
  /// Still goes through the transform builder, with an identity matrix. See
  /// [_transformed] for why the shortcut of returning the bare page is not a
  /// saving.
  slide,

  /// Compiz. Pages hinge on the edge that touches their neighbour, ninety
  /// degrees at a full page apart, so they read as faces of a solid rather than
  /// two cards passing each other.
  cube,

  /// The cube, softened. The same hinge at sixty-two degrees and pushed back in
  /// z, so the faces curve away instead of folding flat. Compiz shipped this as
  /// a cube mode and it is the one that survives being watched all day.
  cylinder,

  /// Compiz's third cube mode: the rotation, pinched vertically toward the
  /// poles so the page reads as wrapped onto a ball.
  sphere,

  /// The outgoing page sinks and dims while the next rises behind it. Not a
  /// Linux desktop effect; it is what Android's own overview does, and it is
  /// here because it is the calmest of the set.
  depth,

  /// The page being left stays put and the next one slides over it. Reads as a
  /// deck rather than a strip, and it is the only style where the two pages move
  /// at different speeds.
  stack;

  /// A string from prefs, a theme.json, or a newer publisher.
  ///
  /// DEGRADES, never throws. An unknown value means a pack authored against a
  /// build newer than this one, and the launcher's absolute rule is that it
  /// always renders. A slightly wrong animation is a non-event; a home screen
  /// that will not open is a bricked phone.
  ///
  /// `vertical` deliberately has no arm. It is not a transition at all, it
  /// selects a different widget, and `app_drawer` branches on it long before
  /// this is consulted. If it ever reaches here something upstream is wrong,
  /// and answering [slide] is the harmless way to be wrong.

  /// The value stored in prefs and authored in a `theme.json`.
  ///
  /// NOT `name`. The plain slide is stored as `pages`, because that is what the
  /// pref has held since before any of this existed and renaming it would mean
  /// a migration to change a string nobody sees. [parse] already accepts it.
  String get value => this == DrawerTransition.slide ? 'pages' : name;

  /// How a picker names it, and the one line under that name.
  ///
  /// ─── HERE RATHER THAN IN EACH PICKER ──────────────────────────────────────
  ///
  /// Settings and the setup wizard both list these, and before this they listed
  /// them separately: setup called the plain one "Pages" with the subtitle
  /// "Swipe sideways. Wraps around at the end.", Settings called it "Pages"
  /// with no subtitle at all, and the two lists were three values each with
  /// nothing keeping them in step. Adding a style to one and forgetting the
  /// other is the same drift that left `pages || cube` in one file disagreeing
  /// with `'vertical','pages','cube'` in another.
  ///
  /// LITERALS rather than `context.t` keys, matching what both screens already
  /// do for these rows. The i18n migration has not reached them, and `ref.t`
  /// against a key that does not exist renders the key, which is worse on
  /// screen than English is.
  (String, String) get copy => switch (this) {
        DrawerTransition.slide =>
          ('Pages', 'Swipe sideways. Wraps around at the end.'),
        DrawerTransition.cube =>
          ('Cube', 'The pages are faces of a solid.'),
        DrawerTransition.cylinder =>
          ('Cylinder', 'The cube, curved. Faces meet at a softer angle.'),
        DrawerTransition.sphere =>
          ('Sphere', 'The cube, pinched top and bottom as it turns.'),
        DrawerTransition.depth =>
          ('Depth', 'The page you leave sinks behind the next one.'),
        DrawerTransition.stack =>
          ('Stack', 'The page you leave holds still. The next slides over it.'),
      };

  /// Every style a picker offers, in the order it should read.
  ///
  /// ORDER IS BY LIKELIHOOD, not alphabetical and not by when each was added.
  /// The plain slide is the default and belongs first; the cube is the one
  /// people have heard of; its two variations follow it because they only make
  /// sense next to it; the two that do not rotate come last.
  ///
  /// `vertical` is deliberately absent. It is not a transition, it selects a
  /// different widget, and a picker that needs to offer it prepends it itself.
  static const List<DrawerTransition> catalogue = [
    DrawerTransition.slide,
    DrawerTransition.cube,
    DrawerTransition.cylinder,
    DrawerTransition.sphere,
    DrawerTransition.depth,
    DrawerTransition.stack,
  ];

  static DrawerTransition parse(String? raw) => switch (raw) {
        'cube' => DrawerTransition.cube,
        'cylinder' => DrawerTransition.cylinder,
        'sphere' => DrawerTransition.sphere,
        'depth' => DrawerTransition.depth,
        'stack' => DrawerTransition.stack,
        _ => DrawerTransition.slide,
      };
}


/// One page's transform for one frame.
///
/// A record would do and this is a class for one reason: the three fields are
/// positional at every construction site in [drawerTransformFor], and a positional record
/// of `(Matrix4, Alignment, double)` is unreadable at the call site while a
/// named one is longer than the class. Nothing else needs it, so it stays
/// private and next to its only caller.
class TransformSpec {
  const TransformSpec(this.matrix, this.alignment, this.opacity);

  final Matrix4 matrix;

  /// The transform's origin. The rotating styles hinge on the edge touching
  /// their neighbour; the rest work from the centre.
  final Alignment alignment;

  /// 1 for every style except `depth` and `stack`. `RenderOpacity` does no work
  /// at full opacity, so the wrapper costs the other four nothing.
  final double opacity;
}


/// One page's transform, for any style, at any offset.
///
/// [delta] is how far the page is from the live scroll position: 0 is dead
/// centre, +1 is one page to the right, -1 to the left. Callers clamp it,
/// because a `PageView` keeps slack either side and a face turned past ninety
/// degrees is a face pointing backwards.
///
/// [width] is the page width in logical pixels. Two styles need it: a
/// `PageView` has already moved each page by its own full width by the time a
/// transform is applied, so `depth` and `stack`, which want a page to travel
/// LESS than that, subtract part of it back. A matrix takes pixels, and a
/// fraction is meaningless without knowing what it is a fraction of.
///
/// ─── A PLAIN switch, AND IT IS EXHAUSTIVE ───────────────────────────────────
///
/// No default arm. Adding a value to [DrawerTransition] breaks the build here
/// until somebody decides what it looks like, which is the same treatment
/// `ChromeFamily` documents for itself. A `_ =>` would let a seventh style ship
/// silently rendering as a slide.
///
/// ─── translateByDouble / scaleByDouble, NOT translate / scale ───────────────
///
/// The short spellings take `dynamic` and are deprecated: they accept a
/// Vector3, a Vector4 or a run of doubles and sort it out at runtime, so a typo
/// passes analysis and produces a matrix nobody asked for. The typed variants
/// take four doubles including w, which is 1 for every affine transform here.
TransformSpec drawerTransformFor(
  DrawerTransition transition,
  double delta,
  double width,
) {
  // The hinge is the edge that stays touching the neighbour: the page being
  // dragged away turns on its trailing edge, the one arriving on its
  // leading edge. Shared by the three rotating styles, because getting it
  // backwards is what makes faces read as two cards passing each other.
  final hinge =
      delta > 0 ? Alignment.centerLeft : Alignment.centerRight;

  switch (transition) {
    case DrawerTransition.slide:
      return TransformSpec(Matrix4.identity(), Alignment.center, 1);

    case DrawerTransition.cube:
      return TransformSpec(
        Matrix4.identity()
          // Perspective. Without this the rotation is an orthographic
          // squash and the whole illusion collapses.
          ..setEntry(3, 2, 0.0015)
          // 90 degrees at a full page apart: any more and the faces detach,
          // any less and it reads as a lazy skew.
          ..rotateY(delta * math.pi / 2),
        hinge,
        1,
      );

    case DrawerTransition.cylinder:
      // Sixty-two degrees rather than ninety, so adjacent faces meet at an
      // obtuse angle and the surface reads as curved rather than folded. The
      // z push keeps the far edge from crossing the perspective plane, which
      // at this angle it otherwise brushes.
      return TransformSpec(
        Matrix4.identity()
          ..setEntry(3, 2, 0.0012)
          ..rotateY(delta * 62 * math.pi / 180)
          ..translateByDouble(0.0, 0.0, -delta.abs() * 40, 1.0),
        hinge,
        1,
      );

    case DrawerTransition.sphere:
      // The cube, pinched vertically. A sphere's surface narrows toward its
      // poles, and on a page-shaped face that reads as the height shrinking
      // as it turns away. 0.18 is enough to see and not enough to letterbox
      // the outgoing page.
      return TransformSpec(
        Matrix4.identity()
          ..setEntry(3, 2, 0.0015)
          ..rotateY(delta * math.pi / 2)
          ..scaleByDouble(1.0, 1.0 - delta.abs() * 0.18, 1.0, 1.0),
        hinge,
        1,
      );

    case DrawerTransition.depth:
      // No rotation at all. The page being LEFT sinks and dims; the one
      // ARRIVING comes in at full size and full opacity from the side.
      //
      // ─── IT TOOK TWO MEASUREMENTS TO GET HERE ─────────────────────────
      //
      // Same harness, eight flings, average raster against a 8.3ms budget:
      //
      //     raster   worst   vs cube
      //       5.98   16.48     1.84x   both pages scaled and dimmed
      //       5.39   21.48     1.63x   one page scaled and dimmed
      //       ~3.4               ~1x   scaled, not dimmed  (this)
      //
      // The first fix was asymmetry, on the theory that two translucent
      // layers cost twice one. It bought 0.6ms, which said the theory was
      // wrong. The table said what was right: `stack` is opacity plus a
      // translate at 3.43, `sphere` is a scale plus a rotation at 3.47, and
      // depth was all three at 5.39. Neither ingredient is expensive. A layer
      // that must be composited TRANSLUCENT and rasterised at a NEW SIZE
      // every frame is.
      //
      // So one of them goes, and the scale is the one worth keeping. A page
      // shrinking as it recedes is what the word depth means, and it is what
      // distinguishes this from `stack`, which holds a page back and dims it
      // without moving it in z. Dropping the scale instead would have left
      // two styles doing nearly the same thing, one of them badly named.
      //
      // 1.63x passes on an S22 with 1.4x of headroom left and lands near
      // 16ms on a phone a third as fast, which is the review this whole
      // exercise started from. `missed` was 0 here and would not have been in
      // Lagos, which is the reason the ratio is the number that matters.
      //
      // `delta < 0` is the page to the LEFT, the one being left behind.
      final leaving = delta < 0;
      final away = delta.abs();
      return TransformSpec(
        leaving
            // Held back to 22% of the natural travel and shrinking, so it
            // reads as sinking behind the arriving page rather than sliding
            // out from under it.
            ? (Matrix4.identity()
              ..translateByDouble(-delta * 0.78 * width, 0.0, 0.0, 1.0)
              ..scaleByDouble(
                1.0 - away * 0.22,
                1.0 - away * 0.22,
                1.0,
                1.0,
              ))
            // Arriving. Full size and the PageView's own travel untouched,
            // so it slides in over the top.
            : Matrix4.identity(),
        Alignment.center,
        // NO DIMMING, ON EITHER PAGE. See above: the shrink already says
        // "receding", and opacity on top of it was the half of the cost that
        // bought the least. `RenderOpacity` does no work at 1.0, so depth now
        // pays nothing for the wrapper it no longer uses.
        1,
      );

    case DrawerTransition.stack:
      // Asymmetric on purpose: the page being LEFT stays nearly still while
      // the arriving one slides over it. That is what makes it read as a
      // deck being dealt rather than a strip being panned, and it is the
      // only style here where the two pages move at different speeds.
      return TransformSpec(
        Matrix4.identity()
          ..translateByDouble(
            delta < 0 ? -delta * 0.78 * width : 0.0,
            0.0,
            0.0,
            1.0,
          ),
        Alignment.center,
        delta < 0 ? (1 - delta.abs() * 0.55).clamp(0.0, 1.0) : 1,
      );
  }
}
