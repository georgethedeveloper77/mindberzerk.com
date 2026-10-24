/// g_network's native bridge. Its own Kotlin package, so its generated
/// FlutterError cannot clash with an app's (G VPN uses com.mindberzerk.gvpn).
///
/// Enum values are single words on purpose: Pigeon upper-cases them for
/// Kotlin, and single words leave no doubt about the generated names.
/// New fields are APPENDED, never inserted.
library;

import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/network_api.g.dart',
    kotlinOut: 'android/src/main/kotlin/com/mindberzerk/g_network/NetworkApi.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.mindberzerk.g_network'),
  ),
)

/// The physical link under any VPN.
enum Transport { wifi, cellular, ethernet, other, none }

/// Wi-Fi security as Android reports it. `unknown` below Android 12, which
/// has no public API for the connected network's security type.
enum WifiSecurity { open, wep, wpa2, wpa3, enterprise, owe, unknown }

class NetworkSnapshot {
  NetworkSnapshot({
    required this.transport,
    required this.vpnActive,
    required this.validated,
    required this.captivePortal,
    required this.metered,
    required this.privateDnsActive,
    required this.dnsServers,
    required this.addresses,
    required this.wifiSecurity,
    this.privateDnsServer,
    this.interfaceName,
    this.gateway,
    this.downKbps,
    this.upKbps,
    this.rssi,
    this.linkSpeedMbps,
    this.frequencyMhz,
    this.carrierName,
    this.ssid,
  });

  Transport transport;
  bool vpnActive;

  /// Android confirmed real internet access on the physical network.
  bool validated;

  /// The network wants a sign-in page first: hotels, cafes, airports.
  bool captivePortal;
  bool metered;
  bool privateDnsActive;

  /// DNS servers apps actually use: the VPN's when a tunnel is up.
  List<String> dnsServers;
  List<String> addresses;
  WifiSecurity wifiSecurity;
  String? privateDnsServer;
  String? interfaceName;
  String? gateway;

  /// Android's own link estimates, not a measurement.
  int? downKbps;
  int? upKbps;
  int? rssi;
  int? linkSpeedMbps;
  int? frequencyMhz;
  String? carrierName;

  /// The Wi-Fi name. Android shares it only with apps holding location
  /// permission, with Location switched on; null otherwise.
  String? ssid;
}

@HostApi()
abstract class NetworkHostApi {
  NetworkSnapshot snapshot();
}

/// Pushed from Android whenever the DEFAULT network changes: joining or
/// leaving Wi-Fi, switching to mobile data, or a VPN coming up or down.
/// Drives the automatic "this network" scan without any polling.
@FlutterApi()
abstract class NetworkEventsApi {
  void onNetworkChanged();
}
