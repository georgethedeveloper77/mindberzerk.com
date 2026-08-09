import 'package:flutter/services.dart';

import '../core/logging.dart';
import 'content_api.g.dart';

/// The Dart face of the content bridge. Same contract as the others: nothing
/// above this line ever sees a PlatformException.
class ContentBridge {
  ContentBridge({ContentHostApi? api}) : _api = api ?? ContentHostApi();

  final ContentHostApi _api;

  Future<void> setBaseUrl(String url) async => _guard(() => _api.setBaseUrl(url));

  Future<ContentSyncResult?> sync() => _guard(_api.sync);

  /// Explicit type argument: this native return is already nullable, so `T` has
  /// to carry the question mark or inference demands a non-null future.
  Future<String?> readContent(String packId) =>
      _guard<String?>(() => _api.readContent(packId));

  Future<List<ContentPackInfo>> packs() async =>
      await _guard(_api.packs) ?? const <ContentPackInfo>[];

  Future<T?> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on PlatformException catch (error, stackTrace) {
      GLog.e(
        'content call failed',
        scope: 'content',
        cause: '${error.code}: ${error.message}',
        stackTrace: stackTrace,
      );
      return null;
    } on MissingPluginException {
      GLog.w('content bridge not registered', scope: 'content');
      return null;
    }
  }
}
