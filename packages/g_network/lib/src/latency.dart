import 'dart:async';
import 'dart:io';

/// Round-trip results from repeated TCP connects.
class LatencyResult {
  const LatencyResult({
    required this.medianMs,
    required this.jitterMs,
    required this.lossPercent,
    required this.samples,
  });

  /// Null when every attempt failed.
  final double? medianMs;
  final double? jitterMs;
  final double lossPercent;
  final int samples;

  /// Pure maths, split out so it is testable without a network.
  ///
  /// Jitter is the mean absolute difference between CONSECUTIVE successful
  /// samples (the RFC 3550 idea, unsmoothed). Standard deviation would punish
  /// a stable but slow link, which is not what a caller feels as jitter.
  factory LatencyResult.fromSamples(List<double?> samples) {
    final ok = samples.whereType<double>().toList();
    final loss = samples.isEmpty ? 0.0 : (samples.length - ok.length) * 100 / samples.length;
    if (ok.isEmpty) {
      return LatencyResult(medianMs: null, jitterMs: null, lossPercent: loss, samples: samples.length);
    }
    final sorted = [...ok]..sort();
    final mid = sorted.length ~/ 2;
    final median = sorted.length.isOdd ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2;
    double? jitter;
    if (ok.length > 1) {
      var sum = 0.0;
      for (var i = 1; i < ok.length; i++) {
        sum += (ok[i] - ok[i - 1]).abs();
      }
      jitter = sum / (ok.length - 1);
    }
    return LatencyResult(medianMs: median, jitterMs: jitter, lossPercent: loss, samples: samples.length);
  }
}

/// Measures latency with TCP connects, because Android apps cannot send ICMP
/// pings without root. A TCP handshake is one round trip, so the timing maps
/// closely to what `ping` would show, and it travels through the VPN when one
/// is up, which is exactly the path the user cares about.
///
/// The default target is Cloudflare's anycast resolver on 443: nearby almost
/// everywhere and reliably open.
Future<LatencyResult> measureLatency({
  String host = '1.1.1.1',
  int port = 443,
  int count = 10,
  Duration timeout = const Duration(seconds: 2),
  Duration spacing = const Duration(milliseconds: 150),
}) async {
  final samples = <double?>[];
  for (var i = 0; i < count; i++) {
    final watch = Stopwatch()..start();
    try {
      final socket = await Socket.connect(host, port, timeout: timeout);
      watch.stop();
      socket.destroy();
      samples.add(watch.elapsedMicroseconds / 1000);
    } on SocketException {
      samples.add(null);
    } on TimeoutException {
      samples.add(null);
    }
    if (i < count - 1) await Future<void>.delayed(spacing);
  }
  return LatencyResult.fromSamples(samples);
}
