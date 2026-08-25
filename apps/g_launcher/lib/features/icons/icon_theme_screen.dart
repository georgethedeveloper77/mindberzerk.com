import 'dart:io' show File;
// `Uint8List`, for the storefront preview bitmaps. `launcher_api.g.dart` uses
// it too but does not re-export it.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/billing/entitlements.dart';
import '../../data/cdn/pack_repository.dart';
import '../../data/prefs/prefs_repository.dart';
import '../../data/repositories/app_repository.dart';
import '../../design/branded_message.dart';
import '../../design/components/components.dart';
import '../../engine/effective_theme.dart';
import '../../platform/launcher_api.g.dart';
import '../../platform/pack_api.g.dart';
import '../drawer/app_icon.dart';
import 'icon_appearance_rows.dart';
import '../themes/theme_catalog.dart' show CardStatus;

/// One native handle for the preview lookup, mirroring theme_engine's rule:
/// a new Pigeon wrapper per card is a new codec instance for no reason.
final _previewApi = PackHostApi();

/// Where a pack's preview.png can be drawn from, or null for the schematic.
///
/// Watches the catalogue so the URL flips from the CDN copy to the installed
/// `file://` copy the moment an install lands, without any card doing its own
/// bookkeeping. Any channel failure is "no preview", never an error: a store
/// card must render something regardless of what the bridge is doing.
final packPreviewUrlProvider =
    FutureProvider.family<String?, String>((ref, packId) async {
  ref.watch(catalogueProvider);
  try {
    return await _previewApi.packPreviewUrl(packId);
  } catch (_) {
    return null;
  }
});

/// ICON THEMES — the distros screen's sibling.
///
/// In Linux an icon set is an ICON THEME (`/usr/share/icons`,
/// `gtk-icon-theme-name`), which is what Yaru, Breeze, Papirus and Numix all
/// call themselves. Keeping that word costs nothing and is accurate: a distro
/// and an icon theme genuinely are different objects, and mixing them is the
/// whole point of this screen.
///
/// ─── TWO SOURCES, TWO SELECTIONS, AND THEY LAYER ────────────────────────────
///
/// This is the thing to understand before changing anything here. There are two
/// prefs and they are NOT alternatives:
///
///   prefs.iconPackId      OURS. A `hero` pack that arrived over the CDN,
///                         signed, sometimes sold. Feeds `IconStyle.heroPack`
///                         in `EffectiveTheme.resolve` and is rendered by the
///                         native icon pipeline.
///   prefs.systemIconPack  THEIRS. A Nova/ADW-format APK installed from Play,
///                         including anything exported from Icon Pack Studio.
///                         Pushed separately by `setIconPack` and read by
///                         `IconPackApps`. Never part of `IconStyle`.
///
/// Native layers the third-party pack ABOVE hero: a Nova pack covers the apps
/// it has art for, the distro's hero art fills the rest, the CC0 brand glyphs
/// fill the rest of that, and the generator catches everything left. So both
/// can be set, `LauncherPrefs.systemIconPack` says so explicitly, and the first
/// draft of this screen got it wrong by making them mutually exclusive.
///
/// Hence two grids, two independent choices, and a line of copy explaining the
/// layering — because a user with both set and no explanation will reasonably
/// conclude one of them is broken.
///
/// ─── WHY `simple-icons` NEVER APPEARS HERE, AND WHY THE LINE PACKS DO ───────
///
/// `simple-icons` is a `brand` pack: the CC0 glyph layer underneath everything,
/// not a set anyone chooses. Excluding it was right.
///
/// The filter did it by TYPE, though, and that comment predicted its own
/// failure: "so a second brand pack cannot leak in later". Fourteen of them
/// arrived. `kali-2024-line`, `ubuntu-24-04-line` and twelve more are `brand`
/// packs too, and unlike `simple-icons` every one of them is a named, priced
/// product a user is meant to choose. They were excluded by construction, which
/// is why the screen offered nothing to install and the packs were never
/// downloaded.
///
/// So the filter is now about ROLE, not type: a brand pack is shown when it is
/// SOLD, and hidden when it is plumbing. `simple-icons` and `arcticons-line`
/// carry no sku and stay invisible; the fourteen carry one and appear beside
/// the hero packs they layer under.
///
/// That test is also self-maintaining in the direction the old one failed: a
/// future plumbing pack is hidden for the same reason `simple-icons` is,
/// without anyone remembering to add it to a list.
///
/// ─── SUPERSEDES `features/settings/icon_pack_page.dart` ─────────────────────
///
/// That page handled `systemIconPack` only, as a one-column list, and NOTHING
/// EVER IMPORTED IT — it has never been reachable. Grep for `IconPackPage`
/// before deleting it.

/// Is this pack something the user is meant to CHOOSE, rather than plumbing?
///
/// ─── ROLE, NOT TYPE ─────────────────────────────────────────────────────────
///
/// Only asked of `brand` packs, and only because two very different things
/// share that type. `simple-icons` and `arcticons-line` are geometry every
/// other pack sits on: no colour of their own, nothing to pick, and listing
/// them puts a card on the shelf that changes nothing when tapped.
///
/// The fourteen official line packs are the same TYPE and the opposite ROLE.
/// Each is that distro's icon set in its own colour and each has a price.
///
/// A sku is what separates them, and it is the honest test rather than a
/// convenient one: a pack with a Play product is by definition something
/// someone can buy, so it must be visible somewhere to be bought. A pack
/// without one has no way to be acquired and therefore no reason to be on a
/// shelf.
///
/// An empty string counts as absent. `PackInfo.sku` is nullable and the index
/// omits the field entirely when free, but a hand-edited pack.json with
/// `"sku": ""` would otherwise appear as a purchasable product with no product
/// behind it, which is the Buy button that does nothing.
bool _isSold(PackInfo pack) => (pack.sku ?? '').isNotEmpty;

/// Third-party icon packs installed as APKs: package name -> label.
///
/// AN EMPTY MAP IS A REAL ANSWER and draws the empty state, never an error. Note
/// while debugging that empty is ALSO what a missing `<queries>` declaration
/// produces on Android 11+, silently, on a phone with forty packs installed.
/// Check the manifest before this file.
///
/// A FutureProvider rather than widget state so it survives a rebuild, and so
/// `ref.invalidate` is the whole of "refresh" when someone installs a pack and
/// comes back.
final installedIconThemesProvider =
    FutureProvider<Map<String, String>>((ref) {
  return ref.read(launcherHostApiProvider).installedIconPacks();
});

/// The installed APK behind a third-party pack, so its own launcher icon can be
/// the preview.
///
/// This is the one honest preview available for a third-party pack and it costs
/// nothing: those apps almost always put a sample of their art on their own
/// icon, and `AppIcon` already knows how to draw one. `componentKey` is
/// `package/class`, so the match is on the segment before the slash.
///
/// Null when the pack is not in the app list, which happens for a pack that has
/// no launcher activity. The card falls back to the schematic.
final iconThemeAppProvider =
    Provider.family<AppEntry?, String>((ref, packageName) {
  final apps = ref.watch(appListProvider).asData?.value ?? const <AppEntry>[];
  for (final a in apps) {
    if (a.componentKey.split('/').first == packageName) return a;
  }
  return null;
});

/// How many of this device's apps a pack actually draws, or null.
///
/// ─── THE ONLY MEASURED NUMBER ON THE SCREEN ─────────────────────────────────
///
/// Everything else a card can say comes from the index and is a claim about the
/// pack: a title, a price, 13,622 drawings. This is a claim about the phone in
/// the user's hand, and it is the difference between "13,622 icons" and "41 of
/// your 46 apps", which is the number they were actually asking about.
///
/// Watches [appListProvider] rather than caching against it, so installing or
/// removing an app re-asks. Native memoises on the app-list size, so that
/// re-ask is free unless the count genuinely moved.
///
/// Also watches [catalogueProvider], because an install is what turns a null
/// answer into a real one: nothing can be counted until the pack is on disk.
///
/// NULL IS A RESULT, not an error. The pack is not installed yet, or it is a
/// theme rather than an icon set, or its json would not parse. The row is
/// simply absent for all three, which is this app's rule for a nullable stat
/// and the honest reading here: a `0 of 46` would describe a pack that covers
/// nothing, which is a different and much worse thing than one that has not
/// been asked yet.
final packCoverageProvider =
    FutureProvider.family<PackCoverage?, String>((ref, packId) async {
  ref.watch(appListProvider);
  ref.watch(catalogueProvider);
  // Swallowed rather than surfaced. A missing caption costs nothing and the
  // card behind it is still correct and still tappable; an error state here
  // would put a retry button on a number nobody asked for.
  //
  // try/catch rather than `catchError`, which on a `Future<PackCoverage?>`
  // takes a `Function` and loses the return type: a handler returning the wrong
  // thing is a runtime cast failure inside the provider rather than a compile
  // error here.
  try {
    return await _previewApi.packCoverage(packId);
  } catch (_) {
    return null;
  }
});

/// Which other distro's colour is being previewed, by distro base id.
///
/// ─── PREVIEW IS NOT A SETTING ───────────────────────────────────────────────
///
/// Deliberately NOT in prefs. It lasts as long as the screen is open and dies
/// with it, because it describes a moment of shopping rather than a choice the
/// user made. Persisting it would mean reopening Icons and finding a distro you
/// do not own already tried on, which reads as something having changed.
///
/// Null means the running distro, which is what the try-on shows before any
/// swatch is tapped.
class _IconPreview extends Notifier<String?> {
  @override
  String? build() => null;

  /// Tapping the swatch already showing resets to the running distro, so the
  /// row is a toggle rather than a one-way trip.
  void set(String base) => state = state == base ? null : base;
}

final _iconPreviewProvider =
    NotifierProvider<_IconPreview, String?>(_IconPreview.new);

class IconThemeScreen extends ConsumerWidget {
  const IconThemeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeAsync = ref.watch(effectiveThemeProvider);

    return themeAsync.when(
      // The theme is resolved long before anything can navigate here, so these
      // are formalities. They render nothing rather than a spinner, because a
      // flash of unthemed chrome on the way into a settings page is worse than
      // a frame of nothing — the same call `themes_screen` makes.
      loading: () =>
          const ThemedScaffold(title: 'Icons', body: SizedBox.shrink()),
      error: (_, __) =>
          const ThemedScaffold(title: 'Icons', body: SizedBox.shrink()),
      data: (theme) => _Screen(theme: theme),
    );
  }
}

class _Screen extends ConsumerWidget {
  const _Screen({required this.theme});

  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // THE FETCH. Same gap the distros grid had: `catalogueProvider` is the
    // cached index and never hits the network, so a hero pack published five
    // minutes ago is invisible until something asks. Fired once per app run and
    // shared with the distros screen, so opening both does not fetch twice.
    ref.watch(catalogueRefreshProvider);

    // ── FILTERED HERE, NOT IN A DERIVED PROVIDER ────────────────────────────
    //
    // This was a `Provider<List<PackInfo>>` watching `catalogueProvider`, and it
    // CRASHED THE SCREEN on first open:
    //
    //   setState() or markNeedsBuild() called during build
    //   ... iconThemePacksProvider -> Ref.watch -> Ref._invalidateSelf
    //
    // A synchronous Provider that watches an ASYNC one gets mounted mid-build
    // the first time this screen opens, the catalogue emits during that same
    // flush, and the resulting `invalidateSelf` lands inside the build phase —
    // which Riverpod forbids. `themeCatalogProvider` avoids it by being a
    // FutureProvider awaiting `catalogueProvider.future`; a plain Provider has
    // no such escape.
    //
    // The filter is three lines and has no reason to be a provider at all. Doing
    // it here removes the mount and the whole class of ordering bug with it.
    final catalogue =
        ref.watch(catalogueProvider).asData?.value ?? const <PackInfo>[];
    final packs = [
      // Hero packs, plus brand packs that are SOLD. See the note at the top of
      // the file: type alone hid the fourteen official line packs, which are
      // brand packs and are also the product.
      for (final p in catalogue)
        if (p.packType == 'hero' || (p.packType == 'brand' && _isSold(p))) p,
    ]..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

    // ── grouped by distro, via the id prefix convention ────────────────────
    //
    // A hero pack belongs to the distro whose base id prefixes its own:
    // `kali-2024-icons` and `kali-2024-neon-icons` both belong to
    // `kali-2024-theme`. Derived from ids alone, deliberately: Dart can only
    // read the ACTIVE distro's theme.json, so every other distro is just a
    // theme pack in the catalogue, and its id is the one fact always present.
    // Longest base wins, so a distro named `ubuntu` could not claim
    // `ubuntu-24-04-icons` away from `ubuntu-24-04`.
    final distroTitles = <String, String>{};
    for (final p in catalogue) {
      if (p.packType != 'theme') continue;
      final base = p.packId.endsWith('-theme')
          ? p.packId.substring(0, p.packId.length - '-theme'.length)
          : p.packId;
      distroTitles[base] = p.title.isEmpty ? base : p.title;
    }
    final currentBase = theme.spec.id.endsWith('-theme')
        ? theme.spec.id.substring(0, theme.spec.id.length - '-theme'.length)
        : theme.spec.id;
    // The active distro may be bundled and never republished, so it can be
    // absent from the catalogue. It still owns its packs.
    distroTitles.putIfAbsent(currentBase, () => theme.spec.name);

    String? distroOf(String packId) {
      String? best;
      for (final base in distroTitles.keys) {
        if (packId.startsWith('$base-') &&
            (best == null || base.length > best.length)) {
          best = base;
        }
      }
      return best;
    }

    /// What the DISTRO itself asks for, in its own theme.json.
    ///
    /// ─── heroPack OR brandPack, AND IT ONLY EVER READ THE FIRST ─────────────
    ///
    /// Every distro now ships an official icon pack, named in `brandPack`, and
    /// none of them names a `heroPack` any more. So this resolved to null, the
    /// merge below never fired, and the shelf showed TWO cards: "Distro
    /// default" with nothing behind it, and beside it the distro's own pack
    /// offering to Get something the user already has by virtue of running that
    /// distro.
    ///
    /// `heroPack` still wins when a distro names one, because hand-drawn art is
    /// the more specific choice and layers above the line set.
    ///
    /// Read HERE rather than further down, because the partition below has to
    /// know it.
    ///
    /// ─── `theme.spec.icons`, NOT `theme.icons`, AND THAT IS THE WHOLE BUG ───
    ///
    /// This read `theme.icons`, which is the RESOLVED style, and resolve does:
    ///
    ///     heroPack: prefs.iconPackId ?? themeIcons.heroPack
    ///
    /// So the user's own selection arrives here wearing the distro's clothes.
    /// Tap EndeavourOS in the colour strip on an Ubuntu device and
    /// `endeavouros-line` becomes what this screen believes Ubuntu names: it is
    /// lifted out as `namedByDistro`, promoted to the wearing card, and handed
    /// the subtitle "Comes with Ubuntu". Every fact on that card was then
    /// wrong, and the only thing that had actually happened was a pack being
    /// chosen, which is the one thing the screen is for.
    ///
    /// The same line explains the emptier version of the fault. Select a pack
    /// that later leaves the catalogue — `kali-2024-icons` was deleted — and
    /// the id resolves to nothing, `namedByDistro` stays null, the card falls
    /// back to "Distro default", and the distro's real pack drops through to a
    /// shelf offering to Get what it comes with.
    ///
    /// `spec.icons` is what the theme.json AUTHORED, with no prefs folded in,
    /// which is the only thing that can answer "what does this distro ship".
    ///
    /// The `??` tail is `EffectiveTheme.resolve`'s own fallback, repeated here
    /// on purpose rather than shared: resolve applies it to build `IconStyle`,
    /// and if this screen did not apply the same one it would say a bundled
    /// distro names no pack while the drawer was busy rendering that pack's
    /// icons. Both call `defaultLinePackFor`, so there is one rule and two
    /// readers, not two rules.
    /// ─── AND A CANDIDATE IS ONLY REAL IF THE CATALOGUE HAS IT ───────────────
    ///
    /// Three candidates in specificity order, and the first one that EXISTS
    /// wins. Existence is the whole addition, and skipping it is what put two
    /// cards on an Ubuntu device: bundled Ubuntu's theme.json names a pack id
    /// that is no longer published, this resolved to that dead id, no pack in
    /// the catalogue matched it, and the wearing card fell all the way back to
    /// "Distro default" while `ubuntu-24-04-line` dropped through to the shelf
    /// underneath offering to Get the icons Ubuntu comes with.
    ///
    /// Two cards for one thing, and the second one charging for it.
    ///
    /// An unpublished id is not a preference to be honoured. A distro naming a
    /// pack nobody can install has not chosen that pack, it has a typo or a
    /// stale reference, and falling through to the id the whole system derives
    /// anyway is both correct and self-healing: delete a pack, rename one,
    /// republish a theme against an older tool, and the card still finds the
    /// distro's icons instead of announcing there are none.
    ///
    /// Null only when NOTHING exists, which is a device whose catalogue has not
    /// synced yet. That is the one case where "Distro default" is the truth.
    final specIcons = theme.spec.icons;
    final catalogueIds = {for (final p in packs) p.packId};
    // ─── THE BRAND TIER, AND ONLY THE BRAND TIER ──────────────────────────
    //
    // `specIcons.heroPack` used to lead this list, which put a hand-drawn pack
    // in the slot the colour strip is about. The two tiers are not ranked
    // against each other, they are STACKED: hero art on top for the forty apps
    // somebody drew, the line set underneath for the several hundred it does
    // not cover. A distro naming both is asking for both, not for the first
    // one this list happens to check.
    //
    // So this mirrors `EffectiveTheme.resolve`'s `brandPack` line exactly, and
    // hero packs live in the Standalone section with `selectedHero` marking
    // them. One rule, two readers.
    final String? distroPack = [
      specIcons.brandPack,
      defaultLinePackFor(theme.spec.id),
    ].firstWhere(
      (id) => id != null && id.isNotEmpty && catalogueIds.contains(id),
      orElse: () => null,
    );

    final byDistro = <String, List<PackInfo>>{};
    final standalone = <PackInfo>[];
    PackInfo? applied;

    // READ HERE, ABOVE THE PARTITION, because `appliedId` below needs it and
    // the partition is the first thing on this screen that has to know what
    // the user chose. It sat with `selectedSystem` further down, next to the
    // writes that use it, which was fine while nothing above cared.
    final selectedHero = theme.prefs.iconPackId;

    /// The colour the user chose, which is a DIFFERENT PREF from the one above.
    ///
    /// Choosing a colour used to write `iconPackId`, and `resolve` routes that
    /// to the hero tier, so a line pack was handed to `HeroIconResolver`, which
    /// cannot read one. Apply completed and nothing changed. See
    /// `LauncherPrefs.iconBrandPackId`.
    final selectedBrand = theme.prefs.iconBrandPackId;

    // ── WHAT IS ON THE PHONE, WHICH IS NOT THE SAME AS WHAT CAME WITH IT ────
    //
    // The card at the top used to be the pack the DISTRO names, and the pack
    // the USER applied had nowhere to appear. Apply Linux Mint on Kali and the
    // card kept saying "Kali Linux Icons, comes with Kali Linux" over a green
    // drawer: the biggest element on the screen describing something that was
    // not true of the device.
    //
    // A marker on the swatch was the first answer and it does not survive
    // contact with fourteen of them. The applied pack scrolls off the row, so
    // the one state worth seeing at a glance is the one you have to go hunting
    // for. The card is always on screen, so the card carries it.
    //
    // `selectedBrand` first because a choice outranks a default, then the
    // distro's own as the thing running when no choice was made.
    final appliedId = selectedBrand ?? distroPack;

    for (final p in packs) {
      // ── THE APPLIED PACK BELONGS TO NO SHELF ───────────────────────────
      //
      // It is drawn by the card above, which carries its preview, its
      // progress and its coverage. Letting it fall through to a shelf as well
      // draws THE SAME PACK TWICE, once as applied and once as a card offering
      // to Get something the device is already wearing.
      //
      // Excluded HERE rather than at a call site, because it may land on any
      // of the three: its own distro's, another distro's, or standalone. A
      // guard at one of them covers a third of the cases, which is what the
      // earlier `p.packId != distroPack` at the currentPacks site did.
      if (p.packId == appliedId) {
        applied = p;
        continue;
      }
      final base = distroOf(p.packId);
      if (base == null) {
        standalone.add(p);
      } else {
        // ─── THE RUNNING DISTRO'S OWN PACK IS IN HERE TOO ───────────────
        //
        // There was a `currentPacks` arm holding it, and a grid below the card
        // to draw it in. Both are gone. Once the card means "applied", the
        // distro's own pack is just another thing you can apply, and giving it
        // a shelf of its own says it is a different KIND of thing.
        //
        // It also makes restoring it the same gesture as choosing anything
        // else: tap the swatch, tap Apply. No restore row, no special case,
        // and no state where the way back is missing.
        (byDistro[base] ??= <PackInfo>[]).add(p);
      }
    }
    // FINAL, so the analyzer's promotion holds inside the card builder below.
    final PackInfo? appliedPack = applied;

    /// True when what is applied is what the distro ships.
    ///
    /// Decides one line of subtitle and nothing else. Kept as a bool rather
    /// than recomputed at the call site because "worn on" versus "comes with"
    /// is the distinction the old card got wrong, and it should be stated once.
    final wearingOwn = appliedPack != null && appliedPack.packId == distroPack;

    final otherDistros = byDistro.keys.toList()
      ..sort((a, b) {
        // The running distro first, then alphabetical. It is the only free one
        // in the row and the only way back to the icons the device shipped
        // with, so it should not be sitting at position nine under M.
        if (a == currentBase) return -1;
        if (b == currentBase) return 1;
        return distroTitles[a]!
            .toLowerCase()
            .compareTo(distroTitles[b]!.toLowerCase());
      });

    final installed = ref.watch(installedIconThemesProvider);
    final progress = ref.watch(packProgressProvider);

    // Watched here so a price arriving from Play repaints the whole grid at
    // once, rather than every card independently re-reading a provider family.
    ref.watch(ownedSkusProvider);

    // ─── AND THE OTHER HALF OF THE SAME QUESTION ────────────────────────────
    //
    // `ownedSkusProvider` pushes what Play says is OWNED. This pushes which
    // distro is APPLIED, which is what decides whether a pack came free with it.
    //
    // Watched rather than read, and watched HERE, because this screen is where
    // both facts are used: it draws Get or a price from one, and native refuses
    // or permits the install from the other. Without this the two disagreed in
    // the most confusing possible way, a card reading Get and a tap replying
    // "needs to be purchased first" for the distro you are running.
    //
    // A Provider with no value; watching it is what runs it.
    ref.watch(activeThemePushProvider);

    // Which swatch is being tried on, or null for the distro in use.
    final previewBase = ref.watch(_iconPreviewProvider);
    // ── THE SELECTED SWATCH, RESOLVED ONCE ────────────────────────────────
    //
    // The strip draws it and the action panel below acts on it, so deriving it
    // in both places would be two rules that can disagree. A LOOKUP rather than
    // a stored PackInfo, because the selection is just a distro base id and the
    // catalogue behind it can change while the screen is open.
    final PackInfo? previewSwatch = previewBase == null
        ? null
        : (byDistro[previewBase]?.isNotEmpty ?? false)
            ? byDistro[previewBase]!.first
            : null;
    final String? previewTitle =
        previewBase == null ? null : distroTitles[previewBase];

    final prefs = ref.read(prefsProvider(theme.spec.id).notifier);

    final selectedSystem = theme.prefs.systemIconPack;


    // ── the two writes ──────────────────────────────────────────────────────
    //
    // `.edit`, never `.update`. `.update` is an inherited name collision on
    // AsyncNotifier that mutates in memory without touching disk, so the choice
    // would look applied and revert on the next cold start.
    //
    // `clearing()`, not `copyWith(x: null)`. copyWith reads a null argument as
    // "leave it alone", so the reset rows would silently do nothing — and only
    // for the one value that needs them to work.
    /// Apply a pack to whichever tier it belongs to.
    ///
    /// ─── ROUTING BY TYPE, WHICH IS THE WHOLE FIX ──────────────────────────
    ///
    /// This was `chooseHero(String packId)` and wrote `iconPackId` for
    /// everything it was handed. `EffectiveTheme.resolve` routes that field to
    /// `IconStyle.heroPack`, native gives it to `HeroIconResolver`, and that
    /// class parses a pack.json with an `icons` map of image filenames. A
    /// derived line pack has no such map, so it read as null, the hero tier
    /// drew nothing, and the brand tier went on rendering the distro's own
    /// colour.
    ///
    /// The visible result was the worst kind: Apply succeeded, prefs were
    /// written, the card updated, the toast said applied, and not one icon in
    /// the drawer changed. Nothing failed, so nothing reported a failure.
    ///
    /// `packType` is on `PackInfo` already, straight from the signed index, so
    /// the answer is data rather than a guess about the id's shape. Taking the
    /// whole pack rather than an id is what makes that possible, and it is why
    /// every call site now passes `p` instead of `p.packId`.
    /// `clearing()`, not `copyWith(x: null)`. copyWith reads a null argument as
    /// "leave it alone", so a reset would silently do nothing, and only for the
    /// one value that needs it to work.
    Future<void> clearPack({bool brand = false, bool hero = false}) =>
        prefs.edit((p) => p.clearing(
              iconBrandPackId: brand,
              iconPackId: hero,
            ));

    Future<void> applyPack(PackInfo p) {
      final brand = p.packType == 'brand';
      // ─── THE DISTRO'S OWN IS CLEARED, NOT PINNED ──────────────────────────
      //
      // Applying it by writing its id would work today and rot quietly: the
      // stored id survives a republished theme that names a different pack, so
      // a device would keep wearing last month's answer to "the distro's own"
      // while every fresh install got the new one. Null means "whatever this
      // distro names", which is the thing actually being asked for.
      if (brand && p.packId == distroPack) return clearPack(brand: true);
      return prefs.edit(
        (prev) => brand
            ? prev.copyWith(iconBrandPackId: p.packId)
            : prev.copyWith(iconPackId: p.packId),
      );
    }

    Future<void> chooseSystem(String? packageName) => prefs.edit(
          (p) => packageName == null
              ? p.clearing(systemIconPack: true)
              : p.copyWith(systemIconPack: packageName),
        );

    // `setIconTheme` and `setIconPack` are deliberately NOT called from here.
    // `effectiveThemeProvider` watches prefs and pushes both, so there is
    // exactly one writer; a second one here would race it and lose about half
    // the time. The grid repaints on its own: these prefs are inside
    // `EffectiveTheme.==`, `AppIcon` folds them into its cache key, and both
    // therefore re-key every icon the moment one changes.

    /// Download, then report per STATUS, never per detail string.
    ///
    /// Lifted from `themes_screen.tapCard` deliberately, message for message.
    /// Each branch needs a different action from the user, and folding them into
    /// one "Download failed" is the message that tells nobody anything — which
    /// is the reason `PackResult` carries a status at all.
    Future<void> download(PackInfo p, {required bool thenApply}) async {
      final result = await ref.read(packActionsProvider).install(p.packId);
      if (!context.mounted) return;

      switch (result.status) {
        case 'installed':
          if (thenApply) {
            await applyPack(p);
            if (context.mounted) context.showMessage('${p.title} applied');
          } else {
            context.showMessage('${p.title} updated');
          }
        case 'upToDate':
          // The common case on a re-tap. Silent on purpose: telling someone
          // nothing happened is noise.
          break;
        case 'notEntitled':
          context.showMessage('${p.title} needs to be purchased first');
        case 'appTooOld':
          context.showMessage('${p.title} needs a newer version of G Launcher');
        case 'noSpace':
          context.showMessage('Not enough free space for ${p.title}');
        case 'cancelled':
          break;
        case 'rejected':
          // A signature or hash check failed. NOT retryable, and worth saying
          // plainly rather than dressing up as a network blip — retrying a bad
          // signature produces the same answer and burns someone's data.
          context.showMessage('${p.title} failed verification and was discarded');
        case 'missingDependency':
          // ─── THE ONE STATUS THAT ALREADY KNOWS WHY ────────────────────
          //
          // An official icon pack is a colour pointing at the pack that holds
          // the drawings. When that one cannot be installed this one is not
          // attempted, because arriving and rendering nothing is worse than not
          // arriving.
          //
          // Native unwraps the dependency's OWN reason into `detail`, so this
          // says "needs 10 MB free" or "needs app version 9" rather than
          // "try again". Without this case it fell to the default below and
          // every one of those became the same unhelpful sentence, which is
          // exactly the failure the unwrapping was written to avoid.
          context.showMessage(
            result.detail.isEmpty
                ? 'Could not download what ${p.title} needs'
                : '${p.title}: ${result.detail}',
          );
        default:
          context.showMessage('Could not download ${p.title}, try again');
      }
    }

    Future<void> tapPack(PackInfo p, CardStatus status) async {
      // PER TIER. This compared everything against `selectedHero`, so with the
      // two prefs split a colour would report "already your icon theme" only
      // when a hero pack of the same id was applied, which is never.
      // `appliedId` already folds the brand default in, so tapping the distro's
      // own colour while wearing it is caught here too.
      final already = p.packType == 'brand'
          ? appliedId == p.packId
          : selectedHero == p.packId;
      if (already) {
        context.showMessage('${p.title} is already your icon theme');
        return;
      }

      switch (status) {
        // On the device already. The selection flips, prefs writes, and every
        // icon re-requests because the pack id is in AppIcon's cache key.
        case CardStatus.bundled:
        case CardStatus.installed:
          await applyPack(p);
          if (context.mounted) context.showMessage('${p.title} applied');

        // On the device but stale. Apply FIRST, update after: the user asked to
        // see this artwork, and making them wait on a download to see something
        // they already have is the wrong trade.
        case CardStatus.updateAvailable:
          await applyPack(p);
          await download(p, thenApply: false);

        case CardStatus.available:
          await download(p, thenApply: true);

        case CardStatus.locked:
          // Play's own sheet. The download is NOT started here: the purchase
          // stream fires asynchronously, possibly minutes later for the cash
          // and carrier-billing methods this market actually uses, and
          // `packBridgeProvider` is listening for exactly that. Kicking off a
          // download on the return of buy() would race the entitlement push and
          // usually lose.
          final started = await ref.read(buyProvider)(p.sku!);
          if (!started && context.mounted) {
            context.showMessage('${p.title} is not available to buy right now');
          }

        case CardStatus.requiresAppUpdate:
          context.showMessage('${p.title} needs a newer version of G Launcher');
      }
    }

    // One grid shape for every section, so the shelves read as one storefront.
    Widget packGrid(List<Widget> children) => GridView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            // The same fixed extent the distros grid uses, so the two screens
            // read as siblings rather than as two people's work.
            mainAxisExtent: 150,
          ),
          children: children,
        );

    return ThemedScaffold(
      title: 'Icons',
      // ── THE SELECTED SWATCH, RESOLVED ────────────────────────────────────
      //
      // Derived here rather than inside the strip, because the action panel
      // below it needs the same pack and deriving it twice is two rules that
      // can disagree. Null when nothing is selected, or when the selection
      // points at a distro that has since left the catalogue, which is why this
      // is a lookup rather than a stored PackInfo.
      body: ListView(
        // The 28 is the list's own breathing room; the inset clears the
        // navigation bar on top of it. No longer const: the inset is runtime.
        padding: EdgeInsets.only(bottom: 28 + context.bottomInset),
        children: [
          // ── ours, grouped by distro ───────────────────────────────────────
          //
          // One shelf per distro rather than one flat sea of cards. The first
          // shelf is the active distro: its default card plus every pack whose
          // id it owns. Other distros' packs follow, then packs that belong to
          // no distro at all. The grouping is the prefix rule above, so
          // publishing a pack under a distro's id is the whole of putting it
          // on that distro's shelf; free or paid falls out of each card's own
          // sku and entitlement, which `PackInfo.unlocked` already resolved.
          ...iconAppearanceRows(context, ref, theme),

          // ─── "YOUR ICONS", NOT "COMES WITH KALI LINUX" ──────────────────
          //
          // The old heading was only true until the moment somebody changed
          // something, and a heading that contradicts the card beneath it is
          // worse than a vague one. This is true in every state and names the
          // card by what it is rather than by where the pack came from.
          const ThemedSectionHeader('Your icons'),

          // ── ONE WIDE CARD, NOT A HALF-WIDTH TILE ─────────────────────────
          //
          // What is applied is not one option among several: it is what the
          // device is wearing, it is the only card on this screen with no
          // price, and it is the only one that can say something measured
          // about THIS phone. Giving it the same 150pt tile as thirteen
          // purchasable colours made the one card that is already yours look
          // like the fourteenth thing for sale.
          //
          // Full width also buys the room for six real icons instead of a 2x2
          // schematic, which matters because the schematic is what every card
          // on the screen was drawing: fourteen products that differ only in
          // colour, rendered as fourteen identical grey squares.
          _WearingCard(
            theme: theme,
            pack: appliedPack,
            // Whether the applied pack is the one the distro ships, which is
            // the difference between "Comes with Kali Linux" and "Worn on Kali
            // Linux". Both are true statements about different situations and
            // the card said the first one in both.
            own: wearingOwn,
            progress: appliedPack == null ? null : progress[appliedPack.packId],
            // Selecting the named pack by hand and selecting the default are
            // ─── ALWAYS ACTIVE, BECAUSE IT IS ALWAYS WHAT IS APPLIED ──────
            //
            // This weighed `selectedHero` against `distroPack` to decide
            // whether the card was showing the live thing. It no longer has to
            // ask: the card IS the applied pack now, so the ring is a fact
            // about the card rather than a comparison that could come out
            // false and leave nothing on the screen marked.
            active: true,
            // ─── THE TAP FINISHES AN INSTALL, IT DOES NOT CHANGE ANYTHING ──
            //
            // It used to also revert to the distro's own icons, because the
            // card was the distro's own icons and tapping it was how you got
            // back. That belongs to the strip now: the running distro has a
            // swatch like every other, and restoring is tap, then Apply. Same
            // two gestures as choosing anything else, and no state where the
            // way back is somewhere different.
            //
            // What remains is the case where the applied pack is named but not
            // yet on disk. `claimOwned` normally has it before the screen
            // opens; if it does not, tapping the card is the obvious thing to
            // try and it should work.
            onTap: () async {
              final ap = appliedPack;
              if (ap == null) return;
              final st = CardStatus.parse(
                ap.state,
                unlocked: ap.unlocked,
                free: ap.sku == null,
              );
              if (st == CardStatus.available ||
                  st == CardStatus.updateAvailable) {
                await download(ap, thenApply: false);
              }
            },
          ),

          // ── OTHER DISTROS: ONE ROW, NOT THIRTEEN SHELVES ─────────────────
          //
          // This was a `ThemedSectionHeader` and a grid PER DISTRO, so a device
          // scrolled past thirteen near-identical shelves, each holding one
          // card, each showing a price. Fourteen products that share one
          // geometry and differ only in colour were presented as fourteen
          // unrelated things.
          //
          // The colour IS the product, so the swatch is the listing. One
          // horizontal row, thirteen swatches, and tapping one previews it on
          // the apps below rather than navigating anywhere.
          // The heading was "Other colours" while the running distro was held
          // out of the row. It is in the row now, so "other" is one swatch
          // wrong, and it is the one swatch somebody is most likely looking
          // for.
          if (otherDistros.isNotEmpty) ...[
            const ThemedSectionHeader('Colours'),
            _ColourStrip(
              theme: theme,
              // Which base is the running distro, so its swatch reads Included
              // rather than a price. No `worn` any more: the applied pack is
              // never in this row, it is the card above.
              current: currentBase,
              // Read HERE rather than inside each swatch. `_Swatch` is a plain
              // StatelessWidget, and making it a ConsumerWidget to watch one
              // family member per swatch would rebuild thirteen of them
              // independently every time Play answers about any one.
              prices: {
                for (final base in otherDistros)
                  if (byDistro[base]!.isNotEmpty)
                    byDistro[base]!.first.packId:
                        ref.watch(productPriceProvider(byDistro[base]!.first.sku)),
              },
              distros: [
                for (final base in otherDistros)
                  if (byDistro[base]!.isNotEmpty)
                    (
                      base: base,
                      title: distroTitles[base] ?? base,
                      pack: byDistro[base]!.first,
                    ),
              ],
              selected: previewBase,
              // ─── SELECTING AND ACQUIRING ARE TWO TAPS, NOT ONE ──────────
              //
              // The strip only ever set preview state, so tapping a locked
              // colour did nothing: no purchase, no message, no navigation.
              // A control that swallows a tap is worse than one that refuses.
              //
              // First tap selects, which is what makes the try-on possible
              // without committing to anything. The action lives on the panel
              // below the strip, where it sits under the thing it buys.
              onSelect: (base) =>
                  ref.read(_iconPreviewProvider.notifier).set(base),
            ),

            // What the selected swatch actually offers. Rendered even before
            // the try-on grid exists, because a strip with no action beneath it
            // is the bug being fixed.
            if (previewSwatch != null)
              _ColourAction(
                theme: theme,
                pack: previewSwatch,
                title: previewTitle ?? previewSwatch.title,
                price: ref.watch(productPriceProvider(previewSwatch.sku)),
                onTap: (status) => tapPack(previewSwatch, status),
              ),
          ],

          if (standalone.isNotEmpty) ...[
            const ThemedSectionHeader('Standalone packs'),
            packGrid([
              for (final p in standalone)
                _PackCard(
                  theme: theme,
                  pack: p,
                  // Hero tier: these are the hand-drawn packs, and the one
                  // applied is `iconPackId`. The colour strip's selection lives
                  // in `iconBrandPackId` and must not light a card here.
                  active: selectedHero == p.packId,
                  progress: progress[p.packId],
                  onTap: (status) => tapPack(p, status),
                ),
            ]),
          ],

          if (packs.isEmpty)
            const _Note(
              text: 'Icon themes arrive with distros. Each one ships its own '
                  'set, and they can be mixed: run the Kali desktop with '
                  'Ubuntu icons if you want.',
            ),

          // ── theirs ────────────────────────────────────────────────────────
          const ThemedSectionHeader('Installed packs'),

          installed.when(
            loading: () => const SizedBox(height: 12),
            // A failed query is indistinguishable from none installed as far as
            // what the user can do about it, so it draws the same thing.
            // Inventing an error state would offer a retry button for a
            // package-manager call that does not fail transiently.
            error: (_, __) => const _Note(text: _emptyPacks),
            data: (map) => map.isEmpty
                ? const _Note(text: _emptyPacks)
                : GridView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      mainAxisExtent: 150,
                    ),
                    children: [
                      _Card(
                        title: 'None',
                        subtitle: 'Distro icons only',
                        active: selectedSystem == null,
                        preview: _Schematic(theme: theme, accent: false),
                        onTap: () async {
                          if (selectedSystem == null) return;
                          await chooseSystem(null);
                        },
                      ),
                      for (final e in map.entries)
                        _SystemCard(
                          theme: theme,
                          packageName: e.key,
                          label: e.value,
                          active: selectedSystem == e.key,
                          onTap: () async {
                            if (selectedSystem == e.key) return;
                            await chooseSystem(e.key);
                            if (context.mounted) {
                              context.showMessage('${e.value} applied');
                            }
                          },
                        ),
                    ],
                  ),
          ),

          // ── the layering, said out loud ───────────────────────────────────
          //
          // Both selections are live at once, and without this line someone who
          // has picked from both grids sees half their icons come from one and
          // reasonably concludes the other did not work.
          const _Disclosure(
            title: 'How the layers combine',
            text: 'An installed pack covers the apps it has art for. Anything '
                'it misses falls back to the icon theme, then to the distro’s '
                'own icons.',
          ),
        ],
      ),
    );
  }
}

const _emptyPacks = 'No icon packs installed. Anything in Nova or ADW format '
    'works, including your own exports from Icon Pack Studio.';

/// The distro's own icon pack, full width, with six of the user's real apps.
///
/// ─── WHY THIS IS NOT A `_Card` ──────────────────────────────────────────────
///
/// It was one, and being one is what made the screen read wrongly. A half-width
/// tile fits a 2x2 schematic and two lines of text, so the card that is already
/// yours looked exactly like the thirteen that cost money, and the only thing
/// distinguishing it was the absence of a price. Full width fits six icons in
/// the pack's own colour and one measured line about this device, which is
/// enough for someone to tell at a glance what they are wearing and how much of
/// their phone it covers.
///
/// ─── SIX ICONS, NOT EIGHT, AND NOT A SCHEMATIC ──────────────────────────────
///
/// Eight is what the try-on row shows, and it needs a horizontal scroll to do
/// it. This is a static card, so the count is whatever fits without scrolling
/// at the largest text scale: six 44pt tiles plus gaps inside a 411pt screen's
/// margins. Taken from the same `_previewProvider` the try-on uses, keyed by
/// tint and size, so opening this screen and then trying the same colour on
/// costs one render rather than two.
///
/// Falls back to `_PackPreview`, and then to the schematic, when the pack has
/// no tint. Hero packs carry their colours inside the art and cannot be
/// recoloured by a hex, so asking native to render them at a tint would be
/// asking for the wrong picture rather than no picture.
class _WearingCard extends ConsumerWidget {
  const _WearingCard({
    required this.theme,
    required this.pack,
    required this.own,
    required this.active,
    required this.progress,
    required this.onTap,
  });

  final EffectiveTheme theme;

  /// The pack this distro names, or null when it names one that is not in the
  /// catalogue. Null is the generator, and the generator is a real answer.
  final PackInfo? pack;

  /// Whether what is applied is what this distro ships.
  ///
  /// ─── ONE LINE, AND THE CARD USED TO GET IT WRONG ────────────────────────
  ///
  /// The subtitle was `'Comes with ${theme.spec.name}'` unconditionally, so
  /// applying Linux Mint on Kali produced "Kali Linux Icons, comes with Kali
  /// Linux" over a green drawer, and later "Linux Mint Icons, comes with Kali
  /// Linux", which is worse: a claim about where the pack came from that is
  /// simply false.
  ///
  /// Both phrasings are true of different situations. The card has to know
  /// which one it is in, and it cannot work that out from `pack` alone because
  /// the answer depends on what the theme names.
  final bool own;

  final bool active;
  final double? progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ChromeScope.of(context);
    final c = d.colors;
    final p = pack;

    // ─── THE DISTRO'S OWN PACK IS NOT SOMETHING YOU FETCH ─────────────────
    //
    // Running elementary means having elementary Icons. There is no decision
    // here and nothing to acquire, so the card carries no Get.
    //
    // It still has to DOWNLOAD, and pretending otherwise would be a card that
    // says nothing while the drawer shows generated icons. So `available`
    // becomes "preparing" rather than an offer: the fetch is already running,
    // started by `claimOwned` the moment the theme was applied, and the user is
    // being told rather than asked.
    final st = p == null
        ? null
        : CardStatus.parse(p.state, unlocked: p.unlocked, free: p.sku == null);
    final preparing =
        st == CardStatus.available || st == CardStatus.updateAvailable;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active ? c.accent : c.line,
              width: active ? 2 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _WearingIcons(theme: theme, pack: p),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          // The pack's own words, never its id. `distroPack`
                          // used to be shown here directly, which was readable
                          // while it held a hand-authored hero pack name and
                          // became `elementary-os-8-line` the moment it
                          // resolved a brand pack.
                          p != null && p.title.isNotEmpty
                              ? p.title
                              : 'Distro default',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: d.text.title,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          // ─── WHAT ACTUALLY RUNS, WHICH CHANGED ──────────
                          //
                          // "Adaptive, every app covered" described the
                          // GENERATOR, and it was true when the generator was
                          // the only thing behind a hand-drawn pack.
                          //
                          // It is wrong in the way that matters now. Every
                          // distro ships an outline pack covering thousands of
                          // drawings, so "every app covered" is the LINE SET's
                          // claim, and the generator is what runs for the
                          // handful it misses. Reading otherwise makes the
                          // default sound complete and the pack sound optional,
                          // which is backwards.
                          p == null
                              ? 'Generated from each app’s own icon'
                              : preparing
                                  ? 'Preparing your icons'
                                  : own
                                      ? 'Comes with ${theme.spec.name}'
                                      // Not "comes with", because it does not.
                                      // You chose it and it is running here.
                                      : 'Worn on ${theme.spec.name}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: d.text.caption,
                        ),
                      ],
                    ),
                  ),
                  if (active) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.check_circle, size: 20, color: c.accent),
                  ] else if (preparing && progress == null) ...[
                    const SizedBox(width: 8),
                    _Mini('Preparing', c.textMuted),
                  ],
                ],
              ),
              // The bar during a transfer, the count when there is none. Never
              // both: two identical bars stacked would read as one thing
              // measured twice.
              //
              // Hand-drawn rather than `ThemedProgress`, matching `_Card` below
              // and for the reason it states: that widget wraps a Material
              // indicator, and Material widgets read the ambient ThemeData,
              // which this screen deliberately does not have.
              if (progress != null) ...[
                const SizedBox(height: 11),
                _Bar(value: progress!, height: 3, rounded: false),
              ] else if (p != null)
                _CoverageRow(packId: p.packId),
            ],
          ),
        ),
      ),
    );
  }
}

/// "41 of your 46 apps", and the bar under it. Absent until it is known.
///
/// ─── NULL RENDERS NOTHING, WHICH IS THE POINT ───────────────────────────────
///
/// A placeholder here would be a number, and a number nobody has measured is
/// worse than a gap: this card's entire claim to the width it takes is that
/// the line under the name is true. So the loading state, the error state and
/// the "cannot be counted" state are all the same zero-height widget, and the
/// row appears once when there is something to say.
///
/// No fixed height around it for the same reason the colour strip has none:
/// caption height scales with the user's font setting, so any constant is right
/// at one scale and clips at another.
class _CoverageRow extends ConsumerWidget {
  const _CoverageRow({required this.packId});

  final String packId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only `d`, for the caption's text style. The bar reads its own
    // ChromeScope inside `_Bar`, so a colour handle here would go unused.
    final d = ChromeScope.of(context);

    final cov = ref.watch(packCoverageProvider(packId)).asData?.value;
    if (cov == null || cov.total <= 0) return const SizedBox.shrink();

    final covered = cov.covered.clamp(0, cov.total);
    final fraction = covered / cov.total;

    return Padding(
      padding: const EdgeInsets.only(top: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            // Their apps, their number. The pack's own icon count belongs in
            // the store listing and says nothing about this phone.
            '$covered of your ${cov.total} apps',
            style: d.text.caption,
          ),
          const SizedBox(height: 6),
          // Rounded and slightly taller than the download bar, so the two are
          // not mistaken for each other. This one is a static fact: it never
          // moves and it never completes, and a bar that looks like progress
          // sitting at 89% reads as a transfer that stalled.
          _Bar(value: fraction, height: 4, rounded: true),
        ],
      ),
    );
  }
}

/// A track and a fill. Two callers, two shapes, one rule about zero.
///
/// `FractionallySizedBox` rather than two `Expanded`s, which is the detail
/// worth keeping: a flex of zero is an assertion failure, and both callers pass
/// a legitimate 0.0 — the first frame of every download, and a pack that draws
/// none of your apps.
class _Bar extends StatelessWidget {
  const _Bar({
    required this.value,
    required this.height,
    required this.rounded,
  });

  final double value;
  final double height;
  final bool rounded;

  @override
  Widget build(BuildContext context) {
    final c = ChromeScope.of(context).colors;

    final bar = SizedBox(
      height: height,
      child: Stack(
        children: [
          // ─── `lineStrong`, NOT `line`, AND IT IS NOT COSMETIC ───────────
          //
          // On a dark palette `c.line` and `c.accent` sit close enough that a
          // filled bar reads as an empty one. 175 of 249 is 70% and looked like
          // nothing had been measured at all, which is worse than showing no
          // bar: it makes the honest number above it look wrong.
          //
          // The fix is the TRACK, not the fill. Brightening the accent would
          // change the colour the pack is being sold in, on the one screen
          // whose subject is that colour.
          Positioned.fill(child: ColoredBox(color: c.lineStrong)),
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            // Clamped, not asserted. A pack covering more packages than the
            // launcher lists is possible on a device with work profiles, and a
            // width factor above 1.0 is an overflow rather than a wrong number.
            widthFactor: value.clamp(0.0, 1.0),
            child: ColoredBox(color: c.accent),
          ),
        ],
      ),
    );

    return rounded
        ? ClipRRect(borderRadius: BorderRadius.circular(height / 2), child: bar)
        : bar;
  }
}

/// Six of the user's real apps, in the pack's colour.
class _WearingIcons extends ConsumerWidget {
  const _WearingIcons({required this.theme, required this.pack});

  final EffectiveTheme theme;
  final PackInfo? pack;

  static const _count = 6;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ChromeScope.of(context).colors;
    final tint = pack?.tint;

    // No colour of its own: a hero pack, or a pack the catalogue predates the
    // field on. `_PackPreview` draws its preview.png and falls back to the
    // schematic, which is what this card showed before and is still correct.
    if (tint == null || tint.isEmpty) {
      return SizedBox(
        height: 64,
        child: pack == null
            ? _Schematic(theme: theme, accent: true)
            : _PackPreview(theme: theme, packId: pack!.packId),
      );
    }

    // Asked for in DEVICE pixels because native renders a bitmap, and handing
    // it a logical number produces a soft icon on every phone above 1x.
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final sizePx = (44 * dpr).round();
    final shot = ref.watch(_previewProvider(_PreviewKey(tint, sizePx)));

    return LayoutBuilder(builder: (context, box) {
      // Six across whatever width is left inside the card's padding, so this
      // does not need to know the screen width and does not wrap at any text
      // scale. `_count - 1` gaps of 8.
      const gap = 8.0;
      final side =
          ((box.maxWidth - gap * (_count - 1)) / _count).clamp(24.0, 56.0);

      Widget slot(Widget? child) => SizedBox(
            width: side,
            height: side,
            child: child,
          );

      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: shot.when(
          // Plates in the right places rather than a spinner. This path bypasses
          // both cache tiers, so six fresh renders take a moment, and six empty
          // tiles read as loading where a spinner reads as broken.
          loading: () => [
            for (var i = 0; i < _count; i++)
              slot(
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: c.line,
                    borderRadius: BorderRadius.circular(side * 0.3),
                  ),
                ),
              ),
          ],
          error: (_, __) => [for (var i = 0; i < _count; i++) slot(null)],
          // ─── SIX THAT DREW, NOT THE FIRST SIX ASKED FOR ─────────────────
          //
          // `previewIcons` returns null for an app the pack has no drawing
          // for, and at 175 of 249 covered that is roughly one slot in three.
          // Rendering the first six positions left holes in the row: a
          // six-wide strip with four icons in it, bunched to one side,
          // which reads as a rendering fault rather than as coverage.
          //
          // The COVERAGE LINE is where "not everything is drawn" belongs, and
          // it says so in numbers directly underneath. The strip is a sample,
          // and a sample should show the pack, so it takes the first six that
          // came back with bytes.
          //
          // Fewer than six is still possible on a device with very little
          // installed, and the row simply ends there rather than padding with
          // blanks.
          data: (bytes) {
            final drawn = [for (final b in bytes) if (b != null) b];
            return [
              for (var i = 0; i < _count; i++)
                slot(
                  i < drawn.length
                      ? Image.memory(drawn[i], fit: BoxFit.contain)
                      : null,
                ),
            ];
          },
        ),
      );
    });
  }
}

/// A card in either grid: preview on top, name and trailing beneath.
///
/// Deliberately shaped like `_ThemeCard` on the distros screen — same 150pt
/// extent, same two-band layout, same active ring — because these are two
/// halves of one storefront and a user moves between them in one sitting.
class _Card extends StatelessWidget {
  const _Card({
    required this.title,
    required this.subtitle,
    required this.active,
    required this.preview,
    required this.onTap,
    this.trailing,
    this.progress,
  });

  final String title;
  final String subtitle;
  final bool active;
  final Widget preview;
  final VoidCallback onTap;
  final Widget? trailing;

  /// 0.0 to 1.0 while this pack is downloading, null otherwise. The bar only
  /// exists during a transfer; a permanent empty track reads as a broken one.
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    final c = d.colors;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? c.accent : c.line,
            width: active ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: preview),
            if (progress != null)
              // Hand-drawn rather than a Material indicator: those read the
              // ambient ThemeData, which this screen deliberately does not have
              // (see no_constants.sh's settings scope).
              SizedBox(
                height: 3,
                child: Stack(
                  children: [
                    Positioned.fill(child: ColoredBox(color: c.line)),
                    // FractionallySizedBox rather than two Expandeds: a flex of
                    // zero is an assertion failure, and progress is legitimately
                    // 0.0 for the first frame of every download.
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: progress!.clamp(0.0, 1.0),
                      child: ColoredBox(color: c.accent),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: d.text.title,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: d.text.caption,
                        ),
                      ],
                    ),
                  ),
                  if (active)
                    Icon(Icons.check_circle, size: 18, color: c.accent)
                  else if (trailing != null) ...[
                    const SizedBox(width: 6),
                    trailing!,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One of ours, from the signed catalogue.
/// One swatch per distro, in a single scrolling row.
///
/// ─── WHY A ROW OF COLOURS AND NOT A GRID OF CARDS ───────────────────────────
///
/// Fourteen packs share one geometry, 13,622 drawings, and differ in exactly
/// one field: `tint`. A card carrying a title, a preview mosaic, a version and
/// a price spends most of its area repeating what every other card says, and
/// thirteen of them stacked vertically read as thirteen unrelated products.
///
/// The colour is the product, so the swatch is the listing. Everything else
/// belongs on the ONE the user tapped, which is the try-on below.
class _ColourStrip extends StatelessWidget {
  const _ColourStrip({
    required this.theme,
    required this.distros,
    required this.prices,
    required this.selected,
    required this.current,
    required this.onSelect,
  });

  final EffectiveTheme theme;
  final List<({String base, String title, PackInfo pack})> distros;
  /// Play's formatted price per pack id, empty until Play answers.
  final Map<String, String?> prices;
  final String? selected;

  /// The base id of the distro being run.
  ///
  /// Its swatch is in this row like every other, and is the only free one, so
  /// it reads Included where the rest carry a price. It is also the way back
  /// to the icons the device shipped with, which is why it sorts first.
  final String? current;

  final void Function(String base) onSelect;

  @override
  Widget build(BuildContext context) {
    /// ─── NO FIXED HEIGHT, BECAUSE THERE IS NO RIGHT NUMBER ─────────────────
    ///
    /// This was a `SizedBox(height: 96)` around a horizontal `ListView`, which
    /// forces every swatch into 96 logical pixels. The content is 56 of
    /// swatch, a price line and up to two lines of label, and it came to 105 on
    /// a device at default font size: 1px over without a price, 18 with one.
    ///
    /// Picking a bigger number does not fix it. Caption height scales with the
    /// user's font setting, so any constant is correct at one text scale and
    /// wrong at the others, and the failure is a striped box on a shipping
    /// screen rather than something that shows up in review.
    ///
    /// A horizontal `SingleChildScrollView` around a `Row` has no such
    /// constraint: the outer `ListView` hands down a bounded width and
    /// unbounded height, so the row sizes to its tallest swatch whatever the
    /// text scale turns out to be.
    ///
    /// The cost is that every swatch builds rather than only the visible ones.
    /// Thirteen is not a list worth virtualising, and each is one small image.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < distros.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Builder(builder: (context) {
              final entry = distros[i];
              // `unlocked` is resolved natively from Play's record ORed with
              // inclusion, so a pack already owned is marked rather than priced.
              return _Swatch(
                title: entry.title,
                pack: entry.pack,
                theme: theme,
                selected: selected == entry.base,
                included: current == entry.base,
                owned: entry.pack.unlocked,
                price: prices[entry.pack.packId],
                onTap: () => onSelect(entry.base),
              );
            }),
          ],
        ],
      ),
    );
  }
}

/// Eight of the user's real apps, repainted in a pack's colour.
///
/// ─── THE PREVIEW NEEDS NO PURCHASE AND NO DOWNLOAD ──────────────────────────
///
/// `arcticons-line` holds all 13,622 drawings and is already on the device: it
/// is free, and required by whichever official pack the user has. A derived
/// pack adds only a colour. So this is installed geometry plus a hex value, and
/// asking Play about it would be asking permission to show something the phone
/// is already holding.
///
/// ─── FAMILY, AND AUTO-DISPOSING ─────────────────────────────────────────────
///
/// Keyed by tint and size, so flicking between two swatches and back is free
/// the second time, and it dies with the screen: previewed bitmaps must not
/// outlive the moment of shopping.
///
/// Native does not cache these at all, by design. `IconCache` keys bitmaps by
/// the applied style, which carries no previewed colour, so caching a preview
/// would poison the drawer with a pack nobody bought and it would survive a
/// restart.
final _previewProvider =
    FutureProvider.family<List<Uint8List?>, _PreviewKey>((ref, key) async {
  // The apps the user actually has, in the order the drawer shows them, so the
  // grid is recognisable rather than a random eight. Taken from the plain list
  // rather than `visibleAppsProvider`, which needs a theme key and applies the
  // hidden-apps filter: a hidden app is fine to preview on, and threading a
  // theme in here would tie the storefront to the drawer's own state.
  final apps = ref.watch(appListProvider).asData?.value ?? const <AppEntry>[];
  if (apps.isEmpty) return const [];

  final keys = [for (final a in apps.take(8)) a.componentKey];
  final api = ref.read(launcherHostApiProvider);
  return api.previewIcons(keys, key.tint, key.sizePx);
});

@immutable
class _PreviewKey {
  const _PreviewKey(this.tint, this.sizePx);
  final String tint;
  final int sizePx;

  @override
  bool operator ==(Object other) =>
      other is _PreviewKey && other.tint == tint && other.sizePx == sizePx;

  @override
  int get hashCode => Object.hash(tint, sizePx);
}

class _ColourAction extends ConsumerWidget {
  const _ColourAction({
    required this.theme,
    required this.pack,
    required this.title,
    required this.price,
    required this.onTap,
  });

  final EffectiveTheme theme;
  final PackInfo pack;
  final String title;
  final String? price;
  final void Function(CardStatus status) onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ChromeScope.of(context);
    final c = d.colors;

    // The same derivation every card on this screen uses. Ownership arrives
    // already resolved on `PackInfo.unlocked`, from native, never re-derived
    // here from sku plus a local owned-set.
    final status = CardStatus.parse(
      pack.state,
      unlocked: pack.unlocked,
      free: pack.sku == null,
    );

    final (label, enabled) = switch (status) {
      // A price when Play has answered, a neutral verb when it has not. A
      // button rendering nothing reads as a button that failed.
      CardStatus.locked => (price ?? 'Buy', true),
      CardStatus.available => ('Get', true),
      CardStatus.updateAvailable => ('Update', true),
      CardStatus.bundled || CardStatus.installed => ('Apply', true),
      // Nothing to offer, and saying so is better than a dead control.
      CardStatus.requiresAppUpdate => ('Needs a newer app', false),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(d.panelRadius),
          border: Border.all(color: c.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ─── THE TRY-ON ─────────────────────────────────────────────
            //
            // Eight of the user's real apps in this pack's colour, above the
            // button that buys it. Selling a colour without showing it on the
            // phone it will live on is asking someone to imagine the product.
            //
            // Only when the pack declares a tint. Hero packs and third-party
            // sets carry their colours inside the art, so there is nothing to
            // restyle and a grid would be showing the wrong thing.
            if (pack.tint != null) ...[
              _TryOn(tint: pack.tint!),
              const SizedBox(height: 14),
            ],
            Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: d.text.body.copyWith(color: c.text)),
                  const SizedBox(height: 3),
                  Text(
                    // BUYING A COLOUR IS NOT BUYING A DISTRO. This is
                    // `icons_kali`, not `distro_kali`: the outlines travel, the
                    // shell and shape stay whatever you are running. Said here
                    // because it is the one thing a buyer could reasonably get
                    // wrong, and the refund is on us if they do.
                    status == CardStatus.locked
                        ? 'These outlines on your own shell and shape'
                        : 'Ready to use on ${theme.spec.name}',
                    style: d.text.caption.copyWith(color: c.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: enabled ? () => onTap(status) : null,
              child: Text(label),
            ),
          ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The eight-app grid.
class _TryOn extends ConsumerWidget {
  const _TryOn({required this.tint});

  final String tint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ChromeScope.of(context);
    final c = d.colors;

    // 48 logical pixels at the device's own ratio. Asked for in DEVICE pixels
    // because native renders a bitmap, and handing it a logical number would
    // produce a soft icon on every phone with a ratio above 1.
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final sizePx = (48 * dpr).round();

    final shot = ref.watch(_previewProvider(_PreviewKey(tint, sizePx)));

    return SizedBox(
      height: 56,
      child: shot.when(
        // A skeleton rather than a spinner. This path bypasses both cache tiers
        // on purpose, so eight fresh renders take a moment, and eight empty
        // plates in the right places read as loading rather than as broken.
        loading: () => _TryOnRow(
          children: [
            for (var i = 0; i < 8; i++)
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  // `c.line`, not `surfaceMuted`: this file uses `line`
                  // everywhere and I could not confirm `surfaceMuted` exists on
                  // the token set. A skeleton is the wrong place to discover a
                  // missing token, because it only renders while loading.
                  color: c.line,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
          ],
        ),
        // Nothing rather than an error. A failed preview costs a picture; the
        // price and the button beneath it are still correct and still work.
        error: (_, __) => const SizedBox.shrink(),
        data: (bytes) => bytes.isEmpty
            ? const SizedBox.shrink()
            : _TryOnRow(
                children: [
                  for (final b in bytes)
                    SizedBox(
                      width: 48,
                      height: 48,
                      // Null where nothing could be drawn for that app, which
                      // is normal: a set covering 13,622 apps still misses some.
                      child: b == null
                          ? null
                          : Image.memory(b, fit: BoxFit.contain),
                    ),
                ],
              ),
      ),
    );
  }
}

/// One scrolling row, so eight icons fit any width without wrapping.
class _TryOnRow extends StatelessWidget {
  const _TryOnRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: children.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => children[i],
      );
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.title,
    required this.pack,
    required this.theme,
    required this.selected,
    required this.included,
    required this.owned,
    required this.price,
    required this.onTap,
  });

  final String title;
  final PackInfo pack;
  final EffectiveTheme theme;
  final bool selected;

  /// This is the running distro's own pack, so it costs nothing.
  ///
  /// ─── THE ONE SWATCH IN THE ROW THAT IS NOT A PURCHASE ─────────────────────
  ///
  /// It used to have no swatch at all: it lived in a card above and the strip
  /// listed the other thirteen. Once the card means "what is applied", that
  /// arrangement leaves the distro's own pack with nowhere to be once you
  /// apply something else, and no way back that resembles the way you left.
  ///
  /// So it joins the row. Same swatch, same tap, same Apply button, and the
  /// caption says Included where the others carry a price.
  final bool included;

  final bool owned;
  final String? price;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    final c = d.colors;

    return SizedBox(
      width: 64,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(d.panelRadius),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      // The selected swatch is ringed in its OWN colour, not the
                      // running distro's accent: the ring is part of the thing
                      // being previewed, and using the accent would make every
                      // selection look like the distro already applied.
                      //
                      // The APPLIED swatch is ringed too, and the caption below
                      // is what tells them apart. A ring alone cannot carry both
                      // meanings, and giving the applied one a different colour
                      // would put a second unexplained highlight in a row whose
                      // whole subject is colour.
                      color: selected ? c.accent : c.line,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  // ─── FITTED, BECAUSE THE PREVIEW IS CARD-SIZED ──────────
                  //
                  // `_PackPreview` falls back to `_Schematic`, which builds a
                  // 2x2 of fixed-size tiles with fixed padding, sized for a card
                  // roughly 120px wide. Dropped into a 34px box it overflowed
                  // horizontally AND vertically, which is the striped mess in
                  // the strip.
                  //
                  // FittedBox scales whatever the preview turns out to be, so
                  // this does not depend on `_Schematic`'s internal numbers and
                  // does not change a widget four other cards rely on. A
                  // real image preview scales the same way.
                  padding: const EdgeInsets.all(9),
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: _PackPreview(theme: theme, packId: pack.packId),
                  ),
                ),
                if (owned)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: c.accent,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.surface, width: 2),
                      ),
                      child: Icon(Icons.check, size: 10, color: c.surface),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            // ─── INCLUDED BEATS THE PRICE ─────────────────────────────────
            //
            // Mutually exclusive on purpose, and not only to save a line. The
            // running distro's pack is free while you run it, so a price under
            // it would be answering a question nobody has; and the two stacked
            // would give one swatch three lines while its neighbours have two,
            // which is the ragged strip the height comment above exists to
            // avoid.
            if (included)
              Text(
                'Included',
                maxLines: 1,
                style: d.text.caption.copyWith(
                  color: c.accent,
                  fontWeight: FontWeight.w600,
                ),
              )
            // ─── EVERY OTHER COLOUR IS A PURCHASE ─────────────────────────
            //
            // Not a shelf to browse. A distro you are not running is one you
            // have not paid for, and the price is the most useful thing the
            // swatch can say after the colour itself.
            //
            // Buying a COLOUR is not buying the DISTRO: this is `icons_kali`,
            // not `distro_kali`. You get Kali's outlines in your own distro's
            // shape and shell.
            //
            // Play may not have answered yet, so a null price shows nothing
            // rather than a guess.
            else if (!owned)
              Text(
                price ?? '',
                maxLines: 1,
                style: d.text.caption.copyWith(color: c.accent),
              ),
            const SizedBox(height: 2),
            Text(
              title,
              maxLines: 2,
              // Runtime truncation, not an authored ellipsis: the label is a
              // distro name from the catalogue and its length is not ours.
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: d.text.caption.copyWith(
                color: selected ? c.text : c.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PackCard extends ConsumerWidget {
  const _PackCard({
    required this.theme,
    required this.pack,
    required this.active,
    required this.progress,
    required this.onTap,
  });

  final EffectiveTheme theme;
  final PackInfo pack;
  final bool active;
  final double? progress;
  final void Function(CardStatus) onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ChromeScope.of(context).colors;

    // The SAME derivation the distros grid uses, reused rather than re-written.
    // Ownership arrives already resolved on `PackInfo.unlocked`, from
    // `CdnIndex.isUnlocked` against the signed grants — never re-derived in
    // Dart from sku plus a local owned-set, which would be a second
    // implementation of the ownership rule in a second language.
    //
    // ─── INCLUSION IS NOT OWNERSHIP, AND ONLY DART KNOWS IT ────────────────
    //
    // Every distro ships an icon pack in its own colour, free with that distro,
    // and priced for anyone running a different one. Both are true at once and
    // which applies depends on the distro RUNNING RIGHT NOW.
    //
    // `isUnlocked` cannot answer that: its inputs are a pack id and Play's
    // record, deliberately, and threading the active theme into it would make
    // one function answer two questions. The day they diverged, one would give
    // a pack away and the other would charge twice for it.
    //
    // So the OR happens here, and it is not the second-implementation problem
    // the note above warns about. Ownership is still native and still
    // untouched. This adds a different fact that native does not have: which
    // theme is applied. `EffectiveTheme.defaultLinePackFor` is the one
    // derivation of distro-to-line-pack in this codebase and it is reused
    // rather than rewritten, so the pack shown as included is by construction
    // the same pack the icon pipeline will actually load.
    final included =
        // A TOP-LEVEL function, not a static on EffectiveTheme. This call site
        // was written against a static that never existed, and the analyzer said
        // so: "The method 'defaultLinePackFor' isn't defined for the type
        // 'EffectiveTheme'."
        //
        // Top level is also the right home: `effective_theme.dart` exports it,
        // `EffectiveTheme.resolve` uses it for its own fallback, and this reuses
        // the same one rather than a copy. One derivation, two callers.
        pack.packId == defaultLinePackFor(theme.spec.id);

    final status = CardStatus.parse(
      pack.state,
      unlocked: pack.unlocked || included,
      free: pack.sku == null,
    );

    // A price from Play, already localised for the user's country and currency.
    // Never a number formatted here: "$1.49" is wrong in every market this
    // launcher actually targets.
    final price = ref.watch(productPriceProvider(pack.sku));

    return _Card(
      title: pack.title,
      subtitle: pack.summary.isEmpty ? 'v${pack.version}' : pack.summary,
      active: active,
      progress: progress,
      preview: _PackPreview(theme: theme, packId: pack.packId),
      trailing: switch (status) {
        // "Update app" rather than Get, because the action is on the app and a
        // Get button here would fail in a way the user cannot diagnose.
        CardStatus.requiresAppUpdate => _Mini('Update app', c.textMuted),
        CardStatus.updateAvailable => _Mini('Update', c.accent),
        // The price when Play has answered, a neutral word when it has not.
        // A card that renders nothing at all reads as a card that failed.
        CardStatus.locked => _Mini(price ?? 'Buy', c.accent),
        CardStatus.available => _Mini('Get', c.accent),
        CardStatus.bundled || CardStatus.installed => null,
      },
      onTap: () => onTap(status),
    );
  }
}

/// The pack's own art, exactly as the admin grid composites it at publish.
///
/// The schematic stays as the honest fallback for packs published before
/// previews existed, for a dead network, and for the frame before the image
/// arrives, so a card never shows a broken-image glyph or an empty box.
class _PackPreview extends ConsumerWidget {
  const _PackPreview({required this.theme, required this.packId});

  final EffectiveTheme theme;
  final String packId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = ref.watch(packPreviewUrlProvider(packId)).asData?.value;
    if (url == null) return _Schematic(theme: theme, accent: false);

    final ImageProvider provider = url.startsWith('file://')
        ? FileImage(File(url.substring('file://'.length)))
        : NetworkImage(url);

    return Padding(
      padding: const EdgeInsets.all(10),
      child: Image(
        image: provider,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _Schematic(theme: theme, accent: false),
      ),
    );
  }
}

/// One of theirs, previewed with the pack app's own launcher icon.
class _SystemCard extends ConsumerWidget {
  const _SystemCard({
    required this.theme,
    required this.packageName,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final EffectiveTheme theme;
  final String packageName;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = ref.watch(iconThemeAppProvider(packageName));

    return _Card(
      title: label,
      // The package name, because that is what it is and it is the only way to
      // tell two similarly-named packs apart.
      subtitle: packageName,
      active: active,
      preview: entry == null
          // No launcher activity, so no icon to borrow. The schematic is the
          // honest answer rather than an empty box.
          ? _Schematic(theme: theme, accent: false)
          : Center(child: AppIcon(entry: entry, size: 46)),
      onTap: onTap,
    );
  }
}

/// A neutral stand-in for artwork we cannot show.
///
/// ─── WHY THERE IS NO REAL PREVIEW FOR ONE OF OURS ───────────────────────────
///
/// The signed index carries a title, a summary, a size and a sku. It carries no
/// pixels, which is the same gap the distros grid has with
/// `PreviewLayout.unknown`, and the same fix applies later: an optional preview
/// block on the index entry. Until then this admits it does not know rather
/// than inventing something that will not match what downloads.
///
/// It DOES track the active icon shape, which is real information and free: the
/// tiles are drawn with the same corner treatment the launcher is currently
/// applying, so the schematic at least tells the truth about that.
class _Schematic extends StatelessWidget {
  const _Schematic({required this.theme, required this.accent});

  final EffectiveTheme theme;

  /// Tint one tile with the theme accent. Used on Distro default so the card
  /// that is almost always selected does not look like the emptiest one.
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final c = ChromeScope.of(context).colors;

    // 2x2, because that is the smallest arrangement that reads as "a set of
    // icons" rather than "one icon".
    const tile = 22.0;
    final radius = tile * _shapeFraction(theme);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var row = 0; row < 2; row++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var col = 0; col < 2; col++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Container(
                        width: tile,
                        height: tile,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(radius),
                          color: accent && row == 0 && col == 0
                              ? c.accent
                              : c.line,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Corner radius as a fraction of the tile, from the icon shape in force.
  ///
  /// Mirrors `folderCornerRadius`'s mapping without reusing it: that one reads
  /// `prefs.folderShape` first, which is a different setting and would make a
  /// folder preference change the look of an icon-theme card.
  static double _shapeFraction(EffectiveTheme theme) =>
      switch (theme.icons.treatment) {
        IconTreatment.circle => 0.5,
        IconTreatment.square => 0.0,
        IconTreatment.squircle => 0.30,
        // A teardrop has no single radius; a circle is the closest honest
        // approximation and beats a square sitting among teardrops.
        IconTreatment.teardrop => 0.5,
        // `original` keeps each app's own artwork, so there is no shape to
        // match — fall back to the neutral default.
        IconTreatment.original => 0.22,
        IconTreatment.roundedSquare => theme.icons.cornerRadius,
      };
}

/// A short coloured word in a card's trailing slot: Get, Update, a price.
///
/// Text rather than an icon because these mean genuinely different things and a
/// download glyph would collapse them into one, which is the ambiguity the
/// status machine exists to remove.
class _Mini extends StatelessWidget {
  const _Mini(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: d.text.label.copyWith(color: color, fontSize: 11.5),
    );
  }
}

/// A quiet paragraph between sections. Not a card, not a row: it is prose, and
/// dressing it as either would suggest it does something when tapped.
class _Note extends StatelessWidget {
  const _Note({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 6),
      child: Text(text, style: d.text.caption.copyWith(height: 1.45)),
    );
  }
}

/// A caption that starts as one tappable line and expands on demand.
///
/// The store screens had grown paragraphs of standing explanation, which read
/// as clutter to everyone except the one person who needed them. Empty states
/// keep the plain [_Note], because an empty state IS the explanation; this is
/// for prose that accompanies content that already speaks for itself.
class _Disclosure extends StatefulWidget {
  const _Disclosure({required this.title, required this.text});

  final String title;
  final String text;

  @override
  State<_Disclosure> createState() => _DisclosureState();
}

class _DisclosureState extends State<_Disclosure> {
  var _open = false;

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => setState(() => _open = !_open),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _open ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: d.colors.textMuted,
                ),
                const SizedBox(width: 6),
                Text(widget.title, style: d.text.caption),
              ],
            ),
            if (_open)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 22),
                child: Text(
                  widget.text,
                  style: d.text.caption.copyWith(height: 1.45),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
