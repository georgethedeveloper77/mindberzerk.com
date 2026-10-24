import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g_network/g_network.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The whoami Worker URL, baked in at build time:
///   flutter run --dart-define=WHOAMI_URL=https://whoami.mindberzerk.com
/// Empty falls back to Cloudflare's trace page (IP and country only).
const _whoamiUrl = String.fromEnvironment('WHOAMI_URL');

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
