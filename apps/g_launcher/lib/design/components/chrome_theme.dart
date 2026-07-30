import 'package:flutter/material.dart';

import '../../engine/theme_spec.dart'
    show ChromeFamily, ThemePalette, ThemeTypography;
import '../tokens/colors.dart';
import '../tokens/typography.dart';

/// The chrome layer — Phase B, B1/B2.
///
/// "Chrome" is every launcher-owned surface that is NOT a desktop shell:
/// Settings, the theme gallery, wallpaper picker, dialogs, bottom sheets,
/// folder popovers. Historically these read the house tokens ([GColors],
/// [GType]) directly, which is why they look identical under every distro. The
/// whole job of Phase B is to make them look like the distro instead — GNOME
/// Settings under Ubuntu, System Settings under KDE — WITHOUT authoring a
/// separate palette per distro.
///
/// The trick that makes that possible: a [ThemePalette] only carries six
/// colours (bgTop, bgBottom, bar, dock, accent, onDark), and they describe the
/// *desktop*, not a settings screen. So the chrome layer DERIVES a full chrome
/// colour set from those six. A theme author never writes `surface` or
/// `textMuted`; they fall out of the palette the theme already ships. That
/// keeps the "a new distro is minimal JSON, no code" promise intact: add
/// Pop!_OS as a palette and its Settings screen is themed for free.
///
/// T1 CHANGED WHAT "THEMED" MEANS HERE, and it is worth reading [_neutral]
/// before changing it back. Surfaces are neutral greys now, not tinted with
/// the wallpaper, because that is what the desktops being imitated actually
/// do. The accent still comes through untouched.
///
/// Flow of truth: EffectiveTheme -> ChromeData.fromPalette -> ChromeScope ->
/// primitives read ChromeScope.of(context). The primitives never touch
/// EffectiveTheme, Riverpod, or the house tokens; they read one inherited
/// object. Only [ThemedScaffold] bridges from the provider to the scope.

/// The derived chrome colours.
///
/// Every field is computed from the theme's six palette colours, EXCEPT the
/// three semantic statuses (ok/warn/danger), which are intentionally
/// theme-independent: "this action is destructive" should read the same red
/// whether you're in Ubuntu or Arch. Brand belongs to the distro; danger
/// belongs to the user's safety.
@immutable
class ChromeColors {
  const ChromeColors({
    required this.bg,
    required this.bar,
    required this.surface,
    required this.surfaceAlt,
    required this.text,
    required this.textMuted,
    required this.textFaint,
    required this.line,
    required this.lineStrong,
    required this.accent,
    required this.onAccent,
    required this.ok,
    required this.warn,
    required this.danger,
    required this.tint,
  });

  /// Page background behind cards. A NEUTRAL grey at Adwaita's page lightness,
  /// carrying a trace of the distro's hue. See [_neutral] for why this stopped
  /// being the wallpaper's own colour.
  final Color bg;

  /// The chrome's header bar. Deliberately the SAME value as [surface], the way
  /// Adwaita's header bar is: separated from the page by a hairline, not by a
  /// step in lightness.
  final Color bar;

  /// Card / list surface, one step up from [bg].
  final Color surface;

  /// Pressed, elevated, or selected surface — one step up again.
  final Color surfaceAlt;

  final Color text;
  final Color textMuted;
  final Color textFaint;

  /// Hairline dividers and control outlines.
  final Color line;

  /// A heavier divider — section splits, focused outlines.
  final Color lineStrong;

  final Color accent;

  /// Ink that sits ON the accent (filled buttons, active switch thumb). Picked
  /// for contrast against [accent], so a pale-accent theme gets dark ink and a
  /// dark-accent theme gets white — no per-theme authoring.
  final Color onAccent;

  final Color ok;
  final Color warn;
  final Color danger;

  /// The distro's OWN base colour, un-neutralised.
  ///
  /// ─── THE ONE COLOUR HERE THAT KEEPS ITS HUE ─────────────────────────────
  ///
  /// Every surface above is drained to a near-grey by [_neutral], and that is
  /// correct for a settings PAGE: real Adwaita and Breeze carry structure in
  /// greys and reserve colour for state, and a settings screen tinted with the
  /// wallpaper reads as a themed app rather than a system one.
  ///
  /// A floating panel is a different surface and the desktops treat it
  /// differently. GNOME's popovers and KDE's panels are translucent over the
  /// wallpaper, and what shows through is the desktop's own colour. So a sheet
  /// needs the aubergine that `_neutral` deliberately threw away, and this is
  /// where it survives.
  ///
  /// Used ONLY by translucent floating surfaces (see [ThemedSheet]). A page
  /// background reaching for this would undo the whole reason `_neutral` exists.
  final Color tint;

  /// Semantic statuses. Same hexes as [GColors]; duplicated here so the derived
  /// path has zero dependency on the house tokens and reads as one coherent
  /// set. These are the only non-derived colours by design.
  static const _ok = Color(0xFF5FD08C);
  static const _warn = Color(0xFFF2B441);
  static const _danger = Color(0xFFF0736F);

  /// Derive the whole chrome set from a theme's six palette colours.
  ///
  /// The blend amounts are the entire visual contract of the chrome layer, so
  /// they're deliberately small and fixed: surfaces are the background nudged a
  /// few percent toward the ink, which keeps the distro's tint in the cards
  /// (Ubuntu cards stay faintly aubergine) instead of dropping to neutral grey.
  factory ChromeColors.fromPalette(ThemePalette p) {
    final ink = p.onDark;

    // `onDark` is the colour chosen to read on this theme's chrome, so its own
    // luminance IS that chrome's brightness, read backwards. Light ink means a
    // dark surface. Same trick LauncherBrandIcon already uses to pick which
    // logo variant to draw, and it needs no new theme field.
    final darkChrome = ink.computeLuminance() > 0.5;

    return ChromeColors(
      bg: _neutral(p.bgBottom, darkChrome ? 0.115 : 0.945, dark: darkChrome),
      // Adwaita's header bar is the SAME value as its cards, separated from
      // the page by a hairline rather than by a step in lightness. Was
      // `p.bar`, the desktop's system-bar colour, which is a different surface
      // doing a different job.
      bar: _neutral(p.bgBottom, darkChrome ? 0.188 : 0.975, dark: darkChrome),
      surface: _neutral(p.bgBottom, darkChrome ? 0.188 : 0.975, dark: darkChrome),
      surfaceAlt:
          _neutral(p.bgBottom, darkChrome ? 0.255 : 0.915, dark: darkChrome),
      text: ink,
      // Opacity ramps rather than fixed greys, so muted text keeps the ink's
      // hue. Under a warm-white ink this reads warmer; that is intended.
      textMuted: ink.withValues(alpha: 0.64),
      textFaint: ink.withValues(alpha: 0.40),
      line: ink.withValues(alpha: 0.09),
      lineStrong: ink.withValues(alpha: 0.16),
      accent: p.accent,
      // Relative luminance decides the ink on the accent. Ubuntu orange
      // (#E95420) lands below 0.5 -> white; a pastel accent would flip to dark.
      onAccent: p.accent.computeLuminance() > 0.5
          ? const Color(0xFF12080D)
          : const Color(0xFFFFFFFF),
      ok: _ok,
      warn: _warn,
      danger: _danger,
      // Straight through, not neutralised. See the field doc.
      tint: p.bgBottom,
    );
  }

  /// A palette colour, drained of hue and pinned to an Adwaita lightness step.
  ///
  /// ─── WHY THE CHROME STOPPED BEING AUBERGINE ─────────────────────────────
  ///
  /// Surfaces used to be `p.bgBottom` nudged toward the ink, so Ubuntu's
  /// Settings came out purple, Fedora's navy, KDE's slate. That was a
  /// deliberate choice and it was the wrong one, for a reason that only shows
  /// up when you put the screen next to the thing it is imitating: REAL Ubuntu
  /// Settings is neutral dark grey. So is Fedora's. So is KDE's. Adwaita and
  /// Breeze both carry structure in greys and reserve the accent for STATE,
  /// and a settings screen tinted with the wallpaper reads as a themed app
  /// rather than as a system one.
  ///
  /// SATURATION IS NOT ZEROED, THOUGH. A trace of the distro's hue survives,
  /// capped at 6%, which is below the threshold where anyone would call it
  /// purple and above the point where every distro's chrome is byte-identical.
  /// Ubuntu's greys stay faintly warm, KDE's faintly cool. Zeroing it outright
  /// was the other option and it makes the six themes indistinguishable
  /// anywhere the accent is not on screen.
  ///
  /// The accent still comes straight through, unmodified. That is the whole
  /// point: greys carry the structure, the accent carries the state, and the
  /// distro is legible from one switch and one selection highlight.
  ///
  /// Lightness steps are Adwaita's own: roughly #1e1e1e page, #303030 card in
  /// dark; #f6f6f6 page, #ffffff card in light. Light is handled even though
  /// every bundled theme is currently dark, because a CDN pack with a pale
  /// palette would otherwise get white text on white cards.
  ///
  /// ─── LIGHT MODE NEEDED DIFFERENT NUMBERS, AND ONE OF THEM WAS A BUG ─────
  ///
  /// The light steps were Adwaita's literal values: a #f6f6f6 page and a
  /// #ffffff card. A card at lightness 1.0 IS WHITE, whatever hue and whatever
  /// saturation you hand it, because saturation has no effect at that
  /// lightness. So the moment light mode existed, every settings page, sheet
  /// and dialog in the app came out pure white and the distro vanished from all
  /// of them.
  ///
  /// Two changes. The card comes off 1.0 so its hue can show at all, and the
  /// saturation cap is far higher on a light surface than a dark one. That is
  /// not an inconsistency: the same 6% that reads as a warm grey against near
  /// black is invisible against near white, and matching the two by NUMBER
  /// rather than by APPEARANCE is what produced a white settings screen under
  /// an aubergine desktop.
  ///
  /// Still restrained. Ubuntu's light card lands at #FAF8F9 and its page at
  /// #F3EFF2, which nobody would call purple and which are visibly not the same
  /// screen KDE draws.
  static Color _neutral(Color base, double lightness, {required bool dark}) {
    final hsl = HSLColor.fromColor(base);

    final scale = dark ? 0.12 : 0.55;
    final cap = dark ? 0.06 : 0.18;

    return hsl
        .withSaturation((hsl.saturation * scale).clamp(0.0, cap))
        .withLightness(lightness)
        .toColor();
  }

  /// The bootstrap floor — house chrome, used ONLY while
  /// [effectiveThemeProvider] is still resolving or has errored. Never a
  /// target: the moment the theme lands, every pixel comes from
  /// [ChromeColors.fromPalette]. This is the one sanctioned reader of [GColors]
  /// in the chrome layer (B5).
  static const bootstrap = ChromeColors(
    bg: GColors.bg,
    bar: GColors.surface,
    surface: GColors.surface,
    surfaceAlt: GColors.surfaceAlt,
    text: GColors.text,
    textMuted: GColors.textMuted,
    textFaint: GColors.textFaint,
    line: GColors.line,
    lineStrong: GColors.lineStrong,
    accent: GColors.accent,
    onAccent: Color(0xFFFFFFFF),
    ok: GColors.ok,
    warn: GColors.warn,
    danger: GColors.danger,
    // No theme yet, so there is no distro colour to show through. The house
    // background is the honest stand-in and makes the bootstrap sheet opaque
    // rather than tinted with nothing.
    tint: GColors.bg,
  );
}

/// The chrome text ramp, coloured for the active theme and set in the theme's
/// fonts.
///
/// The house identity rule survives the move: **every data value is mono**
/// ([value]), prose is sans. A distro can swap either family via its typography
/// block (the terminal theme, for instance, can set both to UbuntuMono so the
/// whole of Settings reads like a TTY).
@immutable
class ChromeText {
  const ChromeText({
    required this.display,
    required this.title,
    required this.body,
    required this.caption,
    required this.label,
    required this.value,
  });

  final TextStyle display;
  final TextStyle title;
  final TextStyle body;
  final TextStyle caption;
  final TextStyle label;
  final TextStyle value;

  /// Build the ramp from resolved [ChromeColors] and the theme's fonts.
  /// [scale] is [EffectiveTheme.textScale] so the theme's density preference
  /// carries into chrome, not just the desktop.
  factory ChromeText.resolve(
    ChromeColors c, {
    ThemeTypography? typography,
    double scale = 1.0,
  }) {
    final sans = typography?.display ?? 'Inter';
    final mono = typography?.mono ?? 'UbuntuMono';
    return ChromeText(
      display: TextStyle(
        fontFamily: sans,
        fontSize: 24 * scale,
        fontWeight: FontWeight.w500,
        color: c.text,
        letterSpacing: -0.3,
      ),
      title: TextStyle(
        fontFamily: sans,
        fontSize: 16 * scale,
        fontWeight: FontWeight.w500,
        color: c.text,
      ),
      body: TextStyle(
        fontFamily: sans,
        fontSize: 14 * scale,
        height: 1.45,
        color: c.text,
      ),
      caption: TextStyle(
        fontFamily: sans,
        fontSize: 12 * scale,
        color: c.textMuted,
      ),
      label: TextStyle(
        fontFamily: sans,
        fontSize: 11 * scale,
        fontWeight: FontWeight.w600,
        color: c.textFaint,
        letterSpacing: 0.6,
      ),
      value: TextStyle(
        fontFamily: mono,
        fontSize: 13 * scale,
        color: c.text,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }

  /// Bootstrap ramp — the house type, reused verbatim. Const because [GType]
  /// is const; costs nothing and matches the house look exactly until the
  /// theme lands.
  static const bootstrap = ChromeText(
    display: GType.display,
    title: GType.title,
    body: GType.body,
    caption: GType.caption,
    label: GType.label,
    value: GType.value,
  );
}

/// The aggregate a primitive reads: colours + type. One object so a widget
/// grabs `ChromeScope.of(context)` once and has everything.
@immutable
class ChromeData {
  const ChromeData({
    required this.colors,
    required this.text,
    this.family = ChromeFamily.generic,
  });

  final ChromeColors colors;
  final ChromeText text;

  /// The structural design language (see [ChromeFamily]). Surfaces that fork on
  /// family — the settings group framing now, later the drawer and folder
  /// chrome — read it from here rather than reaching into the spec. Bootstrap is
  /// [ChromeFamily.generic]: a neutral frame until the real theme lands.
  final ChromeFamily family;

  /// House-chrome floor. See [ChromeColors.bootstrap].
  static const bootstrap = ChromeData(
    colors: ChromeColors.bootstrap,
    text: ChromeText.bootstrap,
    family: ChromeFamily.generic,
  );

  /// The one entry point. Given a theme's palette (+ optional font block, text
  /// scale, and resolved family), produce the full derived chrome.
  /// [ThemedScaffold] calls this with the fields off [EffectiveTheme]; nothing
  /// else should need to.
  factory ChromeData.fromPalette(
    ThemePalette palette, {
    ThemeTypography? typography,
    double textScale = 1.0,
    ChromeFamily family = ChromeFamily.generic,
  }) {
    final colors = ChromeColors.fromPalette(palette);
    return ChromeData(
      colors: colors,
      text: ChromeText.resolve(
        colors,
        typography: typography,
        scale: textScale,
      ),
      family: family,
    );
  }
}

/// Carries [ChromeData] down the tree. Every chrome primitive reads it via
/// [ChromeScope.of]; [ThemedScaffold] installs it at the top of each screen.
///
/// Route boundaries: modal sheets and dialogs push a route that is NOT a
/// descendant of the screen's scope, so `.of` there would fall back to
/// bootstrap and the sheet would look un-themed. [ThemedSheet] and
/// [ThemedDialog] fix this by reading the data before pushing and re-wrapping
/// their content in a fresh [ChromeScope]. If you write a new modal, do the
/// same, or it renders in house colours over a themed screen.
class ChromeScope extends InheritedWidget {
  const ChromeScope({super.key, required this.data, required super.child});

  final ChromeData data;

  /// Nearest chrome data, or the bootstrap floor if there is none. Returning a
  /// safe default rather than asserting means a primitive dropped outside a
  /// [ThemedScaffold] renders in house colours instead of crashing — degrade,
  /// never black-screen, same rule as the theme engine.
  static ChromeData of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ChromeScope>();
    return scope?.data ?? ChromeData.bootstrap;
  }

  @override
  bool updateShouldNotify(ChromeScope oldWidget) =>
      !identical(oldWidget.data, data);
}
