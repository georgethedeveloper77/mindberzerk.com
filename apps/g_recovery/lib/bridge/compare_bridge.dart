import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logging.dart';
import '../core/prefs/prefs_store.dart';
import 'compare_api.g.dart';
import 'compare_ledger.dart';

/// The Dart face of the comparison bridge.
///
/// Written at the same time as the schema, not after it. Adding a HostApi method
/// touches four files and this is the one that gets forgotten.
class CompareBridge {
  CompareBridge({CompareHostApi? api}) : _api = api ?? CompareHostApi();

  final CompareHostApi _api;

  /// Decodes every image once and answers all three questions.
  ///
  /// [maxImages] caps the work rather than the findings. A phone with sixty
  /// thousand photos would otherwise decode for half an hour, and the first few
  /// thousand by size contain nearly all the space worth recovering.
  Future<CompareResult?> scan({
    int maxImages = 4000,
    double blurThreshold = 100,
  }) => _guard(() => _api.scan(maxImages, blurThreshold));

  Future<void> cancel() async => _guard(_api.cancel);

  Future<T?> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on PlatformException catch (error, stackTrace) {
      GLog.e(
        'compare call failed',
        scope: 'compare',
        cause: '${error.code}: ${error.message}',
        stackTrace: stackTrace,
      );
      return null;
    } on MissingPluginException {
      GLog.w('compare bridge not registered', scope: 'compare');
      return null;
    }
  }
}

final Provider<CompareBridge> compareBridgeProvider = Provider<CompareBridge>(
  (Ref ref) => CompareBridge(),
);

/// Progress, pushed from native while a scan runs.
class CompareProgressRelay extends CompareFlutterApi {
  CompareProgressRelay(this._sink);

  final void Function(CompareProgress) _sink;

  @override
  void onCompareProgress(CompareProgress progress) => _sink(progress);
}

final StreamProvider<CompareProgress> compareProgressProvider =
    StreamProvider<CompareProgress>((Ref ref) {
      final StreamController<CompareProgress> controller =
          StreamController<CompareProgress>();
      CompareFlutterApi.setUp(CompareProgressRelay(controller.add));
      ref.onDispose(() {
        CompareFlutterApi.setUp(null);
        controller.close();
      });
      return controller.stream;
    });

/// A scan that reached native and came back with nothing.
///
/// Its own type so the failure is a state rather than an absence. Storing null
/// on failure, which is what this used to do, made a scan that crashed in the
/// decoder indistinguishable from one that was never started: the card went
/// quietly back to saying "Scan" and the user was never told anything had gone
/// wrong.
class ScanFailure implements Exception {
  const ScanFailure();

  @override
  String toString() => 'The comparison could not run';
}

/// THE RESULT, and it is not fetched on its own.
///
/// A comparison scan decodes every photo on the phone, which is minutes of work
/// and real battery. Running it because a card wanted a number would be the
/// worst kind of eager loading: the user never asked, and the cost is invisible
/// to them.
///
/// So nothing here reaches the bridge until something calls [run], and the three
/// cards that depend on it say "Scan" rather than a figure until then.
///
/// ─── BUT THE ANSWER NOW OUTLIVES THE PROCESS ─────────────────────────────────
///
/// [build] reads the last scan off disk. That is the entire difference between a
/// feature someone uses and one they abandon: the previous version held the
/// result in memory only, so an app kill, and even trashing a single group,
/// erased minutes of work and put four cards back to "Scan".
class CompareController extends Notifier<AsyncValue<ScanRecord?>> {
  @override
  AsyncValue<ScanRecord?> build() => AsyncValue<ScanRecord?>.data(
    ScanRecord.read(ref.read(prefsStoreProvider)),
  );

  /// [fingerprint] describes storage at the moment of the scan, and is passed
  /// in rather than read here so this file stays free of feature providers.
  /// A caller with nothing to give passes nothing, and the record is then
  /// unverifiable rather than falsely fresh.
  Future<void> run({String fingerprint = ''}) async {
    if (state.isLoading) return;
    state = const AsyncValue<ScanRecord?>.loading();

    final CompareResult? result = await ref.read(compareBridgeProvider).scan();
    if (result == null) {
      state = AsyncValue<ScanRecord?>.error(
        const ScanFailure(),
        StackTrace.current,
      );
      return;
    }

    // A cancelled scan is saved too. What it found is real; what is not true is
    // that it covered everything, and the record carries that so the UI can say
    // so rather than passing off a partial answer as a complete one.
    final ScanRecord record = ScanRecord.of(result, fingerprint: fingerprint);
    await record.write(ref.read(prefsStoreProvider));
    state = AsyncValue<ScanRecord?>.data(record);
  }

  Future<void> cancel() => ref.read(compareBridgeProvider).cancel();

  /// Drops groups that have been acted on, and nothing else.
  ///
  /// ─── THIS REPLACES forget() ──────────────────────────────────────────────
  ///
  /// The old method blanked the whole result on the correct reasoning that a
  /// group naming trashed files offers to free space that is already free. It
  /// then applied that to every other finding on the phone. Trashing one set of
  /// duplicates threw away the other thirty nine, both similar lists and the
  /// entire blur grid, none of which had been touched.
  Future<void> forgetGroups(Set<String> groupIds) =>
      _prune((ScanRecord record) => record.withoutGroups(groupIds));

  /// The same, for photos removed from the blur grid.
  Future<void> forgetBlurred(Set<String> fileIds) =>
      _prune((ScanRecord record) => record.withoutBlurred(fileIds));

  /// Forgets everything, on purpose.
  ///
  /// Not called after a removal any more. It exists for the case where the
  /// findings are genuinely worthless, which is a user asking for it.
  Future<void> clear() async {
    await ScanRecord.clear(ref.read(prefsStoreProvider));
    state = const AsyncValue<ScanRecord?>.data(null);
  }

  Future<void> _prune(ScanRecord Function(ScanRecord) edit) async {
    final ScanRecord? current = state.value;
    if (current == null) return;

    final ScanRecord next = edit(current);
    if (identical(next, current)) return;

    await next.write(ref.read(prefsStoreProvider));
    state = AsyncValue<ScanRecord?>.data(next);
  }
}

final NotifierProvider<CompareController, AsyncValue<ScanRecord?>>
compareProvider = NotifierProvider<CompareController, AsyncValue<ScanRecord?>>(
  CompareController.new,
);

/// Only the byte identical groups.
final Provider<List<CompareGroup>> exactGroupsProvider =
    Provider<List<CompareGroup>>((Ref ref) {
      final ScanRecord? record = ref.watch(compareProvider).value;
      if (record == null) return const <CompareGroup>[];
      return record.ofKind('exact');
    });

/// Only the near duplicates.
final Provider<List<CompareGroup>> similarGroupsProvider =
    Provider<List<CompareGroup>>((Ref ref) {
      final ScanRecord? record = ref.watch(compareProvider).value;
      if (record == null) return const <CompareGroup>[];
      return record.ofKind('similar');
    });

/// The soft ones, worst first.
final Provider<List<BlurredImage>> blurredProvider =
    Provider<List<BlurredImage>>((Ref ref) {
      final ScanRecord? record = ref.watch(compareProvider).value;
      if (record == null) return const <BlurredImage>[];
      return List<BlurredImage>.of(record.blurred)..sort(
        (BlurredImage a, BlurredImage b) => a.sharpness.compareTo(b.sharpness),
      );
    });
