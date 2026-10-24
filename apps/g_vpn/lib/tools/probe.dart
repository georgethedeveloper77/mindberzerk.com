import 'dart:async';
import 'dart:io';

/// One TCP "ping": time to complete (or be refused by) a TCP handshake.
///
/// Android apps cannot send ICMP without root. A refused connection (RST)
/// is still a full round trip, so it counts as an answer: that is what lets
/// this time a router, which rarely has the probe port open.
/// Returns null when nothing answered in time.
///
/// [refusedCounts] is off for service checks: a censor's sinkhole often
/// refuses connections, and that must read as "blocked", not "up".
Future<double?> tcpPing(
  String host,
  int port, {
  Duration timeout = const Duration(seconds: 2),
  bool refusedCounts = true,
}) async {
  final watch = Stopwatch()..start();
  try {
    final socket = await Socket.connect(host, port, timeout: timeout);
    watch.stop();
    socket.destroy();
    return watch.elapsedMicroseconds / 1000;
  } on SocketException catch (e) {
    watch.stop();
    final refused = e.osError?.errorCode == 111 || (e.osError?.message.toLowerCase().contains('refused') ?? false);
    return refusedCounts && refused && watch.elapsed < timeout ? watch.elapsedMicroseconds / 1000 : null;
  } on TimeoutException {
    return null;
  }
}

/// Whether a TCP port accepts connections.
Future<bool> isOpen(String host, int port, {Duration timeout = const Duration(milliseconds: 1200)}) async {
  try {
    final socket = await Socket.connect(host, port, timeout: timeout);
    socket.destroy();
    return true;
  } on SocketException {
    return false;
  } on TimeoutException {
    return false;
  }
}

/// Runs [task] over [items] with at most [parallel] in flight.
Future<List<R>> pooled<T, R>(List<T> items, int parallel, Future<R> Function(T) task) async {
  final results = List<R?>.filled(items.length, null);
  var next = 0;
  Future<void> lane() async {
    while (next < items.length) {
      final i = next++;
      results[i] = await task(items[i]);
    }
  }

  await Future.wait(List.generate(parallel, (_) => lane()));
  return results.cast<R>();
}
