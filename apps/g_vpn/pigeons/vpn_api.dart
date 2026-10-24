/// The G VPN native bridge. ONE schema, ONE Kotlin package: two schemas in
/// the same package redeclare FlutterError and fail at runtime.
///
/// Regenerate after any change (from apps/g_vpn):
///   dart run pigeon --input pigeons/vpn_api.dart
///
/// Enum values stay single words so the generated Kotlin names are obvious.
library;

import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/vpn/vpn_api.g.dart',
    kotlinOut: 'android/app/src/main/kotlin/com/mindberzerk/gvpn/VpnApi.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.mindberzerk.gvpn'),
  ),
)

/// What the WireGuard backend reports. "Connecting" is a Dart-side phase.
/// [reconnecting]: the tunnel is re-establishing after a network change or
/// sleep. Still the user's VPN, not "off".
enum TunnelPhase { down, up, reconnecting }

/// When auto-connect fires. `open`: password-less, WEP or sign-in-page Wi-Fi.
/// `any`: every Wi-Fi network.
enum AutoConnectMode { open, any }

class TunnelStatus {
  TunnelStatus({required this.phase, required this.rxBytes, required this.txBytes});

  TunnelPhase phase;
  int rxBytes;
  int txBytes;
}

/// A launchable app, for app rules. Only launcher apps are visible, which is
/// what the manifest's <queries> block allows without QUERY_ALL_PACKAGES.
class InstalledApp {
  InstalledApp({required this.packageName, required this.label, required this.system});

  String packageName;
  String label;
  bool system;
}

/// Everything the native side needs to raise the tunnel with no Dart running:
/// the config is pre-rendered with app rules and Shield DNS already applied.
class AutoConnectSettings {
  AutoConnectSettings({required this.configText, required this.mode});

  String configText;
  AutoConnectMode mode;
}

/// A config file the user picked. [name] is the file name without
/// extension, offered as the server's name.
class PickedConfig {
  PickedConfig({required this.name, required this.text});

  String name;
  String text;
}

/// How an OpenVPN tunnel should behave. Mirrors what WireGuard gets through
/// its config rewrite, so app rules and Shield work on both engines.
class OpenVpnOptions {
  OpenVpnOptions({required this.name, required this.excludedApps, required this.dnsServers});

  String name;

  /// Packages that skip the tunnel (banking and the user's own rules).
  List<String> excludedApps;

  /// Empty keeps the server's DNS; Shield passes Quad9.
  List<String> dnsServers;
}

/// One traceroute step: the router that answered at this hop count.
class TraceHop {
  TraceHop({required this.ttl, this.address, this.rttMs, required this.reached});

  int ttl;

  /// Null when the hop stayed silent (many routers never answer).
  String? address;
  double? rttMs;

  /// The destination itself answered: the trace is complete.
  bool reached;
}

/// A nearby Wi-Fi network from the phone's last scan.
class WifiAccessPoint {
  WifiAccessPoint({
    required this.ssid,
    required this.bssid,
    required this.level,
    required this.frequencyMhz,
    required this.channel,
    required this.widthMhz,
    required this.security,
  });

  /// Empty for hidden networks.
  String ssid;
  String bssid;

  /// dBm; closer to 0 is stronger.
  int level;
  int frequencyMhz;
  int channel;
  int widthMhz;

  /// Open, WEP, WPA, WPA2 or WPA3.
  String security;
}

@HostApi()
abstract class VpnHostApi {
  /// Shows the system VPN consent dialog if needed. True when consent exists.
  @async
  bool prepare();

  /// Errors: `bad_config`, `not_authorized`, `connect_failed`.
  @async
  void connect(String configText);

  /// OpenVPN (.ovpn) tunnel, for Community and provider servers. Stops any
  /// WireGuard tunnel first; resolves once traffic flows.
  @async
  void connectOpenVpn(String configText, OpenVpnOptions options);

  /// Stops whichever engine is running.
  @async
  void disconnect();

  TunnelStatus status();

  @async
  List<InstalledApp> listApps();

  /// Null turns auto-connect off and unregisters the network watch.
  void setAutoConnect(AutoConnectSettings? settings);

  bool notificationsAllowed();

  /// Asks for POST_NOTIFICATIONS on Android 13+. True when allowed.
  @async
  bool requestNotifications();

  bool wifiNamesAllowed();

  /// Asks for location permission, which Android requires before it shares
  /// the Wi-Fi name. Call only after the in-app disclosure.
  @async
  bool requestWifiNames();

  /// Whether the phone's Location switch is on. Wi-Fi names and scans need
  /// it as well as the permission.
  bool locationServicesOn();

  /// Opens Android's Location settings.
  void openLocationSettings();

  /// Opens Android's VPN settings, where Always-on VPN is switched on.
  void openVpnSettings();

  /// Opens the battery optimisation list, where G VPN can be exempted so the
  /// phone does not stop it in the background.
  void openBatterySettings();

  /// Whether Android already exempts G VPN from battery optimisation.
  bool batteryUnrestricted();

  /// Google's code scanner, run by Play services: no CAMERA permission in
  /// this app at all. Null when the user backs out.
  @async
  String? scanQr();

  /// The system file picker. Null when the user backs out.
  @async
  PickedConfig? pickConfigFile();

  /// One traceroute step, using the system ping with a TTL limit (apps
  /// cannot send raw ICMP; the system tool can).
  @async
  TraceHop traceHop(String host, int ttl);

  /// Nearby Wi-Fi networks. Needs the location permission Android ties to
  /// Wi-Fi scans; Android also limits scans to a few per minute.
  @async
  List<WifiAccessPoint> scanWifi();
}
