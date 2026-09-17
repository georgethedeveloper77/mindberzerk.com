/// A week of measured battery level, recorded by this app.
///
/// ─── WHY THE LAUNCHER HAS TO KEEP ITS OWN ──────────────────────────────────
///
/// The chart the system settings battery screen draws comes from
/// `BatteryStatsManager`, which is `@SystemApi` behind the `BATTERY_STATS`
/// signature permission. No third-party app reads it, on any device, however
/// it asks. So the only honest way to draw that chart is to have watched the
/// level ourselves, which is what this does.
///
/// ─── AND WHY IT IS NOT [StatsHistory] ──────────────────────────────────────
///
/// That buffer is 120 samples at three seconds, six minutes, in memory, and
/// its own doc argues against persisting: writing every three seconds on a
/// budget phone is the kind of thing that shows up in a battery report, and
/// network rates from before the phone was last unlocked are not information
/// anyone wants plotted.
///
/// Both arguments survive, and neither covers this. A row is written when the
/// CHARGE LEVEL CHANGES, roughly a hundred times a day rather than 28,800, and
/// a charge level from yesterday is exactly the thing being asked for.
///
/// ─── WHAT THE GAPS MEAN ────────────────────────────────────────────────────
///
/// Sampling stops with the launcher: screen off, or another app in front, and
/// nothing here runs. So the series is dense while the desktop is in use and
/// empty otherwise, and the chart DRAWS those gaps rather than bridging them.
/// A straight line across eight hours of sleep would be a shape nobody
/// measured, which is the same rule the conky keeps by hiding a module that
/// has no reading instead of printing a placeholder.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/prefs/prefs_repository.dart';
import '../platform/launcher_api.g.dart' as api;
import 'system_stats.dart';

/// One reading: when, how full, and whether it was on a cable.
@immutable
class BatterySample {
  const BatterySample({
    required this.at,
    required this.percent,
    required this.charging,
  });

  final DateTime at;
  final int percent;
  final bool charging;

  /// A three-element list, not an object. Seven days is about 700 rows and the
  /// keys would be two thirds of the file.
  List<Object> toJson() => [
        at.millisecondsSinceEpoch,
        percent,
        charging ? 1 : 0,
      ];

  static BatterySample? fromJson(Object? raw) {
    if (raw is! List || raw.length < 3) return null;
    final ms = raw[0];
    final pct = raw[1];
    if (ms is! num || pct is! num) return null;
    return BatterySample(
      at: DateTime.fromMillisecondsSinceEpoch(ms.toInt()),
      percent: pct.toInt().clamp(0, 100),
      charging: raw[2] == 1,
    );
  }
}

/// One calendar day's measured discharge.
@immutable
class BatteryDay {
  const BatteryDay({required this.date, required this.dischargePercent});

  final DateTime date;

  /// Summed DOWNWARD steps only.
  ///
  /// A day that discharged 40, charged 60 and discharged 30 again used 70, not
  /// 10. Netting the two would report a phone that spent the afternoon on a
  /// cable as barely used, which is the opposite of what the number is for.
  final int dischargePercent;

  /// A day we were never open for is not a day of zero usage. It has no bar.
  bool get measured => dischargePercent > 0;
}

/// How long a reading is kept.
const Duration batteryRetention = Duration(days: 7);

/// The floor between two rows at the SAME level and charging state.
///
/// Without it a phone sitting at 78% all evening writes a row every tick. With
/// it the flat stretches still get a row often enough to prove they happened.
const Duration _minGap = Duration(minutes: 15);

/// How often the recorder asks, while the desktop is on screen.
///
/// Five minutes, against the stats ticker's three seconds. A level chart needs
/// to know the shape of an hour, not of a second, and this is 12 reads an hour
/// rather than 1,200.
const Duration _recordInterval = Duration(minutes: 5);

const String _storeKey = 'battery.history.v1';

class BatteryHistory extends AsyncNotifier<List<BatterySample>> {
  @override
  Future<List<BatterySample>> build() async {
    final store = ref.watch(prefsStoreProvider);
    final raw = await store.read(_storeKey);
    if (raw == null) return const [];

    try {
      final list = (jsonDecode(raw) as List)
          .map(BatterySample.fromJson)
          .whereType<BatterySample>()
          .toList();
      return _pruned(list);
    } catch (_) {
      // A corrupt history costs a chart, never the page. Same contract as
      // `PrefsRepository.load`.
      return const [];
    }
  }

  /// Offer a reading. Most are dropped, which is the point.
  ///
  /// Takes the snapshot the app already has rather than reading the battery
  /// itself, so the Power page's own three-second ticker feeds this for free
  /// while it is open and the recorder below covers the rest.
  Future<void> offer(SystemStats stats) async {
    final percent = stats.batteryPercent;
    final charging = stats.batteryCharging;
    if (percent == null || charging == null) return;
    if (!state.hasValue) return;

    final now = DateTime.now();
    final current = state.requireValue;
    final last = current.isEmpty ? null : current.last;

    final unchanged = last != null &&
        last.percent == percent &&
        last.charging == charging &&
        now.difference(last.at) < _minGap;
    if (unchanged) return;

    // A clock moved backwards (timezone, manual set) would otherwise put a
    // sample before one already stored and break every day bucket after it.
    if (last != null && now.isBefore(last.at)) return;

    final next = _pruned([
      ...current,
      BatterySample(at: now, percent: percent, charging: charging),
    ]);

    state = AsyncData(next);
    await ref
        .read(prefsStoreProvider)
        .write(_storeKey, jsonEncode([for (final s in next) s.toJson()]));
  }

  /// Everything recorded on one calendar day, oldest first.
  List<BatterySample> samplesOn(DateTime day) {
    if (!state.hasValue) return const [];
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return [
      for (final s in state.requireValue)
        if (!s.at.isBefore(start) && s.at.isBefore(end)) s,
    ];
  }

  /// The last [days] days, oldest first, today last.
  List<BatteryDay> dailyUsage({int days = 7}) {
    final today = DateTime.now();
    final midnight = DateTime(today.year, today.month, today.day);

    return [
      for (var i = days - 1; i >= 0; i--)
        () {
          final date = midnight.subtract(Duration(days: i));
          final samples = samplesOn(date);
          var used = 0;
          for (var j = 1; j < samples.length; j++) {
            final drop = samples[j - 1].percent - samples[j].percent;
            if (drop > 0) used += drop;
          }
          return BatteryDay(date: date, dischargePercent: used);
        }(),
    ];
  }

  Future<void> clear() async {
    state = const AsyncData([]);
    await ref.read(prefsStoreProvider).delete(_storeKey);
  }

  static List<BatterySample> _pruned(List<BatterySample> samples) {
    final cutoff = DateTime.now().subtract(batteryRetention);
    return [
      for (final s in samples)
        if (s.at.isAfter(cutoff)) s,
    ];
  }
}

final batteryHistoryProvider =
    AsyncNotifierProvider<BatteryHistory, List<BatterySample>>(
  BatteryHistory.new,
);

/// The five-minute tick that fills the chart in.
///
/// ─── WHY IT DOES NOT LISTEN TO [systemStatsProvider] ───────────────────────
///
/// That would be free on a distro whose panel already carries readouts, and it
/// would START a three-second poll on every distro whose panel does not, which
/// is most of them. Recording a number that changes about a hundred times a
/// day must not turn on a ticker that fires 1,200 times an hour.
///
/// ─── AND WHY IT PAUSES WITH THE APP ────────────────────────────────────────
///
/// Same reason [systemStatsProvider] does, and it is the whole argument that
/// makes this affordable: a phone in a pocket costs nothing, because the
/// launcher is not running while the screen is off.
class BatteryRecorder {
  BatteryRecorder(this._ref);

  final Ref _ref;
  final _host = api.LauncherHostApi();

  Timer? _timer;
  AppLifecycleListener? _lifecycle;
  bool _reading = false;

  void start() {
    _lifecycle = AppLifecycleListener(
      onPause: _stop,
      onHide: _stop,
      onResume: () {
        _startTimer();
        unawaited(_tick());
      },
    );
    _startTimer();
    unawaited(_tick());
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(_recordInterval, (_) => unawaited(_tick()));
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _tick() async {
    if (_reading) return;
    _reading = true;
    try {
      final raw = await _host.readStats();
      final percent = raw.batteryPercent;
      if (percent == null) return;

      await _ref.read(batteryHistoryProvider.notifier).offer(
            SystemStats(
              batteryPercent: percent.toInt(),
              batteryCharging: raw.batteryCharging,
            ),
          );
    } catch (e) {
      // A failed bridge call costs one reading. The next one is in five
      // minutes and nothing on screen depends on this having succeeded.
      debugPrint('battery history: read failed ($e)');
    } finally {
      _reading = false;
    }
  }

  void dispose() {
    _stop();
    _lifecycle?.dispose();
  }
}

/// Alive for as long as the desktop is. Watched in `HomeScreen`, which is the
/// one place every shell passes through.
final batteryRecorderProvider = Provider<BatteryRecorder>((ref) {
  final recorder = BatteryRecorder(ref);
  ref.onDispose(recorder.dispose);
  recorder.start();
  return recorder;
});
