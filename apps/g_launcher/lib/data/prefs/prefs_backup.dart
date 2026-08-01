import 'dart:convert';
import 'dart:io';

import 'global_prefs.dart';
import 'launcher_prefs.dart';
import 'prefs_repository.dart';
import 'wallpaper_collections.dart';

/// Export and import of everything the launcher stores.
///
/// ─── WHAT A BACKUP IS ───────────────────────────────────────────────────────
///
/// One JSON file the user owns. It goes out through the system share sheet, so
/// where it lands is their choice: Drive, a chat to themselves, their own
/// server. Deliberately NOT a first-party cloud, which is the same commitment
/// the ecosystem makes everywhere else.
///
/// It carries every distro's prefs rather than the active one's, because the
/// thing a person is protecting is the hour they spent arranging four desktops,
/// and a backup that restores one of them is a backup that loses three.
///
/// ─── METADATA, NOT PHOTOS ───────────────────────────────────────────────────
///
/// Wallpaper collections are carried as their NAMES and their file paths, not
/// as the images. A backup with a dozen photos in it is tens of megabytes,
/// cannot go through a share sheet reliably, and turns a settings file into an
/// archive format with its own versioning problems.
///
/// The consequence is honest and worth stating in the UI rather than hiding:
/// restoring onto the SAME phone finds the images exactly where they were and
/// the collections come back whole. Restoring onto a DIFFERENT phone finds
/// nothing at those paths, so [applyBackup] keeps the collections and their
/// names and drops the paths that do not resolve. The user gets their
/// structure back and re-adds the photos, which beats both alternatives:
/// silently listing images that cannot be opened, or refusing the whole
/// restore because one part of it cannot travel.
///
/// ─── CROSS-DEVICE IS ALLOWED ────────────────────────────────────────────────
///
/// A backup made on a phone with Kali installed restores onto a phone without
/// it. Theme prefs are keyed by theme id and an id nothing resolves simply sits
/// in storage, costing a few hundred bytes and waiting; install that distro
/// later and the settings are already there. Refusing the import, or dropping
/// the unknown entries, would both throw away the case this feature is most
/// useful for: moving to a new phone before it is fully set up.
///
/// The selected theme is the one exception. Restoring a pointer to a distro
/// this phone cannot resolve would leave the launcher on the fallback with the
/// stored selection disagreeing, so it is applied only when the id is one of
/// the themes the backup itself carried and is left alone otherwise.
class PrefsBackup {
  const PrefsBackup._();

  /// Identifies our files. A restore that silently accepted somebody else's
  /// JSON would write nonsense into every prefs key at once.
  static const format = 'mindberzerk.g_launcher.backup';

  /// Bumped when the SHAPE changes, not when a field is added: an older build
  /// reading a newer file drops fields it does not know, which is exactly what
  /// `fromJson` already does everywhere else in this layer.
  static const schemaVersion = 1;

  /// The prefix `PrefsRepository` keys per-theme prefs with. Public here so a
  /// backup can find every theme's file without the repository having to grow
  /// a list-themes method it has no other use for.
  static const themePrefix = 'prefs.v1.';

  // ── EXPORT ───────────────────────────────────────────────────────────────

  /// Collect everything into one map.
  ///
  /// ─── TAKES ITS DEPENDENCIES, NOT A REF ──────────────────────────────────
  ///
  /// This took a `Ref` and could therefore only be called from a provider,
  /// while its only caller is a widget holding a `WidgetRef`. Riverpod 3 keeps
  /// those types separate, so the two could never meet.
  ///
  /// Widening the parameter to `WidgetRef` would have fixed the error and left
  /// a data-layer file importing flutter_riverpod to name a widget type. Asking
  /// for the two stores and the collection list instead means this function
  /// depends on what it actually uses, reads the same from a provider or a
  /// widget, and can be tested with a `MemoryPrefsStore` and a literal list.
  static Future<Map<String, dynamic>> collect({
    required PrefsStore store,
    required PrefsRepository repo,
    required List<WallpaperCollection> collections,
  }) async {
    final keys = await store.keys();

    final themes = <String, dynamic>{};
    for (final key in keys.where((k) => k.startsWith(themePrefix))) {
      final raw = await store.read(key);
      if (raw == null) continue;
      try {
        // Parsed and re-encoded rather than copied verbatim, so a corrupt
        // entry is dropped HERE rather than travelling into the backup and
        // failing on the far side, where the user has no idea which distro is
        // at fault.
        themes[key.substring(themePrefix.length)] =
            LauncherPrefs.fromJson(jsonDecode(raw) as Map<String, dynamic>)
                .toJson();
      } catch (_) {}
    }

    final global = await repo.loadGlobal();

    return {
      'format': format,
      'schemaVersion': schemaVersion,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'selectedThemeId': await store.read(selectedThemeKey),
      'global': (global ?? const GlobalPrefs()).toJson(),
      'themes': themes,
      'collections': [for (final c in collections) c.toJson()],
    };
  }

  /// The backup as text, ready to hand to the system's save dialog.
  ///
  /// ─── TEXT, NOT A TEMP FILE ──────────────────────────────────────────────
  ///
  /// This used to write into the temp directory and return a `File` for the
  /// share sheet. The document picker takes BYTES and writes the file itself,
  /// wherever the user chooses, so a temp copy would exist only to be read back
  /// immediately and then left behind for the OS to sweep.
  ///
  /// Indented on purpose. It is a file the user owns and may well open; a
  /// single-line blob invites the conclusion that it is not for them.
  static Future<String> encode({
    required PrefsStore store,
    required PrefsRepository repo,
    required List<WallpaperCollection> collections,
  }) async {
    final data = await collect(
      store: store,
      repo: repo,
      collections: collections,
    );
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// What the save dialog offers as a name. The date is in it because the first
  /// thing anyone does with two backups is try to tell them apart.
  static String suggestedFileName() {
    final day = DateTime.now().toIso8601String().substring(0, 10);
    return 'g-launcher-$day.json';
  }

  // ── IMPORT ───────────────────────────────────────────────────────────────

  /// What a restore is about to do, so the confirm dialog can be specific.
  ///
  /// Read BEFORE anything is written. "Restore 4 distros and 3 collections" is
  /// a sentence someone can agree to; "Restore backup?" is not, and this
  /// action overwrites every setting on the phone.
  static BackupSummary? inspect(String text) {
    try {
      final j = jsonDecode(text) as Map<String, dynamic>;
      if (j['format'] != format) return null;
      final v = (j['schemaVersion'] as num?)?.toInt() ?? 0;
      if (v > schemaVersion) return null;
      return BackupSummary(
        createdAt: j['createdAt'] as String?,
        themeCount: ((j['themes'] as Map?) ?? const {}).length,
        collectionCount: ((j['collections'] as List?) ?? const []).length,
        data: j,
      );
    } catch (_) {
      return null;
    }
  }

  /// Write a verified backup back into storage.
  ///
  /// The caller invalidates the providers afterwards. Doing it here would mean
  /// this function had to know every provider that reads a prefs key, which is
  /// the coupling `prefs_repository` is arranged to avoid.
  static Future<void> apply(
    Map<String, dynamic> j, {
    required PrefsStore store,
    required PrefsRepository repo,
  }) async {
    final themes = ((j['themes'] as Map?) ?? const {}).cast<String, dynamic>();
    for (final e in themes.entries) {
      // Round-tripped through the model so a field this build does not know is
      // dropped and a malformed entry cannot land in storage. A backup is
      // untrusted input: the user may well have edited it.
      try {
        final prefs =
            LauncherPrefs.fromJson((e.value as Map).cast<String, dynamic>());
        await store.write('$themePrefix${e.key}', jsonEncode(prefs.toJson()));
      } catch (_) {}
    }

    if (j['global'] case final Map<String, dynamic> g) {
      try {
        await repo.saveGlobal(GlobalPrefs.fromJson(g));
      } catch (_) {}
    }

    // Only when the backup itself carried that theme. See the class note.
    final selected = j['selectedThemeId'] as String?;
    if (selected != null && themes.containsKey(selected)) {
      await store.write(selectedThemeKey, selected);
    }

    await _applyCollections(store, j['collections']);
  }

  /// Collections come back with their names; images come back only if the
  /// files are still on this device. See the class note on why that is the
  /// honest behaviour rather than a shortcoming.
  static Future<void> _applyCollections(
    PrefsStore store,
    Object? raw,
  ) async {
    if (raw is! List) return;

    final kept = <Map<String, dynamic>>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      try {
        final c = WallpaperCollection.fromJson(entry.cast<String, dynamic>());
        final present = <String>[];
        for (final path in c.paths) {
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
}

/// What a candidate backup contains, for the confirm dialog.
class BackupSummary {
  const BackupSummary({
    required this.createdAt,
    required this.themeCount,
    required this.collectionCount,
    required this.data,
  });

  final String? createdAt;
  final int themeCount;
  final int collectionCount;
  final Map<String, dynamic> data;

  /// The date, as a plain day. The stored value is a UTC timestamp, and the
  /// seconds are noise in a sentence whose job is to let someone recognise
  /// which backup this is.
  String get day => createdAt == null || createdAt!.length < 10
      ? 'an unknown date'
      : createdAt!.substring(0, 10);
}
