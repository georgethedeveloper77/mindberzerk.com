/// PHASE 4.
///
/// Merges the theme's default layout with the user's overrides:
///
///     effective = themeDefault  <-  userOverride (when set)
///
/// Store overrides PER THEME. If someone sets the dock to bottom on Ubuntu,
/// then tries KDE, they should get KDE's authentic bottom panel — not a
/// half-remembered preference from another distro. But when they come back to
/// Ubuntu, their bottom dock is still there.
///
/// Overridable: dock side, rows, cols, icon size, drawer style, labels on/off.
library;

import '../data/prefs/launcher_prefs.dart';
import 'theme_spec.dart';

/// The resolved layout scalars: theme defaults with the user's per-theme
/// overrides applied. Pure data, so [LayoutResolver.resolve] can be unit-tested
/// without a device, the same treatment HomeLayout and DockMetrics already get.
class ResolvedLayout {
  const ResolvedLayout({
    required this.dock,
    required this.topBar,
    required this.rows,
    required this.cols,
    required this.drawerCols,
    required this.iconSizeDp,
    required this.labelLines,
    required this.textScale,
    required this.iconScale,
  });

  final DockSide dock;
  final bool topBar;
  final int rows;
  final int cols;
  final int drawerCols;
  /// The user's EXPLICIT icon-size override, in dp, or the legacy default.
  ///
  /// Being phased out. It is a flat number that knows nothing about the screen,
  /// which is why a 320dp Tecno and a 900dp tablet got the same 52dp icon. New
  /// surfaces should size from their container via `IconSizing` and apply
  /// [iconScale]; this stays until the last caller is converted, so an existing
  /// user's saved preference is not silently dropped.
  final double iconSizeDp;

  final int labelLines;
  final double textScale;

  /// The active theme's per-theme icon multiplier, straight from
  /// `ThemeLayout.iconScale`. No user override merges into it: it describes the
  /// distro's ARTWORK, not a preference, and a user who wants bigger icons has
  /// the grid-columns setting, which changes the cell and therefore the icon.
  final double iconScale;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResolvedLayout &&
          other.dock == dock &&
          other.topBar == topBar &&
          other.rows == rows &&
          other.cols == cols &&
          other.drawerCols == drawerCols &&
          other.iconSizeDp == iconSizeDp &&
          other.labelLines == labelLines &&
          other.textScale == textScale &&
          other.iconScale == iconScale;

  @override
  int get hashCode => Object.hash(
        dock,
        topBar,
        rows,
        cols,
        drawerCols,
        iconSizeDp,
        labelLines,
        textScale,
        iconScale,
      );
}

/// Resolves [ThemeSpec] defaults against [LauncherPrefs] overrides. A null
/// override means "inherit the theme"; a set one wins. This is the ONE place
/// the layout merge lives, so a setting can't silently work in one spot and
/// quietly stop in another.
abstract final class LayoutResolver {
  /// Fallback icon cell size when the user hasn't chosen one.
  ///
  /// DEPRECATED IN SPIRIT. A flat dp number cannot be right on both a 320dp
  /// budget phone and a 900dp tablet, which is precisely why icon size now
  /// derives from the container (`GridMetrics.cellWidthFor` for a grid,
  /// `DockMetrics.slotFor` for a dock) through `IconSizing`. This constant
  /// survives only so a user who already set an explicit size keeps it; nothing
  /// new should read it.
  static const defaultIconSizeDp = 52.0;

  /// Two lines so a long name wraps ("Secure Folder") instead of truncating to
  /// "Secure Fold…". Mirrors GridMetrics.defaultLabelLines.
  static const defaultLabelLines = 2;

  static const defaultTextScale = 1.0;

  static ResolvedLayout resolve(ThemeSpec spec, LauncherPrefs prefs) {
    return ResolvedLayout(
      dock: switch (prefs.dockSide) {
        'left' => DockSide.left,
        'bottom' => DockSide.bottom,
        'off' => DockSide.off,
        _ => spec.layout.dock,
      },
      topBar: prefs.topBar ?? spec.layout.topBar,
      rows: prefs.rows ?? spec.layout.rows,
      cols: prefs.cols ?? spec.layout.cols,
      // Drawer defaults to the SAME width as home (a clean 4-wide), not home+1.
      // The user can still bump it in Settings, and the width-responsive
      // GridMetrics path applies in the drawer widget where it is used.
      drawerCols: prefs.drawerCols ?? (prefs.cols ?? spec.layout.cols),
      iconSizeDp: prefs.iconSizeDp ?? defaultIconSizeDp,
      labelLines: prefs.labelLines ?? defaultLabelLines,
      textScale: prefs.textScale ?? defaultTextScale,
      iconScale: spec.layout.iconScale,
    );
  }
}
