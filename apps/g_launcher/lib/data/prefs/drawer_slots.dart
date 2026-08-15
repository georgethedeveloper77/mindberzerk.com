import 'dart:math' as math;

import 'drawer_layout.dart';
import 'launcher_prefs.dart';

/// Every CUSTOM-ORDER drawer mutation, as pure functions.
///
/// Pure for the same reason [HomeLayout] and [DrawerLayout] are: "I dragged an
/// app and it vanished" is the bug that makes people uninstall a launcher, and
/// it should be provable without a phone.
///
/// ─── THE MODEL: SPARSE SLOTS, ONE UI STYLE ─────────────────────────────────
///
/// Custom order is a sparse assignment of drawer entries (apps AND folders,
/// interleaved) to (page, index) slots against a grid whose size is FROZEN
/// when Custom is entered: `drawerSlotCols` x `drawerSlotRows`, snapshotted
/// from whatever the drawer was rendering at that moment. Gaps are legal and
/// deliberate; "Clean up pages" is the operation that removes them. The grid
/// must be frozen because a sparse position is meaningless against a capacity
/// that reflows with screen width, which is precisely why the responsive
/// column count does not apply while in Custom.
///
/// ─── RESERVED SLOTS ────────────────────────────────────────────────────────
///
/// Flat slots 0, 1 and 2 (page 0, indices 0 to 2) belong to the launcher's own
/// entries, G Launcher Settings, Device Settings and the Terminal, in every
/// mode. They are not stored, not draggable and not drop targets; every
/// function here starts counting at [reservedSlots]. Burying the launcher's
/// settings mid-grid is the bug the pinned block fixed, and Custom does not get
/// to reintroduce it.
///
/// ─── THE COUNT WENT FROM TWO TO THREE, AND THAT MOVED PEOPLE'S APPS ────────
///
/// A stored slot is a flat position, so raising [reservedSlots] means whatever
/// sat at flat 2 is now inside the reserved block and would be skipped by every
/// renderer: present in storage, absent from the screen. That is the worst
/// outcome available, because nothing fails and an app simply disappears.
///
/// [migrateReserved] handles it, and it is SELF DETECTING rather than versioned:
/// an arrangement that predates the change is exactly one that still has a
/// stored slot below [reservedSlots]. Re-packing removes that condition, so the
/// migration runs once and is idempotent afterwards with no flag to persist and
/// no version number to get wrong.
///
/// Order survives, gaps do not, which is the same trade [reflow] already makes
/// and for the same reason: a gap's cell no longer means what it meant.
///
/// ─── TOLERANT BY DESIGN ────────────────────────────────────────────────────
///
/// An entry can reference an app that was since uninstalled or folded into a
/// folder, or a folder that was dissolved. Renderers FILTER those rather than
/// this file deleting them eagerly; storage is swept by [cleanUp] and by
/// [prune]. A dragged item that has no stored slot yet (a fresh install shown
/// appended, a folder member just pulled loose) is CREATED at its destination
/// rather than refused, so the first drag of a new app works like every other
/// drag.
class DrawerSlots {
  const DrawerSlots._();

  /// Flat slots below this are the launcher's own entries. See the class note.
  ///
  /// RAISING THIS IS A DATA MIGRATION. See [migrateReserved].
  static const int reservedSlots = 3;

  /// The frozen per-page capacity, floored at 1 so a corrupt prefs file can
  /// divide nothing by zero on the home screen.
  static int capacity(LauncherPrefs p) =>
      math.max(1, (p.drawerSlotCols ?? 4)) *
      math.max(1, (p.drawerSlotRows ?? 5));

  static int flatOf(LauncherPrefs p, int page, int index) =>
      page * capacity(p) + index;

  /// The stored entry at (page, index), or null when the slot is a gap.
  static DrawerSlot? entryAt(LauncherPrefs p, int page, int index) {
    for (final s in p.drawerSlots) {
      if (s.page == page && s.index == index) return s;
    }
    return null;
  }

  /// The highest occupied flat slot, or [reservedSlots] - 1 when nothing is
  /// stored, so "append after the last thing" degrades to "start at the top".
  static int lastOccupiedFlat(LauncherPrefs p) {
    var last = reservedSlots - 1;
    for (final s in p.drawerSlots) {
      final f = flatOf(p, s.page, s.index);
      if (f > last) last = f;
    }
    return last;
  }

  /// Lay the given display order into dense slots and enter Custom.
  ///
  /// Called ONCE, when the user first picks Custom order with nothing stored:
  /// folders first, then apps, exactly the order the drawer was showing, so
  /// entering Custom changes nothing on screen until the first drag. Also the
  /// moment the grid freezes: [cols] and [rows] are whatever the drawer was
  /// rendering, and they stay authoritative until the slots are reset.
  static LauncherPrefs seed(
    LauncherPrefs p, {
    required List<String> folderIds,
    required List<String> appKeys,
    required int cols,
    required int rows,
  }) {
    final safeCols = math.max(1, cols);
    final safeRows = math.max(1, rows);
    final per = safeCols * safeRows;

    final slots = <DrawerSlot>[];
    var flat = reservedSlots;
    void place({String? componentKey, String? folderId}) {
      slots.add(DrawerSlot(
        page: flat ~/ per,
        index: flat % per,
        componentKey: componentKey,
        folderId: folderId,
      ));
      flat++;
    }

    for (final id in folderIds) {
      place(folderId: id);
    }
    for (final k in appKeys) {
      place(componentKey: k);
    }

    return p.copyWith(
      drawerSortMode: 'custom',
      drawerSlots: slots,
      drawerSlotCols: safeCols,
      drawerSlotRows: safeRows,
    );
  }

  /// Move the dragged entry to a FREE slot, leaving a gap where it was.
  ///
  /// The dragged entry is identified by id, never by source coordinates: an
  /// item the provider merely DISPLAYED appended (a new install not yet
  /// stored) has no source slot, and it is simply created at the destination.
  /// A destination that turns out occupied, or reserved, refuses by returning
  /// [p] unchanged; occupied targets are the tiles' business, not this
  /// function's.
  static LauncherPrefs moveToFree(
    LauncherPrefs p, {
    String? componentKey,
    String? folderId,
    required int toPage,
    required int toIndex,
  }) {
    if (componentKey == null && folderId == null) return p;
    if (flatOf(p, toPage, toIndex) < reservedSlots) return p;
    if (entryAt(p, toPage, toIndex) != null) return p;

    final remaining = _without(p.drawerSlots, componentKey, folderId);
    return p.copyWith(
      drawerSlots: [
        ...remaining,
        DrawerSlot(
          page: toPage,
          index: toIndex,
          componentKey: componentKey,
          folderId: folderId,
        ),
      ],
    );
  }

  /// Insert the dragged entry BEFORE or AFTER the entry at the target slot,
  /// shifting contents ALONG THE OCCUPIED SLOTS.
  ///
  /// The set of occupied slot positions is (almost) preserved: items rotate
  /// through the existing positions between source and destination, so the
  /// gaps the user carved stay exactly where they were. That is the whole
  /// reason this is not "shift everything after by one", which would swallow a
  /// gap on every insert. When the dragged entry was not stored (a displayed
  /// append), one new position is added after the last occupied slot to make
  /// room, which is the same place it was being displayed.
  ///
  /// A target slot holding nothing stored (dropping on the edge of a
  /// displayed-but-unstored tile) falls back to appending the dragged entry
  /// after the last occupied slot. Rare, honest, and never loses the item.
  static LauncherPrefs insertNear(
    LauncherPrefs p, {
    String? componentKey,
    String? folderId,
    required int targetPage,
    required int targetIndex,
    required bool after,
  }) {
    if (componentKey == null && folderId == null) return p;

    final dragged = DrawerSlot(
      page: 0,
      index: 0,
      componentKey: componentKey,
      folderId: folderId,
    );

    final stored = [...p.drawerSlots]..sort(
        (a, b) => flatOf(p, a.page, a.index).compareTo(
              flatOf(p, b.page, b.index),
            ),
      );

    final hadDragged =
        stored.any((s) => _sameIdentity(s, componentKey, folderId));

    // Every occupied position, in order, INCLUDING the dragged entry's own:
    // the sequence rotates through them.
    final positions = <int>[
      for (final s in stored) flatOf(p, s.page, s.index),
    ];
    if (!hadDragged) {
      positions.add(math.max(lastOccupiedFlat(p) + 1, reservedSlots));
    }

    final sequence = [
      for (final s in stored)
        if (!_sameIdentity(s, componentKey, folderId)) s,
    ];

    // Where does the dragged entry go in the sequence?
    var at = -1;
    for (var i = 0; i < sequence.length; i++) {
      final s = sequence[i];
      if (s.page == targetPage && s.index == targetIndex) {
        at = after ? i + 1 : i;
        break;
      }
    }
    // Target not stored: append. See the doc comment.
    if (at < 0) at = sequence.length;

    sequence.insert(at, dragged);

    final per = capacity(p);
    final next = <DrawerSlot>[
      for (var i = 0; i < sequence.length; i++)
        DrawerSlot(
          page: positions[i] ~/ per,
          index: positions[i] % per,
          componentKey: sequence[i].componentKey,
          folderId: sequence[i].folderId,
        ),
    ];

    return p.copyWith(drawerSlots: next);
  }

  /// App dropped on app, in Custom: the folder rules run through
  /// [DrawerLayout.mergeApps] exactly as everywhere else, and the NEW FOLDER
  /// TAKES THE TARGET'S SLOT while both apps leave slot storage (they live in
  /// the folder now). Refusal (already filed, same app) passes straight
  /// through so the caller's identity-compare message still works.
  static LauncherPrefs mergeAppsAt(
    LauncherPrefs p,
    String sourceKey,
    String targetKey, {
    required String Function() newFolderId,
    String newFolderName = 'Folder',
  }) {
    final id = newFolderId();
    final merged = DrawerLayout.mergeApps(
      p,
      sourceKey,
      targetKey,
      newFolderId: () => id,
      newFolderName: newFolderName,
    );
    if (identical(merged, p)) return p;

    final target = _find(p.drawerSlots, targetKey, null);
    var slots = _without(
      _without(merged.drawerSlots, sourceKey, null),
      targetKey,
      null,
    );
    if (target != null) {
      slots = [
        ...slots,
        DrawerSlot(page: target.page, index: target.index, folderId: id),
      ];
    }
    // Target was a displayed append with no stored slot: the folder inherits
    // "unstored" and displays appended too, which is where the target was.
    return merged.copyWith(drawerSlots: slots);
  }

  /// App dropped on a folder (either drag direction), in Custom: the app joins
  /// through [DrawerLayout.addToFolder] and its slot becomes a gap; the folder
  /// keeps its own slot untouched.
  static LauncherPrefs addToFolderAt(
    LauncherPrefs p,
    String folderId,
    String componentKey,
  ) {
    final joined = DrawerLayout.addToFolder(p, folderId, componentKey);
    if (identical(joined, p)) return p;
    return joined.copyWith(
      drawerSlots: _without(joined.drawerSlots, componentKey, null),
    );
  }

  /// Folder dropped on folder, in Custom: [DrawerLayout.mergeFolders] rules
  /// apply (target's name and members-first survive) and the SOURCE folder's
  /// slot becomes a gap; the target keeps its slot.
  static LauncherPrefs mergeFoldersAt(
    LauncherPrefs p,
    String sourceId,
    String targetId,
  ) {
    final merged = DrawerLayout.mergeFolders(p, sourceId, targetId);
    if (identical(merged, p)) return p;
    return merged.copyWith(
      drawerSlots: _without(merged.drawerSlots, null, sourceId),
    );
  }

  /// "Clean up pages": drop entries whose app or folder no longer resolves,
  /// then compact everything into dense slots from [reservedSlots] up, in
  /// current slot order. Gaps and empty pages disappear; relative order does
  /// not change.
  /// Re-pack every placement onto a grid of a different shape.
  ///
  /// ─── WHY A REFLOW HAD TO EXIST ──────────────────────────────────────────
  ///
  /// A stored slot is a (page, index) pair, which only means anything against a
  /// capacity. Change the row count and every index points somewhere else, so
  /// the arrangement was frozen at the count it was created with and the drawer
  /// rendered that many rows whatever the screen could actually fit.
  ///
  /// That freeze is what made the Custom drawer lay out differently from every
  /// other sort mode, and once cells were sized to their contents it stopped
  /// fitting at all. So the grid follows the screen now, and when the shape
  /// changes the arrangement is re-packed onto it.
  ///
  /// ORDER SURVIVES, GAPS DO NOT. There is no honest way to preserve a gap
  /// across a change of capacity: the cell it sat in no longer exists. Order is
  /// the part someone actually arranged, so order is what is kept, and it is
  /// the same trade "Clean up pages" already makes deliberately.
  ///
  /// Returns [p] unchanged when the shape already matches, so this is safe to
  /// call on every layout pass.
  static LauncherPrefs reflow(
    LauncherPrefs p, {
    required int cols,
    required int rows,
    required Set<String> liveAppKeys,
    required Set<String> liveFolderIds,
  }) {
    if (p.drawerSlotCols == cols && p.drawerSlotRows == rows) return p;
    if (p.drawerSlots.isEmpty) {
      return p.copyWith(drawerSlotCols: cols, drawerSlotRows: rows);
    }

    final live = _liveSorted(p, liveAppKeys, liveFolderIds);
    final per = (cols < 1 ? 1 : cols) * (rows < 1 ? 1 : rows);

    return p.copyWith(
      drawerSlotCols: cols,
      drawerSlotRows: rows,
      drawerSlots: [
        for (var i = 0; i < live.length; i++)
          DrawerSlot(
            page: (reservedSlots + i) ~/ per,
            index: (reservedSlots + i) % per,
            componentKey: live[i].componentKey,
            folderId: live[i].folderId,
          ),
      ],
    );
  }

  static LauncherPrefs cleanUp(
    LauncherPrefs p, {
    required Set<String> liveAppKeys,
    required Set<String> liveFolderIds,
  }) {
    final live = _liveSorted(p, liveAppKeys, liveFolderIds);
    final per = capacity(p);

    final compacted = p.copyWith(
      drawerSlots: [
        for (var i = 0; i < live.length; i++)
          DrawerSlot(
            page: (reservedSlots + i) ~/ per,
            index: (reservedSlots + i) % per,
            componentKey: live[i].componentKey,
            folderId: live[i].folderId,
          ),
      ],
    );

    // Back to auto page count. Compacting every gap out of the arrangement and
    // then leaving the pages the user had grown it to hanging off the end,
    // empty, would not be a clean up. Growing it again is one tap.
    return compacted.clearing(drawerPageCount: true);
  }

  /// Does this arrangement predate the current [reservedSlots]?
  ///
  /// True when anything is stored inside the reserved block, which can only
  /// happen if it was written when the block was smaller. Self detecting on
  /// purpose: a persisted version flag is one more thing to write, one more
  /// thing to forget to write, and one more thing that can disagree with the
  /// data it describes.
  ///
  /// Cheap enough to call on every layout pass, which is where it is called.
  static bool needsReservedMigration(LauncherPrefs p) {
    for (final s in p.drawerSlots) {
      if (flatOf(p, s.page, s.index) < reservedSlots) return true;
    }
    return false;
  }

  /// Re-pack an arrangement written against a smaller reserved block.
  ///
  /// Returns [p] unchanged when there is nothing to migrate, so this is safe to
  /// call unconditionally and settles after one pass.
  ///
  /// Deliberately NOT [cleanUp]: that also clears `drawerPageCount`, and taking
  /// away pages someone grew the drawer to is a side effect they did not ask
  /// for and would read as the launcher losing their arrangement. This moves
  /// things and nothing else.
  static LauncherPrefs migrateReserved(
    LauncherPrefs p, {
    required Set<String> liveAppKeys,
    required Set<String> liveFolderIds,
  }) {
    if (!needsReservedMigration(p)) return p;

    final live = _liveSorted(p, liveAppKeys, liveFolderIds);
    final per = capacity(p);

    return p.copyWith(
      drawerSlots: [
        for (var i = 0; i < live.length; i++)
          DrawerSlot(
            page: (reservedSlots + i) ~/ per,
            index: (reservedSlots + i) % per,
            componentKey: live[i].componentKey,
            folderId: live[i].folderId,
          ),
      ],
    );
  }

  /// Drop dead entries WITHOUT compacting: uninstalls must not haunt slots,
  /// but the gaps the user carved are theirs. Call alongside
  /// [DrawerLayout.prune] whenever the app list changes.
  static LauncherPrefs prune(
    LauncherPrefs p, {
    required Set<String> liveAppKeys,
    required Set<String> liveFolderIds,
  }) {
    final kept = [
      for (final s in p.drawerSlots)
        if (_isLive(s, liveAppKeys, liveFolderIds)) s,
    ];
    if (kept.length == p.drawerSlots.length) return p;
    return p.copyWith(drawerSlots: kept);
  }

  // ── internals ─────────────────────────────────────────────────────────────

  static bool _sameIdentity(DrawerSlot s, String? componentKey, String? folderId) {
    if (componentKey != null) return s.componentKey == componentKey;
    if (folderId != null) return s.folderId == folderId;
    return false;
  }

  static DrawerSlot? _find(
    List<DrawerSlot> slots,
    String? componentKey,
    String? folderId,
  ) {
    for (final s in slots) {
      if (_sameIdentity(s, componentKey, folderId)) return s;
    }
    return null;
  }

  static List<DrawerSlot> _without(
    List<DrawerSlot> slots,
    String? componentKey,
    String? folderId,
  ) =>
      [
        for (final s in slots)
          if (!_sameIdentity(s, componentKey, folderId)) s,
      ];

  static bool _isLive(
    DrawerSlot s,
    Set<String> liveAppKeys,
    Set<String> liveFolderIds,
  ) {
    final k = s.componentKey;
    if (k != null) return liveAppKeys.contains(k);
    final f = s.folderId;
    if (f != null) return liveFolderIds.contains(f);
    return false;
  }

  static List<DrawerSlot> _liveSorted(
    LauncherPrefs p,
    Set<String> liveAppKeys,
    Set<String> liveFolderIds,
  ) =>
      [
        for (final s in p.drawerSlots)
          if (_isLive(s, liveAppKeys, liveFolderIds)) s,
      ]..sort(
          (a, b) => flatOf(p, a.page, a.index).compareTo(
                flatOf(p, b.page, b.index),
              ),
        );
}
