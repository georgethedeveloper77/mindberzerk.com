/// Lifecycle-gated subscriptions and timers.
///
/// Android stops the launcher's surface when another app is in front, but
/// Dart timers and platform streams (sensors, stat polling, clock ticks) keep
/// running and keep waking the CPU. Every piece of work that only matters on
/// screen should go through one of these gates: they attach while the app is
/// `resumed` and the feature is enabled, and detach in every other case.
///
/// ```dart
/// final tilt = GatedSubscription<AccelerometerEvent>(
///   () => accelerometerEventStream(samplingPeriod: SensorInterval.uiInterval),
///   _onTilt,
///   enabled: prefs.wallpaperParallax,
/// )..start();
///
/// final clock = GatedTicker(
///   const Duration(minutes: 1),
///   _refreshClock,
///   alignToInterval: true,
/// )..start();
/// ```
library;

import 'dart:async';

import 'package:flutter/widgets.dart';

/// Shared visibility and enablement tracking for [GatedSubscription] and
/// [GatedTicker]. Subclasses implement [_attach] and [_detach] only.
sealed class _VisibilityGate {
  _VisibilityGate({required bool enabled}) : _enabled = enabled;

  AppLifecycleListener? _listener;
  AppLifecycleState _state = AppLifecycleState.resumed;
  bool _enabled;
  bool _active = false;
  bool _disposed = false;

  /// Whether the underlying work is currently running.
  bool get isActive => _active;

  /// User or feature toggle. Turning it off detaches immediately.
  bool get enabled => _enabled;
  set enabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    _sync();
  }

  /// Begins tracking the lifecycle. Idempotent.
  ///
  /// Kept separate from the constructor so subclass fields are fully
  /// initialized before [_attach] can run.
  void start() {
    if (_disposed || _listener != null) return;
    _state =
        WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
    _listener = AppLifecycleListener(onStateChange: _onStateChange);
    _sync();
  }

  /// Detaches the work and stops tracking. The gate cannot be restarted.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _sync();
    _listener?.dispose();
    _listener = null;
  }

  void _onStateChange(AppLifecycleState state) {
    _state = state;
    _sync();
  }

  // Only `resumed` counts as visible. `inactive` covers the notification
  // shade and transitions; pausing there is cheap and resumes instantly.
  void _sync() {
    final shouldRun = !_disposed &&
        _listener != null &&
        _enabled &&
        _state == AppLifecycleState.resumed;
    if (shouldRun == _active) return;

    _active = shouldRun;
    if (shouldRun) {
      _attach();
    } else {
      _detach();
    }
  }

  void _attach();
  void _detach();
}

/// Listens to a stream only while the launcher is visible.
///
/// [source] is a factory, not a stream, because plugins such as
/// `sensors_plus` register the native listener on `listen` and release it on
/// `cancel`. Recreating the subscription is what actually frees the sensor.
final class GatedSubscription<T> extends _VisibilityGate {
  GatedSubscription(
    this._source,
    this._onData, {
    this.onError,
    super.enabled = true,
  });

  final Stream<T> Function() _source;
  final void Function(T event) _onData;
  final void Function(Object error, StackTrace stackTrace)? onError;

  StreamSubscription<T>? _subscription;

  @override
  void _attach() {
    _subscription = _source().listen(_onData, onError: onError);
  }

  @override
  void _detach() {
    // Fire and forget: the gate must not block on a plugin's teardown.
    unawaited(_subscription?.cancel());
    _subscription = null;
  }
}

/// A periodic callback that runs only while the launcher is visible.
///
/// With [fireOnResume], the callback runs as soon as the gate attaches, so a
/// clock or stat readout is never stale after returning to home. With
/// [alignToInterval], ticks land on wall-clock boundaries (for a one-minute
/// interval, exactly at :00), which lets a clock tick once per minute instead
/// of polling every second.
final class GatedTicker extends _VisibilityGate {
  GatedTicker(
    this.interval,
    this._onTick, {
    this.fireOnResume = true,
    this.alignToInterval = false,
    super.enabled = true,
  }) : assert(interval > Duration.zero, 'interval must be positive');

  final Duration interval;
  final VoidCallback _onTick;
  final bool fireOnResume;
  final bool alignToInterval;

  Timer? _timer;

  @override
  void _attach() {
    if (fireOnResume) _onTick();

    if (!alignToInterval) {
      _timer = Timer.periodic(interval, (_) => _onTick());
      return;
    }

    // One-shot to the next boundary, then periodic from there.
    _timer = Timer(_untilNextBoundary(), () {
      _onTick();
      _timer = Timer.periodic(interval, (_) => _onTick());
    });
  }

  @override
  void _detach() {
    _timer?.cancel();
    _timer = null;
  }

  Duration _untilNextBoundary() {
    final periodMs = interval.inMilliseconds;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    return Duration(milliseconds: periodMs - nowMs % periodMs);
  }
}
