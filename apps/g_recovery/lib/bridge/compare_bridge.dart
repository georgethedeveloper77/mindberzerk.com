import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logging.dart';
import 'compare_api.g.dart';

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

/// THE RESULT, and it is not fetched on its own.
///
/// A comparison scan decodes every photo on the phone, which is minutes of work
/// and real battery. Running it because a card wanted a number would be the
/// worst kind of eager loading: the user never asked, and the cost is invisible
/// to them.
///
/// So this stays null until something calls [CompareController.run], and the
/// three cards that depend on it say "Scan" rather than a figure until then.
class CompareController extends Notifier<AsyncValue<CompareResult?>> {
  @override
  AsyncValue<CompareResult?> build() =>
      const AsyncValue<CompareResult?>.data(null);

  Future<void> run() async {
    if (state.isLoading) return;
    state = const AsyncValue<CompareResult?>.loading();
    final CompareResult? result = await ref.read(compareBridgeProvider).scan();
    state = AsyncValue<CompareResult?>.data(result);
  }

  Future<void> cancel() => ref.read(compareBridgeProvider).cancel();

  /// After a removal. The groups name files that no longer exist, and a stale
  /// group is worse than none: it offers to free space that is already free.
  void forget() {
    state = const AsyncValue<CompareResult?>.data(null);
  }
}

final NotifierProvider<CompareController, AsyncValue<CompareResult?>>
compareProvider =
    NotifierProvider<CompareController, AsyncValue<CompareResult?>>(
      CompareController.new,
    );

/// Only the byte identical groups.
final Provider<List<CompareGroup>> exactGroupsProvider =
    Provider<List<CompareGroup>>((Ref ref) {
      final CompareResult? result = ref.watch(compareProvider).value;
      if (result == null) return const <CompareGroup>[];
      return result.groups
          .where((CompareGroup group) => group.kind == 'exact')
          .toList();
    });

/// Only the near duplicates.
final Provider<List<CompareGroup>> similarGroupsProvider =
    Provider<List<CompareGroup>>((Ref ref) {
      final CompareResult? result = ref.watch(compareProvider).value;
      if (result == null) return const <CompareGroup>[];
      return result.groups
          .where((CompareGroup group) => group.kind == 'similar')
          .toList();
    });

/// The soft ones, worst first.
final Provider<List<BlurredImage>> blurredProvider =
    Provider<List<BlurredImage>>((Ref ref) {
      final CompareResult? result = ref.watch(compareProvider).value;
      if (result == null) return const <BlurredImage>[];
      return List<BlurredImage>.of(result.blurred)..sort(
        (BlurredImage a, BlurredImage b) => a.sharpness.compareTo(b.sharpness),
      );
    });
