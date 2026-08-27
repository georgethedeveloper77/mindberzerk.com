import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../design/theme_mark.dart';
import '../../../engine/theme_source.dart';
import '../../../engine/theme_spec.dart' show PanelModule, ThemePalette;
import 'aqua_bar_modules.dart';

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
    this.opacity = 1.0,
    this.modules,
  });

  /// The distro's own bar, or null for the arrangement below.
  ///
  /// ─── THE SAME TREATMENT THE WAYBAR GOT ──────────────────────────────────
  ///
  /// This strip was a fixed Row: mark, title, Spacer, Spotlight. Both aqua
  /// distros therefore had the identical bar, and elementary's wingpanel, which
  /// puts the clock in the MIDDLE and indicators on the right, could not be
  /// expressed at all. `PanelModule`'s vocabulary reached gnome and plasma and
  /// not this shell, exactly as it did not reach tiling before Arch's pass.
  ///
  /// Null keeps the Mac arrangement byte for byte, so a distro that authors no
  /// top panel does not move.
  final List<PanelModule>? modules;

  final ThemePalette palette;

  /// How solid the frosted strip is, from `EffectiveTheme.barOpacity`.
  ///
  /// Multiplied into the authored 0.55 rather than replacing it. The frosted
  /// strip IS the macOS tell, so this scales the translucency the bar already
  /// has and never turns it into a plain opaque toolbar.
  final double opacity;

  /// The theme's name, set semibold where a Mac shows the frontmost app. Read
  /// from the spec rather than hardcoded to "Finder" so a second Aqua-family
  /// theme is still a data change.
  final String title;

  final VoidCallback onLaunchpad;
  final VoidCallback onSpotlight;

  /// The theme's own mark, already RESOLVED, or null for the neutral glyph.
  ///
  /// A [ThemeAsset] rather than the [ThemeLogo] pair, because this bar picks
  /// one variant and always the dark one: the strip is frosted chrome. Taking
  /// the pair meant composing the path here, which is how this file ended up
  /// with the same `Image.asset` on a bare filename that the splash and the
  /// drawer both had. See [ThemeSpec.logoAsset].
  final ThemeAsset? logo;

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
            color: palette.bar.withValues(alpha: 0.55 * opacity),
            border: Border(
              bottom: BorderSide(color: onDark.withValues(alpha: 0.08)),
            ),
          ),
          child: Row(
            children: [
              if (modules == null) ...[
                _MarkAndTitle(
                  logo: logo,
                  title: title,
                  onDark: onDark,
                  displayFontFamily: displayFontFamily,
                  onTap: onLaunchpad,
                ),
                const Spacer(),
              ] else
                ...aquaBarModules(
                  modules!,
                  palette: palette,
                  displayFontFamily: displayFontFamily,
                  logo: logo,
                  title: title,
                  onActivities: onLaunchpad,
                ),

              // ─── SPOTLIGHT IS PINNED, NOT A MODULE ────────────────────
              //
              // The waybar's distro name is fallback-only, because a label in
              // the middle of a bar is decoration and a distro that did not
              // ask for it should not get it. This is the opposite case: search
              // is a FUNCTION, there is no `PanelModule` for it, and an
              // authored bar that silently lost it would be a bar with a
              // feature removed rather than a feature not chosen.
              //
              // Adding a module for it would mean a new arm in three exhaustive
              // switches for one button. Pinning it costs nothing and is
              // honest about which of the two kinds of thing it is.
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

  final ThemeAsset? logo;
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

  final ThemeAsset? logo;
  final Color onDark;

  static const _size = 14.0;

  @override
  Widget build(BuildContext context) {
    // As authored, matching the drawer and the splash. This bar tinted
    // unconditionally on the grounds that a coloured mark goes muddy on frosted
    // glass; the same reasoning made Ubuntu's logo a white disc everywhere it
    // appeared, and a theme's dark-surface variant is already art for chrome
    // like this. The neutral glyph below is still tinted, because it is a
    // system glyph rather than anybody's mark.
    return ThemeMark(
      asset: logo,
      size: _size,
      tint: null,
      // Not a fruit. A generic desktop glyph reads as "this is the system menu"
      // without borrowing anybody's trademark. See the class note.
      fallback: Icon(Icons.blur_on, size: _size, color: onDark),
    );
  }
}
