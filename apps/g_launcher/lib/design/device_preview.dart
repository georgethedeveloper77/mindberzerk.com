import 'package:flutter/material.dart';

import '../engine/theme_spec.dart';

/// A small live phone showing what a layout setting actually does.
///
/// Shared on purpose. Setup and Settings change the SAME prefs, so showing them
/// in two different pictures would be two chances to drift — and the second one
/// would be the one nobody updated. One widget, three modes, every caller
/// passing the live [EffectiveTheme] values.
///
/// Everything is drawn from the palette, so the preview is also a colour
/// preview: switch distro and it repaints in that distro's own scheme without a
/// line of extra wiring.
enum DevicePreviewMode {
  /// Top bar plus dock — for the dock side and app-grid button.
  desktop,

  /// The app drawer's grid — for the columns setting.
  drawer,

  /// An open folder — for the folder grid and folder shape.
  folder,
}

class DevicePreview extends StatelessWidget {
  const DevicePreview({
    super.key,
    required this.palette,
    required this.mode,
    this.dock = DockSide.left,
    this.gridButton = 'end',
    this.cols = 4,
    this.rows = 4,
    this.tileRadiusFraction = 0.22,
    this.framed = true,
  });

  final ThemePalette palette;
  final DevicePreviewMode mode;

  final DockSide dock;

  /// 'start' | 'end' | 'off'.
  final String gridButton;

  final int cols;
  final int rows;

  /// Folder-tile corner radius as a fraction of the tile, so the shape setting
  /// is visible rather than described.
  final double tileRadiusFraction;

  /// A bordered phone (Settings, folders) or edge to edge (setup).
  ///
  /// Setup runs the preview FULL BLEED: the whole screen is the desktop you are
  /// configuring, with the controls floating over it. A phone drawn inside a
  /// phone there would be a picture of the thing instead of the thing.
  final bool framed;

  @override
  Widget build(BuildContext context) {
    final body = switch (mode) {
      DevicePreviewMode.desktop => _desktop(),
      DevicePreviewMode.drawer => _grid(cols, 5, radius: 3),
      DevicePreviewMode.folder => _folder(),
    };

    if (!framed) {
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [palette.bgTop, palette.bgBottom],
          ),
        ),
        child: body,
      );
    }

    return AspectRatio(
      aspectRatio: 10 / 17,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: palette.onDark.withValues(alpha: 0.16)),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [palette.bgTop, palette.bgBottom],
          ),
        ),
        child: body,
      ),
    );
  }

  Widget _desktop() {
    final strip = _DockStrip(
      palette: palette,
      vertical: dock == DockSide.left,
      gridButton: gridButton,
    );

    return Column(
      children: [
        Container(height: 10, color: palette.bar),
        Expanded(
          child: switch (dock) {
            DockSide.left => Row(children: [strip, const Spacer()]),
            DockSide.bottom => Column(children: [const Spacer(), strip]),
            // The authentic empty desktop: no dock at all.
            DockSide.off => const SizedBox.expand(),
          },
        ),
      ],
    );
  }

  Widget _grid(int across, int down, {required double radius}) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: GridView.count(
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: across,
        mainAxisSpacing: 7,
        crossAxisSpacing: 7,
        children: [
          for (var i = 0; i < across * down; i++)
            Container(
              decoration: BoxDecoration(
                color: palette.onDark.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(radius),
              ),
            ),
        ],
      ),
    );
  }

  /// An open folder: the sheet, its grid at the chosen columns, and only as many
  /// rows as the setting allows before it would scroll.
  ///
  /// ─── THE TILE IS SIZED BY BOTH AXES, AND HAS TO BE ──────────────────────
  ///
  /// This used to lay each tile out with `Expanded` + `AspectRatio(1)`, which
  /// derives the tile from the WIDTH alone. The sheet's height then falls out
  /// as `rows x tileWidth`, and nothing ever compared that against the phone it
  /// was being drawn in. At 5 rows in a 10:17 frame it overflowed by 21px, and
  /// the combination that triggers it depends on two SETTINGS (folder rows and
  /// folder columns), so it appears and disappears as you change them, which
  /// is exactly the shape of bug that looks intermittent.
  ///
  /// So the tile is the SMALLER of what each axis can afford. The width budget
  /// is the sheet minus its padding and gaps; the height budget is the share of
  /// the phone the sheet is allowed, minus its own chrome. Whichever is
  /// tighter wins, and the grid can no longer be taller than the thing it sits
  /// in whatever the settings say.
  Widget _folder() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // ── THE FURNITURE SCALES TOO, AND IT HAS TO ────────────────────────
        //
        // The tile was already sized by both axes, which fixed the 5-row
        // overflow inside the 150px preview. It did NOT fix the same widget
        // drawn at 26x40 in `_ChipValue` beside "Folders" in Settings, because
        // the padding (8), the gaps (6) and the sheet's chrome (23) stayed
        // fixed. Four columns need `4 x 3 + 3 x 6 + 16` = 46px of run before
        // the tile floor even applies; a 24px thumbnail has 24, and the
        // difference is the 22px RenderFlex the console reported.
        //
        // This is the SAME bug `_DockStrip` had, for the same reason: one
        // widget used at two sizes that differ by a factor of six, with fixed
        // furniture inside it. The cure is the same too — derive every metric
        // from the run available, capped at the value the large preview used,
        // so at 150px and above nothing changes and the big preview stays
        // pixel-identical, and below it the whole sheet shrinks together
        // instead of the tiles shrinking inside furniture that cannot.
        //
        // `_reference` is the width the fixed numbers were authored against.
        const reference = 150.0;
        final s = (constraints.maxWidth / reference).clamp(0.0, 1.0);

        final hPad = 8.0 * s;
        final vPad = 8.0 * s;
        final bottomPad = 10.0 * s;
        final gap = 6.0 * s;

        // Grab handle (3 + 7 margin) and the folder-name line (5 + 8 margin).
        final chrome = (10.0 + 13.0) * s;

        // A folder sheet covers most of the screen but never all of it: the
        // dimmed drawer behind it is what makes it read as a sheet rather than
        // as a page, so a slice of it stays visible by construction.
        final sheetBudget = constraints.maxHeight * 0.74;

        final fromWidth =
            (constraints.maxWidth - hPad * 2 - gap * (cols - 1)) / cols;
        final fromHeight =
            (sheetBudget - vPad - bottomPad - chrome - gap * rows) / rows;

        // Whichever axis is tighter wins. The floor is 0.5 rather than 3,
        // because a floor ABOVE what the width can afford is precisely how a
        // clamp turns an unreadable preview into an overflowing one: the old
        // `clamp(3.0, ...)` handed the Row a tile the Row had no room for.
        final tile = (fromWidth < fromHeight ? fromWidth : fromHeight)
            .clamp(0.5, double.infinity);

        // Below this there is nothing honest left to draw. Rendering nothing is
        // better than rendering a smear, and far better than throwing on a
        // settings page.
        if (!tile.isFinite || constraints.maxWidth < 8) {
          return const SizedBox.expand();
        }

        return Stack(
          children: [
            // Dimmed desktop behind, so it reads as a sheet over the drawer
            // rather than as a screen of its own.
            Positioned.fill(
              child: ColoredBox(
                color: palette.bgBottom.withValues(alpha: 0.55),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                decoration: BoxDecoration(
                  color: palette.bar,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(10 * s),
                  ),
                ),
                padding: EdgeInsets.fromLTRB(hPad, vPad, hPad, bottomPad),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Grab handle + name line, so the proportions match the
                    // real sheet rather than floating tiles in a box.
                    // Scaled like everything else. The name line especially:
                    // at 34px fixed it is WIDER than the whole tile row in a
                    // thumbnail, and since a Column takes the width of its
                    // widest child it would push the sheet past the phone on
                    // its own, with the tiles entirely innocent.
                    Center(
                      child: Container(
                        width: 22 * s,
                        height: 3 * s,
                        margin: EdgeInsets.only(bottom: 7 * s),
                        decoration: BoxDecoration(
                          color: palette.onDark.withValues(alpha: 0.28),
                          borderRadius: BorderRadius.circular(2 * s),
                        ),
                      ),
                    ),
                    Container(
                      width: 34 * s,
                      height: 5 * s,
                      margin: EdgeInsets.only(left: 2 * s, bottom: 8 * s),
                      decoration: BoxDecoration(
                        color: palette.onDark.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(2 * s),
                      ),
                    ),
                    for (var r = 0; r < rows; r++)
                      Padding(
                        padding: EdgeInsets.only(bottom: gap),
                        child: Row(
                          // The row is exactly the width budget by
                          // construction, but min stops it claiming the
                          // Column's full width on the way there.
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var i = 0; i < cols; i++)
                              Padding(
                                padding: EdgeInsets.only(
                                  right: i == cols - 1 ? 0 : gap,
                                ),
                                child: SizedBox(
                                  width: tile,
                                  height: tile,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: palette.onDark
                                          .withValues(alpha: 0.20),
                                      // The shape setting, drawn, and now
                                      // against the tile's REAL size rather
                                      // than a hardcoded 14 that was only
                                      // right at one column count.
                                      borderRadius: BorderRadius.circular(
                                        tile * tileRadiusFraction,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DockStrip extends StatelessWidget {
  const _DockStrip({
    required this.palette,
    required this.vertical,
    required this.gridButton,
  });

  final ThemePalette palette;
  final bool vertical;
  final String gridButton;

  @override
  Widget build(BuildContext context) {
    // ── THE PIPS SIZE THEMSELVES, AND THEY HAVE TO ──────────────────────────
    //
    // They used to be a fixed 11px with fixed 2px margins, which needs about
    // 68px of run. That is fine in the 150px preview setup shows and overflows
    // by 40px in the 26x40 thumbnail `_ChipValue` puts beside "Desktop grid",
    // which is exactly the RenderFlex the console reported.
    //
    // ONE widget is used at two sizes that differ by a factor of four, so
    // anything fixed here is wrong at one of them. The pip is therefore derived
    // from the run actually available and clamped: never bigger than the old
    // 11 (so the large preview is pixel-identical to before), never smaller
    // than 2 (below that it stops reading as an icon and becomes noise).
    return LayoutBuilder(
      builder: (context, constraints) {
        const pinCount = 3;
        final count = pinCount + (gridButton == 'off' ? 0 : 1);

        final run = vertical ? constraints.maxHeight : constraints.maxWidth;

        // THE PADDING AND THE MARGINS SCALE TOO, and that is the second half of
        // this fix. Clamping only the PIP left the 4px padding and the 2px
        // margins fixed, so the strip could never be shorter than
        // `count * (2 + 4) + 8`, which is 32px for four pips. A 26x40 thumbnail
        // gives it about 28, and it overflowed by the difference: a smaller
        // number than before, from exactly the same cause.
        //
        // So everything is a fraction of the run, capped at the values the
        // large preview used. Above roughly 70px nothing changes and the big
        // preview is pixel-identical; below it the whole strip shrinks together
        // instead of the pips shrinking inside fixed furniture.
        final pad = (run * 0.10).clamp(1.0, 4.0);
        final margin = (run * 0.05).clamp(0.5, 2.0);

        final size = run.isFinite
            ? ((run - pad * 2 - count * margin * 2) / count).clamp(1.5, 11.0)
            : 11.0;

        final pins = [
          for (var i = 0; i < pinCount; i++)
            _pip(palette.onDark.withValues(alpha: 0.55), size, margin),
        ];

        // The app-grid button in the accent, so its position is unmistakable at
        // this size — which is the entire point of the setting it illustrates.
        final grid = _pip(palette.accent, size, margin);

        final children = <Widget>[
          if (gridButton == 'start') grid,
          ...pins,
          if (gridButton == 'end') grid,
        ];

        return Container(
          color: palette.dock,
          padding: EdgeInsets.all(pad),
          child: vertical
              ? Column(mainAxisSize: MainAxisSize.min, children: children)
              : Row(mainAxisSize: MainAxisSize.min, children: children),
        );
      },
    );
  }

  Widget _pip(Color c, double size, double margin) => Container(
        width: size,
        height: size,
        margin: EdgeInsets.all(margin),
        decoration: BoxDecoration(
          color: c,
          // Scaled with the pip: a fixed 3px radius on a 2px pip is a circle
          // and on an 11px one is a rounded square, so the shape would change
          // meaning between the two sizes this widget is used at.
          borderRadius: BorderRadius.circular(size * 0.27),
        ),
      );
}

/// A distro swatch for the setup picker — the small sibling of the theme
/// gallery's card preview. Kept separate from [DevicePreview] because it paints
/// catalog data (a distro that is not yet applied), not the live palette.
class ThemeSwatch extends StatelessWidget {
  const ThemeSwatch({
    super.key,
    required this.bg,
    required this.bar,
    required this.accent,
    this.radial = false,
    this.selected = false,
  });

  final List<Color> bg;
  final Color bar;
  final Color? accent;
  final bool radial;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.25,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          gradient: radial
              ? RadialGradient(colors: bg, radius: 1.1)
              : LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: bg,
                ),
        ),
        child: Column(
          children: [
            Container(height: 4, color: bar),
            if (accent != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Container(
                  width: 10,
                  height: 4,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
