import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bridge/messages_api.g.dart';
import '../../../bridge/messages_bridge.dart';

final Provider<MessagesBridge> messagesBridgeProvider =
    Provider<MessagesBridge>((Ref ref) => MessagesBridge());

/// Whether capture is possible, whether it is on, and how much is kept.
///
/// Invalidated by the shell on resume, alongside the file access grant, because
/// notification access is granted on a settings screen in another task with no
/// result and no callback. Coming back to the foreground is the only moment this
/// app can learn the answer.
final FutureProvider<MessageCapture?> messageCaptureProvider =
    FutureProvider<MessageCapture?>(
      (Ref ref) => ref.watch(messagesBridgeProvider).captureState(),
    );

/// The archive, newest first.
///
/// 300 rather than everything. The store is capped at four thousand lines and a
/// list nobody scrolls past the first hundred of does not need the other three
/// thousand seven hundred decoded on open.
final FutureProvider<List<ArchivedMessage>> archivedMessagesProvider =
    FutureProvider<List<ArchivedMessage>>(
      (Ref ref) => ref.watch(messagesBridgeProvider).messages(),
    );
