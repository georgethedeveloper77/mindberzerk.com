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
  Widget _folder() {
    return Stack(
      children: [
        // Dimmed desktop behind, so it reads as a sheet over the drawer rather
        // than as a screen of its own.
        Positioned.fill(
          child: ColoredBox(color: palette.bgBottom.withValues(alpha: 0.55)),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            decoration: BoxDecoration(
              color: palette.bar,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(10),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Grab handle + name line, so the proportions match the real
                // sheet rather than floating tiles in a box.
                Center(
                  child: Container(
                    width: 22,
                    height: 3,
                    margin: const EdgeInsets.only(bottom: 7),
                    decoration: BoxDecoration(
                      color: palette.onDark.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Container(
                  width: 34,
                  height: 5,
                  margin: const EdgeInsets.only(left: 2, bottom: 8),
                  decoration: BoxDecoration(
                    color: palette.onDark.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                for (var r = 0; r < rows; r++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        for (var i = 0; i < cols; i++)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 3,
                              ),
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: palette.onDark
                                        .withValues(alpha: 0.20),
                                    borderRadius: BorderRadius.circular(
                                      // The shape setting, drawn. 14 is the
                                      // tile's approximate width here.
                                      14 * tileRadiusFraction,
                                    ),
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
    final pins = [
      for (var i = 0; i < 3; i++)
        _pip(palette.onDark.withValues(alpha: 0.55)),
    ];

    // The app-grid button in the accent, so its position is unmistakable at
    // this size — which is the entire point of the setting it illustrates.
    final grid = _pip(palette.accent);

    return Container(
      color: palette.dock,
      padding: const EdgeInsets.all(4),
      child: vertical
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (gridButton == 'start') grid,
                ...pins,
                if (gridButton == 'end') grid,
              ],
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (gridButton == 'start') grid,
                ...pins,
                if (gridButton == 'end') grid,
              ],
            ),
    );
  }

  Widget _pip(Color c) => Container(
        width: 11,
        height: 11,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(3),
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
