import 'package:flutter/services.dart';

import '../core/logging.dart';
import 'messages_api.g.dart';

/// The Dart face of the message archive bridge.
///
/// Same contract as RecoveryBridge and StorageBridge: nothing above this line
/// ever sees a PlatformException, and a missing plugin is a null rather than a
/// crash.
///
/// Written at the same time as the schema, not after it. Adding a HostApi method
/// touches four files and this is the one that gets forgotten; `storageAccess`
/// in device_probe sat in the schema for weeks with no wrapper and therefore no
/// possible caller.
class MessagesBridge {
  MessagesBridge({MessagesHostApi? api}) : _api = api ?? MessagesHostApi();

  final MessagesHostApi _api;

  Future<MessageCapture?> captureState() => _guard(_api.captureState);

  /// Opens the system notification access screen.
  ///
  /// False when no such screen could be reached, which happens on ROMs that
  /// hide it. The caller says so rather than appearing to do nothing.
  Future<bool> openListenerSettings() async =>
      await _guard(_api.openListenerSettings) ?? false;

  Future<void> setCapturing({required bool value}) async =>
      _guard(() => _api.setCapturing(value));

  Future<List<ArchivedMessage>> messages({
    String? conversation,
    int limit = 300,
  }) async =>
      await _guard(() => _api.messages(conversation, limit)) ??
      const <ArchivedMessage>[];

  Future<List<String>> conversations() async =>
      await _guard(_api.conversations) ?? const <String>[];

  Future<void> clear() async => _guard(_api.clear);

  Future<T?> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on PlatformException catch (error, stackTrace) {
      GLog.e(
        'messages call failed',
        scope: 'messages',
        cause: '${error.code}: ${error.message}',
        stackTrace: stackTrace,
      );
      return null;
    } on MissingPluginException {
      GLog.w('messages bridge not registered', scope: 'messages');
      return null;
    }
  }
}
