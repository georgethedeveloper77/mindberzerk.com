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

  /// TWO lines by default, so long app names wrap instead of truncating.
  ///
  /// MUST MIRROR LayoutResolver.defaultLabelLines, whose comment says the same
  /// about this one. They briefly disagreed (this said 1, that said 2), which
  /// is exactly the failure both comments warn about: the drawer sized its
  /// cells from here while the home grid resolved through LayoutResolver, and
  /// two grids on the same phone used different row heights for the same
  /// unset setting. If you change this, change that one to match.
  ///
  /// The known price, measured on a 412dp phone: a paged drawer fits SIX rows
  /// at one line and FIVE at two, so this costs a row per page. Accepted
  /// deliberately; names like "Secure Folder" rendering whole is worth more
  /// than the sixth row, and the people who disagree have the labelLines
  /// setting.
  static const defaultLabelLines = 2;

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

  /// The gap between an icon and its label. Mirrors the SizedBox in the tile.
  static const labelGap = 6.0;

  /// The label's line height multiplier. The tile MUST set this explicitly on
  /// its TextStyle, or what is measured here and what is drawn there disagree
  /// by whatever the font's own default happens to be.
  static const labelLineHeight = 1.25;

  /// A little air under the last line, so a descender does not sit on the cell
  /// boundary and a one-pixel rounding difference does not clip a letter.
  /// Raised from 8 when the drop ring stopped stealing 4 of it. Kept generous
  /// because this is the only slack absorbing a font whose real metrics run
  /// taller than the multiplier, and the cost of too little is a clipped label
  /// while the cost of too much is a few pixels of air.
  static const cellBreathingRoom = 10.0;

  /// How tall a cell has to be to hold its own contents.
  ///
  /// ─── THIS REPLACES A MAGIC ASPECT RATIO ─────────────────────────────────
  ///
  /// The drawer used `labelLines > 1 ? 0.70 : 0.78` and divided the cell width
  /// by it. That number knew nothing about the icon size, nothing about the
  /// font size, and nothing about the SYSTEM font scale, so it was right on one
  /// phone at one setting and wrong everywhere else, in both directions:
  ///
  ///   TOO SHORT  a second label line got clipped, which is why an app called
  ///              "All Document Reader" lost the word "Reader" while its
  ///              one-line neighbours looked fine. Anyone running Android's
  ///              font size above default hit it on far more apps.
  ///
  ///   TOO TALL   a cell sized for two lines holding a one-line label leaves
  ///              dead space at the bottom of every tile in that row, and the
  ///              gap between rows reads as uneven because it is: the space is
  ///              inside the cells, not between them.
  ///
  /// Both are the same mistake, so both take the same fix. Ask what the content
  /// needs and make the cell that tall.
  ///
  /// [textScaler] is the AMBIENT one, from MediaQuery. Flutter applies it to
  /// the label on top of the theme's own `textScale`, so a measurement that
  /// omits it is wrong by exactly the amount the user has turned their font up.
  static double cellHeightFor({
    required double iconSize,
    required int labelLines,
    required double fontSize,
    double textScaler = 1.0,
  }) {
    return iconSize +
        labelGap +
        labelBlockFor(
          labelLines: labelLines,
          fontSize: fontSize,
          textScaler: textScaler,
        ) +
        cellBreathingRoom;
  }

  /// Exactly how tall the label's box is.
  ///
  /// ─── THE TILE MUST ENFORCE THIS, NOT JUST ASSUME IT ─────────────────────
  ///
  /// [cellHeightFor] computes a cell from this number, but nothing made the
  /// LABEL that tall, so the two agreed only as long as the font's own metrics
  /// matched the multiplier. Ubuntu's do not match Inter's, a fallback face for
  /// a script the bundled font lacks matches neither, and the difference lands
  /// on the last row, where there is no row below to lend it space. Everything
  /// above simply pushes down and looks fine.
  ///
  /// So the tile wraps its label in a box of exactly this height. Then the cell
  /// arithmetic and the widget are the same number by construction rather than
  /// by agreement, and a face with taller metrics ellipsises inside its own box
  /// instead of pushing the grid over its edge.
  static double labelBlockFor({
    required int labelLines,
    required double fontSize,
    double textScaler = 1.0,
  }) {
    final lines = labelLines < 1 ? 1 : labelLines;
    return lines * fontSize * textScaler * labelLineHeight;
  }

  /// The cell's aspect for a [SliverGridDelegateWithFixedCrossAxisCount],
  /// which takes width over height rather than a height.
  static double aspectFor({
    required double cellWidth,
    required double iconSize,
    required int labelLines,
    required double fontSize,
    double textScaler = 1.0,
  }) {
    final h = cellHeightFor(
      iconSize: iconSize,
      labelLines: labelLines,
      fontSize: fontSize,
      textScaler: textScaler,
    );
    return h <= 0 ? 1.0 : cellWidth / h;
  }
}
