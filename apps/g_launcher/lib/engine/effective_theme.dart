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
    required this.workspaceAxis,
    required this.rows,
    required this.cols,
    required this.drawerCols,
    required this.drawerScrollStyle,
    required this.drawerGrouping,
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

  /// Which way workspaces page. See [WorkspaceAxis].
  final WorkspaceAxis workspaceAxis;
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
  ThemeTypography get typography => spec.typography;
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
      workspaceAxis: layout.workspaceAxis,
      rows: layout.rows,
      cols: layout.cols,
      drawerCols: layout.drawerCols,
      drawerScrollStyle: layout.drawerScrollStyle,
      drawerGrouping: layout.drawerGrouping,
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
        brandPack: themeIcons.brandPack,
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

  @override
  int get hashCode => Object.hash(
        spec.id,
        prefs,
        dark,
        dock,
        topBar,
        topBarSide,
        topBarStats,
        panels.length,
        workspaceAxis,
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
      );
}

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
  final store = ref.read(prefsStoreProvider);
  final appliedToken =
      wallpaperAppliedToken(spec.id, dark: effective.dark);

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

    final preset = !effective.dark && spec.wallpapersLight.isNotEmpty
        ? spec.wallpapersLight
        : spec.wallpapers;

    final source = themeManaged
        ? (preset.isNotEmpty ? preset.first : current)
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
  // PHASE D-grid — rescale placements onto the fine grid, ONCE per theme.
  //
  // BEFORE the starter branch, and on its own flag, for the same reason the
  // starter and the wallpaper are separate: a desktop that already exists has
  // to be rescaled, and a desktop that does not yet exist has to be authored
  // straight into the new coordinates. Running the migration after the seeding
  // would rescale a starter that was never in the old system.
  //
  // Terminates the same way: it writes prefs, prefs is watched, this provider
  // re-runs, and the marker is set so the branch is skipped.
  if ((prefs.deskletGridVersion ?? 0) < DeskletLayout.gridVersion) {
    final migrated = DeskletLayout.migrateToFineGrid(prefs);
    await ref.read(prefsProvider(spec.id).notifier).edit((_) => migrated);
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
