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
enum TunnelPhase { down, up, reconnecting, paused }

/// When auto-connect fires. `open`: password-less, WEP or sign-in-page Wi-Fi.
/// `any`: every Wi-Fi network.
enum AutoConnectMode { open, any }

class TunnelStatus {
  TunnelStatus({
    required this.phase,
    required this.rxBytes,
    required this.txBytes,
    this.stoppedByUser = false,
    this.pausedUntilMs = 0,
  });

  TunnelPhase phase;
  int rxBytes;
  int txBytes;

  /// The user stopped it outside the app (notification, Quick Settings), so
  /// a drop to "down" is their choice, not the system's. Reported once.
  bool stoppedByUser;

  /// Epoch ms a pause ends; 0 unless [phase] is paused.
  int pausedUntilMs;
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

/// A free server reached over SSTP (VPN Gate). The login is VPN Gate's
/// public one; the server certificate is self-signed.
class SstpOptions {
  SstpOptions({
    required this.host,
    required this.port,
    required this.username,
    required this.password,
    required this.name,
    required this.excludedApps,
    required this.dnsServers,
  });

  String host;
  int port;
  String username;
  String password;

  /// Shown in the notification and Quick Settings.
  String name;
  List<String> excludedApps;
  List<String> dnsServers;
}

/// A WireGuard key pair made on the phone. Only the public half ever
/// leaves it.
class WgKeyPair {
  WgKeyPair({required this.privateKey, required this.publicKey});

  String privateKey;
  String publicKey;
}

@HostApi()
abstract class VpnHostApi {
  /// Shows the system VPN consent dialog if needed. True when consent exists.
  @async
  bool prepare();

  /// Errors: `bad_config`, `not_authorized`, `connect_failed`.
  /// [label] names the session in the notification and Quick Settings.
  @async
  void connect(String configText, String label);

  /// Stops the tunnel for [minutes], then reconnects to the same server.
  void pause(int minutes);

  /// Ends a pause now.
  void resume();

  /// An app's launcher icon as PNG bytes, [sizePx] square; null when the app
  /// is gone. For the app rules list.
  @async
  Uint8List? appIcon(String packageName, int sizePx);

  /// OpenVPN (.ovpn) tunnel, for Community and provider servers. Stops any
  /// WireGuard tunnel first; resolves once traffic flows.
  @async
  void connectOpenVpn(String configText, OpenVpnOptions options);

  /// Connects to a free server over SSTP. Completes once traffic flows.
  @async
  void connectSstp(SstpOptions options);

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

  /// Picks an image (photo picker, no permission) and reads the QR code in
  /// it on the phone. Null when the user backs out; error code no_qr when
  /// the image holds no QR code.
  @async
  String? scanQrFromImage();

  /// A new WireGuard key pair, generated on the phone.
  WgKeyPair generateWgKeyPair();

  /// The phone's maker and model, to tell phones apart in Your devices.
  String deviceName();

  /// A server shared to G VPN from another app (a QR image or the settings
  /// as text), taken once. Null when nothing was shared.
  @async
  String? takeSharedServer();

  /// One traceroute step, using the system ping with a TTL limit (apps
  /// cannot send raw ICMP; the system tool can).
  @async
  TraceHop traceHop(String host, int ttl);

  /// Nearby Wi-Fi networks. Needs the location permission Android ties to
  /// Wi-Fi scans; Android also limits scans to a few per minute.
  @async
  List<WifiAccessPoint> scanWifi();
}
