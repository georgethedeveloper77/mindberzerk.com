import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/app_repository.dart';
import 'backup_store.dart';

/// The user's own folder, as the Dart side sees it.
///
/// ─── THE URI NEVER COMES UP HERE ────────────────────────────────────────────
///
/// Native holds the tree URI, because it has to hold the persisted grant
/// anyway. This layer asks whether there is a folder and gets back a display
/// name, which is the only part of it a settings row can use. One owner instead
/// of two strings that can disagree about which folder is current.
///
/// ─── SEPARATE FROM THE SNAPSHOT STORE, DELIBERATELY ─────────────────────────
///
/// [BackupsNotifier] keeps copies inside app storage: always readable, never
/// permissioned, gone when the app is uninstalled. This is the other half: the
/// copy that survives the phone. They are not tiers of one thing, they answer
/// different questions ("can I undo yesterday" against "can I move to a new
/// phone"), so neither is derived from the other and both are pruned on their
/// own terms.
class BackupFolderEntry {
  const BackupFolderEntry({
    required this.uri,
    required this.name,
    required this.sizeBytes,
    required this.modifiedAt,
  });

  /// The SAF document URI. Opaque: it is a handle to pass back to native, never
  /// a path and never something to build by hand.
  final String uri;

  final String name;
  final int sizeBytes;

  /// From the provider's own timestamp. Epoch when it reported none, which some
  /// providers do for files they did not write.
  final DateTime modifiedAt;

  static BackupFolderEntry? fromJson(String raw) {
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final uri = j['uri'] as String?;
      final name = j['name'] as String?;
      if (uri == null || name == null) return null;
      return BackupFolderEntry(
        uri: uri,
        name: name,
        sizeBytes: (j['size'] as num?)?.toInt() ?? 0,
        modifiedAt: DateTime.fromMillisecondsSinceEpoch(
          (j['modified'] as num?)?.toInt() ?? 0,
        ),
      );
    } catch (_) {
      return null;
    }
  }
}

/// The chosen folder's display name, or null when none is chosen or the grant
/// has been revoked from system settings.
class BackupFolderNotifier extends AsyncNotifier<String?> {
  @override
  Future<String?> build() => ref.watch(launcherHostApiProvider).backupFolder();

  /// Open the system picker. Returns the folder name, or null when the user
  /// backed out, which is not a failure and gets no message.
  Future<String?> choose() async {
    final name = await ref.read(launcherHostApiProvider).chooseBackupFolder();
    if (name != null) {
      state = AsyncData(name);
      ref.invalidate(backupFolderEntriesProvider);
    }
    return name;
  }

  Future<void> forget() async {
    await ref.read(launcherHostApiProvider).forgetBackupFolder();
    state = const AsyncData(null);
    ref.invalidate(backupFolderEntriesProvider);
  }
}

final backupFolderProvider =
    AsyncNotifierProvider<BackupFolderNotifier, String?>(
  BackupFolderNotifier.new,
);

/// What is in the folder, newest first. Empty when no folder is chosen.
final backupFolderEntriesProvider =
    FutureProvider<List<BackupFolderEntry>>((ref) async {
  // Watched rather than read, so picking or forgetting a folder re-lists
  // without anything having to remember to invalidate this.
  final folder = await ref.watch(backupFolderProvider.future);
  if (folder == null) return const [];

  final rows = await ref.read(launcherHostApiProvider).listBackups();
  final out = <BackupFolderEntry>[];
  for (final raw in rows) {
    // A row that will not parse is dropped rather than failing the listing.
    // Losing one entry beats losing the list that names every other backup.
    final e = BackupFolderEntry.fromJson(raw);
    if (e != null) out.add(e);
  }
  return out;
});

/// Copy one local snapshot into the folder, and prune what falls off the end.
///
/// Returns the new document URI, or null when there is no folder, the snapshot
/// has gone, or the provider refused the write.
///
/// ─── THE FOLDER IS PRUNED SEPARATELY FROM THE SNAPSHOTS ─────────────────────
///
/// [BackupsNotifier.keepMax] governs app storage, which is ours and cheap to
/// reason about. This governs a folder the user can also put their own things
/// in, so pruning only ever touches files this launcher would itself have
/// written: the extension filter on the native side, and nothing else in the
/// folder is read, listed or considered.
final exportBackupProvider =
    Provider<Future<String?> Function(BackupRecord, {int keep})>((ref) {
  return (record, {int keep = BackupsNotifier.keepMax}) async {
    final folder = await ref.read(backupFolderProvider.future);
    if (folder == null) return null;

    final bytes = await ref.read(backupsProvider.notifier).read(record);
    if (bytes == null) return null;

    final api = ref.read(launcherHostApiProvider);
    final uri = await api.writeBackup(record.fileName, bytes);
    if (uri == null) return null;

    // Re-listed AFTER the write so the new file is counted, which is what makes
    // "keep 5" mean five including this one rather than five plus this one.
    final rows = await api.listBackups();
    final entries = <BackupFolderEntry>[];
    for (final raw in rows) {
      final e = BackupFolderEntry.fromJson(raw);
      if (e != null) entries.add(e);
    }
    for (final gone in entries.skip(keep)) {
      await api.deleteBackup(gone.uri);
    }

    ref.invalidate(backupFolderEntriesProvider);
    return uri;
  };
});

/// The bytes of one file in the folder, for inspecting or restoring it.
final readFolderBackupProvider =
    Provider<Future<Uint8List?> Function(String)>((ref) {
  return (uri) => ref.read(launcherHostApiProvider).readBackup(uri);
});
