import 'package:device_probe/device_probe.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'device_providers.dart';

/// One moment, reduced to the four numbers the charts draw.
@immutable
class VitalSample {
  const VitalSample({
    required this.atMillis,
    this.busy,
    this.batteryPercent,
    this.freeBytes,
    this.tempDeciC,
  });

  final int atMillis;

  /// 0 to 1. Null on a device that will not report enough of /proc/stat to
  /// compute it, which is a real outcome and not an error.
  final double? busy;

  final int? batteryPercent;
  final int? freeBytes;
  final int? tempDeciC;
}

/// THE LAST FEW MINUTES, kept in Dart.
///
/// ─── WHY NOT ASK THE SAMPLER ─────────────────────────────────────────────────
///
/// It emits one tick at a time and holds no history, which is right: a sampler
/// that buffered would have to decide how much for every consumer, and the home
/// card wants one reading while a chart wants a hundred and twenty.
///
/// ─── WHY A NOTIFIER AND NOT A PROVIDER ───────────────────────────────────────
///
/// Because it accumulates. A derived provider recomputes from its input, and the
/// input here is a single tick with no past, so there is nothing to recompute
/// from. This has to remember.
///
/// ─── IT FILLS ONLY WHILE THE TAB IS OPEN ─────────────────────────────────────
///
/// The sampler is paused everywhere else, so a chart opened cold starts empty
/// and fills left to right over the first minute. That is honest: the app was
/// not watching, and drawing a flat line back to the edge would invent data.
class VitalHistory extends Notifier<List<VitalSample>> {
  /// 120 at 2 Hz is a minute. Enough to see a spike, small enough that keeping
  /// it costs nothing, and the chart draws every point rather than resampling.
  static const int _capacity = 120;

  @override
  List<VitalSample> build() {
    ref.listen<AsyncValue<ProbeTick>>(deviceTickProvider, (
      AsyncValue<ProbeTick>? previous,
      AsyncValue<ProbeTick> next,
    ) {
      final ProbeTick? tick = next.value;
      if (tick == null) return;
      _add(tick);
    });
    return const <VitalSample>[];
  }

  void _add(ProbeTick tick) {
    final DeviceSnapshot current = tick.current;
    final VitalSample sample = VitalSample(
      atMillis: DateTime.now().millisecondsSinceEpoch,
      busy: CpuLoad.busyFraction(tick),
      batteryPercent: current.battery?.percent,
      freeBytes: current.memory?.availBytes,
      tempDeciC: current.battery?.tempDeciC,
    );

    final List<VitalSample> next = <VitalSample>[...state, sample];
    state = next.length <= _capacity
        ? next
        : next.sublist(next.length - _capacity);
  }

  /// Emptied when the user leaves and comes back, so a chart never joins two
  /// separate visits into one continuous line across a gap of minutes.
  void clear() {
    if (state.isEmpty) return;
    state = const <VitalSample>[];
  }
}

final NotifierProvider<VitalHistory, List<VitalSample>> vitalHistoryProvider =
    NotifierProvider<VitalHistory, List<VitalSample>>(VitalHistory.new);

/// The series a chart wants, already extracted and already free of nulls.
///
/// A device that reports battery but not temperature produces a full battery
/// line and no temperature chart at all, rather than a temperature line with
/// holes in it that a reader would take for real dips.
List<double> vitalSeries(
  List<VitalSample> samples,
  double? Function(VitalSample) pick,
) {
  final List<double> out = <double>[];
  for (final VitalSample sample in samples) {
    final double? value = pick(sample);
    if (value != null) out.add(value);
  }
  return out;
}
