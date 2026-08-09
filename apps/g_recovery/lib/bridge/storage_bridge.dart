import 'package:flutter/services.dart';

import '../core/logging.dart';
import 'storage_api.g.dart';

/// The Dart face of the storage bridge. Same contract as RecoveryBridge:
/// nothing above this line ever sees a PlatformException.
class StorageBridge {
  StorageBridge({StorageHostApi? api}) : _api = api ?? StorageHostApi();

  final StorageHostApi _api;

  Future<StorageOverview?> overview() => _guard(_api.overview);

  Future<StorageQueryResult?> query(StorageQuerySpec spec) =>
      _guard(() => _api.query(spec));

  /// The type argument is explicit. `_guard<T>` returns `Future<T?>`, and this
  /// is one of the methods whose native return is ALREADY nullable, so `T` must
  /// carry the question mark or inference demands a non-null future.
  Future<Uint8List?> thumbnail(String fileId, int maxPixels) =>
      _guard<Uint8List?>(() => _api.thumbnail(fileId, maxPixels));

  /// Trash by default. [permanent] skips the OS bin.
  Future<List<StorageOutcome>> remove(
    List<String> fileIds, {
    bool permanent = false,
  }) async =>
      await _guard(() => _api.remove(fileIds, permanent)) ??
      const <StorageOutcome>[];

  Future<T?> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on PlatformException catch (error, stackTrace) {
      GLog.e(
        'storage call failed',
        scope: 'storage',
        cause: '${error.code}: ${error.message}',
        stackTrace: stackTrace,
      );
      return null;
    } on MissingPluginException {
      GLog.w('storage bridge not registered', scope: 'storage');
      return null;
    }
  }
}
