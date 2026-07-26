import 'dart:ui';

import '../design/icon_sizing.dart';
import '../platform/launcher_api.g.dart' as api;
import 'boot_spec.dart';
import 'desklet_skin.dart';
import 'splash_spec.dart';
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
    required this.typography,
    required this.layout,
    required this.icons,
    required this.wallpapers,
    required this.minAppVersion,
    ChromeFamily? chromeFamily,
    this.logo,
    this.boot,
    this.splash,
    this.desklets = const DeskletThemeBlock(),
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
  final ThemeTypography typography;
  final ThemeLayout layout;

  /// Passed straight to native. The launcher never renders icons in Dart.
  final api.IconStyle icons;

  /// The theme's preset wallpapers. The user adds their own on top; both live
  /// in prefs.wallpapers and rotate together.
  final List<String> wallpapers;

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
        typography: typography,
        layout: layout,
        icons: icons,
        wallpapers: wallpapers,
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
        source: source,
      );

  /// Resolve one of this theme's own asset paths (a wallpaper, a logo) to
  /// something openable. Shorthand for `source.asset(path)`.
  ThemeAsset asset(String path) => source.asset(path);

  static ThemeSpec fromJson(Map<String, dynamic> json) {
    final icons = (json['icons'] as Map?)?.cast<String, dynamic>() ?? const {};

    return ThemeSpec(
      id: json['id'] as String,
      name: json['name'] as String,
      version: json['version'] as String? ?? '',
      shell: ShellKind.parse(json['shell'] as String?),
      tier: json['tier'] as String? ?? 'free',
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
      minAppVersion: (json['minAppVersion'] as num?)?.toInt() ?? 0,
      logo: ThemeLogo.fromJson(json['logo']),
      boot: BootSpec.fromJson(
        (json['boot'] as Map?)?.cast<String, dynamic>(),
      ),
      splash: SplashSpec.fromJson(
        (json['splash'] as Map?)?.cast<String, dynamic>(),
      ),
      desklets: DeskletThemeBlock.fromJson(
        (json['desklets'] as Map?)?.cast<String, dynamic>(),
      ),
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

enum DockSide { left, bottom, off }

class ThemeLayout {
  const ThemeLayout({
    required this.dock,
    required this.topBar,
    required this.rows,
    required this.cols,
    this.iconScale = 1.0,
  });

  final DockSide dock;
  final bool topBar;
  final int rows;
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

  /// The theme's DEFAULT. User overrides in Settings always win, and are stored
  /// per-theme so switching themes does not wipe them. Plan §5.3.
  static ThemeLayout fromJson(Map<String, dynamic> j) {
    final grid = (j['grid'] as Map?)?.cast<String, dynamic>() ?? const {};
    return ThemeLayout(
      dock: switch (j['dock'] as String?) {
        'bottom' => DockSide.bottom,
        'off' => DockSide.off,
        _ => DockSide.left,
      },
      topBar: j['topBar'] as bool? ?? true,
      rows: (grid['rows'] as num?)?.toInt() ?? 5,
      cols: (grid['cols'] as num?)?.toInt() ?? 4,
      iconScale: IconSizing.parseScale(j['iconScale']),
    );
  }
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
