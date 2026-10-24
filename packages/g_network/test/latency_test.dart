import 'package:flutter_test/flutter_test.dart';
import 'package:g_network/g_network.dart';

void main() {
  test('median, jitter and loss from mixed samples', () {
    final r = LatencyResult.fromSamples([20, 30, null, 25, 35]);
    expect(r.medianMs, 27.5);
    // Consecutive successful diffs: 10, 5, 10.
    expect(r.jitterMs, closeTo(8.333, 0.001));
    expect(r.lossPercent, 20);
  });

  test('all failed reports null timings and full loss', () {
    final r = LatencyResult.fromSamples([null, null]);
    expect(r.medianMs, isNull);
    expect(r.jitterMs, isNull);
    expect(r.lossPercent, 100);
  });

  test('one sample has a median but no jitter', () {
    final r = LatencyResult.fromSamples([42]);
    expect(r.medianMs, 42);
    expect(r.jitterMs, isNull);
  });
}
