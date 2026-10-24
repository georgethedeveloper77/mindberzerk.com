/// Network tools shared across Mindberzerk apps.
///
/// Pure Dart where Dart can do the job (speed test, latency, public identity);
/// native only for what Android alone knows (link, Wi-Fi and DNS state).
library;

export 'src/latency.dart';
export 'src/ndt7.dart';
export 'src/network_api.g.dart' show NetworkSnapshot, Transport, WifiSecurity;
export 'src/network_events.dart';
export 'src/network_info.dart';
export 'src/public_identity.dart';
export 'src/wifi_safety.dart';
