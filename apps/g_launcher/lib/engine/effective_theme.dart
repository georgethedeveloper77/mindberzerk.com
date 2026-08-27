import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/prefs/desklet_layout.dart';
import '../data/prefs/launcher_prefs.dart';
import '../data/prefs/prefs_repository.dart';
import '../data/prefs/starter_desktop.dart';
import '../data/repositories/app_repository.dart';
import '../platform/launcher_api.g.dart' as api;
import '../system/wallpaper_source.dart';
import 'font_catalogue.dart';
import 'layout_resolver.dart';
import 'theme_engine.dart';
import 'font_registry.dart';
import 'theme_spec.dart';

/// What the shell actually renders.
///
/// ThemeSpec (the distro's defaults) + LauncherPrefs (the user's choices),
/// merged. The user always wins; a null override means "inherit".
///
/// Everything the shell reads should come from HERE, never from ThemeSpec
/// directly — otherwise a setting silently stops working in one widget and you
/// spend an evening finding out which.
class EffectiveTheme {
  const EffectiveTheme({
    required this.spec,
    required this.prefs,
    required this.dock,
    required this.topBar,
    required this.topBarSide,
    required this.topBarStats,
    required this.panels,
    required this.panelsAuthored,
    required this.workspaceAxis,
    required this.appsSurface,
    required this.desktopIcons,
    required this.panelEdit,
    required this.panelHeight,
    required this.panelSide,
    required this.rows,
    required this.cols,
    required this.drawerCols,
    required this.drawerScrollStyle,
    required this.drawerGrouping,
    required this.kickoffRail,
    required this.tilingLauncher,
    required this.appDrawer,
    required this.homeLayout,
    required this.dockStyle,
    required this.dockReveal,
    required this.iconSizeDp,
    required this.labelLines,
    required this.textScale,
    required this.iconScale,
    required this.icons,
    required this.dark,
  });

  final ThemeSpec spec;
  final LauncherPrefs prefs;

  /// Is the DARK variant on screen?
  ///
  /// Resolved from `prefs.themeMode` against the platform brightness, and true
  /// whenever the distro ships no light palette. Stored rather than recomputed
  /// so `==` can see it: see the note on the operator below, which is the whole
  /// reason this is a field.
  final bool dark;

  final DockSide dock;
  final bool topBar;

  /// Which edge the bar sits on, and whether it carries live readouts.
  /// Resolved in [LayoutResolver]; the shells read these and never the spec.
  final TopBarSide topBarSide;
  final bool topBarStats;

  /// Every panel the shell should draw. Resolved in [LayoutResolver]; shells
  /// read this and never the spec.
  final List<PanelSpec> panels;

  /// Did this distro author [panels], or were they synthesised from the legacy
  /// `topBar` trio? See [ThemeLayout.panelsAuthored].
  ///
  /// Here so a SHELL can ask it, which is the point of the field existing at
  /// all: a shell handed a synthesised bar and a shell handed an authored one
  /// currently receive the same list and cannot behave differently. Nothing
  /// reads it yet, and that is deliberate rather than dead weight, because the
  /// alternative was leaving each new slot to re-derive the answer from the
  /// shape of the list the way `LayoutResolver` used to.
  final bool panelsAuthored;

  /// Which way workspaces page. See [WorkspaceAxis].
  final WorkspaceAxis workspaceAxis;

  /// Where the app list lives: an overlay over the desktop, or a page of it.
  /// Resolved and shell-clamped in [LayoutResolver]; read by `WorkspaceCanvas`
  /// and by `openApps`, and never taken off the spec. See [AppsSurface].
  final AppsSurface appsSurface;

  /// Does the desktop carry app icons? The distro's answer, lowered by the
  /// user's if they have turned it off. Read by `WorkspaceCanvas`, which is the
  /// only thing that mounts the grid.
  final bool desktopIcons;

  /// Can the user rearrange this distro's panel? Read by the Plasma shell to
  /// decide whether a long press on the panel opens edit mode.
  final bool panelEdit;

  /// Panel thickness in dp, null for the shell's own default.
  final double? panelHeight;

  /// Which edge the shell's own panel sits on. Never null.
  final TopBarSide panelSide;
  final int rows;
  final int cols;

  /// Denser than home by convention.
  final int drawerCols;

  /// How the drawer moves ('vertical' | 'pages' | 'cube') and how its list is
  /// grouped ('none' | 'az'). Resolved in [LayoutResolver]: the user's choice,
  /// else the distro's authored default, else the engine default. Shells and
  /// settings read THESE and never `prefs.drawerScrollStyle`, which is only
  /// half the answer now that a distro can carry a default.
  final String drawerScrollStyle;
  final String drawerGrouping;

  /// What the Kickoff rail is made of: 'tabs' or 'categories'.
  ///
  /// ─── RESOLVED, AND CARRIED ACROSS FOR THE SAME REASON AS EVERY SCALAR ────
  ///
  /// [LayoutResolver] already produced this. It was not carried onto
  /// EffectiveTheme, so `KickoffDrawer` read `theme.kickoffRail` against a
  /// getter that did not exist and three call sites failed to compile.
  ///
  /// A shell must read the RESOLVED value, never `spec.layout`, or a distro's
  /// authored default silently stops applying in one widget and keeps working
  /// in another. That is the rule this whole class exists to enforce.
  ///
  /// No user override merges in, unlike the two above. This is not a way of
  /// moving through the list, it is WHICH MENU the distro has, and a Mint user
  /// switching it to tabs would be asking for KDE's menu on Mint.
  final String kickoffRail;

  /// Which launcher a tiling distro opens: 'rofi' | 'dmenu'. Resolved in
  /// [LayoutResolver]; read by `TilingLauncher` and nothing else. See
  /// [ThemeLayout.tilingLauncher].
  final String tilingLauncher;

  /// Which drawer this distro opens: 'grid' | 'tools'. Read by `ShellDrawer`,
  /// which consults it BEFORE the shell. See [ThemeLayout.appDrawer].
  final String appDrawer;

  /// Does the drawer file apps into category folders?
  ///
  /// ─── TWO ROUTES TO ONE SHAPE, AND THEY HAD TO AGREE ─────────────────────
  ///
  /// `drawerItemsProvider` emits folders first and the rest after when the
  /// grouping is `library`, and `LibraryView` cuts its sections out of that
  /// order rather than asking for a second, differently sorted provider.
  ///
  /// `appDrawer: "library"` reaches the same widget without a preference, which
  /// is the whole point of the value. On its own it would hand that widget an
  /// UNGROUPED list, and the sections would come out wrong with nothing saying
  /// so: the exact silent-failure shape this codebase keeps finding.
  ///
  /// So the drawer implies the grouping. One getter, read by the provider, and
  /// the two cannot drift.
  bool get libraryGrouped =>
      appDrawer == 'library' || drawerGrouping == 'library';

  /// How the desktop arranges its icons: 'grid' | 'tiled'. Read by `HomeGrid`
  /// and nothing else. See [ThemeLayout.homeLayout].
  final String homeLayout;

  /// How the dock sits: 'flat' | 'floating' | 'magnified'. Read by `AquaDock`
  /// and by the shell that positions it. See [ThemeLayout.dockStyle].
  final String dockStyle;

  /// When the dock exists: 'always' | 'apps'. Read by `gnome_shell` and by
  /// `capabilities.dart`. See [ThemeLayout.dockReveal].
  final String dockReveal;

  final double iconSizeDp;

  /// 2 lets long names wrap ("Secure Folder") instead of truncating to
  /// "Secure Fold…", which is what the drawer does today and it looks bad.
  final int labelLines;
  final double textScale;

  /// The active theme's icon multiplier. Every surface that draws an app icon
  /// passes its container-derived base through `IconSizing.scaled` with this, so
  /// a distro whose artwork reads small is a theme.json edit rather than a
  /// per-widget fudge factor.
  final double iconScale;

  /// The style handed to native. Theme's icon block, with the user's shape
  /// choice layered on top.
  final api.IconStyle icons;

  /// The DESKLET grid, which is finer than the icon grid.
  ///
  /// ─── WHY THESE ARE NOT cols AND rows ──────────────────────────────────
  ///
  /// `cols` and `rows` shape a cell for an app icon with a label under it,
  /// which on a phone is about 83 wide by 140 tall. Android widgets are
  /// authored against a roughly square launcher cell, so on the icon grid a
  /// weather strip wanting 74dp of height could not ask for less than 140.
  ///
  /// Derived rather than stored, and derived from the theme's own grid rather
  /// than fixed, so a distro that authors a 5-column desktop gets a
  /// proportionally finer desklet grid without authoring a second number.
  int get deskletCols => cols * DeskletLayout.colFactor;
  int get deskletRows => rows * DeskletLayout.rowFactor;

  /// How solid the launcher's own surfaces are, 0.6 to 1.0.
  ///
  /// Clamped HERE rather than at the slider, so a value written by a settings
  /// screen from a newer build, or hand-edited into a prefs file, cannot make
  /// the app unreadable. The slider's own bounds are a courtesy; this is the
  /// guarantee.
  double get surfaceOpacity =>
      (prefs.surfaceOpacity ?? 1.0).clamp(0.6, 1.0);

  /// The three surfaces that are PERMANENT chrome over the wallpaper, each
  /// resolved as: the section's own setting, else the main slider, else solid.
  ///
  /// Read THESE, never `prefs.dockOpacity`. A widget reading the raw field
  /// would miss the fallback and paint its section solid the moment the user
  /// moved the main slider without having touched that section, which is the
  /// one way this could make the single slider look broken.
  ///
  /// Same 0.6 floor and the same reason: below it a surface stops being
  /// readable over an arbitrary photograph, and clamping here means a value
  /// from a newer build or a hand-edited prefs file cannot get past it either.
  double get dockOpacity =>
      (prefs.dockOpacity ?? prefs.surfaceOpacity ?? 1.0).clamp(0.6, 1.0);

  double get drawerOpacity =>
      (prefs.drawerOpacity ?? prefs.surfaceOpacity ?? 1.0).clamp(0.6, 1.0);

  double get barOpacity =>
      (prefs.barOpacity ?? prefs.surfaceOpacity ?? 1.0).clamp(0.6, 1.0);

  // ── PANELS ───────────────────────────────────────────────────────────────
  //
  // Every floating glass surface reads these: sheets, dialogs, the desktop
  // menu, the desklet menu. They were constants inside GlassPanel, and each
  // default below is the exact number it used, so an untouched install renders
  // pixel-identically to before these existed.
  //
  // Clamped here rather than at the sliders, the same guarantee the opacities
  // get: a value from a newer build or a hand-edited prefs file cannot make a
  // panel unreadable or give it a corner radius larger than the panel.

  /// Falls back to the main slider, so a panel stays in step with the page
  /// behind it until someone deliberately splits it out.
  double get panelOpacity =>
      (prefs.panelOpacity ?? prefs.surfaceOpacity ?? 1.0).clamp(0.6, 1.0);

  /// 0 to 24. Zero is a real setting and switches the BackdropFilter off; see
  /// [LauncherPrefs.panelBlur] for why that is exposed at all.
  double get panelBlur => (prefs.panelBlur ?? 18.0).clamp(0.0, 24.0);

  /// 0 is neutral grey, 1 is fully the distro's own colour.
  double get panelTint => (prefs.panelTint ?? 0.72).clamp(0.0, 1.0);

  /// Logical pixels. Capped at 28 because past roughly that a sheet's top
  /// corners eat into the grab handle and the title beside it.
  double get panelRadius => (prefs.panelRadius ?? 16.0).clamp(0.0, 28.0);

  /// The palette actually on screen.
  ///
  /// `spec.palette` is the DARK variant and keeps that name for
  /// backward-compatible theme.json; the light one is optional. A distro with
  /// no `paletteLight` block resolves [dark] to true, so this getter returns
  /// the same object it always did and nothing downstream can tell light mode
  /// exists.
  ThemePalette get palette =>
      dark ? spec.palette : (spec.paletteLight ?? spec.palette);

  /// The families actually on screen: the distro's, unless the user said
  /// otherwise.
  ///
  /// ─── NO LONGER A PASSTHROUGH ────────────────────────────────────────────
  ///
  /// `spec.typography` is what the distro authored, and for a faithful Kali it
  /// is what should render. But a font is a property of the PERSON as much as
  /// of the desktop being imitated, so [LauncherPrefs.displayFont] and
  /// [LauncherPrefs.monoFont] sit in the global bucket and win when set.
  ///
  /// Null means the user expressed no preference, which is the same "inherit"
  /// that every other override in this class means. [systemChoice] is a real
  /// value meaning the platform's own face, and it maps to a null `fontFamily`
  /// because that is how Flutter spells it. The two are NOT the same thing and
  /// collapsing them would make "follow my phone" unexpressible.
  ///
  /// Nothing downstream changes. `terminal_view.dart` still reads
  /// `typography.mono` and every label still reads `typography.display`; they
  /// simply start getting a different answer.
  ///
  /// ─── NOT IN ==, AND THAT IS SOUND RATHER THAN AN OVERSIGHT ──────────────
  ///
  /// These two families are computed from `prefs`, `spec` and a static map that
  /// `FontRegistry` fills, so in principle two EffectiveThemes could compare
  /// equal and return different families if the map changed between them.
  ///
  /// It cannot, because of the ordering in `effectiveThemeProvider`: every fetch
  /// is awaited BEFORE the theme is constructed and emitted, so the map is
  /// already settled by the time anything reads this. A later emit with the same
  /// prefs and the same spec id resolves to the same families by construction.
  ///
  /// Changing a font changes `prefs`, which `==` does compare, so the repaint
  /// happens. Break the await ordering and this stops being true, which is one
  /// more reason it is guarded as tightly as it is.
  ThemeTypography get typography => ThemeTypography(
        display: _font(prefs.displayFont, spec.typography.display),
        mono: _font(prefs.monoFont, spec.typography.mono),
      );

  /// One override resolved against what the distro authored.
  ///
  /// The fallback is the DISTRO'S family, not null, and that matters on a cold
  /// start: a chosen font whose bytes have not arrived yet paints in Ubuntu for
  /// a moment rather than dropping to the platform default and back, which reads
  /// as a flicker into the wrong typeface.
  static String? _font(String? choice, String? authored) {
    if (choice == null) {
      // NO USER OVERRIDE, so the distro's own family, and it goes through the
      // SAME resolution. That is the fix for a bug that reached publish: the
      // authored name used to be handed to `fontFamily` raw, so a distro naming
      // any family the APK does not bundle rendered in the platform default.
      // It validated in the panel, signed, published and came up wrong, with no
      // error anywhere in the chain.
      return _resolve(authored);
    }

    // Flutter spells "the platform's own face" as a null family.
    if (choice == systemChoice) return null;

    // NOT null. `monospace` is an Android family alias the platform resolves to
    // a fixed-advance face; a null here would hand the terminal the proportional
    // default and break its column count. See font_catalogue.dart.
    if (choice == systemMonoChoice) return systemMonoChoice;

    // Falls back to the DISTRO'S family rather than to null while a fetch is in
    // flight, so a cold start shows Ubuntu for a moment instead of flickering
    // into the platform default and back.
    return _resolve(choice) ?? _resolve(authored);
  }

  /// One family name turned into one Flutter can actually resolve.
  ///
  /// Bundled families and pack-shipped families are registered under exactly the
  /// name they are written with, so they pass through. A family fetched by
  /// `google_fonts` is NOT: the package picks its own registered name, and
  /// handing the requested one to `fontFamily` resolves to nothing and silently
  /// paints Roboto. That indirection is the whole reason `FontRegistry` keeps a
  /// map instead of just a set.
  ///
  /// Null while a fetch is still running, which the caller reads as "not yet"
  /// rather than as an error.
  static String? _resolve(String? family) {
    if (family == null || family.isEmpty) return null;

    // In the APK. Nothing had to register it and nothing can rename it.
    if (bundledFamilies.contains(family)) return family;

    // NULL WHEN THE MAP MISSES, and that is the point rather than a shortcut.
    // Returning the raw name here would hand `fontFamily` a string nothing has
    // registered, which resolves to nothing and paints Roboto while looking
    // exactly like a deliberate choice. Null lets the caller fall back to the
    // distro's own face instead.
    return FontRegistry.resolvedFamily(family);
  }

  ShellKind get shell => spec.shell;

  /// The resolved chrome family, surfaced here so the chrome layer reads it off
  /// EffectiveTheme (the single source of truth) rather than reaching into the
  /// spec. Pure passthrough; no user override merges into it (yet).
  ChromeFamily get chromeFamily => spec.chromeFamily;

  /// Which variant [prefs] and the platform ask for.
  ///
  /// A theme with no light palette is always dark, checked FIRST: offering a
  /// light mode that cannot render is worse than not offering one, and this is
  /// the line that keeps every bundled distro behaving exactly as it does today
  /// until someone authors the light block.
  static bool resolveDark(ThemeSpec spec, LauncherPrefs prefs,
      {bool systemDark = true}) {
    if (spec.paletteLight == null) return true;
    return switch (prefs.themeMode) {
      'light' => false,
      'dark' => true,
      _ => systemDark,
    };
  }

  /// [systemDark] DEFAULTS TO TRUE RATHER THAN BEING REQUIRED.
  ///
  /// Making it required was the tidier signature and it broke every existing
  /// test, which called `resolve(spec, prefs)` and had no opinion about
  /// brightness because until now there was nothing to have an opinion about.
  ///
  /// The default is not a shrug: `true` is exactly what this function did
  /// before light mode existed, and a theme with no `paletteLight` resolves to
  /// dark whatever is passed. So a caller that forgets gets today's behaviour
  /// rather than a surprise, and the one call site that genuinely knows the
  /// platform brightness, `effectiveThemeProvider`, passes it explicitly.
  static EffectiveTheme resolve(
    ThemeSpec spec,
    LauncherPrefs prefs, {
    bool systemDark = true,
  }) {
    final dark = resolveDark(spec, prefs, systemDark: systemDark);
    // Layout scalars (dock, grid, sizes, labels) live in LayoutResolver, the
    // one owner of the theme-default-then-user-override merge. Icon SHAPE is a
    // separate concern and stays below, coupled to iconCacheId and the native
    // push.
    final layout = LayoutResolver.resolve(spec, prefs);
    final themeIcons = spec.icons;

    return EffectiveTheme(
      spec: spec,
      prefs: prefs,
      dark: dark,
      dock: layout.dock,
      topBar: layout.topBar,
      topBarSide: layout.topBarSide,
      topBarStats: layout.topBarStats,
      panels: layout.panels,
      panelsAuthored: layout.panelsAuthored,
      workspaceAxis: layout.workspaceAxis,
      appsSurface: layout.appsSurface,
      desktopIcons: layout.desktopIcons,
      panelEdit: layout.panelEdit,
      panelHeight: layout.panelHeight,
      panelSide: layout.panelSide,
      rows: layout.rows,
      cols: layout.cols,
      drawerCols: layout.drawerCols,
      drawerScrollStyle: layout.drawerScrollStyle,
      drawerGrouping: layout.drawerGrouping,
      kickoffRail: layout.kickoffRail,
      tilingLauncher: layout.tilingLauncher,
      appDrawer: layout.appDrawer,
      homeLayout: layout.homeLayout,
      dockStyle: layout.dockStyle,
      dockReveal: layout.dockReveal,
      iconSizeDp: layout.iconSizeDp,
      labelLines: layout.labelLines,
      textScale: layout.textScale,
      iconScale: layout.iconScale,
      icons: api.IconStyle(
        // The user's shape choice beats the distro's. Slightly heretical for an
        // authenticity-first launcher, but "I want circles" is the single most
        // common launcher request there is, and refusing it wins nothing.
        treatment: prefs.treatmentEnum ?? themeIcons.treatment,
        cornerRadius: prefs.cornerRadius ?? themeIcons.cornerRadius,
        foregroundScale: themeIcons.foregroundScale,
        backgroundColor: themeIcons.backgroundColor,
        monochromeTint: themeIcons.monochromeTint,
        // ─── THE ICON PACK OVERRIDE ────────────────────────────────────────
        //
        // The user's pack beats the distro's, and this one line is what makes
        // a standalone icon pack a product rather than a promise.
        //
        // `icons_pop_cosmic` is its own Play SKU precisely so someone can run
        // the Kali desktop with Pop!_OS icons. Without this, the only thing
        // that could ever name a hero pack was `ThemeSpec.icons.heroPack` —
        // authored by whoever made the THEME. So buying an icon pack downloaded
        // it, verified it, installed it, and changed nothing on screen unless
        // the theme's author had happened to name it. That is a refund.
        //
        // NO SEPARATE CACHE-KEY LINE IS NEEDED, and that is worth stating
        // because the eight-place ritual conditions you to add one. `heroPack`
        // is ALREADY in `iconCacheId` below; overriding its VALUE here changes
        // that string for free. Adding `prefs.iconPackId` to `iconCacheId` as
        // well would be harmless but redundant, and it would imply the two can
        // differ, which is exactly the confusion this comment exists to stop.
        heroPack: prefs.iconPackId ?? themeIcons.heroPack,
        // Distro-authored, no user override. Someone who wants flat icons picks
        // a flat theme; a "disable gradients" toggle would fight the distro's
        // own look for no gain.
        backgroundGradientEnd: themeIcons.backgroundGradientEnd,
        gradientAngle: themeIcons.gradientAngle,
        // ─── THE FALLBACK THAT MAKES A DISTRO WEAR ITS OWN ICONS ──────────
        //
        // Every distro ships an icon pack named after it: `kali-2024-theme`
        // and `kali-2024-line`. Fourteen of them, sharing one geometry and
        // differing only in colour.
        //
        // Authoring `brandPack` in each theme.json covers the CDN distros and
        // CANNOT cover the three BUNDLED ones: their theme.json lives inside
        // the APK, so republishing them over the CDN changes nothing on a
        // device that loads them from assets. Ubuntu, Terminal and KDE Plasma
        // each resolved null and fell through to the generator while the pack
        // they are entitled to sat unused on the CDN.
        //
        // Derived HERE rather than in the storefront, because this value is
        // what native receives on `IconStyle.brandPack`. Computing it anywhere
        // else would let the card and the drawer name different packs.
        //
        // Already in `iconCacheId` below, so no extra cache line is needed for
        // the same reason `heroPack` needs none: the VALUE changes, and the key
        // reads the value.
        //
        // ─── AND THE USER'S CHOSEN COLOUR BEATS BOTH ──────────────────────
        //
        // [LauncherPrefs.iconBrandPackId] leads, for exactly the reason
        // `prefs.iconPackId` leads on `heroPack` twenty lines up, and it was
        // missing for the whole life of the colour strip.
        //
        // What happened without it: choosing any of the thirteen other colours
        // wrote `prefs.iconPackId`, which routes to the HERO tier. A derived
        // line pack is `{v, id, name, extends, tint, license, attribution}`
        // and nothing else, so `HeroIconResolver.readPack` found no `icons`
        // map and returned null, the hero tier drew nothing, and this line
        // handed the brand tier the distro's own pack as though nobody had
        // chosen anything. Apply completed, the card updated, the toast
        // appeared, and the drawer stayed the colour it already was.
        //
        // TWO FIELDS RATHER THAN ONE FIELD PLUS A KIND FLAG, because they are
        // two different choices and a phone can hold both: `iconPackId` is the
        // hand-drawn set on top, this is the outline set underneath, and the
        // generator catches whatever neither covers. That is the layering this
        // file already describes, and a single field with a tier tag would
        // make choosing one silently discard the other.
        brandPack: prefs.iconBrandPackId ??
            themeIcons.brandPack ??
            defaultLinePackFor(spec.id),
        brandTreatment: themeIcons.brandTreatment,
      ),
    );
  }

  /// Part of the native icon cache key. MUST change whenever anything in
  /// [icons] changes, or the cache serves the old shape forever and the setting
  /// looks broken. This is the one line that makes the icon-shape picker work.
  ///
  /// EVERY field of [icons] belongs here. Add one to IconStyle and forget this
  /// line and the field works exactly once, then serves stale bitmaps forever —
  /// which looks identical to the field being unwired, and is the single most
  /// expensive way to lose an evening on this code.
  String get iconCacheId {
    final i = icons;
    return '${spec.id}'
        // Brightness belongs in the icon key for the same reason every
        // IconStyle field does: `monochromeTint` and `backgroundColor` are
        // resolved per palette, so a light distro renders genuinely different
        // bitmaps. Without this the first mode you open wins and every later
        // flip serves the other mode's icons, which is the eight-place trap
        // this comment block exists to warn about.
        '|${dark ? 'd' : 'l'}'
        '|${i.treatment.name}'
        '|${i.cornerRadius}'
        '|${i.foregroundScale}'
        '|${i.backgroundColor}'
        '|${i.monochromeTint}'
        '|${i.heroPack}'
        '|${i.backgroundGradientEnd}'
        '|${i.gradientAngle}'
        '|${i.brandPack}'
        '|${i.brandTreatment}';
  }

  /// Value equality — LOAD-BEARING, not boilerplate.
  ///
  /// `shellAppsProvider` and `dockEntriesProvider` are `Provider.family` keyed
  /// on this object. Riverpod keys families by `==`/`hashCode`; with the default
  /// identity equality, every `effectiveThemeProvider` re-emit is a brand-new
  /// key, so the family re-resolves the whole app list and every icon re-decodes
  /// even when nothing that matters changed. Value equality collapses those
  /// no-op re-emits into the same key.
  ///
  /// What's compared, and why each is here:
  ///  - [prefs] — the app-list families read `prefs.hiddenApps` / `dockItems`.
  ///    Omit it and the Phase-A hidden-apps filter goes stale: hide an app and
  ///    the cached list keeps showing it. (Best collapse behaviour needs
  ///    `LauncherPrefs` to be value-equal too; if it's identity-equal this is
  ///    still correct, just collapses fewer rebuilds.)
  ///  - [iconCacheId] — an icon-shape change MUST re-key so icons re-decode.
  ///  - `spec.id` — theme identity; a switch changes it. Palette/shell aren't
  ///    compared because no family keyed on this reads them (shells read them off
  ///    the object they already hold), and `spec.id` moves with them anyway.
  ///  - the layout scalars — derived from `(spec, prefs)`, kept for defence
  ///    against a same-id spec whose content changed under it.
  ///
  /// [kickoffRail] is NOT here, and that is deliberate rather than an omission
  /// to fix later. It comes from `spec.layout` with no prefs input, so it cannot
  /// change without `spec.id` changing, which is already compared. Adding it
  /// would be harmless and would imply the two can move independently.
  ///
  /// [panelsAuthored] is absent for exactly the same reason and by the same
  /// test: it is derived from the raw theme.json at parse and takes no prefs
  /// input, so it moves only when `spec.id` moves. The test to apply to any
  /// future field here is that one, not "is it new".
  ///
  /// [appsSurface] passes the same test and is absent for the same reason: it
  /// resolves from `spec.layout` and `spec.shell`, both of which move only with
  /// `spec.id`. So do [tilingLauncher], [appDrawer] and [homeLayout].
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EffectiveTheme &&
          other.spec.id == spec.id &&
          other.prefs == prefs &&
          // ── WHY BRIGHTNESS IS IN HERE ────────────────────────────────
          //
          // This operator compares `spec.id`, not the spec, so it cannot see a
          // palette swap: the id is identical in both modes. And a SYSTEM
          // brightness flip changes no pref either, so without this line two
          // EffectiveThemes that paint completely different colours compare
          // EQUAL.
          //
          // That is not a cosmetic miss. Every Riverpod family keyed on
          // EffectiveTheme (shellApps, drawerItems, the custom grid, every icon
          // request) would keep serving its cached value, and turning on
          // Android's dark mode would repaint nothing at all until something
          // unrelated happened to invalidate the tree.
          other.dark == dark &&
          other.dock == dock &&
          other.topBar == topBar &&
          other.topBarSide == topBarSide &&
          other.topBarStats == topBarStats &&
          other.panels.length == panels.length &&
          other.workspaceAxis == workspaceAxis &&
          other.desktopIcons == desktopIcons &&
          other.panelEdit == panelEdit &&
          other.panelHeight == panelHeight &&
          other.panelSide == panelSide &&
          other.rows == rows &&
          other.cols == cols &&
          other.drawerCols == drawerCols &&
          other.drawerScrollStyle == drawerScrollStyle &&
          other.drawerGrouping == drawerGrouping &&
          other.iconSizeDp == iconSizeDp &&
          other.labelLines == labelLines &&
          other.textScale == textScale &&
          other.iconScale == iconScale &&
          other.iconCacheId == iconCacheId;

  /// ─── hashAll, NOT hash ────────────────────────────────────────────────
  ///
  /// `Object.hash` takes at most 20 positional arguments and this list reached
  /// 21. `Object.hashAll` takes an iterable and has no ceiling, which is why
  /// `LauncherPrefs` has used it for its own longer list all along.
  ///
  /// The failure was loud and immediate, which is the good version: the
  /// alternative would have been quietly dropping a field from the hash and
  /// getting a theme that compares unequal but hashes the same.
  @override
  int get hashCode => Object.hashAll([
        spec.id,
        prefs,
        dark,
        dock,
        topBar,
        topBarSide,
        topBarStats,
        panels.length,
        workspaceAxis,
        desktopIcons,
        panelEdit,
        panelHeight,
        panelSide,
        rows,
        cols,
        drawerCols,
        drawerScrollStyle,
        drawerGrouping,
        iconSizeDp,
        labelLines,
        textScale,
        iconScale,
        iconCacheId,
      ]);
}

/// The line pack a distro ships with, derived from its theme id.
///
/// ─── A NAMING RULE, NOT A TABLE ─────────────────────────────────────────────
///
/// `kali-2024-theme` -> `kali-2024-line`. The `-theme` suffix is stripped when
/// present, which is what makes the three BUNDLED distros work: their ids are
/// `ubuntu-24-04`, `terminal` and `kde-plasma-6`, with no suffix at all.
///
/// A table would be a second list to keep in step with the catalogue, and the
/// symptom of it drifting is a distro quietly wearing generated icons.
/// `CdnIndex.isIncludedWith` applies the same prefix rule to decide whether that
/// pack is FREE; the two have to agree, and a shared rule is the cheapest way to
/// guarantee it.
///
/// Returns a name for every theme, including ones whose pack was never
/// published. That is harmless: `BrandIconResolver` finds nothing installed
/// under that id and the generator draws, exactly as it did before.
///
/// TOP LEVEL rather than a static on [EffectiveTheme], because two callers need
/// it: `resolve` above for the icon style, and the icons storefront to decide
/// whether a pack came free with the distro in use.
String defaultLinePackFor(String themeId) =>
    '${themeId.endsWith('-theme') ? themeId.substring(0, themeId.length - 6) : themeId}-line';

/// The one provider the shells watch.
///
/// Also pushes the resolved icon style down to native on every change — which
/// is what makes changing the icon shape in Settings actually repaint the grid.
final effectiveThemeProvider = FutureProvider<EffectiveTheme>((ref) async {
  final spec = await ref.watch(activeThemeSpecProvider.future);

  // ─── FONTS BEFORE ANYTHING IS PUBLISHED ──────────────────────────────────
  //
  // A downloaded distro's families are registered at runtime, and they have to
  // be registered BEFORE this provider hands out a theme naming them. Do it
  // after and the first frame paints in the platform fallback and then jumps,
  // which on a cold start is the first thing anyone sees.
  //
  // Cheap after the first call: FontRegistry keeps what it has loaded, and a
  // theme with no fonts of its own returns immediately, which is every bundled
  // theme today.
  await FontRegistry.ensure(spec);
  final prefs = await ref.watch(prefsProvider(spec.id).future);

  // ─── AND THE USER'S OWN CHOICE, ON THE SAME SIDE OF THE LINE ─────────────
  //
  // Read AFTER prefs, because that is where the choice lives, and awaited
  // BEFORE resolve for exactly the reason the pack fonts are: a family named in
  // a published theme whose bytes have not been registered measures as the
  // platform fallback at first layout.
  //
  // For the display font that is a flash of the wrong face. For the mono font
  // it is worse, and it has been seen on device: `terminal_screen.dart` derives
  // the PTY column count by measuring a run of glyphs, so a fallback measured
  // there sends the remote host a width the screen does not have and its output
  // wraps where nothing can show it.
  //
  // Cheap after the first call. Both families are cached to disk, so this is a
  // file read on a cold start and a set lookup on every resolve after it.
  await Future.wait([
    // What the DISTRO names, when the pack did not ship the file itself.
    FontRegistry.ensureSpecFonts(spec),
    // And what the USER picked, which wins over it.
    FontRegistry.ensureFamily(prefs.displayFont),
    FontRegistry.ensureFamily(prefs.monoFont),
  ]);

  // Watched, so flipping Android's own dark mode repaints the desktop under
  // the user's thumb rather than on next launch.
  final systemDark = ref.watch(systemDarkProvider);

  final effective =
      EffectiveTheme.resolve(spec, prefs, systemDark: systemDark);

  final api_ = ref.read(launcherHostApiProvider);

  await api_.setIconTheme(effective.iconCacheId, effective.icons);

  // ── THE THIRD-PARTY ICON PACK ───────────────────────────────────────────
  //
  // A SECOND PUSH RATHER THAN A FIELD ON IconStyle, because IconStyle is theme
  // content that arrives over the CDN and this names an APK installed on one
  // device. See the note on `LauncherPrefs.systemIconPack`.
  //
  // PUSHED ON EVERY EMIT, which is every prefs write, and that is fine BECAUSE
  // of the guard in `IconCache.setSystemIconPack`: it compares against what it
  // already holds and returns immediately when nothing changed. Without that
  // guard this line would re-parse a pack's appfilter.xml every time the user
  // nudged the drawer columns.
  //
  // NOT AWAITED ALONGSIDE setIconTheme in a Future.wait: selecting a pack parses
  // thousands of XML entries natively, and the desktop must not wait on that to
  // repaint its palette. The icons arrive when they arrive; the theme is
  // instant.
  unawaited(api_.setIconPack(prefs.systemIconPack));

  // ── WHOSE WALLPAPER IS ON THE SCREEN ────────────────────────
  //
  // Android has ONE wallpaper; these prefs are per theme. The old code
  // reconciled that with a per-theme initialised flag, and it could not work.
  // By the second theme switch that flag is true for BOTH themes, so coming
  // back to Ubuntu skipped the re-apply and left KDE's wallpaper on screen
  // under Ubuntu's palette. That is the "the theme's wallpaper does not
  // always apply" report, and it was never intermittent: it happened every
  // time after the first visit to a theme.
  //
  // So the question changed. Not "has this theme ever applied one" but "is
  // the wallpaper on screen this theme's", which is a single global fact and
  // lives above the per-theme store, exactly like selectedThemeId.
  //
  // Reads and writes the store DIRECTLY rather than through prefsProvider,
  // and that is deliberate: prefs is watched by this provider, so writing to
  // it re-runs the whole thing. The old branch did precisely that and paid a
  // rebuild for it on every first run. Nobody watches this key, so applying a
  // wallpaper now costs one write and no rebuild.
  //
  // ─── THE TOKEN CARRIES THE MODE NOW ────────────────────────────────────
  //
  // It used to be the theme id alone, which was right until light mode existed
  // and then silently wrong: switching to light repainted every surface pale
  // and left the DARK photograph behind them, because as far as this key was
  // concerned the correct wallpaper was already on screen. A pale dock on a
  // near-black desktop is what that looks like, and it does not read as a light
  // theme, it reads as the chrome having lost its colour.
  //
  // Adding the mode means the flip re-applies exactly once per direction, and
  // the bug this key was built to fix stays fixed: it still answers "whose
  // wallpaper is on screen", with one more thing in the answer.
  //
  // ─── AND THE CONTENT, SO A REPUBLISHED DISTRO LANDS ────────────────────
  //
  // The same argument one step further. Re-uploading a free distro over the
  // CDN changes its wallpapers without changing its id or the mode, so this
  // key matched, this branch was skipped, and the phone kept the artwork from
  // the copy it downloaded last month. See [wallpaperContentStamp] for what
  // the digest does and does not notice.
  final store = ref.read(prefsStoreProvider);
  final appliedToken = wallpaperAppliedToken(
    spec.id,
    dark: effective.dark,
    stamp: wallpaperContentStamp(spec.wallpapers, spec.wallpapersLight),
  );

  if (await store.read(wallpaperAppliedForKey) != appliedToken) {
    // ── WHOSE WALLPAPER IS THIS ─────────────────────────────────────────
    //
    // A preset the theme ships is THEME-MANAGED and follows the mode. Anything
    // else is the user's own picture and must not be swapped out from under
    // them because they turned on light mode, which is why this tests
    // membership rather than simply taking `wallpaperCurrent` whenever it is
    // set.
    final current = prefs.wallpaperCurrent;
    final themeManaged = current == null ||
        spec.wallpapers.contains(current) ||
        spec.wallpapersLight.contains(current);

    final offered = !effective.dark && spec.wallpapersLight.isNotEmpty
        ? spec.wallpapersLight
        : spec.wallpapers;

    // ── A HIDDEN PRESET IS NOT AN OFFER ────────────────────────────────
    //
    // Without this, hiding is a suggestion the launcher overrules on its own
    // schedule: the strip greys the picture, the rotation drops it, and then
    // the next mode flip or theme switch seeds it straight back onto the
    // screen. Filtering HERE rather than in the strip is what makes the
    // setting mean something, because this is the one place that applies a
    // wallpaper nobody asked for.
    //
    // Every preset hidden leaves this empty, [source] falls to `current`, and
    // when that is null nothing is applied and the key is not written, which is
    // the same landing a theme shipping no wallpapers already gets.
    final preset = [
      for (final w in offered)
        if (!prefs.wallpapersHidden.contains(w)) w,
    ];

    // ── A CHOICE AMONG THE PRESETS IS STILL A CHOICE ───────────────────
    //
    // `preset.first` unconditionally was fine while this branch only ran on a
    // mode flip, where following the mode is the whole point. It is wrong now
    // that a republish also runs it: someone who deliberately picked the third
    // wallpaper would have been moved to the first one by an update they did
    // not ask for. So when the current pick is still on offer, it is re-applied
    // rather than replaced. The re-apply itself is not skippable, because the
    // pack's files may have moved underneath the same reference.
    final source = themeManaged
        ? (preset.contains(current)
            ? current
            : (preset.isNotEmpty ? preset.first : current))
        : current;

    if (source != null) {
      // ── RESOLVE BEFORE ENCODING ────────────────────────────────────────
      //
      // `spec.asset` is what knows whether this theme's files are in the APK
      // or in `packs/<id>/`, and it is the ONLY thing that does. Handing the
      // raw string to the encoder works for a bundled theme and produces
      // `file://wall_x.webp` for a downloaded one — a relative path behind a
      // scheme, which opens nothing. Since the launcher is transparent over
      // the system wallpaper, that was the entire reason an installed distro
      // arrived looking like it had no wallpaper.
      //
      // Guarded by `isThemeAssetRef` rather than called unconditionally: a
      // user's own photo is an absolute path, and resolving THAT against the
      // pack directory would relocate it. See the note on the predicate.
      final asset = isThemeAssetRef(source) ? spec.asset(source) : null;

      // ── ONLY ATTEMPT WHAT IS THERE, AND ONLY RECORD WHAT WORKED ────────
      //
      // `existsSync` is documented for exactly this call site: synchronous, so
      // it belongs where a theme RESOLVES rather than in a build method, and
      // it reports true for bundled assets because the bundle cannot be probed
      // and a missing one is a build-time problem.
      //
      // The write moved INSIDE the success branch. It used to run
      // unconditionally, one line after an unchecked call, so a wallpaper that
      // failed to apply was recorded as the wallpaper on screen — and because
      // this whole branch is gated on that key, the theme then never tried
      // again. A failure that marks itself done is worse than a failure.
      if (asset == null || asset.existsSync) {
        final applied = await api_.setWallpaper(
          encodeWallpaperSource(asset?.path ?? source),
          prefs.wallpaperLock ?? false,
          // The user's per-theme fit applies to a seeded preset exactly as it
          // does to a manual pick; letterbox bars wear the palette this apply
          // is FOR, not whichever the getter would resolve later.
          prefs.wallpaperFit ?? 'cover',
          (effective.dark ? spec.palette : (spec.paletteLight ?? spec.palette))
              .bgTop
              .toARGB32(),
        );
        if (applied) await store.write(wallpaperAppliedForKey, appliedToken);
      }
    }
    // Nothing to apply, and the key is deliberately NOT written. A theme that
    // ships no wallpapers (Aqua, today) leaves the previous one up, and the
    // moment it gains one over the CDN this branch picks it up rather than
    // having already marked itself done. The re-check is one prefs read.
  }

  // PHASE D3 — the distro's authored desktop, laid out ONCE.
  //
  // A SEPARATE BRANCH from the wallpaper above, on its own flag, deliberately:
  // a theme can ship a starter desktop and no wallpapers, or the reverse, and
  // folding them together would make one silently depend on the other.
  //
  // Terminates for the same reason that one does. It writes prefs, prefs is
  // watched, so this provider re-runs — and on the second pass the flag is true
  // and the branch is skipped. One extra rebuild at first use of a theme, in
  // exchange for never re-stamping a desktop the user has since arranged.
  //
  // Removing every desklet is a legitimate arrangement, which is why the flag
  // exists at all rather than testing `prefs.desklets.isEmpty`.
  //
  // PHASE D-grid — clear placements and let the starter reseed, ONCE per theme.
  //
  // BEFORE the starter branch, and it depends on that order: the reset clears
  // `deskletsInitialized` along with the placements, so the branch below sees
  // an uninitialised theme on the next pass and authors a fresh desktop
  // straight into the corrected coordinates. Running it after the seeding would
  // wipe the starter it had just laid down.
  //
  // Version 2 is a WIPE where version 1 was a rescale. The reasoning is in
  // `DeskletLayout.resetDesklets`; the short version is that every hosted
  // AppWidget on every existing desktop is at a span nobody chose, and their
  // stored config predates the fields needed to re-derive one.
  //
  // Terminates the same way: it writes prefs, prefs is watched, this provider
  // re-runs, and the marker is set so the branch is skipped.
  if ((prefs.deskletGridVersion ?? 0) < DeskletLayout.gridVersion) {
    final reset = DeskletLayout.resetDesklets(prefs);
    await ref.read(prefsProvider(spec.id).notifier).edit((_) => reset);
  }

  if (!prefs.deskletsInitialized) {
    final seeded = StarterDesktop.apply(
      prefs,
      spec.desklets,
      // The FINE grid: authored starter coordinates are in desklet cells, not
      // icon cells. A theme.json shipped before this change is one app version
      // old and its starter has not been applied on this device yet, so there
      // is nothing to convert, only something to author correctly.
      cols: effective.deskletCols,
      rows: effective.deskletRows,
      // Time-based, prefixed, and minted HERE rather than in theme.json — two
      // people installing the same pack must not end up sharing desklet ids.
      newId: () => 'dk${DateTime.now().microsecondsSinceEpoch}',
    );
    await ref
        .read(prefsProvider(spec.id).notifier)
        // .edit, never .update. See the wallpaper note above: `.update` mutates
        // state without writing to disk, so the flag would flip in memory and
        // revert on the next cold start, re-laying the starter desktop over the
        // user's arrangement on every launch.
        .edit((p) => seeded.copyWith(deskletsInitialized: true));
  }

  return effective;
});

/// Is the PHONE in dark mode right now?
///
/// ─── WHY A NOTIFIER AND NOT MediaQuery ──────────────────────────────────────
///
/// `MediaQuery.platformBrightnessOf(context)` is the usual answer and it is the
/// wrong one here, because the thing that needs the value is a PROVIDER, not a
/// widget. `effectiveThemeProvider` has no BuildContext, and threading one in
/// from whichever shell happened to build first would make the palette depend
/// on the widget tree's shape.
///
/// So the platform dispatcher is observed directly and republished as state.
/// One listener for the whole app, no context, and every consumer of
/// EffectiveTheme picks the change up through the ordinary rebuild path.
///
/// `themeMode` of 'light' or 'dark' ignores this entirely; it only decides the
/// 'system' case. The listener still runs in those modes, which costs one
/// comparison on an event most phones fire twice a day.
class SystemDark extends Notifier<bool> {
  ui.PlatformDispatcher? _dispatcher;

  @override
  bool build() {
    final d = ui.PlatformDispatcher.instance;
    _dispatcher = d;

    final previous = d.onPlatformBrightnessChanged;
    d.onPlatformBrightnessChanged = () {
      // Chained, never replaced. `onPlatformBrightnessChanged` is a single
      // slot: assigning it discards whoever registered before, and Flutter's
      // own binding registers here. Dropping that handler stops the framework
      // rebuilding on brightness change, which breaks MediaQuery for every
      // widget in the app to fix the palette for one provider.
      previous?.call();
      final now = _dispatcher?.platformBrightness == ui.Brightness.dark;
      if (now != state) state = now;
    };

    ref.onDispose(() => d.onPlatformBrightnessChanged = previous);

    return d.platformBrightness == ui.Brightness.dark;
  }
}

final systemDarkProvider = NotifierProvider<SystemDark, bool>(SystemDark.new);
