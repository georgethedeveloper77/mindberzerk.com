import 'package:flutter/material.dart';

import '../../../design/ubuntu_tokens.dart';
import '../../../engine/theme_spec.dart' show ThemePalette;

/// The GNOME top bar, phone-adapted.
///
/// On a real GNOME desktop this strip carries Activities (left), the clock
/// (centre) and the tray — wifi, volume, battery — (right). On a phone, the
/// clock and every one of those indicators are ALREADY on screen: they live in
/// Android's own status bar, a few pixels above this. Duplicating them here
/// would put two clocks and two battery readouts on the same screen, which is
/// the opposite of authentic.
///
/// So this bar keeps only the one thing Android does NOT provide: the
/// Activities button, the shell's way into the app drawer. Everything else is
/// deliberately gone, and the strip is transparent — the wallpaper runs edge to
/// edge and Android's status bar does the indicator job it already does well.
///
/// The "Activities" label is doing the heavy lifting: it is the GNOME tell, the
/// single most recognisable thing about the shell, so keeping it (icon + word,
/// top-left) is what makes this still read as GNOME rather than as a launcher
/// with a floating word. Losing the solid fill does not lose the identity.
///
/// Consequence worth knowing: because it no longer watches the clock or the
/// system stats, this widget effectively never rebuilds. The old version
/// repainted on every clock tick and every battery / wifi change; now it is
/// static after first layout — a small, free perf win on the budget phones this
/// app targets.
///
/// Colour is still per-theme: the Activities label takes [ThemePalette.onDark]
/// so it reads on each distro's wallpaper. The typeface and the bar height stay
/// constant — those are GNOME's shell geometry, shared across the family.
class GnomeTopBar extends StatelessWidget {
  const GnomeTopBar({
    super.key,
    required this.palette,
    required this.onActivities,
    this.displayFontFamily,
  });

  /// The active theme's palette. Supplies the on-dark label colour
  /// ([ThemePalette.onDark]). There is no bar fill any more — it is transparent.
  final ThemePalette palette;
  final VoidCallback onActivities;

  /// The theme's display family. Was `Ubuntu.display`, which meant Fedora's
  /// Activities label rendered in Ubuntu's typeface — invisible in a screenshot
  /// and wrong in exactly the way this whole layer exists to prevent.
  final String? displayFontFamily;

  @override
  Widget build(BuildContext context) {
    // The bar sits BELOW Android's status bar, not under it: Activities is a
    // real tap target and must clear the notch / status-bar row above it. The
    // height is unchanged from the old opaque bar, so the desktop layout below
    // does not shift — only the fill and the clock/tray are gone.
    final topInset = MediaQuery.viewPaddingOf(context).top;

    return SizedBox(
      height: Ubuntu.topBarHeight + topInset, // theme-exempt: GNOME shell geometry, shared across the family, not a palette value
      child: Padding(
        padding: EdgeInsets.only(top: topInset, left: 15, right: 15),
        child: Align(
          alignment: Alignment.centerLeft,
          child: _Activities(
            onTap: onActivities,
            color: palette.onDark,
            fontFamily: displayFontFamily,
          ),
        ),
      ),
    );
  }
}

class _Activities extends StatelessWidget {
  const _Activities({
    required this.onTap,
    required this.color,
    this.fontFamily,
  });

  final VoidCallback onTap;
  final String? fontFamily;

  /// On-dark foreground colour, from the theme palette.
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Activities',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.grid_view_rounded, size: 13, color: color),
            const SizedBox(width: 6),
            Text(
              'Activities',
              style: TextStyle(
                fontFamily: fontFamily,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
