import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/prefs/drawer_layout.dart';
import '../../data/prefs/launcher_prefs.dart';
import '../../data/prefs/prefs_repository.dart';
import '../../data/repositories/shell_apps.dart';
import '../../engine/effective_theme.dart';
import '../../platform/launcher_api.g.dart';

/// What the Activities drawer shows: real apps, plus a small number of
/// launcher-owned entries that aren't packages.
///
/// This exists so a synthetic entry never has to masquerade as an [AppEntry].
/// The moment it does, three things go wrong quietly: `launch()` fires a native
/// intent on a component key that isn't there, `getIcon()` asks the OS for an
/// icon that isn't there, and pin-to-dock resolves the key to nothing. A sealed
/// type keeps those paths honest: the drawer switches on the variant and each
/// one gets the tap / icon / menu that actually applies to it.
///
/// Sealed on purpose. When a new launcher-owned entry lands it's a new variant
/// here, and the `switch` in the drawer stops compiling until it's handled.
/// That's the point.
sealed class DrawerItem {
  const DrawerItem();

  /// Used for A-to-Z ordering and search. Every variant has one.
  String get label;
}

/// A real installed app.
class AppDrawerItem extends DrawerItem {
  const AppDrawerItem(this.entry);

  final AppEntry entry;

  @override
  String get label => entry.label;
}

/// A folder the user built in the drawer by dragging one app onto another.
///
/// Carries the resolved [members] rather than raw component keys so the tile can
/// paint its 2x2 preview without every folder cell re-resolving the app list.
/// Only INSTALLED members are included; an uninstalled one is dropped here and
/// swept from storage by `DrawerLayout.prune`.
class FolderDrawerItem extends DrawerItem {
  const FolderDrawerItem(this.folder, this.members);

  final AppFolder folder;
  final List<AppEntry> members;

  @override
  String get label => folder.name;
}

/// G Launcher's own settings, surfaced as a drawer entry so it opens without a
/// gesture. Surfacing what already exists, not a new feature.
class LauncherSettingsItem extends DrawerItem {
  const LauncherSettingsItem();

  static const String title = 'G Launcher Settings';

  @override
  String get label => title;
}

/// A shortcut out to the real Android Settings (`Settings.ACTION_SETTINGS`).
///
/// The launcher owns the entry, never the screen: this hands off to the OS and
/// reimplements nothing. On a GNOME/Ubuntu skin this is the honest analog of the
/// desktop's own "Settings", while [LauncherSettingsItem] is the launcher's
/// tweak surface. Two labels, no ambiguity.
class DeviceSettingsItem extends DrawerItem {
  const DeviceSettingsItem();

  static const String title = 'Device Settings';

  @override
  String get label => title;
}

/// The drawer's contents: the theme's app list wrapped as items, with the
/// launcher-owned entries appended and the whole thing re-sorted so they sit in
/// alphabetical position like any other app.
///
/// Appended HERE, downstream of [shellAppsProvider], and deliberately so:
/// [shellAppsProvider] is where per-theme hidden apps are filtered out. Keeping
/// the launcher entries out of that flow means the "hide app" toggle can never
/// remove the one gesture-free way into Settings.
///
/// Note this is drawer-only. The dock and home grid read [shellAppsProvider]
/// directly and never see these entries, which is correct: the dock resolves
/// component keys against installed apps, and a launcher entry has none.
final drawerItemsProvider =
    Provider.family<List<DrawerItem>, EffectiveTheme>((ref, theme) {
  final apps = ref.watch(shellAppsProvider(theme));
  final byKey = {for (final a in apps) a.componentKey: a};

  // Prefs are watched DIRECTLY rather than read off the [EffectiveTheme] family
  // key, and that is load-bearing.
  //
  // This provider is keyed by EffectiveTheme. If EffectiveTheme's ==/hashCode
  // enumerates specific prefs fields instead of delegating to LauncherPrefs.==,
  // then creating a folder produces a theme that compares EQUAL to the previous
  // one — same family key, cached list returned, and the folder never appears
  // even though it was written to disk. Watching prefsProvider makes this
  // provider a dependent of the prefs notifier, so a folder change invalidates
  // it regardless of how the key compares. Falls back to the key's snapshot
  // while the async prefs load.
  final prefs =
      ref.watch(prefsProvider(theme.spec.id)).asData?.value ?? theme.prefs;

  // Apps that live inside a drawer folder are hidden from the flat list — they
  // are reachable by opening the folder. Everything else stays loose.
  final folded = DrawerLayout.foldedKeys(prefs);

  // FOLDERS FIRST, then apps.
  //
  // A folder is a thing you made; an app is a thing that was installed. Mixing
  // them alphabetically means a folder called "Zoom stuff" sits 200 rows below
  // one called "Admin", and the groups you built are scattered through a wall
  // of icons you did not. Every Android drawer that supports folders puts them
  // up front for this reason.
  //
  // Within the folder block: alphabetical, unless the user dragged them into
  // their own order (see DrawerLayout.orderedFolders).
  final folders = <DrawerItem>[
    for (final f in DrawerLayout.orderedFolders(prefs))
      FolderDrawerItem(
        f,
        [
          for (final k in f.members)
            if (byKey[k] != null) byKey[k]!,
        ],
      ),
  ];

  // LAUNCHER ENTRIES ARE PINNED, NOT SORTED.
  //
  // This REVERSES the Phase A decision to sort them in alphabetically like any
  // other app, and the reversal is not a matter of taste — the original does not
  // survive contact with a real drawer.
  //
  // On a test device with 261 apps, "G Launcher Settings" lands under G, some
  // sixty rows down a four-column grid, and "Device Settings" under D. Someone
  // hunting for the launcher's settings scrolls to S, finds Android's own
  // Settings app, and concludes this launcher has none. Reported as "settings
  // is not appearing", which is exactly what it looks like from the outside.
  //
  // These are not apps. They are the launcher's own chrome, and chrome buried
  // among 261 third-party icons is chrome nobody finds. Same argument that puts
  // folders first: a thing you made, or a thing this app owns, should not be
  // scattered through a wall of things you merely installed.
  //
  // KDE already reached this conclusion independently — kickoff_drawer keeps
  // them out of its main list and pins them to its footer. This brings the grid
  // drawers into line rather than leaving one shell right and three wrong.
  final launcherEntries = <DrawerItem>[
    const LauncherSettingsItem(),
    const DeviceSettingsItem(),
  ];

  final appItems = <DrawerItem>[
    for (final a in apps)
      if (!folded.contains(a.componentKey)) AppDrawerItem(a),
  ]..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));

  return [...folders, ...launcherEntries, ...appItems];
});

/// The drawer list, filtered by a query, WITH the launcher entries included.
///
/// ─── WHY THIS EXISTS SEPARATELY FROM paletteResultsProvider ─────────────────
///
/// That provider ranks `AppEntry`, and a launcher entry is not one. So the rofi
/// launcher shows Settings on an empty query (it renders [drawerItemsProvider])
/// and loses it the instant you type, because it switches to the app matcher.
/// Typing "settings" on Arch could never find G Launcher's settings.
///
/// This is the same root cause the terminal shell had, and the terminal only
/// got fixed because there it was obvious: with no drawer at all, the absence
/// was total rather than merely intermittent.
///
/// A SUBSTRING match, not fuzzy, and that is deliberate. Fuzzy ranking is right
/// for the palette, where you type two letters and want the best guess. Here the
/// list is already on screen and the user is narrowing it; results reordering
/// under a substring they typed reads as the list fighting them. `AppDrawer`'s
/// own filter made the same call.
final drawerSearchProvider = Provider.family<List<DrawerItem>,
    ({EffectiveTheme theme, String query})>((ref, arg) {
  final items = ref.watch(drawerItemsProvider(arg.theme));
  final q = arg.query.trim().toLowerCase();
  if (q.isEmpty) return items;

  return [
    for (final i in items)
      if (_matches(i, q)) i,
  ];
});

/// The launcher-owned entries a query should surface, in pinned order.
///
/// PUBLIC because three surfaces need the same vocabulary and must not each
/// invent their own: the rofi launcher's typed branch, the GNOME search page,
/// and any future one. Three private copies of "does 'theme' mean Settings" is
/// how a search box starts disagreeing with itself between shells.
///
/// Empty for an empty query — a caller showing its own pre-typing layout does
/// not want these injected into it.
List<DrawerItem> launcherItemsMatching(String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const [];

  const all = <DrawerItem>[LauncherSettingsItem(), DeviceSettingsItem()];
  return [
    for (final i in all)
      if (_matches(i, q)) i,
  ];
}

/// Label first, then the aliases below for the launcher-owned entries.
///
/// An app matches on its label and nothing else: inventing synonyms for
/// third-party apps is how a search box starts surfacing things nobody asked
/// for. The launcher's own entries are the exception because their labels are
/// the one thing the user cannot guess — nobody types "G Launcher Settings".
bool _matches(DrawerItem item, String q) {
  if (item.label.toLowerCase().contains(q)) return true;

  final aliases = switch (item) {
    LauncherSettingsItem() => launcherSettingsAliases,
    DeviceSettingsItem() => deviceSettingsAliases,
    // Folders match on the name the user gave them, which is already the label.
    AppDrawerItem() || FolderDrawerItem() => const <String>[],
  };

  for (final a in aliases) {
    if (a.contains(q) || q.contains(a)) return true;
  }
  return false;
}

/// Extra words that should find a launcher entry.
///
/// "settings" is the obvious one and it already matches by label. These are the
/// ones that do not: someone looking for the theme picker types "theme", not
/// "G Launcher Settings", and the theme picker lives one tap inside that screen.
///
/// Kept as data next to the items rather than inside a matcher so the terminal's
/// command table and the drawer search can agree on the vocabulary.
const launcherSettingsAliases = <String>[
  'settings',
  'theme',
  'themes',
  'distro',
  'launcher',
  'wallpaper',
  'gestures',
  'icons',
];

const deviceSettingsAliases = <String>[
  'android',
  'system',
  'device',
  'phone',
];
