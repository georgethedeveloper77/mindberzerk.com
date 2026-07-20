/// How big an icon is. The ONE place that answers it.
///
/// Pure functions, no imports, no Flutter — testable at every screen size the
/// way DockMetrics and GridMetrics already are.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// THERE ARE NO DP CONSTANTS FOR ICON SIZE ANY MORE, AND THAT IS THE POINT.
///
/// Icon size used to have three owners that disagreed:
///
///   * `LayoutResolver.defaultIconSizeDp = 52.0` — a flat number that ignored
///     the screen entirely, so a 320dp Tecno and a 900dp tablet got the same
///     52dp icon.
///   * `GridMetrics.iconSizeFor` — responsive and correct, but only consulted
///     by the drawer.
///   * `DockMetrics.appGlyphFor` — slot-derived, correct, and unaware of both.
///
/// Three answers means a setting that visibly works in one surface and quietly
/// does nothing in another, which is exactly the class of bug the EffectiveTheme
/// rule exists to prevent. So: size always derives from the CONTAINER the icon
/// sits in (a grid cell, a dock slot), times an optional per-theme [ThemeLayout]
/// `iconScale`, clamped here and nowhere else.
///
/// A distro whose icon set reads small — Papirus-ish sets draw well inside their
/// keyline — sets `"iconScale": 0.92` in its theme.json and every surface
/// follows. That is a CDN theme edit, not a Play release, which is the same bet
/// the rest of the theme layer makes.
/// ─────────────────────────────────────────────────────────────────────────────
library;

abstract final class IconSizing {
  /// The unscaled range for a grid icon. These are the bounds
  /// `GridMetrics.iconSizeFor` has always applied, preserved exactly so a theme
  /// that sets no `iconScale` renders pixel-identically to before this file
  /// existed.
  static const gridMinDp = 40.0;
  static const gridMaxDp = 64.0;

  /// The absolute floor and ceiling AFTER [ThemeLayout.iconScale] is applied.
  /// Wider than the unscaled range, because scaling is allowed to push past the
  /// default, and hard because a CDN theme must not be able to ship a 200dp
  /// icon that pushes the label off the screen.
  static const hardMinDp = 32.0;
  static const hardMaxDp = 76.0;

  /// How much of a grid cell the icon occupies, with the rest going to the
  /// label. 0.62 leaves room for two lines of text, which is what stops
  /// "Secure Folder" rendering as "Secure Fold…".
  static const cellRatio = 0.62;

  /// The icon size for a grid [cellDp] wide, before any theme scale.
  static double baseInCell(double cellDp) =>
      (cellDp * cellRatio).clamp(gridMinDp, gridMaxDp);

  /// Applies a theme's [scale] to any base size and clamps the result.
  ///
  /// The single choke point. Dock glyphs (`DockMetrics.appGlyphFor`), Aqua's
  /// magnified slots and grid cells all pass through here, so `iconScale` cannot
  /// work in one surface and silently miss another.
  static double scaled(double baseDp, double scale) =>
      (baseDp * scale).clamp(hardMinDp, hardMaxDp);

  /// The full grid path: cell to final size, scale applied.
  static double inCell(double cellDp, {double scale = 1.0}) =>
      scaled(baseInCell(cellDp), scale);

  /// Parses and BOUNDS a theme's `layout.iconScale`.
  ///
  /// Clamped on the way in rather than trusted, for the same reason
  /// `SplashSpec` clamps its duration in the constructor: a downloaded theme is
  /// content that drives UI, and content that drives UI gets validated. Absent
  /// or unparseable yields 1.0.
  static const minScale = 0.7;
  static const maxScale = 1.4;

  static double parseScale(Object? raw) {
    final v = (raw as num?)?.toDouble();
    if (v == null || v.isNaN || !v.isFinite) return 1.0;
    return v.clamp(minScale, maxScale);
  }
}
