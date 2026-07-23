/// The theme storefront's data — one entry per distro the gallery shows.
///
/// **PHASE C: this is now CDN-backed, and the swap happened exactly where the
/// old comment said it would.** [themeCatalogProvider] merges the signed
/// catalogue over a hardcoded floor; the same [ThemeCard]s come out the other
/// end, so the gallery UI did not have to change shape.
///
/// ## The floor is not legacy, it is the offline answer
///
/// [_floorCards] looks like the old hardcoded list and it is, but deleting it
/// would be a bug rather than a cleanup. The storefront is reachable from
/// Settings, Settings is reachable from the drawer, and a gallery that renders
/// EMPTY on a plane — or on a device whose every sync has failed — is a bug
/// report. The bundled themes are genuinely on the device; they should be
/// listed whether or not the network agrees.
///
/// So: the floor is the truth about what is in the APK, the catalogue is the
/// truth about what exists, and a card in both takes its identity from the
/// floor (hand-authored preview, real name) and its STATE from the catalogue
/// (version, price, whether an update is waiting).
///
/// ## What is still missing, and it is deliberate
///
/// A CDN theme with no floor entry has no [ThemePreviewSpec], because the index
/// carries a title and a summary but no colours. Those cards render with a
/// neutral preview drawn from the active chrome rather than invented distro
/// colours: a preview that lies about what a theme looks like is worse than one
/// that admits it does not know. The fix is an optional preview block on the
/// index entry, which is a small format addition and the next thing to do here.
///
/// The preview is deliberately NOT a screenshot. Screenshots rot the moment a
/// distro re-spins, weigh a few hundred KB each over the CDN, and can't reflect
/// the user's own icon-shape choice. A tiny data-driven desktop — a bar colour,
/// a dock, a couple of tiles — is a few bytes, always current, and honest about
/// what the theme actually changes.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/cdn/pack_repository.dart';
import '../../platform/pack_api.g.dart';


enum PreviewLayout {
  /// Ubuntu: left dock of dots + two offset tiles.
  dockLeft,

  /// KDE: a floating bottom dock strip.
  dockBottom,

  /// Fedora: a centred row of tiles.
  iconsCentered,

  /// Pop!_OS / Arch: a left-aligned row of tiles (+ optional corner label).
  iconsLeft,

  /// The TUI shell: a mono prompt on near-black.
  terminal,

  /// A catalogue theme whose colours we do not have yet. Renders as a neutral
  /// placeholder rather than inventing a palette.
  unknown,

  /// Aqua: a menu-bar strip plus a centred floating dock whose middle tile is
  /// drawn larger. The magnification IS the recognisable thing about this
  /// desktop, so the preview shows it rather than a plain bottom strip.
  dockMagnified,
}

/// Where a card actually is, from the device's point of view.
///
/// This is what the storefront branches on. [ThemeTier] below survives because
/// the card's colour treatment reads off it, but it cannot express "downloading"
/// or "an update is waiting" — three values (active/free/pro) were enough for a
/// static catalogue and are not enough for a live one.
///
/// The strings come from native (`PackHostApiImpl.stateOf`) so the rule lives
/// in one place. Anything unrecognised degrades to [available], which is the
/// safe direction: the worst case is offering a download that then reports
/// `notOffered`, rather than hiding a theme the user paid for.
enum CardStatus {
  /// Ships in the APK. Always present, may still update over the CDN.
  bundled,

  /// On disk and current.
  installed,

  /// On disk, and the catalogue advertises a newer version.
  updateAvailable,

  /// In the catalogue, not on disk, and this device may have it.
  available,

  /// In the catalogue, not on disk, and it has to be bought first.
  locked,

  /// Offered, but this build is too old to run it.
  ///
  /// ITS OWN STATE, NOT AN ERROR. The action is "update G Launcher", so a Get
  /// button here fails in a way the user cannot diagnose — they tap, nothing
  /// arrives, and the app looks broken rather than out of date.
  requiresAppUpdate;

  static CardStatus parse(String raw, {required bool unlocked, required bool free}) {
    if (raw == 'requiresAppUpdate') return CardStatus.requiresAppUpdate;
    if (raw == 'bundled') return CardStatus.bundled;
    if (raw == 'installed') return CardStatus.installed;
    if (raw == 'updateAvailable') return CardStatus.updateAvailable;
    // Not installed. Ownership decides whether it is gettable or buyable.
    if (!free && !unlocked) return CardStatus.locked;
    return CardStatus.available;
  }

  bool get isOnDevice =>
      this == bundled || this == installed || this == updateAvailable;
}

/// How the entry reads on the right of its meta row, and what tapping it does.
enum ThemeTier {
  /// The theme currently applied — shows the check dot, not tappable to "apply".
  active,

  /// Bundled or free-over-CDN. Shows its DE tag; tap applies it (once available).
  free,

  /// Paid. Shows the Pro badge; tap explains it's coming, does not fake a paywall.
  pro,
}

/// Everything the preview needs to paint itself. Pure data — the widget that
/// renders it lives in themes_screen.dart.
@immutable
class ThemePreviewSpec {
  const ThemePreviewSpec({
    required this.bg,
    required this.bar,
    required this.layout,
    this.radial = false,
    this.icons = const [],
    this.accent,
    this.dockBg,
    this.corner,
  });

  /// Two stops. Radial for Ubuntu's spotlight, linear otherwise.
  final List<Color> bg;
  final bool radial;

  /// The top-bar strip colour.
  final Color bar;

  final PreviewLayout layout;

  /// Tile colours, in order. 2–3 of them.
  final List<Color> icons;

  /// Dock's first-dot / highlight colour (Ubuntu's orange launcher).
  final Color? accent;

  /// The dock strip's own fill (left dock or bottom dock).
  final Color? dockBg;

  /// A mono corner label, e.g. Arch's `[hyprland]`.
  final String? corner;
}

@immutable
class ThemeCard {
  const ThemeCard({
    required this.id,
    required this.name,
    required this.version,
    required this.tag,
    required this.tier,
    required this.preview,
    this.specId,
    this.bundled = false,
    this.status = CardStatus.bundled,
    this.sku,
    this.sizeBytes = 0,
    this.remoteVersion = 0,
    this.installedVersion = 0,
  });

  /// Where this card is right now. Defaults to [CardStatus.bundled] so a floor
  /// card with no catalogue entry reads correctly offline.
  final CardStatus status;

  /// The Play product that unlocks it. null = free.
  ///
  /// PRESENTATION ONLY. Whether the user OWNS it is Play's answer, already
  /// folded into [status] by native. Never re-derive ownership from this.
  final String? sku;

  /// Payload size, for "1.2 MB" under the Get button. 0 = unknown.
  final int sizeBytes;

  final int remoteVersion;
  final int installedVersion;

  /// The id the pack pipeline knows this by.
  ///
  /// [specId] for anything that maps to a real ThemeSpec, [id] otherwise. The
  /// two differ on the floor cards ('ubuntu' vs 'ubuntu-24-04') and installing
  /// under the wrong one silently downloads nothing, because the catalogue has
  /// never heard of it.
  String get packIdOrSpec => specId ?? id;

  ThemeCard withPack(PackInfo p) => ThemeCard(
        id: id,
        name: name,
        version: version,
        tag: tag,
        // Recomputed: a floor card authored as `pro` before billing existed
        // must follow the catalogue, not its own stale guess.
        tier: p.sku == null ? ThemeTier.free : ThemeTier.pro,
        preview: preview,
        specId: specId,
        bundled: bundled,
        status: CardStatus.parse(
          p.state,
          unlocked: p.unlocked,
          free: p.sku == null,
        ),
        sku: p.sku,
        sizeBytes: p.sizeBytes,
        remoteVersion: p.version,
        installedVersion: p.installedVersion,
      );

  final String id;

  /// "Ubuntu", "KDE Plasma".
  final String name;

  /// The meta line under the name: "24.04 · GNOME". Set in mono by the card.
  final String version;

  /// The small DE tag shown when the card is neither active nor Pro
  /// ("Plasma", "GNOME", "TUI").
  final String tag;

  final ThemeTier tier;
  final ThemePreviewSpec preview;

  /// The bundled ThemeSpec's `id` this card corresponds to, if any. Used to
  /// light up the active border. Only Ubuntu has one today.
  final String? specId;

  /// True for the theme that ships inside the APK (Ubuntu). Used as the active
  /// fallback when [specId] doesn't string-match the loaded spec, so the active
  /// ring never simply fails to appear.
  final bool bundled;
}

/// A row in the "More themes" list — a swatch, a name, and either a Get button
/// (free, arrives over the CDN) or a Pro badge.
@immutable
class ThemeMoreEntry {
  const ThemeMoreEntry({
    required this.name,
    required this.subtitle,
    required this.swatch,
    required this.pro,
  });

  final String name;
  final String subtitle;
  final List<Color> swatch; // 2 gradient stops
  final bool pro;
}

// ─────────────────────────────────────────────────────────────────────────────
// The catalog. Colours lifted verbatim from the mockup's inline styles so the
// previews match the storefront pixel-for-pixel.
// ─────────────────────────────────────────────────────────────────────────────

const _ubuntuOrange = Color(0xFFE95420);

/// The gallery, catalogue merged over the floor.
///
/// ORDER IS FLOOR FIRST, THEN THE REST. The themes that are actually on the
/// device sit at the top of the grid in a stable hand-authored order, and
/// downloadable ones follow. Sorting the whole thing by the catalogue would let
/// a publish reshuffle the user's own grid, which reads as the app losing its
/// place.
final themeCatalogProvider = FutureProvider<List<ThemeCard>>((ref) async {
  final packs = await ref.watch(catalogueProvider.future);

  // Themes only. The catalogue also carries brand and hero packs, which are
  // plumbing the storefront has no business showing.
  final byId = <String, PackInfo>{
    for (final p in packs)
      if (p.packType == 'theme') p.packId: p,
  };

  final merged = <ThemeCard>[];
  final claimed = <String>{};

  for (final card in _floorCards) {
    // The merge key is specId, not id: the card is 'ubuntu' and the pack is
    // 'ubuntu-24-04'. Getting this backwards produces a gallery where every
    // bundled theme also appears a second time as a download.
    final key = card.specId;
    final pack = key == null ? null : byId[key];
    if (pack != null) claimed.add(key!);
    merged.add(pack == null ? card : card.withPack(pack));
  }

  for (final entry in byId.entries) {
    if (claimed.contains(entry.key)) continue;
    merged.add(_cardFromPack(entry.value));
  }

  return merged;
});

/// Bundled themes only, resolved SYNCHRONOUSLY.
///
/// Exists for initial setup, which asks "choose your desktop" before the user
/// has a desktop. Two reasons it does not use [themeCatalogProvider]:
///
///  1. That provider is async, so the distro row would be empty for a frame or
///     two on a cold first run. An empty row in a wizard step whose entire
///     content is that row reads as a broken screen, and it is the FIRST screen
///     anyone sees.
///  2. Setup has no business offering downloads. Everything here is already in
///     the APK and applies instantly, which is what makes the step feel like a
///     switch rather than a purchase.
///
/// Filtered the same way setup filtered it before the CDN swap: bundled, and
/// carrying a real ThemeSpec id to select.
final bundledThemeCardsProvider = Provider<List<ThemeCard>>(
  (ref) => _floorCards.where((c) => c.bundled && c.specId != null).toList(),
);

/// A catalogue theme with no floor entry.
///
/// The preview is intentionally BLANK rather than invented. The index carries a
/// title and a summary but no colours, so any palette put here would be a guess,
/// and a preview that misrepresents a theme is worse than one that admits it
/// does not know yet. `_ThemePreview` renders [PreviewLayout.unknown] as a
/// neutral chrome-derived placeholder.
ThemeCard _cardFromPack(PackInfo p) => ThemeCard(
      id: p.packId,
      name: p.title,
      version: p.summary.isEmpty ? 'v${p.version}' : p.summary,
      tag: 'Theme',
      tier: p.sku == null ? ThemeTier.free : ThemeTier.pro,
      preview: const ThemePreviewSpec(
        bg: [Color(0xFF14141A), Color(0xFF0A0A0E)],
        bar: Color(0xFF1E1E26),
        layout: PreviewLayout.unknown,
      ),
      specId: p.packId,
      status: CardStatus.parse(p.state, unlocked: p.unlocked, free: p.sku == null),
      sku: p.sku,
      sizeBytes: p.sizeBytes,
      remoteVersion: p.version,
      installedVersion: p.installedVersion,
    );

/// The catalogue floor: what the Themes screen shows before the CDN index has
/// ever been read, and what it falls back to offline.
///
/// ─── THESE MUST AGREE WITH theme_registry.bundledThemes ─────────────────────
///
/// `bundled: true` means the theme.json is IN THE APK. Three of these claimed
/// it and were wrong: Aqua, Arch and Fedora kept `bundled: true` and a
/// `specId` after their asset directories were deleted, and every card here
/// defaults to `CardStatus.bundled`, so the screen offered to apply them.
/// `bundledAssetFor` resolves an unknown id to Ubuntu, so tapping Aqua
/// silently applied Ubuntu: no error, no message, just the wrong desktop.
///
/// The rule, so it cannot drift again: a card is `bundled` if and only if its
/// id is a key in `bundledThemes`. Everything else is `available` and arrives
/// over the CDN, which is also the free/paid line (bundled implies free).
const _floorCards = <ThemeCard>[
      ThemeCard(
        id: 'ubuntu',
        name: 'Ubuntu',
        version: '24.04 · GNOME',
        tag: 'GNOME',
        tier: ThemeTier.free,
        specId: 'ubuntu-24-04',
        bundled: true,
        preview: ThemePreviewSpec(
          bg: [Color(0xFF622A4C), Color(0xFF2C0A22)],
          radial: true,
          bar: Color(0xFF1A171B),
          layout: PreviewLayout.dockLeft,
          dockBg: Color(0xCC201B21), // rgba(32,27,33,.8)
          accent: _ubuntuOrange,
          icons: [_ubuntuOrange, Color(0xFF3A6EA5)],
        ),
      ),
      ThemeCard(
        id: 'terminal',
        name: 'Terminal',
        version: 'type-to-launch',
        tag: 'TUI',
        tier: ThemeTier.free,
        specId: 'terminal',
        bundled: true,
        preview: ThemePreviewSpec(
          bg: [Color(0xFF080D08), Color(0xFF080D08)],
          bar: Color(0xFF0E1A0E),
          layout: PreviewLayout.terminal,
        ),
      ),
      ThemeCard(
        id: 'kde-plasma-6',
        name: 'KDE Plasma',
        version: '6 · Breeze',
        tag: 'Plasma',
        tier: ThemeTier.free,
        specId: 'kde-plasma-6',
        bundled: true,
        preview: ThemePreviewSpec(
          bg: [Color(0xFF1B2A3A), Color(0xFF0E1620)],
          bar: Color(0xFF31363B),
          layout: PreviewLayout.dockBottom,
          dockBg: Color(0xE62A2E33), // Breeze panel
          accent: Color(0xFF3DAEE9), // Breeze blue
          icons: [Color(0xFF3DAEE9), Color(0xFF1D99F3), Color(0xFF27AE60)],
        ),
      ),
      // The paid distros (Kali, Garuda, Pop!_OS) live ONLY in themeMoreProvider
      // below, as coming-soon rows, until three things ship together: their
      // theme packs on the CDN, the Play billing loop, and the render bridge
      // that lets a downloaded theme.json actually paint. Until then a real card
      // could only dead-end: `available` installs a pack that does not exist,
      // `locked` opens a purchase for a theme that cannot render. A coming-soon
      // row promises nothing it cannot keep, which is the only honest state for
      // a distro that is real but not yet buildable end to end.
      //
      // Aqua, Fedora and Arch were removed here for the same reason: they were
      // `pro/available` grid cards with no pack, no SKU and no render path, so
      // every tap produced "needs to be purchased first" with nowhere to buy.
    ];

/// The coming-soon teaser. Every entry taps to a "coming soon" message and
/// starts no download and no purchase, so this list is safe to ship before the
/// CDN, billing and render paths exist. The three `pro` entries are the locked
/// paid lineup and match the Play product ids already created
/// (distro_kali, distro_garuda_dragonized, distro_pop_cosmic); Mint is a planned
/// free add. Nothing here can dead-end because nothing here promises a button.
final themeMoreProvider = Provider<List<ThemeMoreEntry>>((ref) => const [
      ThemeMoreEntry(
        name: 'Kali Linux',
        subtitle: 'Dragon · undercover mode',
        swatch: [Color(0xFFA80030), Color(0xFF5E0019)],
        pro: true,
      ),
      ThemeMoreEntry(
        name: 'Garuda Dr460nized',
        subtitle: 'Neon · Dragonized',
        swatch: [Color(0xFFB44BE8), Color(0xFF5E1E8C)],
        pro: true,
      ),
      ThemeMoreEntry(
        name: 'Pop!_OS',
        subtitle: '22.04 · COSMIC',
        swatch: [Color(0xFF48B9C7), Color(0xFF1F6F79)],
        pro: true,
      ),
      ThemeMoreEntry(
        name: 'Linux Mint',
        subtitle: '22 · Cinnamon',
        swatch: [Color(0xFF0F4C2D), Color(0xFF082B19)],
        pro: false,
      ),
    ]);
