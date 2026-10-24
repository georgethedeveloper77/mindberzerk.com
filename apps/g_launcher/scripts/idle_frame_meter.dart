/// Frame and lifecycle probe for diagnosing idle battery drain.
///
/// Off by default and compiled out unless built with
/// `--dart-define=IDLE_PROBE=true`. Use a profile build for realistic numbers.
/// Every [IdleFrameMeter.window] it logs one line to logcat (tag `flutter`):
///
///     IDLE_PROBE frames=0 state=resumed elapsed=10.0s
///
/// A healthy launcher reports `frames=0` while untouched on the home screen.
/// In a debug build, add `--dart-define=IDLE_PROBE_STACKS=true` to print the
/// stack trace of whatever scheduled each frame, which names the culprit.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

final class IdleFrameMeter with WidgetsBindingObserver {
  IdleFrameMeter._();

  static final IdleFrameMeter instance = IdleFrameMeter._();

  static const bool enabled = bool.fromEnvironment('IDLE_PROBE');
  static const bool _printStacks = bool.fromEnvironment('IDLE_PROBE_STACKS');
  static const Duration window = Duration(seconds: 10);

  final Stopwatch _elapsed = Stopwatch();
  int _frames = 0;
  AppLifecycleState _state = AppLifecycleState.resumed;
  Timer? _ticker;

  /// Starts sampling. Idempotent, and a no-op unless [enabled].
  void start() {
    if (!enabled || _ticker != null) return;

    final binding = WidgetsBinding.instance;
    _state = binding.lifecycleState ?? AppLifecycleState.resumed;
    binding
      ..addObserver(this)
      ..addTimingsCallback(_onTimings);

    if (kDebugMode && _printStacks) debugPrintScheduleFrameStacks = true;

    _elapsed.start();
    _ticker = Timer.periodic(window, (_) => _flush());
  }

  /// Stops sampling and detaches every callback.
  void stop() {
    final ticker = _ticker;
    if (ticker == null) return;

    ticker.cancel();
    _ticker = null;
    WidgetsBinding.instance
      ..removeObserver(this)
      ..removeTimingsCallback(_onTimings);
    debugPrintScheduleFrameStacks = false;
    _elapsed
      ..stop()
      ..reset();
  }

  // The engine batches timings, so count entries rather than callbacks.
  void _onTimings(List<FrameTiming> timings) => _frames += timings.length;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Close the current window so frames are attributed to the state that
    // produced them, not the one we are entering.
    _flush();
    _state = state;
  }

  void _flush() {
    final seconds = _elapsed.elapsedMilliseconds / 1000;
    debugPrint(
      'IDLE_PROBE frames=$_frames state=${_state.name} '
      'elapsed=${seconds.toStringAsFixed(1)}s',
    );
    _frames = 0;
    _elapsed.reset();
  }
}
