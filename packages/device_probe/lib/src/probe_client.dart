import 'dart:developer' as developer;

import 'package:flutter/services.dart';

import 'device_probe_api.g.dart';

/// The Dart face of the bridge.
///
/// Every method returns null on failure instead of throwing. The reason is the
/// same one that shapes the whole package: on Android there is no way to know in
/// advance whether a given kernel will answer, so a refused read is an ordinary
/// outcome rather than an exception. A UI that has to wrap every stat in a
/// try/catch ends up catching nothing and showing zeros.
///
/// The one thing that is never swallowed is a bug in our own code: a
/// [PlatformException] is logged with its code before being converted, so a
/// genuine crash in the Kotlin side is still visible in logcat.
class DeviceProbe {
  DeviceProbe({DeviceProbeHostApi? api})
      : _api = api ?? DeviceProbeHostApi();

  final DeviceProbeHostApi _api;

  /// Which sources this device will actually serve. Cached natively for the
  /// process, so calling it repeatedly is cheap.
  Future<ProbeCapabilities?> capabilities() => _guard(_api.capabilities);

  /// Static topology. Read once per launch.
  Future<CpuInfo?> cpuInfo() => _guard(_api.cpuInfo);

  /// The full sensor list, including entries this app may not register for.
  Future<List<SensorInfo>> sensors() async =>
      await _guard(_api.sensors) ?? const <SensorInfo>[];

  /// One tick of everything live.
  Future<DeviceSnapshot?> snapshot() => _guard(_api.readSnapshot);

  /// Which phone this is. Cached natively, so calling it per screen is cheap.
  Future<DeviceIdentity?> deviceIdentity() => _guard(_api.deviceIdentity);

  /// Which storage model this device is on and what was actually granted.
  ///
  /// NOT cached on either side. All Files Access is a toggle the user can flip
  /// from Settings while this app is backgrounded, so call it when a screen that
  /// depends on it appears, and again on resume.
  Future<StorageAccess?> storageAccess() => _guard(_api.storageAccess);

  Future<T?> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on PlatformException catch (error, stackTrace) {
      developer.log(
        'probe call failed',
        name: 'device_probe',
        level: 900,
        error: '${error.code}: ${error.message}',
        stackTrace: stackTrace,
      );
      return null;
    } on MissingPluginException {
      // The plugin is not registered. Happens in unit tests and on a platform
      // the package does not implement. Not an error worth logging on every
      // tick of a 2 Hz sampler.
      return null;
    }
  }
}
