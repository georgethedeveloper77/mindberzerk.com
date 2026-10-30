import 'dart:convert';

import 'prefs_repository.dart';

/// `layout commit` / `log` / `checkout`: git for the home screen.
///
/// ─── WHAT A SNAPSHOT HOLDS ──────────────────────────────────────────────────
///
/// The ARRANGEMENT and nothing else: dock, home items, folders on both
/// surfaces, drawer slots, desklets, and the grid they sit on. Not the icon
/// shape, not the wallpaper, not the hidden set. Checking out last week's
/// layout must not also undo the font you picked this morning.
///
/// Per distro, because a layout belongs to the shell it was arranged on: an
/// Ubuntu dock restored onto Plasma's panel would be nonsense.
///
/// ─── OUTSIDE THE prefs. KEYS ON PURPOSE ─────────────────────────────────────
///
/// So backups do not carry twenty copies of every layout, and a restore cannot
/// arrive with a history that belongs to another phone's apps.
class LayoutSnapshot {
  const LayoutSnapshot({
    required this.id,
    required this.at,
    required this.message,
    required this.data,
    this.auto = false,
  });

  /// Seven hex characters of a hash of [data], git-style. Identical layouts
  /// get identical ids, which is what lets `commit` refuse a no-op.
  final String id;
  final DateTime at;
  final String message;
  final bool auto;
  final Map<String, dynamic> data;

  Map<String, dynamic> toJson() => {
        'id': id,
        'at': at.millisecondsSinceEpoch,
        'message': message,
        if (auto) 'auto': true,
        'data': data,
      };

  static LayoutSnapshot? fromJson(Map<String, dynamic> j) {
    final id = j['id'];
    final at = j['at'];
    final data = j['data'];
    if (id is! String || at is! num || data is! Map) return null;
    return LayoutSnapshot(
      id: id,
      at: DateTime.fromMillisecondsSinceEpoch(at.toInt()),
      message: (j['message'] as String?) ?? '',
      auto: j['auto'] == true,
      data: data.cast<String, dynamic>(),
    );
  }
}

abstract final class LayoutSnapshots {
  /// The fields that ARE a layout, as named in `LauncherPrefs.toJson`.
  static const layoutKeys = <String>[
    'favourites',
    'dockExcluded',
    'homeItems',
    'folders',
    'drawerFolders',
    'drawerSlots',
    'desklets',
    'deskletGridVersion',
    'rows',
    'cols',
  ];

  /// Newest first. Twenty kept, oldest dropped, so this is a history and not
  /// an archive.
  static const cap = 20;

  static String _key(String themeId) => 'layout.snapshots.v1.$themeId';

  /// The layout half of a prefs JSON map. Absent optional fields stay absent,
  /// so restoring them clears what is there now rather than leaving it.
  static Map<String, dynamic> extract(Map<String, dynamic> prefsJson) => {
        for (final k in layoutKeys)
          if (prefsJson.containsKey(k)) k: prefsJson[k],
      };

  /// [prefsJson] with its layout replaced by [snapshot]'s.
  static Map<String, dynamic> apply(
    Map<String, dynamic> prefsJson,
    LayoutSnapshot snapshot,
  ) =>
      {
        for (final e in prefsJson.entries)
          if (!layoutKeys.contains(e.key)) e.key: e.value,
        ...snapshot.data,
      };

  /// FNV-1a over the canonical JSON, as 7 hex digits.
  static String idFor(Map<String, dynamic> data) {
    var h = 0x811c9dc5;
    for (final u in utf8.encode(jsonEncode(data))) {
      h ^= u;
      h = (h * 0x01000193) & 0xffffffff;
    }
    return h.toRadixString(16).padLeft(8, '0').substring(0, 7);
  }

  static Future<List<LayoutSnapshot>> load(
    PrefsStore store,
    String themeId,
  ) async {
    final raw = await store.read(_key(themeId));
    if (raw == null) return const [];
    try {
      return [
        for (final e in jsonDecode(raw) as List)
          if (e is Map)
            if (LayoutSnapshot.fromJson(e.cast<String, dynamic>())
                case final s?)
              s,
      ];
    } catch (_) {
      return const [];
    }
  }

  static Future<void> _save(
    PrefsStore store,
    String themeId,
    List<LayoutSnapshot> list,
  ) =>
      store.write(
        _key(themeId),
        jsonEncode([for (final s in list.take(cap)) s.toJson()]),
      );

  /// Record [prefsJson]'s layout. Returns null when the newest snapshot is
  /// already this exact layout ("nothing to commit").
  static Future<LayoutSnapshot?> commit(
    PrefsStore store,
    String themeId,
    Map<String, dynamic> prefsJson, {
    required String message,
    bool auto = false,
  }) async {
    final data = extract(prefsJson);
    final id = idFor(data);
    final list = await load(store, themeId);
    if (list.isNotEmpty && list.first.id == id) return null;
    final snap = LayoutSnapshot(
      id: id,
      at: DateTime.now(),
      message: message,
      data: data,
      auto: auto,
    );
    await _save(store, themeId, [snap, ...list.where((s) => s.id != id)]);
    return snap;
  }

  /// A snapshot by id prefix, or by `HEAD~n` / plain index `n` (0 newest).
  static LayoutSnapshot? find(List<LayoutSnapshot> list, String ref) {
    final r = ref.trim();
    final head = RegExp(r'^(?:HEAD~)?(\d+)$').firstMatch(r);
    if (head != null) {
      final n = int.parse(head.group(1)!);
      return n < list.length ? list[n] : null;
    }
    final hits = [
      for (final s in list)
        if (s.id.startsWith(r.toLowerCase())) s,
    ];
    return hits.length == 1 ? hits.first : null;
  }

  static Future<void> remove(
    PrefsStore store,
    String themeId,
    String id,
  ) async {
    final list = await load(store, themeId);
    await _save(store, themeId, [
      for (final s in list)
        if (s.id != id) s,
    ]);
  }

  /// One line of counts, for `log` and `diff`: "dock 5 · home 12 · folders 3".
  static String summary(Map<String, dynamic> data) {
    int n(String k) => (data[k] as List?)?.length ?? 0;
    return 'dock ${n('favourites')} · home ${n('homeItems')} · '
        'folders ${n('folders') + n('drawerFolders')} · '
        'desklets ${n('desklets')}';
  }
}
