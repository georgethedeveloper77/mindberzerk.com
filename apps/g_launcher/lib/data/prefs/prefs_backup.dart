import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'backup_apps.dart';
import 'global_prefs.dart';
import 'launcher_prefs.dart';
import 'prefs_repository.dart';
import 'wallpaper_collections.dart';

/// Export and import of everything the launcher stores.
///
/// ─── WHAT A BACKUP IS ───────────────────────────────────────────────────────
///
/// One file the user owns. It goes out through the system's own save dialog, so
/// where it lands is their choice: Drive, an SD card, their own server.
/// Deliberately NOT a first-party cloud, which is the same commitment the
/// ecosystem makes everywhere else.
///
/// It carries every distro's prefs rather than the active one's, because the
/// thing a person is protecting is the hour they spent arranging four desktops,
/// and a backup that restores one of them is a backup that loses three.
///
/// ─── v2 IS A ZIP, AND THAT IS THE WHOLE POINT OF v2 ─────────────────────────
///
/// v1 was a single JSON file that carried wallpaper collections as NAMES and
/// PATHS. Restoring onto the same phone found the images; restoring onto a new
/// one produced collections that came back named and empty, which is the
/// failure the redesign set out to remove. Images cannot travel inside a JSON
/// document without base64 inflating them by a third and turning the file into
/// something no text editor will open, so the container changed instead.
///
///   backup.json                     the v1 map, plus the fields below
///   wallpapers/<collectionId>/<n>   the bytes of each carried image
///
/// [wallpaperEntries] maps a collection's ORIGINAL absolute path to the archive
/// entry holding its bytes. A map rather than a parallel list because an image
/// that could not be read is simply absent, and a list with holes in it would
/// have to carry nulls and stay index-aligned with `paths` forever.
///
/// ─── READING v1 IS NOT OPTIONAL ─────────────────────────────────────────────
///
/// People have v1 files. [inspect] sniffs the first two bytes: a zip begins
/// `PK`, and anything else is tried as JSON text. A v1 file therefore imports
/// with no ceremony and no migration step, and its collections behave exactly
/// as they always did, because a file that carries no images cannot be made to
/// carry them after the fact.
///
/// ─── CROSS-DEVICE IS ALLOWED ────────────────────────────────────────────────
///
/// A backup made on a phone with Kali installed restores onto a phone without
/// it. Theme prefs are keyed by theme id, and an id nothing resolves simply
/// sits in storage waiting: install that distro later and the settings are
/// already there. Refusing the import, or dropping the unknown entries, would
/// both throw away the case this feature is most useful for.
///
/// The selected theme is the one exception. Restoring a pointer to a distro
/// this phone cannot resolve would leave the launcher on the fallback with the
/// stored selection disagreeing, so it is applied only when the id is one of
/// the themes actually being restored.
class PrefsBackup {
  const PrefsBackup._();

  /// Identifies our files. A restore that silently accepted somebody else's
  /// JSON would write nonsense into every prefs key at once.
  static const format = 'mindberzerk.g_launcher.backup';

  /// 1 was the bare JSON document. 2 is the zip described above.
  ///
  /// Bumped when the SHAPE changes, not when a field is added: an older build
  /// reading a newer file drops fields it does not know, which is what
  /// `fromJson` already does everywhere else in this layer.
  static const schemaVersion = 2;

  /// The prefix `PrefsRepository` keys per-theme prefs with. Public here so a
  /// backup can find every theme's file without the repository having to grow
  /// a list-themes method it has no other use for.
  static const themePrefix = 'prefs.v1.';

  static const manifestName = 'backup.json';
  static const wallpaperDir = 'wallpapers';

  /// NOT `.glb`, which is glTF's binary format and would have file managers
  /// offering a 3D viewer. NOT `.zip` either, which invites someone to unpack
  /// it and hand the folder back.
  static const fileExtension = 'glbak';

  static const _zipMagic = [0x50, 0x4B];

  // ── EXPORT ───────────────────────────────────────────────────────────────

  /// Everything except the images, as a plain map.
  ///
  /// ─── TAKES ITS DEPENDENCIES, NOT A REF ──────────────────────────────────
  ///
  /// Asking for the two stores and the collection list means this function
  /// depends on what it actually uses, reads the same from a provider or a
  /// widget, and can be tested with a `MemoryPrefsStore` and a literal list.
  static Future<Map<String, dynamic>> collect({
    required PrefsStore store,
    required PrefsRepository repo,
    required List<WallpaperCollection> collections,
    String? deviceLabel,
    Map<String, String> themeNames = const {},
    Map<String, BackupAppRef> installedApps = const {},
  }) async {
    final keys = await store.keys();

    final themes = <String, dynamic>{};
    final placed = <String>{};
    for (final key in keys.where((k) => k.startsWith(themePrefix))) {
      final raw = await store.read(key);
      if (raw == null) continue;
      try {
        // Parsed and re-encoded rather than copied verbatim, so a corrupt entry
        // is dropped HERE rather than travelling into the backup and failing on
        // the far side, where the user has no idea which distro is at fault.
        final prefs =
            LauncherPrefs.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        themes[key.substring(themePrefix.length)] = prefs.toJson();
        // Collected from the PARSED prefs rather than by reading field names
        // out of the JSON. The typed accessor moves when the model does; a
        // string key here would silently stop finding folders the day one is
        // renamed.
        placed.addAll(referencedKeys(prefs));
      } catch (_) {}
    }

    // ─── ONLY THE APPS ACTUALLY PLACED ───────────────────────────────────
    //
    // The caller hands over every installed app because it has the list to
    // hand; this keeps the handful that appear in a layout. A phone with two
    // hundred apps and nine on its dock records nine, and the restore screen
    // on the far side gets a list it can act on rather than an inventory.
    final apps = <String, dynamic>{};
    for (final key in placed) {
      final ref = installedApps[key];
      if (ref != null) apps[key] = ref.toJson();
    }

    final global = await repo.loadGlobal();

    return {
      'format': format,
      'schemaVersion': schemaVersion,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      // Null rather than a placeholder when the caller could not read it. The
      // restore screen then says nothing about the source phone instead of
      // saying "Unknown device", which reads as a fault rather than an absence.
      'device': deviceLabel,
      // Supplied by the caller from the theme registry, so this layer does not
      // have to know the registry exists. Absent ids fall back to the id
      // itself on the far side, which is still recognisable.
      'themeNames': themeNames,
      'selectedThemeId': await store.read(selectedThemeKey),
      'global': (global ?? const GlobalPrefs()).toJson(),
      'themes': themes,
      'apps': apps,
      'collections': [for (final c in collections) c.toJson()],
    };
  }

  /// The whole backup as bytes, ready for the save dialog or for our own
  /// snapshot directory.
  ///
  /// [includeWallpapers] false produces a v2 zip with no image entries rather
  /// than a v1 document. One reader, one writer, one shape to reason about; the
  /// difference is a few kilobytes of container and it keeps `wallpaperEntries`
  /// meaningful (empty) instead of absent.
  static Future<Uint8List> encode({
    required PrefsStore store,
    required PrefsRepository repo,
    required List<WallpaperCollection> collections,
    bool includeWallpapers = true,
    String? deviceLabel,
    Map<String, String> themeNames = const {},
    Map<String, BackupAppRef> installedApps = const {},
  }) async {
    final data = await collect(
      store: store,
      repo: repo,
      collections: collections,
      deviceLabel: deviceLabel,
      themeNames: themeNames,
      installedApps: installedApps,
    );

    final archive = Archive();
    final entries = <String, String>{};

    if (includeWallpapers) {
      for (final c in collections) {
        for (var i = 0; i < c.paths.length; i++) {
          final path = c.paths[i];
          // A file that cannot be read is SKIPPED, not fatal. The picker can
          // hand back a path the OS has already evicted, and losing the other
          // nine photos to it would be the worse outcome. The same rule
          // `WallpaperCollectionsNotifier.addImages` follows.
          Uint8List bytes;
          try {
            bytes = await File(path).readAsBytes();
          } catch (_) {
            continue;
          }

          // Indexed, not named after the original. Collection ids are ours and
          // safe; a user's file name is not, and a path separator or a
          // traversal sequence inside one would write outside the target
          // directory on extract.
          final name = '$wallpaperDir/${c.id}/$i${_extensionOf(path)}';
          archive.addFile(ArchiveFile(name, bytes.length, bytes));
          entries[path] = name;
        }
      }
    }

    data['wallpaperEntries'] = entries;

    // Indented on purpose. It is a file the user owns and may well open, and a
    // single-line blob invites the conclusion that it is not for them.
    final manifest =
        utf8.encode(const JsonEncoder.withIndent('  ').convert(data));
    archive.addFile(ArchiveFile(manifestName, manifest.length, manifest));

    final zipped = ZipEncoder().encode(archive);
    if (zipped == null) throw StateError('The backup could not be packed');
    return Uint8List.fromList(zipped);
  }

  /// What the save dialog offers as a name. The date is in it because the first
  /// thing anyone does with two backups is try to tell them apart.
  static String suggestedFileName() {
    final day = DateTime.now().toIso8601String().substring(0, 10);
    return 'g-launcher-$day.$fileExtension';
  }

  // ── IMPORT ───────────────────────────────────────────────────────────────

  /// What a restore is about to do, read BEFORE anything is written.
  ///
  /// Accepts both shapes. Returns null for anything that is not one of ours,
  /// which is the only validation that matters: a restore writes every prefs
  /// key at once and a stray JSON document would fill them with nonsense.
  static BackupSummary? inspect(Uint8List bytes) {
    if (bytes.length >= 2 &&
        bytes[0] == _zipMagic[0] &&
        bytes[1] == _zipMagic[1]) {
      return _inspectArchive(bytes);
    }
    try {
      return _summaryOf(
        jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>,
        null,
      );
    } catch (_) {
      return null;
    }
  }

  static BackupSummary? _inspectArchive(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final manifest = archive.findFile(manifestName);
      if (manifest == null) return null;
      final text = utf8.decode(manifest.content as List<int>);
      return _summaryOf(jsonDecode(text) as Map<String, dynamic>, archive);
    } catch (_) {
      return null;
    }
  }

  static BackupSummary? _summaryOf(Map<String, dynamic> j, Archive? archive) {
    if (j['format'] != format) return null;
    final v = (j['schemaVersion'] as num?)?.toInt() ?? 0;
    // A file from a FUTURE build is refused rather than partly read. Dropping
    // unknown fields is right within a shape; it is not right across one.
    if (v > schemaVersion) return null;

    final entries = ((j['wallpaperEntries'] as Map?) ?? const {})
        .cast<String, dynamic>()
        .map((k, v) => MapEntry(k, v as String));

    final apps = <String, BackupAppRef>{};
    for (final e in ((j['apps'] as Map?) ?? const {}).entries) {
      if (e.value is! Map) continue;
      // A malformed entry is dropped, not fatal. Losing one app's label costs
      // a readable row; failing here would cost the whole restore.
      final ref = BackupAppRef.fromJson(
        (e.value as Map).cast<String, dynamic>(),
      );
      if (ref != null) apps[e.key as String] = ref;
    }

    return BackupSummary(
      createdAt: j['createdAt'] as String?,
      device: j['device'] as String?,
      schemaVersion: v,
      themeCount: ((j['themes'] as Map?) ?? const {}).length,
      collectionCount: ((j['collections'] as List?) ?? const []).length,
      photoCount: entries.length,
      themeIds: ((j['themes'] as Map?) ?? const {}).keys.cast<String>().toList(),
      themeNames: ((j['themeNames'] as Map?) ?? const {})
          .cast<String, dynamic>()
          .map((k, v) => MapEntry(k, v as String)),
      wallpaperEntries: entries,
      apps: apps,
      data: j,
      archive: archive,
    );
  }

  /// Write a verified backup back into storage.
  ///
  /// [themeIds] null restores every distro in the file. A non-null set restores
  /// exactly those, which is what the restore screen's per-distro selection
  /// produces. Everything outside the selection is left untouched rather than
  /// cleared: unticking a distro means "leave mine alone", not "wipe mine".
  ///
  /// The caller invalidates the providers afterwards. Doing it here would mean
  /// this function had to know every provider that reads a prefs key, which is
  /// the coupling `prefs_repository` is arranged to avoid.
  static Future<void> apply(
    BackupSummary summary, {
    required PrefsStore store,
    required PrefsRepository repo,
    Set<String>? themeIds,
    bool includeGlobal = true,
    bool includeCollections = true,
  }) async {
    final j = summary.data;
    final themes = ((j['themes'] as Map?) ?? const {}).cast<String, dynamic>();

    final restored = <String>{};
    for (final e in themes.entries) {
      if (themeIds != null && !themeIds.contains(e.key)) continue;
      // Round-tripped through the model so a field this build does not know is
      // dropped and a malformed entry cannot land in storage. A backup is
      // untrusted input: the user may well have edited it.
      try {
        final prefs =
            LauncherPrefs.fromJson((e.value as Map).cast<String, dynamic>());
        await store.write('$themePrefix${e.key}', jsonEncode(prefs.toJson()));
        restored.add(e.key);
      } catch (_) {}
    }

    if (includeGlobal) {
      if (j['global'] case final Map<String, dynamic> g) {
        try {
          await repo.saveGlobal(GlobalPrefs.fromJson(g));
        } catch (_) {}
      }
    }

    // Only when that distro was actually restored. See the class note.
    final selected = j['selectedThemeId'] as String?;
    if (selected != null && restored.contains(selected)) {
      await store.write(selectedThemeKey, selected);
    }

    if (includeCollections) await _applyCollections(store, summary);
  }

  /// Collections come back whole when the backup carried their images, and
  /// come back as far as the phone allows when it did not.
  ///
  /// Three cases per image, in order:
  ///
  ///   in the archive   extracted into THIS phone's collection directory and
  ///                    the path rewritten, which is what makes a restore onto
  ///                    a new phone produce a full collection
  ///   on disk already  kept as it is, the same-phone case, no copy made
  ///   neither          dropped, silently, because the alternative is a list
  ///                    entry that draws the broken placeholder forever
  static Future<void> _applyCollections(
    PrefsStore store,
    BackupSummary summary,
  ) async {
    final raw = summary.data['collections'];
    if (raw is! List) return;

    final kept = <Map<String, dynamic>>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      try {
        final c = WallpaperCollection.fromJson(entry.cast<String, dynamic>());
        final dir = await wallpaperStorageDir('wallpaper_collections/${c.id}');

        final present = <String>[];
        for (final path in c.paths) {
          final name = summary.wallpaperEntries[path];
          final file = name == null ? null : summary.archive?.findFile(name);

          if (file != null) {
            final written = await _extract(dir, file, path);
            if (written != null) {
              present.add(written);
              continue;
            }
          }
          if (await File(path).exists()) present.add(path);
        }
        kept.add(c.copyWith(paths: present).toJson());
      } catch (_) {}
    }
    if (kept.isEmpty) return;

    await store.write(
      WallpaperCollectionsNotifier.storageKey,
      jsonEncode({
        'schemaVersion': WallpaperCollectionsNotifier.schemaVersion,
        'collections': kept,
      }),
    );
  }

  /// Write one archived image into [dir] under a fresh name, returning the new
  /// absolute path or null when it could not be written.
  ///
  /// A fresh name, never the archived entry's: the entry name comes from a file
  /// we are about to trust with a write, and the same microsecond-stamp scheme
  /// `copyWallpaperInto` uses keeps a restore from colliding with photos
  /// already in that collection.
  static Future<String?> _extract(
    Directory dir,
    ArchiveFile file,
    String originalPath,
  ) async {
    var stamp = DateTime.now().microsecondsSinceEpoch;
    var dest = File('${dir.path}/$stamp${_extensionOf(originalPath)}');
    while (await dest.exists()) {
      stamp += 1;
      dest = File('${dir.path}/$stamp${_extensionOf(originalPath)}');
    }
    try {
      await dest.writeAsBytes(file.content as List<int>, flush: true);
      return dest.path;
    } catch (_) {
      return null;
    }
  }

  /// The dotted extension of [path], lowercased, defaulting to `.jpg`. Matches
  /// what `copyWallpaperInto` does, so a photo keeps the same suffix whether it
  /// arrived through the picker or through a restore.
  static String _extensionOf(String path) {
    final m = RegExp(r'\.([A-Za-z0-9]+)$').firstMatch(path);
    return m == null ? '.jpg' : '.${m.group(1)!.toLowerCase()}';
  }
}

/// What a candidate backup contains, for the restore screen and the row that
/// names it in a list.
class BackupSummary {
  const BackupSummary({
    required this.createdAt,
    required this.device,
    required this.schemaVersion,
    required this.themeCount,
    required this.collectionCount,
    required this.photoCount,
    required this.themeIds,
    required this.themeNames,
    required this.wallpaperEntries,
    required this.apps,
    required this.data,
    required this.archive,
  });

  final String? createdAt;

  /// The phone it was taken on, when the file records one. Null for every v1
  /// file and for any v2 file whose encoder could not read the device name.
  final String? device;

  final int schemaVersion;
  final int themeCount;
  final int collectionCount;

  /// Images actually carried in the container. Zero for a v1 file, which is
  /// the distinction the restore screen has to be honest about.
  final int photoCount;

  /// Every distro id in the file, for the per-distro selection.
  final List<String> themeIds;

  /// Display names by id, when the encoder had the registry to hand.
  final Map<String, String> themeNames;

  /// Original absolute path to archive entry name.
  final Map<String, String> wallpaperEntries;

  /// componentKey to what the source phone knew about that app. Empty for a v1
  /// file, which recorded nothing, and for a v2 file whose encoder was handed
  /// no app list.
  final Map<String, BackupAppRef> apps;

  final Map<String, dynamic> data;

  /// Null for a v1 file, and for a v2 file read by something that only needed
  /// the manifest.
  final Archive? archive;

  /// A display name for one distro id: the recorded name, or the id, which is
  /// still something a person can recognise.
  String nameOf(String id) => themeNames[id] ?? id;

  /// When it was taken, as a local time. Null when the field was missing or
  /// unparseable, so callers show what they know instead of a made-up date.
  DateTime? get takenAt => DateTime.tryParse(createdAt ?? '')?.toLocal();

  /// The date as a plain day, for a one-line description.
  String get day => takenAt == null
      ? 'an unknown date'
      : createdAt!.substring(0, 10);
}
