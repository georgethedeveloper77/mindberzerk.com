import 'device_sampler.dart';

/// Rate arithmetic over a [ProbeTick].
///
/// Kept out of the UI because it has one genuinely subtle case: `/proc/stat`
/// counters are monotonic until they are not. A core coming online, a governor
/// reset, or a container boundary can make the total go backwards, and the naive
/// subtraction then produces a negative denominator and a nonsense percentage
/// that renders as a full bar.
class CpuLoad {
  const CpuLoad._();

  /// Busy fraction, 0 to 1, or null when this device does not serve
  /// `/proc/stat`, when the tick has no predecessor, or when the counters moved
  /// backwards.
  ///
  /// Null is three different situations on purpose: all three mean "do not draw
  /// a number", and the capability flag is what distinguishes permanently
  /// absent from merely pending.
  static double? busyFraction(ProbeTick tick) {
    final int? currentIdle = tick.current.cpu?.idleJiffies;
    final int? currentTotal = tick.current.cpu?.totalJiffies;
    final int? previousIdle = tick.previous?.cpu?.idleJiffies;
    final int? previousTotal = tick.previous?.cpu?.totalJiffies;

    if (currentIdle == null ||
        currentTotal == null ||
        previousIdle == null ||
        previousTotal == null) {
      return null;
    }

    final int totalDelta = currentTotal - previousTotal;
    final int idleDelta = currentIdle - previousIdle;
    if (totalDelta <= 0 || idleDelta < 0 || idleDelta > totalDelta) return null;

    return (totalDelta - idleDelta) / totalDelta;
  }

  /// Mean of the readable core frequencies in kHz, or null when none are.
  ///
  /// A mean across clusters is not a meaningful physical quantity, so this is
  /// for a single glance figure only. Anything that matters reads the per
  /// cluster values.
  static double? meanKhz(ProbeTick tick) {
    final List<int?>? cores = tick.current.cpu?.coreKhz;
    if (cores == null) return null;
    final List<int> readable = cores.whereType<int>().toList();
    if (readable.isEmpty) return null;
    return readable.reduce((int a, int b) => a + b) / readable.length;
  }
}
