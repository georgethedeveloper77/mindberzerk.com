/// PHASE 4b: the storefront's picture, with the user's own wallpaper and dock.
///
/// ─── ONE WIDGET, BECAUSE THE CARD AND THE PAGE MUST NOT DIVERGE ─────────────
///
/// The card and the detail hero both need the same four things: the peeked
/// theme, the wallpaper currently on this phone, the apps in this phone's dock,
/// and the fallback for when the peek has not landed. Two copies of that would
/// drift, and the way it would drift is invisible: a card and the page it opens
/// showing subtly different pictures of the same distro.
///
/// They now differ in exactly one value, [modes], and that difference is the
/// only one there is: the card shows three panes and the page shows the one its
/// strip has selected. Everything else is resolved here, once, for both.
///
/// ─── IT RESOLVES ONCE AND DRAWS N TIMES ─────────────────────────────────────
///
/// Three panes on a card is not three previews' worth of work. The peek is one
/// provider watch, the wallpaper and its framing are computed once, and the
/// dock icons are one list of widgets handed to each pane. Building three
/// `StorePreview`s instead would have been three watches of the same family key
/// and three copies of the framing resolution for one identical answer.
///
/// ─── THIS FILE ARRANGES NOTHING ─────────────────────────────────────────────
///
/// Sizing the panes, laying them out and staggering them in belongs to
/// [PreviewStrip], which has no Riverpod import and no idea what a distro is.
/// The same split `DistroPreview` and `DevicePreview` already have: one file
/// knows the domain, the other knows the pixels.
///
/// ─── THE WALLPAPER IS THE USER'S, AND IT COMES FROM THE ACTIVE THEME ────────
///
/// Not the peeked one. A peek fetches `theme.json` and nothing else, so an
/// unowned pack's wallpaper is not on the device; the spec still NAMES one, and
/// nothing on this phone backs the name. See [PeekedTheme.assetsOnDisk].
///
/// Drawing the user's own is also the better picture rather than a consolation:
/// a card should show this distro's chrome over the background this phone
/// actually has, because that is what buying it would look like.
///
/// [wallpaperImageFor] and [previewWallpaperFor] are reused from the wallpaper
/// screen rather than reimplemented. They already know the three kinds of
/// string `wallpaperCurrent` can hold and which of them resolve through a pack
/// directory, and a second answer to that question is how this app previously
/// ended up with a downloaded distro that appeared to have no wallpaper.
///
/// ─── THE FRAMING IS PASSED THROUGH, AND IT IS NOW SAFE TO ───────────────────
///
/// This resolves the user's real framing and hands it down, which is what a
/// preview of their phone has to do. It is also what produced the stretch: the
/// default fit is `fill`, the band was 2.16 and the device is 0.462, and `fill`
/// did exactly what it promises.
///
/// Two things changed and BOTH matter. The panes are now the device's shape, so
/// `fill` means here what it means on the phone. And `WallpaperPaint` refuses a
/// `fill` in a box that is materially the wrong shape regardless, so the next
/// caller to put a preview in a mural cannot reintroduce it silently.
///
/// ─── AND THE ICONS ARE THE USER'S TOO, WHICH IS NOT A COMPROMISE ────────────
///
/// [AppIcon] renders in the ACTIVE theme's style: it keys on
/// `effectiveThemeProvider.iconCacheId`, and `setIconTheme` pushes ONE style to
/// native at a time. So a preview cannot draw the previewed distro's icon shape
/// without a per-request style on the bridge, which would fight the live
/// desktop for the same cache.
///
/// That constraint happens to land on the right answer. A distro's artwork is a
/// separate SKU, so previewing it would advertise something the distro purchase
/// does not include. The free tier is what a buyer gets, and the free tier is
/// exactly what their phone is already showing.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/shell_apps.dart';
import '../../design/device_preview.dart';
import '../../design/distro_preview.dart';
import '../../engine/effective_theme.dart';
import '../../engine/wallpaper_framing.dart';
import '../drawer/app_icon.dart';
import '../settings/wallpaper_screen.dart';
import 'preview_strip.dart';
import 'theme_catalog.dart';
import 'theme_peek.dart';

/// What a storefront CARD shows: three views of one distro.
///
/// ─── DESKTOP, DRAWER, FOLDER, AND lock IS NOT AN OVERSIGHT ──────────────────
///
/// These are the three [DevicePreviewMode]s that differ per distro. The desktop
/// carries the panel and the dock, the drawer carries the grid and its column
/// count, and the folder is the only one that draws `tileRadiusFraction` at a
/// size where a circle and a square are distinguishable.
///
/// `lock` is excluded on its own authority: its docblock says it deliberately
/// carries no launcher chrome, because Android draws the real thing. It would
/// be the identical picture on every card in the catalogue, which is the
/// opposite of what a third pane is for.
///
/// The same order as the detail page's mode strip, so the third pane on a card
/// and the third tab on the page it opens are the same view.
const kStoreCardModes = <DevicePreviewMode>[
  DevicePreviewMode.desktop,
  DevicePreviewMode.drawer,
  DevicePreviewMode.folder,
];

/// How big an app icon is asked for inside a preview.
///
/// ─── SMALL ON PURPOSE ───────────────────────────────────────────────────────
///
/// `AppIcon` requests a bitmap of `size * devicePixelRatio` and native caches
/// per pixel size, so every distinct size is another entry in a cache the
/// drawer and the dock are already filling. A dock slot in one of these panes
/// is well under 20dp, and `_DockStrip` fits whatever it is given into the
/// slot, so asking for the drawer's size would spend memory on detail nothing
/// can show.
///
/// One size for both the card and the hero, deliberately, and it is now
/// slightly generous for the card and slightly mean for the hero. Two sizes
/// would double the cache entries to make the larger picture very slightly
/// crisper, which is the same trade this constant was created to refuse.
const double _previewIconSize = 28;

/// The storefront's picture of one distro.
class StorePreview extends ConsumerWidget {
  const StorePreview({
    super.key,
    required this.card,
    required this.fallback,
    this.modes = kStoreCardModes,
  });

  final ThemeCard card;

  /// What to draw when the peek has not answered.
  ///
  /// ─── PASSED IN RATHER THAN BUILT HERE ─────────────────────────────────────
  ///
  /// `ThemePreview` lives in `themes_screen.dart`, which is one of this file's
  /// two callers, so constructing it here would make the two files import each
  /// other. Dart permits that and this codebase already carries one deliberate
  /// cycle, but a cycle earns its keep when the alternative is duplicating a
  /// rule, and here the alternative is one parameter.
  final Widget fallback;

  /// Which views to draw, in order. One for the detail hero, three for a card.
  ///
  /// A LIST rather than a count, because the detail page needs to say WHICH
  /// one: its mode strip selects a single view and passes it here, so a count
  /// would have to be paired with an index and the two could disagree.
  final List<DevicePreviewMode> modes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `.value`, not `asData`, for the reason the whole storefront now reads
    // things this way: a family re-resolving must not blank the picture it is
    // about to replace. The VERSION is in the key, so a republished distro is a
    // different provider and the preview follows the catalogue by itself.
    final peeked = ref
        .watch(
          peekedThemeProvider(
            (packId: card.packIdOrSpec, version: card.remoteVersion),
          ),
        )
        .value;

    if (peeked == null) return fallback;

    // The ACTIVE theme, which is what owns the wallpaper and the dock. Null
    // only before the first resolve, which on this screen has already happened,
    // and the preview simply draws the distro's own gradient until it has.
    final active = ref.watch(effectiveThemeProvider).value;

    ImageProvider? wallpaper;
    var framing = const WallpaperFraming();
    var dockTiles = const <Widget>[];

    if (active != null) {
      final source = previewWallpaperFor(active);
      wallpaper = wallpaperImageFor(active, source);
      if (source != null) {
        framing = resolveWallpaperFraming(
          user: active.prefs.wallpaperFraming,
          authored: active.spec.wallpaperMeta,
          source: source,
          legacyFit: active.prefs.wallpaperFit,
        );
      }

      // The ACTIVE theme, again, and not the peeked one. A dock is the apps
      // this person pinned; it does not change because they are looking at a
      // different distro, and `shellAppsProvider` filters by the prefs of the
      // theme it is handed, which for a peeked theme are the neutral defaults
      // this preview resolves with.
      //
      // BUILT ONCE for all three panes. The same widget object appearing in
      // three places in the tree is fine: a widget is a configuration, not an
      // instance, and `AppIcon` holds no GlobalKey.
      dockTiles = [
        for (final entry in ref.watch(dockEntriesProvider(active)))
          AppIcon(
            entry: entry,
            size: _previewIconSize,
            // No unread counts on a store card. A badge is a notification about
            // the user's life appearing on a picture of a product, and at this
            // size it is a coloured dot with no explanation.
            showBadge: false,
          ),
      ];
    }

    // ─── THE KEY IS WHAT MAKES THE ANIMATION PLAY ONCE ──────────────────────
    //
    // [PreviewStrip] staggers its panes in from the first frame of its own
    // State. Without a stable key that State would be recreated on any rebuild
    // that changed this subtree's shape, and this widget rebuilds on every
    // catalogue invalidate and on every download progress tick. Three panes
    // re-fading each time a percentage ticks over, on every card on screen, is
    // the failure that key prevents.
    //
    // It is keyed on the VERSION as well as the pack, so a republished distro
    // is a different key and does restage, which is the one time replaying is
    // the right answer.
    return KeyedSubtree(
      key: ValueKey<String>('${card.packIdOrSpec}:${card.remoteVersion}'),
      child: PreviewStrip(
        // The PEEKED palette. The panes are a picture of this distro and the
        // space around them should be the same distro, not the one being worn.
        palette: peeked.effective.palette,
        panes: [
          for (final mode in modes)
            DistroPreview(
              peeked: peeked,
              mode: mode,
              // TRUE, and it used to be false. See the docblock on
              // `DistroPreview.framed`: a card being the picture was the right
              // call while the picture filled the card, and a pane inside a
              // band is not that.
              framed: true,
              background: wallpaper,
              backgroundFraming: framing,
              dockTiles: dockTiles,
              // `DistroPreview` decides which modes get real tiles. Passing the
              // list unconditionally and letting it gate keeps that rule in one
              // file rather than asserting it in two.
              tiles: dockTiles,
            ),
        ],
      ),
    );
  }
}
