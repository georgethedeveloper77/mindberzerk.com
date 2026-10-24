/// TEMPORARY. How many frames the launcher draws while nobody is touching it.
///
/// ─── WHY THIS IS THE NUMBER THAT MATTERS ────────────────────────────────────
///
/// Samsung's own per-app figures put G Launcher at 4.9% for 20 minutes on
/// screen and 6.4% for 46 minutes, which is TikTok territory per minute and far
/// above what One UI Home costs. The background pollers are already gated on
/// lifecycle, so the cost is on-screen, per frame.
///
/// Per frame is expensive here for a structural reason: `getBackgroundMode()`
/// returns transparent so the system wallpaper shows through, which puts
/// Flutter on a FlutterTextureView, which WidgetStage then depends on for
/// hosting third-party widgets behind FlutterView. That path cannot be swapped
/// for a SurfaceView without breaking widgets, so the only lever left is
/// drawing fewer frames.
///
/// A static home screen should produce ZERO frames per second: Flutter
/// schedules a frame only when something marks itself dirty. Anything above
/// zero with the phone untouched is a widget animating or rebuilding on a
/// timer, and each of those frames pays the full composite.
///
/// DELETE once the offender is found. Debug and profile only; [start] returns
/// immediately in release.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

abstract final class FrameProbe {
  /// Long enough that a once-a-minute clock tick does not read as a rate, short
  /// enough to bisect a configuration without waiting around.
  static const _window = Duration(seconds: 10);

  static Timer? _report;
  static AppLifecycleListener? _lifecycle;
  static int _frames = 0;
  static int _buildMicros = 0;
  static int _rasterMicros = 0;
  static bool _running = false;

  static void start() {
    if (_running || kReleaseMode) return;
    _running = true;

    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    // Flush on the way out so a window that ends with the screen off does not
    // report the frames before it as the idle rate. Then stop the timer: a
    // backgrounded probe printing "0 frames" every ten seconds is a wakeup that
    // inflates the very background CPU figure it sits next to in logcat.
    _lifecycle = AppLifecycleListener(
      onPause: _pause,
      onHide: _pause,
      onResume: _resume,
    );
    _resume();
  }

  static void _resume() {
    _report?.cancel();
    _report = Timer.periodic(_window, (_) => _flush());
  }

  static void _pause() {
    final report = _report;
    if (report == null) return;
    report.cancel();
    _report = null;
    _flush();
  }

  static void stop() {
    if (!_running) return;
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _lifecycle?.dispose();
    _lifecycle = null;
    _report?.cancel();
    _report = null;
    _running = false;
  }

  static void _onTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      _frames++;
      _buildMicros += t.buildDuration.inMicroseconds;
      _rasterMicros += t.rasterDuration.inMicroseconds;
    }
  }

  /// `debugPrint`, not the app logger: this is scaffolding read in logcat next
  /// to a stopwatch, and routing it through Crashlytics would dress up
  /// something with a known expiry.
  static void _flush() {
    final frames = _frames;
    _frames = 0;
    final buildMicros = _buildMicros;
    _buildMicros = 0;
    final rasterMicros = _rasterMicros;
    _rasterMicros = 0;

    if (frames == 0) {
      debugPrint(
        'frame probe: 0 frames in ${_window.inSeconds}s (idle, as it should be)',
      );
      return;
    }
    final fps = (frames / _window.inSeconds).toStringAsFixed(1);
    final build = (buildMicros / frames / 1000).toStringAsFixed(1);
    final raster = (rasterMicros / frames / 1000).toStringAsFixed(1);
    debugPrint(
      'frame probe: $frames frames in ${_window.inSeconds}s ($fps fps), '
      'build ${build}ms, raster ${raster}ms',
    );
  }
}
