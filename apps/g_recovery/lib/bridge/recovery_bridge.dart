import 'dart:async';

import 'package:flutter/services.dart';

import '../core/logging.dart';
import 'recovery_api.g.dart';

/// The Dart face of the recovery bridge.
///
/// Same contract as DeviceProbe: nothing above this line ever sees a
/// PlatformException. A refused read is an ordinary outcome on Android, not an
/// exception, and a UI that has to wrap every call in a try/catch ends up
/// catching nothing and showing zeros.
///
/// Implements the FlutterApi itself so scan progress arrives as a stream rather
/// than as a callback the UI has to wire up.
class RecoveryBridge implements RecoveryFlutterApi {
  RecoveryBridge({RecoveryHostApi? api}) : _api = api ?? RecoveryHostApi() {
    RecoveryFlutterApi.setUp(this);
  }

  final RecoveryHostApi _api;

  final StreamController<ScanProgress> _progress =
      StreamController<ScanProgress>.broadcast();

  Stream<ScanProgress> get progress => _progress.stream;

  @override
  void onScanProgress(ScanProgress progress) {
    if (!_progress.isClosed) _progress.add(progress);
  }

  /// Hands native the trash path registry.
  ///
  /// Dart owns the SOURCE of this JSON, which is the whole point. Today it is a
  /// bundled asset. In Phase 7 it is a signed CDN pack, and only this call site
  /// changes.
  Future<void> setTrashMap(String json) async =>
      _guard(() => _api.setTrashMap(json));

  Future<RecoveryAccess?> access() => _guard(_api.access);

  Future<bool> requestAllFilesAccess() async =>
      await _guard(_api.requestAllFilesAccess) ?? false;

  Future<RecoverySummary?> prescan() => _guard(_api.prescan);

  Future<RecoverySummary?> scan(List<String> sourceIds) =>
      _guard(() => _api.scan(sourceIds));

  Future<void> cancelScan() async => _guard(_api.cancelScan);

  Future<List<RecoverableItem>> items(
    String sourceId, {
    int offset = 0,
    int limit = 200,
  }) async =>
      await _guard(() => _api.items(sourceId, offset, limit)) ??
      const <RecoverableItem>[];

  Future<List<RestoreOutcome>> restore(List<String> itemIds) async =>
      await _guard(() => _api.restore(itemIds)) ?? const <RestoreOutcome>[];

  Future<List<RestoreOutcome>> purge(List<String> itemIds) async =>
      await _guard(() => _api.purge(itemIds)) ?? const <RestoreOutcome>[];

  /// JPEG preview bytes, downscaled natively.
  ///
  /// Null for anything with no renderable preview, which is the honest answer
  /// for audio and documents rather than an error.
  /// The type argument is explicit, and it has to be.
  ///
  /// `_guard<T>` returns `Future<T?>`, so inference reads the declared return
  /// type and picks `T = Uint8List`, which then demands a non-null
  /// `Future<Uint8List>` from the closure. This is the only bridge method whose
  /// native return is ALREADY nullable, so `T` must be `Uint8List?` and the two
  /// nullabilities collapse into one.
  Future<Uint8List?> thumbnail(String itemId, int maxPixels) =>
      _guard<Uint8List?>(() => _api.thumbnail(itemId, maxPixels));

  /// Deleted items and live files in one list, deleted first.
  ///
  /// Returns an empty list rather than null on failure, because search runs on
  /// every keystroke and a null here would make every call site handle a state
  /// that is indistinguishable from no matches.
  Future<List<RecoverableItem>> search(String query, int limit) async =>
      await _guard(() => _api.search(query, limit)) ??
      const <RecoverableItem>[];

  Future<void> dispose() async {
    await _progress.close();
  }

  Future<T?> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on PlatformException catch (error, stackTrace) {
      GLog.e(
        'recovery call failed',
        scope: 'recovery',
        cause: '${error.code}: ${error.message}',
        stackTrace: stackTrace,
      );
      return null;
    } on MissingPluginException {
      GLog.w('recovery bridge not registered', scope: 'recovery');
      return null;
    }
  }
}
