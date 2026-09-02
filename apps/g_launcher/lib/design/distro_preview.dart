/// PHASE 3: a real picture of a distro, from its own resolved theme.
///
/// ─── AN ADAPTER, NOT A SECOND RENDERER ──────────────────────────────────────
///
/// Nothing here draws. Every pixel is [DevicePreview], which is the same widget
/// setup, Settings and the folders screen already use, and the only reason this
/// file exists is that the storefront speaks [EffectiveTheme] while that widget
/// speaks primitives.
///
/// The alternative was a preview widget of its own, and the storefront has been
/// living with the consequence of that choice: `ThemePreview` in
/// `themes_screen.dart` is a second renderer with twelve hand-drawn layout arms,
/// and it drew seven of fifteen distros with a top bar they do not have, four
/// with a dock they do not have, and every CDN pack as a flat rectangle. Two
/// renderers means the one nobody is looking at is wrong.
///
/// So the mapping lives here and the drawing lives there. A field added to
/// `EffectiveTheme` becomes one line in [_previewOf] rather than a new arm in a
/// parallel painter.
///
/// ─── WHAT A PREVIEW HONESTLY CONTAINS ───────────────────────────────────────
///
/// Wallpaper, panels, dock, icons. That is the whole list, and the omission
/// worth naming is DESKLETS: clocks, stat panes, terminals. They are not in
/// `EffectiveTheme` at all, because they live in `LauncherPrefs` as things the
/// user placed. Phase 2 resolves a peeked theme with neutral prefs on purpose,
/// so a peeked distro has none, and inventing some here would be drawing an
/// arrangement nobody has made and then charging for it.
///
/// ─── AND THE WALLPAPER IS THE USER'S ────────────────────────────────────────
///
/// See [PeekedTheme.assetsOnDisk]. A peek fetches `theme.json` and nothing
/// else, so an uninstalled pack's wallpaper is not on the device; its spec
/// still NAMES one. So [background] is passed in by the caller, which passes
/// the wallpaper the phone already has.
///
/// A peeked spec now carries `ThemeSource.remote`, so asking it for that
/// wallpaper reports `existsSync` false rather than handing back an
/// `AssetImage` for a file that does not exist. That is a floor, not a
/// licence: the flag is still the thing to read, because a source that
/// refuses to resolve gives a renderer nothing to draw either.
///
/// That is also the better picture. A card shows this distro's chrome over the
/// background the user is actually looking at, which is what they would get.
library;

import 'package:flutter/widgets.dart';

import '../engine/effective_theme.dart';
import '../engine/theme_spec.dart';
import '../engine/wallpaper_framing.dart';
import '../features/themes/theme_peek.dart';
// `launcher_api`, NOT `pack_api`. `IconStyle` and `IconTreatment` are the
// launcher bridge's types, which is where `theme_spec.dart` imports them from
// under the same prefix. Two generated files, similar names, and only one of
// them defines these.
import '../platform/launcher_api.g.dart' as api;
import 'device_preview.dart';

/// One picture of one distro.
class DistroPreview extends StatelessWidget {
  const DistroPreview({
    super.key,
    required this.peeked,
    this.mode = DevicePreviewMode.desktop,
    this.background,
    this.backgroundFraming = const WallpaperFraming(),
    this.tiles = const <Widget>[],
    this.dockTiles = const <Widget>[],
    this.framed = false,
  });

  /// The resolved distro. See [PeekedTheme].
  final PeekedTheme peeked;

  final DevicePreviewMode mode;

  /// The wallpaper to draw behind it. The caller's, not the pack's.
  final ImageProvider? background;

  /// How that wallpaper meets the preview.
  ///
  /// Passed through rather than defaulted here, because a wallpaper the user
  /// has deliberately pushed off centre must not be re-centred by a store card:
  /// that is the same bug `DevicePreview.backgroundFraming` was added for, and
  /// this is the newest caller most likely to reintroduce it.
  final WallpaperFraming backgroundFraming;

  /// Real app icons for the drawer grid. Empty draws the placeholder slabs,
  /// which is the right picture on a card too small to read a label.
  final List<Widget> tiles;

  /// Real app icons for the dock.
  final List<Widget> dockTiles;

  /// A bordered phone.
  ///
  /// ─── FALSE USED TO BE THE STOREFRONT'S ANSWER, AND IT WAS RIGHT THEN ──────
  ///
  /// The argument was that a card IS the picture, so a phone drawn inside a
  /// card is a picture of a phone. That holds exactly as long as the card's
  /// box is the shape of a phone, and a full-width band 328 x 152 is not: it
  /// is 2.16 against a device's 0.462. Under `framed: false` the preview simply
  /// filled that box, so the chrome was laid out against it too, and a GNOME
  /// dock that runs nearly the full height of a phone became a stubby strip
  /// across two fifths of a landscape band.
  ///
  /// The storefront now passes TRUE and sizes the pane itself. The old
  /// reasoning survives everywhere it was actually true: `DeviceStage` in setup
  /// is full bleed over the real screen and still passes false, because there
  /// the preview genuinely is the picture.
  final bool framed;

  @override
  Widget build(BuildContext context) {
    final t = peeked.effective;

    return DevicePreview(
      palette: t.palette,
      mode: mode,
      framed: framed,
      background: background,
      backgroundFraming: backgroundFraming,

      // ── LAYOUT, ALL RESOLVED ──────────────────────────────────────────────
      //
      // Every one of these is read off `EffectiveTheme` and never off
      // `ThemeSpec`. That is the rule the whole engine is built on and it is
      // not a formality here: `LayoutResolver` is where a distro's authored
      // default meets the engine's fallback, and a preview reading the spec
      // would show a different desktop from the one the shell would draw for
      // any field the distro left unset.
      dock: t.dock,
      dockStyle: t.dockStyle,
      panels: _panelsFor(t),
      homeLayout: t.homeLayout,
      desktopIcons: t.desktopIcons,
      cols: _colsFor(t),
      rows: _rowsFor(t),
      iconCornerFraction: _cornerOf(t),

      // ── THE FOLDER'S TILES TAKE THE DISTRO'S SHAPE TOO ────────────────────
      //
      // `DevicePreview._folder` draws its tiles from `tileRadiusFraction`,
      // which is a separate parameter from `iconCornerFraction` because the
      // settings previews drive the two from different rows. This adapter has
      // one answer for both: they are the same fact about the distro, and a
      // folder pane previewing a circle-icon distro with squircle tiles would
      // be wrong in the one mode that exists to show icon shape.
      tileRadiusFraction: _cornerOf(t),

      // ── CONTENT ───────────────────────────────────────────────────────────
      //
      // The DRAWER gets the user's real apps, because a drawer is every
      // installed app and that is true on any distro. The home canvas does not:
      // see the note in `DevicePreview._desktop`, a home arrangement is
      // something the user makes and this user has not made one for a distro
      // they do not own.
      tiles: mode == DevicePreviewMode.desktop ? const <Widget>[] : tiles,
      dockTiles: dockTiles,

      // The app-grid pip is an affordance for the SETTING that strip was built
      // to illustrate. On a store card it would read as a fifth app, so it is
      // off whenever real icons are present and `_DockStrip` ignores it anyway
      // in that case. Stated here too, because relying on the other end to
      // ignore a value is how a value comes back.
      gridButton: dockTiles.isEmpty ? 'end' : 'off',
    );
  }

  /// The panels to draw, or none.
  ///
  /// ─── A DOCK IS NOT A PANEL, AND ONE DISTRO PROVED IT ────────────────────
  ///
  /// `EffectiveTheme.panels` is the authored list when the distro wrote one and
  /// a synthesised list when it did not, which is exactly what a preview wants:
  /// every distro answers, and the ones that opted in answer in detail.
  ///
  /// The one thing it must not do is invent a panel for a distro with none. A
  /// tiling desktop with a bar it does not have is the same error the old
  /// `ThemePreview` made on seven cards, and `LayoutResolver` already answers
  /// this correctly with an empty list.
  ///
  /// EMPTY MEANS NO PANEL, and `DevicePreview.panels` is nullable precisely so
  /// that meaning is available: null is "no opinion, draw the settings strip",
  /// which is what every other caller wants and what this must never send.
  ///
  /// `topBar` is the resolved boolean that separates "no panel" from "a panel
  /// with nothing authored in it", and both are real: three distros have no bar
  /// at all, and several have one whose modules predate the panel vocabulary.
  List<PanelSpec> _panelsFor(EffectiveTheme t) {
    if (t.panels.isNotEmpty) return t.panels;
    if (!t.topBar) return const <PanelSpec>[];

    // A bar with nothing authored in it. `DevicePreview` draws a plain strip
    // for an empty module list, on the resolved side, which is what this distro
    // actually has.
    return [
      PanelSpec(
        side: t.panelSide,
        modules: const <PanelModule>[],
        height: t.panelHeight,
      ),
    ];
  }

  /// ─── ONE cols FIELD, THREE MODES THAT MEAN DIFFERENT THINGS BY IT ─────────
  ///
  /// [DevicePreview] takes a single `cols`/`rows` pair and each mode reads it
  /// as its own grid: the desktop as the home grid, the drawer as the drawer's
  /// column count, the folder as the folder's.
  ///
  /// This adapter used to hand all three the DESKTOP grid, which was invisible
  /// while the storefront only ever drew the desktop. The card draws all three
  /// now, so a distro with a five-column home grid would have previewed a
  /// five-column folder that no folder on this device has.
  ///
  /// The folder arm reads PREFS rather than the resolved theme, because that is
  /// where folder dimensions live and there is no `EffectiveTheme.folderCols`
  /// to read instead. A peeked distro resolves with neutral prefs, so this is
  /// null there and lands on 4 x 3, which is exactly what a folder on this
  /// phone would be for a distro that has never been applied. The same `?? 4`
  /// and `?? 3` `icon_appearance_rows` uses, so the preview and the setting
  /// cannot disagree.
  int _colsFor(EffectiveTheme t) => switch (mode) {
        DevicePreviewMode.drawer => t.drawerCols,
        DevicePreviewMode.folder => t.prefs.folderCols ?? 4,
        DevicePreviewMode.desktop || DevicePreviewMode.lock => t.cols,
      };

  int _rowsFor(EffectiveTheme t) => switch (mode) {
        DevicePreviewMode.folder => t.prefs.folderRows ?? 3,
        DevicePreviewMode.drawer ||
        DevicePreviewMode.desktop ||
        DevicePreviewMode.lock =>
          t.rows,
      };

  /// The distro's icon corner, as a fraction of the icon box.
  ///
  /// ─── DERIVED FROM THE SHAPE, NOT FROM A NUMBER ──────────────────────────
  ///
  /// `IconStyle` carries the treatment the icon pipeline renders with, and the
  /// dock pips in a preview are drawn by Flutter rather than by that pipeline,
  /// so the two have to agree by construction or a circle-icon distro previews
  /// as squircles.
  ///
  /// Reads the RESOLVED style, so a distro's own shape shows even though this
  /// preview resolves with neutral prefs: neutral means the user has not
  /// overridden it, which is the whole point.
  ///
  /// `roundedSquare` and `original` defer to the authored `cornerRadius`, which
  /// is already a fraction of the box and is the field a theme.json sets when
  /// it wants a specific softness. The named shapes do not, because a distro
  /// asking for circles and also carrying a leftover 0.22 should get circles.
  ///
  /// EXHAUSTIVE, with no default arm. `IconTreatment` is a Pigeon enum shared
  /// with native, and a `_ =>` here would let a seventh value ship drawing
  /// squircles with nothing failing to say so. This is the same treatment
  /// `ChromeFamily` documents for itself.
  double _cornerOf(EffectiveTheme t) => switch (t.icons.treatment) {
        api.IconTreatment.circle => 0.5,
        api.IconTreatment.square => 0.02,
        api.IconTreatment.squircle => 0.28,
        api.IconTreatment.teardrop => 0.34,
        api.IconTreatment.roundedSquare => t.icons.cornerRadius,
        api.IconTreatment.original => t.icons.cornerRadius,
      };
}
