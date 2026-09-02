import 'package:flutter/material.dart';

import '../engine/theme_spec.dart';
import '../engine/wallpaper_framing.dart';
import 'device_metrics.dart';
import 'wallpaper_paint.dart';

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

  /// The LOCK screen: clock, date, nothing else.
  ///
  /// The one mode that is not a picture of this launcher. It exists because the
  /// wallpaper setting can apply to the lock screen too, and that toggle is
  /// otherwise a promise the user has to lock the phone to check. Android draws
  /// the real thing, so this is a stand-in for the wallpaper behind it rather
  /// than an imitation of any particular OEM's lock screen, and it deliberately
  /// carries no launcher chrome for that reason.
  lock,
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
    this.background,
    this.backgroundFraming = const WallpaperFraming(),
    this.clockLabel,
    this.dateLabel,
    this.tiles = const <Widget>[],
    this.dockTiles = const <Widget>[],
    this.overlay,
    this.panels,
    this.dockStyle = 'flat',
    this.homeLayout = 'grid',
    this.desktopIcons = true,
    this.iconCornerFraction = 0.20,
  });

  final ThemePalette palette;
  final DevicePreviewMode mode;

  final DockSide dock;

  // ───────────────────────────────────────────────────────────────────────────
  // THE DISTRO FIELDS
  //
  // Everything above this line describes a SETTING and has a primitive default
  // that reproduces what this widget drew before any of these existed. That is
  // deliberate and it is the contract: six screens draw this widget, two of
  // them at 26x40 in a value chip, and none of them passes anything below.
  //
  // Everything below describes a DISTRO, and arrives from `EffectiveTheme` by
  // way of `DistroPreview`. Each one defaults to the answer that was hardcoded
  // here: one top bar, a flat dock, a grid, icons on, a 0.20 corner. So the
  // settings previews are pixel-identical and the storefront gets the parts
  // that actually tell two distros apart.
  // ───────────────────────────────────────────────────────────────────────────

  /// The distro's panels, in `EffectiveTheme.panels` order.
  ///
  /// ─── ONE FIELD CARRIES THE EDGE AND THE CONTENT ───────────────────────────
  ///
  /// A `barSide` parameter was the obvious shape and it is half an answer. Four
  /// of fourteen distros put their bar along the BOTTOM and three have none at
  /// all, so a top-or-bottom flag fixes the position and leaves every panel
  /// drawn as the same coloured strip. A GNOME top bar and a Plasma panel are
  /// not the same object in a different place: one is an Activities corner and
  /// a clock, the other is a launcher, task buttons, a pager and a tray. At
  /// 152dp that difference is the most recognisable thing on the card.
  ///
  /// `LayoutResolver` already synthesises a panel list for themes authored
  /// before panels existed, so this is populated for every distro rather than
  /// only the ones that opted in.
  ///
  /// ─── THREE STATES, AND COLLAPSING TWO OF THEM IS A BUG ───────────────────
  ///
  ///   null        no opinion. Draws the single top strip this widget has
  ///               always drawn, which is what every settings caller wants: a
  ///               bar in a layout preview is furniture saying "this is a
  ///               desktop", not a claim about any distro's panel.
  ///   empty       this distro has NO panel. Three in the catalogue do not, and
  ///               drawing one for them is the same error the old storefront
  ///               preview made on seven cards.
  ///   non-empty   draw these.
  ///
  /// A non-nullable list cannot say the first two apart, and the version of
  /// this that used `const []` for "no opinion" had no way left to express a
  /// distro with no bar.
  final List<PanelSpec>? panels;

  /// 'flat' | 'floating' | 'magnified'. From `EffectiveTheme.dockStyle`.
  ///
  /// The gap under a floating dock is the whole visible difference between
  /// Plank and a Latte dock, and the swollen middle icon IS the recognisable
  /// thing about Aqua. Both survive at thumbnail size; a colour does not.
  final String dockStyle;

  /// 'grid' | 'tiled'. From `EffectiveTheme.homeLayout`.
  ///
  /// A tiling desktop is windows filling the canvas edge to edge, and it is the
  /// one shape no other card in the catalogue shows. Drawing Pop or Arch with a
  /// grid of icons is drawing the wrong desktop, not a simplified one.
  final String homeLayout;

  /// Does the desktop carry icons at all. From `EffectiveTheme.desktopIcons`.
  final bool desktopIcons;

  /// Corner radius of a dock pip, as a fraction of its box.
  ///
  /// The distro's icon shape, which `_DockStrip` used to hardcode at 0.27. A
  /// circle at 0.5 and a square at 0 are both real answers in the catalogue and
  /// they read differently across a room.
  final double iconCornerFraction;

  /// 'start' | 'end' | 'off'.
  final String gridButton;

  final int cols;
  final int rows;

  /// Folder-tile corner radius as a fraction of the tile, so the shape setting
  /// is visible rather than described.
  final double tileRadiusFraction;

  /// The wallpaper, drawn behind everything instead of the palette gradient.
  ///
  /// ─── WHY THIS IS A PROVIDER AND NOT A PATH ──────────────────────────────
  ///
  /// Because a theme's wallpaper is a bundled asset on one device and a file
  /// inside `packs/<id>/` on the next, and `ThemeAsset.image` is the one thing
  /// that knows which. Taking a String here would put a fourth copy of that
  /// decision in a widget whose whole job is drawing, and the app has already
  /// paid for that mistake in the strip, the splash, the drawer and the Aqua
  /// bar.
  ///
  /// Null keeps the gradient, which is right for every caller that is
  /// previewing a LAYOUT rather than a picture.
  final ImageProvider? background;

  /// How [background] meets the preview, matching how it meets the phone.
  ///
  /// ─── WHY A PREVIEW HAS TO CARE ──────────────────────────────────────────
  ///
  /// This drew every wallpaper `BoxFit.cover`, centred, which was correct for
  /// exactly as long as that was the only thing the app could do. Once framing
  /// became per wallpaper the preview at the top of the wallpaper page started
  /// claiming a centred crop for an image the user had deliberately pushed off
  /// centre, and it is the ONE picture on that page whose whole job is to say
  /// what the phone looks like.
  ///
  /// The default is the default everywhere else, so every existing caller draws
  /// exactly what it drew before: a layout preview is previewing a LAYOUT and
  /// has no business knowing about focal points.
  final WallpaperFraming backgroundFraming;

  /// Clock face for [DevicePreviewMode.lock], and the date under it.
  ///
  /// Passed in rather than read here, because this widget has no Riverpod
  /// import and should not gain one: it is drawn inside settings rows, inside
  /// chooser tiles and at thumbnail size in a value chip, and a clock ticking
  /// in six places at once on a settings page is a lot of rebuilds for a
  /// picture. The caller formats them once.
  final String? clockLabel;
  final String? dateLabel;

  /// REAL CONTENT for the grid, in order. Empty keeps the flat placeholders.
  ///
  /// ─── WIDGETS, NOT PACKAGE NAMES ─────────────────────────────────────────
  ///
  /// Taking a list of app entries here would drag the icon pipeline into a
  /// widget whose entire job is drawing rectangles: `AppIcon` is a
  /// `ConsumerWidget`, so this file would gain a Riverpod import, and it is
  /// drawn inside settings rows, chooser tiles and a value chip at thumbnail
  /// size. Six icon lookups behind a 24px chip is a lot of work for a picture.
  ///
  /// So the CALLER decides what a tile is and this decides where it goes. The
  /// setup stage passes real `AppIcon`s; every existing caller passes nothing
  /// and gets exactly what it got before.
  ///
  /// SHORT LISTS ARE FINE. A grid asks for `across * down` tiles and takes
  /// what it is given, falling back to the placeholder for the rest, because a
  /// phone with four apps installed is a real phone and a grid that threw on
  /// it would be a crash during setup.
  final List<Widget> tiles;

  /// Real content for the DOCK, in order. Empty keeps the coloured pips.
  ///
  /// Separate from [tiles] because the two are different lists on a real
  /// phone: the dock is what you pinned and the grid is what you arranged, and
  /// a preview that drew the same four icons in both would be claiming a
  /// coincidence. The storefront passes the user's actual dock; every settings
  /// caller passes nothing and keeps the pips, which is right for a picture
  /// whose job is showing WHERE the dock is.
  final List<Widget> dockTiles;

  /// Drawn OVER the desktop canvas, inside the dock's remaining space.
  ///
  /// The setup widgets step uses it to show where the chosen desklets will
  /// land. It sits inside the canvas rather than over the whole preview so it
  /// cannot cover the dock or the top bar, which are the two things the
  /// neighbouring steps are asking about.
  ///
  /// Ignored by every mode except [DevicePreviewMode.desktop]: a drawer has no
  /// canvas to lay anything over.
  final Widget? overlay;

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
      DevicePreviewMode.drawer => _grid(cols, radius: 3),
      DevicePreviewMode.folder => _folder(),
      DevicePreviewMode.lock => _lock(),
    };

    // The gradient stays UNDER the wallpaper rather than being replaced by it.
    // A photo that has not decoded yet, or one whose file has gone, then shows
    // the distro's own colours for a frame instead of a white flash or a hole.
    final fill = BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [palette.bgTop, palette.bgBottom],
      ),
    );

    // A STACK, where this used to be `DecorationImage`. The decoration could
    // take a fit and an alignment but had nowhere to put the zoom, so honouring
    // framing through it would have silently dropped a quarter of the setting.
    // [WallpaperPaint] is the same code the framing screen draws with, which is
    // the only way the two can be guaranteed to agree.
    Widget layered(Widget child) => background == null
        ? child
        : Stack(
            fit: StackFit.expand,
            children: [
              WallpaperPaint(
                image: background,
                palette: palette,
                framing: backgroundFraming,
              ),
              child,
            ],
          );

    if (!framed) {
      return DecoratedBox(decoration: fill, child: layered(body));
    }

    // ─── THE SHAPE OF THIS PHONE, AND IT USED TO BE `10 / 17` ──────────────
    //
    // 0.588, hardcoded, against an S22's real 0.462. The frame was 27% wider
    // relative to its height than the device it was drawn on, and every framed
    // preview in Settings and setup inherited that.
    //
    // Harmless while a preview only had to say WHERE the dock is. Not harmless
    // since `WallpaperFraming.defaultFit` became `fill`, whose entire claim is
    // that the picture the settings page draws is the picture the phone draws.
    // A `fill` into a box of the wrong shape makes the preview the one place
    // the wallpaper is guaranteed to be wrong, which is the opposite of what
    // that fit was chosen for.
    //
    // ─── THE 10 / 15 IN setting_previews.dart IS DELIBERATELY NOT THIS ──────
    //
    // `PreviewChoice`'s tiles keep their own constant. They draw a LAYOUT with
    // no wallpaper, so nothing in them can stretch, and their aspect is a tile
    // budget rather than a claim about this device: four across at 360dp is
    // about 75dp each, and 0.462 would make each one 162dp tall and turn a
    // chooser row into a page.
    return AspectRatio(
      aspectRatio: previewAspectOf(context),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: fill.copyWith(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: palette.onDark.withValues(alpha: 0.16)),
        ),
        child: layered(body),
      ),
    );
  }

  Widget _desktop() {
    // ── THE CANVAS USED TO BE A Spacer, AND THAT WAS THE WHOLE DESKTOP ────
    //
    // A top bar and a dock, with nothing between them. At 150dp in a settings
    // row that is enough to tell three distros apart, which is all it was ever
    // asked to do. Drawn full width as the setup stage it is mostly empty
    // wallpaper with one strip of pips floating in it, and it reads as a
    // rendering failure rather than as a desktop.
    //
    // So the space between them is now the home page it is supposed to be:
    // `cols` across, `rows` deep, or as many rows as actually fit.
    //
    // PLACEHOLDERS, NOT REAL APPS, and deliberately even though [tiles] would
    // supply them. A home layout does not exist during setup and does not
    // exist at all until the user arranges one, so filling this with their
    // apps would be a picture of an arrangement nobody has made. The drawer is
    // the honest place for real apps, because a drawer IS every installed app.
    //
    // ─── UNLESS THE DISTRO TILES, IN WHICH CASE THERE IS NO GRID ──────────
    //
    // A tiling desktop has no icon field. Drawing one and calling it Pop!_OS
    // would be showing a desktop that distro cannot produce, which is the same
    // error the unconditional top bar made for seven of fifteen cards.
    final Widget body;
    if (homeLayout == 'tiled') {
      body = _tiled();
    } else if (!desktopIcons) {
      // The distro says no icons on the desktop. An empty canvas is the
      // correct picture, not a bug: wallpaper, panel, dock.
      body = const SizedBox.expand();
    } else {
      body = _grid(cols, radius: 3, maxDown: rows, placeholders: false);
    }

    final canvas = overlay == null
        ? body
        : Stack(fit: StackFit.expand, children: [body, overlay!]);

    // ── PANELS, WHICH USED TO BE ONE UNCONDITIONAL TOP STRIP ──────────────
    //
    // See [panels]. Empty is the settings case and draws exactly what this
    // method drew before: a scaled bar across the top.
    final top = <Widget>[];
    final bottom = <Widget>[];
    final ps = panels;
    if (ps == null) {
      top.add(_bar(null));
    } else {
      for (final p in ps) {
        switch (p.side) {
          case TopBarSide.top:
            top.add(_bar(p));
          case TopBarSide.bottom:
            bottom.add(_bar(p));
          // A vertical panel is a real thing in the vocabulary and nothing in
          // the catalogue ships one. Drawn as a horizontal strip on the near
          // edge rather than dropped, so a distro that starts using one is
          // visibly wrong rather than invisibly missing.
          case TopBarSide.left:
          case TopBarSide.right:
            top.add(_bar(p));
        }
      }
    }

    final strip = _DockStrip(
      palette: palette,
      // Both vertical sides. This read `== DockSide.left` and was correct
      // while left was the only one, which is the shape of nearly every site
      // the enum change is about to break.
      vertical: dock == DockSide.left || dock == DockSide.right,
      gridButton: gridButton,
      style: dockStyle,
      corner: iconCornerFraction,
      tiles: dockTiles,
    );

    return Column(
      children: [
        ...top,
        Expanded(
          child: switch (dock) {
            DockSide.left => Row(children: [strip, Expanded(child: canvas)]),
            DockSide.right => Row(children: [Expanded(child: canvas), strip]),
            DockSide.bottom =>
              // A FLOATING or MAGNIFIED dock sits OVER the canvas with a gap
              // beneath it; a flat one sits under it and takes its own row.
              // Laying the first two out in a Column would put the gap below
              // the dock rather than between the dock and the edge, which is
              // the one detail that tells Plank and Latte apart.
              dockStyle == 'flat'
                  ? Column(children: [Expanded(child: canvas), strip])
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        canvas,
                        Align(alignment: Alignment.bottomCenter, child: strip),
                      ],
                    ),
            // The authentic empty desktop: no dock at all. Still a desktop
            // though, so it keeps its grid.
            DockSide.off => canvas,
          },
        ),
        ...bottom,
      ],
    );
  }

  /// One panel: a coloured strip, with its modules drawn in it when it has any.
  ///
  /// ─── THE MODULES ARE SHAPES, NOT TEXT ───────────────────────────────────
  ///
  /// A clock reading 09:41 at 152dp is four illegible pixels, and this widget
  /// is also drawn at 26x40 in a settings value chip where it would be noise.
  /// So each module is the SILHOUETTE it has on a real panel: the launcher is
  /// an accent square, task buttons are wide slabs, the pager is a run of small
  /// squares, the tray is dots, the clock is a wide block.
  ///
  /// That is enough to tell a GNOME bar from a Plasma panel across a room,
  /// which is the entire job. Anything more legible would be a lie about how
  /// much of the panel this preview can honestly show.
  Widget _bar(PanelSpec? panel) {
    return LayoutBuilder(
      builder: (context, c) {
        // Scales with the rest of the furniture. A fixed 10px bar above a grid
        // that grew by a factor of three is the same mismatch the padding had.
        //
        // ── THE FLOOR WAS 1.0 AND THAT IS WHAT OVERFLOWED ──────────────────
        //
        // A floor above what the width can afford is the exact failure
        // `_folder` documents: it turns an unreadable preview into an
        // overflowing one. At 150dp and above this clamp never bound, so the
        // bug sat here until the storefront started drawing panels into 70dp
        // panes, where `s` should have been 0.47 and was forced to 1.0. Every
        // module was then laid out at the 150dp size inside a box a third that
        // wide, and a Plasma panel overflowed its Row by 29px.
        //
        // ZERO, matching `_folder` and `_grid`'s drawer arm. The module
        // geometry is proportional to `s` on both axes, so the whole panel
        // shrinks together and the large preview is untouched: above 150dp
        // this is identical to what it drew before.
        final s = (c.maxWidth / 150.0).clamp(0.0, 2.6);

        // ── THE AUTHORED HEIGHT IS A RATIO HERE, NOT A MEASUREMENT ────────
        //
        // `PanelSpec.height` is thickness in dp on a real phone. Using it
        // directly would put a 44dp Plasma panel into a 152dp-tall card, which
        // is a third of the picture, and at the 26x40 thumbnail size it would
        // be the whole thing. The preview is a miniature: every other number in
        // this file is derived from the run available, and this has to be too.
        //
        // So the base is the 10px bar this widget always drew, and an authored
        // height only nudges it against a nominal 36dp panel. A chunky Plasma
        // panel reads thicker than a thin GNOME bar, which is the part that is
        // true at this size, and neither can eat the desktop.
        final base = 10.0 * s;
        final authored = panel?.height;
        final height = authored == null
            ? base
            : base * (authored / 36.0).clamp(0.6, 1.8);

        final modules = panel?.modules ?? const <PanelModule>[];
        if (modules.isEmpty) {
          return Container(height: height, color: palette.bar);
        }

        final pad = 2.0 * s;
        final unit = (height - pad * 2).clamp(1.0, double.infinity);

        return Container(
          height: height,
          // CLIPPED, and only here. A module is a silhouette standing in for a
          // clock or a tray, so a panel that runs out of room and loses its
          // last shape is still an honest picture of a panel. The dock below is
          // deliberately NOT clipped: those are the user's real icons and one
          // quietly disappearing is a bug that should stay loud.
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(color: palette.bar),
          padding: EdgeInsets.symmetric(horizontal: pad * 1.5, vertical: pad),
          child: Row(
            children: [
              for (final m in modules) ..._module(m, unit, s),
            ],
          ),
        );
      },
    );
  }

  /// One module's silhouette, plus the gap after it.
  ///
  /// Returns a LIST so a spacer can contribute an [Expanded] rather than a box,
  /// which is the one module whose whole meaning is that it has no size.
  List<Widget> _module(PanelModule m, double unit, double s) {
    Widget block(double w, {Color? c, double? radius}) => Padding(
          padding: EdgeInsets.only(right: 2.0 * s),
          child: Container(
            width: w,
            height: unit,
            decoration: BoxDecoration(
              color: c ?? palette.onDark.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(radius ?? unit * 0.22),
            ),
          ),
        );

    return switch (m) {
      // Pushes everything after it to the far end. See [PanelModule.spacer].
      PanelModule.spacer => [const Spacer()],

      // The launcher, in the accent. On Plasma and Mint it is the leftmost
      // thing on the panel and the only coloured element, which is exactly how
      // it reads on a phone.
      PanelModule.kickoff => [block(unit, c: palette.accent)],
      PanelModule.activities => [block(unit, c: palette.accent)],

      // Running windows as labelled buttons. Wide, and there are several.
      PanelModule.tasks => [
          block(unit * 2.4),
          block(unit * 2.0),
        ],

      // Workspace squares: small, equal, and in a run.
      PanelModule.pager => [
          block(unit * 0.55, radius: 1 * s),
          block(unit * 0.55, radius: 1 * s),
          block(unit * 0.55, radius: 1 * s),
        ],

      // Status icons: round, and quieter than everything else.
      PanelModule.tray => [
          _dotModule(unit, s),
          _dotModule(unit, s),
        ],

      PanelModule.clock => [block(unit * 1.8)],

      // The three readouts. Narrow blocks, because a throughput figure and a
      // memory figure occupy the same slot shape on a real panel.
      PanelModule.network => [block(unit * 1.2)],
      PanelModule.memory => [block(unit * 1.2)],
      PanelModule.storage => [block(unit * 1.2)],
    };
  }

  Widget _dotModule(double unit, double s) => Padding(
        padding: EdgeInsets.only(right: 2.0 * s),
        child: Container(
          width: unit * 0.6,
          height: unit * 0.6,
          margin: EdgeInsets.symmetric(vertical: unit * 0.2),
          decoration: BoxDecoration(
            color: palette.onDark.withValues(alpha: 0.55),
            shape: BoxShape.circle,
          ),
        ),
      );

  /// A tiling desktop: windows filling the canvas with hairline gutters.
  ///
  /// Four of them in a 60/40 over 40/60 split, which is what a tiling WM
  /// produces on a phone-shaped screen after two splits and is the arrangement
  /// nothing else in this file draws. Deliberately NOT the app grid with
  /// smaller gaps: the point is that there is no icon field at all.
  Widget _tiled() {
    return LayoutBuilder(
      builder: (context, c) {
        final s = (c.maxWidth / 150.0).clamp(1.0, 2.0);
        final gap = 2.0 * s;
        final inset = 4.0 * s;

        Widget pane(int i) => DecoratedBox(
              decoration: BoxDecoration(
                color: palette.onDark.withValues(alpha: 0.07 + i * 0.02),
                border: Border.all(
                  color: palette.onDark.withValues(alpha: 0.34),
                  width: 0.8,
                ),
              ),
              // The focused pane wears the accent on its border, which is the
              // one piece of colour a tiling desktop has.
              child: i == 0
                  ? DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: palette.accent, width: 1.1),
                      ),
                    )
                  : null,
            );

        return Padding(
          padding: EdgeInsets.all(inset),
          child: Column(
            children: [
              Expanded(
                flex: 52,
                child: Row(
                  children: [
                    Expanded(flex: 60, child: pane(0)),
                    SizedBox(width: gap),
                    Expanded(flex: 40, child: pane(1)),
                  ],
                ),
              ),
              SizedBox(height: gap),
              Expanded(
                flex: 48,
                child: Row(
                  children: [
                    Expanded(flex: 40, child: pane(2)),
                    SizedBox(width: gap),
                    Expanded(flex: 60, child: pane(3)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// The lock screen: a clock, a date, and the wallpaper behind them.
  ///
  /// Scaled from the run like everything else here, because this widget is
  /// drawn at 150px in a settings preview and at 26px in a value chip, and
  /// fixed type sizes are the bug `_DockStrip` and `_folder` both already
  /// documented.
  Widget _lock() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final s = (constraints.maxWidth / 130).clamp(0.0, 1.0);
        final ink = palette.onDark;

        return Padding(
          padding: EdgeInsets.only(top: constraints.maxHeight * 0.16),
          child: Column(
            children: [
              Text(
                clockLabel ?? '',
                maxLines: 1,
                style: TextStyle(
                  color: ink,
                  fontSize: 26 * s,
                  fontWeight: FontWeight.w300,
                  height: 1.1,
                ),
              ),
              SizedBox(height: 3 * s),
              Text(
                dateLabel ?? '',
                maxLines: 1,
                style: TextStyle(
                  color: ink.withValues(alpha: 0.85),
                  fontSize: 8.5 * s,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// The app drawer's grid.
  ///
  /// ─── THE ROW COUNT IS DERIVED, AND IT USED TO BE THE CONSTANT 5 ─────────
  ///
  /// This was a `GridView.count` asking for five rows with 10px padding and
  /// 7px gaps, and every one of those numbers was authored against the 150dp
  /// framed thumbnail this widget started life as. A GridView.count makes
  /// SQUARE cells from the width alone, so at full stage width four columns
  /// produce cells roughly four times taller than they were, five of them are
  /// far taller than the box, and the grid is silently clipped part way
  /// through the third row. On the thumbnail it looked correct; on the stage it
  /// looked broken, and nothing in between reported anything.
  ///
  /// So the tile is sized by BOTH axes, exactly as [_folder] already is, and
  /// the row count falls out of what actually fits. That is also the honest
  /// picture: a drawer draws as many rows as the screen has room for, and a
  /// preview claiming five rows in a box with room for two was never showing
  /// the real thing anyway.
  ///
  /// ─── AND THE FURNITURE SCALES WITH IT ───────────────────────────────────
  ///
  /// Same fix and same reason as the folder sheet. Fixed padding inside a
  /// widget drawn at 150dp and at 400dp is furniture that stays put while its
  /// contents change by a factor of three, which is what made the icons read
  /// as edge to edge here: a 10px inset around a 95dp tile is not an inset.
  /// [maxDown] caps the derived row count. The DRAWER passes none, because a
  /// drawer is as long as it needs to be; the HOME canvas passes `rows`,
  /// because a home page has a fixed number and drawing a sixth would be
  /// showing a layout the shell will never produce.
  /// [placeholders] draws the flat slab for a cell [tiles] does not fill.
  ///
  /// ─── THE DESKTOP PASSES FALSE, AND THAT IS NOT A REGRESSION ─────────────
  ///
  /// A drawer with no content still has to look like a drawer, so its empty
  /// cells are drawn: at thumbnail size in a settings row the slabs ARE the
  /// picture. A home page is the opposite. It has no content during setup
  /// because no arrangement exists yet, so its slabs were fifteen translucent
  /// rectangles laid over the distro's wallpaper, and at stage size that reads
  /// as a rendering fault rather than as an empty desktop.
  ///
  /// An empty desktop is a real thing and looks like a wallpaper, a bar and a
  /// dock. That is what it draws now.
  Widget _grid(int across, {required double radius, int? maxDown, bool placeholders = true}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // The width the fixed numbers below were authored against, so at 150dp
        // and above the thumbnail stays pixel-identical to what it was.
        const reference = 150.0;
        // CAPPED AT 1.8, not 2.6. Scaling the furniture linearly with width
        // kept the thumbnail correct and made the stage wrong the other way:
        // at 360dp the 10px inset became 24 and the 7px gap became 17, so four
        // tiles sat in a field of padding and read as slabs rather than as a
        // grid. The tile is what should grow with the box; the space around it
        // grows more slowly, which is how every real grid on a phone behaves.
        final s = (constraints.maxWidth / reference).clamp(1.0, 1.8);

        final pad = 10.0 * s;
        final gap = 7.0 * s;

        final usable = constraints.maxWidth - pad * 2 - gap * (across - 1);
        if (across < 1 || usable <= 0 || !usable.isFinite) {
          return const SizedBox.expand();
        }
        final tile = usable / across;

        // How many WHOLE rows fit. A partial row is the clipping this method
        // exists to stop, so the last one that does not fit is simply not
        // drawn. Floor of one, because a box too short for a single row still
        // has to render something rather than an empty rectangle.
        final vertical = constraints.maxHeight - pad * 2;
        final fits = vertical.isFinite && tile > 0
            ? ((vertical + gap) / (tile + gap)).floor()
            : 4;
        final ceiling = maxDown ?? 8;
        final down = fits.clamp(1, ceiling < 1 ? 1 : ceiling);

        return Padding(
          padding: EdgeInsets.all(pad),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var r = 0; r < down; r++) ...[
                if (r > 0) SizedBox(height: gap),
                SizedBox(
                  height: tile,
                  child: Row(
                    children: [
                      for (var col = 0; col < across; col++) ...[
                        if (col > 0) SizedBox(width: gap),
                        SizedBox(
                          width: tile,
                          height: tile,
                          // The corner scales with the tile. A fixed 3px on a
                          // 30dp thumbnail tile is a soft corner; the same 3px
                          // on a 90dp stage tile is a square.
                          child: _cell(
                            r * across + col,
                            radius * s,
                            placeholders,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// One grid cell: a real tile when the caller supplied one, else the flat
  /// placeholder this preview has always drawn.
  ///
  /// No decoration behind a real tile. An icon already carries its own
  /// silhouette and plate, and a translucent square under every one of them
  /// reads as the whole grid being selected at once.
  Widget _cell(int i, double radius, bool placeholders) {
    if (i < tiles.length) return tiles[i];
    if (!placeholders) return const SizedBox.shrink();
    // INSET, at the same fraction a real icon takes of its cell. A placeholder
    // filling its cell edge to edge is denser than the thing it stands in for,
    // so a grid of them reads as a wall of slabs while the same grid of real
    // icons reads as apps. The two have to occupy the same share of the cell
    // or the preview changes shape the moment content arrives.
    return FractionallySizedBox(
      widthFactor: 0.78,
      heightFactor: 0.78,
      child: Container(
        decoration: BoxDecoration(
          color: palette.onDark.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(radius),
        ),
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
    this.style = 'flat',
    this.corner = 0.27,
    this.tiles = const <Widget>[],
  });

  final ThemePalette palette;
  final bool vertical;
  final String gridButton;

  /// 'flat' | 'floating' | 'magnified'. See [DevicePreview.dockStyle].
  final String style;

  /// Pip corner as a fraction of the pip. 0.27 is what this drew before the
  /// distro's own icon shape could reach it.
  final double corner;

  /// Real icons instead of pips. See [DevicePreview.dockTiles].
  final List<Widget> tiles;

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

        // ── EVERY TERM, IN THE ORDER THE BOX ACTUALLY EATS THEM ───────────
        //
        // This started as "the pip is fixed at 11px", became "the pip, the
        // padding and the margins all scale with the run", and was still wrong
        // in five more ways that only appeared once the storefront drew a dock
        // into a 70px pane. Every one of them was hidden by the 11.0 cap while
        // the run was 328px wide.
        //
        //  SLOTS      `size` divided by `count`, while the real-icon branch
        //             below lays out up to `count + 1`. Four icons sized for
        //             three.
        //  MAGNIFIER  `_swell` makes the middle slot 1.42x on a magnified
        //             dock, so the widest style in the catalogue was the one
        //             measured smallest.
        //  THE GAP    A floating strip is wrapped in `Padding(pad * 1.6)` at
        //             the bottom of this same builder.
        //  THE BORDER A Container's border IS padding: `BoxDecoration.padding`
        //             returns `border.dimensions`, so the floating hairline
        //             eats a pixel on each side before the Row is measured.
        //             This one is worth its own line because it is the least
        //             visible term here and it is exactly 2.0px, which is
        //             exactly what was left over after the other three.
        //  THE FLOORS Both the pip floor and the margin floor sat ABOVE what a
        //             narrow run can afford, which is the failure `_folder`
        //             documents: a floor above the affordable turns an
        //             unreadable preview into an overflowing one. Below about
        //             41px of run the margins ALONE exceeded the row, so no
        //             pip size could have fitted.
        //
        // The order below is the order the box consumes them, so each line
        // subtracts from what the previous one left rather than from the run.
        final pad = (run * 0.10).clamp(1.0, 4.0);

        final floating = style == 'floating' || style == 'magnified';

        // Named here and passed to `Border.all` below, so the measurement and
        // the border it measures cannot drift apart.
        const hairline = 1.0;

        // What is left after the floating gap and the hairline.
        final usable = run - (floating ? pad * 3.2 + hairline * 2 : 0.0);

        // What the Row itself is handed, which is the number the overflow
        // assert compares against.
        final rowRun = usable - pad * 2;

        final slots = tiles.isNotEmpty
            ? (tiles.length < count + 1 ? tiles.length : count + 1)
            : count;

        // A fraction rather than an int: the magnifier's extra 0.42 of a slot
        // is real width.
        final demand =
            slots + (style == 'magnified' && !vertical ? 0.42 : 0.0);

        // ── THE MARGIN IS CAPPED BY THE ROW, NOT ONLY BY THE RUN ──────────
        //
        // 5% of the run, as before, but never more than a quarter of the row
        // each, so the margins can never take more than half of it. Without
        // the cap a 20px run produced 8px of margins inside a 7.6px row, and
        // no pip size could recover that: the pips are what this shrinks, and
        // the thing overflowing was the furniture around them.
        final marginCap = rowRun / (slots * 4);
        final wanted = (run * 0.05).clamp(0.5, 2.0);
        final margin = wanted < marginCap ? wanted : marginCap;

        // ── HALF A PIXEL, HELD BACK ON PURPOSE ────────────────────────────
        //
        // With everything above counted this divides the space up EXACTLY, to
        // the last decimal. That is correct and it is one rounding away from
        // being wrong again, and the way it goes wrong is a striped banner
        // across a store card rather than anything a user can act on.
        //
        // Half a pixel is invisible here (it shortens a 7px pip by about a
        // tenth) and it is the difference between arithmetic that fits and
        // arithmetic that fits with nothing left over.
        const slack = 0.5;

        final size = run.isFinite
            ? ((rowRun - slots * margin * 2 - slack) / demand).clamp(0.5, 11.0)
            : 11.0;

        // ── REAL ICONS WHEN THE CALLER HAS THEM ────────────────────────────
        //
        // The storefront passes the user's own dock. Everything else passes
        // nothing and gets the pips, which is right for a picture whose job is
        // showing WHERE the dock is rather than what is in it.
        //
        // No app-grid pip in that case: it is an affordance for the SETTING
        // this strip was built to illustrate, and an accent square wedged into
        // a row of real icons on a store card reads as a fifth app.
        final children = <Widget>[];
        if (tiles.isNotEmpty) {
          for (var i = 0; i < tiles.length && i < count + 1; i++) {
            children.add(
              _slot(size, margin, i, tiles[i]),
            );
          }
        } else {
          final pins = [
            for (var i = 0; i < pinCount; i++)
              _pip(palette.onDark.withValues(alpha: 0.55), size, margin, i),
          ];

          // The app-grid button in the accent, so its position is unmistakable
          // at this size, which is the entire point of the setting it
          // illustrates.
          final grid = _pip(palette.accent, size, margin, -1);

          children.addAll([
            if (gridButton == 'start') grid,
            ...pins,
            if (gridButton == 'end') grid,
          ]);
        }

        // ── HOW THE DOCK MEETS THE EDGE ────────────────────────────────────
        //
        // Flat is glued to it and square where they meet: Ubuntu's rail, and
        // elementary's Plank. Floating clears the edge and rounds every corner,
        // which is the entire visible difference between Plank and a Latte
        // dock. Magnified floats too, and swells the middle icon, which is the
        // one recognisable thing about that desktop and survives at thumbnail
        // size where a colour does not.
        final strip = Container(
          decoration: BoxDecoration(
            color: palette.dock,
            borderRadius: floating
                ? BorderRadius.circular(size * 0.55)
                : BorderRadius.zero,
            border: floating
                ? Border.all(
                    color: palette.onDark.withValues(alpha: 0.16),
                    // Explicit, and it is the default. See `hairline` above:
                    // this width is subtracted from the run before the pips are
                    // sized, so it has to be stated rather than assumed.
                    width: hairline,
                  )
                : null,
          ),
          padding: EdgeInsets.all(pad),
          child: vertical
              ? Column(mainAxisSize: MainAxisSize.min, children: children)
              // BOTTOM-ALIGNED, matching the real dock: a swollen icon grows
              // upward while its feet stay on the line. Centring them would
              // make a magnified dock a plain strip with one big square in it.
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: children,
                ),
        );

        if (!floating) return strip;

        return Padding(
          padding: EdgeInsets.all(pad * 1.6),
          child: strip,
        );
      },
    );
  }

  /// The magnification factor for slot [i], or 1.
  ///
  /// Only the middle one, only on a magnified dock, and only when the dock is
  /// horizontal: a vertical rail does not magnify in any desktop that ships
  /// one. `-1` is the app-grid pip, which never swells because it is not an
  /// app.
  double _swell(int i, int count) {
    if (style != 'magnified' || vertical || i < 0) return 1;
    return i == count ~/ 2 ? 1.42 : 1;
  }

  Widget _pip(Color c, double size, double margin, int i) {
    final z = size * _swell(i, 3);
    return Container(
      width: z,
      height: z,
      margin: EdgeInsets.all(margin),
      decoration: BoxDecoration(
        color: c,
        // Scaled with the pip: a fixed 3px radius on a 2px pip is a circle
        // and on an 11px one is a rounded square, so the shape would change
        // meaning between the two sizes this widget is used at. The FRACTION
        // is the distro's own icon shape now rather than a hardcoded 0.27.
        borderRadius: BorderRadius.circular(z * corner),
      ),
    );
  }

  /// A real icon in a dock slot, sized and magnified like a pip would be.
  ///
  /// The icon draws itself, including its own plate and corner, so nothing here
  /// masks it: a square behind an `AppIcon` reads as the slot being selected.
  Widget _slot(double size, double margin, int i, Widget child) {
    final z = size * _swell(i, tiles.length);
    return Container(
      width: z,
      height: z,
      margin: EdgeInsets.all(margin),
      child: FittedBox(fit: BoxFit.contain, child: child),
    );
  }
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
