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
/// keeps the "a new distro is minimal JSON, no code" promise intact — add
/// Pop!_OS as a palette and its Settings screen is themed for free.
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
  });

  /// Page background behind cards. The distro's darker wallpaper stop, so the
  /// Settings screen sits in the same aubergine / navy / black the desktop
  /// does instead of a neutral grey that reads as "generic Android app".
  final Color bg;

  /// The chrome's top bar / app bar. Literally the distro's system-bar colour.
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
    return ChromeColors(
      bg: p.bgBottom,
      bar: p.bar,
      // 5.5% / 10% toward the ink: just enough separation to read as a raised
      // card on the page without inventing a second hue.
      surface: Color.lerp(p.bgBottom, ink, 0.055)!,
      surfaceAlt: Color.lerp(p.bgBottom, ink, 0.10)!,
      text: ink,
      // Opacity ramps rather than fixed greys, so muted text keeps the ink's
      // hue. Under a warm-white ink this reads warmer; that's intended.
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
    );
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
