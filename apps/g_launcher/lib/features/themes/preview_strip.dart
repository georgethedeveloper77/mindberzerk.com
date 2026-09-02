/// PHASE B: the storefront's picture band, as phones rather than as a mural.
///
/// ─── WHAT THIS FIXES, AND IT WAS NOT ONLY THE STRETCH ───────────────────────
///
/// The card's picture was one landscape box, 328 x 152, holding a
/// [DevicePreview] with `framed: false`. Two things followed from that shape
/// and only one of them was visible.
///
/// The visible one: the box painted the user's wallpaper with their real
/// framing, whose default fit is `fill`, so a portrait photograph was stretched
/// across a 2.16 box by a factor of 4.7. `WallpaperPaint`'s guard now degrades
/// that to `cover` on its own, so this file is not what stops the distortion.
///
/// The other one is why this file exists anyway. The CHROME was laid out
/// against that box too. A GNOME dock that runs nearly the full height of a
/// phone became a stubby strip covering two fifths of a landscape band, and
/// every distro's proportions were wrong in the same direction. A preview of a
/// phone has to be phone-shaped or it is a preview of something else.
///
/// ─── WHY THREE, AND WHY THESE THREE ─────────────────────────────────────────
///
/// One phone-shaped pane in a 176dp band is about 81dp wide, which leaves two
/// thirds of the card empty. Three fill it, and the alternative use of that
/// width was the mural that caused the problem.
///
/// Desktop, drawer, folder. Those are the [DevicePreviewMode]s that differ per
/// distro: the desktop carries the panel and the dock, the drawer carries the
/// grid, and the folder is the only one that draws `tileRadiusFraction` at a
/// size where a circle and a square are told apart. `lock` is deliberately
/// absent — its own docblock says it carries no launcher chrome by design, so
/// it would be the same picture on all fifteen cards.
///
/// The detail page passes ONE mode and gets one large pane through the same
/// widget, which is what keeps the card and the page it opens from drawing
/// subtly different pictures of the same distro.
///
/// ─── THE BACKDROP IS THE DISTRO'S PALETTE, NOT A BLURRED WALLPAPER ──────────
///
/// A blurred copy of the wallpaper behind the panes was the obvious filler and
/// it is the wrong one twice. It costs a real blur per card, and about five
/// cards are alive in the sliver at any moment on a phone this launcher is
/// built for. And it would put the SAME backdrop behind every card, because the
/// wallpaper is the user's and does not change between distros.
///
/// The peeked distro's own gradient costs nothing and is per distro, so the
/// space between the panes is carrying information instead of decoration.
///
/// ─── THE ANIMATION IS A TweenAnimationBuilder, AND THAT IS LOAD BEARING ─────
///
/// These cards live in a `SliverList.builder`, which exists precisely so that
/// thirty of them are not built at once. An `AnimationController` needs a
/// `State` with a `dispose`, in a list that creates and destroys elements as
/// you scroll. A `TweenAnimationBuilder` has neither and cannot leak one.
///
/// The stagger is not three animations. One value runs 0 to 1 over the whole
/// sequence and each pane reads its own slice of it, so there is one ticker per
/// band rather than one per pane.
library;

import 'package:flutter/widgets.dart';

import '../../design/device_metrics.dart';
import '../../engine/theme_spec.dart';

/// A row of device-shaped panes over the distro's own gradient.
class PreviewStrip extends StatelessWidget {
  const PreviewStrip({
    super.key,
    required this.palette,
    required this.panes,
    this.gap = 10,
    this.stagger = const Duration(milliseconds: 160),
    this.fade = const Duration(milliseconds: 280),
    this.rise = 8,
  });

  /// Drawn behind the panes. The PEEKED distro's palette, not the active
  /// theme's: the panes are a picture of that distro and the space around them
  /// should not be a picture of a different one.
  final ThemePalette palette;

  /// Already built, not yet sized. This widget owns the size because it is the
  /// only thing that knows both the band it was given and this device's shape,
  /// and a caller passing a pre-sized pane would be guessing at one of them.
  final List<Widget> panes;

  final double gap;

  /// Between one pane starting and the next.
  ///
  /// Past about 250ms this stops reading as one card arriving and starts
  /// reading as three separate events.
  final Duration stagger;

  /// How long one pane takes.
  final Duration fade;

  /// How far a pane travels upward on its way in, in logical pixels.
  ///
  /// Eight rather than the more obvious sixteen. These panes are about 81dp
  /// wide and sit close together, so a long travel reads as the middle one
  /// shoving its neighbours rather than as the card settling.
  final double rise;

  @override
  Widget build(BuildContext context) {
    final n = panes.length;
    if (n == 0) return const SizedBox.expand();

    final aspect = previewAspectOf(context);

    // ── ONE PANE GETS MORE OF THE BAND THAN THREE DO ────────────────────────
    //
    // Three panes need the breathing room or they read as one wide object with
    // seams in it. A single pane on the detail page is the subject of the page
    // and gains nothing from a margin the surrounding gradient already
    // provides.
    final factor = n > 1 ? 0.86 : 0.96;

    final decoration = BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [palette.bgTop, palette.bgBottom],
      ),
    );

    return DecoratedBox(
      decoration: decoration,
      child: LayoutBuilder(
        builder: (context, c) {
          // ── FIT ON BOTH AXES, NOT JUST HEIGHT ─────────────────────────────
          //
          // Height alone is right on a phone and wrong on the two shapes that
          // actually break it: a foldable, where `previewAspectOf` clamps to
          // 0.80 and three panes at the band's height are wider than the card,
          // and a short band on a small screen. Whichever axis is tighter wins,
          // which is the same rule `DevicePreview._folder` already applies to
          // its tiles.
          final maxH = c.maxHeight.isFinite ? c.maxHeight : 176.0;
          final maxW = c.maxWidth.isFinite ? c.maxWidth : 328.0;

          final byHeight = maxH * factor;
          final byWidth = ((maxW - gap * (n - 1)) / n) / aspect;
          final h = byHeight < byWidth ? byHeight : byWidth;
          final w = h * aspect;

          // Below this there is nothing honest left to draw, and the
          // alternative is handing a SizedBox a negative dimension. Same floor
          // and same reasoning as `_folder`.
          if (!h.isFinite || h < 8 || !w.isFinite) return const SizedBox.expand();

          final totalMs = stagger.inMilliseconds * (n - 1) + fade.inMilliseconds;

          return TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            // Zero collapses the whole thing to its end state on the first
            // frame, which is the correct reading of "remove animations" and
            // is one line rather than a branch through everything below.
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : Duration(milliseconds: totalMs),
            // LINEAR here on purpose. The easing is per pane below, and a curve
            // applied to the shared driver would bend the stagger itself, so
            // the gap between panes would vary through the sequence.
            curve: Curves.linear,
            builder: (context, t, _) => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < n; i++) ...[
                  if (i > 0) SizedBox(width: gap),
                  _staged(i, t, totalMs, w, h),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  /// One pane, at its own point in the shared sequence.
  Widget _staged(int i, double t, int totalMs, double w, double h) {
    final sized = SizedBox(width: w, height: h, child: panes[i]);

    final startMs = stagger.inMilliseconds * i;
    final start = startMs / totalMs;
    final end = (startMs + fade.inMilliseconds) / totalMs;
    // `.toDouble()` after the clamp, for the reason `previewAspectOf` and
    // `WallpaperFraming.fromJson` both spell out: `num.clamp` returns `num`,
    // and `Curve.transform` takes a `double`.
    final p = ((t - start) / (end - start)).clamp(0.0, 1.0).toDouble();
    final e = Curves.easeOutCubic.transform(p);

    // ── THE SETTLED PANE CARRIES NEITHER WRAPPER ────────────────────────────
    //
    // `Opacity` at 1.0 already skips its layer and `Transform` at zero is
    // nearly free, so this is not the saving it looks like. It is a guarantee:
    // once the sequence is over, a card that scrolls past is exactly the widget
    // tree it would have been if this file had no animation in it at all.
    if (e >= 1.0) return sized;

    return Opacity(
      opacity: e,
      child: Transform.translate(
        offset: Offset(0, (1 - e) * rise),
        child: sized,
      ),
    );
  }
}
