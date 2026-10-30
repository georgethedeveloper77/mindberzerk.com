import 'launcher_prefs.dart';

/// Every home-screen and folder mutation, as pure functions.
///
/// Pure on purpose: drag-and-drop is fiddly, folder merging is fiddlier, and
/// "I dragged an app onto a folder and lost it" is the kind of bug that makes
/// people uninstall a launcher and never come back. Pure functions mean all of
/// this is tested without a phone.
///
/// Widgets do gestures. This does state.
class HomeLayout {
  const HomeLayout._();

  /// Slot [index] on [page], or null if empty.
  static HomeItem? itemAt(LauncherPrefs p, int page, int index) {
    for (final i in p.homeItems) {
      if (i.page == page && i.index == index) return i;
    }
    return null;
  }

  static AppFolder? folder(LauncherPrefs p, String id) {
    for (final f in p.folders) {
      if (f.id == id) return f;
    }
    return null;
  }

  /// First free slot on [page], or null when the page is full.
  static int? firstFreeSlot(LauncherPrefs p, int page, int capacity) {
    final taken = {
      for (final i in p.homeItems)
        if (i.page == page) i.index,
    };
    for (var i = 0; i < capacity; i++) {
      if (!taken.contains(i)) return i;
    }
    return null;
  }

  /// Already on this page? Home should not silently hold the same app twice.
  static bool isOnHome(LauncherPrefs p, String componentKey) =>
      p.homeItems.any((i) => i.componentKey == componentKey);

  /// Where an app sits on the home screen, or null when it is not on one.
  ///
  /// Needed because a cross-surface drag knows WHAT it is holding but not where
  /// that thing was: the dock receives a component key, and taking the app off
  /// the desktop means finding the tile it left behind. [isOnHome] answers the
  /// same question with less of the answer.
  static HomeItem? slotOf(LauncherPrefs p, String componentKey) {
    for (final i in p.homeItems) {
      if (i.componentKey == componentKey) return i;
    }
    return null;
  }

  /// Last free slot on [page]: the bottom row first, left to right within it,
  /// then upward. Null when the page is full.
  ///
  /// ─── WHY A PINNED APP LANDS AT THE BOTTOM ───────────────────────────────
  ///
  /// [firstFreeSlot] put it in the top-left cell, which on a 6.1 inch phone is
  /// the one corner a thumb cannot reach without moving the hand. The desktop
  /// is not a list being filled from the start; it is a surface reached with
  /// one hand, and the row nearest the dock is the row nearest the thumb.
  ///
  /// Bottom-up rather than "skip the first two rows", which was the other way
  /// to say this. A fixed skip has to mean something on a three-row desktop and
  /// on a seven-row one, and it does not.
  ///
  /// LEFT TO RIGHT WITHIN THE ROW, not a plain reverse walk. Reversing the
  /// index would fill the bottom row right to left, so the first app pinned on
  /// a fresh desktop would sit in the bottom-RIGHT corner with three empty
  /// cells beside it, and the second would appear to its left. Apps would
  /// accumulate backwards, which no launcher does.
  static int? lastFreeSlot(
    LauncherPrefs p,
    int page,
    int capacity,
    int cols,
  ) {
    if (cols <= 0) return firstFreeSlot(p, page, capacity);

    final taken = {
      for (final i in p.homeItems)
        if (i.page == page) i.index,
    };

    // `ceil`, so a capacity that is not a whole number of rows still has its
    // last, partial row searched. The bounds check inside covers the cells that
    // row does not have.
    final rows = (capacity / cols).ceil();
    for (var r = rows - 1; r >= 0; r--) {
      for (var c = 0; c < cols; c++) {
        final i = r * cols + c;
        if (i >= capacity) continue;
        if (!taken.contains(i)) return i;
      }
    }
    return null;
  }

  /// Pin an app the user just asked for. Lands in the bottom row.
  ///
  /// `cols` is REQUIRED rather than optional with a fallback. An `int? cols`
  /// defaulting to the old top-left walk would compile at every call site and
  /// keep the old behaviour at whichever one was missed, which is the shape of
  /// failure this codebase keeps finding. Required means the compiler names
  /// them, and it did: `starter_home` and six tests.
  static LauncherPrefs addToHome(
    LauncherPrefs p,
    String componentKey, {
    int page = 0,
    required int capacity,
    required int cols,
  }) =>
      _place(
        p,
        componentKey,
        page,
        lastFreeSlot(p, page, capacity, cols),
      );

  /// Lay a starting desktop out, top-left first.
  ///
  /// ─── WHY THE SEED DOES NOT FILL THE WAY A PIN DOES ──────────────────────
  ///
  /// Thumb reach is the argument for [addToHome], and it is an argument about
  /// ONE app arriving on a desktop the user is already looking at. A starter
  /// block is laid out before anyone has touched anything, and every desktop
  /// this launcher imitates puts its starting icons in the top-left corner:
  /// Plasma's Folder View, Cinnamon, Deepin.
  ///
  /// It also has an order to keep. `StarterHome` walks an ALPHABETICAL list, so
  /// filling upward would read bottom-left, bottom-right, then up a row, which
  /// is not a reading order anybody has.
  ///
  /// ─── AND WHY THIS IS A SECOND FUNCTION RATHER THAN A FLAG ───────────────
  ///
  /// A `bool fromTop` on [addToHome] would put the decision at the call site,
  /// where it reads as a formatting preference rather than as two different
  /// events. These are named for what happened: a person pinned something, or a
  /// theme was applied for the first time. Both go through [_place], so the
  /// duplicate and full-page refusals cannot drift apart.
  static LauncherPrefs seedToHome(
    LauncherPrefs p,
    String componentKey, {
    int page = 0,
    required int capacity,
  }) =>
      _place(
        p,
        componentKey,
        page,
        firstFreeSlot(p, page, capacity),
      );

  /// The shared half: refuse a duplicate, refuse a full page, otherwise write.
  ///
  /// Returns `p` ITSELF on both refusals, not a copy. `StarterHome` counts
  /// placements with `identical(next, out)`, so a fresh object that happened to
  /// be equal would count as a placement and the starter would stop early.
  static LauncherPrefs _place(
    LauncherPrefs p,
    String componentKey,
    int page,
    int? slot,
  ) {
    if (isOnHome(p, componentKey)) return p;
    if (slot == null) return p; // page full; caller should say so

    return p.copyWith(
      homeItems: [
        ...p.homeItems,
        HomeItem(page: page, index: slot, componentKey: componentKey),
      ],
    );
  }

  /// Put an app on a SPECIFIC slot, falling back to the next free one.
  ///
  /// ─── WHY [addToHome] WAS NOT ENOUGH ────────────────────────────────────
  ///
  /// That one places at `lastFreeSlot`, which is right for "add this app to my
  /// home screen" from a menu, where the user named an app and not a place. A
  /// drop names a place: somebody dragging an icon from the dock onto the third
  /// slot of the second row means that slot, and putting it at the end of the
  /// page instead reads as the drag having been ignored.
  ///
  /// The requested slot is taken only if it is EMPTY. A cross-surface drop onto
  /// an occupied tile is not a merge: merging is a deliberate gesture between
  /// two icons already on the desktop, and an app arriving from the dock landing
  /// inside a folder the user was only dragging past is not recoverable by
  /// anything they can see.
  static LauncherPrefs placeAt(
    LauncherPrefs p,
    String componentKey, {
    required int page,
    required int index,
    required int capacity,
    required int cols,
  }) {
    final free = itemAt(p, page, index) == null;
    return _place(
      p,
      componentKey,
      page,
      free ? index : lastFreeSlot(p, page, capacity, cols),
    );
  }

  static LauncherPrefs removeFromHome(LauncherPrefs p, int page, int index) {
    return p.copyWith(
      homeItems: p.homeItems
          .where((i) => !(i.page == page && i.index == index))
          .toList(),
    );
  }

  /// Drag a home item to an empty slot. Occupied targets go to [mergeOrSwap].
  static LauncherPrefs move(
    LauncherPrefs p, {
    required int fromPage,
    required int fromIndex,
    required int toPage,
    required int toIndex,
  }) {
    final item = itemAt(p, fromPage, fromIndex);
    if (item == null) return p;
    if (itemAt(p, toPage, toIndex) != null) return p; // occupied — not our job

    return p.copyWith(
      homeItems: [
        for (final i in p.homeItems)
          if (i.page == fromPage && i.index == fromIndex)
            HomeItem(
              page: toPage,
              index: toIndex,
              componentKey: i.componentKey,
              folderId: i.folderId,
            )
          else
            i,
      ],
    );
  }

  /// Dropping one home item onto another.
  ///
  /// The classic launcher interaction, and there are three distinct cases —
  /// getting any of them wrong loses an app:
  ///   app  onto app    -> NEW folder containing both
  ///   app  onto folder -> app joins the folder
  ///   folder onto anything -> refuse. Nested folders are a mess nobody wants,
  ///                           and merging two folders silently is worse.
  static LauncherPrefs mergeOrSwap(
    LauncherPrefs p, {
    required int fromPage,
    required int fromIndex,
    required int toPage,
    required int toIndex,
    required String Function() newFolderId,
    String newFolderName = 'Folder',
  }) {
    final source = itemAt(p, fromPage, fromIndex);
    final target = itemAt(p, toPage, toIndex);
    if (source == null || target == null) return p;
    if (source.page == target.page && source.index == target.index) return p;

    // Refuse to drag a folder onto anything.
    if (source.isFolder) return p;

    final sourceKey = source.componentKey;
    if (sourceKey == null) return p;

    // app -> folder
    if (target.isFolder) {
      final f = folder(p, target.folderId!);
      if (f == null) return p;
      if (f.members.contains(sourceKey)) return p;

      return p.copyWith(
        folders: [
          for (final x in p.folders)
            if (x.id == f.id)
              x.copyWith(members: [...x.members, sourceKey])
            else
              x,
        ],
        // The app leaves its old slot — it lives in the folder now.
        homeItems: p.homeItems
            .where((i) => !(i.page == fromPage && i.index == fromIndex))
            .toList(),
      );
    }

    // app -> app: new folder, in the TARGET's slot. The target does not move,
    // which is what users expect: you dropped something onto it, so it stays.
    final targetKey = target.componentKey;
    if (targetKey == null) return p;

    final id = newFolderId();

    // The dragged app leaves home entirely — it lives in the folder now. Filter
    // it out first: a collection-for has no `continue`, and trying to skip an
    // element inline is what broke the build.
    final remaining =
        p.homeItems.where((i) => !(i.page == fromPage && i.index == fromIndex));

    return p.copyWith(
      folders: [
        ...p.folders,
        AppFolder(id: id, name: newFolderName, members: [targetKey, sourceKey]),
      ],
      homeItems: [
        for (final i in remaining)
          if (i.page == toPage && i.index == toIndex)
            // The folder takes the TARGET's slot. The target does not move —
            // you dropped something onto it, so it stays put.
            HomeItem(page: toPage, index: toIndex, folderId: id)
          else
            i,
      ],
    );
  }

  static LauncherPrefs renameFolder(LauncherPrefs p, String id, String name) {
    return p.copyWith(
      folders: [
        for (final f in p.folders)
          if (f.id == id) f.copyWith(name: name) else f,
      ],
    );
  }

  /// Give [id] an icon, or clear it back to the fallback with a null [glyph].
  ///
  /// The twin of `DrawerLayout.setGlyph`, writing to [LauncherPrefs.folders]
  /// instead of `drawerFolders`. The two are separate for the reason every
  /// other pair here is separate: same [AppFolder] type, two storage lists, and
  /// a single function taking a "which list" flag would be one line shorter and
  /// one bug deeper.
  ///
  /// Unlike [renameFolder] this normalises: a glyph that is whitespace is
  /// stored as null, because an id that trims to nothing can never resolve and
  /// keeping it would leave the picker showing a selection that draws the
  /// fallback.
  static LauncherPrefs setFolderGlyph(
    LauncherPrefs p,
    String id,
    String? glyph,
  ) {
    final trimmed = glyph?.trim();
    final next = (trimmed == null || trimmed.isEmpty) ? null : trimmed;

    return p.copyWith(
      folders: [
        for (final f in p.folders)
          if (f.id == id) f.copyWith(glyph: [next]) else f,
      ],
    );
  }

  /// Pulling the last-but-one app out must dissolve the folder. A folder holding
  /// one app is pointless UI, and one holding zero is a ghost that outlives
  /// every app in it.
  static LauncherPrefs removeFromFolder(
    LauncherPrefs p,
    String folderId,
    String componentKey, {
    required int capacity,
  }) {
    final f = folder(p, folderId);
    if (f == null) return p;

    final members = f.members.where((m) => m != componentKey).toList();

    if (members.length >= 2) {
      return p.copyWith(
        folders: [
          for (final x in p.folders)
            if (x.id == folderId) x.copyWith(members: members) else x,
        ],
      );
    }

    // A DOCK folder hands its dock slot to the survivor instead. Without this
    // the survivor would land on page 0 slot 0 over whatever sits there, and
    // the dock would keep a key pointing at a folder that no longer exists.
    final dockKey = dockFolderKey(folderId);
    if (p.favourites.contains(dockKey)) {
      return p.copyWith(
        folders: p.folders.where((x) => x.id != folderId).toList(),
        favourites: [
          for (final k in p.favourites)
            if (k != dockKey)
              k
            else if (members.isNotEmpty)
              members.first,
        ],
      );
    }

    // Dissolve. The folder's slot is inherited by whatever is left, so the
    // survivor does not vanish off the home screen.
    final slot = p.homeItems.firstWhere(
      (i) => i.folderId == folderId,
      orElse: () => const HomeItem(page: 0, index: 0),
    );

    final survivors = <HomeItem>[
      for (final i in p.homeItems)
        if (i.folderId != folderId) i,
      if (members.isNotEmpty)
        HomeItem(
          page: slot.page,
          index: slot.index,
          componentKey: members.first,
        ),
    ];

    return p.copyWith(
      folders: p.folders.where((x) => x.id != folderId).toList(),
      homeItems: survivors,
    );
  }

  /// Every app currently inside some HOME folder.
  ///
  /// The mirror of `DrawerLayout.foldedKeys`, and needed for the same reason:
  /// the Add-to-folder chooser must not offer an app that is already filed,
  /// because [addToFolder] declines to move one between folders and offering a
  /// choice that will be refused is worse than not offering it.
  ///
  /// Note what it does NOT exclude: an app sitting in a desktop slot is a fair
  /// candidate. Adding it frees that slot, which is what dragging it onto the
  /// folder would have done.
  static Set<String> foldedKeys(LauncherPrefs p) => {
        for (final f in p.folders) ...f.members,
      };

  /// The home folder holding [componentKey], or null when it is not in one.
  static AppFolder? folderOf(LauncherPrefs p, String componentKey) {
    for (final f in p.folders) {
      if (f.members.contains(componentKey)) return f;
    }
    return null;
  }

  /// File a loose app into an existing home folder.
  ///
  /// The chooser's half of [mergeOrSwap]: same outcome, reached by picking from
  /// a list rather than by dragging. It frees the app's desktop slot for the
  /// same reason that one does, since an app cannot be in a folder AND on the
  /// grid at once without the folder becoming a second copy of it.
  ///
  /// Refuses (returns [p] unchanged, so a caller can compare by identity) when
  /// the folder is gone, when the app is already in it, or when it is in
  /// another folder. That last refusal matches `DrawerLayout.addToFolder`: a
  /// move between folders is two decisions and the user should make both.
  static LauncherPrefs addToFolder(
    LauncherPrefs p,
    String folderId,
    String componentKey,
  ) {
    final f = folder(p, folderId);
    if (f == null) return p;
    if (f.members.contains(componentKey)) return p;
    if (folderOf(p, componentKey) != null) return p;

    return p.copyWith(
      folders: [
        for (final x in p.folders)
          if (x.id == folderId)
            x.copyWith(members: [...x.members, componentKey])
          else
            x,
      ],
      // The app leaves the grid; it lives in the folder now.
      homeItems:
          p.homeItems.where((i) => i.componentKey != componentKey).toList(),
    );
  }

  /// Move [sourceKey] to sit before or after [targetKey] inside a folder.
  ///
  /// The member order is what the folder's pages are built from, so this is the
  /// only thing that decides which apps share page one. Slot geometry does not
  /// enter into it: a folder is a list, even on a surface made of slots.
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

    final next = [...f.members]..remove(sourceKey);
    var at = next.indexOf(targetKey);
    if (at < 0) return p;
    if (after) at += 1;
    next.insert(at, sourceKey);

    return p.copyWith(
      folders: [
        for (final x in p.folders)
          if (x.id == folderId) x.copyWith(members: next) else x,
      ],
    );
  }

  /// How many slots [folderId] could return members to right now.
  ///
  /// Split out from [dissolve] so a caller can ASK before it acts. The folder
  /// overlay pops its route before writing, to get the exit animation rather
  /// than a blink, and a dissolve that then refused would leave the user
  /// looking at a folder they had just been told was ungrouped.
  ///
  /// The folder's own slot counts as free, because ungrouping frees it.
  static int dissolveRoom(
    LauncherPrefs p,
    String folderId, {
    required int capacity,
  }) {
    final f = folder(p, folderId);
    if (f == null) return 0;

    var page = 0;
    for (final i in p.homeItems) {
      if (i.folderId == folderId) {
        page = i.page;
        break;
      }
    }

    final taken = {
      for (final i in p.homeItems)
        if (i.page == page && i.folderId != folderId) i.index,
    };
    var free = 0;
    for (var i = 0; i < capacity; i++) {
      if (!taken.contains(i)) free++;
    }
    return free;
  }

  /// Ungroup: the folder goes, its members return to the desktop.
  ///
  /// ─── ALL OF THEM OR NONE OF THEM ────────────────────────────────────────
  ///
  /// The obvious implementation places what fits and drops the rest, on the
  /// reasoning that a dropped app is still installed and still in the drawer.
  /// That is exactly the shape of "I ungrouped a folder and lost three apps",
  /// which is the bug class this whole file is pure in order to rule out. The
  /// user cannot see the page's capacity and did not ask to make a choice
  /// about it.
  ///
  /// So a dissolve that would not fit is REFUSED WHOLE, returning [p] unchanged
  /// so the caller can compare by identity and say why. [dissolveRoom] lets it
  /// ask first.
  ///
  /// Placement starts at the folder's OWN slot and walks forward into whatever
  /// is free on that page, so the apps appear where the folder was rather than
  /// scattered to the end of the grid.
  static LauncherPrefs dissolve(
    LauncherPrefs p,
    String folderId, {
    required int capacity,
  }) {
    final f = folder(p, folderId);
    if (f == null) return p;
    if (f.members.length > dissolveRoom(p, folderId, capacity: capacity)) {
      return p;
    }

    var page = 0;
    var start = 0;
    for (final i in p.homeItems) {
      if (i.folderId == folderId) {
        page = i.page;
        start = i.index;
        break;
      }
    }

    // The folder's own tile goes first, so its slot is free for the members.
    final kept = [
      for (final i in p.homeItems)
        if (i.folderId != folderId) i,
    ];

    final taken = {
      for (final i in kept)
        if (i.page == page) i.index,
    };

    final placed = <HomeItem>[];
    var slot = start;
    for (final m in f.members) {
      while (slot < capacity && taken.contains(slot)) {
        slot++;
      }
      // Unreachable given the room check above. A break rather than an assert,
      // because if the count is ever wrong, placing fewer beats crashing on a
      // desktop the user is looking at.
      if (slot >= capacity) break;
      taken.add(slot);
      placed.add(HomeItem(page: page, index: slot, componentKey: m));
    }

    return p.copyWith(
      folders: p.folders.where((x) => x.id != folderId).toList(),
      homeItems: [...kept, ...placed],
      // Ungrouping a DOCK folder sends its members to the grid: a dock of four
      // cannot take a folder of nine back as loose apps.
      favourites: p.favourites
          .where((k) => k != dockFolderKey(folderId))
          .toList(),
    );
  }

  /// Apps that vanished (uninstalled) must not linger as dead slots or ghost
  /// folder members. Call this whenever the app list changes.
  static LauncherPrefs prune(LauncherPrefs p, Set<String> liveKeys) {
    final folders = [
      for (final f in p.folders)
        f.copyWith(members: f.members.where(liveKeys.contains).toList()),
    ];

    final aliveFolderIds = {
      for (final f in folders)
        if (f.members.length >= 2) f.id,
    };

    return p.copyWith(
      folders: folders.where((f) => aliveFolderIds.contains(f.id)).toList(),
      homeItems: p.homeItems.where((i) {
        if (i.isFolder) return aliveFolderIds.contains(i.folderId);
        return liveKeys.contains(i.componentKey);
      }).toList(),
      // A dock folder is kept while it is alive, and a folder left with ONE
      // app hands its slot to that app, the same rule `removeFromFolder`
      // applies when the user takes the second-to-last one out.
      favourites: _pruneDock(p.favourites, folders, aliveFolderIds, liveKeys),
      // An exclusion is a decision about an app. When the app goes, so does the
      // decision: keeping it would mean reinstalling something months later and
      // finding it silently refused a dock slot for a reason nothing can show.
      dockExcluded: p.dockExcluded.where(liveKeys.contains).toSet(),
    );
  }

  // ─── DOCK ──────────────────────────────────────────────────────────────────
  //
  // The dock is `favourites`. The field already existed ("componentKeys, dock
  // order"), already serialises, and `prune()` above already cleans it — no
  // migration, no schema bump.
  //
  // Pure, same as the folder rules, for the same reason with higher stakes: the
  // dock is now the ONLY app surface on the home screen (authentic decision).
  // "I pinned an app and it vanished" is the folder bug, but on the one surface
  // the user cannot avoid.

  static bool isPinned(LauncherPrefs p, String componentKey) =>
      p.favourites.contains(componentKey);

  /// Appends. Refuses duplicates and refuses to exceed [capacity].
  ///
  /// Refusal returns [p] unchanged — the caller compares identity and tells the
  /// user ("Dock is full"). A silently dropped pin is worse than a refused one.
  static LauncherPrefs pinToDock(
    LauncherPrefs p,
    String componentKey, {
    required int capacity,
  }) {
    if (isPinned(p, componentKey)) return p;
    if (p.favourites.length >= capacity) return p;
    return p.copyWith(favourites: [...p.favourites, componentKey]);
  }

  /// Move [sourceKey] to sit beside [targetKey] in the dock.
  ///
  /// ─── WHY THIS EXISTS BESIDE [reorderDock] AND NOT INSTEAD OF IT ─────────
  ///
  /// [reorderDock] takes indices, and its own comment explains the trap: `to`
  /// means the index AFTER the item was removed, and getting it wrong shifts
  /// every downward drag by one. That warning is correct and it is not the
  /// worst of it.
  ///
  /// The dock does not render `favourites`. It renders [dockKeys], which drops
  /// any pin whose app is no longer installed, and truncates to the capacity
  /// the CURRENT dock side can hold. So a slot's index on screen is not that
  /// key's index in `favourites`, and the two drift by however many dead or
  /// overflowed pins sit ahead of it. An index measured from the dock would
  /// move a different app, and only for users who have uninstalled a pinned app
  /// or moved their dock to a shorter edge.
  ///
  /// Keys have no such gap: both ends resolve against `favourites` here, so an
  /// unrendered pin stays where it is and everything else moves around it.
  ///
  /// [after] is which side of the target the drop landed on, from which half of
  /// the target slot the pointer was over.
  ///
  /// Refuses, returning [p] unchanged, when either key is not pinned or the two
  /// are the same. A dock in frequent-apps mode (empty `favourites`) therefore
  /// refuses everything, which is correct: there is no arrangement to change,
  /// and silently converting the dock to pinned mode because someone dragged
  /// inside it would take away the auto-fill they never opted out of.
  static LauncherPrefs reorderDockKeys(
    LauncherPrefs p,
    String sourceKey,
    String targetKey, {
    required bool after,
  }) {
    if (sourceKey == targetKey) return p;
    if (!isPinned(p, sourceKey) || !isPinned(p, targetKey)) return p;

    // Remove first, then locate. Once the source is gone there is one list and
    // one index, so the "before or after removal" question [reorderDock]
    // documents has nowhere left to go wrong.
    final next = [...p.favourites]..remove(sourceKey);
    final at = next.indexOf(targetKey);

    next.insert(after ? at + 1 : at, sourceKey);
    return p.copyWith(favourites: next);
  }

  /// Unpinning the LAST app returns the dock to frequent-apps mode rather than
  /// leaving it empty — that falls out of [dockKeys] treating an empty
  /// `favourites` as "untouched". So there is nothing special to do here, and
  /// the user cannot strand themselves with no way to launch anything.
  static LauncherPrefs unpinFromDock(LauncherPrefs p, String componentKey) =>
      p.copyWith(
        favourites: p.favourites.where((k) => k != componentKey).toList(),
      );

  /// Take an app OUT of the auto-filled dock.
  ///
  /// ─── WHY THIS IS NOT unpinFromDock ──────────────────────────────────────
  ///
  /// Those are opposite operations on different modes. Unpinning removes a
  /// choice the user made; this records one they had not been able to make. An
  /// app in the auto dock is there because they use it, so removing it from
  /// `favourites` is a no-op: it was never in there.
  ///
  /// Idempotent, and safe on a pinned app even though nothing offers it there:
  /// the set is only read on the frequent path, so an entry for a pinned app
  /// simply never comes up.
  static LauncherPrefs excludeFromDock(LauncherPrefs p, String componentKey) =>
      p.copyWith(dockExcluded: {...p.dockExcluded, componentKey});

  /// Put one back, or all of them when [componentKey] is null.
  ///
  /// It does not reappear immediately unless it is still frequent enough to
  /// make the cut, which is correct: this restores its ELIGIBILITY rather than
  /// its slot, and a dock that promotes an app you barely use because you once
  /// un-removed it would be the haunted behaviour `dockKeys` warns about.
  static LauncherPrefs restoreToDock(LauncherPrefs p, [String? componentKey]) =>
      componentKey == null
          ? p.copyWith(dockExcluded: const {})
          : p.copyWith(
              dockExcluded: {
                for (final k in p.dockExcluded)
                  if (k != componentKey) k,
              },
            );

  /// Drag-reorder within the dock. [to] is the index in the list AFTER the item
  /// has been removed — the ReorderableListView convention. Getting that wrong
  /// shifts every downward drag by one, which reads as "the dock ignores me".
  static LauncherPrefs reorderDock(LauncherPrefs p, int from, int to) {
    if (from < 0 || from >= p.favourites.length) return p;

    final next = [...p.favourites];
    final key = next.removeAt(from);
    next.insert(to.clamp(0, next.length), key);

    return p.copyWith(favourites: next);
  }

  /// What the dock shows.
  ///
  /// **The user pinned nothing → their most-used apps, capped at [defaultLimit]
  /// (four, out of the box). The user pinned ANYTHING → the dock is theirs,
  /// entirely, up to [capacity], and stops moving on its own.**
  ///
  /// Deliberately not a hybrid. Pins-plus-autofill feels haunted: you pin two
  /// apps, four you never chose appear beside them, and one silently swaps out
  /// next week when your usage shifts. Pinning one app means "I am arranging
  /// this now" — the same contract as HomeGrid's seed layout.
  ///
  /// [defaultLimit] bounds ONLY the auto-filled (unpinned) set — the "four
  /// bigger apps" out-of-box look. Pins are bounded by [capacity], because a
  /// deliberately-pinned dock is the user's to fill. Omit [defaultLimit] and the
  /// default set falls back to [capacity], i.e. the old behaviour.
  static List<String> dockKeys(
    LauncherPrefs p, {
    required List<String> frequent,
    required int capacity,
    int? defaultLimit,
  }) {
    // Pins fill the whole dock: the user asked for these, up to what fits.
    if (p.favourites.isNotEmpty) {
      return p.favourites.take(capacity).toList();
    }
    // The auto-filled (unpinned) dock is a small, deliberate set — four by
    // default — not "every frequent app that fits". Never more than `capacity`.
    final limit = (defaultLimit ?? capacity).clamp(0, capacity);

    // ── EXCLUSIONS APPLY BEFORE THE LIMIT, NOT AFTER ────────────────────
    //
    // Taking four and then dropping the removed one would leave a dock of
    // three with a gap the filler had a candidate for, and the gap would
    // reappear every time the user removed another. Filtering first means the
    // next most-used app moves up, which is what "removed from the dock"
    // has to mean on a surface that refills itself.
    //
    // Only reachable here, on the frequent path. Pinned mode returned above.
    return [
      for (final k in frequent)
        if (!p.dockExcluded.contains(k)) k,
    ].take(limit).toList();
  }

  // ─── DOCK FOLDERS AND POSITIONED PINS ──────────────────────────────────────
  //
  // A dock folder is an ordinary [AppFolder] in `folders` whose place is a
  // `favourites` entry instead of a [HomeItem]. The entry is
  // `folder:<id>`: Android package names are `[A-Za-z0-9_.]` and a component
  // key is `package/class`, so a colon can never begin a real one. Every
  // folder operation above (rename, reorder, remove, dissolve) works on it
  // unchanged, because they all address the folder by id.

  /// What marks a `favourites` entry as a folder.
  static const dockFolderPrefix = 'folder:';

  /// The `favourites` entry for folder [folderId].
  static String dockFolderKey(String folderId) => '$dockFolderPrefix$folderId';

  /// The folder id behind a `favourites` entry, or null for an app.
  static String? dockFolderIdOf(String dockKey) =>
      dockKey.startsWith(dockFolderPrefix)
          ? dockKey.substring(dockFolderPrefix.length)
          : null;

  static String? _soleMember(List<AppFolder> folders, String id) {
    for (final f in folders) {
      if (f.id == id) return f.members.length == 1 ? f.members.first : null;
    }
    return null;
  }

  /// `prune`'s dock half: apps must still be installed, folders must still
  /// be alive, and a folder down to one app becomes that app.
  static List<String> _pruneDock(
    List<String> favourites,
    List<AppFolder> folders,
    Set<String> aliveFolderIds,
    Set<String> liveKeys,
  ) {
    final out = <String>[];
    for (final k in favourites) {
      final id = dockFolderIdOf(k);
      if (id == null) {
        if (liveKeys.contains(k)) out.add(k);
      } else if (aliveFolderIds.contains(id)) {
        out.add(k);
      } else {
        final only = _soleMember(folders, id);
        if (only != null && !out.contains(only)) out.add(only);
      }
    }
    return out;
  }

  /// Make the dock's current arrangement explicit, once.
  ///
  /// A dock that is still auto-filling has an empty `favourites`, and a drop
  /// that opened a gap BETWEEN two of its apps has to land between those two
  /// apps. Pinning only the dropped one would collapse the dock to a single
  /// icon, which is not what the gap promised. So the visible apps become the
  /// pins first. Returns [p] unchanged when the dock is already pinned.
  static LauncherPrefs adoptDock(LauncherPrefs p, List<String> visible) =>
      p.favourites.isNotEmpty || visible.isEmpty
          ? p
          : p.copyWith(favourites: [...visible]);

  /// Put [dockKey] in the dock just before [beforeKey], or just after
  /// [afterKey], or at the end when both are null.
  ///
  /// Keys rather than an index, for the reason [reorderDockKeys] gives: the
  /// dock draws a filtered, truncated view of `favourites`, so a position
  /// measured on screen is not an index into the list.
  ///
  /// Already pinned means MOVE, and a move never counts against [capacity].
  /// A new arrival on a full dock is refused by returning [p] unchanged, so
  /// the caller can compare identity and say the dock is full.
  static LauncherPrefs pinToDockAt(
    LauncherPrefs p,
    String dockKey, {
    String? beforeKey,
    String? afterKey,
    required int capacity,
  }) {
    final moving = p.favourites.contains(dockKey);
    if (!moving && p.favourites.length >= capacity) return p;

    final next = [...p.favourites]..remove(dockKey);
    var at = next.length;
    if (beforeKey != null && next.contains(beforeKey)) {
      at = next.indexOf(beforeKey);
    } else if (afterKey != null && next.contains(afterKey)) {
      at = next.indexOf(afterKey) + 1;
    }
    next.insert(at, dockKey);
    return p.copyWith(favourites: next);
  }

  /// Take whatever [dockKey] names off the home grid: an app's tile, or a
  /// folder's. The second half of a grid-to-dock move.
  static LauncherPrefs takeOffHome(LauncherPrefs p, String dockKey) {
    final folderId = dockFolderIdOf(dockKey);
    return p.copyWith(
      homeItems: [
        for (final i in p.homeItems)
          if (folderId != null
              ? i.folderId != folderId
              : i.componentKey != dockKey)
            i,
      ],
    );
  }

  /// Drop app [dropKey] onto dock entry [ontoKey]: into it when it is a
  /// folder, otherwise a new folder takes [ontoKey]'s slot.
  ///
  /// The dropped app leaves wherever it was (dock, grid). Refuses, returning
  /// [p] unchanged, when [ontoKey] is not in the dock, when the two are the
  /// same, when [dropKey] is a folder (no folders inside folders), or when
  /// [dropKey] is already filed in some folder.
  static LauncherPrefs dockFolder(
    LauncherPrefs p, {
    required String ontoKey,
    required String dropKey,
    required String Function() newFolderId,
    String newFolderName = 'Folder',
  }) {
    if (ontoKey == dropKey) return p;
    if (!p.favourites.contains(ontoKey)) return p;
    if (dockFolderIdOf(dropKey) != null) return p;
    if (folderOf(p, dropKey) != null) return p;

    final cleared = takeOffHome(
      p.copyWith(favourites: [...p.favourites]..remove(dropKey)),
      dropKey,
    );

    final ontoFolder = dockFolderIdOf(ontoKey);
    if (ontoFolder != null) {
      if (folder(cleared, ontoFolder) == null) return p;
      return cleared.copyWith(
        folders: [
          for (final x in cleared.folders)
            if (x.id == ontoFolder)
              x.copyWith(members: [...x.members, dropKey])
            else
              x,
        ],
      );
    }

    final id = newFolderId();
    return cleared.copyWith(
      folders: [
        ...cleared.folders,
        AppFolder(id: id, name: newFolderName, members: [ontoKey, dropKey]),
      ],
      favourites: [
        for (final k in cleared.favourites)
          if (k == ontoKey) dockFolderKey(id) else k,
      ],
    );
  }

  /// Put folder [folderId] on the grid at [index] of [page], or the nearest
  /// free slot when that one is taken, and take it out of the dock.
  ///
  /// [placeAt] for a folder. Refuses when the page is full.
  static LauncherPrefs placeFolderAt(
    LauncherPrefs p,
    String folderId, {
    required int page,
    required int index,
    required int capacity,
    required int cols,
  }) {
    if (folder(p, folderId) == null) return p;
    if (p.homeItems.any((i) => i.folderId == folderId)) return p;
    final slot = itemAt(p, page, index) == null
        ? index
        : lastFreeSlot(p, page, capacity, cols);
    if (slot == null) return p;
    return p.copyWith(
      homeItems: [
        ...p.homeItems,
        HomeItem(page: page, index: slot, folderId: folderId),
      ],
      favourites: p.favourites
          .where((k) => k != dockFolderKey(folderId))
          .toList(),
    );
  }

  /// The first seed: pin one app per resolved role, in role order.
  ///
  /// [packages] is the platform's answer per role (null where nothing handles
  /// it). [keyByPackage] maps a package to the component key the dock should
  /// launch, already filtered to visible, non-hidden apps. Duplicates are
  /// dropped, so a phone whose dialer also handles SMS pins it once.
  ///
  /// Marks the seed done either way. A user who already pinned something
  /// keeps their dock untouched.
  static LauncherPrefs seedDock(
    LauncherPrefs p, {
    required List<String?> packages,
    required Map<String, String> keyByPackage,
    required int capacity,
  }) {
    if (p.dockInitialized) return p;
    if (p.favourites.isNotEmpty) return p.copyWith(dockInitialized: true);

    final keys = <String>[];
    for (final pkg in packages) {
      final key = pkg == null ? null : keyByPackage[pkg];
      if (key == null || keys.contains(key)) continue;
      if (keys.length >= capacity) break;
      keys.add(key);
    }
    return p.copyWith(favourites: keys, dockInitialized: true);
  }
}
