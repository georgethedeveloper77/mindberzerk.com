import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logging.dart';
import 'apps_api.g.dart';

/// The Dart face of the app storage bridge.
///
/// There is no clear method, on purpose. See the schema.
class AppsBridge {
  AppsBridge({AppsHostApi? api}) : _api = api ?? AppsHostApi();

  final AppsHostApi _api;

  Future<AppsState?> state() => _guard(_api.state);

  Future<bool> requestUsageAccess() async =>
      await _guard(_api.requestUsageAccess) ?? false;

  Future<List<AppEntry>> apps() async =>
      await _guard(_api.apps) ?? const <AppEntry>[];

  Future<AppsProgress?> readProgress() => _guard(_api.readProgress);

  Future<bool> openAppSettings(String packageName) async =>
      await _guard(() => _api.openAppSettings(packageName)) ?? false;

  Future<T?> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on PlatformException catch (error, stackTrace) {
      GLog.e(
        'apps call failed',
        scope: 'apps',
        cause: '${error.code}: ${error.message}',
        stackTrace: stackTrace,
      );
      return null;
    } on MissingPluginException {
      GLog.w('apps bridge not registered', scope: 'apps');
      return null;
    }
  }
}

final Provider<AppsBridge> appsBridgeProvider = Provider<AppsBridge>(
  (Ref ref) => AppsBridge(),
);

/// Whether this can work, and the two totals worth showing before the list.
///
/// Cheap after the first call: native caches the read for the life of the
/// process, because two hundred packages take seconds and nothing changes
/// between two taps of the same screen.
final FutureProvider<AppsState?> appsStateProvider = FutureProvider<AppsState?>(
  (Ref ref) => ref.watch(appsBridgeProvider).state(),
);

/// Every app, largest first.
final FutureProvider<List<AppEntry>> appsProvider =
    FutureProvider<List<AppEntry>>(
      (Ref ref) => ref.watch(appsBridgeProvider).apps(),
    );

/// How far the current read has got, polled while it runs.
///
/// ─── POLLED RATHER THAN PUSHED ─────────────────────────────────────────────
///
/// A FlutterApi would let native push each step, at the cost of a second
/// registration path in MainActivity and a callback surface to keep alive for
/// the whole life of the app. What is being reported is two integers that
/// change a few hundred times over a few seconds; asking for them four times a
/// second costs a binder call that returns three volatile fields, and native
/// answers it off the worker so it never queues behind the read.
///
/// ─── IT ENDS BY ITSELF ─────────────────────────────────────────────────────
///
/// The loop stops on the first answer that reports nothing in flight and some
/// work done, so the stream closes when the read finishes whether or not
/// anything is still listening. Nothing here needs a timer to be cancelled.
///
/// The guard on `done` matters: before the read has started, native honestly
/// answers zero and not reading, and a loop that stopped there would give up
/// before the first package was sized.
final StreamProvider<AppsProgress> appsProgressProvider =
    StreamProvider<AppsProgress>((Ref ref) async* {
      final AppsBridge bridge = ref.watch(appsBridgeProvider);

      bool alive = true;
      ref.onDispose(() => alive = false);

      while (alive) {
        final AppsProgress? progress = await bridge.readProgress();
        if (progress == null) return;

        yield progress;
        if (!progress.reading && progress.done > 0) return;

        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    });

/// How apps are ordered on the list screen.
enum AppSort {
  total,
  cache,
  data,
  unused;

  String get label => switch (this) {
    AppSort.total => 'Largest first',
    AppSort.cache => 'Most cache',
    AppSort.data => 'Most data',
    AppSort.unused => 'Longest unused',
  };
}

class AppSortController extends Notifier<AppSort> {
  @override
  AppSort build() => AppSort.total;

  void select(AppSort next) => state = next;
}

final NotifierProvider<AppSortController, AppSort> appSortProvider =
    NotifierProvider<AppSortController, AppSort>(AppSortController.new);

/// The list in the chosen order.
///
/// Sorted in Dart rather than native, and here that is correct: the whole list
/// is already in memory, so ordering it sorts everything there is. The storage
/// grid sends its order native only because a 400 row cap would otherwise sort
/// the page instead of the phone.
final Provider<List<AppEntry>> sortedAppsProvider = Provider<List<AppEntry>>((
  Ref ref,
) {
  final List<AppEntry> apps =
      ref.watch(appsProvider).value ?? const <AppEntry>[];
  final AppSort sort = ref.watch(appSortProvider);

  final List<AppEntry> out = List<AppEntry>.of(apps);
  switch (sort) {
    case AppSort.total:
      out.sort(
        (AppEntry a, AppEntry b) => (b.appBytes + b.dataBytes + b.cacheBytes)
            .compareTo(a.appBytes + a.dataBytes + a.cacheBytes),
      );
    case AppSort.cache:
      out.sort(
        (AppEntry a, AppEntry b) => b.cacheBytes.compareTo(a.cacheBytes),
      );
    case AppSort.data:
      out.sort((AppEntry a, AppEntry b) => b.dataBytes.compareTo(a.dataBytes));
    case AppSort.unused:
      // Never opened sorts FIRST here, unlike the expiry sort where a null goes
      // last. An app that has never been used is the strongest candidate for
      // removal, so its null means "most unused" rather than "unknown".
      out.sort(
        (AppEntry a, AppEntry b) =>
            (a.lastUsedMillis ?? 0).compareTo(b.lastUsedMillis ?? 0),
      );
  }
  return out;
});
