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
/// Where the launcher keeps ITS OWN copies of the user's images.
///
/// ─── COPIES ARE THE POINT, NOT AN OPTIMISATION ──────────────────────────────
///
/// `image_picker` hands back a path inside `cacheDir`, and the OS is free to
/// evict a cache whenever storage gets tight. A wallpaper list built from those
/// paths therefore ROTS: the entries survive in prefs, the files do not, and
/// the user sees broken thumbnails for photos they never removed. The screen
/// that stored them said "the photo is already on the device", which is true of
/// the ORIGINAL and not of the path we were given.
///
/// Copying also makes the per-file picker sufficient for everything: no folder
/// access, no MANAGE_EXTERNAL_STORAGE, no Play declaration. Support dir, never
/// cache, for the same reason `WallpaperController` stashes to filesDir.
Future<Directory> wallpaperStorageDir(String relative) async {
  final base = await getApplicationSupportDirectory();
  final d = Directory('${base.path}/$relative');
  if (!await d.exists()) await d.create(recursive: true);
  return d;
}

/// The loose photos a user adds under "Yours", as opposed to a collection.
Future<Directory> ownWallpapersDir() =>
    wallpaperStorageDir('wallpapers_own');

/// Is [path] one of OUR copies?
///
/// The question a delete has to ask. A legacy entry still points into the
/// picker's cache, which is not ours to remove, and a theme preset is an asset
/// reference; deleting either would be reaching outside our own storage on the
/// strength of a string.
Future<bool> isOwnWallpaperCopy(String path) async {
  if (!path.startsWith('/')) return false;
  final base = await getApplicationSupportDirectory();
  return path.startsWith('${base.path}/wallpapers_own/') ||
      path.startsWith('${base.path}/wallpaper_collections/');
}

/// Copy [source] into [dir], returning the new absolute path, or null when the
/// source could not be read.
///
/// Null rather than a throw: the picker can hand back a path the OS has
/// already evicted, and losing nine other photos to it would be the worse
/// outcome. Callers count the nulls by omission.
Future<String?> copyWallpaperInto(Directory dir, String source) async {
  final ext =
      RegExp(r'\.([A-Za-z0-9]+)$').firstMatch(source)?.group(1)?.toLowerCase() ??
          'jpg';

  // A tight import loop can read the same microsecond twice on a coarse
  // clock, and the second photo silently overwriting the first would look
  // exactly like the picker having dropped it.
  var stamp = DateTime.now().microsecondsSinceEpoch;
  var dest = File('${dir.path}/$stamp.$ext');
  while (await dest.exists()) {
    stamp += 1;
    dest = File('${dir.path}/$stamp.$ext');
  }

  try {
    await File(source).copy(dest.path);
    return dest.path;
  } catch (_) {
    return null;
  }
}

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
  /// PUBLIC, because [PrefsBackup] writes this key directly rather than
  /// going through this notifier: a restore lands every key in one pass and
  /// then invalidates, so no half-applied state is ever on screen.
  static const storageKey = 'wallpaperCollections.v1';
  static const schemaVersion = 1;

  @override
  Future<List<WallpaperCollection>> build() async {
    final raw = await ref.watch(prefsStoreProvider).read(storageKey);
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
          storageKey,
          jsonEncode({
            'schemaVersion': schemaVersion,
            'collections': [for (final c in next) c.toJson()],
          }),
        );
  }

  /// Where one collection's copies live. Support dir, NOT cache; see the
  /// class doc for why that distinction is the whole feature.
  Future<Directory> _dirFor(String id) =>
      wallpaperStorageDir('wallpaper_collections/$id');

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
    final added = <String>[];
    for (final src in sourcePaths) {
      // Shared with the "Yours" import, so both paths name and place a copy
      // identically and a delete can recognise either.
      final copied = await copyWallpaperInto(dir, src);
      if (copied != null) added.add(copied);
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
