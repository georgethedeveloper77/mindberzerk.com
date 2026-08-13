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

  /// Drop folder [sourceId] onto folder [targetId] → one folder holding both
  /// sets of members.
  ///
  /// **The target's name survives, and the source's is discarded.** Same rule as
  /// [mergeApps]: the target is the thing that stayed put, so it reads as the
  /// one that absorbed the other. Naming the result after the dragged folder
  /// would mean the folder under your finger renamed itself when something
  /// landed on it, which nobody expects.
  ///
  /// Member order is target-first, then the source's in its own order, with
  /// duplicates dropped. Duplicates should be impossible — an app lives in at
  /// most one folder — but a prefs file written by a newer build could contain
  /// them, and silently doubling an app inside a folder is the sort of bug that
  /// survives for months because it reads as a rendering glitch.
  ///
  /// Refuses to merge a folder into itself, and refuses when either id fails to
  /// resolve, returning [p] unchanged so the caller can compare by identity.
  static LauncherPrefs mergeFolders(
    LauncherPrefs p,
    String sourceId,
    String targetId,
  ) {
    if (sourceId == targetId) return p;

    final source = folder(p, sourceId);
    final target = folder(p, targetId);
    if (source == null || target == null) return p;

    final seen = <String>{};
    final members = <String>[
      for (final k in [...target.members, ...source.members])
        if (seen.add(k)) k,
    ];

    return p.copyWith(
      drawerFolders: [
        for (final x in p.drawerFolders)
          if (x.id == targetId)
            x.copyWith(members: members)
          // The source is DELETED, not emptied. An empty folder is a ghost;
          // `prune` would sweep it eventually, and doing it here means the
          // drawer never renders the intermediate state.
          else if (x.id != sourceId)
            x,
      ],
    );
  }

  /// Drop a folder onto a LOOSE app → the app joins the folder.
  ///
  /// The mirror of dropping an app onto a folder, and it resolves the same way
  /// on purpose: whichever direction you drag, a folder plus an app is that
  /// folder with one more app in it. The alternative — the folder somehow
  /// becoming a member of something — is the nested-folder mess the drawer
  /// deliberately does not have.
  static LauncherPrefs absorbApp(
    LauncherPrefs p,
    String folderId,
    String componentKey,
  ) =>
      addToFolder(p, folderId, componentKey);

  /// Move [sourceKey] to sit beside [targetKey] inside [folderId].
  ///
  /// ─── KEYS, NOT INDICES, AND THAT IS THE WHOLE DESIGN ────────────────────
  ///
  /// The obvious signature is `(from, to)` like [HomeLayout.reorderDock], whose
  /// own comment warns that `to` means "the index AFTER the item was removed"
  /// and that getting it wrong shifts every downward drag by one. That warning
  /// is real, but there is a worse problem here that an index signature cannot
  /// even express.
  ///
  /// The folder grid does not render `folder.members`. It renders the members
  /// that RESOLVED to an installed app, because a member whose app has been
  /// uninstalled has no icon and no label and is simply skipped. So the index
  /// of a tile on screen is not the index of that key in the stored list, and
  /// the two drift by exactly the number of dead members ahead of it. An index
  /// handed in from the grid would silently move the wrong app, and only for
  /// users who had uninstalled something, which is the kind of bug that never
  /// reproduces on the developer's phone.
  ///
  /// Keys have no such gap. Both ends are resolved against the stored list here,
  /// so a dead member simply sits where it is and everything else moves around
  /// it correctly.
  ///
  /// [after] is which SIDE of the target the drop landed on: false inserts
  /// before it, true after it. Computed from which half of the target tile the
  /// pointer was over, so the drop reads as "put it here" rather than as a
  /// swap.
  ///
  /// Refuses, returning [p] unchanged so the caller can compare by identity,
  /// when the folder is gone, when either key is not a member, or when source
  /// and target are the same app.
  static LauncherPrefs reorderMembers(
    LauncherPrefs p,
    String folderId,
    String sourceKey,
    String targetKey, {
    required bool after,
  }) {
    if (sourceKey == targetKey) return p;

    final f = folder(p, folderId);
    if (f == null) return p;
    if (!f.members.contains(sourceKey)) return p;
    if (!f.members.contains(targetKey)) return p;

    // Remove FIRST, then locate the target in the shortened list. This is the
    // off-by-one [HomeLayout.reorderDock] documents, dodged rather than
    // handled: once the source is gone there is only one list and one index,
    // so there is no "before or after removal" question left to get wrong.
    final next = [...f.members]..remove(sourceKey);
    final at = next.indexOf(targetKey);

    next.insert(after ? at + 1 : at, sourceKey);

    return p.copyWith(
      drawerFolders: [
        for (final x in p.drawerFolders)
          if (x.id == folderId) x.copyWith(members: next) else x,
      ],
    );
  }

  /// "Ungroup" — every member returns to the list at once.
  static LauncherPrefs dissolve(LauncherPrefs p, String folderId) =>
      p.copyWith(
        drawerFolders:
            p.drawerFolders.where((x) => x.id != folderId).toList(),
      );

  /// Ungroup EVERYTHING: every folder's members return to the list at once.
  ///
  /// The manual folder ORDER goes with them. An order over zero folders is not
  /// an arrangement, and leaving [LauncherPrefs.folderOrderCustom] set would
  /// start the next folder someone creates in "custom order" mode for no
  /// reason they chose. `clearing`, not `copyWith`, because copyWith cannot
  /// write null.
  ///
  /// No-folders returns [p] unchanged, same identity-comparable refusal the
  /// other mutations use.
  static LauncherPrefs dissolveAll(LauncherPrefs p) => p.drawerFolders.isEmpty
      ? p
      : p
          .copyWith(drawerFolders: const [])
          .clearing(folderOrderCustom: true);

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
