import 'dart:async';

import 'device_probe_api.g.dart';
import 'probe_client.dart';

/// One tick, carrying the previous one.
///
/// The pair travels together because every rate in this package is a delta:
/// CPU busy time is cumulative jiffies, not a percentage. Emitting only the
/// current snapshot would push the "remember the last one" problem into every
/// consumer, and each would solve it slightly differently.
class ProbeTick {
  const ProbeTick({required this.current, this.previous});

  final DeviceSnapshot current;

  /// Null on the first tick of a session, which is a real state the UI must
  /// render: rates are pending, not absent.
  final DeviceSnapshot? previous;

  /// Milliseconds between the two samples, from the device's own monotonic
  /// clock rather than from wall time or from the timer's nominal interval.
  /// Survives a late frame and a deep sleep gap.
  int? get intervalMillis {
    final DeviceSnapshot? last = previous;
    if (last == null) return null;
    final int delta =
        current.elapsedRealtimeMillis - last.elapsedRealtimeMillis;
    return delta > 0 ? delta : null;
  }
}

/// Polls [DeviceProbe] on an interval and emits [ProbeTick]s.
///
/// The interval lives here rather than natively, so native holds no state and
/// the delta arithmetic stays in one tested place.
class DeviceSampler {
  DeviceSampler({
    required DeviceProbe probe,
    Duration interval = const Duration(milliseconds: 500),
  })  : _probe = probe,
        _interval = interval {
    _controller = StreamController<ProbeTick>.broadcast(
      onListen: _start,
      onCancel: _stop,
    );
  }

  final DeviceProbe _probe;
  late final StreamController<ProbeTick> _controller;

  Duration _interval;
  Timer? _timer;
  DeviceSnapshot? _previous;
  bool _paused = false;

  /// Guards against overlapping reads. A snapshot takes a few milliseconds on a
  /// healthy device and can take much longer on a loaded budget one. Without
  /// this, a slow read at 2 Hz queues calls faster than they drain and the
  /// platform thread never catches up.
  bool _inFlight = false;

  Stream<ProbeTick> get ticks => _controller.stream;

  Duration get interval => _interval;

  bool get isPaused => _paused;

  /// Stops sampling without tearing down the stream.
  ///
  /// Needed because the shell keeps every tab alive in an IndexedStack, so the
  /// Device page is still mounted and still subscribed while the user is three
  /// tabs away. Relying on listener count alone would poll sysfs at 2 Hz for a
  /// screen nobody is looking at, which is exactly the battery drain a device
  /// monitor must not cause.
  void setPaused({required bool value}) {
    if (value == _paused) return;
    _paused = value;
    if (value) {
      _stop();
    } else if (_controller.hasListener) {
      _start();
    }
  }

  /// Changes the cadence without dropping the stream or losing [_previous], so
  /// the first tick after a foreground and background switch still has a valid
  /// delta rather than restarting as pending.
  void setInterval(Duration value) {
    if (value == _interval) return;
    _interval = value;
    if (_timer != null) {
      _stop();
      _start();
    }
  }

  void _start() {
    if (_paused) return;
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) => _sample());
    // Fire immediately as well: waiting a full interval for the first frame
    // makes the screen look broken at the slower background cadence.
    _sample();
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _sample() async {
    if (_inFlight || _paused || _controller.isClosed) return;
    _inFlight = true;
    try {
      final DeviceSnapshot? snapshot = await _probe.snapshot();
      if (snapshot == null || _controller.isClosed) return;
      _controller.add(ProbeTick(current: snapshot, previous: _previous));
      _previous = snapshot;
    } finally {
      _inFlight = false;
    }
  }

  Future<void> dispose() async {
    _stop();
    await _controller.close();
  }
}
