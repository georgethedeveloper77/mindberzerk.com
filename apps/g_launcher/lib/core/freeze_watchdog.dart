/// Turns "it froze once" into a report with a number on it.
///
/// ─── WHY CRASHLYTICS ALONE DOES NOT ANSWER THE BUG ──────────────────────────
///
/// A freeze is not a crash. Nothing throws, no stack unwinds, and the process
/// is perfectly healthy right up until Android decides it has waited long
/// enough and files an ANR. Crashlytics does collect Android ANRs, but only
/// once the system raises one (five seconds of unresponded input, and only if
/// the user was pressing something), and the stack it hands back is the native
/// main thread, which for a Flutter app is almost always parked in the message
/// loop with nothing to say about which Dart code is at fault.
///
/// So the observed symptom, a launcher that stops responding for a few seconds
/// and then recovers, produces no crash, no ANR, and no report at all. That is
/// the gap this file closes.
///
/// ─── THE TWO SIGNALS, AND WHY BOTH ──────────────────────────────────────────
///
/// EVENT LOOP LAG catches a blocked main isolate. A periodic timer that should
/// fire every second and fires four seconds late was not late: the isolate was
/// busy, and nothing else could run either. This is the signal that fires for
/// synchronous Dart work and for a platform channel reply that never came, and
/// it fires whether or not anything was being drawn.
///
/// FRAME STALL catches a slow frame that did not block the isolate. Timers
/// still run, so lag stays clean, but the user is looking at a screen that has
/// not moved. `FrameTiming` also splits build from raster, and that split is
/// the most useful single fact in the whole report: build-heavy points at Dart
/// (the icon cache, a provider rebuilding the world), raster-heavy points at
/// the GPU (shader compilation, the transparent surface a launcher is obliged
/// to use, a blur over a large area).
///
/// ─── WHAT THIS HONESTLY CANNOT DO ───────────────────────────────────────────
///
/// It cannot tell you WHERE. By the time either signal fires, the block is
/// over, so `StackTrace.current` points at this file and nothing else. There is
/// no Dart API to sample the stack of a blocked isolate from within the same
/// isolate; that would need an out-of-process profiler.
///
/// What it gives instead is: the freeze is real, it lasted this long, it was
/// build-bound or raster-bound, and here are the breadcrumbs and custom keys
/// from the moment it happened. For the two main-thread offenders already known
/// in this codebase (the unbounded icon disk cache, and `IconCache.get` walking
/// the cache on the main thread) that is enough to convict, because both leave
/// a breadcrumb trail and both scale with app count, which is a custom key.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import 'crash.dart';

abstract final class FreezeWatchdog {
  static Timer? _timer;
  static bool _running = false;

  /// How often the heartbeat fires. Short enough to catch a two second stall,
  /// long enough that the timer itself is free.
  static const Duration _beat = Duration(seconds: 1);

  /// Lateness past which the isolate was genuinely blocked rather than merely
  /// busy. Timers are best-effort and a hundred milliseconds of drift is normal
  /// under load; two full seconds is not, and it is under Android's own five
  /// second ANR threshold, so this fires BEFORE the system would.
  static const Duration _lagThreshold = Duration(seconds: 2);

  /// A single frame this slow is a visible hitch, not jank. Ordinary dropped
  /// frames are 16 to 100ms and reporting those would produce thousands of
  /// events that say only "phones are slow sometimes".
  static const Duration _frameThreshold = Duration(milliseconds: 700);

  /// At most one report per minute, and a hard session cap.
  ///
  /// Both are load-bearing. A device that stalls once usually stalls in a
  /// cluster (a page of icons all missing the cache at once), and without this
  /// a single bad scroll files forty identical non-fatals, which burns the
  /// user's battery and data to tell us one thing forty times.
  static const Duration _minGap = Duration(minutes: 1);
  static const int _sessionCap = 12;

  static DateTime? _lastReport;
  static int _reports = 0;

  static DateTime _expected = DateTime.now();

  /// Start watching. Safe to call twice; the second call does nothing.
  ///
  /// Called after Crashlytics is live. Starting it earlier would only buffer
  /// reports about a startup that is, by definition, still running.
  static void start() {
    if (_running) return;
    _running = true;

    _expected = DateTime.now().add(_beat);
    _timer = Timer.periodic(_beat, _onBeat);

    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _running = false;
  }

  // ---- event loop lag ----------------------------------------------------

  static void _onBeat(Timer _) {
    final now = DateTime.now();
    final lateBy = now.difference(_expected);
    _expected = now.add(_beat);

    if (lateBy < _lagThreshold) return;

    // ── THE LIFECYCLE CHECK IS NOT OPTIONAL FOR A LAUNCHER ──────────────
    //
    // Being backgrounded is the NORMAL state of a launcher: every app the user
    // opens puts this process behind it, Android stops delivering frames, and
    // timers are throttled or frozen outright by Doze. Without this check the
    // watchdog would report a multi-second stall every single time the user
    // opened WhatsApp, and the dashboard would show a thousand freezes a day
    // that are simply the operating system working correctly.
    //
    // Read from the binding rather than tracked with an observer, because an
    // observer registered here would need a widget to own it and this is not a
    // widget.
    final state = SchedulerBinding.instance.lifecycleState;
    if (state != AppLifecycleState.resumed) return;

    _report(
      _MainIsolateStall(lateBy),
      'main isolate blocked for ${lateBy.inMilliseconds}ms',
    );
  }

  // ---- frame stalls ------------------------------------------------------

  static void _onTimings(List<FrameTiming> timings) {
    // The WORST frame in the batch, not each of them. A stutter delivers
    // several timings at once and they are one event to the person who saw it.
    FrameTiming? worst;
    for (final t in timings) {
      if (worst == null || t.totalSpan > worst.totalSpan) worst = t;
    }
    if (worst == null) return;
    if (worst.totalSpan < _frameThreshold) return;

    final build = worst.buildDuration;
    final raster = worst.rasterDuration;
    final bound = build >= raster ? 'build' : 'raster';

    _report(
      _FrameStall(worst.totalSpan, bound),
      'frame ${worst.totalSpan.inMilliseconds}ms '
      '($bound bound: build ${build.inMilliseconds}ms, '
      'raster ${raster.inMilliseconds}ms)',
    );
  }

  // ---- reporting ---------------------------------------------------------

  static void _report(Object error, String reason) {
    if (_reports >= _sessionCap) return;

    final now = DateTime.now();
    final last = _lastReport;
    if (last != null && now.difference(last) < _minGap) return;

    _lastReport = now;
    _reports++;

    // Debug gets the console line and nothing else. Crash.record already
    // no-ops when collection is off, but printing here is what makes the
    // watchdog useful while developing, which is where most of these will be
    // caught before a user ever sees one.
    if (kDebugMode) debugPrint('freeze-watchdog: $reason');

    Crash.record(error, StackTrace.current, reason: reason);
  }
}

/// A blocked main isolate.
///
/// A named type rather than a string, because Crashlytics groups by the thrown
/// type: this keeps every stall in one issue with a count, instead of scattering
/// them across as many issues as there are distinct millisecond values.
@immutable
class _MainIsolateStall implements Exception {
  const _MainIsolateStall(this.lateBy);
  final Duration lateBy;

  @override
  String toString() => 'MainIsolateStall(${lateBy.inMilliseconds}ms)';
}

/// A single frame far over budget. Grouped by what it was bound on, so a
/// shader compilation problem and an icon cache problem do not land in the same
/// issue and cancel each other out.
@immutable
class _FrameStall implements Exception {
  const _FrameStall(this.span, this.bound);
  final Duration span;
  final String bound;

  @override
  String toString() => 'FrameStall($bound)';
}
