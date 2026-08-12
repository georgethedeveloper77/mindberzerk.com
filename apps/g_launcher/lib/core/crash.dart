/// The launcher's crash surface.
///
/// **One file, one switch, no call sites that can throw.** Same discipline as
/// `analytics.dart`: every path into Crashlytics goes through here, so there is
/// exactly one place that knows whether reporting is live and exactly one place
/// that swallows a reporting failure.
///
/// ─── WHY THIS CANNOT JUST CALL FirebaseCrashlytics.instance ─────────────────
///
/// `main.dart` deliberately lets Firebase init FAIL and carries on, because this
/// is the home screen and a phone that cannot reach its desktop because
/// telemetry would not start is a bricked phone. That is the right call and it
/// has a consequence: on a de-Googled ROM, or a device with Play Services
/// disabled, `FirebaseCrashlytics.instance` throws on first touch.
///
/// So an unguarded `recordError` inside an error handler would throw FROM the
/// error handler, on exactly the devices the try/catch in `main` exists to
/// protect, and the second throw is the one that takes the launcher down. The
/// [_live] guard is not defensive style. It is the whole reason this file is a
/// wrapper rather than three direct calls.
///
/// ─── WHY THERE IS AN EARLY BUFFER ───────────────────────────────────────────
///
/// [enable] cannot run until Firebase is up, and Firebase cannot come up until
/// after `bootstrap()`. Everything between those two points (the binding, the
/// prefs read, the i18n load) is unreported, and a failure there is a launcher
/// that never draws a first frame, which is the single worst bug this app can
/// have and the one we would have been blind to. [installEarly] takes the
/// handlers immediately and holds what it catches until there is somewhere to
/// send it.
library;

import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

abstract final class Crash {
  /// True once Firebase is up AND Crashlytics has accepted its handlers.
  /// Every public method below is a no-op while this is false.
  static bool _live = false;

  /// Errors caught by [installEarly] before [enable] could run. Bounded: if
  /// startup is failing in a loop, the last thing anyone needs is an unbounded
  /// list of identical stacks in a process that is already in trouble.
  static final List<_Pending> _pending = <_Pending>[];
  static const int _maxPending = 8;

  /// Keys set before Crashlytics was live, replayed by [enable].
  static final Map<String, Object> _pendingKeys = <String, Object>{};

  static bool get isLive => _live;

  // ---- installation ------------------------------------------------------

  /// Take the error handlers NOW, before Firebase exists.
  ///
  /// Called from `bootstrap()`. Anything caught here is buffered and flushed by
  /// [enable]; if [enable] never runs (no Play Services), the buffer is simply
  /// dropped at the end of the process, which is the correct outcome on a
  /// device that has nowhere to send it.
  ///
  /// [FlutterError.presentError] is still called for every error, so the red
  /// screen and the console output behave exactly as they did before this file
  /// existed. Reporting is additive; it never replaces the debug experience.
  static void installEarly() {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      _capture(details.exception, details.stack, 'FlutterError', false);
    };

    // Async errors that escape a Future with no catch. Since Flutter 3.3 this
    // is the supported hook and it makes `runZonedGuarded` unnecessary, which
    // matters here: `main` awaits three things before `runApp`, and wrapping
    // that in a guarded zone means the binding and the app can end up in
    // different zones, which breaks platform channel completion in ways that
    // look exactly like a freeze.
    PlatformDispatcher.instance.onError = (error, stack) {
      _capture(error, stack, 'PlatformDispatcher', true);
      return true;
    };
  }

  /// Firebase is up. Turn reporting on and flush anything held.
  ///
  /// Called ONLY from the successful branch of Firebase init. Wrapped anyway,
  /// because `setCrashlyticsCollectionEnabled` reaches the native SDK and a
  /// half-initialised Play Services can fail there even when `initializeApp`
  /// returned cleanly.
  static Future<void> enable() async {
    try {
      final crashlytics = FirebaseCrashlytics.instance;

      // Off in debug. A hot restart, a deliberate `throw` while wiring a
      // screen, and every red-screen layout overflow would otherwise land in
      // the same dashboard as real field crashes, and a dashboard nobody
      // trusts is a dashboard nobody reads.
      await crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);

      _live = true;

      for (final e in _pendingKeys.entries) {
        await crashlytics.setCustomKey(e.key, e.value);
      }
      _pendingKeys.clear();

      for (final p in _pending) {
        await crashlytics.recordError(
          p.error,
          p.stack,
          reason: p.reason,
          fatal: p.fatal,
        );
      }
      _pending.clear();
    } catch (e) {
      // Reporting is optional; the desktop is not. Same rule as _initFirebase.
      debugPrint('crashlytics: enable failed, reporting stays off ($e)');
      _live = false;
    }
  }

  // ---- reporting ---------------------------------------------------------

  /// Report a non-fatal.
  ///
  /// [fatal] false by default and that is deliberate: nothing this launcher
  /// catches deliberately is fatal, and marking handled errors fatal ruins the
  /// crash-free-users number, which is the one metric Play surfaces to users.
  static void record(
    Object error,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
  }) =>
      _capture(error, stack, reason, fatal);

  /// A breadcrumb. Shows up in the log attached to the NEXT report, which is
  /// what makes a stack from deep inside the framework locatable.
  ///
  /// Cheap enough to call on navigation and on every pack install, and no more
  /// than that. Crashlytics keeps a rolling 64KB of log; a breadcrumb per frame
  /// would push out the ones that matter.
  static void log(String message) {
    if (!_live) return;
    try {
      FirebaseCrashlytics.instance.log(message);
    } catch (_) {
      // Silence by design. A breadcrumb that cannot be written is not worth a
      // second failure path.
    }
  }

  /// Attach state to every subsequent report.
  ///
  /// The launcher's freezes are a state problem rather than a stack problem:
  /// the same stack inside the icon cache means something different with 261
  /// apps than with 40, and something different again on the TUI shell than on
  /// GNOME. These keys are what turn a report into a reproduction.
  ///
  /// Buffered when called before [enable], so a key set during startup is not
  /// lost just because it was set early.
  static void setKey(String key, Object value) {
    if (!_live) {
      _pendingKeys[key] = value;
      return;
    }
    try {
      FirebaseCrashlytics.instance.setCustomKey(key, value);
    } catch (_) {
      // As above.
    }
  }

  /// The state worth knowing on every report, set in one call.
  ///
  /// Named rather than free-form for the reason `analytics.dart` gives about
  /// event names: a key spelled `shell` in one place and `shellId` in another
  /// splits the same field into two columns and neither is complete.
  static void setContext({
    String? shell,
    String? themeId,
    int? appCount,
    int? drawerPage,
  }) {
    if (shell != null) setKey('shell', shell);
    if (themeId != null) setKey('theme_id', themeId);
    if (appCount != null) setKey('app_count', appCount);
    if (drawerPage != null) setKey('drawer_page', drawerPage);
  }

  // ---- internals ---------------------------------------------------------

  static void _capture(
    Object error,
    StackTrace? stack,
    String? reason,
    bool fatal,
  ) {
    if (!_live) {
      if (_pending.length < _maxPending) {
        _pending.add(_Pending(error, stack, reason, fatal));
      }
      return;
    }
    try {
      FirebaseCrashlytics.instance.recordError(
        error,
        stack,
        reason: reason,
        fatal: fatal,
      );
    } catch (e) {
      debugPrint('crashlytics: record failed ($e)');
    }
  }
}

@immutable
class _Pending {
  const _Pending(this.error, this.stack, this.reason, this.fatal);
  final Object error;
  final StackTrace? stack;
  final String? reason;
  final bool fatal;
}
