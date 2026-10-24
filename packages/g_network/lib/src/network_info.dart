import 'network_api.g.dart';

/// Reads the device's current network state. Cheap: one binder round trip,
/// no network traffic, safe to call on every screen open.
class NetworkInfoProbe {
  NetworkInfoProbe({NetworkHostApi? api}) : _api = api ?? NetworkHostApi();

  final NetworkHostApi _api;

  Future<NetworkSnapshot> snapshot() => _api.snapshot();
}
