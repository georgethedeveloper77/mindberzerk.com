import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bridge/recovery_api.g.dart';
import '../../../bridge/recovery_bridge.dart';
import '../../../core/content/content_store.dart';

final Provider<RecoveryBridge> recoveryBridgeProvider =
    Provider<RecoveryBridge>((Ref ref) {
  final RecoveryBridge bridge = RecoveryBridge();
  ref.onDispose(bridge.dispose);
  return bridge;
});

/// Loads the registry through the CONTENT STORE and pushes it native.
///
/// Everything that touches the scanner watches this first, so the map can never
/// be missing when a scan starts.
///
/// Reading it here rather than from rootBundle directly is the Phase 7B seam:
/// the store decides whether the JSON came from the APK or from a verified CDN
/// pack, and neither this provider nor any Kotlin changes when that happens.
final FutureProvider<void> trashMapReadyProvider =
    FutureProvider<void>((Ref ref) async {
  final String? json =
      await ref.watch(contentStoreProvider).read(ContentStore.trashMap);
  if (json == null) return;
  await ref.watch(recoveryBridgeProvider).setTrashMap(json);
});

final FutureProvider<RecoveryAccess?> recoveryAccessProvider =
    FutureProvider<RecoveryAccess?>(
  (Ref ref) => ref.watch(recoveryBridgeProvider).access(),
);

/// Counts only, fast enough to run behind onboarding.
final FutureProvider<RecoverySummary?> prescanProvider =
    FutureProvider<RecoverySummary?>((Ref ref) async {
  await ref.watch(trashMapReadyProvider.future);
  return ref.watch(recoveryBridgeProvider).prescan();
});

final StreamProvider<ScanProgress> scanProgressProvider =
    StreamProvider<ScanProgress>(
  (Ref ref) => ref.watch(recoveryBridgeProvider).progress,
);

/// Holds the result of the last full scan, or null when none has run.
class ScanController extends Notifier<AsyncValue<RecoverySummary?>> {
  /// Sources whose native index has been populated in this session.
  ///
  /// Tracked because "has a scan ever run" is the wrong question. Opening a
  /// second category after the first one scanned would otherwise see a non-null
  /// summary, decide there was nothing to do, and render an empty list for a
  /// source that was never walked.
  final Set<String> _scanned = <String>{};

  @override
  AsyncValue<RecoverySummary?> build() =>
      const AsyncValue<RecoverySummary?>.data(null);

  bool covers(List<String> sourceIds) =>
      sourceIds.every(_scanned.contains);

  /// Scans only what is missing. Safe to call on every category open.
  Future<void> ensure(List<String> sourceIds) async {
    final List<String> missing =
        sourceIds.where((String id) => !_scanned.contains(id)).toList();
    if (missing.isEmpty) return;
    await run(missing);
  }

  Future<void> run(List<String> sourceIds) async {
    state = const AsyncValue<RecoverySummary?>.loading();
    await ref.read(trashMapReadyProvider.future);
    final RecoverySummary? summary =
        await ref.read(recoveryBridgeProvider).scan(sourceIds);
    _scanned.addAll(sourceIds);
    state = AsyncValue<RecoverySummary?>.data(summary);
  }

  Future<void> cancel() async {
    await ref.read(recoveryBridgeProvider).cancelScan();
  }

  /// Called after a restore or purge so counts stop including items that are no
  /// longer in the native index.
  void forget() {
    _scanned.clear();
    state = const AsyncValue<RecoverySummary?>.data(null);
  }
}

final NotifierProvider<ScanController, AsyncValue<RecoverySummary?>>
    scanControllerProvider =
    NotifierProvider<ScanController, AsyncValue<RecoverySummary?>>(
  ScanController.new,
);

/// Every source id the app can scan.
const List<String> kAllSourceIds = <String>[
  'media_trash',
  'app_trash',
  'thumbnails',
];

/// What a category screen is asking for.
///
/// A CATEGORY IS A KIND, NOT A SOURCE, and getting that backwards was a real
/// bug: on a phone whose entire 357 findings live in the thumbnail cache, a
/// Photos tile wired to `media_trash` shows nothing while the hero above it
/// says 357. The user is asking for photos. Which source they came from is our
/// bookkeeping, and it belongs on the row as a fidelity stamp rather than in
/// the routing.
@immutable
class RecoveryQuery {
  const RecoveryQuery({required this.sourceIds, this.kind});

  /// Sources to search. Usually all of them.
  final List<String> sourceIds;

  /// "image", "video", "audio", "document", or null for everything.
  final String? kind;

  @override
  bool operator ==(Object other) =>
      other is RecoveryQuery &&
      other.kind == kind &&
      other.sourceIds.length == sourceIds.length &&
      other.sourceIds.join(',') == sourceIds.join(',');

  @override
  int get hashCode => Object.hash(kind, sourceIds.join(','));
}

/// Findings matching a query, merged across sources.
///
/// Sorted newest deleted first, then largest, matching what native does per
/// source. Re-sorted here because merging two already sorted lists interleaved
/// by source would otherwise put a week old trashed photo below a thumbnail
/// from last year.
/// Type is INFERRED rather than annotated.
///
/// The explicit `FutureProviderFamily<...>` annotation failed to resolve here,
/// and the family type name is Riverpod internals that can be renamed between
/// versions without it counting as a breaking change. The type arguments on
/// `FutureProvider.family` below already pin everything that matters, so the
/// annotation was buying nothing and costing a compile.
final recoveryItemsProvider =
    FutureProvider.family<List<RecoverableItem>, RecoveryQuery>(
        (Ref ref, RecoveryQuery query) async {
  final RecoveryBridge bridge = ref.watch(recoveryBridgeProvider);
  final List<RecoverableItem> merged = <RecoverableItem>[];
  for (final String sourceId in query.sourceIds) {
    merged.addAll(await bridge.items(sourceId, limit: 400));
  }
  final List<RecoverableItem> filtered = query.kind == null
      ? merged
      : merged
          .where((RecoverableItem item) => item.kind == query.kind)
          .toList();
  filtered.sort((RecoverableItem a, RecoverableItem b) {
    final int byDate = (b.dateDeletedMillis ?? 0).compareTo(
      a.dateDeletedMillis ?? 0,
    );
    return byDate != 0 ? byDate : b.sizeBytes.compareTo(a.sizeBytes);
  });
  return filtered;
});

/// Which items the user has ticked. Cleared whenever a scan runs.
class SelectionController extends Notifier<Set<String>> {
  @override
  Set<String> build() => <String>{};

  void toggle(String itemId) {
    final Set<String> next = <String>{...state};
    if (!next.remove(itemId)) next.add(itemId);
    state = next;
  }

  void clear() => state = <String>{};
}

final NotifierProvider<SelectionController, Set<String>> selectionProvider =
    NotifierProvider<SelectionController, Set<String>>(SelectionController.new);
