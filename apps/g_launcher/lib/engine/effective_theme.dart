import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/prefs/launcher_prefs.dart';
import '../data/prefs/prefs_repository.dart';
import '../data/repositories/app_repository.dart';
import '../platform/launcher_api.g.dart' as api;
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
        heroPack: themeIcons.heroPack,
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

  // First time this theme is used, apply its default wallpaper — the first
  // entry in the theme's list. ONCE, ever, tracked per theme.
  //
  // This does re-trigger the provider (we write prefs, prefs is watched), but it
  // terminates immediately: on the second pass wallpaperInitialized is true and
  // the branch is skipped. One extra rebuild at first run is a fair price for
  // never stamping over a wallpaper the user chose.
  if (!prefs.wallpaperInitialized && spec.wallpapers.isNotEmpty) {
    final source = spec.wallpapers.first;
    await api_.setWallpaper(
      source.startsWith('assets/') ? 'asset:$source' : source,
      false,
    );
    await ref
        .read(prefsProvider(spec.id).notifier)
        // .edit, NOT .update. `.update` resolves to the inherited
        // AsyncNotifier.update, which mutates state but never writes to disk —
        // so wallpaperInitialized would flip true in memory, then revert on the
        // next cold start, and the theme would re-stamp its default wallpaper
        // over the user's choice every launch. This is the exact `.update` trap
        // no_bare_update.sh exists to catch; it slipped through here.
        .edit((p) => p.copyWith(wallpaperInitialized: true));
  }

  return effective;
});
