import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g_network/g_network.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../i18n/strings.g.dart';

/// The whoami Worker, which adds the city and its coordinates that place
/// the user on the map. Overridable per build, like COMMUNITY_URL:
///   flutter run --dart-define=WHOAMI_URL=https://whoami.mindberzerk.com
/// When it cannot be reached, Cloudflare's trace page answers with the IP
/// and country only.
const _whoamiUrl = String.fromEnvironment(
  'WHOAMI_URL',
  defaultValue: 'https://gvpn-whoami.mindberzerk.workers.dev',
);

/// Identifies this app to M-Lab's locator, as their API asks.
const _clientVersion = String.fromEnvironment('APP_VERSION', defaultValue: '2.0.0');

final networkProbeProvider = Provider<NetworkInfoProbe>((ref) => NetworkInfoProbe());

/// Re-read on demand with `ref.invalidate(networkSnapshotProvider)`.
final networkSnapshotProvider = FutureProvider.autoDispose<NetworkSnapshot>(
  (ref) => ref.watch(networkProbeProvider).snapshot(),
);

/// One fresh lookup, uncached. Home and Tools both go through this.
///
/// Right after a tunnel comes up, the first requests can fail while routes
/// and DNS settle, and some volunteer servers drop the odd connection. So it
/// retries a few times, and falls back to Cloudflare's trace page (IP and
/// country only) when the whoami Worker cannot be reached.
Future<PublicIdentity> lookupIdentity() async {
  final primary = _whoamiUrl.isEmpty ? null : Uri.parse(_whoamiUrl);
  Object? last;
  for (final wait in const [Duration.zero, Duration(milliseconds: 1500), Duration(seconds: 3)]) {
    await Future<void>.delayed(wait);
    try {
      return await fetchPublicIdentity(endpoint: primary, timeout: const Duration(seconds: 6));
    } on Object catch (e) {
      last = e;
    }
    if (primary != null) {
      try {
        return await fetchPublicIdentity(timeout: const Duration(seconds: 6));
      } on Object catch (e) {
        last = e;
      }
    }
  }
  throw last ?? const IdentityException('The lookup failed.');
}

final publicIdentityProvider = FutureProvider.autoDispose<PublicIdentity>((ref) => lookupIdentity());

final latencyProvider = FutureProvider.autoDispose<LatencyResult>((ref) => measureLatency());

/// M-Lab publishes results with the tester's IP, so the first test needs an
/// explicit yes. Stored once; the notice stays visible on the tool either way.
final mlabConsentProvider = AsyncNotifierProvider<MlabConsent, bool>(MlabConsent.new);

class MlabConsent extends AsyncNotifier<bool> {
  static const _key = 'gvpn.mlab_consent.v1';

  @override
  Future<bool> build() async =>
      (await SharedPreferences.getInstance()).getBool(_key) ?? false;

  Future<void> accept() async {
    await (await SharedPreferences.getInstance()).setBool(_key, true);
    state = const AsyncData(true);
  }
}

class SpeedTestState {
  const SpeedTestState({
    this.progress,
    this.error,
    this.running = false,
    this.downSamples = const [],
    this.upSamples = const [],
  });

  final SpeedProgress? progress;
  final String? error;
  final bool running;

  /// Live Mbps readings, for the chart under the dial.
  final List<double> downSamples;
  final List<double> upSamples;
}

final speedTestProvider =
    NotifierProvider.autoDispose<SpeedTestController, SpeedTestState>(SpeedTestController.new);

/// Auto-disposed with the screen: leaving the speed test mid-run cancels the
/// stream, which closes the sockets. No test keeps running unseen.
class SpeedTestController extends Notifier<SpeedTestState> {
  StreamSubscription<SpeedProgress>? _sub;

  @override
  SpeedTestState build() {
    ref.onDispose(() => _sub?.cancel());
    return const SpeedTestState();
  }

  void start() {
    if (state.running) return;
    state = const SpeedTestState(running: true);
    _sub = Ndt7Client(clientName: 'gvpn-android', clientVersion: _clientVersion).run().listen(
      (p) => state = SpeedTestState(
        progress: p,
        running: p.phase != SpeedPhase.done,
        downSamples: p.phase == SpeedPhase.download ? [...state.downSamples, p.mbps] : state.downSamples,
        upSamples: p.phase == SpeedPhase.upload ? [...state.upSamples, p.mbps] : state.upSamples,
      ),
      onError: (Object e) => state = SpeedTestState(
        progress: state.progress,
        error: e.toString(),
        downSamples: state.downSamples,
        upSamples: state.upSamples,
      ),
      onDone: () => _sub = null,
    );
  }

  Future<void> cancel() async {
    await _sub?.cancel();
    _sub = null;
    state = SpeedTestState(progress: state.progress, downSamples: state.downSamples, upSamples: state.upSamples);
  }
}

/// The last download speed measured WITHOUT the VPN, so a test through the
/// tunnel can say what the VPN costs ("70% of your direct speed").
final directSpeedProvider = AsyncNotifierProvider<DirectSpeed, double?>(DirectSpeed.new);

class DirectSpeed extends AsyncNotifier<double?> {
  static const _key = 'gvpn.direct_mbps.v1';

  @override
  Future<double?> build() async => (await SharedPreferences.getInstance()).getDouble(_key);

  Future<void> record(double mbps) async {
    await (await SharedPreferences.getInstance()).setDouble(_key, mbps);
    state = AsyncData(mbps);
  }
}

/// One finished speed test, kept on this phone only.
class SpeedResult {
  const SpeedResult({
    required this.at,
    required this.down,
    required this.up,
    this.pingMs,
    required this.viaVpn,
    this.isp,
  });

  final DateTime at;

  /// The provider the test ran over: the ISP for a direct test. Null
  /// through the VPN, where the provider is the VPN server's.
  final String? isp;
  final double down;
  final double up;
  final double? pingMs;
  final bool viaVpn;

  Map<String, Object?> toJson() =>
      {'at': at.millisecondsSinceEpoch, 'down': down, 'up': up, 'ping': pingMs, 'vpn': viaVpn, 'isp': isp};

  static SpeedResult? fromJson(Object? j) {
    if (j is! Map) return null;
    final at = j['at'], down = j['down'], up = j['up'];
    if (at is! int || down is! num || up is! num) return null;
    return SpeedResult(
      at: DateTime.fromMillisecondsSinceEpoch(at),
      down: down.toDouble(),
      up: up.toDouble(),
      pingMs: (j['ping'] as num?)?.toDouble(),
      viaVpn: j['vpn'] == true,
      isp: j['isp'] is String ? j['isp'] as String : null,
    );
  }
}

/// The last 20 speed tests, newest first.
final speedHistoryProvider = AsyncNotifierProvider<SpeedHistory, List<SpeedResult>>(SpeedHistory.new);

class SpeedHistory extends AsyncNotifier<List<SpeedResult>> {
  static const _key = 'gvpn.speed_history.v1';
  static const _keep = 20;

  @override
  Future<List<SpeedResult>> build() async {
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    if (raw == null) return const [];
    try {
      return (jsonDecode(raw) as List).map(SpeedResult.fromJson).whereType<SpeedResult>().toList();
    } on FormatException {
      return const [];
    }
  }

  Future<void> add(SpeedResult r) async {
    final next = [r, ...(state.value ?? const <SpeedResult>[])].take(_keep).toList();
    state = AsyncData(next);
    await (await SharedPreferences.getInstance()).setString(_key, jsonEncode([for (final x in next) x.toJson()]));
  }

  Future<void> clear() async {
    state = const AsyncData([]);
    await (await SharedPreferences.getInstance()).remove(_key);
  }
}

/// A plain-language grade for a connection, from download, upload and
/// latency together: a fast download with a slow upload still struggles on
/// video calls, so no single figure decides it.
(String letter, String label) speedGrade(double down, double up, double? pingMs) {
  final ping = pingMs ?? 999;
  if (down >= 100 && up >= 20 && ping <= 30) return ('A+', t.speed.gradeExcellent);
  if (down >= 50 && up >= 10 && ping <= 50) return ('A', t.speed.gradeVeryGood);
  if (down >= 25 && up >= 5 && ping <= 80) return ('B', t.speed.gradeGood);
  if (down >= 10 && up >= 2 && ping <= 150) return ('C', t.speed.gradeFair);
  if (down >= 3) return ('D', t.speed.gradeSlow);
  return ('E', t.speed.gradeVerySlow);
}

// ── ISP comparison ─────────────────────────────────────────────────────────

const _ispsUrl = String.fromEnvironment('ISPS_URL');

/// Whether direct test results are shared for provider comparisons. On by
/// default, off with one switch; reading the comparison never shares.
final shareResultsProvider = AsyncNotifierProvider<ShareResults, bool>(ShareResults.new);

class ShareResults extends AsyncNotifier<bool> {
  static const _key = 'gvpn.share_results.v1';

  @override
  Future<bool> build() async => (await SharedPreferences.getInstance()).getBool(_key) ?? true;

  Future<void> set(bool on) async {
    state = AsyncData(on);
    await (await SharedPreferences.getInstance()).setBool(_key, on);
  }
}

class IspStanding {
  const IspStanding({required this.isp, required this.tests, required this.down, required this.up, required this.ping, required this.rank});

  final String isp;
  final int tests;
  final double down;
  final double up;
  final int ping;
  final int rank;
}

class IspComparison {
  const IspComparison({this.isp, this.city, this.country, this.scope, this.of = 0, this.rank, this.providers = const []});

  /// The caller's provider and place, as the comparison service sees them.
  final String? isp;
  final String? city;
  final String? country;

  /// "city" or "country"; null when too few tests exist anywhere near.
  final String? scope;
  final int of;
  final int? rank;
  final List<IspStanding> providers;
}

/// Providers near the phone, ranked by median download over 30 days. Only
/// meaningful without the VPN, so callers skip it while connected.
final ispComparisonProvider = FutureProvider.autoDispose<IspComparison?>((ref) async {
  if (_ispsUrl.isEmpty) return null;
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
  try {
    final req = await client.getUrl(Uri.parse('$_ispsUrl/compare'));
    final res = await req.close().timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) return null;
    final j = jsonDecode(await res.transform(utf8.decoder).join()) as Map<String, Object?>;
    final you = j['you'] as Map<String, Object?>?;
    return IspComparison(
      isp: you?['isp'] as String?,
      city: you?['city'] as String?,
      country: you?['country'] as String?,
      scope: j['scope'] as String?,
      of: (j['of'] as num?)?.toInt() ?? 0,
      rank: (j['rank'] as num?)?.toInt(),
      providers: [
        for (final p in (j['providers'] as List? ?? const []))
          if (p is Map)
            IspStanding(
              isp: p['isp'] as String,
              tests: (p['tests'] as num).toInt(),
              down: (p['down'] as num).toDouble(),
              up: (p['up'] as num).toDouble(),
              ping: (p['ping'] as num).toInt(),
              rank: (p['rank'] as num).toInt(),
            ),
      ],
    );
  } on Object {
    return null;
  } finally {
    client.close(force: true);
  }
});

/// Sends one direct test's three numbers. Fire-and-forget: a failure costs
/// nothing but this one data point.
Future<void> shareResult({required double down, required double up, required double ping}) async {
  if (_ispsUrl.isEmpty) return;
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
  try {
    final req = await client.postUrl(Uri.parse('$_ispsUrl/results'));
    req.headers.contentType = ContentType.json;
    req.write(jsonEncode({'down': down, 'up': up, 'ping': ping}));
    await (await req.close().timeout(const Duration(seconds: 8))).drain<void>();
  } on Object {
    // Not worth troubling the user about.
  } finally {
    client.close(force: true);
  }
}
