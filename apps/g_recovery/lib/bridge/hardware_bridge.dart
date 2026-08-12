import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logging.dart';
import 'hardware_api.g.dart';

/// The Dart face of the hardware bridge.
class HardwareBridge {
  HardwareBridge({HardwareHostApi? api}) : _api = api ?? HardwareHostApi();

  final HardwareHostApi _api;

  Future<DisplayInfo?> display() => _guard(_api.display);

  Future<NetworkInfo?> network() => _guard(_api.network);

  Future<WifiInfo?> wifi() => _guard(_api.wifi);

  Future<FeatureFlags?> features() => _guard(_api.features);

  Future<ThroughputSample?> throughput() => _guard(_api.throughput);

  Future<List<CameraInfo>> cameras() async =>
      await _guard(_api.cameras) ?? const <CameraInfo>[];

  Future<void> startSensors(List<String> types) async =>
      _guard(() => _api.startSensors(types));

  Future<void> stopSensors() async => _guard(_api.stopSensors);

  Future<List<SensorReading>> sensorValues() async =>
      await _guard(_api.sensorValues) ?? const <SensorReading>[];

  Future<void> playTone(double hertz, int milliseconds, String channel) async =>
      _guard(() => _api.playTone(hertz, milliseconds, channel));

  Future<void> stopTone() async => _guard(_api.stopTone);

  Future<bool> vibrate(String pattern) async =>
      await _guard(() => _api.vibrate(pattern)) ?? false;

  Future<List<SimInfo>> sims() async =>
      await _guard(_api.sims) ?? const <SimInfo>[];

  Future<BluetoothInfo?> bluetooth() => _guard(_api.bluetooth);

  Future<bool> requestBluetooth() async =>
      await _guard(_api.requestBluetooth) ?? false;

  Future<bool> requestPhoneState() async =>
      await _guard(_api.requestPhoneState) ?? false;

  Future<bool> requestLocation() async =>
      await _guard(_api.requestLocation) ?? false;

  Future<T?> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on PlatformException catch (error, stackTrace) {
      GLog.e(
        'hardware call failed',
        scope: 'hardware',
        cause: '${error.code}: ${error.message}',
        stackTrace: stackTrace,
      );
      return null;
    } on MissingPluginException {
      GLog.w('hardware bridge not registered', scope: 'hardware');
      return null;
    }
  }
}

final Provider<HardwareBridge> hardwareBridgeProvider =
    Provider<HardwareBridge>((Ref ref) => HardwareBridge());

final FutureProvider<DisplayInfo?> displayProvider =
    FutureProvider<DisplayInfo?>(
      (Ref ref) => ref.watch(hardwareBridgeProvider).display(),
    );

final FutureProvider<NetworkInfo?> networkProvider =
    FutureProvider<NetworkInfo?>(
      (Ref ref) => ref.watch(hardwareBridgeProvider).network(),
    );

final FutureProvider<WifiInfo?> wifiProvider = FutureProvider<WifiInfo?>(
  (Ref ref) => ref.watch(hardwareBridgeProvider).wifi(),
);

final FutureProvider<List<CameraInfo>> camerasProvider =
    FutureProvider<List<CameraInfo>>(
      (Ref ref) => ref.watch(hardwareBridgeProvider).cameras(),
    );

final FutureProvider<List<SimInfo>> simsProvider =
    FutureProvider<List<SimInfo>>(
      (Ref ref) => ref.watch(hardwareBridgeProvider).sims(),
    );

final FutureProvider<BluetoothInfo?> bluetoothProvider =
    FutureProvider<BluetoothInfo?>(
      (Ref ref) => ref.watch(hardwareBridgeProvider).bluetooth(),
    );

final FutureProvider<FeatureFlags?> featuresProvider =
    FutureProvider<FeatureFlags?>(
      (Ref ref) => ref.watch(hardwareBridgeProvider).features(),
    );

/// A rolling window of throughput readings.
///
/// ─── SIXTY SAMPLES, ONE A SECOND ─────────────────────────────────────────────
///
/// A minute of history at a rate a person can follow. Faster sampling would draw
/// a noisier line without telling anyone more, and the first reading is always
/// zero because a rate needs two counter reads to exist.
class ThroughputHistory extends Notifier<List<ThroughputSample>> {
  static const int _window = 60;

  @override
  List<ThroughputSample> build() => const <ThroughputSample>[];

  void record(ThroughputSample sample) {
    final List<ThroughputSample> next = <ThroughputSample>[...state, sample];
    state = next.length <= _window ? next : next.sublist(next.length - _window);
  }

  void clear() => state = const <ThroughputSample>[];
}

final NotifierProvider<ThroughputHistory, List<ThroughputSample>>
throughputHistoryProvider =
    NotifierProvider<ThroughputHistory, List<ThroughputSample>>(
      ThroughputHistory.new,
    );

/// Polls throughput while the network page is open.
///
/// A StreamProvider rather than a timer in the widget, so it stops the moment
/// the page is disposed. A poll that outlives its screen is a battery cost with
/// nothing watching it.
final StreamProvider<ThroughputSample?> throughputProvider =
    StreamProvider<ThroughputSample?>((Ref ref) async* {
      final HardwareBridge bridge = ref.watch(hardwareBridgeProvider);

      while (true) {
        final ThroughputSample? sample = await bridge.throughput();
        if (sample != null) {
          ref.read(throughputHistoryProvider.notifier).record(sample);
        }
        yield sample;
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    });

/// The sensors worth watching move.
///
/// Six, not thirty one. A phone reports step counters, rotation vectors and a
/// dozen fused virtual sensors, none of which mean anything to a person reading
/// a number. These six do: tilt the phone and the accelerometer moves, cover it
/// and the light and proximity readings move.
const List<String> kLiveSensors = <String>[
  'accelerometer',
  'gyroscope',
  'magnetometer',
  'light',
  'proximity',
  'pressure',
];

/// Live sensor values, started and stopped with the screen watching them.
///
/// ─── onDispose IS THE POINT ──────────────────────────────────────────────────
///
/// Registering a SensorEventListener wakes the CPU whether or not anything is
/// reading it. Tying registration to a provider that Riverpod disposes with the
/// route is the difference between a page that costs nothing when closed and a
/// drain nobody would attribute to this app.
final StreamProvider<List<SensorReading>>
sensorValuesProvider = StreamProvider<List<SensorReading>>((Ref ref) async* {
  final HardwareBridge bridge = ref.watch(hardwareBridgeProvider);
  await bridge.startSensors(kLiveSensors);
  ref.onDispose(bridge.stopSensors);

  while (true) {
    // 200ms. Faster than the eye needs for a number to feel live, slower than
    // the sensor fires, so nothing is spent serialising readings that would be
    // replaced before they were drawn.
    await Future<void>.delayed(const Duration(milliseconds: 200));
    yield await bridge.sensorValues();
  }
});
