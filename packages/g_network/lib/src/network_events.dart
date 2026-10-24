import 'dart:async';

import 'network_api.g.dart';

/// Network changes as a Dart stream.
///
/// Android often reports a change as a burst (lost, then available, then
/// capabilities settling), so events are coalesced: one event per 800 ms of
/// quiet. Without that, one Wi-Fi join would trigger three scans.
class NetworkEvents implements NetworkEventsApi {
  NetworkEvents._() {
    NetworkEventsApi.setUp(this);
  }

  static final NetworkEvents instance = NetworkEvents._();

  final _out = StreamController<void>.broadcast();
  Timer? _quiet;

  Stream<void> get changes => _out.stream;

  @override
  void onNetworkChanged() {
    _quiet?.cancel();
    _quiet = Timer(const Duration(milliseconds: 800), () => _out.add(null));
  }
}
