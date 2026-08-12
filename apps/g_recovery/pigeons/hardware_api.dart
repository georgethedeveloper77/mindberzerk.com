import 'package:pigeon/pigeon.dart';

/// THE SOURCE OF TRUTH for the hardware detail pages.
///
/// Regenerate after ANY edit here:
///
///   cd apps/g_recovery
///   dart run pigeon --input pigeons/hardware_api.dart
///
/// Outputs (both generated, never hand-edit):
///   lib/bridge/hardware_api.g.dart
///   android/app/src/main/kotlin/com/mindhunter/g_recovery/hardware/HardwareApi.g.kt
///
/// ─── HERE RATHER THAN IN device_probe ────────────────────────────────────────
///
/// The probe package is shared with G Launcher, which needs none of this. Adding
/// display metrics, throughput and camera specs there would make every launcher
/// build carry them, and would mean two packages to regenerate on every change.
///
/// ─── DECLARATION ORDER IS THE WIRE FORMAT ────────────────────────────────────
///
///   129 DisplayInfo    130 NetworkInfo    131 WifiInfo
///   132 CameraInfo     133 FeatureFlags   134 ThroughputSample
///   135 SensorReading  136 SimInfo       137 BluetoothInfo
///   138 PairedDevice
///
/// ADD NEW TYPES AT THE END. NO ENUMS, ever: they number before classes.
@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/bridge/hardware_api.g.dart',
    kotlinOut:
        'android/app/src/main/kotlin/com/mindhunter/g_recovery/hardware/HardwareApi.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.mindhunter.g_recovery.hardware'),
    dartPackageName: 'g_recovery',
  ),
)
/// The screen. Codec 129.
class DisplayInfo {
  DisplayInfo({
    required this.widthPx,
    required this.heightPx,
    required this.densityDpi,
    required this.refreshHz,
    required this.supportedHz,
    required this.hdr,
    required this.wideColour,
    required this.hdrTypes,
    required this.maxLuminance,
    required this.minLuminance,
    required this.averageLuminance,
  });

  final int widthPx;
  final int heightPx;
  final int densityDpi;
  final double refreshHz;

  /// Every mode the panel will run at, largest first. One entry on a fixed
  /// 60 Hz screen, which is not an error and needs no note.
  final List<double> supportedHz;

  final bool hdr;
  final bool wideColour;

  /// "HDR10", "HLG", "HDR10+", "Dolby Vision".
  final List<String> hdrTypes;

  /// Candelas per square metre, and null on a panel that does not declare them,
  /// which is most non HDR screens.
  final double? maxLuminance;
  final double? minLuminance;
  final double? averageLuminance;
}

/// The active connection. Codec 130.
class NetworkInfo {
  NetworkInfo({
    required this.type,
    required this.connected,
    required this.metered,
    required this.ipv4,
    required this.ipv6,
    required this.rxBytesTotal,
    required this.txBytesTotal,
  });

  /// "wifi" | "cellular" | "ethernet" | "vpn" | "none"
  final String type;

  final bool connected;
  final bool metered;

  final String? ipv4;
  final String? ipv6;

  /// Since boot, across every interface. TrafficStats needs no permission for
  /// device totals, unlike the per app figures.
  final int rxBytesTotal;
  final int txBytesTotal;
}

/// The Wi-Fi link. Codec 131.
///
/// ─── HALF OF THIS NEEDS LOCATION ─────────────────────────────────────────────
///
/// From Android 10, SSID, BSSID and MAC are only real with ACCESS_FINE_LOCATION.
/// Without it the system hands back "unknown ssid" and 02:00:00:00:00:00, and
/// an app that prints those is printing a refusal as though it were data.
///
/// So they are NULLABLE and native returns null rather than the placeholder. The
/// UI shows the row missing and names the permission once.
class WifiInfo {
  WifiInfo({
    required this.connected,
    required this.ssid,
    required this.bssid,
    required this.macAddress,
    required this.standard,
    required this.frequencyMhz,
    required this.linkSpeedMbps,
    required this.rxLinkSpeedMbps,
    required this.signalPercent,
    required this.security,
    required this.supports5Ghz,
    required this.supports6Ghz,
    required this.hasLocationPermission,
  });

  final bool connected;

  final String? ssid;
  final String? bssid;
  final String? macAddress;

  /// "802.11n", "802.11ac", "802.11ax".
  final String? standard;

  final int? frequencyMhz;
  final int? linkSpeedMbps;
  final int? rxLinkSpeedMbps;
  final int? signalPercent;
  final String? security;

  final bool supports5Ghz;
  final bool supports6Ghz;

  /// So the UI can say which permission would fill the gaps, rather than
  /// guessing from a null that might just be a disconnected radio.
  final bool hasLocationPermission;
}

/// One camera. Codec 132.
class CameraInfo {
  CameraInfo({
    required this.id,
    required this.facing,
    required this.megapixels,
    required this.widthPx,
    required this.heightPx,
    required this.focalLengthsMm,
    required this.apertures,
    required this.isoMin,
    required this.isoMax,
    required this.supportsRaw,
    required this.hasFlash,
  });

  final String id;

  /// "front" | "back" | "external"
  final String facing;

  final double megapixels;
  final int widthPx;
  final int heightPx;

  final List<double> focalLengthsMm;
  final List<double> apertures;

  final int? isoMin;
  final int? isoMax;

  final bool supportsRaw;
  final bool hasFlash;
}

/// What the hardware has. Codec 133.
class FeatureFlags {
  FeatureFlags({
    required this.nfc,
    required this.gps,
    required this.uwb,
    required this.usbHost,
    required this.fingerprint,
    required this.bluetooth,
    required this.bluetoothLe,
    required this.telephony,
  });

  final bool nfc;
  final bool gps;
  final bool uwb;
  final bool usbHost;
  final bool fingerprint;
  final bool bluetooth;
  final bool bluetoothLe;
  final bool telephony;
}

/// One throughput reading. Codec 134.
class ThroughputSample {
  ThroughputSample({
    required this.rxBytesPerSecond,
    required this.txBytesPerSecond,
    required this.rxBytesTotal,
    required this.txBytesTotal,
  });

  /// A RATE, computed natively from two counter reads.
  ///
  /// Native owns the previous counter and the elapsed time, because doing the
  /// subtraction in Dart would make every rate wrong by however long the UI
  /// thread was busy.
  final int rxBytesPerSecond;
  final int txBytesPerSecond;

  final int rxBytesTotal;
  final int txBytesTotal;
}

/// One sensor, reading now. Codec 135.
class SensorReading {
  SensorReading({
    required this.type,
    required this.name,
    required this.values,
    required this.unit,
    required this.maxRange,
  });

  /// The Android sensor type constant, as a string. Numbers would be an enum,
  /// and an enum here would renumber every class above it.
  final String type;

  final String name;

  /// One to three axes. Light and pressure send one, the accelerometer sends
  /// three, and the caller renders whatever arrives rather than assuming.
  final List<double> values;

  /// "m/s2", "lux", "uT", "rad/s", "hPa", "cm".
  final String unit;

  /// The largest value this sensor can report, for scaling a bar. Null where
  /// the sensor does not declare one.
  final double? maxRange;
}

/// One SIM. Codec 136.
///
/// ─── WHAT IS FREE AND WHAT IS NOT ────────────────────────────────────────────
///
/// Carrier name, country, MCC and MNC come from SubscriptionManager and need
/// READ_PHONE_STATE from Android 11. The number and the ICCID need more than
/// that and are not read at all: a recovery app does not need the subscriber's
/// phone number, and asking for it would be the single most alarming permission
/// in the app.
class SimInfo {
  SimInfo({
    required this.slot,
    required this.carrier,
    required this.countryIso,
    required this.mcc,
    required this.mnc,
    required this.embedded,
    required this.roaming,
    required this.dataDefault,
  });

  final int slot;
  final String? carrier;

  /// Two letters, uppercased for display. Null where the SIM does not report a
  /// country, which happens on some MVNOs.
  final String? countryIso;

  final String? mcc;
  final String? mnc;

  /// An eSIM rather than a physical card.
  final bool embedded;

  final bool roaming;

  /// The SIM carrying mobile data. False on both when data is off.
  final bool dataDefault;
}

/// One paired device. Codec 137.
class PairedDevice {
  PairedDevice({
    required this.name,
    required this.address,
    required this.type,
    required this.connected,
  });

  final String name;

  /// Masked to the last four characters. A full MAC on screen is a tracking
  /// identifier for a device the user may be about to photograph the screen of.
  final String address;

  /// "audio" | "phone" | "computer" | "wearable" | "input" | "other"
  final String type;

  final bool connected;
}

/// The Bluetooth radio. Codec 138.
class BluetoothInfo {
  BluetoothInfo({
    required this.available,
    required this.enabled,
    required this.name,
    required this.hasPermission,
    required this.paired,
    required this.leSupported,
    required this.le2mSupported,
    required this.leCodedSupported,
    required this.leAudioSupported,
  });

  /// The device has a radio at all.
  final bool available;

  final bool enabled;

  /// Null without BLUETOOTH_CONNECT, which is where the adapter name lives from
  /// Android 12.
  final String? name;

  final bool hasPermission;

  /// Empty without the permission, which is not the same as no paired devices.
  /// [hasPermission] tells the two apart.
  final List<PairedDevice> paired;

  final bool leSupported;
  final bool le2mSupported;
  final bool leCodedSupported;
  final bool leAudioSupported;
}

@HostApi()
abstract class HardwareHostApi {
  @async
  DisplayInfo display();

  @async
  NetworkInfo network();

  @async
  WifiInfo wifi();

  @async
  List<CameraInfo> cameras();

  @async
  FeatureFlags features();

  /// One reading, taken against the previous call.
  ///
  /// The first call after a cold start returns zero rates and real totals, since
  /// there is nothing to subtract from yet.
  @async
  ThroughputSample throughput();

  /// Starts listening to a small set of sensors.
  ///
  /// ─── EXPLICIT START AND STOP, NOT A STANDING SUBSCRIPTION ────────────────
  ///
  /// A registered SensorEventListener wakes the CPU at whatever rate it asked
  /// for, whether or not anything is looking. Tying registration to a screen
  /// being open is the difference between a page that costs nothing when closed
  /// and a background drain nobody attributes to this app.
  @async
  void startSensors(List<String> types);

  @async
  void stopSensors();

  /// The latest value from each started sensor.
  ///
  /// Polled rather than pushed. A sensor at its default rate fires far more
  /// often than a screen refreshes, and forwarding every event over a channel
  /// would spend more time in serialisation than in the reading.
  @async
  List<SensorReading> sensorValues();

  /// Every SIM the phone can see, by slot.
  @async
  List<SimInfo> sims();

  @async
  BluetoothInfo bluetooth();

  /// Plays a steady tone through one or both speakers.
  ///
  /// ─── GENERATED, NOT A BUNDLED FILE ───────────────────────────────────────
  ///
  /// A sine wave written straight into an AudioTrack. An asset would be a few
  /// hundred kilobytes in the APK for a sound the phone can compute, and a
  /// plugin would be a dependency for sixty lines of Kotlin.
  ///
  /// [channel] is "left", "right" or "both". Separate channels are the whole
  /// point: a phone with one dead speaker sounds fine on "both".
  @async
  void playTone(double hertz, int milliseconds, String channel);

  @async
  void stopTone();

  /// [pattern] is "short", "long" or "double".
  @async
  bool vibrate(String pattern);

  /// Opens the system dialog for nearby Bluetooth devices.
  @async
  bool requestBluetooth();

  /// Opens the system dialog for phone state, which SIM details need.
  @async
  bool requestPhoneState();

  /// Opens the system dialog for fine location.
  @async
  bool requestLocation();
}
