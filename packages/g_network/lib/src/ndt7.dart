import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

/// M-Lab ndt7 speed test over WebSockets, in pure Dart.
///
/// Spec: github.com/m-lab/ndt-server/blob/main/spec/ndt7-protocol.md
///
/// PRIVACY: M-Lab publishes every test, including the client IP address, as
/// open research data. The app MUST show that before the first test; this
/// class does not ask, it only measures.
enum SpeedPhase { locating, download, upload, done }

class SpeedServer {
  const SpeedServer({this.city, this.country, required this.machine});

  final String? city;
  final String? country;
  final String machine;
}

class SpeedProgress {
  const SpeedProgress({
    required this.phase,
    this.mbps = 0,
    this.server,
    this.downloadMbps,
    this.uploadMbps,
    this.minRttMs,
  });

  final SpeedPhase phase;

  /// The live rate of the current phase.
  final double mbps;
  final SpeedServer? server;

  /// Final figures, filled in as each phase completes.
  final double? downloadMbps;
  final double? uploadMbps;

  /// Lowest TCP round trip the server observed during download, in ms.
  final double? minRttMs;
}

class SpeedTestException implements Exception {
  const SpeedTestException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Pulls the fields we use out of one server measurement message.
class Ndt7Measurement {
  const Ndt7Measurement({this.appBytes, this.appElapsedUs, this.minRttUs});

  final int? appBytes;
  final int? appElapsedUs;
  final int? minRttUs;

  static Ndt7Measurement? tryParse(String text) {
    final Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException {
      return null;
    }
    if (json is! Map) return null;
    final app = json['AppInfo'];
    final tcp = json['TCPInfo'];
    int? asInt(Object? v) => v is num ? v.toInt() : null;
    return Ndt7Measurement(
      appBytes: app is Map ? asInt(app['NumBytes']) : null,
      appElapsedUs: app is Map ? asInt(app['ElapsedTime']) : null,
      minRttUs: tcp is Map ? asInt(tcp['MinRTT']) : null,
    );
  }
}

class Ndt7Client {
  Ndt7Client({required this.clientName, required this.clientVersion});

  /// Sent to M-Lab's locator, which asks clients to identify themselves.
  final String clientName;
  final String clientVersion;

  static const _protocol = 'net.measurementlab.ndt.v7';
  static const _phaseLimit = Duration(seconds: 13);
  static const _uploadFor = Duration(seconds: 10);
  static const _emitEvery = Duration(milliseconds: 200);

  /// Upload flow control: never let more than this sit unacknowledged in the
  /// socket buffer. dart:io WebSocket has no bufferedAmount, so without a cap a
  /// fast loop on a slow link would queue hundreds of megabytes in memory.
  static const _maxInFlight = 8 << 20;

  /// Runs locate, download, upload. Cancelling the subscription closes the
  /// sockets immediately.
  Stream<SpeedProgress> run() {
    final open = <WebSocket>{};
    var cancelled = false;
    final out = StreamController<SpeedProgress>(
      onCancel: () {
        cancelled = true;
        for (final ws in open) {
          ws.close();
        }
      },
    );

    Future<void> body() async {
      try {
        out.add(const SpeedProgress(phase: SpeedPhase.locating));
        final target = await _locate();
        if (cancelled) return;

        double? minRttMs;
        final down = await _download(target.downloadUrl, open, () => cancelled, (mbps, rtt) {
          if (rtt != null) minRttMs = rtt;
          out.add(SpeedProgress(phase: SpeedPhase.download, mbps: mbps, server: target.server, minRttMs: minRttMs));
        });
        if (cancelled) return;

        final up = await _upload(target.uploadUrl, open, () => cancelled, (mbps) {
          out.add(SpeedProgress(
            phase: SpeedPhase.upload,
            mbps: mbps,
            server: target.server,
            downloadMbps: down,
            minRttMs: minRttMs,
          ));
        });
        if (cancelled) return;

        out.add(SpeedProgress(
          phase: SpeedPhase.done,
          mbps: down,
          server: target.server,
          downloadMbps: down,
          uploadMbps: up,
          minRttMs: minRttMs,
        ));
      } on SpeedTestException catch (e) {
        if (!cancelled) out.addError(e);
      } on SocketException {
        if (!cancelled) out.addError(const SpeedTestException('Lost connection to the test server.'));
      } on WebSocketException {
        if (!cancelled) out.addError(const SpeedTestException('The test server closed the connection.'));
      } on TimeoutException {
        if (!cancelled) out.addError(const SpeedTestException('The test server did not respond.'));
      } finally {
        if (!out.isClosed) await out.close();
      }
    }

    unawaited(body());
    return out.stream;
  }

  Future<({String downloadUrl, String uploadUrl, SpeedServer server})> _locate() async {
    final uri = Uri.https('locate.measurementlab.net', '/v2/nearest/ndt/ndt7', {
      'client_name': clientName,
      'client_version': clientVersion,
    });
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.getUrl(uri);
      final response = await request.close().timeout(const Duration(seconds: 8));
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode == 429) {
        throw const SpeedTestException('Too many tests right now. Try again in a minute.');
      }
      if (response.statusCode != 200) {
        throw SpeedTestException('No test server available (HTTP ${response.statusCode}).');
      }
      final json = jsonDecode(body);
      final results = json is Map ? json['results'] : null;
      if (results is! List || results.isEmpty) {
        throw const SpeedTestException('No test server available right now.');
      }
      final first = results.first as Map;
      final urls = first['urls'] as Map;
      final location = first['location'];
      final down = urls['wss:///ndt/v7/download'];
      final up = urls['wss:///ndt/v7/upload'];
      if (down is! String || up is! String) {
        throw const SpeedTestException('The test server list was incomplete.');
      }
      return (
        downloadUrl: down,
        uploadUrl: up,
        server: SpeedServer(
          machine: first['machine'] as String? ?? 'unknown',
          city: location is Map ? location['city'] as String? : null,
          country: location is Map ? location['country'] as String? : null,
        ),
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<WebSocket> _connect(String url, Set<WebSocket> open) async {
    final ws = await WebSocket.connect(
      url,
      protocols: const [_protocol],
      // permessage-deflate would compress the payload and inflate the result.
      compression: CompressionOptions.compressionOff,
    ).timeout(const Duration(seconds: 8));
    open.add(ws);
    return ws;
  }

  Future<double> _download(
    String url,
    Set<WebSocket> open,
    bool Function() cancelled,
    void Function(double mbps, double? minRttMs) onProgress,
  ) async {
    final ws = await _connect(url, open);
    final watch = Stopwatch()..start();
    var bytes = 0;
    var lastEmit = Duration.zero;
    final done = Completer<void>();
    final guard = Timer(_phaseLimit, () => ws.close());

    ws.listen(
      (message) {
        double? rtt;
        if (message is List<int>) {
          bytes += message.length;
        } else if (message is String) {
          bytes += message.length;
          final m = Ndt7Measurement.tryParse(message);
          if (m?.minRttUs != null) rtt = m!.minRttUs! / 1000;
        }
        final now = watch.elapsed;
        if (now - lastEmit >= _emitEvery || rtt != null) {
          lastEmit = now;
          onProgress(_mbps(bytes, now.inMicroseconds), rtt);
        }
      },
      onDone: () {
        if (!done.isCompleted) done.complete();
      },
      onError: (Object e) {
        if (!done.isCompleted) done.completeError(e);
      },
      cancelOnError: true,
    );

    try {
      await done.future;
    } finally {
      guard.cancel();
      open.remove(ws);
    }
    if (cancelled()) return 0;
    return _mbps(bytes, watch.elapsedMicroseconds);
  }

  Future<double> _upload(
    String url,
    Set<WebSocket> open,
    bool Function() cancelled,
    void Function(double mbps) onProgress,
  ) async {
    final ws = await _connect(url, open);
    final watch = Stopwatch()..start();
    final random = Random();
    var size = 1 << 13;
    var payload = _randomBytes(size, random);
    var sent = 0;
    var serverBytes = 0;
    var serverElapsedUs = 0;
    var closed = false;
    var lastEmit = Duration.zero;

    final sub = ws.listen(
      (message) {
        if (message is! String) return;
        final m = Ndt7Measurement.tryParse(message);
        if (m?.appBytes != null && m?.appElapsedUs != null) {
          serverBytes = m!.appBytes!;
          serverElapsedUs = m.appElapsedUs!;
        }
      },
      onDone: () => closed = true,
      onError: (Object _) => closed = true,
      cancelOnError: true,
    );

    try {
      while (!closed && !cancelled() && watch.elapsed < _uploadFor) {
        if (sent - serverBytes > _maxInFlight) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          continue;
        }
        ws.add(payload);
        sent += size;

        // The spec's scaling rule: grow the message while it is small
        // relative to what has been sent, up to 1 MiB.
        if (size < (1 << 20) && size < sent ~/ 16) {
          size *= 2;
          payload = _randomBytes(size, random);
        }

        final now = watch.elapsed;
        if (now - lastEmit >= _emitEvery) {
          lastEmit = now;
          onProgress(_uploadRate(serverBytes, serverElapsedUs, sent, now.inMicroseconds));
        }
        // Yield so the socket can drain and server messages can arrive.
        await Future<void>.delayed(Duration.zero);
      }
    } finally {
      await ws.close();
      await sub.cancel();
      open.remove(ws);
    }
    return _uploadRate(serverBytes, serverElapsedUs, sent, watch.elapsedMicroseconds);
  }

  /// Prefer the server's own count: bytes the client queued are not bytes
  /// that crossed the network.
  static double _uploadRate(int serverBytes, int serverUs, int sent, int clientUs) =>
      serverUs > 0 ? _mbps(serverBytes, serverUs) : _mbps(sent, clientUs);

  /// Bits per microsecond is megabits per second.
  static double _mbps(int bytes, int micros) => micros <= 0 ? 0 : bytes * 8 / micros;

  /// Random rather than zeros, as the spec asks, so nothing on the path can
  /// compress the payload and flatter the result.
  static Uint8List _randomBytes(int n, Random random) {
    final out = Uint8List(n);
    for (var i = 0; i < n; i++) {
      out[i] = random.nextInt(256);
    }
    return out;
  }
}
