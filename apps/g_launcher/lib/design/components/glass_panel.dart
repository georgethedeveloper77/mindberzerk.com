import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';

import 'chrome_theme.dart';

/// A translucent, distro-tinted, blurred panel. Sheets, dialogs and anchored
/// menus all sit on one.
///
/// ─── WHY A FLOATING PANEL IS NOT A SETTINGS PAGE ────────────────────────────
///
/// [ChromeColors] drains the hue out of every surface deliberately, because
/// real Adwaita and Breeze carry structure in greys and reserve colour for
/// state. That reasoning is about PAGES. Both desktops draw floating panels
/// the other way: GNOME's popovers and KDE's panels are translucent with the
/// wallpaper showing through, and what shows through is the desktop's own
/// colour. So this is the one surface that reaches for [ChromeColors.tint],
/// and a page reaching for it would undo the whole point of `_neutral`.
///
/// ─── THE LAYER ORDER IS THE WHOLE LOOK ──────────────────────────────────────
///
/// Back to front: blur, then the distro's base colour at most of full opacity,
/// then the neutral chrome surface at a fraction on top. The grey does the
/// work and the hue only warms it, which is what makes this read as a tinted
/// grey panel rather than as a purple one. Swapping the two produces something
/// that looks like a themed app, which is the trap `_neutral` exists to avoid.
///
/// ─── THE BLUR IS THE EXPENSIVE PART AND IT IS BOUNDED ───────────────────────
///
/// [BackdropFilter] rasterises what is behind it, and this app targets budget
/// Infinix and Tecno hardware. Three things keep it affordable: it is clipped
/// to the panel rather than the screen, it exists only while the panel is open,
/// and [blurSigma] is modest. A bigger radius looks better on a flagship and
/// drops frames on the devices most of these users actually have. If it ever
/// needs to go, setting the sigma to zero leaves a tinted opaque panel that
/// still looks deliberate.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.borderRadius,
    this.border,
    this.blurSigma,
  });

  final Widget child;

  /// Null takes the chrome's shared panel radius, which is what every caller
  /// should do now that the radius is a setting. Pass one only for a shape the
  /// setting cannot express: a sheet's top-only rounding builds its own from
  /// [ChromeData.panelRadius] rather than overriding the number.
  final BorderRadius? borderRadius;

  /// Defaults to a hairline on every side. A sheet passes a top-only edge,
  /// because its other three run off the screen.
  final BoxBorder? border;

  /// Null takes the chrome's blur. See [ChromeData.panelBlur].
  final double? blurSigma;

  /// How much neutral chrome sits on top of the tint.
  ///
  /// Still a constant, and deliberately the one of the pair that did NOT
  /// become a setting. The grey is what makes this read as a tinted grey panel
  /// rather than a coloured one, which is the whole argument in the note
  /// above; exposing both would let someone dissolve the panel into a wash of
  /// distro colour with no structure in it. The tint rides over this.
  static const _surfaceAlpha = 0.62;

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    final c = d.colors;

    // The user's surface setting, applied to this panel's own two layers.
    //
    // `c.tint` and `c.surface` are palette colours composed here rather than
    // taken ready-made, so the fills that ChromeData already made translucent
    // do not reach this widget. Scaling both by the same amount keeps a sheet
    // in step with the page behind it; a panel that stayed solid while every
    // page went see-through would read as a bug rather than a setting.
    final o = d.opacity;

    final radius = borderRadius ?? BorderRadius.circular(d.panelRadius);
    final sigma = blurSigma ?? d.panelBlur;

    // ─── ZERO SIGMA SKIPS THE FILTER, IT DOES NOT PASS ZERO TO IT ─────────
    //
    // A BackdropFilter with a zero-sigma blur still rasterises the layer
    // behind it, so it costs the whole expense of the effect and produces none
    // of it. Since zero is now a real user setting, and specifically the one a
    // person reaches for when the launcher stutters, honouring it has to mean
    // not building the filter at all.
    Widget fill = DecoratedBox(
      decoration: BoxDecoration(
        color: c.tint.withValues(alpha: d.panelTint * o),
        borderRadius: radius,
        // The edge is not decoration. A translucent panel over a busy
        // wallpaper has no boundary at all without one, and it matters more
        // now: a panel with the blur turned off and the tint low has the
        // hairline as its only boundary.
        border: border ?? Border.all(color: c.lineStrong),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.surface.withValues(alpha: _surfaceAlpha * o),
          borderRadius: radius,
        ),
        child: child,
      ),
    );

    if (sigma > 0) {
      fill = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: fill,
      );
    }

    return ClipRRect(borderRadius: radius, child: fill);
  }
}
