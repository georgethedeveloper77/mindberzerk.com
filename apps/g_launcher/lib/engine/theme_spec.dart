import 'dart:ui';

import '../design/icon_sizing.dart';
import '../platform/launcher_api.g.dart' as api;
import 'boot_spec.dart';
import 'desklet_skin.dart';
import 'splash_spec.dart';
import 'terminal_spec.dart';
import 'theme_source.dart';

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
    this.fonts = const [],
    required this.minAppVersion,
    ChromeFamily? chromeFamily,
    this.logo,
    this.boot,
    this.splash,
    this.terminal,
    this.desklets = const DeskletThemeBlock(),
    this.gestures = const {},
    this.source = const ThemeSource.bundled(),
  }) : _chromeFamily = chromeFamily;

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
  final ThemeSource source;

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
        desklets: desklets,
        gestures: gestures,
        source: source,
      );

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
      layout: ThemeLayout.fromJson(
        (json['layout'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
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
    );
  }

  /// Accepts a "wallpapers" list, and still reads the old single
  /// wallpaper.asset — a theme already on someone's phone must not stop working
  /// because we changed the manifest shape.
  static List<String> _wallpapers(Map<String, dynamic> json) {
    final list = json['wallpapers'] as List?;
    if (list != null) return list.map((e) => e as String).toList();

    final legacy = (json['wallpaper'] as Map?)?['asset'] as String?;
    return legacy == null ? const [] : [legacy];
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
  aqua,
  generic;

  /// Parse a theme.json `chromeFamily` value. Unknown or absent yields null so
  /// the caller can fall back to the shell default — a value from a newer CDN
  /// theme this build doesn't recognise degrades to the shell default rather
  /// than throwing, same contract as [ShellKind.parse] and the icon treatment.
  static ChromeFamily? parse(String? raw) => switch (raw) {
        'adwaita' => ChromeFamily.adwaita,
        'breeze' => ChromeFamily.breeze,
        'aqua' => ChromeFamily.aqua,
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
    this.workspaceAxis = WorkspaceAxis.vertical,
    this.desktopIcons = false,
    this.panelEdit = false,
    required this.rows,
    required this.cols,
    this.iconScale = 1.0,
    this.drawerScrollStyle,
    this.drawerGrouping,
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

  /// Which way workspaces page. Defaults to vertical, which is what this shell
  /// has always done and what GNOME does.
  final WorkspaceAxis workspaceAxis;

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

  /// The distro's DEFAULT grouping: 'none' | 'az', or null for the engine
  /// default ('none'). Same default-never-override contract as
  /// [drawerScrollStyle], and like the user pref it only means anything when
  /// the resolved scroll style is the list.
  final String? drawerGrouping;

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
      workspaceAxis: WorkspaceAxis.parse(j['workspaceAxis'] as String?),
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
        'library' => 'library',
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
