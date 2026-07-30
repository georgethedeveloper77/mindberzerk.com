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
    this.borderRadius = BorderRadius.zero,
    this.border,
    this.blurSigma = 18,
  });

  final Widget child;
  final BorderRadius borderRadius;

  /// Defaults to a hairline on every side. A sheet passes a top-only edge,
  /// because its other three run off the screen.
  final BoxBorder? border;

  final double blurSigma;

  /// How much of the distro's own colour comes through.
  static const _tintAlpha = 0.72;

  /// How much neutral chrome sits on top of it.
  static const _surfaceAlpha = 0.62;

  @override
  Widget build(BuildContext context) {
    final c = ChromeScope.of(context).colors;

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: c.tint.withValues(alpha: _tintAlpha),
            borderRadius: borderRadius,
            // The edge is not decoration. A translucent panel over a busy
            // wallpaper has no boundary at all without one.
            border: border ?? Border.all(color: c.lineStrong),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: c.surface.withValues(alpha: _surfaceAlpha),
              borderRadius: borderRadius,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
