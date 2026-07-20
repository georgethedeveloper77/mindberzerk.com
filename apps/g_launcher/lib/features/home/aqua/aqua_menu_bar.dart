import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../engine/theme_spec.dart' show ThemePalette, ThemeLogo;

/// The macOS menu bar, phone-adapted.
///
/// Same reasoning as [GnomeTopBar], different conclusion. On a real Mac this
/// strip carries the Apple mark, the active app's name in bold, that app's
/// menus, then Control Center, Spotlight and the clock on the right. On a phone,
/// the clock and every status indicator ALREADY live in Android's status bar a
/// few pixels above, so duplicating them would put two clocks on one screen.
///
/// But unlike GNOME's bar, this one is NOT transparent. The frosted strip IS the
/// macOS tell — the thing that makes a screenshot read as a Mac before you have
/// looked at anything else — so it keeps a translucent fill with a real blur
/// behind it. Losing the fill here would lose the identity, which is exactly the
/// opposite of the GNOME case, where the "Activities" word carries it alone.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// NO APPLE LOGO, EVER, AND THAT IS NOT AN OVERSIGHT.
///
/// The Apple mark is a trademark and shipping it in a paid or free theme is a
/// fight nobody needs. So the left glyph is the THEME'S own logo via
/// [ThemeSpec.logo] — the same light/dark pair every other distro uses — and the
/// bundled Aqua theme deliberately ships none, which falls back to a neutral
/// glyph. If a user side-loads a CDN theme that supplies its own mark, that is
/// their asset and their call, and the mechanism costs us nothing.
/// ─────────────────────────────────────────────────────────────────────────────
///
/// Fake menus are worse than no menus. There is no "File Edit View" here,
/// because a menu that does not open is a screenshot of a desktop rather than a
/// desktop. What is left is the two things that genuinely do something: the
/// name, and Spotlight.
class AquaMenuBar extends StatelessWidget {
  const AquaMenuBar({
    super.key,
    required this.palette,
    required this.title,
    required this.onLaunchpad,
    required this.onSpotlight,
    this.logo,
    this.displayFontFamily,
  });

  final ThemePalette palette;

  /// The theme's name, set semibold where a Mac shows the frontmost app. Read
  /// from the spec rather than hardcoded to "Finder" so a second Aqua-family
  /// theme is still a data change.
  final String title;

  final VoidCallback onLaunchpad;
  final VoidCallback onSpotlight;

  /// The theme's own mark, or null for the neutral glyph. See the class note.
  final ThemeLogo? logo;

  final String? displayFontFamily;

  /// The menu bar's own height, excluding the status-bar inset. A Mac's is
  /// 24pt; 26 leaves the glyph and the label room without reading as a toolbar.
  static const height = 26.0;

  @override
  Widget build(BuildContext context) {
    // The bar sits BELOW Android's status bar, not under it. Both the mark and
    // Spotlight are real tap targets and must clear the notch.
    final topInset = MediaQuery.viewPaddingOf(context).top;
    final onDark = palette.onDark;

    return ClipRect(
      child: BackdropFilter(
        // Cheaper than the dock's blur because this strip is short, but it is
        // still a blur over an arbitrary photograph. If the launcher ever janks
        // on a Tecno, this and the dock are the two places to look.
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          height: height + topInset,
          padding: EdgeInsets.only(top: topInset, left: 12, right: 12),
          decoration: BoxDecoration(
            // Translucent, not opaque: the wallpaper reads through it the way a
            // real menu bar's does.
            color: palette.bar.withValues(alpha: 0.55),
            border: Border(
              bottom: BorderSide(color: onDark.withValues(alpha: 0.08)),
            ),
          ),
          child: Row(
            children: [
              _MarkAndTitle(
                logo: logo,
                title: title,
                onDark: onDark,
                displayFontFamily: displayFontFamily,
                onTap: onLaunchpad,
              ),
              const Spacer(),
              Semantics(
                button: true,
                label: 'Spotlight',
                child: GestureDetector(
                  onTap: onSpotlight,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      Icons.search,
                      size: 15,
                      color: onDark.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MarkAndTitle extends StatelessWidget {
  const _MarkAndTitle({
    required this.logo,
    required this.title,
    required this.onDark,
    required this.onTap,
    this.displayFontFamily,
  });

  final ThemeLogo? logo;
  final String title;
  final Color onDark;
  final VoidCallback onTap;
  final String? displayFontFamily;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Mark(logo: logo, onDark: onDark),
            const SizedBox(width: 9),
            Text(
              title,
              style: TextStyle(
                fontFamily: displayFontFamily,
                fontSize: 12.5,
                // Semibold is the tell: a Mac sets the frontmost app's name in
                // bold and everything after it regular.
                fontWeight: FontWeight.w600,
                color: onDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The left mark. The theme's logo when it ships one, tinted to read on the
/// bar; otherwise a neutral glyph. Never an Apple logo — see [AquaMenuBar].
class _Mark extends StatelessWidget {
  const _Mark({required this.logo, required this.onDark});

  final ThemeLogo? logo;
  final Color onDark;

  static const _size = 14.0;

  @override
  Widget build(BuildContext context) {
    final asset = logo?.dark;
    if (asset == null) {
      // Not a fruit. A generic desktop glyph reads as "this is the system menu"
      // without borrowing anybody's trademark.
      return Icon(Icons.blur_on, size: _size, color: onDark);
    }

    // srcIn to onDark, the same rule LauncherBrandIcon uses on a dark surface: a
    // coloured mark goes muddy on frosted chrome, and a tinted silhouette is
    // guaranteed to read and matches the label beside it.
    final tint = ColorFilter.mode(onDark, BlendMode.srcIn);

    return SizedBox(
      width: _size,
      height: _size,
      child: asset.endsWith('.svg')
          ? SvgPicture.asset(asset, width: _size, height: _size, colorFilter: tint)
          : Image.asset(
              asset,
              width: _size,
              height: _size,
              color: onDark,
              colorBlendMode: BlendMode.srcIn,
              filterQuality: FilterQuality.medium,
            ),
    );
  }
}
