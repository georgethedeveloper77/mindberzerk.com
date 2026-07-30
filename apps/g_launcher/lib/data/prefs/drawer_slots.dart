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
/// Flat slots 0 and 1 (page 0, indices 0 and 1) belong to the launcher's own
/// entries, G Launcher Settings and Device Settings, in every mode. They are
/// not stored, not draggable and not drop targets; every function here starts
/// counting at [reservedSlots]. Burying the launcher's settings mid-grid is
/// the bug the pinned block fixed, and Custom does not get to reintroduce it.
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
  static const int reservedSlots = 2;

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
