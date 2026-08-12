import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logging.dart';
import 'server_api.g.dart';

/// The Dart face of the home server bridge.
///
/// ─── THE PASSWORD GOES ONE WAY ───────────────────────────────────────────────
///
/// It is an argument to [test] and [save] and is never returned. Nothing in Dart
/// can read a stored password back, which means no screen can leak one and no
/// log line can print one.
///
/// An empty string means "use the stored one", so changing a setting on a saved
/// server does not make someone retype it.
class ServerBridge {
  ServerBridge({ServerHostApi? api}) : _api = api ?? ServerHostApi();

  final ServerHostApi _api;

  Future<ServerConfig?> current() => _guard<ServerConfig?>(_api.current);

  Future<ServerProbe?> test(ServerConfig config, {String password = ''}) =>
      _guard(() => _api.test(config, password));

  Future<void> save(ServerConfig config, {String password = ''}) async =>
      _guard(() => _api.save(config, password));

  Future<void> forget() async => _guard(_api.forget);

  Future<void> setSchedule({required bool enabled}) async =>
      _guard(() => _api.setSchedule(enabled));

  /// Explicit type argument, because the method is itself nullable.

  Future<int?> nextRunMillis() => _guard<int?>(_api.nextRunMillis);

  Future<void> startBackup() async => _guard(_api.startBackup);

  Future<void> cancelBackup() async => _guard(_api.cancelBackup);

  Future<TransferState?> transferState() => _guard(_api.transferState);

  /// Returns the ids that matched byte for byte. Anything missing failed.
  Future<List<String>> verify(List<String> fileIds) async =>
      await _guard(() => _api.verify(fileIds)) ?? const <String>[];

  Future<List<ReclaimCandidate>> reclaimable({int limit = 500}) async =>
      await _guard(() => _api.reclaimable(limit)) ?? const <ReclaimCandidate>[];

  Future<T?> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on PlatformException catch (error, stackTrace) {
      GLog.e(
        'server call failed',
        scope: 'server',
        cause: '${error.code}: ${error.message}',
        stackTrace: stackTrace,
      );
      return null;
    } on MissingPluginException {
      GLog.w('server bridge not registered', scope: 'server');
      return null;
    }
  }
}

final Provider<ServerBridge> serverBridgeProvider = Provider<ServerBridge>(
  (Ref ref) => ServerBridge(),
);

/// The saved server, or null when none is set up.
final FutureProvider<ServerConfig?> serverConfigProvider =
    FutureProvider<ServerConfig?>(
      (Ref ref) => ref.watch(serverBridgeProvider).current(),
    );

/// How a copy is going, polled while one runs.
///
/// Polled rather than pushed, unlike the compare scan. A transfer emits an
/// update per file rather than per decode, so the traffic is low enough that a
/// FlutterApi would be more machinery than the problem needs, and polling stops
/// by itself when nothing is running.
final StreamProvider<TransferState?>
transferProvider = StreamProvider<TransferState?>((Ref ref) async* {
  final ServerBridge bridge = ref.watch(serverBridgeProvider);

  TransferState? state = await bridge.transferState();
  yield state;

  int idle = 0;
  while (idle < 2) {
    await Future<void>.delayed(
      state?.running ?? false
          ? const Duration(milliseconds: 700)
          : const Duration(seconds: 3),
    );
    state = await bridge.transferState();
    yield state;

    // Two slow ticks after it stops, then the poll ends. Long enough to catch a
    // final state, short enough that an idle screen is not asking a question
    // every three seconds for the life of the app.
    idle = (state?.running ?? false) ? 0 : idle + 1;
  }
});

/// Local files whose copy on the server has been checked.
///
/// Read once when the reclaim screen opens. Each entry costs a round trip to
/// the server for a size, so this is not something to re-run on every rebuild.
final FutureProvider<List<ReclaimCandidate>> reclaimableProvider =
    FutureProvider<List<ReclaimCandidate>>(
      (Ref ref) => ref.watch(serverBridgeProvider).reclaimable(),
    );

/// When the nightly run is next due, or null when it is off.
final FutureProvider<int?> nextRunProvider = FutureProvider<int?>(
  (Ref ref) => ref.watch(serverBridgeProvider).nextRunMillis(),
);
