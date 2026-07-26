import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/prefs/launcher_prefs.dart';
import '../data/prefs/prefs_repository.dart';
import '../data/prefs/starter_desktop.dart';
import '../data/repositories/app_repository.dart';
import '../platform/launcher_api.g.dart' as api;
import '../system/wallpaper_source.dart';
import 'layout_resolver.dart';
import 'theme_engine.dart';
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
    required this.rows,
    required this.cols,
    required this.drawerCols,
    required this.iconSizeDp,
    required this.labelLines,
    required this.textScale,
    required this.iconScale,
    required this.icons,
  });

  final ThemeSpec spec;
  final LauncherPrefs prefs;

  final DockSide dock;
  final bool topBar;
  final int rows;
  final int cols;

  /// Denser than home by convention.
  final int drawerCols;

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

  ThemePalette get palette => spec.palette;
  ThemeTypography get typography => spec.typography;
  ShellKind get shell => spec.shell;

  /// The resolved chrome family, surfaced here so the chrome layer reads it off
  /// EffectiveTheme (the single source of truth) rather than reaching into the
  /// spec. Pure passthrough; no user override merges into it (yet).
  ChromeFamily get chromeFamily => spec.chromeFamily;

  static EffectiveTheme resolve(ThemeSpec spec, LauncherPrefs prefs) {
    // Layout scalars (dock, grid, sizes, labels) live in LayoutResolver, the
    // one owner of the theme-default-then-user-override merge. Icon SHAPE is a
    // separate concern and stays below, coupled to iconCacheId and the native
    // push.
    final layout = LayoutResolver.resolve(spec, prefs);
    final themeIcons = spec.icons;

    return EffectiveTheme(
      spec: spec,
      prefs: prefs,
      dock: layout.dock,
      topBar: layout.topBar,
      rows: layout.rows,
      cols: layout.cols,
      drawerCols: layout.drawerCols,
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
          other.dock == dock &&
          other.topBar == topBar &&
          other.rows == rows &&
          other.cols == cols &&
          other.drawerCols == drawerCols &&
          other.iconSizeDp == iconSizeDp &&
          other.labelLines == labelLines &&
          other.textScale == textScale &&
          other.iconScale == iconScale &&
          other.iconCacheId == iconCacheId;

  @override
  int get hashCode => Object.hash(
        spec.id,
        prefs,
        dock,
        topBar,
        rows,
        cols,
        drawerCols,
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
  final prefs = await ref.watch(prefsProvider(spec.id).future);

  final effective = EffectiveTheme.resolve(spec, prefs);

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
  final store = ref.read(prefsStoreProvider);
  if (await store.read(wallpaperAppliedForKey) != spec.id) {
    // The user's choice for THIS theme, else the theme's own first preset.
    final source = prefs.wallpaperCurrent ??
        (spec.wallpapers.isNotEmpty ? spec.wallpapers.first : null);

    if (source != null) {
      await api_.setWallpaper(
        encodeWallpaperSource(source),
        prefs.wallpaperLock ?? false,
      );
      await store.write(wallpaperAppliedForKey, spec.id);
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
  if (!prefs.deskletsInitialized) {
    final seeded = StarterDesktop.apply(
      prefs,
      spec.desklets,
      cols: effective.cols,
      rows: effective.rows,
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
