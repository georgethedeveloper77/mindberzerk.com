import 'package:collection/collection.dart';

import '../../engine/wallpaper_framing.dart';
import '../../platform/launcher_api.g.dart' as api;

/// User overrides for ONE theme.
///
/// The rule from plan §5.3: the theme provides defaults, the user's choices
/// always win, and they are stored PER THEME — so switching Ubuntu → KDE → back
/// to Ubuntu returns you to your Ubuntu setup rather than wiping it.
///
/// That is why nearly every field here is nullable. **null means "inherit from
/// the theme"**, and it is not the same as a default value. If [cols] were
/// non-null with a default of 4, then a theme that ships a 5-column grid would
/// be silently overridden by a preference the user never set. Nullable is the
/// whole design.
/// "No icon pack at all", for [LauncherPrefs.iconPackId] and
/// [LauncherPrefs.iconBrandPackId].
///
/// ─── WHY A SENTINEL AND NOT A THIRD FIELD ───────────────────────────────────
///
/// Both fields are nullable and null already MEANS something: "whatever this
/// distro names". `EffectiveTheme.resolve` reads it that way, and the icons
/// screen relies on it, writing null rather than the distro's own pack id so a
/// republished theme naming a different pack is followed rather than pinned to
/// last month's answer.
///
/// So there was no way to say "none". Every resolve ended at
/// `defaultLinePackFor`, which returns a name for every theme, and the brand
/// tier could not be switched off. That is the state the setup icon step needs
/// to offer: each app's own artwork, in the distro's shape, with no pack over
/// the top.
///
/// A third field would mean four edits in this file (constructor, [copyWith],
/// [clearing], both JSON directions) to express what one reserved string does,
/// and would let the two disagree. The sentinel costs nothing: it round-trips
/// through JSON as an ordinary value, `clearing` still resets it, and
/// `iconCacheId` already reads the RESOLVED pack rather than the pref, so the
/// native cache re-keys for free.
///
/// ─── AND WHY IT CANNOT COLLIDE ──────────────────────────────────────────────
///
/// `PackManifest.isSafePackId` rejects it, so no pack can ever carry this id:
/// it cannot be published, downloaded or installed. A reserved value that the
/// rest of the system is structurally incapable of producing is the only kind
/// worth having.
///
/// BOTH FIELDS TAKE IT, and they have to. Setting it on the brand tier alone
/// would leave a hero pack resolving, so "app icons" would mean hand-drawn art
/// for the handful a hero pack covers and generated icons for everything else,
/// which is neither of the two things the step offers.
const kNoIconPack = '__none__';

class LauncherPrefs {
  const LauncherPrefs({
    this.dockSide,
    this.dockGridButton,
    this.topBar,
    this.desktopIcons,
    this.panelModules,
    this.panelHeight,
    this.panelSide,
    this.rows,
    this.cols,
    this.drawerCols,
    this.drawerSearchPosition,
    this.drawerScrollStyle,
    this.drawerGrouping,
    this.drawerSortMode,
    this.drawerSlots = const [],
    this.drawerSlotCols,
    this.drawerSlotRows,
    this.drawerPageCount,
    this.themeMode,
    this.accentId,
    this.layoutPreset,
    this.deskletGridVersion,
    this.topBarSide,
    this.topBarStats,
    this.surfaceOpacity,
    this.dockOpacity,
    this.drawerOpacity,
    this.barOpacity,
    this.panelOpacity,
    this.panelBlur,
    this.panelTint,
    this.panelRadius,
    this.badgeStyle,
    this.workspaceCount,
    this.verboseBoot,
    this.iconSizeDp,
    this.iconTreatment,
    this.iconPackId,
    this.iconBrandPackId,
    this.systemIconPack,
    this.cornerRadius,
    this.labelLines,
    this.textScale,
    this.displayFont,
    this.monoFont,
    this.gestures = const {},
    this.hiddenApps = const {},
    this.hiddenAppsSearchable,
    this.favourites = const [],
    this.dockExcluded = const {},
    this.homeItems = const [],
    this.folders = const [],
    this.drawerFolders = const [],
    this.desklets = const [],
    this.dismissedSuggestions = const {},
    this.folderCols,
    this.folderRows,
    this.folderShape,
    this.folderOrderCustom,
    this.wallpapers = const [],
    this.wallpapersHidden = const {},
    this.wallpaperLock,
    this.wallpaperCurrent,
    this.wallpaperRotationMinutes,
    this.wallpaperRotationSource,
    this.wallpaperFit,
    this.wallpaperFraming = const {},
    this.wallpaperOrder = const [],
    this.wallpaperInitialized = false,
    this.deskletsInitialized = false,
    this.homeInitialized = false,
  });

  /// Bumped when the JSON shape changes incompatibly. Read it before parsing;
  /// an unknown future version should reset to defaults, not throw on the home
  /// screen.
  ///
  /// Still 1: `dockGridButton`, `workspaceCount`, `wallpapersHidden`,
  /// `displayFont` and `monoFont` are additive and `fromJson` tolerates their
  /// absence, so old prefs files parse unchanged. Additive fields never bump
  /// the schema.
  ///
  /// The font pair is worth a word because it is ALSO promoted to GlobalPrefs,
  /// and promotion is the case that usually forces a bump there: a field that
  /// already held per-theme values loses them when it moves buckets, which is
  /// what `withV2PromotionsFrom` exists to carry across. These two have never
  /// held a value anywhere, so there is nothing to carry and nothing to bump.
  static const int schemaVersion = 1;

  // --- layout (null = inherit from ThemeSpec) ---
  final String? dockSide; // 'left' | 'bottom' | 'off'

  /// Where the Activities grid button sits in the dock.
  /// 'start' | 'end' | 'off'. null = theme decides (Ubuntu: 'end').
  ///
  /// Exists because the grid button is the most-tapped thing in the dock, and
  /// the far end of a tall left dock is a stretch on a big phone.
  final String? dockGridButton;

  final bool? topBar;

  /// The user's answer to "icons on my desktop", and ONLY as a way to say no.
  ///
  /// Null inherits the distro. True is indistinguishable from null, because a
  /// distro with no grid stays without one either way: `LayoutResolver` ANDs
  /// this with the theme's capability rather than letting it win outright.
  /// Stored per theme like every other override here, so turning icons off on
  /// Plasma leaves Mint's alone.
  final bool? desktopIcons;

  /// The panel the user built, as module names in order. Null inherits the
  /// distro's.
  ///
  /// ─── A WHOLE PANEL, NOT A DIFF ──────────────────────────────────────────
  ///
  /// Storing "removed the tray" would have to survive the distro later changing
  /// its own panel, and there is no honest answer to what a removal means once
  /// the thing it removed is no longer there. A replacement has no such
  /// question: while this is set, it IS the panel, and clearing it hands the
  /// panel back to the distro whole.
  ///
  /// Names rather than indices, because `PanelModule.name` round-trips through
  /// the same `parse` a theme.json goes through, and an unknown name written by
  /// a newer build is dropped exactly as an unknown module in a theme is.
  ///
  /// An EMPTY list is meaningful and distinct from null: it is a panel the user
  /// has emptied. `PanelSpec.fromJson` drops an empty panel at parse, which is
  /// right for an authored theme and wrong here, so the resolver keeps it.
  final List<String>? panelModules;

  /// Panel thickness in dp, or null for the distro's own.
  ///
  /// SEPARATE FROM [panelModules] rather than folded into it, because the two
  /// are set independently: someone can thicken the panel without removing a
  /// module, and clearing the modules back to the distro's should not silently
  /// throw away a height they chose. Reset in the edit bar clears both, which
  /// is the one place they move together.
  final double? panelHeight;

  /// Which edge the panel sits on: 'top', 'bottom', 'left', 'right', or null
  /// for the distro's own.
  ///
  /// A STRING, like [dockSide] and [topBarSide] beside it, and for the reason
  /// their docs give: a value written by a newer build has to survive a round
  /// trip through an older one rather than crashing it, and an enum index would
  /// not. Every read goes through a parser that falls back.
  ///
  /// SEPARATE from [topBarSide], which is a different panel. A GNOME theme's
  /// bar and a Plasma panel can both exist in one app and neither should move
  /// when the other does.
  final String? panelSide;
  final int? rows;
  final int? cols;

  /// The drawer is denser than home by convention — more columns, smaller
  /// icons. Separate from [cols] because tying them together means widening the
  /// drawer also thins out your home screen, which nobody wants.
  final int? drawerCols;

  /// Where the drawer's search field sits: 'top' | 'bottom'. null = the theme
  /// decides, and the grid drawers resolve that to 'bottom' (thumb-reachable,
  /// matching the One UI search page); a theme may pin it to 'top' for an
  /// authentic GNOME feel. Only the grid drawers (GNOME, KDE, macOS) read this.
  /// Tiling and TUI own their own input placement and ignore it.
  final String? drawerSearchPosition;

  /// How the drawer moves: 'vertical', 'pages', or 'cube'. null means "the
  /// user has never chosen", which is a real state, not a value: it lets the
  /// distro's own authored default apply, and `LayoutResolver` falls to
  /// 'pages' when the distro has no opinion either. (This doc once claimed
  /// vertical was the default while every read site said `?? 'pages'`; the
  /// read sites were what users actually got, and the resolver now writes
  /// that down once.)
  ///
  /// Vertical is one long scroll — what every Android drawer does, and what
  /// nobody notices. Pages and cube are paged; the cube is the old
  /// Nova/CyanogenMod rotation. Both are pure transforms over already-built
  /// pages, so they cost nothing at runtime — and they are the kind of thing
  /// people screenshot, which is what makes them worth having at all.
  final String? drawerScrollStyle;

  /// How the drawer's app list is GROUPED. null | 'none' | 'az'.
  ///
  /// ─── WHY THIS IS NOT A FOURTH drawerScrollStyle VALUE ──────────────────
  ///
  /// It was going to be, and that would have been a bug in the settings UI
  /// rather than in the code. A-to-Z means letter headers, and letter headers
  /// need a continuous scroll to sit in: there is nowhere to put "M" on a page
  /// that turns. So as a fourth value of drawerScrollStyle, picking 'az' would
  /// have had to silently mean "and also stop being paged", and two of the
  /// four options in one row would have quietly disabled each other.
  ///
  /// Grouping is therefore ORTHOGONAL to layout, and only meaningful when
  /// drawerScrollStyle is the list. Settings hides this row otherwise.
  final String? drawerGrouping;

  /// How the drawer's loose apps are ORDERED.
  /// null | 'az' | 'mostUsed' | 'recent' | 'custom'. null = alphabetical.
  ///
  /// 'mostUsed' ranks by the frecency in UsageStats.ranked, 'recent' by
  /// UsageStats.recent; both fall back to alphabetical for apps that have
  /// never been launched. 'custom' switches the drawer to the sparse slot
  /// arrangement in [drawerSlots]. Per theme like everything else here, and
  /// values from a newer build degrade to alphabetical rather than throwing.
  final String? drawerSortMode;

  /// The CUSTOM arrangement: sparse (page, index) slots holding apps and
  /// folders, interleaved, One UI style. Gaps are legal and deliberate;
  /// "Clean up pages" compacts them. Empty means Custom has never been seeded
  /// for this theme. All mutation lives in `DrawerSlots`; nothing else writes
  /// this list.
  final List<DrawerSlot> drawerSlots;

  /// The grid the slots were laid against, FROZEN when Custom was entered.
  ///
  /// A sparse position is meaningless against a capacity that reflows with
  /// screen width, so while in Custom the drawer renders THIS grid and the
  /// responsive column count (and [drawerCols]) do not apply. null until the
  /// first seed.
  final int? drawerSlotCols;
  final int? drawerSlotRows;

  /// How many pages the CUSTOM drawer has, when the user has grown it past
  /// what its contents need.
  ///
  /// null means "exactly as many as the slots require", which is the resting
  /// state. The "+" beside the page dots writes a larger number, and that is
  /// the only thing that keeps an empty page alive.
  ///
  /// This replaces an always-on trailing empty page. That page existed so a
  /// drag had somewhere to go, and it worked, but it also meant the drawer
  /// permanently ended on a blank screen nobody asked for. Modern launchers
  /// make growing the drawer an explicit act and then remember it, which is
  /// both less surprising and less to explain.
  ///
  /// Cleared by Clean up pages, along with the gaps: compacting the
  /// arrangement and then leaving three empty pages hanging off the end would
  /// not be a clean up.
  final int? drawerPageCount;

  /// 'system' | 'light' | 'dark'. Null means system, so an existing prefs file
  /// with no opinion behaves the way a phone expects without a migration.
  ///
  /// GLOBAL, not per theme: see [GlobalPrefs]. Wanting a light phone is a fact
  /// about the person and the room they are in, not about which distro they
  /// are imitating this week.
  ///
  /// A theme with no `paletteLight` block ignores this and stays dark. That is
  /// deliberate; see [ThemeSpec.paletteLight].
  final String? themeMode;

  /// The [ThemeAccent] id this user picked, per theme.
  ///
  /// ─── AN ID, AND NEVER REWRITTEN BY THE ENGINE ───────────────────────────
  ///
  /// `EffectiveTheme.accent` looks it up in the distro's authored list and
  /// returns null when nothing matches, which leaves the distro's own accent on
  /// screen. It deliberately does NOT clear this field: a pack update that
  /// retires an id would otherwise silently discard a choice that becomes valid
  /// again the moment the colour comes back.
  ///
  /// Null means the distro's default, which is every theme today.
  final String? accentId;

  /// The [ThemeLayoutPreset] id this user picked, per theme.
  ///
  /// Null means the distro's own layout, which is every theme today.
  ///
  /// ─── SWITCHING ONE CLEARS THE OVERRIDES IT OWNS ─────────────────────────
  ///
  /// Not enforced here, because this is storage. It is enforced at the one
  /// place a preset is chosen, and the reason is that `LayoutResolver` reads
  /// `prefs.X ?? layout.X` for the dock, the bar, the grid and the panel: a
  /// user who has ever moved any of those would pick a new preset and watch
  /// nothing happen, because their old override still wins over the new
  /// layout. Clearing is the only option that keeps the picker honest without
  /// scoping every layout pref per preset, which would multiply the stored
  /// surface by the number of presets for a feature nobody has used yet.
  final String? layoutPreset;

  /// Which coordinate system [desklets] are stored in.
  ///
  /// null or 0  the ICON grid, `layout.grid` cols by rows
  /// 1          the FINE desklet grid, cols x2 by rows x3
  ///
  /// Exists because the desklet grid was split off from the icon grid, and
  /// every stored `col`, `row`, `spanX` and `spanY` had to be rescaled once.
  /// Without a marker the migration would run on every load and a desklet would
  /// double in size forever; with it, it runs exactly once per theme.
  final int? deskletGridVersion;

  /// 'top' | 'bottom'. Null inherits the distro.
  ///
  /// PER THEME, not global: which edge the shell bar sits on is exactly the
  /// kind of thing that makes a desktop recognisable, the same reasoning that
  /// keeps `dockSide` and `topBar` per theme.
  final String? topBarSide;

  /// Live readouts in the bar. Null inherits the distro.
  final bool? topBarStats;

  /// How solid the launcher's own surfaces are, 0.6 to 1.0. Null is 1.0.
  ///
  /// ─── WHY THIS IS GLOBAL AND WHY IT HAS A FLOOR ──────────────────────────
  ///
  /// Global because it is a statement about how much wallpaper someone wants to
  /// see, which does not change when they switch distro. It sits beside icon
  /// shape and text scale in [GlobalPrefs] for the same reason.
  ///
  /// Floored at 0.6 because below that a settings page stops being readable
  /// over a photograph: the rows are dense text and the wallpaper underneath is
  /// arbitrary. A slider that can be dragged into unusability is a slider that
  /// will be, and the person doing it will read the result as the app being
  /// broken rather than as their own setting.
  final double? surfaceOpacity;

  // ── PER-SECTION OPACITY ──────────────────────────────────────────────────
  //
  // Each is null by default and FALLS BACK TO [surfaceOpacity], so the single
  // slider still governs everything until someone deliberately splits one out.
  // Nobody's phone changes on upgrade, and a user who never opens these three
  // rows keeps exactly the behaviour they have.
  //
  // The earlier reasoning against per-section opacity was that a settings page
  // and a sheet over it disagreeing about how solid they are reads as a
  // rendering fault. That is why the split covers the surfaces that are
  // PERMANENT chrome over the wallpaper.
  //
  // ─── AND WHY PANELS JOINED THEM, WITH THE RISK WRITTEN DOWN ────────────
  //
  // Sheets, dialogs and menus were deliberately excluded on exactly that
  // ground. They are now [panelOpacity] below, which reopens the case the
  // paragraph above closed: a sheet CAN now be set to disagree with the page
  // under it.
  //
  // Two things make that acceptable rather than a reversal. It is opt-in, and
  // it falls back to [surfaceOpacity], so no phone changes and the stacking
  // stays consistent until someone deliberately splits it. And the setting
  // that people actually wanted from this group is not the opacity at all: it
  // is the blur and the tint, which have no equivalent on a flat page and
  // therefore nothing to disagree with. Opacity comes along because a panel
  // section that governed everything about a panel EXCEPT how solid it is
  // would be the odd one out.
  //
  // Resolved in [EffectiveTheme], never read raw: a widget reading these would
  // miss the fallback and paint its section solid the moment the user moved
  // the main slider without having touched that section.

  /// The dock or task strip. Multiplied INTO the palette's own dock alpha
  /// rather than replacing it: Ubuntu authors 0xBD deliberately, and
  /// overwriting it would make every distro's dock equally solid.
  final double? dockOpacity;

  /// The app drawer's full-screen wash. Its own setting because the drawer is
  /// the one surface people genuinely disagree about: a solid drawer is easier
  /// to read, and a translucent one is half the reason to run this launcher.
  final double? drawerOpacity;

  /// The top bar or panel. Inert on GNOME, whose bar paints no fill at all,
  /// and live on Plasma's panel, the tiling waybar and Aqua's frosted menu
  /// bar. Inert-where-inapplicable is the same honest arrangement
  /// `drawerScrollStyle` already has, and it needs no clamping code.
  final double? barOpacity;

  // ── PANELS ───────────────────────────────────────────────────────────────
  //
  // Every floating glass surface: sheets, dialogs, the desktop menu, the
  // desklet menu. ONE material, so one set of settings; a dialog that blurred
  // differently from the sheet it opened from would read as two design
  // languages in one app.
  //
  // All four are null by default and every default below reproduces exactly
  // what GlassPanel hardcoded before this existed, so an untouched install
  // renders identically.
  //
  // Resolved in [EffectiveTheme], never read raw, same contract as the
  // opacities above.

  /// How solid a floating panel is. Falls back to [surfaceOpacity].
  final double? panelOpacity;

  /// Backdrop blur radius, 0 to 24. Default 18.
  ///
  /// ZERO IS A REAL SETTING, not just the low end. [BackdropFilter] rasterises
  /// what is behind it and this app targets budget Infinix and Tecno hardware;
  /// GlassPanel's own doc already names the sigma as the first thing to cut if
  /// the launcher ever janks. Exposing it means the person on the slow phone
  /// can cut it without waiting for a release, and a tinted opaque panel still
  /// looks deliberate.
  final double? panelBlur;

  /// How much of the distro's own colour comes through, 0 to 1. Default 0.72.
  ///
  /// STRENGTH, NOT HUE, and the distinction is deliberate. A colour picker
  /// here would let someone paint a GNOME desktop's sheets pink, which is the
  /// same argument desklet_settings makes for offering a short swatch list
  /// rather than an arbitrary hex: this launcher's whole claim is that a
  /// distro owns its colour. Zero is neutral grey, one is fully the distro's.
  final double? panelTint;

  /// Corner radius for every floating panel, in logical pixels. Default 16,
  /// which is GRadius.lg, the value the sheet and the dialog both hardcoded.
  final double? panelRadius;

  // ── NOTIFICATION BADGES ──────────────────────────────────────────────────

  /// 'auto' | 'dot' | 'count' | 'off'. null means auto.
  ///
  /// A STRING, not an enum, and for once the reason is not Pigeon: this never
  /// crosses the bridge. It is the same rule every other stored choice in this
  /// class follows (`iconTreatment`, `drawerScrollStyle`, `folderShape`) so
  /// that a value written by a NEWER build lands in an older one as an unknown
  /// string and falls through to auto, rather than failing to parse and taking
  /// the whole prefs file down with it.
  ///
  /// Auto is the distro's own answer: a dot under GNOME, a number under Plasma,
  /// nothing on a tiling or terminal shell. See `badgeStyleFor`.
  final String? badgeStyle;

  /// How many vertical workspaces the desktop has, 1–5. null = default (3).
  ///
  /// Purely a user preference, not a themed default: the authentic empty
  /// desktop has no icons, so nothing in the ThemeSpec has an opinion about how
  /// many pages there should be. Stored per-theme all the same, so it rides the
  /// same reset/switch machinery as everything else.
  final int? workspaceCount;

  /// Play the full verbose boot log every time the shell opens, not only on
  /// first run. null = off (a quick splash instead). This is the geek toggle:
  /// leave it on for Arch, off for Ubuntu, and each theme remembers, because it
  /// rides the same per-theme store as every other override.
  final bool? verboseBoot;

  final double? iconSizeDp;

  // --- icons ---
  /// The user's shape choice. Overrides the theme's treatment entirely.
  final String? iconTreatment; // matches api.IconTreatment names

  /// The hero icon pack to draw with, overriding the theme's own `heroPack`.
  /// null = the theme decides, which is the out-of-box behaviour.
  ///
  /// ─── WHY THIS EXISTS AS A SEPARATE SETTING ────────────────────────────────
  ///
  /// Because icon packs are sold separately from distros. `icons_pop_cosmic` is
  /// its own Play product precisely so someone can run the Kali desktop with
  /// Pop!_OS icons, and `ThemeSpec.icons.heroPack` cannot express that: it is
  /// authored by whoever made the theme, so buying an icon pack would do
  /// nothing until the theme's author happened to name it. A pack that cannot
  /// be applied is a refund.
  ///
  /// PER-THEME, like everything else in this file, and that is the right shape
  /// rather than an accident of where it landed. "Kali desktop, Pop icons" is a
  /// statement about the Kali desktop; switching to Garuda and back should
  /// return you to it, not carry it along.
  ///
  /// This is an id, NOT a path. `EffectiveTheme.resolve` substitutes it into the
  /// `IconStyle` it hands native, and it MUST also be folded into
  /// `iconCacheId` — a change to the pack that does not change the cache key is
  /// invisible: the correct icons render once for anything not already cached
  /// and every previously-seen app keeps its old bitmap forever. That failure
  /// looks exactly like the setting being unwired, which is why it costs a day
  /// to find.
  final String? iconPackId;

  /// The OUTLINE set underneath the hero art: one of the fourteen line packs.
  ///
  /// ─── WHY THIS IS NOT [iconPackId] ────────────────────────────────────────
  ///
  /// It was, and that was the bug. The colour strip wrote every choice into
  /// [iconPackId], which `EffectiveTheme.resolve` routes to `IconStyle.heroPack`
  /// and native hands to `HeroIconResolver`. That class wants a pack.json with
  /// an `icons` map of image filenames; a derived line pack is `extends` and
  /// `tint` and nothing else, so it parsed to null, drew nothing, and the brand
  /// tier carried on rendering the distro's own colour. Applying any of the
  /// thirteen other colours completed, updated the card, showed a toast, and
  /// changed not one icon.
  ///
  /// ─── AND WHY TWO FIELDS RATHER THAN ONE PLUS A TIER FLAG ─────────────────
  ///
  /// Because a phone can hold both, and the icon pipeline is built to: hero art
  /// on top for the forty apps somebody drew by hand, the line set underneath
  /// for the several hundred it does not cover, the generator for the rest.
  /// Papirus over Mint green is a reasonable thing to want and it is now
  /// expressible. One field carrying a tier tag would make choosing either one
  /// silently discard the other.
  ///
  /// Same scoping as [iconPackId], per theme, for the same reason: "Kali
  /// desktop, Pop outlines" is a statement about the Kali desktop.
  ///
  /// An id, not a path. `resolve` substitutes it into `IconStyle.brandPack`,
  /// which `iconCacheId` already reads, so overriding the VALUE rekeys the
  /// native cache for free and no cache line needs adding here.
  final String? iconBrandPackId;

  /// A THIRD-PARTY icon pack installed as its own APK: Icon Pack Studio
  /// exports, and every Nova/ADW-format pack on Play. Null = none.
  ///
  /// ─── NOT THE SAME FIELD AS [iconPackId], AND NOT A DUPLICATE ──────────────
  ///
  /// [iconPackId] names a hero pack that arrived over the CDN: content this
  /// ecosystem authored, signed and possibly sold. This names an APK that
  /// happens to be installed on this one device and was authored by a stranger.
  /// They resolve through completely different code (one is `IconStyle.heroPack`
  /// handed to the renderer, the other is `IconPackResolver` reading another
  /// app's resources), and a user can reasonably have both — a pack from Play
  /// for the apps it covers, the distro's hero art for the rest.
  ///
  /// ─── WHY IT IS NOT IN [api.IconStyle] ─────────────────────────────────────
  ///
  /// IconStyle is theme CONTENT: it is authored in a theme.json and delivered
  /// over the CDN. No distro could fill this in even if it wanted to, because
  /// the answer is a package name that exists on one phone. It is pushed to
  /// native separately, by `setIconPack`.
  ///
  /// PER-THEME, like everything else in this file, and deliberately the same
  /// scoping as [iconPackId]. Two icon-pack settings with opposite scope would
  /// be genuinely confusing, and "Ubuntu with Yaru, Kali with Whicons" is a
  /// reasonable thing to want.
  final String? systemIconPack;

  final double? cornerRadius;

  // --- labels ---
  /// 1 or 2. Two lines lets long app names wrap instead of "Secure Fold…".
  final int? labelLines;
  final double? textScale;

  // --- fonts (global bucket: see GlobalPrefs) ---

  /// The family every label, title and menu is set in, overriding whatever the
  /// distro authored in its `theme.json`.
  ///
  /// THREE STATES, AND ONLY ONE OF THEM IS A FAMILY NAME:
  ///
  ///   null              no preference. Ubuntu comes up in Ubuntu, Kali in
  ///                     Kali's face. The default, and the point of the product.
  ///   `systemChoice`    the phone's own typeface, whatever the user set it to
  ///                     in Android's settings. Resolves to a null `fontFamily`.
  ///   anything else     that family, fetched once from the Play Services font
  ///                     provider and cached to disk.
  ///
  /// "Follow the distro" and "follow the phone" are different answers and a
  /// single null cannot hold both, which is why the second is a real stored
  /// string rather than a second flavour of absent. See font_catalogue.dart.
  ///
  /// PROMOTED TO THE GLOBAL BUCKET, unlike almost everything above it. A font
  /// is a fact about the person reading it: someone who chose a family because
  /// it is what they can read comfortably means it on Plasma too, and per theme
  /// they would have to say so again on every distro they ever tried.
  final String? displayFont;

  /// The family the terminal, the TUI shell and every fixed-width readout use.
  ///
  /// Separate from [displayFont] deliberately: wanting JetBrains Mono in an SSH
  /// session says nothing at all about wanting it under the app icons.
  ///
  /// ONLY EVER HOLDS A FIXED-ADVANCE FAMILY, and that is enforced at the picker
  /// rather than here. `terminal_screen.dart` derives the PTY column count by
  /// measuring a run of glyphs in this family and sends the number to the remote
  /// host. A proportional face makes the count too generous, the host formats
  /// for a width the screen does not have, and its output wraps where nothing
  /// can show it. That has been seen on device.
  ///
  /// Its "system" value is `systemMonoChoice`, not `systemChoice`, for the same
  /// reason: the platform default is proportional.
  final String? monoFont;

  // --- gestures ---
  /// gestureId -> binding. A binding is a GestureAction id, or "app:<key>".
  /// Unset gestures fall back to defaultGestures — including the v1
  /// double-tap-left-edge, which existing users have in muscle memory.
  final Map<String, String> gestures;

  // --- content ---
  final Set<String> hiddenApps; // componentKeys

  /// Whether a hidden app may still be reached by TYPING ITS WHOLE NAME.
  ///
  /// null means the default, which is `true` — see `HiddenApps.searchable`, the
  /// one place that decision is written down. Hiding is "off my drawer", not
  /// "uninstalled", so the app stays launchable for the person who knows it is
  /// there; turning this off is the stronger promise, that the name produces
  /// nothing at all.
  ///
  /// Per theme like [hiddenApps] itself, because the two only make sense
  /// together: a hidden set with a global search rule would mean hiding an app
  /// in Ubuntu quietly changed how KDE's search behaved.
  final bool? hiddenAppsSearchable;

  /// The dock's pinned apps, in dock order.
  ///
  /// **Empty is meaningful.** Empty means "the user has never arranged the
  /// dock", and the dock shows their most-used apps instead. The moment one app
  /// is pinned, the dock is theirs and stops moving on its own. See
  /// `HomeLayout.dockKeys`.
  final List<String> favourites; // componentKeys, dock order

  /// Apps the user has taken OUT of the auto-filled dock, by component key.
  ///
  /// ─── ONLY THE FREQUENT PATH READS THIS ──────────────────────────────────
  ///
  /// `HomeLayout.dockKeys` has two modes. Pin anything and the dock is yours
  /// entirely and stops moving; pin nothing and it is your most-used apps,
  /// refilled from frequency. The second mode had no way out: long-press
  /// offered "Pin to dock" and nothing else, so an app the filler kept putting
  /// there could not be removed except by pinning around it, which nobody
  /// would think to try.
  ///
  /// This is that way out, and it SUBTRACTS ONLY. The note on `dockKeys`
  /// argues against pins-plus-autofill because things you never chose appear
  /// beside your pins and swap themselves out; an exclusion cannot do that.
  /// The dock keeps refilling and the next most-used app moves up, which is
  /// what the auto mode already promises.
  ///
  /// NOT applied in pinned mode. There, unpinning already removes an app and it
  /// stays gone, so a second mechanism would be two ways to say one thing.
  ///
  /// Per theme, like `favourites` and `hiddenApps`, and pruned with them: a key
  /// for an app that has been uninstalled is a record of a decision about
  /// something that no longer exists.
  final Set<String> dockExcluded;

  final List<HomeItem> homeItems;
  final List<AppFolder> folders;

  /// Folders the user built IN THE DRAWER by dragging one app onto another.
  ///
  /// Separate from [folders], which is home-screen folders living in slots. The
  /// drawer has no slots, so its folders have their own rules (see
  /// `DrawerLayout`) and their own storage — merging in the drawer must not
  /// rearrange the home screen, and vice versa.
  final List<AppFolder> drawerFolders;

  /// Desklets placed on the desktop, across every workspace.
  ///
  /// PHASE D2. Additive, so [schemaVersion] stays 1 and an older prefs file
  /// parses unchanged as "no desklets", which is what every existing user has.
  ///
  /// FLAT, WITH `page` ON THE RECORD — the same shape [homeItems] already uses,
  /// and for the same three reasons:
  ///   * per-workspace content needs no new container type
  ///   * dropping the workspace count from 5 to 2 HIDES pages 3-5 rather than
  ///     destroying what is on them, because nothing prunes by page
  ///   * raising it back restores them intact
  ///
  /// Order is meaningful ONLY on the pane surface (the terminal shell), where
  /// desklets are command output in sequence rather than cards on a grid. On a
  /// grid surface the order is irrelevant and `col`/`row` carry the position.
  final List<Desklet> desklets;

  /// Folder suggestions the user said no to, by suggestion id.
  ///
  /// Without this, "ignore" means "ask me again on every rebuild", which is how
  /// a helpful suggestion turns into nagging. Accepting needs no such record:
  /// an accepted suggestion becomes a real folder, its members are then folded,
  /// and the suggester skips folded apps — so it cannot propose the same group
  /// twice.
  final Set<String> dismissedSuggestions;

  /// Columns inside an OPEN folder. null = 4.
  ///
  /// Separate from [drawerCols] on purpose: a folder holds a handful of apps in
  /// a sheet, the drawer holds two hundred on a full screen. Tying them together
  /// means widening the drawer squeezes every folder, which is not what anyone
  /// asked for.
  final int? folderCols;

  /// Rows of a folder visible before it scrolls. null = 3.
  final int? folderRows;

  /// The folder tile's shape: 'roundedSquare' | 'circle' | 'squircle' | 'square'.
  /// null = follow the theme's icon treatment, so a folder looks like the icons
  /// around it without the user setting anything.
  final String? folderShape;

  /// Has the user dragged folders into their own order?
  ///
  /// null/false = alphabetical, which is the right default: a folder you just
  /// named lands where its name says it should, and you can find it. Once you
  /// reorder ANYTHING, [drawerFolders] becomes the order of record and we stop
  /// re-sorting behind you — otherwise the next rename would silently undo the
  /// arrangement you just made.
  final bool? folderOrderCustom;

  // --- wallpaper ---
  /// Content URIs the user added, on top of the theme's presets.
  final List<String> wallpapers;

  /// Distro presets the user does not want, by their `theme.json` reference.
  ///
  /// ─── A CURATION, NOT A SETTING, AND THAT DECIDES WHERE IT LIVES ───────────
  ///
  /// Shipping a distro means shipping its wallpapers, and nobody likes all of
  /// them. Hiding one drops it out of the rotation pool and greys it in the
  /// strip; it is still there, because a preset belongs to the pack and is not
  /// the user's to delete. The user's OWN photos are not in here: those have a
  /// real Remove that deletes a real copy, which is the honest verb for a file
  /// you own.
  ///
  /// Keyed on the REFERENCE STRING, not on a resolved path, so a distro
  /// republished over the CDN with the same filename stays hidden. Resolved
  /// paths carry the pack directory and would forget on every reinstall.
  ///
  /// PER THEME, like everything else here: Ubuntu's rejects are a fact about
  /// Ubuntu, and one global set would hide an unrelated `numbat_dark.webp`
  /// shipped by another distro that happened to pick the same name.
  ///
  /// NOT in any [PrefsSection]. `prefs_reset.dart` draws the line and this
  /// falls on the content side of it, beside `dismissedSuggestions`: a setting
  /// has a default to return to, and this has nothing but the user's own
  /// judgement. A "restore wallpaper settings" tap that silently un-hid months
  /// of pruning would be exactly the reset nobody can predict.
  final Set<String> wallpapersHidden;

  /// Also set this theme's wallpaper on the LOCK screen. null = home only.
  ///
  /// Off by default, deliberately. The lock screen is the one surface a user
  /// sees before they have decided to use their phone, and silently replacing it
  /// because they tried a launcher theme is a step further than they asked for.
  /// Opt in, per theme, like everything else here.
  final bool? wallpaperLock;

  /// The wallpaper currently chosen FOR THIS THEME, as an unencoded source.
  ///
  /// ─── WHY THIS HAD TO EXIST ─────────────────────────────────────────────
  ///
  /// Android's wallpaper is ONE GLOBAL SETTING, but this launcher's prefs are
  /// per theme. Nothing recorded which wallpaper belonged to which distro, so
  /// switching Ubuntu to KDE and back left KDE's wallpaper on screen under
  /// Ubuntu's palette, with nothing to put back.
  ///
  /// The old `wallpaperInitialized` flag could not fix that: it answers "has
  /// this theme ever applied one", which is true for both themes by the second
  /// switch, so the re-apply was skipped exactly when it was needed.
  ///
  /// Null means this theme has no user choice yet, and its own first preset is
  /// used instead.
  final String? wallpaperCurrent;

  /// null = no rotation. Android's WorkManager floor is 15 minutes; anything
  /// smaller is silently clamped, so do not offer "every 5 minutes" in the UI
  /// and quietly lie.
  final int? wallpaperRotationMinutes;

  /// Where rotation draws from. null = this distro's pool (its presets plus
  /// the photos under Yours). 'all' = that pool plus every collection.
  /// 'collection:<id>' = one collection alone.
  ///
  /// PER THEME, while the collections themselves are GLOBAL (see
  /// `wallpaper_collections.dart`): the photos are facts about the person,
  /// which pool a distro cycles is a fact about that distro, so the terminal
  /// can rotate moody screenshots while Aqua rotates the family album. A value
  /// from a newer build, or a collection id since deleted, degrades to the
  /// distro pool at the read site (`rotationPoolFor`) rather than sticking or
  /// throwing.
  final String? wallpaperRotationSource;

  /// How a wallpaper meets the screen: 'cover' | 'contain' | 'fill' |
  /// 'center'. null means cover, which is byte-for-byte the pre-fit
  /// behaviour. PER THEME like `wallpaperCurrent`, because the fit describes
  /// how THIS distro's chosen image sits: a terminal theme can letterbox a
  /// screenshot while Aqua covers with a photo. Native degrades an unknown
  /// value to cover, so a pref written by a newer build renders instead of
  /// failing.
  final String? wallpaperFit;

  /// Per-wallpaper framing the user has set, keyed by the SAME source string
  /// stored in [wallpaperCurrent] and listed in [wallpapers].
  ///
  /// ─── WHY THIS DID NOT REPLACE [wallpaperFit] ────────────────────────────
  ///
  /// [wallpaperFit] is the older per-theme setting and it is still read, as the
  /// arm below this one in `resolveWallpaperFraming`. Deleting it would
  /// silently reset everyone who ever chose Fit for a letterboxed screenshot,
  /// and migrating it is not possible: it would have to guess WHICH wallpaper
  /// the user meant it for, and the setting never named one. So the old
  /// preference keeps working everywhere until a wallpaper gets framing of its
  /// own, at which point that wallpaper stops asking.
  ///
  /// ─── ENTRIES THAT SAY NOTHING ARE NOT STORED ────────────────────────────
  ///
  /// The writer drops any [WallpaperFraming] whose `isDefault` is true. This
  /// map is per theme and a distro's wallpaper list plus the user's own photos
  /// can run long, so an entry per wallpaper the user merely opened is a prefs
  /// blob that only ever grows. A key that is absent and a key holding all
  /// defaults mean the same thing, and only one of them costs bytes on every
  /// read.
  final Map<String, WallpaperFraming> wallpaperFraming;

  /// The user's own order for THIS DISTRO'S PRESETS, by name.
  ///
  /// ─── WHY THE PRESETS NEED A LIST AND THE USER'S PHOTOS DO NOT ───────────
  ///
  /// `wallpapers` IS the user's own list, so reordering it is the edit. The
  /// presets come from `spec.wallpapers`, which the pack owns and a republish
  /// rewrites, so there is nothing there to reorder in place and the override
  /// has to live somewhere the pack cannot overwrite.
  ///
  /// ─── WHY A REPUBLISH DOES NOT DESTROY IT ────────────────────────────────
  ///
  /// Names here that the pack no longer ships are IGNORED rather than pruned,
  /// and names the pack ships that are absent here sort to the END. So a pack
  /// that adds two wallpapers shows them after the ordered ones instead of
  /// silently discarding an order the user set, and a pack that renames one
  /// loses only that entry's position. Empty means the pack's own order, which
  /// is what every install starts with and what the author intended.
  final List<String> wallpaperOrder;

  /// Has this theme's default wallpaper been applied yet?
  ///
  /// Per-theme, and ONCE. Ubuntu applies Numbat the first time you use it; if
  /// you then pick your own photo and switch to KDE and back, Ubuntu must NOT
  /// stamp Numbat over your choice again. A theme that keeps resetting your
  /// wallpaper is a theme people uninstall.
  final bool wallpaperInitialized;

  /// Has this theme's STARTER DESKTOP been laid out yet?
  ///
  /// Per theme, and ONCE, for exactly the reason [wallpaperInitialized] is:
  /// choosing Arch should lay out a waybar-ish desktop the first time, and must
  /// never re-stamp it over an arrangement the user has since made. Removing
  /// every desklet is a legitimate arrangement, so "the list is empty" cannot
  /// stand in for this flag.
  final bool deskletsInitialized;

  /// Has this theme's authored HOME grid been laid out yet?
  ///
  /// [deskletsInitialized]'s sibling and separate from it on purpose. The two
  /// seeds can arrive in different builds and a distro can gain a `home` block
  /// long after its desklets: one flag for both would mean a theme already
  /// marked done never picks up the icons it was later given.
  ///
  /// Same ONCE rule and the same reason. An empty desktop is a legitimate
  /// arrangement, so "there are no home items" cannot stand in for this.
  final bool homeInitialized;

  LauncherPrefs copyWith({
    String? dockSide,
    String? dockGridButton,
    bool? topBar,
    bool? desktopIcons,
    List<String>? panelModules,
    double? panelHeight,
    String? panelSide,
    int? rows,
    int? cols,
    int? drawerCols,
    String? drawerSearchPosition,
    String? drawerScrollStyle,
    String? drawerGrouping,
    String? drawerSortMode,
    List<DrawerSlot>? drawerSlots,
    int? drawerSlotCols,
    int? drawerSlotRows,
    int? drawerPageCount,
    String? themeMode,
    String? accentId,
    String? layoutPreset,
    int? deskletGridVersion,
    String? topBarSide,
    bool? topBarStats,
    double? surfaceOpacity,
    double? dockOpacity,
    double? drawerOpacity,
    double? barOpacity,
    double? panelOpacity,
    double? panelBlur,
    double? panelTint,
    double? panelRadius,
    String? badgeStyle,
    int? workspaceCount,
    bool? verboseBoot,
    double? iconSizeDp,
    String? iconTreatment,
    String? iconPackId,
    String? iconBrandPackId,
    String? systemIconPack,
    double? cornerRadius,
    int? labelLines,
    double? textScale,
    String? displayFont,
    String? monoFont,
    Map<String, String>? gestures,
    Set<String>? hiddenApps,
    bool? hiddenAppsSearchable,
    List<String>? favourites,
    Set<String>? dockExcluded,
    List<HomeItem>? homeItems,
    List<AppFolder>? folders,
    List<AppFolder>? drawerFolders,
    List<Desklet>? desklets,
    Set<String>? dismissedSuggestions,
    int? folderCols,
    int? folderRows,
    String? folderShape,
    bool? folderOrderCustom,
    List<String>? wallpapers,
    Set<String>? wallpapersHidden,
    bool? wallpaperLock,
    String? wallpaperCurrent,
    int? wallpaperRotationMinutes,
    String? wallpaperRotationSource,
    String? wallpaperFit,
    Map<String, WallpaperFraming>? wallpaperFraming,
    List<String>? wallpaperOrder,
    bool? wallpaperInitialized,
    bool? deskletsInitialized,
    bool? homeInitialized,
  }) {
    return LauncherPrefs(
      dockSide: dockSide ?? this.dockSide,
      dockGridButton: dockGridButton ?? this.dockGridButton,
      topBar: topBar ?? this.topBar,
      desktopIcons: desktopIcons ?? this.desktopIcons,
      panelModules: panelModules ?? this.panelModules,
      panelHeight: panelHeight ?? this.panelHeight,
      panelSide: panelSide ?? this.panelSide,
      rows: rows ?? this.rows,
      cols: cols ?? this.cols,
      drawerCols: drawerCols ?? this.drawerCols,
      drawerSearchPosition: drawerSearchPosition ?? this.drawerSearchPosition,
      drawerScrollStyle: drawerScrollStyle ?? this.drawerScrollStyle,
      drawerGrouping: drawerGrouping ?? this.drawerGrouping,
      drawerSortMode: drawerSortMode ?? this.drawerSortMode,
      drawerSlots: drawerSlots ?? this.drawerSlots,
      drawerSlotCols: drawerSlotCols ?? this.drawerSlotCols,
      drawerSlotRows: drawerSlotRows ?? this.drawerSlotRows,
      drawerPageCount: drawerPageCount ?? this.drawerPageCount,
      themeMode: themeMode ?? this.themeMode,
      accentId: accentId ?? this.accentId,
      layoutPreset: layoutPreset ?? this.layoutPreset,
      deskletGridVersion: deskletGridVersion ?? this.deskletGridVersion,
      topBarSide: topBarSide ?? this.topBarSide,
      topBarStats: topBarStats ?? this.topBarStats,
      surfaceOpacity: surfaceOpacity ?? this.surfaceOpacity,
      dockOpacity: dockOpacity ?? this.dockOpacity,
      drawerOpacity: drawerOpacity ?? this.drawerOpacity,
      barOpacity: barOpacity ?? this.barOpacity,
      panelOpacity: panelOpacity ?? this.panelOpacity,
      panelBlur: panelBlur ?? this.panelBlur,
      panelTint: panelTint ?? this.panelTint,
      panelRadius: panelRadius ?? this.panelRadius,
      badgeStyle: badgeStyle ?? this.badgeStyle,
      workspaceCount: workspaceCount ?? this.workspaceCount,
      verboseBoot: verboseBoot ?? this.verboseBoot,
      iconSizeDp: iconSizeDp ?? this.iconSizeDp,
      iconTreatment: iconTreatment ?? this.iconTreatment,
      iconPackId: iconPackId ?? this.iconPackId,
      iconBrandPackId: iconBrandPackId ?? this.iconBrandPackId,
      systemIconPack: systemIconPack ?? this.systemIconPack,
      cornerRadius: cornerRadius ?? this.cornerRadius,
      labelLines: labelLines ?? this.labelLines,
      textScale: textScale ?? this.textScale,
      displayFont: displayFont ?? this.displayFont,
      monoFont: monoFont ?? this.monoFont,
      gestures: gestures ?? this.gestures,
      hiddenApps: hiddenApps ?? this.hiddenApps,
      hiddenAppsSearchable: hiddenAppsSearchable ?? this.hiddenAppsSearchable,
      favourites: favourites ?? this.favourites,
      dockExcluded: dockExcluded ?? this.dockExcluded,
      homeItems: homeItems ?? this.homeItems,
      folders: folders ?? this.folders,
      drawerFolders: drawerFolders ?? this.drawerFolders,
      dismissedSuggestions: dismissedSuggestions ?? this.dismissedSuggestions,
      folderCols: folderCols ?? this.folderCols,
      folderRows: folderRows ?? this.folderRows,
      folderShape: folderShape ?? this.folderShape,
      folderOrderCustom: folderOrderCustom ?? this.folderOrderCustom,
      wallpapers: wallpapers ?? this.wallpapers,
      wallpapersHidden: wallpapersHidden ?? this.wallpapersHidden,
      wallpaperLock: wallpaperLock ?? this.wallpaperLock,
      wallpaperCurrent: wallpaperCurrent ?? this.wallpaperCurrent,
      wallpaperRotationMinutes:
          wallpaperRotationMinutes ?? this.wallpaperRotationMinutes,
      wallpaperRotationSource:
          wallpaperRotationSource ?? this.wallpaperRotationSource,
      wallpaperFit: wallpaperFit ?? this.wallpaperFit,
      wallpaperFraming: wallpaperFraming ?? this.wallpaperFraming,
      wallpaperOrder: wallpaperOrder ?? this.wallpaperOrder,
      desklets: desklets ?? this.desklets,
      wallpaperInitialized: wallpaperInitialized ?? this.wallpaperInitialized,
      deskletsInitialized: deskletsInitialized ?? this.deskletsInitialized,
      homeInitialized: homeInitialized ?? this.homeInitialized,
    );
  }

  /// copyWith cannot clear a field to null — that is the classic Dart trap, and
  /// "reset this setting back to the theme default" is a thing users do.
  LauncherPrefs clearing({
    bool dockSide = false,
    bool dockGridButton = false,
    bool topBar = false,
    bool desktopIcons = false,
    bool panelModules = false,
    bool panelHeight = false,
    bool panelSide = false,
    bool rows = false,
    bool cols = false,
    bool drawerCols = false,
    bool drawerSearchPosition = false,
    bool drawerScrollStyle = false,
    bool drawerGrouping = false,
    bool drawerSortMode = false,
    bool drawerPageCount = false,
    bool themeMode = false,
    bool accentId = false,
    bool layoutPreset = false,
    bool deskletGridVersion = false,
    bool topBarSide = false,
    bool topBarStats = false,
    bool surfaceOpacity = false,
    bool dockOpacity = false,
    bool drawerOpacity = false,
    bool barOpacity = false,
    bool panelOpacity = false,
    bool panelBlur = false,
    bool panelTint = false,
    bool panelRadius = false,
    bool badgeStyle = false,

    /// Clearable, because removing the wallpaper you had chosen has to
    /// leave NO choice rather than a path pointing at a picture that is no
    /// longer in the list. `effective_theme` treats a non-null value here
    /// as "the user picked this", so a dangling one is a choice nobody can
    /// see or change.
    bool wallpaperCurrent = false,
    bool wallpaperLock = false,
    bool wallpaperRotationMinutes = false,
    bool wallpaperRotationSource = false,
    bool wallpaperFit = false,
    bool wallpaperFraming = false,
    bool wallpaperOrder = false,
    bool folderCols = false,
    bool folderRows = false,
    bool folderShape = false,
    bool folderOrderCustom = false,
    bool workspaceCount = false,
    bool verboseBoot = false,
    bool hiddenAppsSearchable = false,
    bool iconSizeDp = false,
    bool iconTreatment = false,
    bool iconPackId = false,
    bool iconBrandPackId = false,
    bool systemIconPack = false,
    bool cornerRadius = false,
    bool labelLines = false,
    bool textScale = false,
    bool displayFont = false,
    bool monoFont = false,
  }) {
    return LauncherPrefs(
      dockSide: dockSide ? null : this.dockSide,
      dockGridButton: dockGridButton ? null : this.dockGridButton,
      // Clearable now, for the section resets. It was pass-through, so
      // "restore defaults" on Icons and bar could turn the bar back ON but
      // could never hand it back to the distro's own answer.
      topBar: topBar ? null : this.topBar,
      desktopIcons: desktopIcons ? null : this.desktopIcons,
      panelModules: panelModules ? null : this.panelModules,
      panelHeight: panelHeight ? null : this.panelHeight,
      panelSide: panelSide ? null : this.panelSide,
      rows: rows ? null : this.rows,
      cols: cols ? null : this.cols,
      drawerCols: drawerCols ? null : this.drawerCols,
      drawerSearchPosition:
          drawerSearchPosition ? null : this.drawerSearchPosition,
      // BUG FIX (D2): this line did not exist, so EVERY call to clearing() —
      // whatever it was clearing — silently reset the drawer scroll style back
      // to null. A field omitted from this method is not "left alone", it is
      // dropped, because the constructor defaults it.
      drawerScrollStyle: drawerScrollStyle ? null : this.drawerScrollStyle,
      drawerGrouping: drawerGrouping ? null : this.drawerGrouping,
      drawerSortMode: drawerSortMode ? null : this.drawerSortMode,
      // Pass-through, not clearable: the arrangement survives leaving Custom,
      // which is what lets returning to Custom restore it. Omitting these
      // from this method would silently wipe them on every unrelated clear,
      // the exact bug drawerScrollStyle once had.
      drawerSlots: drawerSlots,
      drawerSlotCols: drawerSlotCols,
      drawerSlotRows: drawerSlotRows,
      // Clearable, unlike the slots above: Clean up pages resets the
      // drawer to exactly as many pages as it needs.
      drawerPageCount: drawerPageCount ? null : this.drawerPageCount,
      themeMode: themeMode ? null : this.themeMode,
      accentId: accentId ? null : this.accentId,
      layoutPreset: layoutPreset ? null : this.layoutPreset,
      deskletGridVersion: deskletGridVersion ? null : this.deskletGridVersion,
      topBarSide: topBarSide ? null : this.topBarSide,
      topBarStats: topBarStats ? null : this.topBarStats,
      surfaceOpacity: surfaceOpacity ? null : this.surfaceOpacity,
      dockOpacity: dockOpacity ? null : this.dockOpacity,
      drawerOpacity: drawerOpacity ? null : this.drawerOpacity,
      barOpacity: barOpacity ? null : this.barOpacity,
      panelOpacity: panelOpacity ? null : this.panelOpacity,
      panelBlur: panelBlur ? null : this.panelBlur,
      panelTint: panelTint ? null : this.panelTint,
      panelRadius: panelRadius ? null : this.panelRadius,
      badgeStyle: badgeStyle ? null : this.badgeStyle,
      workspaceCount: workspaceCount ? null : this.workspaceCount,
      verboseBoot: verboseBoot ? null : this.verboseBoot,
      iconSizeDp: iconSizeDp ? null : this.iconSizeDp,
      iconTreatment: iconTreatment ? null : this.iconTreatment,
      iconPackId: iconPackId ? null : this.iconPackId,
      // The route back to the distro's own colour. copyWith cannot write null,
      // so without this line "use the icons this distro came with" has no
      // implementation and the last colour chosen is permanent.
      iconBrandPackId: iconBrandPackId ? null : this.iconBrandPackId,
      systemIconPack: systemIconPack ? null : this.systemIconPack,
      cornerRadius: cornerRadius ? null : this.cornerRadius,
      labelLines: labelLines ? null : this.labelLines,
      textScale: textScale ? null : this.textScale,
      // THE ONLY ROUTE BACK TO THE DISTRO'S OWN FONT. copyWith cannot write
      // null, so without these two lines "use the distro's font" is a choice
      // the picker offers and cannot deliver: it would appear to do nothing.
      displayFont: displayFont ? null : this.displayFont,
      monoFont: monoFont ? null : this.monoFont,
      gestures: gestures,
      hiddenApps: hiddenApps,
      hiddenAppsSearchable:
          hiddenAppsSearchable ? null : this.hiddenAppsSearchable,
      favourites: favourites,
      dockExcluded: dockExcluded,
      homeItems: homeItems,
      folders: folders,
      drawerFolders: drawerFolders,
      desklets: desklets,
      dismissedSuggestions: dismissedSuggestions,
      folderCols: folderCols ? null : this.folderCols,
      folderRows: folderRows ? null : this.folderRows,
      folderShape: folderShape ? null : this.folderShape,
      folderOrderCustom: folderOrderCustom ? null : this.folderOrderCustom,
      wallpapers: wallpapers,
      // Pass-through. A Set has no null state, so there is no flag for it and
      // never will be: emptying it is `copyWith(wallpapersHidden: const {})`,
      // the same shape `PrefsSection.gestures` uses and for the same reason.
      wallpapersHidden: wallpapersHidden,
      // Pass-through, not clearable. A field OMITTED from this method is
      // dropped rather than preserved, which is how drawerScrollStyle was
      // once silently reset by every unrelated clear.
      wallpaperCurrent: wallpaperCurrent ? null : this.wallpaperCurrent,
      // Clearable now (it was pass-through). The rotation sheet's Off used
      // copyWith(null), which copyWith cannot write, so the interval survived
      // Off forever. Nothing re-read it then; rescheduleRotation does now, and
      // a stale interval would resurrect a rotation the user turned off the
      // next time a collection changed.
      wallpaperLock: wallpaperLock ? null : this.wallpaperLock,
      wallpaperRotationMinutes:
          wallpaperRotationMinutes ? null : this.wallpaperRotationMinutes,
      wallpaperRotationSource:
          wallpaperRotationSource ? null : this.wallpaperRotationSource,
      wallpaperFit: wallpaperFit ? null : this.wallpaperFit,
      // Cleared to EMPTY, not null: the field is non-nullable because "no
      // framing anywhere" and "framing I have not loaded" are the same state
      // for a map, unlike every nullable field above where null means inherit.
      wallpaperFraming: wallpaperFraming ? const {} : this.wallpaperFraming,
      // Empty, not null, for the same reason the map above is: a list has no
      // null state and clearing it means "back to the pack's order".
      wallpaperOrder: wallpaperOrder ? const [] : this.wallpaperOrder,
      wallpaperInitialized: wallpaperInitialized,
      deskletsInitialized: deskletsInitialized,
      homeInitialized: homeInitialized,
    );
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        if (dockSide != null) 'dockSide': dockSide,
        if (dockGridButton != null) 'dockGridButton': dockGridButton,
        if (topBar != null) 'topBar': topBar,
        if (desktopIcons != null) 'desktopIcons': desktopIcons,
        if (panelModules != null) 'panelModules': panelModules,
        if (panelHeight != null) 'panelHeight': panelHeight,
        if (panelSide != null) 'panelSide': panelSide,
        if (rows != null) 'rows': rows,
        if (cols != null) 'cols': cols,
        if (drawerCols != null) 'drawerCols': drawerCols,
        if (drawerScrollStyle != null) 'drawerScrollStyle': drawerScrollStyle,
        if (drawerGrouping != null) 'drawerGrouping': drawerGrouping,
        if (drawerSortMode != null) 'drawerSortMode': drawerSortMode,
        'drawerSlots': drawerSlots.map((e) => e.toJson()).toList(),
        if (drawerSlotCols != null) 'drawerSlotCols': drawerSlotCols,
        if (drawerSlotRows != null) 'drawerSlotRows': drawerSlotRows,
        if (drawerPageCount != null) 'drawerPageCount': drawerPageCount,
        if (themeMode != null) 'themeMode': themeMode,
        if (accentId != null) 'accentId': accentId,
        if (layoutPreset != null) 'layoutPreset': layoutPreset,
        if (deskletGridVersion != null)
          'deskletGridVersion': deskletGridVersion,
        if (topBarSide != null) 'topBarSide': topBarSide,
        if (topBarStats != null) 'topBarStats': topBarStats,
        if (surfaceOpacity != null) 'surfaceOpacity': surfaceOpacity,
        if (dockOpacity != null) 'dockOpacity': dockOpacity,
        if (drawerOpacity != null) 'drawerOpacity': drawerOpacity,
        if (barOpacity != null) 'barOpacity': barOpacity,
        if (panelOpacity != null) 'panelOpacity': panelOpacity,
        if (panelBlur != null) 'panelBlur': panelBlur,
        if (panelTint != null) 'panelTint': panelTint,
        if (panelRadius != null) 'panelRadius': panelRadius,
        if (badgeStyle != null) 'badgeStyle': badgeStyle,
        if (drawerSearchPosition != null)
          'drawerSearchPosition': drawerSearchPosition,
        if (workspaceCount != null) 'workspaceCount': workspaceCount,
        if (verboseBoot != null) 'verboseBoot': verboseBoot,
        if (iconSizeDp != null) 'iconSizeDp': iconSizeDp,
        if (iconTreatment != null) 'iconTreatment': iconTreatment,
        if (iconPackId != null) 'iconPackId': iconPackId,
        if (iconBrandPackId != null) 'iconBrandPackId': iconBrandPackId,
        if (systemIconPack != null) 'systemIconPack': systemIconPack,
        if (cornerRadius != null) 'cornerRadius': cornerRadius,
        if (labelLines != null) 'labelLines': labelLines,
        if (textScale != null) 'textScale': textScale,
        if (displayFont != null) 'displayFont': displayFont,
        if (monoFont != null) 'monoFont': monoFont,
        'gestures': gestures,
        'hiddenApps': hiddenApps.toList(),
        if (hiddenAppsSearchable != null)
          'hiddenAppsSearchable': hiddenAppsSearchable,
        'favourites': favourites,
        'dockExcluded': dockExcluded.toList(),
        'homeItems': homeItems.map((e) => e.toJson()).toList(),
        'folders': folders.map((e) => e.toJson()).toList(),
        'drawerFolders': drawerFolders.map((e) => e.toJson()).toList(),
        'desklets': desklets.map((e) => e.toJson()).toList(),
        'dismissedSuggestions': dismissedSuggestions.toList(),
        if (folderCols != null) 'folderCols': folderCols,
        if (folderRows != null) 'folderRows': folderRows,
        if (folderShape != null) 'folderShape': folderShape,
        if (folderOrderCustom != null) 'folderOrderCustom': folderOrderCustom,
        'wallpapers': wallpapers,
        'wallpapersHidden': wallpapersHidden.toList(),
        if (wallpaperLock != null) 'wallpaperLock': wallpaperLock,
        if (wallpaperCurrent != null) 'wallpaperCurrent': wallpaperCurrent,
        if (wallpaperRotationMinutes != null)
          'wallpaperRotationMinutes': wallpaperRotationMinutes,
        if (wallpaperRotationSource != null)
          'wallpaperRotationSource': wallpaperRotationSource,
        if (wallpaperFit != null) 'wallpaperFit': wallpaperFit,
        // Empty entries are dropped on the way out as well as on the way in,
        // so a framing reset actually shrinks the blob instead of leaving a
        // row of defaults behind it.
        if (wallpaperOrder.isNotEmpty) 'wallpaperOrder': wallpaperOrder,
        if (wallpaperFraming.isNotEmpty)
          'wallpaperFraming': {
            for (final e in wallpaperFraming.entries)
              if (!e.value.isDefault) e.key: e.value.toJson(),
          },
        'wallpaperInitialized': wallpaperInitialized,
        'deskletsInitialized': deskletsInitialized,
        'homeInitialized': homeInitialized,
      };

  static LauncherPrefs fromJson(Map<String, dynamic> j) {
    // A prefs file written by a NEWER build. Resetting to defaults is ugly but
    // survivable; throwing here would black-screen the home screen after a
    // downgrade, which is not.
    final v = (j['schemaVersion'] as num?)?.toInt() ?? 0;
    if (v > schemaVersion) return const LauncherPrefs();

    return LauncherPrefs(
      dockSide: j['dockSide'] as String?,
      dockGridButton: j['dockGridButton'] as String?,
      topBar: j['topBar'] as bool?,
      desktopIcons: j['desktopIcons'] as bool?,
      panelModules:
          (j['panelModules'] as List?)?.map((e) => e.toString()).toList(),
      panelHeight: (j['panelHeight'] as num?)?.toDouble(),
      panelSide: j['panelSide'] as String?,
      rows: (j['rows'] as num?)?.toInt(),
      cols: (j['cols'] as num?)?.toInt(),
      drawerCols: (j['drawerCols'] as num?)?.toInt(),
      drawerSearchPosition: j['drawerSearchPosition'] as String?,
      drawerScrollStyle: j['drawerScrollStyle'] as String?,
      drawerGrouping: j['drawerGrouping'] as String?,
      drawerSortMode: j['drawerSortMode'] as String?,
      drawerSlots: ((j['drawerSlots'] as List?) ?? const [])
          .map((e) => DrawerSlot.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      drawerSlotCols: (j['drawerSlotCols'] as num?)?.toInt(),
      drawerSlotRows: (j['drawerSlotRows'] as num?)?.toInt(),
      drawerPageCount: (j['drawerPageCount'] as num?)?.toInt(),
      themeMode: j['themeMode'] as String?,
      accentId: j['accentId'] as String?,
      layoutPreset: j['layoutPreset'] as String?,
      deskletGridVersion: (j['deskletGridVersion'] as num?)?.toInt(),
      topBarSide: j['topBarSide'] as String?,
      topBarStats: j['topBarStats'] as bool?,
      surfaceOpacity: (j['surfaceOpacity'] as num?)?.toDouble(),
      dockOpacity: (j['dockOpacity'] as num?)?.toDouble(),
      drawerOpacity: (j['drawerOpacity'] as num?)?.toDouble(),
      barOpacity: (j['barOpacity'] as num?)?.toDouble(),
      panelOpacity: (j['panelOpacity'] as num?)?.toDouble(),
      panelBlur: (j['panelBlur'] as num?)?.toDouble(),
      panelTint: (j['panelTint'] as num?)?.toDouble(),
      panelRadius: (j['panelRadius'] as num?)?.toDouble(),
      badgeStyle: j['badgeStyle'] as String?,
      workspaceCount: (j['workspaceCount'] as num?)?.toInt(),
      verboseBoot: j['verboseBoot'] as bool?,
      iconSizeDp: (j['iconSizeDp'] as num?)?.toDouble(),
      iconTreatment: j['iconTreatment'] as String?,
      iconPackId: j['iconPackId'] as String?,
      // Absent on every prefs file written before this field existed, which
      // reads as null and means "the distro's own", which is what those
      // devices are already wearing.
      iconBrandPackId: j['iconBrandPackId'] as String?,
      systemIconPack: j['systemIconPack'] as String?,
      cornerRadius: (j['cornerRadius'] as num?)?.toDouble(),
      labelLines: (j['labelLines'] as num?)?.toInt(),
      textScale: (j['textScale'] as num?)?.toDouble(),
      displayFont: j['displayFont'] as String?,
      monoFont: j['monoFont'] as String?,
      gestures: ((j['gestures'] as Map?) ?? const {})
          .map((k, v) => MapEntry(k as String, v as String)),
      hiddenApps: ((j['hiddenApps'] as List?) ?? const [])
          .map((e) => e as String)
          .toSet(),
      hiddenAppsSearchable: j['hiddenAppsSearchable'] as bool?,
      dockExcluded: ((j['dockExcluded'] as List?) ?? const [])
          .map((e) => e as String)
          .toSet(),
      favourites: ((j['favourites'] as List?) ?? const [])
          .map((e) => e as String)
          .toList(),
      homeItems: ((j['homeItems'] as List?) ?? const [])
          .map((e) => HomeItem.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      folders: ((j['folders'] as List?) ?? const [])
          .map((e) => AppFolder.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      drawerFolders: ((j['drawerFolders'] as List?) ?? const [])
          .map((e) => AppFolder.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      desklets: ((j['desklets'] as List?) ?? const [])
          .map((e) => Desklet.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      dismissedSuggestions: ((j['dismissedSuggestions'] as List?) ?? const [])
          .map((e) => e as String)
          .toSet(),
      folderCols: (j['folderCols'] as num?)?.toInt(),
      folderRows: (j['folderRows'] as num?)?.toInt(),
      folderShape: j['folderShape'] as String?,
      folderOrderCustom: j['folderOrderCustom'] as bool?,
      wallpapers: ((j['wallpapers'] as List?) ?? const [])
          .map((e) => e as String)
          .toList(),
      wallpapersHidden: ((j['wallpapersHidden'] as List?) ?? const [])
          .map((e) => e as String)
          .toSet(),
      wallpaperLock: j['wallpaperLock'] as bool?,
      wallpaperCurrent: j['wallpaperCurrent'] as String?,
      wallpaperRotationMinutes:
          (j['wallpaperRotationMinutes'] as num?)?.toInt(),
      wallpaperRotationSource: j['wallpaperRotationSource'] as String?,
      wallpaperFit: j['wallpaperFit'] as String?,
      wallpaperOrder: ((j['wallpaperOrder'] as List?) ?? const [])
          .whereType<String>()
          .toList(),
      wallpaperFraming: {
        for (final e in ((j['wallpaperFraming'] as Map?) ?? const {}).entries)
          if (e.key is String && e.value is Map)
            e.key as String: WallpaperFraming.fromJson(
              (e.value as Map).cast<String, dynamic>(),
            ),
      },
      wallpaperInitialized: j['wallpaperInitialized'] as bool? ?? false,
      deskletsInitialized: j['deskletsInitialized'] as bool? ?? false,
      homeInitialized: j['homeInitialized'] as bool? ?? false,
    );
  }

  /// The user's shape choice, as the native enum. null = theme decides.
  api.IconTreatment? get treatmentEnum => switch (iconTreatment) {
        'circle' => api.IconTreatment.circle,
        'squircle' => api.IconTreatment.squircle,
        'roundedSquare' => api.IconTreatment.roundedSquare,
        'square' => api.IconTreatment.square,
        'teardrop' => api.IconTreatment.teardrop,
        'original' => api.IconTreatment.original,
        _ => null,
      };

  /// Value equality — this is what makes the `EffectiveTheme` `==` fix pay off.
  ///
  /// `EffectiveTheme` compares `prefs == prefs`, and it is the family key for the
  /// app-list providers. Without this, every new prefs INSTANCE (even one with
  /// identical values, e.g. a re-read from disk) reads as different and re-churns
  /// the app list. The collection fields need DEEP equality, so they go through
  /// `package:collection` rather than reference `==`.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LauncherPrefs &&
        other.dockSide == dockSide &&
        other.dockGridButton == dockGridButton &&
        other.topBar == topBar &&
        other.desktopIcons == desktopIcons &&
        const ListEquality<String>().equals(other.panelModules, panelModules) &&
        other.panelHeight == panelHeight &&
        other.panelSide == panelSide &&
        other.rows == rows &&
        other.cols == cols &&
        other.drawerCols == drawerCols &&
        other.drawerSearchPosition == drawerSearchPosition &&
        other.drawerScrollStyle == drawerScrollStyle &&
        other.drawerGrouping == drawerGrouping &&
        other.drawerSortMode == drawerSortMode &&
        const ListEquality<DrawerSlot>()
            .equals(other.drawerSlots, drawerSlots) &&
        other.drawerSlotCols == drawerSlotCols &&
        other.drawerSlotRows == drawerSlotRows &&
        other.drawerPageCount == drawerPageCount &&
        other.themeMode == themeMode &&
        other.accentId == accentId &&
        other.layoutPreset == layoutPreset &&
        other.deskletGridVersion == deskletGridVersion &&
        other.topBarSide == topBarSide &&
        other.topBarStats == topBarStats &&
        other.surfaceOpacity == surfaceOpacity &&
        other.dockOpacity == dockOpacity &&
        other.drawerOpacity == drawerOpacity &&
        other.barOpacity == barOpacity &&
        other.panelOpacity == panelOpacity &&
        other.panelBlur == panelBlur &&
        other.panelTint == panelTint &&
        other.panelRadius == panelRadius &&
        other.badgeStyle == badgeStyle &&
        other.workspaceCount == workspaceCount &&
        other.verboseBoot == verboseBoot &&
        other.iconSizeDp == iconSizeDp &&
        other.iconTreatment == iconTreatment &&
        other.iconPackId == iconPackId &&
        // ─── THE SEVENTH AND EIGHTH PLACES ────────────────────────────────
        //
        // A value class with a hand-written equality has EIGHT places a field
        // has to appear, not six. Adding it to the constructor, the field list,
        // copyWith, clearing, toJson and fromJson makes it save and load
        // perfectly, and leaving it out of `==` and `hashCode` makes it do
        // nothing at all.
        //
        // The failure is total and silent. `edit` writes the new prefs to disk,
        // then hands the notifier a value that compares EQUAL to the one it
        // already holds, so Riverpod treats it as no change and publishes
        // nothing. `effectiveThemeProvider` never re-resolves, native is never
        // pushed, no card repaints. Reading the phone afterwards shows the
        // value correctly stored and the app behaving as though it had never
        // been set, and a COLD START applies it, because on the first build
        // there is nothing to compare against.
        other.iconBrandPackId == iconBrandPackId &&
        other.systemIconPack == systemIconPack &&
        other.cornerRadius == cornerRadius &&
        other.labelLines == labelLines &&
        other.textScale == textScale &&
        other.displayFont == displayFont &&
        other.monoFont == monoFont &&
        const MapEquality<String, String>().equals(other.gestures, gestures) &&
        const SetEquality<String>().equals(other.hiddenApps, hiddenApps) &&
        other.hiddenAppsSearchable == hiddenAppsSearchable &&
        const ListEquality<String>().equals(other.favourites, favourites) &&
        const SetEquality<String>().equals(other.dockExcluded, dockExcluded) &&
        const ListEquality<HomeItem>().equals(other.homeItems, homeItems) &&
        const ListEquality<AppFolder>().equals(other.folders, folders) &&
        const ListEquality<AppFolder>()
            .equals(other.drawerFolders, drawerFolders) &&
        const ListEquality<Desklet>().equals(other.desklets, desklets) &&
        const SetEquality<String>()
            .equals(other.dismissedSuggestions, dismissedSuggestions) &&
        other.folderCols == folderCols &&
        other.folderRows == folderRows &&
        other.folderShape == folderShape &&
        other.folderOrderCustom == folderOrderCustom &&
        const ListEquality<String>().equals(other.wallpapers, wallpapers) &&
        const SetEquality<String>()
            .equals(other.wallpapersHidden, wallpapersHidden) &&
        other.wallpaperLock == wallpaperLock &&
        other.wallpaperCurrent == wallpaperCurrent &&
        other.wallpaperRotationMinutes == wallpaperRotationMinutes &&
        other.wallpaperRotationSource == wallpaperRotationSource &&
        other.wallpaperFit == wallpaperFit &&
        const MapEquality<String, WallpaperFraming>()
            .equals(other.wallpaperFraming, wallpaperFraming) &&
        const ListEquality<String>()
            .equals(other.wallpaperOrder, wallpaperOrder) &&
        other.wallpaperInitialized == wallpaperInitialized &&
        other.deskletsInitialized == deskletsInitialized &&
        other.homeInitialized == homeInitialized;
  }

  @override
  int get hashCode => Object.hashAll([
        dockSide,
        dockGridButton,
        topBar,
        desktopIcons,
        const ListEquality<String>().hash(panelModules),
        panelHeight,
        panelSide,
        rows,
        cols,
        drawerCols,
        drawerSearchPosition,
        drawerScrollStyle,
        drawerGrouping,
        drawerSortMode,
        const ListEquality<DrawerSlot>().hash(drawerSlots),
        drawerSlotCols,
        drawerSlotRows,
        drawerPageCount,
        themeMode,
        accentId,
        layoutPreset,
        deskletGridVersion,
        topBarSide,
        topBarStats,
        surfaceOpacity,
        dockOpacity,
        drawerOpacity,
        barOpacity,
        panelOpacity,
        panelBlur,
        panelTint,
        panelRadius,
        badgeStyle,
        workspaceCount,
        verboseBoot,
        iconSizeDp,
        iconTreatment,
        iconPackId,
        iconBrandPackId,
        systemIconPack,
        cornerRadius,
        labelLines,
        textScale,
        displayFont,
        monoFont,
        const MapEquality<String, String>().hash(gestures),
        const SetEquality<String>().hash(hiddenApps),
        hiddenAppsSearchable,
        const ListEquality<String>().hash(favourites),
        const SetEquality<String>().hash(dockExcluded),
        const ListEquality<HomeItem>().hash(homeItems),
        const ListEquality<AppFolder>().hash(folders),
        const ListEquality<AppFolder>().hash(drawerFolders),
        const ListEquality<Desklet>().hash(desklets),
        const SetEquality<String>().hash(dismissedSuggestions),
        folderCols,
        folderRows,
        folderShape,
        // BUG FIX (D2): folderOrderCustom was in operator== but missing here,
        // so two prefs differing only in it compared unequal yet hashed equal.
        // Legal, but the asymmetry is exactly what bites in a Set or a Map key.
        folderOrderCustom,
        const ListEquality<String>().hash(wallpapers),
        const SetEquality<String>().hash(wallpapersHidden),
        wallpaperLock,
        wallpaperCurrent,
        wallpaperRotationMinutes,
        wallpaperRotationSource,
        wallpaperFit,
        // In BOTH == and hashCode. The D2 note a few lines up is about exactly
        // this omission on folderOrderCustom, and a map is the field where it
        // bites hardest: prefs go into providers keyed by value.
        const MapEquality<String, WallpaperFraming>().hash(wallpaperFraming),
        const ListEquality<String>().hash(wallpaperOrder),
        wallpaperInitialized,
        deskletsInitialized,
        homeInitialized,
      ]);
}

/// One slot on a home page. Either an app or a folder, never both.
class HomeItem {
  const HomeItem({
    required this.page,
    required this.index,
    this.componentKey,
    this.folderId,
  });

  final int page;
  final int index;
  final String? componentKey;
  final String? folderId;

  bool get isFolder => folderId != null;

  Map<String, dynamic> toJson() => {
        'page': page,
        'index': index,
        if (componentKey != null) 'componentKey': componentKey,
        if (folderId != null) 'folderId': folderId,
      };

  static HomeItem fromJson(Map<String, dynamic> j) => HomeItem(
        page: (j['page'] as num).toInt(),
        index: (j['index'] as num).toInt(),
        componentKey: j['componentKey'] as String?,
        folderId: j['folderId'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HomeItem &&
          other.page == page &&
          other.index == index &&
          other.componentKey == componentKey &&
          other.folderId == folderId;

  @override
  int get hashCode => Object.hash(page, index, componentKey, folderId);
}

/// One CUSTOM-ORDER drawer slot. Either an app or a folder, never both.
///
/// The same shape as [HomeItem] on purpose, and a separate type on purpose:
/// the drawer's slot grid and the home grid share nothing but geometry, and a
/// shared type would invite home mutations to run against drawer storage the
/// way sharing [AppFolder] deliberately does NOT invite sharing folder rules.
/// Position is against the FROZEN grid in `drawerSlotCols` x `drawerSlotRows`;
/// see `DrawerSlots` for every rule that touches these.
class DrawerSlot {
  const DrawerSlot({
    required this.page,
    required this.index,
    this.componentKey,
    this.folderId,
  });

  final int page;
  final int index;
  final String? componentKey;
  final String? folderId;

  bool get isFolder => folderId != null;

  Map<String, dynamic> toJson() => {
        'page': page,
        'index': index,
        if (componentKey != null) 'componentKey': componentKey,
        if (folderId != null) 'folderId': folderId,
      };

  static DrawerSlot fromJson(Map<String, dynamic> j) => DrawerSlot(
        page: (j['page'] as num).toInt(),
        index: (j['index'] as num).toInt(),
        componentKey: j['componentKey'] as String?,
        folderId: j['folderId'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DrawerSlot &&
          other.page == page &&
          other.index == index &&
          other.componentKey == componentKey &&
          other.folderId == folderId;

  @override
  int get hashCode => Object.hash(page, index, componentKey, folderId);
}

class AppFolder {
  const AppFolder({
    required this.id,
    required this.name,
    this.members = const [],
    this.glyph,
  });

  final String id;
  final String name;
  final List<String> members; // componentKeys

  /// This folder's icon, as a catalogue id (see `folder_glyphs.dart`).
  ///
  /// ─── WHY AN ID AND NOT AN ASSET PATH OR A CODE POINT ────────────────────
  ///
  /// A path ties stored prefs to a file that a later build may rename or drop,
  /// and a raw Material code point ties them to Flutter's icon font, which is
  /// tree-shaken: a code point that no widget names literally is removed from
  /// the shipped font, so a folder restored from a backup would draw a blank
  /// square. An id resolves through a const map that the tree-shaker can see,
  /// which is the only spelling where a stored value is guaranteed to still
  /// render two releases later.
  ///
  /// Null means no choice has been made, and the drawing site falls back. It
  /// is APPENDED to this class rather than inserted, so an older build reading
  /// a newer prefs blob simply drops the key.
  final String? glyph;

  /// [glyph] takes a WRAPPED value, unlike the two above it.
  ///
  /// Every other field here uses `x ?? this.x`, which cannot express "clear
  /// it": passing null means inherit. Clearing a glyph back to the fallback is
  /// a thing the picker has to be able to do, so this one is a one-element
  /// list where absent means inherit and `[null]` means clear.
  AppFolder copyWith({
    String? name,
    List<String>? members,
    List<String?>? glyph,
  }) =>
      AppFolder(
        id: id,
        name: name ?? this.name,
        members: members ?? this.members,
        glyph: glyph == null ? this.glyph : glyph.first,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'members': members,
        // Omitted when absent, so a folder that has never been given an icon
        // serialises byte for byte the way it did before this field existed.
        if (glyph != null) 'glyph': glyph,
      };

  static AppFolder fromJson(Map<String, dynamic> j) => AppFolder(
        id: j['id'] as String,
        name: j['name'] as String,
        members: ((j['members'] as List?) ?? const [])
            .map((e) => e as String)
            .toList(),
        glyph: (j['glyph'] as String?)?.trim().isEmpty ?? true
            ? null
            : (j['glyph'] as String).trim(),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppFolder &&
          other.id == id &&
          other.name == name &&
          other.glyph == glyph &&
          const ListEquality<String>().equals(other.members, members);

  @override
  int get hashCode => Object.hash(
        id,
        name,
        glyph,
        const ListEquality<String>().hash(members),
      );
}

/// One desklet placed on the desktop.
///
/// PHASE D2. "Desklet" and not "widget", deliberately: `Widget` already means
/// two things here (Flutter's, and Android's `AppWidget`), and a third meaning
/// in the same codebase guarantees a confusing hour later. Cinnamon calls these
/// desklets, KDE calls them plasmoids, and the Linux vocabulary happens to fit
/// the product.
///
/// ─── WHY col/row/span AND NOT A FLAT SLOT INDEX ─────────────────────────────
///
/// [HomeItem] uses a single `index` because an app occupies exactly one cell.
/// A desklet occupies a RECTANGLE, and a flat index cannot express one: a
/// 2x2 tile starting at index 7 covers 7, 8, and two cells a row below whose
/// indices depend on the column count, which changes per theme. So position is
/// (col, row) and size is (spanX, spanY), and every occupancy test is a
/// rectangle overlap.
///
/// ─── WHY kind IS A STRING ───────────────────────────────────────────────────
///
/// Same contract as `ShellKind.parse`, `brandTreatment` and `BootLineKind`: a
/// kind this build does not recognise must render as ABSENT, never crash and
/// NEVER be silently deleted. A CDN theme can offer a desklet a shipped APK has
/// never heard of, and an older app must round-trip that placement untouched so
/// it reappears after an update. An enum could not do that.
class Desklet {
  const Desklet({
    required this.id,
    required this.kind,
    required this.page,
    this.col = 0,
    this.row = 0,
    this.spanX = 1,
    this.spanY = 1,
    this.config = const {},
  });

  /// Stable across moves and resizes. Not derived from position, because the
  /// position is the thing that changes.
  final String id;

  /// Registry key, e.g. "clock", "monitor", "fastfetch". Unknown values survive
  /// a round trip and simply do not draw.
  final String kind;

  /// Which workspace. Same convention as [HomeItem.page].
  final int page;

  /// Top-left cell on the desktop grid.
  ///
  /// IGNORED ON THE PANE SURFACE (the terminal shell), where desklets are
  /// persistent command output in list order rather than positioned cards.
  /// Precisely the way `dockSide` is already ignored under the Aqua shell: the
  /// record is shared, the renderer is not.
  final int col;
  final int row;

  /// Size in cells, always >= 1. Clamped against the kind's limits AND the grid
  /// on every write; see `DeskletLayout`.
  final int spanX;
  final int spanY;

  /// Per-kind settings. FREE-FORM FROM DAY ONE, and that is a deliberate cost
  /// decision rather than laziness.
  ///
  /// Placements are persisted user data, so adding a typed field later is a
  /// migration and a schema bump; adding a key to an already-free-form map is
  /// nothing. The first two desklets need it immediately anyway (a clock wants
  /// `format` and `showSeconds`, a note is ENTIRELY config), so "add it when
  /// something needs it" resolves to "add it now".
  ///
  /// Validated and CLAMPED ON READ, never on write — the same rule
  /// `SplashSpec.durationMs` and `IconSizing.parseScale` follow. Unknown keys
  /// are ignored and absent keys fall to the kind's default, so a config key
  /// written by a newer build degrades instead of failing to parse.
  final Map<String, Object?> config;

  bool get isPointLike => spanX == 1 && spanY == 1;

  /// Half-open on both axes: a desklet at col 2 with spanX 2 covers 2 and 3,
  /// and [right] is 4. Off-by-one here is an overlap bug that only shows up as
  /// two tiles drawn on top of each other.
  int get right => col + spanX;
  int get bottom => row + spanY;

  bool overlaps(Desklet other) {
    if (other.page != page) return false;
    return col < other.right &&
        other.col < right &&
        row < other.bottom &&
        other.row < bottom;
  }

  Desklet copyWith({
    int? page,
    int? col,
    int? row,
    int? spanX,
    int? spanY,
    Map<String, Object?>? config,
  }) =>
      Desklet(
        id: id,
        kind: kind,
        page: page ?? this.page,
        col: col ?? this.col,
        row: row ?? this.row,
        spanX: spanX ?? this.spanX,
        spanY: spanY ?? this.spanY,
        config: config ?? this.config,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        'page': page,
        'col': col,
        'row': row,
        'spanX': spanX,
        'spanY': spanY,
        // Omitted when empty: most desklets never carry config, and writing
        // `"config": {}` on every one of them bloats a file that is read on
        // every theme resolve.
        if (config.isNotEmpty) 'config': config,
      };

  /// Tolerant by design. A missing span or position reads as the safe minimum
  /// rather than throwing, because this parses content that may have been
  /// authored in an admin panel or shipped in a CDN starter desktop, and one
  /// bad field must not take the whole desktop down.
  static Desklet fromJson(Map<String, dynamic> j) => Desklet(
        id: j['id'] as String,
        kind: j['kind'] as String,
        page: (j['page'] as num?)?.toInt() ?? 0,
        col: (j['col'] as num?)?.toInt() ?? 0,
        row: (j['row'] as num?)?.toInt() ?? 0,
        spanX: (j['spanX'] as num?)?.toInt() ?? 1,
        spanY: (j['spanY'] as num?)?.toInt() ?? 1,
        config: ((j['config'] as Map?) ?? const {})
            .map((k, v) => MapEntry(k as String, v as Object?)),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Desklet &&
          other.id == id &&
          other.kind == kind &&
          other.page == page &&
          other.col == col &&
          other.row == row &&
          other.spanX == spanX &&
          other.spanY == spanY &&
          const MapEquality<String, Object?>().equals(other.config, config);

  @override
  int get hashCode => Object.hash(
        id,
        kind,
        page,
        col,
        row,
        spanX,
        spanY,
        const MapEquality<String, Object?>().hash(config),
      );
}
