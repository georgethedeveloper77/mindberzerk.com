import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/app_repository.dart';
import 'backup_apps.dart';
import 'prefs_repository.dart';

/// Apps a restore placed that this phone does not have yet.
///
/// ─── WHY THIS OUTLIVES THE RESTORE ──────────────────────────────────────────
///
/// A restored layout is a set of componentKeys, and the grid drops the ones it
/// cannot resolve. That was right when an unresolvable key meant an uninstalled
/// app; after a restore from another phone it means a gap where something the
/// user deliberately arranged used to be, with nothing on screen to say so.
///
/// The backup knew the label and the package. The grid, half an hour later,
/// does not: the file has been closed and the restore screen is gone. So the
/// missing ones are written down at restore time and read by whatever needs to
/// draw a placeholder in their place.
///
/// ─── IT EMPTIES ITSELF ──────────────────────────────────────────────────────
///
/// [build] watches the installed app list, which `AppChangeWatcher` already
/// refills on every install, and drops anything whose package has arrived. So
/// installing Termux removes its own entry between frames, with no completion
/// callback, no polling, and nothing to go stale if the user installs it a week
/// later from somewhere else entirely.
///
/// Only the INSTALLABLE bucket is recorded. An app that was preinstalled on the
/// source phone cannot arrive on this one, so a placeholder for it would be a
/// permanent promise nothing can keep.
class PendingApp {
  const PendingApp({
    required this.componentKey,
    required this.label,
    required this.packageName,
  });

  final String componentKey;
  final String label;
  final String packageName;

  Map<String, dynamic> toJson() => {'label': label, 'package': packageName};

  static PendingApp? fromJson(String key, Map<String, dynamic> j) {
    final label = j['label'] as String?;
    final pkg = j['package'] as String?;
    if (label == null || pkg == null) return null;
    return PendingApp(componentKey: key, label: label, packageName: pkg);
  }
}

class PendingAppsNotifier extends AsyncNotifier<Map<String, PendingApp>> {
  static const storageKey = 'backups.pendingApps.v1';

  @override
  Future<Map<String, PendingApp>> build() async {
    final raw = await ref.watch(prefsStoreProvider).read(storageKey);
    if (raw == null) return const {};

    final stored = <String, PendingApp>{};
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      for (final e in j.entries) {
        if (e.value is! Map) continue;
        final p = PendingApp.fromJson(
          e.key,
          (e.value as Map).cast<String, dynamic>(),
        );
        if (p != null) stored[e.key] = p;
      }
    } catch (_) {
      return const {};
    }

    // Watched, not read. This is the whole completion mechanism: an install
    // pushes a new list and this rebuilds without the placeholder, or the
    // screen showing it, knowing anything happened.
    final apps = ref.watch(appListProvider);
    if (!apps.hasValue) return stored;

    final here = {for (final a in apps.requireValue) a.packageName};
    final live = <String, PendingApp>{
      for (final e in stored.entries)
        if (!here.contains(e.value.packageName)) e.key: e.value,
    };

    // Written back only when something actually arrived, so a rebuild for any
    // other reason does not touch storage.
    if (live.length != stored.length) await _persist(live);
    return live;
  }

  Future<void> _persist(Map<String, PendingApp> next) async {
    final store = ref.read(prefsStoreProvider);
    if (next.isEmpty) {
      await store.delete(storageKey);
      return;
    }
    await store.write(
      storageKey,
      jsonEncode({for (final e in next.entries) e.key: e.value.toJson()}),
    );
  }

  /// Remember the apps a restore just placed and could not resolve.
  ///
  /// MERGED with whatever is already there rather than replacing it. Restoring
  /// one distro today and another tomorrow leaves both sets of gaps on screen,
  /// and the second restore has no business forgetting the first one's.
  Future<void> record(Iterable<BackupApp> apps) async {
    final current = state.hasValue ? state.requireValue : await future;
    final next = <String, PendingApp>{
      ...current,
      for (final a in apps)
        a.componentKey: PendingApp(
          componentKey: a.componentKey,
          label: a.label,
          packageName: a.packageName,
        ),
    };
    state = AsyncData(next);
    await _persist(next);
  }

  /// Drop one, for a user who removed the placeholder rather than filling it.
  Future<void> forget(String componentKey) async {
    final current = state.hasValue ? state.requireValue : await future;
    final next = Map<String, PendingApp>.from(current)..remove(componentKey);
    state = AsyncData(next);
    await _persist(next);
  }
}

final pendingAppsProvider =
    AsyncNotifierProvider<PendingAppsNotifier, Map<String, PendingApp>>(
  PendingAppsNotifier.new,
);
