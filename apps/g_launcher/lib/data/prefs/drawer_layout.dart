import 'launcher_prefs.dart';

/// Every drawer-folder mutation, as pure functions.
///
/// Pure for the same reason [HomeLayout] is: "I merged two apps and one
/// vanished" is the bug that makes people uninstall a launcher, and it should be
/// provable without a phone.
///
/// **Why this is not [HomeLayout].** Home folders live in SLOTS — every mutation
/// there is about `page`/`index`, and dissolving a folder has to hand its slot to
/// the survivor so the app doesn't fall off the screen. The drawer has no slots:
/// it is one alphabetical list, and an app that leaves a folder simply reappears
/// in the list under its own name. Reusing the slot-based functions here would
/// drag home-screen geometry into a surface that has none. Same [AppFolder] type,
/// separate rules, separate storage ([LauncherPrefs.drawerFolders]).
///
/// The invariant, everywhere below: **a folder holds two or more apps.** One is
/// pointless UI, zero is a ghost. Any operation that would drop a folder under
/// two members dissolves it instead, and the leftover app returns to the list.
class DrawerLayout {
  const DrawerLayout._();

  /// The folder containing [componentKey], or null when the app is loose.
  static AppFolder? folderOf(LauncherPrefs p, String componentKey) {
    for (final f in p.drawerFolders) {
      if (f.members.contains(componentKey)) return f;
    }
    return null;
  }

  static AppFolder? folder(LauncherPrefs p, String id) {
    for (final f in p.drawerFolders) {
      if (f.id == id) return f;
    }
    return null;
  }

  /// Every app currently inside some folder. The drawer hides these from the
  /// flat list — they are reachable by opening their folder.
  static Set<String> foldedKeys(LauncherPrefs p) => {
        for (final f in p.drawerFolders) ...f.members,
      };

  /// Drop app [sourceKey] onto app [targetKey] → a new folder holding both.
  ///
  /// Refuses to fold an app onto itself, and refuses when either app is already
  /// in a folder (drag it out first). Refusal returns [p] unchanged so the caller
  /// can compare by identity and say something, rather than silently doing
  /// nothing.
  static LauncherPrefs mergeApps(
    LauncherPrefs p,
    String sourceKey,
    String targetKey, {
    required String Function() newFolderId,
    String newFolderName = 'Folder',
  }) {
    if (sourceKey == targetKey) return p;
    if (folderOf(p, sourceKey) != null) return p;
    if (folderOf(p, targetKey) != null) return p;

    // Target first: it is the app that stayed put, so it reads as the folder's
    // first member the way the user built it.
    return p.copyWith(
      drawerFolders: [
        ...p.drawerFolders,
        AppFolder(
          id: newFolderId(),
          name: newFolderName,
          members: [targetKey, sourceKey],
        ),
      ],
    );
  }

  /// Drop a loose app onto an existing folder.
  static LauncherPrefs addToFolder(
    LauncherPrefs p,
    String folderId,
    String componentKey,
  ) {
    final f = folder(p, folderId);
    if (f == null) return p;
    if (f.members.contains(componentKey)) return p;
    // Already filed elsewhere: the caller should pull it out first. Silently
    // moving it between folders is a surprise.
    if (folderOf(p, componentKey) != null) return p;

    return p.copyWith(
      drawerFolders: [
        for (final x in p.drawerFolders)
          if (x.id == folderId)
            x.copyWith(members: [...x.members, componentKey])
          else
            x,
      ],
    );
  }

  /// Take an app back out. Dropping to one member dissolves the folder, and both
  /// apps return to the alphabetical list.
  static LauncherPrefs removeFromFolder(
    LauncherPrefs p,
    String folderId,
    String componentKey,
  ) {
    final f = folder(p, folderId);
    if (f == null) return p;
    if (!f.members.contains(componentKey)) return p;

    final members = f.members.where((m) => m != componentKey).toList();

    if (members.length >= 2) {
      return p.copyWith(
        drawerFolders: [
          for (final x in p.drawerFolders)
            if (x.id == folderId) x.copyWith(members: members) else x,
        ],
      );
    }

    // Dissolve. Nothing to re-home: the survivor is simply no longer folded, so
    // the drawer's flat list picks it up again on the next build.
    return p.copyWith(
      drawerFolders: p.drawerFolders.where((x) => x.id != folderId).toList(),
    );
  }

  /// "Ungroup" — every member returns to the list at once.
  static LauncherPrefs dissolve(LauncherPrefs p, String folderId) =>
      p.copyWith(
        drawerFolders:
            p.drawerFolders.where((x) => x.id != folderId).toList(),
      );

  /// Rename. A blank name is refused rather than stored: an unnamed folder in an
  /// alphabetical list has nowhere to sort and nothing to tap.
  static LauncherPrefs rename(LauncherPrefs p, String folderId, String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return p;

    return p.copyWith(
      drawerFolders: [
        for (final x in p.drawerFolders)
          if (x.id == folderId) x.copyWith(name: trimmed) else x,
      ],
    );
  }

  /// Folders in display order.
  ///
  /// Alphabetical until the user drags one, then their arrangement wins. Sorting
  /// forever would mean a rename silently re-shuffles a hand-made order; never
  /// sorting would mean new folders pile up at the end in creation order, which
  /// nobody can predict. The flag is what lets both be true at the right time.
  static List<AppFolder> orderedFolders(LauncherPrefs p) {
    if (p.folderOrderCustom == true) return p.drawerFolders;
    return [...p.drawerFolders]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  /// Drag-reorder. [to] is the index AFTER the item has been removed — the
  /// ReorderableListView convention. Getting that wrong shifts every downward
  /// drag by one, which reads as "the list ignores me".
  ///
  /// Reordering from the alphabetical view has to bake that view in first,
  /// otherwise the very first drag is computed against indices the user was not
  /// looking at.
  static LauncherPrefs reorderFolders(LauncherPrefs p, int from, int to) {
    final current = orderedFolders(p);
    if (from < 0 || from >= current.length) return p;

    final next = [...current];
    final moved = next.removeAt(from);
    next.insert(to.clamp(0, next.length), moved);

    return p.copyWith(drawerFolders: next, folderOrderCustom: true);
  }

  /// Back to A-to-Z, discarding the manual arrangement.
  static LauncherPrefs resetFolderOrder(LauncherPrefs p) =>
      p.folderOrderCustom != true
          ? p
          : p.copyWith(
              drawerFolders: orderedFolders(
                p.copyWith(folderOrderCustom: false),
              ),
            ).clearing(folderOrderCustom: true);

  /// Uninstalled apps must not haunt folders, and a folder emptied down to one
  /// survivor by an uninstall dissolves like any other. Call alongside
  /// [HomeLayout.prune] whenever the app list changes.
  static LauncherPrefs prune(LauncherPrefs p, Set<String> liveKeys) {
    final folders = [
      for (final f in p.drawerFolders)
        f.copyWith(members: f.members.where(liveKeys.contains).toList()),
    ];

    return p.copyWith(
      drawerFolders: folders.where((f) => f.members.length >= 2).toList(),
    );
  }
}
