import 'dart:ui';

import '../design/icon_sizing.dart';
import '../platform/launcher_api.g.dart' as api;
import 'boot_spec.dart';
import 'desklet_skin.dart';
import 'splash_spec.dart';
import 'terminal_spec.dart';
import 'theme_source.dart';
import 'wallpaper_framing.dart';

/// A distro, as data.
///
/// Palette, shell, dock side, icon treatment, wallpaper. That is a theme — and
/// because it is only data, a new distro ships over the CDN without a Play
/// release. Anything that would require new *code* to render is a sign the spec
/// is missing a field.
class ThemeSpec {
  const ThemeSpec({
    required this.id,
    required this.name,
    required this.version,
    required this.shell,
    required this.tier,
    required this.palette,
    this.paletteLight,
    required this.typography,
    required this.layout,
    required this.icons,
    required this.wallpapers,
    this.wallpapersLight = const [],
    this.wallpaperMeta = const {},
    this.fonts = const [],
    required this.minAppVersion,
    ChromeFamily? chromeFamily,
    this.logo,
    this.boot,
    this.splash,
    this.terminal,
    this.desklets = const DeskletThemeBlock(),
    this.home = const HomeBlock(),
    this.gestures = const {},
    this.categories = const [],
    this.categoryFallback,
    this.accents = const [],
    this.layouts = const [],
    this.surfaces,
    ThemeSource? source,
    // ─── STORED NULLABLE, RESOLVED IN THE GETTER ─────────────────────────
    //
    // This was `this.source = const ThemeSource.bundled()`, which took no
    // argument because bundled resolution used to be the identity function. It
    // resolves against `assets/themes/<id>/` now, so the default has to carry
    // the id.
    //
    // Defaulting it in the initializer list does not compile. This constructor
    // is `const`, so every initializer must be a POTENTIALLY CONSTANT
    // expression, and `ThemeSource.bundled(id)` is not one: object creation
    // only qualifies when it is written `const`, and `const` cannot take a
    // constructor parameter as an argument. The analyzer says
    // `invalid_constant` and it is right.
    //
    // So the resolution moves to [source], one line down. Dropping `const`
    // from this constructor would also have worked and is the worse trade: it
    // is the single most-constructed object in the theme layer.
  })  : _chromeFamily = chromeFamily,
        _source = source;

  final String id;
  final String name;
  final String version;

  /// Which shell widget renders it: gnome, plasma, tiling, tui.
  final ShellKind shell;

  /// A theme's explicit chrome-family override, or null to take the shell
  /// default. STORED nullable on purpose; read the [chromeFamily] getter, never
  /// this. Kept private so a caller can't accidentally read the un-resolved
  /// override and get a null.
  final ChromeFamily? _chromeFamily;

  /// The resolved chrome family (see [ChromeFamily]) — the STRUCTURAL design
  /// language of the launcher's own surfaces (Settings, dialogs, sheets), as
  /// opposed to [shell], which is the desktop metaphor.
  ///
  /// Resolution: the theme's explicit `chromeFamily`, else
  /// [ChromeFamily.defaultForShell]. Always non-null, so consumers never
  /// branch on absence. The five bundled themes name no family and resolve
  /// through the shell default: gnome->adwaita (Ubuntu, Fedora),
  /// plasma->breeze (KDE), tiling/tui->generic (Arch, terminal).
  ChromeFamily get chromeFamily =>
      _chromeFamily ?? ChromeFamily.defaultForShell(shell);

  final String tier;
  final ThemePalette palette;

  /// The LIGHT variant, when the distro ships one.
  ///
  /// Additive and optional, so every existing theme.json keeps parsing and a
  /// theme without this block simply has no light mode: [EffectiveTheme] falls
  /// back to [palette] rather than inventing a pale version of it. Inverting
  /// six colours algorithmically produces something that is technically light
  /// and looks like nothing any of these desktops ship, which is the opposite
  /// of the point.
  ///
  /// `palette` remains the DARK variant and keeps its name. Renaming it to
  /// `paletteDark` would have been tidier and would also have broken every
  /// bundled theme.json and every pack already published to the CDN.
  final ThemePalette? paletteLight;
  final ThemeTypography typography;
  final ThemeLayout layout;

  /// Passed straight to native. The launcher never renders icons in Dart.
  final api.IconStyle icons;

  /// The theme's preset wallpapers. The user adds their own on top; both live
  /// in prefs.wallpapers and rotate together.
  final List<String> wallpapers;

  /// Wallpapers for LIGHT mode, when the distro ships them.
  ///
  /// Empty means "use [wallpapers] in both modes", which is what every theme
  /// did before light mode existed and what the terminal will always do.
  ///
  /// ─── WHY A WALLPAPER HAS TO FOLLOW THE MODE ─────────────────────────────
  ///
  /// The launcher runs TRANSPARENT over the system wallpaper, so the wallpaper
  /// is the background of everything else. Switching the palette to light while
  /// leaving a dark photograph behind it gives a pale dock and a pale drawer
  /// floating on a near-black desktop, which does not read as a light theme at
  /// all: it reads as the chrome having lost its colour. Ubuntu has shipped
  /// `noble_light.webp` in its wallpapers list the whole time and nothing ever
  /// chose it.
  final List<String> wallpapersLight;

  /// How each of this theme's own wallpapers should meet the screen, keyed by
  /// the SAME string that appears in [wallpapers] or [wallpapersLight].
  ///
  /// ─── WHY THIS IS A SIDECAR MAP AND NOT A RICHER `wallpapers` ENTRY ───────
  ///
  /// The obvious shape is to promote each entry from a string to an object with
  /// a path and a framing block. It is wrong twice over. `wallpapers` is a
  /// published wire format: every pack in the bucket and every theme.json on
  /// someone's phone holds an array of strings, and `_wallpapers` already
  /// carries a legacy branch for the single `wallpaper.asset` form, so this
  /// would be the THIRD shape that parser has to tell apart. And the string is
  /// an identity elsewhere: `prefs.wallpaperCurrent` stores it, the rotation
  /// worker stores a list of them, `wallpaperContentStamp` digests them. A map
  /// keyed by that same string leaves all of those untouched.
  ///
  /// ─── WHY A THEME GETS A SAY AT ALL ──────────────────────────────────────
  ///
  /// Framing is per wallpaper and the user owns it, so this is only ever the
  /// STARTING POINT: prefs win the moment anyone drags. But without it every
  /// pack asset arrives centred with the default fit, and a distro whose art
  /// has its subject two thirds down the frame ships looking wrong until the
  /// user notices they can fix it. The author knows where the dragon is. This
  /// is how they say so.
  ///
  /// UNKNOWN KEYS ARE HARMLESS. A map entry naming a wallpaper this theme does
  /// not ship is simply never looked up, which is the tolerant-parser rule the
  /// rest of this file follows: a stale key from an older pack must not be
  /// fatal.
  final Map<String, WallpaperFraming> wallpaperMeta;

  /// Font families this theme ships, to be registered at runtime.
  ///
  /// ─── WHY A DISTRO CANNOT JUST NAME A FONT ───────────────────────────────
  ///
  /// [ThemeTypography] holds family NAMES, and a name only resolves if the
  /// family is declared in pubspec.yaml. That works for the bundled three, and
  /// it can never work for a pack downloaded after the APK was built: a CDN
  /// theme cannot edit pubspec.
  ///
  /// So a pack carries its font files and this block names them. `FontLoader`
  /// registers a family at runtime from bytes, which is the only route from a
  /// downloaded file to a resolvable family name.
  ///
  /// Empty for every theme that uses a bundled family, which is all of them
  /// today; nothing about the existing path changes.
  final List<ThemeFont> fonts;

  /// Gates against versionCode. A theme built for features this build does not
  /// have must refuse to load rather than render half-broken.
  final int minAppVersion;

  /// The theme's brand mark for the dock's app-drawer launch button and the
  /// launcher's own "G Launcher Settings" drawer entry. Light/dark artwork.
  ///
  /// Null falls back to the shell's glyph (dock) or the Mindhunter mark
  /// (drawer), so a theme without a logo degrades cleanly. It is only data, so a
  /// distro's mark ships over the CDN with the rest of the theme, no Play
  /// release.
  final ThemeLogo? logo;

  /// The fake Linux boot log this distro plays before the shell appears — the
  /// scrolling `[  OK  ]` systemd spew. Null falls back to
  /// `BootSpec.defaultForShell(shell)` at the call site, so a theme with no boot
  /// block still boots authentically for its shell family. Only data, so a
  /// distro's own boot sequence ships over the CDN with the rest of the theme.
  final BootSpec? boot;

  /// The quick splash shown while the desktop comes up — Plymouth's logo, KDE's
  /// progress bar, Arch's bare text. Null falls back to
  /// `SplashSpec.defaultForShell(shell)` at the call site, so a theme with no
  /// splash block still comes up looking like its family.
  ///
  /// This is what MOST launches show. [boot] is the opt-in verbose log for
  /// people who want the full `[  OK  ]` scroll; the two are alternatives, not
  /// a sequence — see home_screen, which plays one or the other.
  final SplashSpec? splash;

  /// This distro's terminal identity: the sixteen ANSI colours, the prompt, the
  /// drawer entry's label, and any aliases the pack binds.
  ///
  /// Null falls back to `TerminalSpec.defaultForShell(shell)` at the call site,
  /// the same promise [boot] and [splash] make, so a theme that predates this
  /// block still gets a terminal that looks like its family.
  ///
  /// ADDITIVE ON PURPOSE. [palette] carries six colours and none of them is an
  /// ANSI colour, so a terminal cannot be drawn from it. Widening ThemePalette
  /// to sixteen would have made every theme.json and every published pack
  /// declare colours that only one surface reads.
  ///
  /// A theme having a terminal is INDEPENDENT of its shell being `tui`. Kali is
  /// `shell: gnome` and needs one, because the Terminal app is a drawer entry
  /// and gnome distros have drawers.
  final TerminalSpec? terminal;

  /// What this distro puts on its desktop, and how it draws it. PHASE D3.
  ///
  /// Three things in one block, and they are three different concerns wearing
  /// the same roof only because they are all authored together:
  ///   * `offers`  which desklet kinds appear in this distro's picker
  ///   * `starter` the desktop laid out the first time the theme is chosen
  ///   * `skins`   per-kind look, merged over the shell family default
  ///
  /// Never null, so no caller needs a `?? const DeskletThemeBlock()`. A theme
  /// with no block gets shell defaults for everything, which is the same
  /// promise `boot` and `splash` make with their `defaultForShell`.
  final DeskletThemeBlock desklets;

  /// The desktop ICON grid this distro starts with. [DeskletThemeBlock]'s
  /// sibling, and deliberately a separate block: a desklet is a widget the app
  /// owns by `kind`, an icon is somebody's installed app, and the two cannot
  /// share a starter list because a theme author cannot know what is installed.
  ///
  /// See [HomeBlock.fill] for why this is a COUNT and not a list of apps.
  ///
  /// Never null, for the same reason [desklets] is not: a theme with no block
  /// gets a fill of zero, which is the empty desktop every distro has today.
  final HomeBlock home;

  /// The distro's DEFAULT gesture bindings, gestureId to binding string, in
  /// the same encoding `LauncherPrefs.gestures` uses (a GestureAction id, or
  /// "app:<componentKey>").
  ///
  /// ─── THE HARD RULE: A DISTRO NEVER REBINDS A SET GESTURE ─────────────────
  ///
  /// A theme default applies ONLY to a gesture the user has never bound.
  /// Several actions are driven by an accessibility service the user granted
  /// for a specific purpose, and a distro silently rebinding one is not the
  /// same kind of choice as a distro choosing a dock side. The touched marker
  /// is entry presence in `prefs.gestures`: the Settings sheet always writes an
  /// explicit entry, including when the user re-picks the value already on
  /// screen, and never deletes one. So a user entry beats this map
  /// unconditionally, this map beats `defaultGestures`, and switching distro
  /// can never rebind a deliberate choice. The one place that resolution
  /// lives is `bindingFor` in gesture_actions.dart.
  ///
  /// Kept as raw strings on parse; an action id from a newer catalogue is
  /// screened out in `bindingFor` (falling through to `defaultGestures`, not
  /// decoding to a dead gesture), which keeps the known-id list beside the
  /// enum it belongs to rather than duplicated here.
  final Map<String, String> gestures;

  /// Where this theme's FILES live: the APK's asset bundle, or an installed
  /// pack directory.
  ///
  /// NOT PARSED FROM JSON, and it must never be. It is not a property the
  /// author of a theme knows or gets to assert — the same authored `theme.json`
  /// is bundled in one build and downloaded in the next. It is set by whoever
  /// LOADED the file, which is the only code that can possibly know the answer,
  /// and that is `theme_engine.dart`.
  ///
  /// Defaults to bundled so every existing construction site, test and fixture
  /// compiles and behaves exactly as before.
  /// Null means bundled, and is not the same as "unknown". Read [source], never
  /// this: a null here is a spec that came out of [fromJson] over an asset in
  /// the APK, and the getter is what turns that into a resolvable source.
  ///
  /// Private so a caller cannot accidentally read the unresolved value and get
  /// a null, exactly as [_chromeFamily] is.
  final ThemeSource? _source;

  /// Where this theme's files live, always answerable.
  ///
  /// The loader stamps [ThemeSource.installed] onto a pack immediately after
  /// parsing it and `theme_peek` stamps [ThemeSource.remote], so this fallback
  /// is only reached by a theme read out of the asset bundle. Which is the one
  /// case that knows its own directory from its id.
  ///
  /// Allocates on each read rather than caching, which is affordable because
  /// [ThemeSource] is two nullable strings with value equality: a caller that
  /// holds two of these compares them as equal, so nothing downstream can tell
  /// the difference between this and a cached field.
  ThemeSource get source => _source ?? ThemeSource.bundled(id);

  /// This distro's own category vocabulary, in display order. Empty means the
  /// built-in set (Social, Media, Productivity, Games, News, Travel, Utilities,
  /// Other), which is what every distro shipping today gets. See
  /// [ThemeCategory].
  final List<ThemeCategory> categories;

  /// The accent colours this distro offers, in the order the picker shows them.
  ///
  /// ─── WHY A DISTRO SHIPS A LIST AND NOT A COLOUR WHEEL ───────────────────
  ///
  /// A free picker is one line of code and it destroys the thing being sold.
  /// Zorin ships six accents, Ubuntu ships ten, and both chose theirs against
  /// their own wallpapers and their own chrome; a user who lands on a colour
  /// nobody vetted gets a desktop that looks like the distro is broken rather
  /// than like they customised it. The authored set is the product.
  ///
  /// EMPTY IS THE NORMAL CASE and means this distro offers no choice at all:
  /// [ThemePalette.accent] stands alone, which is what every theme did before
  /// this field existed. So nothing moves until a pack authors it.
  ///
  /// The list does NOT have to contain [ThemePalette.accent]. When it does, the
  /// matching entry reads as selected on a fresh install; when it does not, the
  /// picker simply has no selection until one is made, which is honest.
  final List<ThemeAccent> accents;

  /// This distro's named layout presets, in the order the picker shows them.
  ///
  /// ─── WHY A PRESET IS A WHOLE LAYOUT AND NOT A DIFF AT RUNTIME ───────────
  ///
  /// Each entry here is already MERGED: the preset's JSON is shallow-merged
  /// over the distro's own `layout` at parse, where both maps are still in
  /// scope, and the result is a complete [ThemeLayout]. So nothing downstream
  /// merges anything. [LayoutResolver] takes one layout and applies the user's
  /// overrides to it exactly as it always has, and no shell, no drawer and no
  /// panel learns that presets exist.
  ///
  /// The merge is SHALLOW on purpose. A preset naming `panels` replaces the
  /// panel list wholesale rather than merging panel-by-panel, because "the
  /// macOS-like layout has a top bar with these four modules" is a statement
  /// about the whole bar, and a deep merge would leave it carrying leftover
  /// modules from the layout it replaced.
  ///
  /// EMPTY IS THE NORMAL CASE and means this distro has one layout, which is
  /// every theme shipping today. See [layoutFor].
  final List<ThemeLayoutPreset> layouts;

  /// How solid, how blurred and how tinted this distro's glass is.
  ///
  /// ─── THE DISTRO IS THE ROOT OF THE CHAIN, NOT A FOURTH LEVEL ────────────
  ///
  /// `EffectiveTheme` already resolves the dock, the bar and the drawer as
  /// "this section's own setting, else the main slider, else solid". This adds
  /// exactly one step under the main slider and changes nothing above it: the
  /// section rows still Follow the main slider, and the main slider now Follows
  /// the distro. Authoring per-section values here would make three levels into
  /// four and give "Follow" two possible meanings on one screen.
  ///
  /// ─── AND WHY IT MATTERS MORE THAN IT LOOKS ──────────────────────────────
  ///
  /// The default was a hardcoded 1.0, so every distro shipped fully opaque and
  /// nothing in the catalogue was translucent until someone found the slider.
  /// Garuda's entire identity is glass; it looked like every other dark distro
  /// out of the box, and the reason was one constant.
  ///
  /// Null means the old constants, so every theme that authors nothing renders
  /// exactly as it did.
  final ThemeSurfaces? surfaces;

  /// Where an app lands when nothing in [categories] claims it.
  ///
  /// Null takes the built-in 'Other'. Kali names it 'Usual Applications',
  /// which is the bucket real Kali puts ordinary software in, and which is why
  /// its thirteen tool groups can honestly start empty.
  final String? categoryFallback;

  /// Same theme, told where it came from. Used by the loader immediately after
  /// [fromJson], which cannot know.
  ThemeSpec withSource(ThemeSource source) => ThemeSpec(
        id: id,
        name: name,
        version: version,
        shell: shell,
        tier: tier,
        palette: palette,
        paletteLight: paletteLight,
        typography: typography,
        layout: layout,
        icons: icons,
        wallpapers: wallpapers,
        wallpapersLight: wallpapersLight,
        wallpaperMeta: wallpaperMeta,
        fonts: fonts,
        minAppVersion: minAppVersion,
        // The PRIVATE override, not the resolved getter. Passing
        // `chromeFamily` would bake the shell default into the field, so a
        // theme that named no family would come out the other side asserting
        // one — and a later change to `defaultForShell` would then be ignored
        // for every theme that had been through here.
        chromeFamily: _chromeFamily,
        logo: logo,
        boot: boot,
        splash: splash,
        // ─── DROPPED FOR THE WHOLE LIFE OF THIS METHOD ──────────────────
        //
        // Exactly the omission the `categories` note below warns about, and it
        // went unnoticed for exactly the reason that note gives: `withSource`
        // only runs for INSTALLED packs, so every bundled distro kept its
        // terminal block and every CDN one silently lost it. A downloaded Kali
        // fell back to the generic sixteen ANSI colours and the default prompt
        // while the bundled terminal looked right, which reads as the CDN
        // pack having been authored without one.
        terminal: terminal,
        desklets: desklets,
        home: home,
        gestures: gestures,
        // CARRIED. `withSource` reconstructs the whole spec, so a field added
        // to the constructor and forgotten here is silently dropped the moment
        // the loader stamps a pack's source onto it, which is every CDN distro
        // and none of the bundled ones. That asymmetry is why the omission
        // would survive testing on the emulator.
        categories: categories,
        categoryFallback: categoryFallback,
        // CARRIED, for the reason the note above gives. An accent list dropped
        // here would leave every CDN distro with no picker and every bundled
        // one with a working one, which is the exact asymmetry that hid the
        // `terminal` omission for the whole life of this method.
        accents: accents,
        layouts: layouts,
        surfaces: surfaces,
        source: source,
      );

  /// The layout to actually resolve against: the named preset, else this
  /// distro's own.
  ///
  /// ─── AN UNKNOWN ID FALLS BACK RATHER THAN FAILING ───────────────────────
  ///
  /// `prefs.layoutPreset` is per theme and survives a pack update, so an id
  /// that a later version retires must not leave the launcher with no layout at
  /// all. Falling back to [layout] gives the distro's default, which is exactly
  /// what a user who never chose a preset sees, and the stored id is left alone
  /// so reinstating the preset reinstates their choice. Same contract
  /// `EffectiveTheme.accent` follows for the same reason.
  ///
  /// The DEFAULT preset is not applied automatically. A theme marking one
  /// `default: true` is describing which card reads as selected before anyone
  /// has chosen, and that card must paint the same layout [layout] already
  /// produces, or the picker would show a selection that does not match the
  /// desktop behind it.
  ThemeLayout layoutFor(String? presetId) {
    final id = presetId?.trim();
    if (id == null || id.isEmpty) return layout;
    for (final p in layouts) {
      if (p.id == id) return p.layout;
    }
    return layout;
  }

  /// Resolve one of this theme's own asset paths (a wallpaper, a logo) to
  /// something openable. Shorthand for `source.asset(path)`.
  ThemeAsset asset(String path) => source.asset(path);

  /// The brand mark for a surface, RESOLVED.
  ///
  /// ─── THE THIRD TIME THIS BUG WAS FIXED, SO IT IS FIXED HERE INSTEAD ─────
  ///
  /// [logo] is a pair of strings and every reader has to do two things with
  /// them: pick the variant matching the surface, and resolve the path through
  /// [source] so an installed pack's bare `logo_dark.webp` becomes a file
  /// rather than an asset-bundle lookup that finds nothing.
  ///
  /// Three readers did the first and skipped the second: the splash, the
  /// drawer's `LauncherBrandIcon`, and the Aqua menu bar. Each produced the
  /// same `Unable to load asset: "logo_dark.webp"` the moment a distro was
  /// republished over the CDN, logged once into a console nobody watches, and
  /// drew a hole where the mark should be. Fixing them one at a time was three
  /// fixes and a fourth caller waiting to be written.
  ///
  /// So the composition lives here. A reader asks for the mark BY SURFACE and
  /// gets something openable or null, with no string to mishandle on the way.
  ///
  /// [onDarkSurface] describes the surface the mark will be painted on, not the
  /// ink of the artwork. See [ThemeLogo]: the semantics are by surface
  /// precisely because getting that backwards is easy.
  ThemeAsset? logoAsset({required bool onDarkSurface}) {
    final l = logo;
    if (l == null) return null;
    final path = onDarkSurface ? l.dark : l.light;
    if (path.isEmpty) return null;
    return source.asset(path);
  }

  static ThemeSpec fromJson(Map<String, dynamic> json) {
    final icons = (json['icons'] as Map?)?.cast<String, dynamic>() ?? const {};

    return ThemeSpec(
      id: json['id'] as String,
      name: json['name'] as String,
      version: json['version'] as String? ?? '',
      shell: ShellKind.parse(json['shell'] as String?),
      tier: json['tier'] as String? ?? 'free',
      paletteLight: json['paletteLight'] is Map
          ? ThemePalette.fromJson(
              (json['paletteLight'] as Map).cast<String, dynamic>(),
            )
          : null,
      palette: ThemePalette.fromJson(
        (json['palette'] as Map).cast<String, dynamic>(),
      ),
      typography: ThemeTypography.fromJson(
        (json['typography'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      layout: ThemeLayout.fromJson(_rawLayout(json)),
      icons: api.IconStyle(
        treatment: _treatment(icons['treatment'] as String?),
        cornerRadius: (icons['cornerRadius'] as num?)?.toDouble() ?? 0.22,
        foregroundScale: (icons['foregroundScale'] as num?)?.toDouble() ?? 1.0,
        backgroundColor:
            parseColor(icons['backgroundColor'] as String?)?.toARGB32(),
        monochromeTint:
            parseColor(icons['monochromeTint'] as String?)?.toARGB32(),
        heroPack: icons['heroPack'] as String?,
        backgroundGradientEnd:
            parseColor(icons['backgroundGradientEnd'] as String?)?.toARGB32(),
        gradientAngle: (icons['gradientAngle'] as num?)?.toDouble(),
        brandPack: icons['brandPack'] as String?,
        brandTreatment: icons['brandTreatment'] as String?,
      ),
      wallpapers: _wallpapers(json),
      wallpapersLight: ((json['wallpapersLight'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      wallpaperMeta: _wallpaperMeta(json),
      fonts: ((json['fonts'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => ThemeFont.fromJson(e.cast<String, dynamic>()))
          .where((f) => f.isUsable)
          .toList(),
      minAppVersion: (json['minAppVersion'] as num?)?.toInt() ?? 0,
      logo: ThemeLogo.fromJson(json['logo']),
      boot: BootSpec.fromJson(
        (json['boot'] as Map?)?.cast<String, dynamic>(),
      ),
      splash: SplashSpec.fromJson(
        (json['splash'] as Map?)?.cast<String, dynamic>(),
      ),
      terminal: TerminalSpec.fromJson(
        (json['terminal'] as Map?)?.cast<String, dynamic>(),
      ),
      desklets: DeskletThemeBlock.fromJson(
        (json['desklets'] as Map?)?.cast<String, dynamic>(),
      ),
      home: HomeBlock.fromJson(
        (json['home'] as Map?)?.cast<String, dynamic>(),
      ),
      // String entries only; anything else is dropped rather than fatal. The
      // action ids are NOT validated here (see the field doc): bindingFor
      // screens them beside the enum, so this stays a dumb carrier.
      gestures: {
        for (final e in ((json['gestures'] as Map?) ?? const {}).entries)
          if (e.key is String && e.value is String)
            e.key as String: e.value as String,
      },
      // Explicit override only. A null here (key absent, or an unknown value
      // from a newer CDN theme) lets the ThemeSpec.chromeFamily getter fall
      // back to the shell default, so the bundled themes need no JSON change.
      chromeFamily: ChromeFamily.parse(json['chromeFamily'] as String?),
      // A malformed entry is DROPPED, not fatal, matching every other list in
      // this file. A category with no name is a rail slot nobody can read.
      categories: ((json['categories'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => ThemeCategory.fromJson(e.cast<String, dynamic>()))
          .whereType<ThemeCategory>()
          .toList(),
      categoryFallback: (json['categoryFallback'] as String?)?.trim(),
      // Same tolerance as `categories`: an entry with no id or an unparseable
      // colour is dropped rather than fatal, because a pack authored against a
      // newer builder must still install.
      accents: ((json['accents'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => ThemeAccent.fromJson(e.cast<String, dynamic>()))
          .whereType<ThemeAccent>()
          .toList(),
      surfaces: ThemeSurfaces.fromJson(
        (json['surfaces'] as Map?)?.cast<String, dynamic>(),
      ),
      // Merged HERE, where the base layout map is still in scope. Doing it at
      // resolve time would mean carrying the raw JSON on the spec for the whole
      // life of the app so that one getter could re-parse it on every frame.
      layouts: ((json['layouts'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => ThemeLayoutPreset.fromJson(
                e.cast<String, dynamic>(),
                _rawLayout(json),
              ))
          .whereType<ThemeLayoutPreset>()
          .toList(),
    );
  }

  /// The distro's own `layout` map, or an empty one.
  ///
  /// Read twice during parse, by the base layout and by every preset merging
  /// over it, and a second spelling of this would eventually disagree about
  /// what an absent `layout` key means.
  static Map<String, dynamic> _rawLayout(Map<String, dynamic> json) =>
      (json['layout'] as Map?)?.cast<String, dynamic>() ?? const {};

  /// Accepts a "wallpapers" list, and still reads the old single
  /// wallpaper.asset — a theme already on someone's phone must not stop working
  /// because we changed the manifest shape.
  static List<String> _wallpapers(Map<String, dynamic> json) {
    final list = json['wallpapers'] as List?;
    if (list != null) return list.map((e) => e as String).toList();

    final legacy = (json['wallpaper'] as Map?)?['asset'] as String?;
    return legacy == null ? const [] : [legacy];
  }

  /// Reads the optional `wallpaperMeta` block.
  ///
  /// A malformed entry is DROPPED rather than fatal, matching every other map
  /// and list in this file. The failure mode of a bad framing block is a
  /// wallpaper that sits where it always used to sit, which is survivable; the
  /// failure mode of throwing is a theme that will not load.
  static Map<String, WallpaperFraming> _wallpaperMeta(
    Map<String, dynamic> json,
  ) {
    final raw = json['wallpaperMeta'] as Map?;
    if (raw == null || raw.isEmpty) return const {};
    return {
      for (final e in raw.entries)
        if (e.key is String && e.value is Map)
          e.key as String:
              WallpaperFraming.fromJson(
            (e.value as Map).cast<String, dynamic>(),
          ),
    };
  }

  static api.IconTreatment _treatment(String? raw) {
    switch (raw) {
      case 'circle':
        return api.IconTreatment.circle;
      case 'squircle':
        return api.IconTreatment.squircle;
      case 'square':
        return api.IconTreatment.square;
      case 'teardrop':
        return api.IconTreatment.teardrop;
      case 'original':
        return api.IconTreatment.original;
      case 'roundedSquare':
      default:
        // Unknown treatment from a newer CDN theme degrades to the sane default
        // rather than throwing. A theme from the future should look slightly
        // wrong, not crash the home screen.
        return api.IconTreatment.roundedSquare;
    }
  }
}

/// A theme's brand mark, as light/dark artwork.
///
/// Two variants on purpose: a real logo is COLOURED, and srcIn-tinting one asset
/// to fit both backgrounds throws that colour away (flattening it to a
/// silhouette). [light] is shown on a light surface, [dark] on a dark one.
///
/// Semantics are by SURFACE, not by ink: `light` = "use on a light background",
/// `dark` = "use on a dark background". Assign the files accordingly in
/// theme.json. When a theme ships only one, both point at it, so a single-asset
/// theme still renders (just without mode-matching).
/// One bucket in a distro's own category vocabulary.
///
/// ─── THE VOCABULARY IS THE DISTRO, THE FILING RULE IS NOT ───────────────────
///
/// `builtInBucket` in drawer_items reads `ApplicationInfo.category`, which
/// the app declares about itself, and its doc is emphatic that nothing may be
/// inferred from a package name: a drawer that groups less but never lies is
/// worth more than one that groups everything and is sometimes absurd.
///
/// A distro authoring categories does not get to break that. It supplies the
/// NAMES and the ORDER, and [feeds] says which of the built-in buckets pour
/// into each one. Anything unmapped lands in [ThemeSpec.categoryFallback].
///
/// For Kali that means [feeds] is EMPTY on all thirteen tool groups, because no
/// Android category honestly maps to "01 Information Gathering" and pretending
/// Chrome is a reconnaissance tool is the absurdity that rule exists to
/// prevent. Real Kali does the same thing: ordinary applications live under
/// Usual Applications and 01 through 13 hold tools. On a phone those thirteen
/// start empty and the user fills them, which is what makes the CRUD the
/// feature rather than a consolation.
/// A distro's own glass: how solid, how blurred, how tinted, how rounded.
///
/// ─── EVERY FIELD IS NULLABLE AND NULL MEANS THE OLD CONSTANT ────────────────
///
/// A theme authoring only `blur` must not silently reset the other three to
/// something it never chose. So this is four independent opt-ins rather than a
/// block with defaults, and `EffectiveTheme` reads each one separately.
///
/// ─── THE THEME MAY GO BELOW THE USER'S FLOOR ────────────────────────────────
///
/// `surfaceOpacity` clamps user values to 0.6, and `settings_rows.dart` gives
/// the reason: under that a settings page stops being readable over an
/// arbitrary photograph. That reasoning assumes NO BLUR. At 24 logical pixels
/// the wallpaper behind a panel is a wash rather than a photograph, and 0.4 is
/// perfectly legible.
///
/// So the authored floor is 0.35 and the user's stays 0.6. The asymmetry is the
/// point: a distro author has seen the result on their own wallpapers and
/// chosen it, and somebody dragging a slider has not. Nobody can drag their way
/// to an unreadable launcher; a pack can ship one deliberately.
class ThemeSurfaces {
  const ThemeSurfaces({this.opacity, this.blur, this.tint, this.radius});

  /// 0.35 to 1.0. The ROOT of the opacity chain, under the main slider.
  final double? opacity;

  /// 0 to 24 logical pixels. Zero switches the BackdropFilter off entirely,
  /// which is a real answer for a distro that wants flat chrome.
  final double? blur;

  /// 0 is neutral grey, 1 is fully the distro's own colour.
  final double? tint;

  /// Logical pixels, capped at 28 for the reason [EffectiveTheme.panelRadius]
  /// gives: past that a sheet's corners eat the grab handle.
  final double? radius;

  static ThemeSurfaces? fromJson(Map<String, dynamic>? j) {
    if (j == null) return null;
    double? num_(Object? v) => (v as num?)?.toDouble();
    final out = ThemeSurfaces(
      opacity: num_(j['opacity']),
      blur: num_(j['blur']),
      tint: num_(j['tint']),
      radius: num_(j['radius']),
    );
    // A block that authored nothing readable is the same as no block. Returning
    // an empty instance would work, and would also make `spec.surfaces != null`
    // a lie that a later reader would have to test around.
    if (out.opacity == null &&
        out.blur == null &&
        out.tint == null &&
        out.radius == null) {
      return null;
    }
    return out;
  }
}

/// One named layout this distro offers.
///
/// Zorin Appearance is the reference: one install, several desktops, chosen by
/// the user rather than by reinstalling. It is the single feature that cannot
/// be reproduced by the all-access settings, because those move one field at a
/// time and a layout is a coherent set of them that somebody designed together.
class ThemeLayoutPreset {
  const ThemeLayoutPreset({
    required this.id,
    required this.name,
    required this.layout,
    this.summary,
    this.isDefault = false,
  });

  /// Stable and permanent once published: `prefs.layoutPreset` stores it, so
  /// renaming one drops every user who chose it back to the distro's default.
  final String id;

  final String name;

  /// One short line under the card. Null renders no line, never a placeholder.
  final String? summary;

  /// Reads as selected before the user has chosen. See [ThemeSpec.layoutFor]
  /// for why it is not applied.
  final bool isDefault;

  /// Already merged over the distro's base layout. See [ThemeSpec.layouts].
  final ThemeLayout layout;

  static ThemeLayoutPreset? fromJson(
    Map<String, dynamic> j,
    Map<String, dynamic> baseLayout,
  ) {
    final id = (j['id'] as String?)?.trim();
    if (id == null || id.isEmpty) return null;
    final name = (j['name'] as String?)?.trim();
    final summary = (j['summary'] as String?)?.trim();
    final over = (j['layout'] as Map?)?.cast<String, dynamic>() ?? const {};
    return ThemeLayoutPreset(
      id: id,
      // An unnamed preset would be a blank card. The id is a poor label and a
      // better one than nothing, and it makes the omission visible in the
      // picker rather than invisible.
      name: (name == null || name.isEmpty) ? id : name,
      summary: (summary == null || summary.isEmpty) ? null : summary,
      isDefault: j['default'] == true,
      layout: ThemeLayout.fromJson({...baseLayout, ...over}),
    );
  }
}

/// One accent this distro offers.
///
/// ─── THE ID IS THE STORED VALUE, NOT THE COLOUR ─────────────────────────────
///
/// `prefs.accentId` holds the id, so a pack update that retunes its blue moves
/// every user who chose blue rather than stranding them on the old hex. Storing
/// the colour would freeze each user's desktop at the version they happened to
/// pick on, and the whole reason themes are data is that the author can still
/// change their mind.
///
/// It also means an id is permanent once published. Renaming one silently
/// resets every user who chose it back to the distro default.
class ThemeAccent {
  const ThemeAccent({
    required this.id,
    required this.name,
    required this.value,
  });

  /// Stable, lowercase, and never reused for a different colour.
  final String id;

  /// Shown under the swatch. Not derived from [id], because "Grey" and "grey"
  /// are a label and a key and only one of them should ever be translated.
  final String name;

  final Color value;

  static ThemeAccent? fromJson(Map<String, dynamic> j) {
    final id = (j['id'] as String?)?.trim();
    if (id == null || id.isEmpty) return null;
    final value = parseColor(j['value'] as String?);
    // No fallback colour. An accent that cannot be parsed is a swatch that
    // would render as something nobody authored, and a picker offering a
    // colour the distro did not choose is worse than a picker with five
    // entries instead of six.
    if (value == null) return null;
    final name = (j['name'] as String?)?.trim();
    return ThemeAccent(
      id: id,
      name: (name == null || name.isEmpty) ? id : name,
      value: value,
    );
  }
}

class ThemeCategory {
  const ThemeCategory({
    required this.name,
    this.feeds = const [],
    this.glyph,
  });

  /// The label, and the folder id. Shown in the rail and on the folder tile.
  final String name;

  /// Built-in bucket names ('Social', 'Media', 'Games', 'News', 'Travel',
  /// 'Productivity', 'Utilities') that file into this category. Empty means
  /// nothing arrives automatically.
  final List<String> feeds;

  /// The icon this bucket wears, as a `folder_glyphs.dart` catalogue id.
  ///
  /// The distro's DEFAULT, not a lock: a user who picks their own writes it
  /// onto the folder and that wins forever after. Null means the fallback,
  /// which is what every theme authored before this field existed gets.
  ///
  /// An id this build does not know resolves to the fallback rather than to
  /// nothing, so a pack authored against a newer catalogue degrades to a plain
  /// folder instead of an empty square.
  final String? glyph;

  static ThemeCategory? fromJson(Map<String, dynamic> j) {
    final name = (j['name'] as String?)?.trim();
    if (name == null || name.isEmpty) return null;
    final glyph = (j['glyph'] as String?)?.trim();
    return ThemeCategory(
      name: name,
      feeds: [
        for (final f in (j['feeds'] as List?) ?? const [])
          if ('$f'.trim().isNotEmpty) '$f'.trim(),
      ],
      glyph: (glyph == null || glyph.isEmpty) ? null : glyph,
    );
  }
}

class ThemeLogo {
  const ThemeLogo({required this.light, required this.dark});

  /// Shown on a LIGHT surface (typically the darker-ink artwork).
  final String light;

  /// Shown on a DARK surface (typically the lighter-ink artwork).
  final String dark;

  /// Accepts either a bare string (one asset for both modes) or an object
  /// `{"light": "…", "dark": "…"}`. Either key may be omitted and falls back to
  /// the other. All-null, or an unexpected shape, yields null so the caller
  /// falls back to its glyph / the Mindhunter mark.
  static ThemeLogo? fromJson(Object? j) {
    if (j is String) return ThemeLogo(light: j, dark: j);
    if (j is Map) {
      final m = j.cast<String, dynamic>();
      final light = m['light'] as String?;
      final dark = m['dark'] as String?;
      final base = light ?? dark;
      if (base == null) return null;
      return ThemeLogo(light: light ?? base, dark: dark ?? base);
    }
    return null;
  }
}

enum ShellKind {
  gnome,
  plasma,
  tiling,
  tui,

  /// macOS. Menu bar across the top, magnifying dock centred at the bottom.
  ///
  /// APPENDED, and every switch over this enum is exhaustive with no default
  /// arm, so adding it here deliberately broke the build in six places until
  /// each one chose an answer on purpose. That is the design working: a shell
  /// with a silently-defaulted boot log, splash and drawer would ship looking
  /// like GNOME wearing a different palette.
  aqua;

  static ShellKind parse(String? raw) => switch (raw) {
        'plasma' => ShellKind.plasma,
        'tiling' => ShellKind.tiling,
        'tui' => ShellKind.tui,
        'aqua' => ShellKind.aqua,
        _ => ShellKind.gnome,
      };
}

/// The design language the launcher's OWN surfaces are dressed in — the
/// structural axis of theming, orthogonal to both [ShellKind] and the palette.
///
/// [ShellKind] decides what the desktop looks like (GNOME top bar + dock, KDE
/// bottom panel, tiling waybar, TUI). ChromeFamily decides what Settings,
/// dialogs, bottom sheets, and folder popovers look like: an Adwaita
/// sidebar-plus-content page under GNOME distros, a Breeze framing under KDE,
/// Aqua under macOS, or a neutral generic fallback.
///
/// It is a small, closed set on purpose. Distros within a family SHARE their
/// chrome, so a new GNOME distro (Pop!_OS, Zorin, Mint-GNOME) inherits its whole
/// Settings look for free by resolving to [adwaita] — the entire point of B1.
/// The colours still come per-distro from the palette (see the chrome layer);
/// the family only decides structure.
///
/// [aqua] now resolves from [ShellKind.aqua], which the bundled Aqua theme
/// names. It is still nameable explicitly by any theme that wants Mac-style
/// chrome over a different desktop metaphor.
enum ChromeFamily {
  adwaita,
  breeze,

  /// Xfce, and the reason it is not [generic].
  ///
  /// ─── FIVE DISTROS WERE SHARING THE FALLBACK ─────────────────────────────
  ///
  /// Kali, Manjaro, Arch, EndeavourOS and Terminal all resolved to [generic],
  /// which is the bucket everything unclaimed falls into rather than a design
  /// language anyone ships. So the five most distinct desktops in the catalogue
  /// had the identical menu and the identical settings page.
  ///
  /// Xfce is a real answer with real conventions and two of them are visible on
  /// a phone: its menus are dense lists WITH icons and no separators, and its
  /// Settings is a GRID of icons rather than a list of rows. Nothing else in
  /// the catalogue looks like the Settings Manager.
  ///
  /// APPENDED, and every switch over this enum is exhaustive with no default
  /// arm, so adding it here deliberately breaks the build at each site that
  /// decides something on family until that site chooses. That is the same
  /// treatment [ShellKind.aqua] got, and it is what stops a fifth family
  /// shipping as a fourth one wearing a different name.
  xfce,

  /// A tiling window manager: i3, Hyprland, sway.
  ///
  /// The SIXTH, and it exists because [xfce] took half of what [generic] used
  /// to hold and the other half is not the same desktop. Kali and Manjaro are
  /// Xfce; Arch, EndeavourOS and the terminal are window managers, and the two
  /// differ on the axis that carries most: an Xfce menu is a dense list WITH
  /// icons, and a WM's menus are text. That is the same reason its launcher is
  /// dmenu rather than a card, so the family and [ThemeLayout.tilingLauncher]
  /// are saying one thing in two places rather than two things.
  ///
  /// Nothing rounds. `generic` is still the fallback and still rounds by 12,
  /// which is a sane neutral and is exactly wrong for a desktop whose entire
  /// visual argument is corners.
  wm,

  aqua,

  /// A phone's home screen. The seventh, and the only one not named after a
  /// desktop, because the product it belongs to is not one.
  ///
  /// ─── AND NOT NAMED AFTER THE PHONE EITHER ───────────────────────────────
  ///
  /// Named for the product. A family name reaches the source, the panel's
  /// dropdown and every theme.json that ever uses it, which is the one place a
  /// careless name is permanent and the one place a trademark would sit
  /// forever.
  ///
  /// ─── WHAT IT DECIDES ────────────────────────────────────────────────────
  ///
  /// [aqua] draws a plain separated list at the screen centre, which is a Mac's
  /// menu and correct for elementary and Deepin. A phone's app menu lifts the
  /// icon you held, dims the rest, and opens a rounded card beneath it, with
  /// hairlines between the rows and a trailing glyph on each. Same information,
  /// a different object.
  pocket,
  generic;

  /// Parse a theme.json `chromeFamily` value. Unknown or absent yields null so
  /// the caller can fall back to the shell default — a value from a newer CDN
  /// theme this build doesn't recognise degrades to the shell default rather
  /// than throwing, same contract as [ShellKind.parse] and the icon treatment.
  static ChromeFamily? parse(String? raw) => switch (raw) {
        'adwaita' => ChromeFamily.adwaita,
        'breeze' => ChromeFamily.breeze,
        'xfce' => ChromeFamily.xfce,
        'wm' => ChromeFamily.wm,
        'aqua' => ChromeFamily.aqua,
        'pocket' => ChromeFamily.pocket,
        'generic' => ChromeFamily.generic,
        _ => null,
      };

  /// The family a shell defaults to when a theme names none. This IS the
  /// "default map for the bundled themes"; it collapses to a shell rule because
  /// family tracks shell:
  ///   gnome  -> adwaita   (Ubuntu, Fedora)
  ///   plasma -> breeze    (KDE)
  ///   tiling -> generic   (Arch)
  ///   tui    -> generic   (terminal)
  ///
  /// [ChromeFamily.xfce] is NOT a default for any shell, deliberately. No shell
  /// implies Xfce: Kali runs it on what this app calls the gnome shell (a bar
  /// plus a dock), and a distro that wants it says so. Making it the default
  /// for anything would hand it to distros that never asked, which is how
  /// `generic` ended up covering five desktops.
  /// Exhaustive over [ShellKind] with no default arm, so adding a shell (Aqua)
  /// is a compile error here until its family is chosen deliberately.
  static ChromeFamily defaultForShell(ShellKind shell) => switch (shell) {
        ShellKind.gnome => ChromeFamily.adwaita,
        ShellKind.plasma => ChromeFamily.breeze,
        ShellKind.tiling => ChromeFamily.generic,
        ShellKind.tui => ChromeFamily.generic,
        ShellKind.aqua => ChromeFamily.aqua,
      };
}

class ThemePalette {
  const ThemePalette({
    required this.bgTop,
    required this.bgBottom,
    required this.bar,
    required this.dock,
    required this.accent,
    required this.onDark,
  });

  final Color bgTop;
  final Color bgBottom;
  final Color bar;
  final Color dock;
  final Color accent;
  final Color onDark;

  static ThemePalette fromJson(Map<String, dynamic> j) => ThemePalette(
        bgTop: parseColor(j['bgTop'] as String?) ?? const Color(0xFF2C0A22),
        bgBottom:
            parseColor(j['bgBottom'] as String?) ?? const Color(0xFF220817),
        bar: parseColor(j['bar'] as String?) ?? const Color(0xFF1A171B),
        dock: parseColor(j['dock'] as String?) ?? const Color(0xBD201B21),
        accent: parseColor(j['accent'] as String?) ?? const Color(0xFFE95420),
        onDark: parseColor(j['onDark'] as String?) ?? const Color(0xFFFFFFFF),
      );

  /// This palette with a different accent.
  ///
  /// Exists for [EffectiveTheme.palette] and nothing else. A full `copyWith`
  /// was the obvious spelling and is the wrong one here: six optional named
  /// parameters invite a caller to rewrite a distro's background from a widget,
  /// and the accent is the only one of the six a user is ever allowed to move.
  ThemePalette withAccent(Color accent) => ThemePalette(
        bgTop: bgTop,
        bgBottom: bgBottom,
        bar: bar,
        dock: dock,
        accent: accent,
        onDark: onDark,
      );

  /// Value equality, added with the light variant.
  ///
  /// It matters now because two palettes for one distro are compared to decide
  /// whether the desktop must repaint. Without it, `paletteLight` and `palette`
  /// are always unequal by identity even when a theme ships the same six
  /// colours twice, and every brightness flip would repaint for nothing.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ThemePalette &&
          other.bgTop == bgTop &&
          other.bgBottom == bgBottom &&
          other.bar == bar &&
          other.dock == dock &&
          other.accent == accent &&
          other.onDark == onDark;

  @override
  int get hashCode => Object.hash(bgTop, bgBottom, bar, dock, accent, onDark);
}

class ThemeTypography {
  const ThemeTypography({required this.display, required this.mono});
  final String? display;
  final String? mono;

  static ThemeTypography fromJson(Map<String, dynamic> j) => ThemeTypography(
        display: j['display'] as String?,
        mono: j['mono'] as String?,
      );
}

/// One font family a theme ships.
///
/// [files] are BARE FILENAMES, not paths. `PackPaths.installedFile` refuses a
/// separator, so every asset inside a pack is flat, and a font is no different
/// from a wallpaper in that respect. A bundled theme's files are asset-bundle
/// paths, resolved through the same [ThemeSource] everything else uses.
// No @immutable: nothing else in this file is annotated and it imports neither
// meta nor foundation. The class is const-constructible with final fields,
// which is the property that matters.

class ThemeFont {
  const ThemeFont({required this.family, required this.files});

  /// The name [ThemeTypography] refers to. Must match, or the text falls back
  /// silently to the platform default, which is the failure mode this whole
  /// block exists to make impossible to hit by accident.
  final String family;

  final List<String> files;

  /// A family with no name or no files registers nothing and would only add a
  /// load attempt that cannot succeed. Filtered at parse, so nothing
  /// downstream has to check.
  bool get isUsable => family.isNotEmpty && files.isNotEmpty;

  static ThemeFont fromJson(Map<String, dynamic> j) => ThemeFont(
        family: (j['family'] as String?) ?? '',
        files: ((j['files'] as List?) ?? const [])
            .map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList(),
      );

  @override
  bool operator ==(Object other) =>
      other is ThemeFont &&
      other.family == family &&
      other.files.length == files.length &&
      other.files.every(files.contains);

  @override
  int get hashCode => Object.hash(family, Object.hashAll(files));
}

/// One panel: an edge, a thickness, and what it carries.
///
/// ─── WHY A LIST REPLACED A SINGLE BAR ───────────────────────────────────────
///
/// The shell could express one bar, on one edge, carrying a fixed set of
/// readouts behind a boolean. That covers GNOME, which has exactly one, and it
/// cannot express Xfce at all: Kali ships a top bar AND a bottom dock, and
/// authoring it as a one-bar distro is close enough to look wrong.
///
/// It also turned the readouts into a yes-or-no. A waybar feels authored
/// because its author chose which modules and in what order; `topBarStats: true`
/// gives every distro the same three in the same order forever.
///
/// The DOCK is not a panel and is still [ThemeLayout.dock]. It holds pinned
/// apps, it magnifies on Aqua, it has its own capacity rules; folding it in
/// here would mean one type doing two unrelated jobs.
class PanelSpec {
  const PanelSpec({
    required this.side,
    required this.modules,
    this.height,
  });

  final TopBarSide side;

  /// In order, leading edge first. A [PanelModule.spacer] splits the run.
  final List<PanelModule> modules;

  /// Thickness in dp. Null takes the shell's own default, which is what every
  /// theme authored before panels existed gets.
  final double? height;

  bool get isEmpty => modules.isEmpty;

  static PanelSpec? fromJson(Map<String, dynamic> j) {
    final mods = ((j['modules'] as List?) ?? const [])
        .map((e) => PanelModule.parse(e.toString()))
        .whereType<PanelModule>()
        .toList();

    // A panel with nothing in it is a coloured strip. Dropped at parse so
    // nothing downstream has to decide what an empty one means.
    if (mods.isEmpty) return null;

    return PanelSpec(
      side: TopBarSide.parse(j['side'] as String?),
      modules: mods,
      height: (j['height'] as num?)?.toDouble(),
    );
  }
}

/// Which way workspaces run.
///
/// ─── WHY THIS IS AUTHORED AND NOT ASSUMED ───────────────────────────────────
///
/// GNOME's workspaces are a vertical strip and this shell has always paged
/// vertically because of it. macOS Spaces run horizontally, and a phone
/// imitating macOS that swipes DOWN to change space is wrong in a way anyone
/// who has used one notices immediately.
///
/// One enum rather than a per-shell constant, because the axis belongs to the
/// distro rather than to the shell implementation: Plasma is configurable and
/// a distro shipping either answer is authentic.
/// WHERE the app list lives, which is a different question from what it looks
/// like.
///
/// ─── THE THIRD AXIS OF A DESKTOP, AND THE ONE NOBODY COULD AUTHOR ───────────
///
/// [ShellKind] decides the desktop, `ChromeFamily` decides the dialogs, and the
/// drawer fields decide how the app list is grouped and how it moves. None of
/// them can express the question a phone actually asks first: do I swipe to my
/// apps, or do they cover the screen when I ask for them?
///
/// Every distro shipping today answers the same way by default, because the app
/// list has only ever been an overlay: something that appears over the desktop
/// and goes away. That is GNOME's Activities and it is KDE's Kickoff, so it was
/// the right and only answer for a long time.
///
/// It is not Deepin's. Deepin's launcher is the screen, and its fashion mode is
/// openly modelled on a phone: the apps are simply THERE, one swipe over, with
/// the dock unchanged underneath. There is no open and no close.
///
///  - **overlay**: the app list appears over the desktop and is dismissed. The
///    default, and what all fourteen distros do today.
///  - **workspace**: the app list IS a page of the desktop, appended after the
///    last workspace. Nothing opens it and nothing closes it; you swipe. The
///    dock stays mounted across every page, because it never had anything to
///    hide behind.
///
/// A CAPABILITY, not a preference, so it takes no user override. This is the
/// same argument [desktopIcons] makes: a Deepin user switching it to overlay
/// would be asking for a launcher Deepin does not have. `LayoutResolver` also
/// clamps it per shell, because two of the five do not implement it and a
/// silently-ignored field is the failure this codebase keeps meeting.
///
/// Unknown values from a newer catalogue parse to null and fall through, the
/// same drop-not-fatal contract as [PanelModule.parse].
enum AppsSurface {
  overlay,
  workspace;

  static AppsSurface? parse(String? raw) => switch (raw) {
        'overlay' => AppsSurface.overlay,
        'workspace' => AppsSurface.workspace,
        _ => null,
      };
}

enum WorkspaceAxis {
  vertical,
  horizontal;

  static WorkspaceAxis parse(String? raw) =>
      raw == 'horizontal' ? WorkspaceAxis.horizontal : WorkspaceAxis.vertical;
}

/// Which edge the dock lives on.
///
/// ─── `right` IS APPENDED, AND EVERY SWITCH OVER THIS IS EXHAUSTIVE ──────────
///
/// Same treatment `ShellKind.aqua` got and for the same reason: adding it
/// breaks the build at every site that decides where a dock goes, and each one
/// has to answer on purpose. A `_ =>` arm here would ship a launcher whose dock
/// setting silently does nothing on four screens out of five, which is
/// indistinguishable from the setting being broken.
///
/// APPENDED rather than slotted between `bottom` and `off` only out of habit:
/// nothing serialises this by index. The stored pref is a STRING and every
/// read goes through `.name` or one of the two parsers, so the order here is
/// presentation and not wire format.
///
/// `right` mirrors `left` exactly: a vertical strip against the far edge. It is
/// not a new kind of dock, which is what makes it cheap; what it is not cheap
/// for is everything that assumed a vertical dock meant the LEFT edge, and
/// those are the sites the compiler is about to list.
enum DockSide { left, bottom, off, right }

class ThemeLayout {
  const ThemeLayout({
    required this.dock,
    required this.topBar,
    this.topBarSide = TopBarSide.top,
    this.topBarStats = false,
    this.panels = const [],
    this.panelsAuthored = false,
    this.workspaceAxis = WorkspaceAxis.vertical,
    this.appsSurface = AppsSurface.overlay,
    this.desktopIcons = false,
    this.panelEdit = false,
    required this.rows,
    required this.cols,
    this.iconScale = 1.0,
    this.drawerScrollStyle,
    this.drawerGrouping,
    this.drawerSearchPosition,
    this.kickoffRail,
    this.tilingLauncher,
    this.appDrawer,
    this.homeLayout,
    this.dockStyle,
    this.dockReveal,
    this.workspaces,
  });

  final DockSide dock;
  final bool topBar;

  /// Which edge the shell bar sits on.
  ///
  /// ─── WHY THIS IS SEPARATE FROM [topBar] AND NOT AN ENUM REPLACING IT ────
  ///
  /// `topBar` is a BOOL and stays one, because it answers "is there a bar",
  /// which is what `LayoutResolver`, `EffectiveTheme` and three shells already
  /// ask. Widening it to an enum would have rippled through all of them to
  /// carry information only the placement cares about.
  ///
  /// So visibility and position are two questions. A theme that says nothing
  /// gets the top, which is where every GNOME-family desktop puts it and what
  /// this shell did before the field existed.
  final TopBarSide topBarSide;

  /// Does the bar carry live system readouts?
  ///
  /// ─── AND WHY THIS IS OFF BY DEFAULT ─────────────────────────────────────
  ///
  /// `gnome_top_bar.dart` argues, correctly, that the bar carries nothing
  /// because Android's status bar a few pixels above it already shows the
  /// clock, the battery and the connection, and duplicating those is the
  /// opposite of authentic.
  ///
  /// That argument covers exactly the things Android shows. Throughput, memory
  /// pressure and free space are none of them, and a waybar or a polybar
  /// carries all three. So a distro can opt in, and the modules that ship are
  /// only the ones the status bar does NOT already own.
  final bool topBarStats;

  /// Every panel this distro draws, in no particular order.
  ///
  /// ─── SYNTHESISED WHEN A THEME DOES NOT AUTHOR IT ────────────────────────
  ///
  /// [topBar], [topBarSide] and [topBarStats] still parse and still mean what
  /// they meant. When `panels` is absent they are turned INTO one, so there is
  /// exactly one shape downstream and no shell has to ask which era a theme was
  /// written in. Authoring `panels` supersedes all three.
  ///
  /// Empty means no panel at all, which is what `topBar: false` has always
  /// meant and what the tiling and TUI shells want.
  final List<PanelSpec> panels;

  /// Did the theme.json actually contain a `panels` key?
  ///
  /// ─── THE DIFFERENCE BETWEEN "AUTHORED NOTHING" AND "AUTHORED THE
  ///     DEFAULT", WHICH NOTHING COULD SEE BEFORE ────────────────────────────
  ///
  /// [_panels] returns a list either way. A theme that authored panels gets
  /// its own; a theme that did not gets one SYNTHESISED from [topBar],
  /// [topBarSide] and [topBarStats]. Downstream those two are the same type,
  /// the same length, and carry the same fields, so by the time the list
  /// reaches `LayoutResolver` there is no way left to tell them apart.
  ///
  /// That is not a tidiness complaint. `LayoutResolver` needed the distinction
  /// twice and could not have it, so it guessed both times:
  ///
  ///   * the synthesis-override branch tested `panels.length == 1 &&
  ///     panels.first.height == null`, which is TRUE of a real authored panel
  ///     that happens to be alone and heightless. Such a distro had its panel
  ///     side quietly rebound to the `topBarSide` pref, which is the setting
  ///     for the OTHER kind of panel entirely.
  ///   * `_panelSide` gave up and hardcoded bottom, with a comment saying a
  ///     distro wanting a left panel out of the box needs authored and
  ///     synthesised panels told apart first. This is that.
  ///
  /// A DERIVED flag, not a theme.json key. Nothing authors `panelsAuthored`;
  /// it is the answer to "was `panels` present", computed once at parse where
  /// the raw JSON is still in scope and the question is still answerable. So
  /// there is no `theme-spec.ts` constant, no canonicaliser arm, and no import
  /// guard to add on the panel side.
  ///
  /// An authored EMPTY list counts as authored. `panels: []` is a distro
  /// saying it draws no panel, which is a decision, and it must not be
  /// confused with `topBar: false` arriving at the same `const []`.
  final bool panelsAuthored;

  /// Which way workspaces page. Defaults to vertical, which is what this shell
  /// has always done and what GNOME does.
  final WorkspaceAxis workspaceAxis;

  /// Where this distro's app list lives. See [AppsSurface].
  ///
  /// Defaults to [AppsSurface.overlay], which is not a cautious default but the
  /// correct one: it is what every distro shipping at the time of writing does,
  /// so nothing moves until a theme.json says otherwise.
  final AppsSurface appsSurface;

  /// Does this distro's desktop carry app icons?
  ///
  /// ─── OFF BY DEFAULT, AND THAT IS THE AUTHENTIC ANSWER FOR MOST ──────────
  ///
  /// GNOME 40 and later show nothing on the desktop, elementary shows nothing,
  /// and a tiling WM has no desktop to show anything on. Those are the distros
  /// shipping today, so false is not a cautious default, it is the correct one
  /// for every theme that exists at the time of writing.
  ///
  /// KDE is the opposite case and the reason this field exists: Folder View is
  /// Plasma's DEFAULT containment, so a Plasma desktop with no icon grid is not
  /// a minimal Plasma, it is a Plasma missing the thing a Plasma user reaches
  /// for first. Cinnamon is the same, which is what Linux Mint will need.
  ///
  /// A capability, not a preference. The user may turn icons OFF on a distro
  /// that has them; they cannot turn them on where the distro has none, because
  /// GNOME having a bare desktop IS GNOME rather than a setting someone forgot
  /// to expose. `LayoutResolver` enforces that direction.
  final bool desktopIcons;

  /// Can the user rearrange this distro's panel?
  ///
  /// ─── A FIELD, NOT A SHELL CHECK, AND FOR A PRODUCT REASON ───────────────
  ///
  /// The authenticity argument for gating this is weaker than it looks. A GNOME
  /// user of THIS app can already move the top bar to any edge and toggle its
  /// readouts, which real GNOME does not offer, so "GNOME's bar is not editable"
  /// is a line this launcher already crossed.
  ///
  /// The argument that survives is that panel editing is what Plasma is sold
  /// on, and Manjaro and Garuda are sold partly on inheriting it. A field hands
  /// it to exactly the distros that carry it and lets a CDN distro opt in
  /// without an APK release. A `switch` on shell kind would hardcode the answer
  /// and would quietly grant it to every future plasma-shell distro, whether or
  /// not that was the intent.
  ///
  /// Off by default, like [desktopIcons], so no distro shipping today changes.
  final bool panelEdit;  final int rows;
  final int cols;

  /// A per-theme multiplier on every icon, everywhere: drawer, dock, folders.
  ///
  /// Distro icon sets are not drawn to one standard. A Papirus-ish set sits well
  /// inside its keyline and reads small next to a full-bleed Yaru icon at the
  /// same nominal size, and no amount of masking fixes that — it is a property
  /// of the ARTWORK, not of the shape. So the theme says how big its own icons
  /// want to be, and [IconSizing] is the one place that applies it.
  ///
  /// Bounded on parse by `IconSizing.parseScale` (0.7–1.4). A downloaded theme
  /// is content that drives UI, and content that drives UI gets validated —
  /// same rule SplashSpec's duration clamp follows.
  final double iconScale;

  /// The distro's DEFAULT drawer motion: 'vertical' | 'pages' | 'cube', or
  /// null for the engine default ('pages', see `LayoutResolver`).
  ///
  /// ─── A DEFAULT, NEVER AN OVERRIDE ────────────────────────────────────────
  ///
  /// These two fields exist so a distro like Mint can say "I am a list distro"
  /// without a new ShellKind. They are consulted ONLY when the user has never
  /// touched the setting, and "touched" already has a marker: the promoted
  /// global pref is non-null. The Settings and Setup rows always write an
  /// explicit value (including the one that matches the default on screen), so
  /// a deliberate choice is never confusable with an untouched one, and
  /// switching distro never rebinds a choice the user made. The merge lives in
  /// `LayoutResolver.resolve` and nowhere else.
  ///
  /// Unknown values from a newer catalogue parse to null and fall through,
  /// same drop-not-fatal contract as `PanelModule.parse`.
  final String? drawerScrollStyle;

  /// The distro's DEFAULT grouping: 'none' | 'az' | 'library', or null for the
  /// engine default ('none'). Same default-never-override contract as
  /// [drawerScrollStyle], and like the user pref it only means anything when
  /// the resolved scroll style is the list.
  ///
  /// 'library' was missing from BOTH this doc and the parse arm while
  /// `LayoutResolver` and `EffectiveTheme.libraryGrouped` both accepted it. The
  /// doc mattering is not incidental: it is what a reader checks before adding
  /// a value, so a stale list here is how the next one goes missing too.
  final String? drawerGrouping;

  /// The distro's DEFAULT search bar position: 'top' | 'bottom' | 'off', or
  /// null for the engine default ('bottom').
  ///
  /// ─── THE PREF EXISTED AND THE DISTRO HAD NO VOTE ─────────────────────────
  ///
  /// `LauncherPrefs.drawerSearchPosition` has been settable since the bar had
  /// three positions, and `AppDrawer` read it as
  /// `theme.prefs.drawerSearchPosition ?? 'bottom'` with a comment saying "a
  /// theme may pin 'top' for an authentic GNOME feel". No theme could. There
  /// was no field here, no arm in `LayoutResolver`, and the fallback in that
  /// expression was the literal string. The comment described a capability
  /// nobody had built, which is the same shape as `drawerGrouping: 'library'`
  /// being documented one layer above the parse that admitted it.
  ///
  /// It cost Deepin its search. Deepin sets `appsSurface: "workspace"`, so its
  /// app list is a PAGE with the dock painted over it rather than an overlay
  /// covering the dock. A bar defaulted to the bottom therefore laid out
  /// underneath the dock: rendered, hit-testable in theory, invisible in fact.
  /// Every overlay distro got away with the same default.
  ///
  /// Same default-never-override contract as [drawerScrollStyle]: consulted
  /// only when the user has never touched the setting, and a user who has
  /// still wins. Unknown values parse to null and fall through.
  ///
  ///  - **top**: the field above the grid. What Deepin's fullscreen launcher
  ///    does and what GNOME's Activities does, and mandatory rather than
  ///    decorative on a bottom-dock distro whose app list is a page.
  ///  - **bottom**: thumb-reachable, matching the One UI search page. The
  ///    engine default and what every distro had before this field.
  ///  - **off**: no bar. For a distro that reaches search by gesture or by the
  ///    desktop search desklet.
  final String? drawerSearchPosition;

  /// What the Plasma menu's left rail is made of: 'tabs' | 'categories', or
  /// null for the engine default ('tabs').
  ///
  /// ─── WHY THIS IS NOT drawerGrouping ─────────────────────────────────────
  ///
  /// [drawerGrouping] and [drawerScrollStyle] describe [AppDrawer], and
  /// `shell_drawer.dart` sends plasma to [KickoffDrawer], which reads neither.
  /// Authoring 'library' on a plasma distro therefore writes a valid value that
  /// nothing consumes, which is the silent-drop failure this codebase keeps
  /// meeting. A separate field says plainly that this is the KICKOFF rail and
  /// only the Kickoff rail.
  ///
  /// A CAPABILITY, not a preference, and so it takes no user override: which
  /// menu a distro has is what makes Mint not KDE, in the same way
  /// [desktopIcons] decides whether a desktop grid exists at all.
  ///
  ///  - **tabs**: Favorites / Frequent / All, labelled, at 74dp. KDE's own
  ///    Kickoff and what every plasma distro drew before this field.
  ///  - **categories**: the same two tabs plus the generated category buckets,
  ///    icon-only at 56dp with the active label heading the list. Cinnamon's
  ///    menu, and what Linux Mint needs to stop reading as a green KDE.
  ///
  /// Unknown values from a newer catalogue parse to null and fall through, the
  /// same drop-not-fatal contract as `PanelModule.parse`.
  final String? kickoffRail;

  /// Which launcher a TILING distro opens: 'rofi' | 'dmenu', or null for the
  /// engine default ('rofi').
  ///
  /// ─── NAMED FOR ITS WIDGET, FOR THE REASON [kickoffRail] IS ──────────────
  ///
  /// `shell_drawer.dart` sends tiling to [TilingLauncher] and nothing else
  /// reads this, so a plasma distro authoring 'dmenu' writes a valid value that
  /// nothing consumes. That is the silent-drop failure this file keeps meeting,
  /// and the answer here is the one [kickoffRail] already established: name the
  /// field after the widget it configures, so the theme.json says plainly which
  /// drawer it is talking to. No shell clamp, unlike `appsSurface`, because
  /// there the field describes a PLACE that two shells cannot provide, whereas
  /// this one describes a widget only one shell mounts at all.
  ///
  /// A CAPABILITY, not a preference, so no user override merges in. Arch's
  /// launcher being a bare strip IS Arch, in the same way Mint's menu is what
  /// makes Mint not KDE.
  ///
  ///  - **rofi**: a centred floating card with an accent border, app icons, a
  ///    ranked list and a footer hint. What every tiling distro drew before
  ///    this field, and what EndeavourOS wants: its community edition ships
  ///    rofi in drun mode and its whole look is soft and purple.
  ///  - **dmenu**: one line across the top edge. Prompt, input, then the
  ///    matches running horizontally beside it with the top hit inverted. No
  ///    icons, no card, no border, no scrim, no footer. The most austere thing
  ///    in the catalogue, which is exactly what Arch is.
  ///
  /// The two share the matcher, the item list and the long-press menu. Only the
  /// shape differs, which is the point: two distros that both launch from a
  /// keybind should not therefore look identical.
  ///
  /// Unknown values from a newer catalogue parse to null and fall through, the
  /// same drop-not-fatal contract as [PanelModule.parse].
  final String? tilingLauncher;

  /// Which drawer this distro opens, when its shell offers a choice:
  /// 'grid' | 'tools', or null for the engine default ('grid').
  ///
  /// ─── THE FIRST FIELD THAT OVERRIDES shell_drawer ────────────────────────
  ///
  /// Every other drawer field so far configures the drawer the SHELL picked.
  /// This one picks a different drawer. `shell_drawer.dart` mapped five shells
  /// onto three widgets, which is why eight of fourteen distros shared one, and
  /// no amount of configuring a shared widget separates Kali from Ubuntu when
  /// both are handed the same grid.
  ///
  ///  - **grid**: whatever the shell would have chosen. Every distro today.
  ///  - **tools**: the numbered category menu. Kali's Applications menu, where
  ///    the rail is Kali's own thirteen tool categories rather than a letter or
  ///    a tab.
  ///  - **card**: Slingshot. A card that drops from the Applications button and
  ///    covers about half the screen, with the wallpaper and the dock still
  ///    visible around it. The only drawer here that does NOT take the display,
  ///    which is the whole of what elementary is selling.
  ///  - **whisker**: Xfce's menu. A narrow column standing on the bottom-left
  ///    corner, search on top, a short run of apps, and a strip of category
  ///    buttons along its foot. It grows UP from the panel button, which is
  ///    where every one of its proportions comes from.
  ///  - **cinnamon**: Mint's menu. Three columns side by side, a favourites
  ///    strip, the categories and the apps, with search across the foot. The
  ///    only three-column menu here, and the reason Mint is not a green KDE.
  ///  - **library**: the App Library. Category bubbles, three apps and a
  ///    cluster to a bubble, rendered by `library_view`.
  ///
  ///    ─── AND YES, `drawerGrouping: "library"` REACHES THE SAME WIDGET ────
  ///
  ///    It does, and that is the wrong route for a product selling it.
  ///    `drawerGrouping` has a prefs arm, so any buyer can set it on any distro
  ///    in four taps and an App Library reached that way cannot be an exclusive
  ///    row. As an [appDrawer] value it takes no user override.
  ///
  ///    elementary and Zorin keep the grouping route, which is right for them:
  ///    on those it is a default the user may change, not a thing being sold.
  ///  - **query**: Pop's launcher. A line at the top of the screen with ranked
  ///    results under it, and nothing else. The only one that does not arrange
  ///    apps at all: it assumes you know what you want and gets out of the way
  ///    while you say it.
  ///  - **zorin**: the Start menu's shape. A grid of pinned apps ABOVE a rule,
  ///    everything else as a list below it, search over both. The only stacked
  ///    one: the columned menus make favourites a peer of the rest, and a tier
  ///    above a rule makes them the answer and the rest the fallback.
  /// A CAPABILITY, not a preference, so it takes no user override: which menu a
  /// distro has is what makes Kali not Ubuntu, the same argument [desktopIcons]
  /// and [kickoffRail] make.
  ///
  /// Unknown values parse to null and fall through, the same drop-not-fatal
  /// contract as [PanelModule.parse].
  final String? appDrawer;

  /// How the desktop arranges its icons: 'grid' | 'tiled', or null for the
  /// engine default ('grid').
  ///
  /// ─── A GEOMETRY, NOT A SECOND SURFACE ───────────────────────────────────
  ///
  /// Both modes render the same slots from the same [HomeLayout] storage, so
  /// dragging, merging into folders, the long-press menu and the per-workspace
  /// page all behave identically. Only where a slot LANDS differs.
  ///
  ///  - **grid**: an evenly spaced run of `rows` by `cols` cells with a gutter
  ///    around them. Every distro that has a desktop today.
  ///  - **tiled**: the slots fill the workspace edge to edge with no gap
  ///    between them, each taking a share of what is left after the ones before
  ///    it, alternating the split axis. A tiling window manager's screen is
  ///    full of windows, and a spaced grid of rounded icons is the most
  ///    phone-looking thing this launcher can draw, which is the wrong thing to
  ///    draw on the distro whose whole argument is that it is not a phone.
  ///
  /// A CAPABILITY, not a preference. Nothing in Settings offers it, because a
  /// tiled Ubuntu is not a preference anyone holds, it is a different distro.
  ///
  /// Capacity is still `rows * cols`, so a tiled distro controls how many tiles
  /// a workspace holds through the grid it already authors. Arch wants a small
  /// number: six tiles read as windows, twenty read as a mosaic.
  final String? homeLayout;

  /// How the dock SITS: 'flat' | 'floating' | 'magnified', or null for the
  /// shell's own.
  ///
  /// ─── THREE, BECAUSE TWO WOULD ORPHAN A BUILT FEATURE ────────────────────
  ///
  /// The obvious pair is flat against the edge versus floating off it, which is
  /// the difference between Pantheon's Plank and Deepin's fashion dock. Adding
  /// only those two would leave `AquaDockMetrics` and the parabolic swell it
  /// computes with no distro using them, because both of the aqua distros want
  /// a dock that does NOT magnify. A feature this app already has, that nothing
  /// asks for, is the thing every pass in this run has been finding.
  ///
  ///  - **flat**: on the edge, square-topped, running dots under the icons.
  ///    Plank. What elementary wants.
  ///  - **floating**: off the edge with a margin, rounded, translucent, no
  ///    swell. Deepin's fashion mode.
  ///  - **magnified**: floating AND swelling under the finger. The showpiece,
  ///    and Garuda is where it belongs.
  ///
  /// A CAPABILITY, not a preference: which dock a desktop has is what makes it
  /// that desktop. `dockSide` stays the preference, and on aqua it is already
  /// refused for a separate and older reason.
  final String? dockStyle;

  /// When the dock EXISTS: 'always' | 'apps', or null for always.
  ///
  /// ─── THE FIELD THAT TELLS FEDORA FROM UBUNTU ────────────────────────────
  ///
  /// Both are GNOME, both have a top bar, both use the paged grid, and both
  /// authored `dock: left`. On a real screen the one difference is that
  /// Ubuntu's dock is part of the desktop and upstream GNOME's is not: there is
  /// no dock until you open Activities, where a dash appears at the bottom and
  /// leaves again with the overview.
  ///
  /// That is a REVEAL rather than an absence, which matters because absence
  /// cannot be sold and a reveal can be seen the moment the phone unlocks.
  ///
  ///  - **always**: the dock is part of the desktop. What every distro draws
  ///    today, so a theme that says nothing does not move.
  ///  - **apps**: it exists only while the apps surface is open. A DASH, and
  ///    the desktop underneath has nothing on it at all.
  ///  - **desktop**: the mirror. A dock on every home page and none on the app
  ///    list. What iOS does, and what Pocket is: the App Library replaces the
  ///    dock with its own search field rather than sitting under it.
  ///
  ///    It reads as a third value and is really the first distinction this
  ///    field has had to make on a WORKSPACE-surface distro. 'always' and
  ///    'apps' were both written for an overlay, where `activitiesOpenProvider`
  ///    answers everything; on a distro whose apps are a page there is no flag,
  ///    and Deepin and Pocket want opposite answers from the same arrangement.
  ///    Deepin's "the dock stays put" is one of its exclusive rows.
  ///
  /// `gnome_shell` already computes `dockRevealed` for its own edge gesture, so
  /// the machinery was built and wired to one caller. That is the third time
  /// this run has found the same shape, after [dockStyle] reaching only aqua
  /// and [panelEdit] only plasma.
  ///
  /// A CAPABILITY: nothing in Settings offers it, and Dock position and Dock
  /// opacity grey out on a distro with no permanent dock to position or fade.
  final String? dockReveal;

  /// How many workspaces this distro STARTS with, or null for the engine's
  /// three.
  ///
  /// ─── A DEFAULT, NOT A CEILING ───────────────────────────────────────────
  ///
  /// `WorkspaceCount` reads `prefs.workspaceCount ?? fallback`, and `fallback`
  /// was a hardcoded 3 with a comment saying the mockup showed three dots.
  /// Nothing in that chain ever asked the theme, so every distro started with
  /// three whatever its desktop is actually like.
  ///
  /// It costs most on a distro whose apps are a workspace PAGE. Deepin's app
  /// list sits after the last desktop, so three workspaces means two empty
  /// swipes before you reach it, and the fastest way to your apps on the distro
  /// built around reaching apps quickly is four gestures.
  ///
  /// This is the DEFAULT and the user still owns the number: the stepper is
  /// live, `set` writes prefs, and prefs win. So it is not an exclusive row and
  /// is not meant to be. It is the answer to "how many should this distro have
  /// before anyone touches it", which nothing could answer.
  ///
  /// Clamped to the same 1 to 5 the stepper uses. A theme asking for eight gets
  /// five rather than a screen of dots nobody can count.
  final int? workspaces;

  /// Panels, authored or synthesised from the legacy trio.
  ///
  /// The synthesis is the compatibility layer and it is deliberately literal:
  /// one panel, on the authored side, carrying Activities and, if the theme
  /// asked for stats, the same three readouts in the same order the boolean
  /// always produced. Nobody's desktop moves.
  ///
  /// A spacer sits between them because that is what the old bar did with its
  /// `Spacer()`: Activities left, readouts far end.
  static List<PanelSpec> _panels(Map<String, dynamic> j) {
    final raw = j['panels'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => PanelSpec.fromJson(e.cast<String, dynamic>()))
          .whereType<PanelSpec>()
          .toList();
    }

    if ((j['topBar'] as bool? ?? true) == false) return const [];

    return [
      PanelSpec(
        side: TopBarSide.parse(j['topBarSide'] as String?),
        modules: [
          PanelModule.activities,
          if (j['topBarStats'] as bool? ?? false) ...[
            PanelModule.spacer,
            PanelModule.network,
            PanelModule.memory,
            PanelModule.storage,
          ],
        ],
      ),
    ];
  }

  /// The theme's DEFAULT. User overrides in Settings always win, and are stored
  /// per-theme so switching themes does not wipe them. Plan §5.3.
  static ThemeLayout fromJson(Map<String, dynamic> j) {
    final grid = (j['grid'] as Map?)?.cast<String, dynamic>() ?? const {};
    return ThemeLayout(
      dock: switch (j['dock'] as String?) {
        'bottom' => DockSide.bottom,
        'off' => DockSide.off,
        'right' => DockSide.right,
        // Unknown, absent, or 'right' from a theme authored against a NEWER
        // build than this one: left. A CDN distro that asks for a side this
        // APK has never heard of gets the default rather than no dock, which
        // is the same forward-compatibility contract every other field in this
        // file keeps.
        _ => DockSide.left,
      },
      topBar: j['topBar'] as bool? ?? true,
      topBarSide: TopBarSide.parse(j['topBarSide'] as String?),
      topBarStats: j['topBarStats'] as bool? ?? false,
      panels: _panels(j),
      // The raw key, asked here and nowhere else. `_panels` cannot answer it
      // for us: it returns the same type from both branches, which is the
      // whole problem this flag exists to fix.
      panelsAuthored: j['panels'] is List,
      workspaceAxis: WorkspaceAxis.parse(j['workspaceAxis'] as String?),
      // Absent, or a value from a newer catalogue: the overlay every distro
      // already uses. Same forward-compatibility contract as the drawer fields
      // directly below.
      appsSurface:
          AppsSurface.parse(j['appsSurface'] as String?) ?? AppsSurface.overlay,
      desktopIcons: j['desktopIcons'] as bool? ?? false,
      panelEdit: j['panelEdit'] as bool? ?? false,
      rows: (grid['rows'] as num?)?.toInt() ?? 5,
      cols: (grid['cols'] as num?)?.toInt() ?? 4,
      iconScale: IconSizing.parseScale(j['iconScale']),
      drawerScrollStyle: switch (j['drawerScrollStyle'] as String?) {
        'vertical' => 'vertical',
        'pages' => 'pages',
        'cube' => 'cube',
        // Absent, or a value from a newer catalogue: no theme opinion, so the
        // resolver falls through to the engine default.
        _ => null,
      },
      drawerGrouping: switch (j['drawerGrouping'] as String?) {
        'none' => 'none',
        'az' => 'az',
        // Category folders, iOS App Library shaped. Paired with
        // `drawerScrollStyle: 'vertical'` it is the whole look; on its own it
        // is folders in whatever motion the distro already uses, which is a
        // coherent thing to want rather than a broken half.
        //
        // ─── THIS ARM WAS MISSING, AND THE COMMENT ABOVE DESCRIBED IT ───────
        //
        // The doc for this value sat here without the case that admits it, so
        // 'library' fell to `_ => null` one layer ABOVE the layer that wants
        // it: `LayoutResolver` accepts `{'none', 'az', 'library'}` and
        // `EffectiveTheme.libraryGrouped` reads `drawerGrouping == 'library'`
        // directly. The panel had already been corrected: `DRAWER_GROUPINGS`
        // in `theme-spec.ts` lists all three and its own comment calls that
        // constant the bug's headstone. So the value was authored, validated,
        // signed, published and dropped on arrival.
        //
        // Two shipping distros were affected and neither reported anything,
        // because the ungrouped list is a completely plausible fallback:
        // elementary authors `drawerGrouping: "library"` and `CardDrawer`
        // opens flat instead of on categories, and Zorin authors it and gets
        // nothing. Same failure shape as the `LayoutResolver` allow-lists: a
        // value parsed correctly, dropped by a list downstream, hidden by a
        // fallback that looks deliberate.
        'library' => 'library',
        _ => null,
      },
      // THE SECOND LIST. `LayoutResolver._pick` carries the other one, and a
      // value here that is missing there resolves to the default forever. That
      // is written up at length on the `appDrawer` allow-list, where six
      // passes shipped drawers nothing could reach.
      drawerSearchPosition: switch (j['drawerSearchPosition'] as String?) {
        'top' => 'top',
        'bottom' => 'bottom',
        'off' => 'off',
        _ => null,
      },
      kickoffRail: switch (j['kickoffRail'] as String?) {
        'tabs' => 'tabs',
        'categories' => 'categories',
        _ => null,
      },
      tilingLauncher: switch (j['tilingLauncher'] as String?) {
        'rofi' => 'rofi',
        'dmenu' => 'dmenu',
        _ => null,
      },
      appDrawer: switch (j['appDrawer'] as String?) {
        'grid' => 'grid',
        'tools' => 'tools',
        'card' => 'card',
        'whisker' => 'whisker',
        'cinnamon' => 'cinnamon',
        'zorin' => 'zorin',
        'library' => 'library',
        'query' => 'query',
        _ => null,
      },
      homeLayout: switch (j['homeLayout'] as String?) {
        'grid' => 'grid',
        'tiled' => 'tiled',
        _ => null,
      },
      workspaces: (j['workspaces'] as num?)?.toInt(),
      dockReveal: switch (j['dockReveal'] as String?) {
        'always' => 'always',
        'apps' => 'apps',
        // THE MIRROR OF 'apps', and the value Pocket needs. See the field doc.
        // Remember `LayoutResolver._pick` carries the other half of this list.
        'desktop' => 'desktop',
        _ => null,
      },
      dockStyle: switch (j['dockStyle'] as String?) {
        'flat' => 'flat',
        'floating' => 'floating',
        'magnified' => 'magnified',
        _ => null,
      },
    );
  }
}

/// Which edge the shell bar sits on.
///
/// ─── THE VERTICAL CASE, AND THE COLLISION THAT DID NOT HAPPEN ───────────────
///
/// `left` and `right` were withheld until the layout existed, on the reasoning
/// that a left bar would sit exactly where Ubuntu's dock already is. It turns
/// out it does not: the dock is `Positioned` inside the WORKSPACE's own
/// LayoutBuilder, not inside the shell's outer Stack, so a bar placed as a
/// sibling of the workspace shrinks the box the dock is positioned within and
/// the two simply never overlap.
///
/// That is also the authentic arrangement. A polybar or a waybar owns its edge
/// outright and everything else lives inboard of it, which is exactly what
/// falls out of putting the bar and the workspace in one Row.
/// One module in a panel.
///
/// Deliberately SHORT. Every entry here is something Android's own status bar
/// does not already show, which is the rule gnome_top_bar's doc lays down: a
/// clock or a battery percentage in a launcher panel is duplication, and
/// duplication is the opposite of authentic.
enum PanelModule {
  /// The Activities affordance. Opens the overview.
  activities,

  /// Down and up throughput.
  network,

  /// Used against total.
  memory,

  /// Free space.
  storage,

  /// Pushes everything after it to the far end. A panel with no spacer packs
  /// to the leading edge, which is what a dense polybar does.
  spacer,

  // ─── THE PLASMA FAMILY ────────────────────────────────────────────────────
  //
  // The five above describe a GNOME top bar, which is the only panel that
  // existed when this enum was written. Plasma's panel is five different
  // things, and none of them was addressable: `_PlasmaPanel` hardcoded them
  // into a Row because there was no way to write "kickoff" in a theme.json.
  //
  // That is what made panel edit mode impossible rather than merely unbuilt.
  // A user cannot rearrange a list that does not exist, and a distro could not
  // ship a different arrangement without an APK release, which is the thing
  // the whole theme layer is for.

  /// The application launcher button. Plasma's, and Mint's under another name.
  kickoff,

  /// Open windows as labelled buttons. A taskbar, not a dock: the dock shows
  /// what you pinned, this shows what is running.
  tasks,

  /// The workspace squares.
  pager,

  /// Status icons.
  tray,

  /// Time, with the date beneath it where the panel is tall enough.
  ///
  /// ─── AND WHY GNOME STILL WILL NOT HAVE ONE ──────────────────────────────
  ///
  /// `gnome_top_bar` argues that the bar carries no clock because Android's
  /// status bar a few pixels above it already shows one, and duplicating it is
  /// the opposite of authentic. That argument is untouched. The module exists
  /// because a BOTTOM panel is nowhere near the status bar and a Plasma panel
  /// without a clock is not a Plasma panel. GNOME's theme simply does not list
  /// it, which is the difference between a vocabulary and a mandate.
  clock;

  static PanelModule? parse(String raw) => switch (raw) {
        'activities' => PanelModule.activities,
        'network' => PanelModule.network,
        'memory' => PanelModule.memory,
        'storage' => PanelModule.storage,
        'spacer' => PanelModule.spacer,
        'kickoff' => PanelModule.kickoff,
        'tasks' => PanelModule.tasks,
        'pager' => PanelModule.pager,
        'tray' => PanelModule.tray,
        'clock' => PanelModule.clock,
        // An unknown module from a newer catalogue is DROPPED, not fatal. A
        // panel missing one readout is a panel; a theme that fails to parse is
        // a black screen.
        _ => null,
      };
}

enum TopBarSide {
  top,
  bottom,
  left,
  right;

  /// Does the bar run down an edge rather than across one?
  ///
  /// The shell reads this to choose a Row over a Column, and the bar itself
  /// reads it to stack its contents instead of laying them out in a line. Both
  /// need the same answer, so it lives here rather than being asked twice.
  bool get isVertical => this == TopBarSide.left || this == TopBarSide.right;

  static TopBarSide parse(String? raw) => switch (raw) {
        'bottom' => TopBarSide.bottom,
        'left' => TopBarSide.left,
        'right' => TopBarSide.right,
        _ => TopBarSide.top,
      };
}

/// Accepts "#RRGGBB" and "#AARRGGBB". Null-in, null-out — a null colour is
/// meaningful in the icon block ("use the app's own background").
Color? parseColor(String? hex) {
  if (hex == null) return null;
  var s = hex.replaceFirst('#', '').trim();
  if (s.length == 6) s = 'FF$s';
  if (s.length != 8) return null;
  final v = int.tryParse(s, radix: 16);
  return v == null ? null : Color(v);
}

/// The desktop icon grid a distro starts with.
///
/// ─── WHY THIS IS A COUNT AND NOT A LIST OF APPS ─────────────────────────────
///
/// [StarterDesklet] names a `kind`, which is a closed vocabulary this app owns,
/// so a theme can author it exactly. A [HomeItem] names a `componentKey`, which
/// is an Android component on somebody else's phone. A theme author in one
/// country cannot know what is installed in another, so a list of apps would be
/// a list of things that mostly are not there.
///
/// A count is the honest shape. It says how full this distro's desktop should
/// look and lets the device decide with what, which is also the only answer
/// that is right for Pocket: an iOS home screen shows YOUR apps, so a rule is
/// more correct there than any list would have been.
///
/// ─── WHAT THIS DOES NOT DO, AND WHY THAT IS DELIBERATE ──────────────────────
///
/// It cannot say "put Files in the top left". Kali's Xfce desktop genuinely
/// wants that and does not get it here. Adding it means resolving a ROLE
/// ('files', 'browser', 'terminal') to a package, which is either an intent
/// query through native or a package-name allowlist in Dart, and an allowlist
/// is wrong on exactly the OEM skins this app targets and cannot be tested
/// without those devices.
///
/// A `role` key can be added to this block later without disturbing `fill`,
/// which is why this is a block rather than a bare integer on `layout`.
class HomeBlock {
  const HomeBlock({this.fill = 0});

  /// How many app icons to lay onto the desktop the first time this theme is
  /// used. Zero, the default, is the empty desktop every distro has today.
  ///
  /// CLAMPED AT PARSE rather than trusted, the same contract
  /// `SplashSpec.durationMs` and `IconSizing.parseScale` keep: this arrives
  /// over the CDN, and a pack asking for 400 icons on a 20-slot grid should be
  /// corrected rather than left to `addToHome` to refuse 380 times.
  ///
  /// The real ceiling is the grid's own capacity and is applied at seed time by
  /// the caller, which knows `rows * cols`. This bound is only here to keep an
  /// absurd number out of the loop.
  final int fill;

  static const int maxFill = 60;

  /// Forward-compatible: a missing block, a malformed one, or a `fill` of the
  /// wrong type all yield a fill of zero rather than throwing. A desktop must
  /// not fail to draw because a newer pack authored something this build has
  /// not heard of.
  static HomeBlock fromJson(Map<String, dynamic>? j) {
    if (j == null) return const HomeBlock();
    final raw = (j['fill'] as num?)?.toInt() ?? 0;
    return HomeBlock(fill: raw < 0 ? 0 : (raw > maxFill ? maxFill : raw));
  }

  @override
  bool operator ==(Object other) => other is HomeBlock && other.fill == fill;

  @override
  int get hashCode => fill.hashCode;
}
