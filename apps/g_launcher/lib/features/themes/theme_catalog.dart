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

  /// On this device right now, so switching to it costs nothing.
  ///
  /// Bundled counts. It ships in the APK, which is the strongest form of being
  /// installed, and a tab called Installed that hid Ubuntu would be absurd.
  /// `updateAvailable` counts too: it is on disk and it applies, the update is
  /// an offer rather than a precondition.
  bool get onDevice =>
      this == CardStatus.bundled ||
      this == CardStatus.installed ||
      this == CardStatus.updateAvailable;

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
/// One thing a distro does that the card can name.
///
/// ─── TWO ON THE CARD, THE REST ON THE DETAIL PAGE ─────────────────────────
///
/// A card carrying five of these is a wall of text people scroll past, so the
/// card shows the first two [exclusive] ones in AUTHORED ORDER. The order they
/// are written in is therefore the order they sell in, which makes it a real
/// editorial decision rather than an accident of the data.
///
/// [exclusive] means the all-access settings cannot reproduce it. That word is
/// the whole price argument: a distro whose list is all `false` is selling a
/// palette, and either needs a feature built or should not be paid.
@immutable
class ThemeFeature {
  const ThemeFeature({
    required this.title,
    required this.body,
    this.exclusive = true,
  });

  final String title;

  /// One short sentence. It is set beside the title on a phone card, so a
  /// second sentence is a second line nobody reads.
  final String body;

  final bool exclusive;
}

class ThemeCard {
  const ThemeCard({
    required this.id,
    required this.name,
    required this.subtitle,
    this.tag,
    required this.tier,
    required this.preview,
    this.specId,
    this.bundled = false,
    this.status = CardStatus.bundled,
    this.sku,
    this.sizeBytes = 0,
    this.remoteVersion = 0,
    this.installedVersion = 0,
    this.features = const [],
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
        subtitle: subtitle,
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
        // ─── THE INDEX WINS, BUT ONLY WHEN IT SPOKE ────────────────────────
        //
        // Three states, and collapsing any two of them is a bug:
        //
        //   null          this entry predates the features block. Keep the
        //                 floor card's rows, which is how the three bundled
        //                 distros stay correct without republishing.
        //   empty list    this entry HAS the block and chose to name nothing.
        //                 An editorial decision, and overriding it with the
        //                 floor card's rows would silently ignore it.
        //   non-empty     use it.
        //
        // The first cut of this used `p.features ?? features` with an empty
        // list treated as absent, which reads fine and makes "publish a distro
        // with no rows" impossible to express.
        features: p.features == null
            ? features
            : [
                for (final f in p.features!)
                  if (f != null)
                    ThemeFeature(
                      title: f.title,
                      body: f.body,
                      exclusive: f.exclusive,
                    ),
              ],
      );

  final String id;

  /// "Ubuntu", "KDE Plasma".
  final String name;

  /// The meta line under the name: "24.04 · GNOME". Set in mono by the card.
  ///
  /// ─── IT WAS CALLED `version`, AND THAT IS WHY IT SHOWED ONE ───────────────
  ///
  /// The field has always held the SUMMARY. It was named `version` and carried
  /// a `'v${p.version}'` fallback for packs whose summary was empty, so the
  /// moment the catalogue shipped empty summaries every card in the store read
  /// `v1787590303`. A pack version is a developer lever: it decides whether an
  /// update is offered and it belongs nowhere near a storefront.
  ///
  /// EMPTY IS A VALID VALUE and renders as nothing. A card with a name and no
  /// meta line is plain; a card with a name and a build number is broken, and
  /// looks it.
  final String subtitle;

  /// The small DE tag shown when the card is neither active nor Pro
  /// ("Plasma", "GNOME", "TUI").
  ///
  /// NULL when unknown, and then no chip is drawn at all. Every CDN card used
  /// to read `Distro` here, which spent the most valuable corner of the card on
  /// the one word all fourteen shared. A chip earns its place by telling the
  /// cards apart, and one that cannot do that is worse than an empty corner.
  final String? tag;

  final ThemeTier tier;
  final ThemePreviewSpec preview;

  /// What this distro does differently. EMPTY IS A VALID STATE and renders as a
  /// card with no feature rows, which is what every CDN pack gets until the
  /// signed index carries a `features` block. A card that invented rows for a
  /// theme it knows nothing about would be lying about a paid product.
  final List<ThemeFeature> features;

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
/// Parse one "#RRGGBB" or "#AARRGGBB" out of the index, or null.
///
/// Strings on the wire because that is how a theme.json authors a colour and
/// how the panel already stores one. Parsed here, once, rather than carried as
/// an int the panel would have to compute and the index would have to explain.
Color? _previewColor(String? hex) {
  if (hex == null) return null;

  var v = hex.trim();
  if (v.startsWith('#')) v = v.substring(1);
  // 6 digits means fully opaque. Same convention `ThemePalette` uses, so a
  // colour reads identically here and in the shell that eventually draws it.
  if (v.length == 6) v = 'FF$v';
  if (v.length != 8) return null;

  final n = int.tryParse(v, radix: 16);
  return n == null ? null : Color(n);
}

/// The card's miniature, built from the index's optional preview block.
///
/// ─── THE RENDERER WAS ALWAYS THERE ──────────────────────────────────────────
///
/// `_ThemePreview` can already draw any of seven layouts from a palette, and
/// the bundled distros have used it since the storefront shipped. The only
/// thing a CDN distro lacked was the DATA: the index carried a title and a
/// summary and no colours, so every downloadable pack fell back to
/// [PreviewLayout.unknown], a flat rectangle. On a paid distro that made the
/// card you charge for the emptiest one on the screen.
///
/// ─── AND IT STILL FALLS BACK, DELIBERATELY ──────────────────────────────────
///
/// Every field is optional and every pack published before the block existed
/// has none of them, so this returns the same flat rectangle for those rather
/// than inventing colours. A guessed palette on a paid product is worse than an
/// honest blank: it would be wrong, and it would look deliberate.
///
/// The gate is `previewShell` plus the two background stops, because those
/// three are what the renderer cannot draw anything without. `bar`, `dock` and
/// `accent` each degrade on their own.
ThemePreviewSpec _previewFromPack(PackInfo p) {
  const fallback = ThemePreviewSpec(
    bg: [Color(0xFF14141A), Color(0xFF0A0A0E)],
    bar: Color(0xFF1E1E26),
    layout: PreviewLayout.unknown,
  );

  final top = _previewColor(p.previewBgTop);
  final bottom = _previewColor(p.previewBgBottom);
  final shell = p.previewShell;
  if (top == null || bottom == null || shell == null) return fallback;

  final accent = _previewColor(p.previewAccent);
  final bar = _previewColor(p.previewBar) ?? fallback.bar;

  return ThemePreviewSpec(
    bg: [top, bottom],
    bar: bar,
    // ─── SHELLS MAP ONTO LAYOUTS, THEY ARE NOT THE SAME LIST ───────────
    //
    // `PreviewLayout` is named for what it DRAWS, not for the shell that wants
    // it: `dockLeft`, `dockBottom`, `iconsCentered`, `iconsLeft`,
    // `dockMagnified`, `terminal`. I first wrote this switch with arms called
    // gnome, plasma and aqua, which do not exist.
    //
    // gnome is `dockLeft` because that is Ubuntu's left rail, which is the
    // GNOME the floor card already draws. plasma is `dockBottom`, its floating
    // Breeze strip. aqua is `dockMagnified`, because the magnification IS the
    // recognisable thing about that desktop, as the enum's own doc says.
    // tiling is `iconsLeft`, which is what Arch's floor card uses.
    //
    // Unknown for a shell string from a newer build, the same contract every
    // other parsed enum here follows: degrade, never throw.
    layout: switch (shell) {
      'gnome' => PreviewLayout.dockLeft,
      'plasma' => PreviewLayout.dockBottom,
      'aqua' => PreviewLayout.dockMagnified,
      'tiling' => PreviewLayout.iconsLeft,
      'tui' => PreviewLayout.terminal,
      _ => PreviewLayout.unknown,
    },
    accent: accent,
    dockBg: _previewColor(p.previewDock),
    // Three tiles, the same count the floor cards use, tinted off the accent so
    // the miniature reads as this distro rather than as a grey mock. Drawn from
    // the palette rather than from the pack's real icons, which are not on the
    // device until it is installed.
    icons: accent == null
        ? const []
        : [
            accent,
            accent.withValues(alpha: 0.72),
            accent.withValues(alpha: 0.48),
          ],
  );
}

/// The index's shell name, as a chip label.
///
/// Returns null for an unknown or absent shell, and the card then draws no chip
/// rather than a placeholder. `previewShell` is absent on every entry published
/// before the preview block existed, so null is the common case today, not an
/// error.
///
/// The labels are the DESKTOP's name, not the engine's: a user reading a card
/// knows what GNOME is and has never heard of `aqua`, which is our word for the
/// metaphor rather than anyone's product. `tui` becomes TUI because that is
/// what the Terminal floor card has always said.
String? _shellTag(String? shell) => switch (shell) {
      'gnome' => 'GNOME',
      'plasma' => 'Plasma',
      'aqua' => 'Desktop',
      'tiling' => 'Tiling',
      'tui' => 'TUI',
      // Includes null, and any shell a newer catalogue names that this build
      // does not know. Degrades to no chip, never to a guess.
      _ => null,
    };

ThemeCard _cardFromPack(PackInfo p) => ThemeCard(
      id: p.packId,
      name: p.title,
      // NO VERSION FALLBACK. See [ThemeCard.subtitle]: an empty summary draws
      // nothing, because the alternative was printing the pack version and it
      // did exactly that on all fourteen distros.
      subtitle: p.summary,
      // The shell, when the entry carries a preview to name it, and otherwise
      // nothing. Derived rather than stored because `PackInfo` has no shell of
      // its own: `previewShell` is the only place the index says what kind of
      // desktop this is.
      tag: _shellTag(p.previewShell),
      tier: p.sku == null ? ThemeTier.free : ThemeTier.pro,
      preview: _previewFromPack(p),
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
        subtitle: '24.04 · GNOME',
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
        features: [
          ThemeFeature(
            title: 'Activities overview',
            body: 'Windows, workspaces and search on one surface.',
          ),
          ThemeFeature(
            title: 'Left vertical dock',
            body: 'Always visible, show-apps button at the foot.',
          ),
          ThemeFeature(
            title: 'Aubergine and orange',
            body: 'Ubuntu Sans, Yaru squircles.',
            exclusive: false,
          ),
        ],
      ),
      ThemeCard(
        id: 'terminal',
        name: 'Terminal',
        subtitle: 'type-to-launch',
        tag: 'TUI',
        tier: ThemeTier.free,
        specId: 'terminal',
        bundled: true,
        preview: ThemePreviewSpec(
          bg: [Color(0xFF080D08), Color(0xFF080D08)],
          bar: Color(0xFF0E1A0E),
          layout: PreviewLayout.terminal,
        ),
        features: [
          ThemeFeature(
            title: 'Everything by command',
            body: 'Launch, search and read device state from a prompt.',
          ),
          ThemeFeature(
            title: 'Scrollback buffer',
            body: 'Your session history stays where you left it.',
          ),
        ],
      ),
      ThemeCard(
        id: 'kde-plasma-6',
        name: 'KDE Plasma',
        subtitle: '6 · Breeze',
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
        features: [
          ThemeFeature(
            title: 'Panel edit mode',
            body: 'Hold the panel, add or remove modules, move it to any edge.',
          ),
          ThemeFeature(
            title: 'Desktop icons',
            body: 'Folder View, with apps placed on the workspace itself.',
          ),
          ThemeFeature(
            title: 'Breeze palette',
            body: 'Noto Sans, squircle icons.',
            exclusive: false,
          ),
        ],
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

/// The "More themes" list. EMPTY, and that is the change.
///
/// ─── AVAILABLE ONLY ─────────────────────────────────────────────────────────
///
/// This held four hand-written teasers: Kali, Garuda, Pop!_OS and Mint. Each
/// tapped to a "coming soon" message, started nothing, and could not be bought,
/// downloaded or applied. They were honest about being unbuyable and still
/// wrong, for three reasons that only became visible once the pipeline worked:
///
///  1. THE GRID ALREADY SHOWS EVERYTHING REAL. [themeCatalogProvider] merges
///     the signed index over the floor and calls `_cardFromPack` for any theme
///     the index advertises that has no floor entry. So the moment Kali is
///     genuinely published it appears ABOVE as a card with a Get button and a
///     price. Anything that could legitimately be listed down here is, by
///     definition, already listed up there.
///  2. THEY CONTRADICTED THE PRICING MODEL. Two of them render a Pro badge, and
///     there is no Pro tier: every launcher FEATURE is free and what is sold is
///     whole distros and icon packs. A badge reading "Pro" on a screen where
///     nothing else does is the one piece of UI still describing the model that
///     was dropped.
///  3. A HARDCODED LIST DRIFTS. These four are a promise made in Dart, so
///     keeping them true means an app release every time the storefront moves.
///     The whole point of the signed index is that it does not.
///
/// Kept as a provider returning nothing rather than deleted, so [ThemeMoreEntry]
/// and `_MoreRow` stay compiled and the section can come back as a real,
/// catalogue-derived list (an "announced but not yet published" block, say)
/// without reconstructing the widgets. `themes_screen` hides the header when
/// this is empty, so today the section simply is not there.
///
/// If nothing wants it back, grep for `ThemeMoreEntry`, `_MoreRow` and
/// `_MoreHeader` and remove the four together.
final themeMoreProvider = Provider<List<ThemeMoreEntry>>(
  (ref) => const <ThemeMoreEntry>[],
);
