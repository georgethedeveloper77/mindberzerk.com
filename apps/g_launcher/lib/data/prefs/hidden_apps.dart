import '../../platform/launcher_api.g.dart';
import 'launcher_prefs.dart';

/// Hiding apps, and the one rule for whether a hidden app may still be found.
///
/// **This file exists because there is more than one search box.** The drawer
/// filters through `visibleAppsProvider`, the search page uses the same, the
/// terminal and the tiling launcher rank through `paletteResultsProvider`, and
/// the desklet command bar has its own matcher. If the hidden rule lived in the
/// drawer, a hidden app would still fall out of the rofi launcher on two
/// letters, and the setting would be a lie on the surface people brag about.
/// One predicate, called from all of them, is the only shape of this that stays
/// true as surfaces get added.
///
/// ─── THE RULE ────────────────────────────────────────────────────────────────
///
/// A hidden app is **never ranked**. It cannot be reached by a prefix, a
/// substring, a fuzzy subsequence, a frecency boost or an empty query. It is
/// admitted only when the query IS the app's whole name.
///
/// That strictness is the entire feature. A rule of "hidden apps rank lower" or
/// "hidden apps need three characters" means typing `ti` resurfaces TikTok in
/// front of whoever you were hiding it from, and hiding becomes theatre. Whole
/// name or nothing: you have to already know what you are looking for, which is
/// exactly the person the escape hatch is for.
///
/// The package name is admitted too, because `com.zhiliaoapp.musically` is
/// something only the owner of the phone would ever type, and it is the honest
/// way out when an app's label is unpronounceable or duplicated.
abstract final class HiddenApps {
  /// Whether hidden apps may be reached by typing their whole name.
  ///
  /// **The default lives here and nowhere else.** null in prefs means "not
  /// chosen", and every caller must resolve it through this function rather
  /// than writing `?? true` at the call site — the moment two places spell the
  /// default, one of them is eventually wrong.
  static bool searchable(LauncherPrefs p) => p.hiddenAppsSearchable ?? true;

  static bool isHidden(LauncherPrefs p, String componentKey) =>
      p.hiddenApps.contains(componentKey);

  /// Hide / unhide, as a pure prefs edit like every other mutation in this
  /// folder. Returns [p] unchanged when there is nothing to do, so callers can
  /// compare by identity.
  static LauncherPrefs hide(LauncherPrefs p, String componentKey) =>
      p.hiddenApps.contains(componentKey)
          ? p
          : p.copyWith(hiddenApps: {...p.hiddenApps, componentKey});

  static LauncherPrefs unhide(LauncherPrefs p, String componentKey) =>
      p.hiddenApps.contains(componentKey)
          ? p.copyWith(
              hiddenApps: {...p.hiddenApps}..remove(componentKey),
            )
          : p;

  static LauncherPrefs unhideAll(LauncherPrefs p) =>
      p.hiddenApps.isEmpty ? p : p.copyWith(hiddenApps: const {});

  /// Uninstalled apps must not haunt the hidden set — otherwise reinstalling an
  /// app you once hid brings it back invisible, and nobody connects the two.
  /// Call alongside `DrawerLayout.prune`.
  static LauncherPrefs prune(LauncherPrefs p, Set<String> liveKeys) {
    final kept = p.hiddenApps.where(liveKeys.contains).toSet();
    return kept.length == p.hiddenApps.length
        ? p
        : p.copyWith(hiddenApps: kept);
  }

  /// Whether [app] may appear in results for [query].
  ///
  /// Visible apps always may — this function has no opinion about them, it only
  /// answers the hidden question, so callers can apply it unconditionally
  /// instead of branching.
  static bool admits(LauncherPrefs p, AppEntry app, String query) {
    if (!p.hiddenApps.contains(app.componentKey)) return true;
    if (!searchable(p)) return false;

    final q = _norm(query);
    if (q.isEmpty) return false;

    return q == _norm(app.label) || q == app.packageName.toLowerCase().trim();
  }

  /// The list a search surface should actually match against.
  ///
  /// Fast path first: the overwhelmingly common case is an empty hidden set on
  /// a ~130-app drawer, and that must not cost an allocation per keystroke.
  static List<AppEntry> forSearch(
    List<AppEntry> apps,
    LauncherPrefs p,
    String query,
  ) {
    if (p.hiddenApps.isEmpty) return apps;
    return [
      for (final a in apps)
        if (admits(p, a, query)) a,
    ];
  }

  /// Case, surrounding space and INTERNAL runs of space folded away, so
  /// "WA  Business" and "wa business" are the same thing typed twice. Nothing
  /// else is stripped: removing punctuation would let `x` match "X", which is
  /// a whole-name match by accident and precisely what the rule forbids.
  static String _norm(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}
