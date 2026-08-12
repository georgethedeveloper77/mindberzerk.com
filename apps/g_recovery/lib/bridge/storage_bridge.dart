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
  Future<Uint8List?> thumbnail(
    String fileId,
    int maxPixels, {
    required String kind,
    String? name,
    String? mimeType,
  }) => _guard<Uint8List?>(
    () => _api.thumbnail(fileId, maxPixels, kind, name, mimeType),
  );

  /// A playable content URI, or null when the file is no longer listed.
  ///
  /// Explicit type argument. `_guard<T>` returns `Future<T?>` and the native
  /// return here is ALREADY nullable, so without it inference demands a non
  /// null future.
  Future<String?> contentUri(String fileId) =>
      _guard<String?>(() => _api.contentUri(fileId));

  /// Raw bytes for the formats rendered in app.
  ///
  /// Two megabytes by default, which is a very long text file and a very short
  /// video. Null means missing OR over the cap, and the caller separates those
  /// with the size it already has.
  Future<Uint8List?> readBytes(
    String fileId, {
    int maxBytes = 2 * 1024 * 1024,
  }) => _guard<Uint8List?>(() => _api.readBytes(fileId, maxBytes));

  /// Every mounted volume: internal, and any card or drive.
  Future<List<VolumeEntry>> volumes() async =>
      await _guard(_api.volumes) ?? const <VolumeEntry>[];

  /// What is directly inside a folder. Null path means the volume roots.
  Future<List<DirEntry>> listDirectory(String? path) async =>
      await _guard(() => _api.listDirectory(path)) ?? const <DirEntry>[];

  /// Hands the file to another app. False when nothing can open it.
  Future<bool> openExternally(String fileId) async =>
      await _guard(() => _api.openExternally(fileId)) ?? false;

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
