import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'prefs_repository.dart';

/// The user's wallpaper collections: named sets of photos, rotated as one.
///
/// ─── GLOBAL, AND WHY ────────────────────────────────────────────────────────
///
/// A collection is the person's photos, not a distro's content, so it lives
/// ABOVE the per-theme store under its own top-level key, exactly like
/// `selectedThemeId` and the global prefs bucket do. What IS per theme is the
/// rotation SELECTION (`LauncherPrefs.wallpaperRotationSource`): which pool a
/// distro cycles is a fact about that distro, so the terminal can rotate moody
/// screenshots while Aqua rotates the family album, both drawing from the same
/// shared collections.
///
/// NOT a [GlobalPrefs] field: that class is the promoted-field overlay for
/// [LauncherPrefs] and its change detection (`promotedChanged`) enumerates
/// exactly those fields. Collections are their own store with their own
/// lifecycle, and wedging them into the overlay would pollute a mechanism
/// built for something else.
///
/// ─── COPIES, NOT REFERENCES ─────────────────────────────────────────────────
///
/// Every imported photo is COPIED into app storage (support dir, never the
/// cache: the OS clears caches whenever storage gets tight, which is how the
/// existing "Yours" list can rot, since it stores `image_picker`'s cache
/// paths). Copies are what make the per-file photo picker sufficient: no
/// folder access, no `MANAGE_EXTERNAL_STORAGE`, no Play declaration. The
/// user's originals are never touched, including on delete.
class WallpaperCollection {
  const WallpaperCollection({
    required this.id,
    required this.name,
    this.paths = const [],
  });

  final String id;
  final String name;

  /// Absolute paths of OUR copies, in the order they were added. Order is the
  /// rotation order, matching the worker's cycle-in-order contract.
  final List<String> paths;

  WallpaperCollection copyWith({String? name, List<String>? paths}) =>
      WallpaperCollection(
        id: id,
        name: name ?? this.name,
        paths: paths ?? this.paths,
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'paths': paths};

  static WallpaperCollection fromJson(Map<String, dynamic> j) =>
      WallpaperCollection(
        id: j['id'] as String,
        name: j['name'] as String,
        paths: ((j['paths'] as List?) ?? const [])
            .map((e) => e as String)
            .toList(),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WallpaperCollection &&
          other.id == id &&
          other.name == name &&
          const ListEquality<String>().equals(other.paths, paths);

  @override
  int get hashCode =>
      Object.hash(id, name, const ListEquality<String>().hash(paths));
}

class WallpaperCollectionsNotifier
    extends AsyncNotifier<List<WallpaperCollection>> {
  static const _key = 'wallpaperCollections.v1';
  static const schemaVersion = 1;

  @override
  Future<List<WallpaperCollection>> build() async {
    final raw = await ref.watch(prefsStoreProvider).read(_key);
    if (raw == null) return const [];

    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      // A file written by a newer build reads as empty rather than throwing,
      // same contract every other store here follows. The images stay on disk,
      // so upgrading again restores them.
      final v = (j['schemaVersion'] as num?)?.toInt() ?? 0;
      if (v > schemaVersion) return const [];
      return [
        for (final e in (j['collections'] as List? ?? const []))
          WallpaperCollection.fromJson((e as Map).cast<String, dynamic>()),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// The list every mutation starts from.
  ///
  /// AWAITS the first load when the state has not resolved yet, rather than
  /// treating "still loading" as "empty". Mutating against an assumed-empty
  /// list and then saving is not a stale write, it is a wipe of every
  /// collection, the same trap `PrefsNotifier.edit` documents for itself.
  Future<List<WallpaperCollection>> _snapshot() async =>
      state.hasValue ? state.requireValue : await future;

  /// Optimistic like `PrefsNotifier.edit`: state moves now, disk catches up.
  Future<void> _write(List<WallpaperCollection> next) async {
    state = AsyncData(next);
    await ref.read(prefsStoreProvider).write(
          _key,
          jsonEncode({
            'schemaVersion': schemaVersion,
            'collections': [for (final c in next) c.toJson()],
          }),
        );
  }

  /// Where one collection's copies live. Support dir, NOT cache; see the
  /// class doc for why that distinction is the whole feature.
  Future<Directory> _dirFor(String id) async {
    final base = await getApplicationSupportDirectory();
    final d = Directory('${base.path}/wallpaper_collections/$id');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  /// Returns the new collection, or null when the name was blank. Blank is
  /// refused rather than stored, same rule `DrawerLayout.rename` follows: an
  /// unnamed thing in a list has nothing to tap.
  Future<WallpaperCollection?> create(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;

    final current = await _snapshot();
    final c = WallpaperCollection(
      id: 'wc${DateTime.now().microsecondsSinceEpoch}',
      name: trimmed,
    );
    await _write([...current, c]);
    return c;
  }

  Future<void> rename(String id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    final current = await _snapshot();
    await _write([
      for (final c in current)
        if (c.id == id) c.copyWith(name: trimmed) else c,
    ]);
  }

  /// Copy each source into the collection and record the copies. Returns how
  /// many landed, so the caller's message can be honest when some did not.
  ///
  /// A source that cannot be copied is SKIPPED, not fatal: the picker can hand
  /// back a path the OS has already evicted, and losing the other nine photos
  /// to it would be the worse outcome.
  Future<int> addImages(String id, List<String> sourcePaths) async {
    if (sourcePaths.isEmpty) return 0;

    final current = await _snapshot();
    if (current.every((c) => c.id != id)) return 0;

    final dir = await _dirFor(id);
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final added = <String>[];
    for (final src in sourcePaths) {
      final ext =
          RegExp(r'\.([A-Za-z0-9]+)$').firstMatch(src)?.group(1)?.toLowerCase() ??
              'jpg';
      final dest = '${dir.path}/${stamp}_${added.length}.$ext';
      try {
        await File(src).copy(dest);
        added.add(dest);
      } catch (_) {
        // Skipped; counted by omission.
      }
    }
    if (added.isEmpty) return 0;

    await _write([
      for (final c in current)
        if (c.id == id) c.copyWith(paths: [...c.paths, ...added]) else c,
    ]);
    return added.length;
  }

  /// Remove one image and delete OUR copy. The record goes first so a failed
  /// file delete leaves an orphaned file, not a listed image that draws the
  /// broken placeholder forever.
  Future<void> removeImage(String id, String path) async {
    final current = await _snapshot();
    await _write([
      for (final c in current)
        if (c.id == id)
          c.copyWith(paths: c.paths.where((p) => p != path).toList())
        else
          c,
    ]);
    try {
      await File(path).delete();
    } catch (_) {}
  }

  /// Delete a collection and its directory of copies. The user's originals
  /// are untouched, which is what the confirm dialog promises.
  Future<void> delete(String id) async {
    final current = await _snapshot();
    await _write(current.where((c) => c.id != id).toList());
    try {
      final base = await getApplicationSupportDirectory();
      final d = Directory('${base.path}/wallpaper_collections/$id');
      if (await d.exists()) await d.delete(recursive: true);
    } catch (_) {}
  }
}

final wallpaperCollectionsProvider =
    AsyncNotifierProvider<WallpaperCollectionsNotifier, List<WallpaperCollection>>(
  WallpaperCollectionsNotifier.new,
);
