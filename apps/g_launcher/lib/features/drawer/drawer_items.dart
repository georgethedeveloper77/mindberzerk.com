import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/prefs/drawer_layout.dart';
import '../../data/prefs/drawer_slots.dart';
import '../../data/prefs/launcher_prefs.dart';
import '../../data/prefs/prefs_repository.dart';
import '../../data/repositories/shell_apps.dart';
import '../../data/usage/usage_repository.dart';
import '../../engine/effective_theme.dart';
import '../../engine/terminal_spec.dart';
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

/// The Terminal, surfaced as a drawer entry.
///
/// ─── WHY THIS IS A DRAWER ENTRY AND NOT AN ACTIVITY ─────────────────────────
///
/// The obvious implementation is an exported activity-alias enabled per theme,
/// so the OS lists it like any app. It is also the wrong one: the label is
/// per distro, the icon is per distro, and the entry would then have to be
/// enabled and disabled as themes are installed and switched, with a launcher
/// restart to see it.
///
/// As a [DrawerItem] it costs nothing. Every drawer already switches on this
/// type, so list, grid, cube, horizontal and Kickoff all get it at once, and it
/// follows a theme change in the same frame the palette does.
///
/// ─── WHY IT CARRIES ITS LABEL ───────────────────────────────────────────────
///
/// [LauncherSettingsItem] and [DeviceSettingsItem] each expose a `static const
/// title`, because their names are fixed. This one is not: it is
/// `TerminalSpec.appLabel`, so Kali says "Kali Terminal" and COSMIC says
/// "COSMIC Terminal". A static title would be a fourth place for a name to
/// live and the only place it could be wrong.
class TerminalDrawerItem extends DrawerItem {
  const TerminalDrawerItem([this.title = defaultTitle]);

  /// Used where no theme is in hand. Every path that has one passes it.
  static const String defaultTitle = 'Terminal';

  final String title;

  @override
  String get label => title;

  @override
  bool operator ==(Object other) =>
      other is TerminalDrawerItem && other.title == title;

  @override
  int get hashCode => title.hashCode;
}

/// This theme's terminal label, with the shell family default behind it.
///
/// A theme that predates the `terminal` block still gets a terminal, which is
/// the promise `TerminalSpec.defaultForShell` makes and the reason a Kali user
/// on `shell: gnome` is not left without one.
String terminalLabelFor(EffectiveTheme theme) =>
    theme.spec.terminal?.appLabel ??
    TerminalSpec.defaultForShell(theme.spec.shell).appLabel;

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
/// The `id` prefix every generated category folder carries.
///
/// The one thing that tells a synthetic folder from one the user built. It is a
/// prefix rather than a flag on [FolderDrawerItem] because the id travels
/// everywhere the folder does: into the overlay, into `DrawerLayout` calls,
/// into slot storage. A flag would have to be threaded through all of those and
/// would be dropped by the first place that reconstructs an [AppFolder] from an
/// id alone.
const kCategoryFolderPrefix = 'cat:';

/// How many apps the Suggestions bucket holds.
///
/// Six, because the tile draws three large and the rest as a cluster, and a
/// cluster of one is a cluster that should have been a fourth large icon.
const _kSuggestions = 6;

/// Below this many, the bucket does not appear at all.
///
/// Four, not one. A Suggestions folder holding two apps is a heading that has
/// learned almost nothing about you and takes a whole tile to say so; the
/// categories underneath are more useful until it has more.
const _kMinSuggestions = 4;

/// True for a folder this file generated rather than one the user made.
bool isCategoryFolder(String folderId) =>
    folderId.startsWith(kCategoryFolderPrefix);

/// Which folder an app belongs in, or null to leave it loose.
///
/// ─── READ, NOT GUESSED ──────────────────────────────────────────────────────
///
/// Every answer here comes from `ApplicationInfo.category`, which the app
/// itself declares in its manifest, or from `isGame`, which the bridge already
/// resolves from the modern category with a fallback to the legacy
/// `FLAG_IS_GAME`. Nothing is inferred from a package name or a label.
///
/// That restraint is the whole point. A category folder built by name-matching
/// files Signal under Shopping once, and after that nobody trusts any folder on
/// the screen. A drawer that groups less but never lies is worth more than one
/// that groups everything and is sometimes absurd.
///
/// ─── UNDEFINED STAYS LOOSE, AND THAT IS MOST APPS ───────────────────────────
///
/// `CATEGORY_UNDEFINED` is the default and plenty of apps never set it, so on a
/// real device a large share returns null here. They render as loose icons in
/// the A to Z run rather than being swept into a folder called Other.
///
/// A folder holding most of the drawer is not organisation, and its 2x2 preview
/// would show four arbitrary icons out of two hundred. Loose is the honest
/// rendering: the library degrades into the grid that already works.
String? builtInBucket(AppEntry a) {
  // GAMES FIRST, and it is not just the category. `isGame` also catches apps
  // that predate the category and only set the legacy flag, which is a lot of
  // what is actually installed on a budget phone.
  if (a.isGame) return 'Games';

  // The numbers are `ApplicationInfo`'s own constants. They are written as
  // literals rather than imported because the bridge hands over a plain int and
  // there is no Dart-side enum to compare against.
  return switch (a.category) {
    0 => 'Games', // CATEGORY_GAME, for anything isGame missed
    1 => 'Media', // AUDIO
    2 => 'Media', // VIDEO
    3 => 'Media', // IMAGE
    4 => 'Social', // SOCIAL
    5 => 'News',
    6 => 'Travel', // MAPS
    7 => 'Productivity',
    8 => 'Utilities', // ACCESSIBILITY
    // ─── EVERYTHING ELSE HAS A FOLDER, AND THAT IS A REVERSAL ───────────
    //
    // These used to return null and render as loose icons, on the reasoning
    // that `CATEGORY_UNDEFINED` is the default most apps never set, so an Other
    // folder would swallow a large share of the drawer and its preview would
    // show four arbitrary icons.
    //
    // iOS has exactly this folder and it works, because a folder is not a
    // summary. It OPENS into a scrollable grid; the tile only ever promises its
    // top few and a count. A big Other is not a broken folder, it is a big
    // folder, and it beats a hundred loose icons after the categories.
    //
    // -1 is CATEGORY_UNDEFINED. Anything else is a constant from an Android
    // newer than this build knows about, and lands here for the same reason.
    _ => 'Other',
  };
}

/// The order category folders appear in.
///
/// FIXED, not alphabetical and not by size. A drawer whose folders reorder
/// themselves as you install things is a drawer you cannot build muscle memory
/// against, and size-ordering means the biggest folder moves to the front the
/// first time you install two of something.
const kCategoryOrder = [
  'Social',
  'Media',
  'Productivity',
  'Games',
  'News',
  'Travel',
  'Utilities',
  // LAST, always. It is the remainder, and on a device where few apps declare
  // a category it is also the biggest, which is exactly why it must not be the
  // first thing the eye lands on.
  'Other',
];

/// Below this, a category renders as loose icons instead of a folder.
///
/// A folder holding one app is strictly worse than that app sitting loose: same
/// tap count to launch it becomes two, and its 2x2 preview is three quarters
/// empty. Two is the smallest number where a folder saves any space at all.
const kMinCategoryMembers = 2;

/// The category vocabulary in force: which buckets exist, in what order, and
/// what an app that matches none of them is called.
///
/// ─── ONE OBJECT BECAUSE TWO PLACES WERE HARDCODING THE SAME THREE THINGS ────
///
/// The library branch below and `KickoffDrawer._bucket` both walked
/// [kCategoryOrder], both called [builtInBucket], and both wrote the string
/// `'Other'` inline as the bucket that is never swept. Three constants, two
/// copies, and the copies could not both be right once a distro was allowed to
/// name its own categories. Kickoff's own doc already says what must not
/// diverge is the RULE; this is the rule with a type.
///
/// ─── AND A DISTRO CANNOT USE IT TO LIE ──────────────────────────────────────
///
/// [ThemeCategory] supplies names and order. It does NOT supply a filing rule:
/// [nameFor] still asks [builtInBucket], which reads what the app declares
/// about itself, and a distro can only say which built-in bucket pours into
/// which of its own names. So Kali gets thirteen tool groups in the rail and
/// none of them can claim Chrome, because no Android category honestly maps to
/// "01 Information Gathering".
class CategorySet {
  const CategorySet({
    required this.order,
    required this.feeds,
    required this.fallback,
  });

  /// Display order. [fallback] is last, always: it is the remainder, and on a
  /// device where few apps declare a category it is also the biggest.
  final List<String> order;

  /// Built-in bucket name to this distro's name. Empty means the built-in
  /// names ARE the distro's names, which is every distro shipping today.
  final Map<String, String> feeds;

  /// Where an unclaimed app goes. Never swept below [kMinCategoryMembers],
  /// because there is nowhere left for its members to go.
  final String fallback;

  /// The set every distro gets unless its theme.json says otherwise. Byte for
  /// byte the behaviour that was inline before this type existed.
  static const builtIn = CategorySet(
    order: kCategoryOrder,
    feeds: {},
    fallback: 'Other',
  );

  /// This distro's set, or [builtIn] when it authors none.
  static CategorySet forTheme(EffectiveTheme theme) {
    final authored = theme.spec.categories;
    if (authored.isEmpty) return builtIn;

    final fallback = theme.spec.categoryFallback?.trim();
    final name = (fallback == null || fallback.isEmpty) ? 'Other' : fallback;

    return CategorySet(
      // The fallback is APPENDED rather than assumed to be in the list. A
      // distro naming thirteen tool groups has no reason to remember to add a
      // fourteenth for the apps that are not tools, and if it does name it the
      // order below still puts it exactly once and exactly last.
      order: [
        for (final c in authored)
          if (c.name != name) c.name,
        name,
      ],
      feeds: {
        for (final c in authored)
          for (final f in c.feeds) f: c.name,
      },
      fallback: name,
    );
  }

  /// What this app's folder is called, or null to leave it loose.
  String? nameFor(AppEntry a) {
    final bucket = builtInBucket(a);
    if (bucket == null) return null;
    final mapped = feeds[bucket];
    if (mapped != null) return mapped;
    // An unmapped bucket keeps its own name only if this vocabulary has one.
    // On an authored set it does not, so it falls to the remainder, which is
    // what puts Chrome under Usual Applications rather than inventing a
    // Social folder inside Kali's tool menu.
    return order.contains(bucket) ? bucket : fallback;
  }

  /// Sweep sub-threshold buckets into [fallback], the way both call sites did
  /// by hand. Returns the members that moved.
  ///
  /// Generic over the element so the library branch can sweep `AppEntry` and
  /// Kickoff can sweep `DrawerItem` without a second copy.
  List<T> sweep<T>(Map<String, List<T>> buckets) {
    final strays = <T>[];
    buckets.removeWhere((name, v) {
      if (name == fallback || v.length >= kMinCategoryMembers) return false;
      strays.addAll(v);
      return true;
    });
    if (strays.isNotEmpty) (buckets[fallback] ??= []).addAll(strays);
    return strays;
  }
}

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
  //
  // THE TERMINAL SITS WITH THEM, and for the same reason rather than a new one.
  // It is launcher-owned, it is not an installed package, and a person looking
  // for it is looking for this launcher's terminal specifically. Sorted in
  // alphabetically it would land under T among 261 icons on the one distro
  // whose entire pitch is that it has a terminal.
  final launcherEntries = <DrawerItem>[
    const LauncherSettingsItem(),
    const DeviceSettingsItem(),
    TerminalDrawerItem(terminalLabelFor(theme)),
  ];

  // ── SORT MODES ──────────────────────────────────────────────────────────
  //
  // 'az' (null) is the order everything above described. 'mostUsed' and
  // 'recent' re-rank the LOOSE APPS by the usage repository's two orderings,
  // with never-launched apps keeping their alphabetical order after the
  // ranked ones; folders and the launcher entries do not re-rank, because a
  // folder's frecency is not a thing the usage store measures. 'custom'
  // returns the slot arrangement FLATTENED, launcher entries first, so search
  // and every other flat consumer sees the drawer in the order the user
  // built; the drawer body itself renders the sparse grid via
  // [drawerCustomGridProvider], gaps included.
  final mode = prefs.drawerSortMode ?? 'custom';

  // ── THE LIBRARY ─────────────────────────────────────────────────────────
  //
  // Category folders, generated from what each app declares about itself.
  // Reached only under `drawerGrouping: 'library'`, so every other distro's
  // drawer is byte-identical to what it was.
  //
  // ─── BEFORE THE SORT MODES, AND THAT IS THE CORRECTION ────────────────────
  //
  // This sat at the BOTTOM, after `custom` had already returned its slot grid.
  // The reasoning was that a grid the user arranged by hand is the one thing
  // grouping must not rewrite, which sounds right and is wrong for one reason:
  // `drawerSortMode ?? 'custom'` means custom is the DEFAULT. So on any device
  // where nobody had gone looking for the sort setting, picking Library did
  // absolutely nothing, with no message saying why.
  //
  // Grouping outranks sort mode because it is the stronger statement. Custom is
  // usually a default nobody chose; Library is a switch somebody deliberately
  // moved. Switching back restores the slot grid untouched, because this reads
  // the arrangement and never writes it.
  if (theme.libraryGrouped) {
    final loose = <DrawerItem>[
      for (final a in apps)
        if (!folded.contains(a.componentKey)) AppDrawerItem(a),
    ]..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));

    // THE DISTRO'S vocabulary, not the built-in one. Identical for every theme
    // that authors no `categories`, which is all of them but Kali.
    final cats = CategorySet.forTheme(theme);

    final buckets = <String, List<AppEntry>>{};
    for (final item in loose) {
      final entry = (item as AppDrawerItem).entry;
      final name = cats.nameFor(entry);
      if (name == null) continue;
      (buckets[name] ??= []).add(entry);
    }

    // A folder of one is worse than that app sitting loose: two taps to launch
    // instead of one. Its members go to the fallback rather than back to the
    // loose run, because with a fallback existing there is no loose run left.
    cats.sweep(buckets);

    // ─── MOST USED FIRST, INSIDE EVERY FOLDER ─────────────────────────────
    //
    // The tile shows its first three large and the next few as a cluster, so
    // "first" is the whole question: alphabetical order means a folder called
    // Social leads with whatever happens to start with A.
    //
    // `frequentAppsProvider` is the same frecency ranking the `mostUsed` sort
    // mode uses, so nothing new is measured and no figure is invented. Apps
    // with no usage yet keep their alphabetical order behind the ranked ones,
    // which is what makes a fresh install still look deliberate.
    final freq = ref.watch(frequentAppsProvider);
    final rank = {for (var i = 0; i < freq.length; i++) freq[i]: i};
    for (final list in buckets.values) {
      list.sort((a, b) {
        final ra = rank[a.componentKey] ?? 1 << 30;
        final rb = rank[b.componentKey] ?? 1 << 30;
        if (ra != rb) return ra.compareTo(rb);
        return a.label.toLowerCase().compareTo(b.label.toLowerCase());
      });
    }

    final filed = <String>{
      for (final members in buckets.values)
        for (final a in members) a.componentKey,
    };

    final categoryFolders = <DrawerItem>[
      for (final name in cats.order)
        if (buckets[name] != null)
          FolderDrawerItem(
            AppFolder(
              id: '$kCategoryFolderPrefix$name',
              name: name,
              members: [for (final a in buckets[name]!) a.componentKey],
            ),
            buckets[name]!,
          ),
    ];

    // ─── SUGGESTIONS, AND WHY IT IS NOT A CATEGORY ────────────────────────
    //
    // Every folder above answers "what KIND of app is this", from the manifest
    // or from the distro's own vocabulary. This one answers "what do you
    // actually open", which is a different question and the reason it leads:
    // a phone's App Library opens on the apps you use, not on the letter A.
    //
    // ─── IT DELIBERATELY DOUBLE-COUNTS ────────────────────────────────────
    //
    // Its members are NOT added to `filed`, so an app in Suggestions still
    // appears in Social or Productivity underneath. That is not an oversight:
    // a bucket of your six most-used apps that emptied their real categories
    // would make those categories lie about what is in them, and the app you
    // use most would be the one you could no longer find where you expect it.
    //
    // ─── AND IT IS SILENT ON A FRESH INSTALL ──────────────────────────────
    //
    // `frequentAppsProvider` is empty until something has been launched, so
    // this bucket does not exist on day one rather than showing six arbitrary
    // apps under a heading claiming they are your favourites. The section
    // appears the moment it has something true to say.
    //
    // Built AFTER `filed` for exactly the reason above, and given the same
    // `cat:` prefix as the derived folders because that is what it is: a
    // read-only bucket the user cannot file into, and every screen that already
    // knows not to write into a category folder knows not to write into this.
    final suggestions = <AppEntry>[
      for (final k in freq.take(_kSuggestions))
        if (byKey[k] != null) byKey[k]!,
    ];

    return [
      // ─── SUGGESTIONS LEADS, AHEAD OF THE USER'S OWN ───────────────────
      //
      // It sat after the user's folders on the reasoning that something you
      // built outranks something derived for you. On screen that put a folder
      // called Games in the top-left and Suggestions beside it, and the tile
      // you actually open every time was the second thing your eye reached.
      //
      // The rule was right about ownership and wrong about position. This one
      // is not a category competing with yours; it is the shortcut past all of
      // them, and a shortcut below the things it shortcuts is not one.
      if (suggestions.length >= _kMinSuggestions)
        FolderDrawerItem(
          AppFolder(
            id: '${kCategoryFolderPrefix}Suggestions',
            name: 'Suggestions',
            members: [for (final a in suggestions) a.componentKey],
          ),
          suggestions,
        ),
      // Then the user's own, which still outrank the derived categories below.
      ...folders,
      ...categoryFolders,
      ...launcherEntries,
      for (final item in loose)
        if (!filed.contains((item as AppDrawerItem).entry.componentKey)) item,
    ];
  }

  if (mode == 'custom') {
    // The STORED pair here, not the live one, and that is not the same
    // inconsistency the provider's doc warns about. This provider produces a
    // flat ORDER for search, the dock and everything else that wants a list;
    // order is unchanged by how many rows the screen happens to fit, and this
    // provider has no screen to ask. The BODY is what renders the grid, and it
    // passes the derived count.
    final grid = ref.watch(drawerCustomGridProvider((
      theme: theme,
      cols: math.max(1, prefs.drawerSlotCols ?? 4),
      rows: math.max(1, prefs.drawerSlotRows ?? 5),
    )));
    return [
      for (final cell in grid.cells)
        if (cell != null) cell,
    ];
  }

  var appItems = <DrawerItem>[
    for (final a in apps)
      if (!folded.contains(a.componentKey)) AppDrawerItem(a),
  ]..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));

  if (mode == 'mostUsed' || mode == 'recent') {
    final ranked = mode == 'mostUsed'
        ? ref.watch(frequentAppsProvider)
        : ref.watch(recentAppsProvider);
    final rank = {for (var i = 0; i < ranked.length; i++) ranked[i]: i};

    // A STABLE re-sort: ranked apps in rank order, everything unranked keeps
    // the alphabetical order it already has, after them. List.sort is not
    // stable in Dart, so the split-and-concatenate does what a stable sort
    // key would.
    final rankedItems = <(int, DrawerItem)>[];
    final unranked = <DrawerItem>[];
    for (final item in appItems) {
      final key = (item as AppDrawerItem).entry.componentKey;
      final r = rank[key];
      if (r != null) {
        rankedItems.add((r, item));
      } else {
        unranked.add(item);
      }
    }
    rankedItems.sort((a, b) => a.$1.compareTo(b.$1));
    appItems = [for (final e in rankedItems) e.$2, ...unranked];
  }

  return [...folders, ...launcherEntries, ...appItems];
});

/// What the CUSTOM drawer renders: the sparse slot grid, resolved.
///
/// A flat cell list of length pageCount x capacity, where null is a gap. The
/// first two cells are always the launcher's own entries (see
/// [DrawerSlots.reservedSlots]). Entries whose app or folder no longer
/// resolves render as gaps here and are swept from storage by Clean up pages
/// or the next prune. Anything alive but UNPLACED, a new install, an app just
/// pulled out of a folder, a folder made outside Custom, is DISPLAYED
/// appended after the last occupied slot, folders before apps, both
/// alphabetical; it becomes stored the first time it is dragged. One trailing
/// empty page always exists so there is somewhere to drag things to.
typedef DrawerCustomGrid = ({
  List<DrawerItem?> cells,
  int cols,
  int rows,
  int pageCount,
});

/// The key for [drawerCustomGridProvider].
///
/// ─── WHY THE GRID IS PASSED IN AND NOT READ FROM PREFS ──────────────────────
///
/// It used to read `drawerSlotCols` and `drawerSlotRows`, the count frozen when
/// Custom was first entered. Freezing the grid was the whole point of the
/// sparse-slot model: a stored (page, index) only means anything against a
/// known capacity.
///
/// It also meant the Custom drawer rendered a DIFFERENT number of rows from
/// every other sort mode. Once cells were sized to their contents the frozen
/// count no longer fit, the pager squeezed the cells to make it fit, and
/// squeezing a content-sized cell clips exactly one thing: the label on the
/// last row.
///
/// So the row count now comes from the SAME derivation alphabetical uses, and
/// the stored pair is what the caller reconciles against; see the reflow in
/// app_drawer. Custom, most used and recently used all lay out identically,
/// which is what they should have done from the start.
typedef DrawerGridKey = ({EffectiveTheme theme, int cols, int rows});

final drawerCustomGridProvider =
    Provider.family<DrawerCustomGrid, DrawerGridKey>((ref, key) {
  final theme = key.theme;
  final apps = ref.watch(shellAppsProvider(theme));
  final byKey = {for (final a in apps) a.componentKey: a};

  final prefs =
      ref.watch(prefsProvider(theme.spec.id)).asData?.value ?? theme.prefs;

  final cols = math.max(1, key.cols);
  final rows = math.max(1, key.rows);
  final per = cols * rows;

  final folded = DrawerLayout.foldedKeys(prefs);
  final folderById = {for (final f in prefs.drawerFolders) f.id: f};

  DrawerItem? resolve(DrawerSlot s) {
    final k = s.componentKey;
    if (k != null) {
      final e = byKey[k];
      if (e == null || folded.contains(k)) return null;
      return AppDrawerItem(e);
    }
    final f = folderById[s.folderId];
    if (f == null) return null;
    return FolderDrawerItem(
      f,
      [
        for (final m in f.members)
          if (byKey[m] != null) byKey[m]!,
      ],
    );
  }

  final placed = <int, DrawerItem>{};
  final placedApps = <String>{};
  final placedFolders = <String>{};
  var lastFlat = DrawerSlots.reservedSlots - 1;

  for (final s in prefs.drawerSlots) {
    final flat = s.page * per + s.index;
    if (flat < DrawerSlots.reservedSlots) continue;
    final item = resolve(s);
    if (item == null) continue;
    placed[flat] = item;
    if (flat > lastFlat) lastFlat = flat;
    if (s.componentKey != null) placedApps.add(s.componentKey!);
    if (s.folderId != null) placedFolders.add(s.folderId!);
  }

  // Alive but unplaced: displayed appended, folders first, per the append-at-
  // end decision. Skipping occupied flats keeps this correct even if storage
  // somehow holds an entry past lastFlat with a gap before it.
  var next = lastFlat + 1;
  void append(DrawerItem item) {
    while (placed.containsKey(next)) {
      next++;
    }
    placed[next] = item;
    next++;
  }

  for (final f in DrawerLayout.orderedFolders(prefs)) {
    if (placedFolders.contains(f.id)) continue;
    append(FolderDrawerItem(
      f,
      [
        for (final m in f.members)
          if (byKey[m] != null) byKey[m]!,
      ],
    ));
  }
  for (final a in apps) {
    if (folded.contains(a.componentKey)) continue;
    if (placedApps.contains(a.componentKey)) continue;
    append(AppDrawerItem(a));
  }

  final maxFlat = placed.isEmpty
      ? DrawerSlots.reservedSlots
      : placed.keys.reduce(math.max);

  // Exactly as many pages as the contents occupy, PLUS any the user has grown
  // the drawer to with the "+" beside the page dots.
  //
  // This used to be `+ 2`, an unconditional trailing empty page, so that a
  // drag always had somewhere to land. It worked and it was wrong: the drawer
  // permanently ended on a blank screen nobody had asked for. Growing the
  // drawer is now an explicit act that is then remembered, which is how modern
  // launchers do it, and Clean up pages is what takes the empty pages back.
  final needed = (maxFlat ~/ per) + 1;
  final pageCount = math.max(needed, prefs.drawerPageCount ?? 0);

  final cells = List<DrawerItem?>.filled(pageCount * per, null);
  // `needed` is at least 1 and `per` at least 1, but a one-column one-row grid
  // would leave no room for the second reserved cell, so both writes below are
  // bounds-checked rather than assumed.
  // Bounds-checked rather than assumed: a one-column one-row grid leaves no
  // room for the second and third reserved cells.
  if (cells.isNotEmpty) cells[0] = const LauncherSettingsItem();
  if (cells.length > 1) cells[1] = const DeviceSettingsItem();
  if (cells.length > 2) cells[2] = TerminalDrawerItem(terminalLabelFor(theme));
  placed.forEach((flat, item) {
    if (flat < cells.length) cells[flat] = item;
  });

  return (cells: cells, cols: cols, rows: rows, pageCount: pageCount);
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
List<DrawerItem> launcherItemsMatching(
  String query, {
  String terminalLabel = TerminalDrawerItem.defaultTitle,
}) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const [];

  final all = <DrawerItem>[
    const LauncherSettingsItem(),
    const DeviceSettingsItem(),
    TerminalDrawerItem(terminalLabel),
  ];
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
    TerminalDrawerItem() => terminalAliases,
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

/// The words that should find the terminal.
///
/// The label already matches "terminal" on every theme that uses that word, and
/// several do not: a Kali user types "terminal", a KDE user might type
/// "konsole", and someone who lives in a shell types "sh" or "bash" without
/// thinking. All three should land in the same place.
const terminalAliases = <String>[
  'terminal',
  'konsole',
  'shell',
  'console',
  'command',
  'cmd',
  'bash',
  'tty',
  'ssh',
];
