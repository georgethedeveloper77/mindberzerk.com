/// Reports how the PREVIOUS process died.
///
/// ─── THE GAP: SIX KILLS THAT PRODUCED NO REPORT AT ALL ──────────────────────
///
/// `freeze_watchdog.dart` reasoned correctly that a freeze is not a crash, and
/// built a detector for the case where the isolate blocks and then recovers.
/// The real failure on this device was one layer further out: the launcher was
/// not blocking, it was being KILLED. Six `reason=3 (LOW_MEMORY)` exits in
/// fourteen hours at RSS values up to 778MB, plus one
/// `EXCESSIVE_RESOURCE_USAGE` for burning CPU while the process was empty.
///
/// A kill produces no throw, no stack, no ANR and no catchable signal. The
/// watchdog's own timer dies with the isolate mid-beat. Crashlytics reported
/// nothing, which was correct, and the entire episode was invisible until
/// someone ran `dumpsys activity exit-info` by hand.
///
/// `ExitInfoBridge` on the native side reads the system's own record of the
/// death, which survives precisely because the SYSTEM keeps it rather than the
/// process. This file turns each record into a non-fatal.
///
/// ─── WHY THE TYPE CARRIES THE REASON AND THE MESSAGE CARRIES THE NUMBERS ────
///
/// Crashlytics groups by the thrown type's `toString()`. Putting the RSS in
/// there would scatter one problem across as many issues as there are distinct
/// megabyte values, which is the exact mistake `_MainIsolateStall` in
/// `freeze_watchdog.dart` documents avoiding. So the type is
/// `ProcessKilled(low_memory)` and everything variable rides the breadcrumb
/// log, where it stays readable and stays grouped.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'crash.dart';

abstract final class ExitInfo {
  static const MethodChannel _channel = MethodChannel('g_launcher/exit_info');

  /// At most this many reports per launch.
  ///
  /// The native side returns at most sixteen, and a device that is thrashing
  /// will hand over all sixteen on a single cold start. Six is enough to see a
  /// pattern and few enough that a bad night does not spend the user's data
  /// telling us the same thing sixteen times. The count of what was dropped
  /// goes in the breadcrumb, so the cap is never silent.
  static const int _maxReports = 6;

  /// Drain and report. Call AFTER `Crash.enable()`.
  ///
  /// The ordering is load-bearing rather than tidy: `Crash.log` is a hard no-op
  /// while reporting is off, so a breadcrumb written before `enable` is not
  /// buffered like a report is, it is simply gone. Called earlier, every one of
  /// these would arrive as a bare exception with none of its numbers.
  ///
  /// Never rethrows. This is diagnostics running on the startup path of a home
  /// screen, and it must not be able to be the reason a desktop does not draw.
  static Future<void> reportPending() async {
    if (!Crash.isLive) return;

    // ── THE WATERMARK MUST NOT MOVE IN DEBUG ────────────────────────────
    //
    // `Crash.enable` sets `_live` true but turns COLLECTION off in debug, so
    // everything below runs and lands nowhere. The native side's watermark
    // would still advance, and since the system holds only sixteen exits and
    // does not refill on demand, one `flutter run` would consume the whole
    // record of a bad night before a release build could report it.
    //
    // So debug reads without committing and prints to the console instead,
    // which is also how you verify the bridge is wired at all.
    const commit = !kDebugMode;

    final List<Object?> records;
    try {
      records = await _channel.invokeMethod<List<Object?>>(
            'drain',
            <String, Object?>{'commit': commit},
          ) ??
          const <Object?>[];
    } catch (e) {
      // MissingPluginException on a build where the bridge is not registered,
      // and anything the platform throws below API 30. Both are ordinary.
      debugPrint('exit-info: drain unavailable ($e)');
      return;
    }

    if (records.isEmpty) return;

    if (!commit) {
      for (final raw in records) {
        if (raw is! Map) continue;
        debugPrint(
          'exit-info: ${raw['reasonName']} rss=${_mb(_int(raw['rssBytes']))} '
          'at ${_stamp(_int(raw['timestampMs']))} ${raw['description'] ?? ''}',
        );
      }
      debugPrint(
        'exit-info: ${records.length} record(s) read, watermark NOT advanced '
        '(debug build, Crashlytics collection is off)',
      );
      return;
    }

    final dropped = records.length - _maxReports;
    for (final raw in records.take(_maxReports)) {
      if (raw is! Map) continue;
      _report(Map<Object?, Object?>.from(raw), dropped);
    }
  }

  static void _report(Map<Object?, Object?> record, int dropped) {
    final reason = record['reasonName'] as String? ?? 'unknown';
    final rss = _int(record['rssBytes']);
    final pss = _int(record['pssBytes']);
    final importance = _int(record['importance']);
    final description = record['description'] as String?;
    final at = _int(record['timestampMs']);

    // Breadcrumbs first: Crashlytics attaches the log as it stands when the
    // report is filed, so anything written after `record` lands on the NEXT
    // one instead.
    Crash.log('exit: $reason at ${_stamp(at)}');
    Crash.log('exit: rss=${_mb(rss)} pss=${_mb(pss)} importance=$importance');
    if (description != null && description.isNotEmpty) {
      Crash.log('exit: $description');
    }
    if (dropped > 0) {
      Crash.log('exit: $dropped older exits not reported this launch');
    }

    // The trace exists only for ANR and native crashes. When it does exist it
    // is the single most useful thing in the record, because it names the
    // thread that was blocking, which is the one thing the freeze watchdog
    // openly admits it cannot tell us.
    final trace = record['trace'] as String?;
    if (trace != null && trace.isNotEmpty) {
      for (final line in _head(trace, 40)) {
        Crash.log('trace: $line');
      }
    }

    Crash.record(
      _ProcessKilled(reason),
      StackTrace.empty,
      reason: 'previous process exited: $reason, rss ${_mb(rss)}',
    );
  }

  /// The first [n] non-blank lines. The native side already truncates to 16KB;
  /// this is a second cut because Crashlytics keeps a rolling 64KB of log and a
  /// full thread dump would evict every other breadcrumb on the report.
  static Iterable<String> _head(String trace, int n) => trace
      .split('\n')
      .map((l) => l.trimRight())
      .where((l) => l.isNotEmpty)
      .take(n);

  static int? _int(Object? v) => v is int ? v : null;

  static String _mb(int? bytes) =>
      bytes == null ? 'unknown' : '${(bytes / (1024 * 1024)).round()}MB';

  static String _stamp(int? ms) => ms == null
      ? 'unknown'
      : DateTime.fromMillisecondsSinceEpoch(ms).toIso8601String();
}

/// A process the system ended.
///
/// Named per REASON and nothing else, so every low-memory kill lands in one
/// issue with a count on it rather than one issue per distinct RSS. Same rule
/// as `_MainIsolateStall`, and it matters more here: this is the type whose
/// count is the number we are trying to drive down.
@immutable
class _ProcessKilled implements Exception {
  const _ProcessKilled(this.reason);
  final String reason;

  @override
  String toString() => 'ProcessKilled($reason)';
}
