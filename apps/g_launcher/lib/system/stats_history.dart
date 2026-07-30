import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'system_stats.dart';

/// A short rolling history of [SystemStats], so a chart has something to draw.
///
/// ─── WHY THIS EXISTS SEPARATELY ─────────────────────────────────────────────
///
/// [systemStatsProvider] is a stream of SNAPSHOTS. Everything that read it
/// until now wanted one number: the conky prints the current rate, the settings
/// row prints the current charge. A line chart wants the last two minutes, and
/// nothing was keeping them.
///
/// Kept in memory only, and deliberately not persisted. Network rates from
/// before the phone was last unlocked are not information anyone wants plotted,
/// and writing a sample to disk every three seconds on a budget device is the
/// kind of thing that shows up in a battery report.
///
/// ─── THE BUFFER IS SMALL ON PURPOSE ─────────────────────────────────────────
///
/// [capacity] samples at the poller's three-second interval is about six
/// minutes, which is the range over which "is something downloading right now"
/// is answerable. A longer window would need a real time axis, downsampling,
/// and a decision about what to do across the pause when the screen was off,
/// and none of that makes the answer better.
@immutable
class StatsSample {
  const StatsSample({
    this.downBytesPerSec,
    this.upBytesPerSec,
    this.batteryPercent,
    this.batteryTempC,
    this.batteryCurrentMa,
  });

  final double? downBytesPerSec;
  final double? upBytesPerSec;
  final int? batteryPercent;
  final double? batteryTempC;
  final int? batteryCurrentMa;

  factory StatsSample.of(SystemStats s) => StatsSample(
        downBytesPerSec: s.netDownBytesPerSec,
        upBytesPerSec: s.netUpBytesPerSec,
        batteryPercent: s.batteryPercent,
        batteryTempC: s.batteryTempC,
        batteryCurrentMa: s.batteryCurrentMa,
      );
}

@immutable
class StatsSeries {
  const StatsSeries(this.samples);

  const StatsSeries.empty() : samples = const [];

  /// Oldest first, so index doubles as the x axis with no arithmetic.
  final List<StatsSample> samples;

  static const int capacity = 120;

  bool get isEmpty => samples.isEmpty;

  /// A chart of one point is a dot. Two is the minimum that draws a line, and
  /// waiting for four meant twelve seconds of a page that looked like it had no
  /// chart at all, which is indistinguishable from the feature being missing.
  bool get chartable => samples.length >= 2;

  StatsSeries push(StatsSample s) {
    final next = samples.length >= capacity
        ? [...samples.sublist(samples.length - capacity + 1), s]
        : [...samples, s];
    return StatsSeries(next);
  }

  /// The series for one field, with gaps DROPPED rather than zeroed.
  ///
  /// A null rate means the sample could not be measured (the first tick after a
  /// resume has no previous counter to subtract). Plotting that as zero draws a
  /// spike down to the axis and invents a moment where the network stopped,
  /// which is the same class of lie as a conky printing `cpu --%`.
  List<double> series(double? Function(StatsSample) pick) {
    final out = <double>[];
    for (final s in samples) {
      final v = pick(s);
      if (v != null) out.add(v);
    }
    return out;
  }
}

/// Accumulates [systemStatsProvider] into a rolling window.
///
/// Listens rather than watches: watching would rebuild this notifier and throw
/// its own buffer away on every sample, which is the opposite of a history.
class StatsHistory extends Notifier<StatsSeries> {
  @override
  StatsSeries build() {
    ref.listen(systemStatsProvider, (_, next) {
      // hasValue, not asData, for the same reason as everywhere else: a
      // provider in flight still carries its previous value and asData is null
      // through it. Here it would simply drop samples rather than corrupt
      // anything, but dropping samples is what this class exists to prevent.
      if (!next.hasValue) return;
      state = state.push(StatsSample.of(next.requireValue));
    });

    return const StatsSeries.empty();
  }
}

final statsHistoryProvider =
    NotifierProvider<StatsHistory, StatsSeries>(StatsHistory.new);
