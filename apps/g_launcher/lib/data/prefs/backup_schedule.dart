import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'backup_store.dart';
import 'prefs_backup.dart';
import 'prefs_repository.dart';
import 'wallpaper_collections.dart';

/// When the launcher backs itself up without being asked.
///
/// ─── NO WORKMANAGER, AND NOT AS A COMPROMISE ────────────────────────────────
///
/// The obvious shape for a daily job is a scheduled worker, which on Flutter
/// means a background isolate plugin, a foreground service declaration, and a
/// second entry point that has to rebuild the whole prefs stack from nothing.
///
/// This app is the home screen. It is resumed dozens of times a day by
/// definition, so a due check on resume fires far more reliably than a worker
/// the OS is free to defer, and costs one comparison against a stored
/// timestamp. No plugin, no service, no second entry point, nothing to declare
/// on Play.
///
/// ─── NO WI-FI OR CHARGING CONDITIONS, BECAUSE THERE IS NO UPLOAD ────────────
///
/// The mockup carried a "Wi-Fi and charging only" switch. A scheduled backup
/// writes into app storage and touches no network at all, so the switch would
/// have gated a cost that does not exist. It belongs to B3, where a silent
/// write into the user's own folder is a real upload with a real cost.
///
/// ─── AN IDENTICAL BACKUP IS NOT WRITTEN ─────────────────────────────────────
///
/// Every run fingerprints what a backup WOULD contain and compares it to the
/// last one written. Nothing changed means nothing is written, which matters
/// because the store keeps five: a week of untouched days would otherwise push
/// every real backup out of the list and leave five copies of the same thing.
enum BackupFrequency {
  daily,
  weekly,

  /// Back up when the settings actually differ from the last backup. The
  /// fingerprint below is what makes this cheap enough to check on resume.
  onChange,
}

class BackupSchedule {
  const BackupSchedule({
    this.enabled = false,
    this.frequency = BackupFrequency.daily,
    this.lastRunAt,
    this.fingerprint,
  });

  final bool enabled;
  final BackupFrequency frequency;

  /// When a run last completed, whether or not it wrote anything. Null until
  /// the first one, which is what makes a freshly enabled schedule run at the
  /// next resume rather than waiting a day.
  final DateTime? lastRunAt;

  /// What the settings looked like when a backup was last WRITTEN.
  final String? fingerprint;

  BackupSchedule copyWith({
    bool? enabled,
    BackupFrequency? frequency,
    DateTime? lastRunAt,
    String? fingerprint,
  }) =>
      BackupSchedule(
        enabled: enabled ?? this.enabled,
        frequency: frequency ?? this.frequency,
        lastRunAt: lastRunAt ?? this.lastRunAt,
        fingerprint: fingerprint ?? this.fingerprint,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'frequency': frequency.name,
        'lastRunAt': lastRunAt?.toUtc().toIso8601String(),
        'fingerprint': fingerprint,
      };

  static BackupSchedule fromJson(Map<String, dynamic> j) => BackupSchedule(
        enabled: j['enabled'] as bool? ?? false,
        // An unknown name falls back rather than throwing, the same contract
        // every other `fromJson` in this layer follows.
        frequency: BackupFrequency.values.firstWhere(
          (f) => f.name == j['frequency'],
          orElse: () => BackupFrequency.daily,
        ),
        lastRunAt:
            DateTime.tryParse((j['lastRunAt'] as String?) ?? '')?.toLocal(),
        fingerprint: j['fingerprint'] as String?,
      );

  /// How often a run is allowed to write. [BackupFrequency.onChange] has no
  /// interval of its own: the fingerprint decides, and [_checkGap] keeps the
  /// check off every single resume.
  Duration? get interval => switch (frequency) {
        BackupFrequency.daily => const Duration(days: 1),
        BackupFrequency.weekly => const Duration(days: 7),
        BackupFrequency.onChange => null,
      };

  bool get isDue {
    if (!enabled) return false;
    final last = lastRunAt;
    if (last == null) return true;
    final gap = interval;
    if (gap == null) return true;
    return DateTime.now().difference(last) >= gap;
  }
}

class BackupScheduleNotifier extends AsyncNotifier<BackupSchedule> {
  static const storageKey = 'backups.schedule.v1';

  /// The floor between two due checks, regardless of frequency.
  ///
  /// A launcher is resumed every time the home button is pressed. Without this,
  /// `onChange` would collect and fingerprint every prefs key dozens of times
  /// an hour to discover nothing had changed.
  static const _checkGap = Duration(minutes: 5);

  /// In memory on purpose. It guards against resume storms within one process,
  /// and a fresh process should check immediately rather than honour a gap it
  /// cannot remember the start of.
  DateTime? _lastCheck;
  bool _running = false;

  @override
  Future<BackupSchedule> build() async {
    final raw = await ref.watch(prefsStoreProvider).read(storageKey);
    if (raw == null) return const BackupSchedule();
    try {
      return BackupSchedule.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const BackupSchedule();
    }
  }

  Future<BackupSchedule> _snapshot() async =>
      state.hasValue ? state.requireValue : await future;

  Future<void> _write(BackupSchedule next) async {
    state = AsyncData(next);
    await ref
        .read(prefsStoreProvider)
        .write(storageKey, jsonEncode(next.toJson()));
  }

  Future<void> setEnabled(bool value) async {
    final current = await _snapshot();
    await _write(current.copyWith(enabled: value));
    // Run straight away when switched on. Someone who just asked for automatic
    // backups and then sees "No backup yet" has been told the switch does
    // nothing.
    if (value) await runIfDue();
  }

  Future<void> setFrequency(BackupFrequency value) async {
    final current = await _snapshot();
    await _write(current.copyWith(frequency: value, enabled: true));
  }

  /// Back up if the schedule says so and anything has actually changed.
  ///
  /// Returns true only when a backup was WRITTEN, so a caller can tell "not
  /// due" apart from "nothing to do" apart from "done".
  ///
  /// Never throws. It is called from a lifecycle callback where there is
  /// nobody to catch, and a failed automatic backup must not take the home
  /// screen down with it.
  Future<bool> runIfDue({bool force = false}) async {
    if (_running) return false;

    final now = DateTime.now();
    final since = _lastCheck;
    if (!force && since != null && now.difference(since) < _checkGap) {
      return false;
    }
    _lastCheck = now;

    _running = true;
    try {
      final schedule = await _snapshot();
      if (!force && !schedule.isDue) return false;

      // ─── FINGERPRINTED BEFORE ENCODED ──────────────────────────────
      //
      // `collect` is the cheap half: prefs keys and a JSON encode. `create`
      // goes on to read every wallpaper off disk and zip them, which on a
      // collection of forty photos is tens of megabytes of IO. Comparing
      // first means an unchanged phone pays for the cheap half only.
      //
      // It does mean `collect` runs twice on a run that does write. That is
      // the right trade: writes are rare, and the alternative is encoding the
      // whole archive to find out it was not needed.
      final data = await PrefsBackup.collect(
        store: ref.read(prefsStoreProvider),
        repo: ref.read(prefsRepositoryProvider),
        collections: await ref.read(wallpaperCollectionsProvider.future),
      );
      final print = fingerprintOf(data);

      if (!force && print == schedule.fingerprint) {
        // Checked, nothing to do. `lastRunAt` still moves, so a daily schedule
        // does not re-collect on every resume for the rest of the day.
        await _write(schedule.copyWith(lastRunAt: now));
        return false;
      }

      final record = await ref.read(backupsProvider.notifier).create();
      if (record == null) return false;

      await _write(
        schedule.copyWith(lastRunAt: DateTime.now(), fingerprint: print),
      );
      return true;
    } catch (_) {
      return false;
    } finally {
      _running = false;
    }
  }
}

/// A stable fingerprint of what a backup would contain.
///
/// FNV-1a over the canonical JSON, masked to 32 bits so the arithmetic stays
/// in range on every target rather than relying on how one of them wraps.
/// `String.hashCode` was the obvious alternative and is the wrong tool: Dart
/// makes no promise that it is stable across releases, and a hash that changes
/// under an SDK upgrade would trigger one pointless backup per user.
///
/// The three volatile fields are stripped first. `createdAt` changes on every
/// call by definition, `device` is a constant that would only matter if the
/// phone renamed itself, and `wallpaperEntries` is assigned during encoding
/// and is absent here anyway.
String fingerprintOf(Map<String, dynamic> data) {
  final copy = Map<String, dynamic>.from(data)
    ..remove('createdAt')
    ..remove('device')
    ..remove('wallpaperEntries');

  var h = 0x811C9DC5;
  for (final b in utf8.encode(jsonEncode(copy))) {
    h ^= b;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return h.toRadixString(16);
}

final backupScheduleProvider =
    AsyncNotifierProvider<BackupScheduleNotifier, BackupSchedule>(
  BackupScheduleNotifier.new,
);
