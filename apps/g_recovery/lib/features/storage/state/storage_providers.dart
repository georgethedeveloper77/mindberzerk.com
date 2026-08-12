import 'dart:convert';

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bridge/storage_api.g.dart';
import '../../../bridge/storage_bridge.dart';
import '../../../core/prefs/prefs_store.dart';

final Provider<StorageBridge> storageBridgeProvider = Provider<StorageBridge>(
  (Ref ref) => StorageBridge(),
);

final FutureProvider<StorageOverview?>
storageOverviewProvider = FutureProvider<StorageOverview?>((Ref ref) async {
  final StorageOverview? overview = await ref
      .watch(storageBridgeProvider)
      .overview();
  if (overview != null) {
    // Every overview doubles as a free sample for the forecast. No background
    // job, no extra read: the user opening the tab is the trigger.
    ref.read(freeSpaceHistoryProvider.notifier).record(overview.volume);
  }
  return overview;
});

/// The current filter.
@immutable
class StorageFilter {
  const StorageFilter({
    this.kinds = const <String>[],
    this.minBytes,
    this.olderThanDays,
    this.folderPrefix,
    this.nameContains,
  });

  final List<String> kinds;
  final int? minBytes;
  final int? olderThanDays;
  final String? folderPrefix;
  final String? nameContains;

  bool get isEmpty =>
      kinds.isEmpty &&
      minBytes == null &&
      olderThanDays == null &&
      folderPrefix == null &&
      (nameContains == null || nameContains!.isEmpty);

  StorageFilter toggleKind(String kind) {
    final List<String> next = <String>[...kinds];
    if (!next.remove(kind)) next.add(kind);
    return copyWith(kinds: next);
  }

  StorageFilter copyWith({
    List<String>? kinds,
    int? minBytes,
    int? olderThanDays,
    String? folderPrefix,
    String? nameContains,
    bool clearMinBytes = false,
    bool clearOlderThan = false,
    bool clearFolder = false,
  }) => StorageFilter(
    kinds: kinds ?? this.kinds,
    minBytes: clearMinBytes ? null : (minBytes ?? this.minBytes),
    olderThanDays: clearOlderThan
        ? null
        : (olderThanDays ?? this.olderThanDays),
    folderPrefix: clearFolder ? null : (folderPrefix ?? this.folderPrefix),
    nameContains: nameContains ?? this.nameContains,
  );

  StorageQuerySpec toSpec() => StorageQuerySpec(
    kinds: kinds,
    limit: 300,
    // The tab's own filter list, which has never had a sort control and
    // does not need one: it is a preview under a chart, not a page someone
    // scrolls. Largest first is the only order that makes a preview useful.
    sort: 'largest',
    minBytes: minBytes,
    olderThanDays: olderThanDays,
    folderPrefix: folderPrefix,
    nameContains: nameContains,
  );

  @override
  bool operator ==(Object other) =>
      other is StorageFilter &&
      other.kinds.join(',') == kinds.join(',') &&
      other.minBytes == minBytes &&
      other.olderThanDays == olderThanDays &&
      other.folderPrefix == folderPrefix &&
      other.nameContains == nameContains;

  @override
  int get hashCode => Object.hash(
    kinds.join(','),
    minBytes,
    olderThanDays,
    folderPrefix,
    nameContains,
  );
}

class StorageFilterController extends Notifier<StorageFilter> {
  @override
  StorageFilter build() => const StorageFilter();

  void set(StorageFilter next) => state = next;

  void toggleKind(String kind) => state = state.toggleKind(kind);

  void clear() => state = const StorageFilter();
}

final NotifierProvider<StorageFilterController, StorageFilter>
storageFilterProvider =
    NotifierProvider<StorageFilterController, StorageFilter>(
      StorageFilterController.new,
    );

/// Results for the current filter. Null while no filter is set, so the tab
/// shows the overview instead of querying for everything.
final storageQueryProvider = FutureProvider<StorageQueryResult?>((
  Ref ref,
) async {
  final StorageFilter filter = ref.watch(storageFilterProvider);
  if (filter.isEmpty) return null;
  return ref.watch(storageBridgeProvider).query(filter.toSpec());
});

/// Free space samples, for the fill-up forecast.
///
/// One per day, thirty kept. Recorded whenever the Storage tab is opened rather
/// than by a background job, because a WorkManager task that wakes the phone to
/// write one number is exactly the kind of thing a storage utility should not
/// do.
class FreeSpaceHistory extends Notifier<List<FreeSpaceSample>> {
  static const String _key = 'free_space_history';

  @override
  List<FreeSpaceSample> build() {
    final Map<String, Object?> json = ref
        .read(prefsStoreProvider)
        .readJson(_key);
    final Object? raw = json['samples'];
    if (raw is! List) return const <FreeSpaceSample>[];
    return raw
        .whereType<Map<String, Object?>>()
        .map(FreeSpaceSample.fromJson)
        .toList();
  }

  void record(VolumeInfo volume) {
    if (volume.totalBytes <= 0) return;
    final DateTime now = DateTime.now();
    final List<FreeSpaceSample> kept = <FreeSpaceSample>[
      for (final FreeSpaceSample sample in state)
        if (!_sameDay(sample.at, now)) sample,
    ];
    kept.add(FreeSpaceSample(at: now, freeBytes: volume.freeBytes));
    kept.sort((FreeSpaceSample a, FreeSpaceSample b) => a.at.compareTo(b.at));
    final List<FreeSpaceSample> trimmed = kept.length > 30
        ? kept.sublist(kept.length - 30)
        : kept;
    state = trimmed;
    ref.read(prefsStoreProvider).writeJson(_key, <String, Object?>{
      'samples': <Object?>[
        for (final FreeSpaceSample sample in trimmed) sample.toJson(),
      ],
    });
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

@immutable
class FreeSpaceSample {
  const FreeSpaceSample({required this.at, required this.freeBytes});

  final DateTime at;
  final int freeBytes;

  Map<String, Object?> toJson() => <String, Object?>{
    'at': at.millisecondsSinceEpoch,
    'free': freeBytes,
  };

  factory FreeSpaceSample.fromJson(Map<String, Object?> json) =>
      FreeSpaceSample(
        at: DateTime.fromMillisecondsSinceEpoch(
          (json['at'] as num? ?? 0).toInt(),
        ),
        freeBytes: (json['free'] as num? ?? 0).toInt(),
      );
}

final NotifierProvider<FreeSpaceHistory, List<FreeSpaceSample>>
freeSpaceHistoryProvider =
    NotifierProvider<FreeSpaceHistory, List<FreeSpaceSample>>(
      FreeSpaceHistory.new,
    );

/// Projected date the volume fills, or null when there is not enough history.
///
/// NULL IS THE COMMON ANSWER AND THAT IS CORRECT. A forecast from two samples
/// taken an hour apart is astrology. This wants at least four samples spanning
/// at least four days, and a downward trend; anything else returns null and the
/// UI omits the row entirely rather than printing a guess.
final Provider<DateTime?> fillForecastProvider = Provider<DateTime?>((Ref ref) {
  final List<FreeSpaceSample> samples = ref.watch(freeSpaceHistoryProvider);
  if (samples.length < 4) return null;

  final FreeSpaceSample first = samples.first;
  final FreeSpaceSample last = samples.last;
  final int spanDays = last.at.difference(first.at).inDays;
  if (spanDays < 4) return null;

  final int consumed = first.freeBytes - last.freeBytes;
  if (consumed <= 0) return null;

  final double perDay = consumed / spanDays;
  if (perDay <= 0) return null;

  final double daysLeft = last.freeBytes / perDay;
  // Beyond two years the projection is meaningless and saying "full in 2031"
  // reads as a joke rather than a warning.
  if (daysLeft > 730) return null;

  return DateTime.now().add(Duration(days: daysLeft.round()));
});

/// Debug helper for inspecting the stored history.
String debugHistoryJson(List<FreeSpaceSample> samples) => jsonEncode(<Object?>[
  for (final FreeSpaceSample sample in samples) sample.toJson(),
]);

/// Every mounted volume.
///
/// Read once per launch. A card is inserted or removed rarely enough that
/// polling for it would be work spent on nothing.
final FutureProvider<List<VolumeEntry>> volumesProvider =
    FutureProvider<List<VolumeEntry>>(
      (Ref ref) => ref.watch(storageBridgeProvider).volumes(),
    );
