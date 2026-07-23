/// Responsive grid defaults.
///
/// There is no Android API for "what grid is comfortable on this screen" — but
/// comfort follows *width*: column count should track it, and icon size follows
/// from column count. Width is the only input that matters, so these are pure
/// functions of it.
///
/// Context: the old default was 5×5 with single-line labels, which on a 392dp
/// phone gives ~78dp per cell of which ~24dp is label — cramped, and every
/// second app renders as "Secure Fold…". 4 columns gives ~98dp and room for the
/// label to wrap.
library;

import 'icon_sizing.dart';

abstract final class GridMetrics {
  /// Drawer columns by screen width in dp.
  ///
  /// The drawer SCROLLS, so rows are emergent — column count is the only real
  /// decision. This is the fallback when neither the user (prefs.drawerCols)
  /// nor a good reason from the theme has set one.
  static int drawerColumns(double widthDp) {
    if (widthDp < 360) return 3; // small phones, split-screen
    if (widthDp < 420) return 4; // ~every current phone. The default.
    if (widthDp < 600) return 5; // large/wide phones, landscape-ish
    if (widthDp < 900) return 6; // small tablets
    return 8; // big tablets
  }

  /// ONE line by default. This reverses the earlier call, and the earlier
  /// reasoning ("Secure Fold…" is not a name, it's a shrug) was right about the
  /// label and wrong about the price.
  ///
  /// The price is a whole ROW of grid height on every page, paid to accommodate
  /// roughly one app in twenty. Measured on a 412dp phone, a paged drawer fits
  /// SIX rows at one line and FIVE at two. Trading a sixth of the drawer for a
  /// truncation nobody hits often is the wrong side of that trade, and the
  /// people who disagree have a toggle in Settings.
  static const defaultLabelLines = 1;

  /// Icon size for a given width and column count, label space allowed for.
  /// 16dp outer padding each side, 8dp between columns — matching the drawer's
  /// existing GridView padding/spacing.
  ///
  /// The CELL is this file's business; how much of it an icon takes is
  /// [IconSizing]'s. Splitting it that way is what lets a theme's `iconScale`
  /// reach the drawer, the dock and the folder grid through one function
  /// instead of three that drift.
  ///
  /// [scale] defaults to 1.0, so an existing caller that has no EffectiveTheme
  /// to hand gets exactly the numbers this returned before.
  static double iconSizeFor(double widthDp, int columns, {double scale = 1.0}) {
    return IconSizing.inCell(cellWidthFor(widthDp, columns), scale: scale);
  }

  /// The raw cell width, exposed because the folder grid and the drawer both
  /// need it for spacing decisions that are not about the icon.
  static double cellWidthFor(double widthDp, int columns) =>
      (widthDp - 32 - (columns - 1) * 8) / columns;
}
