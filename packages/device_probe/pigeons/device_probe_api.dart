import 'package:pigeon/pigeon.dart';

/// THE SOURCE OF TRUTH for the device_probe bridge, shared by G Recovery and
/// G Launcher.
///
/// Regenerate after ANY edit here:
///
///   cd packages/device_probe
///   dart run pigeon --input pigeons/device_probe_api.dart
///
/// Outputs (both generated, never hand-edit):
///   lib/src/device_probe_api.g.dart
///   android/src/main/kotlin/com/mindberzerk/device_probe/DeviceProbeApi.g.kt
///
/// KEEP THIS FILE. Generated code is not a backup of its own source, and this
/// schema is now load-bearing for two apps rather than one.
///
/// NOTE ON IMPORTS: a Pigeon schema may import ONLY 'package:pigeon/pigeon.dart'.
///
/// ─── NEVER WRITE A SHELL GLOB IN A DOC COMMENT HERE ──────────────────────────
///
/// Pigeon copies these comments VERBATIM into Kotlin KDoc, which is delimited by
/// slash-star and star-slash. A sysfs path written the natural way, with a star
/// immediately before a slash, closes the comment block early. Everything after
/// it lands inside the generated data class constructor as stray tokens, and the
/// error you get names a parameter that does not exist in this schema.
///
/// This cost an entire build cycle to find. Write `policyN` and `cpuN`, or name
/// the file in prose, but never the star-slash pair.
///
/// ─── ITS OWN KOTLIN PACKAGE ──────────────────────────────────────────────────
///
/// `com.mindberzerk.device_probe`, deliberately neither `g_launcher` nor
/// `g_recovery`. Pigeon emits a `FlutterError` class into every generated Kotlin
/// file, so two schemas sharing a package is a redeclaration error that only
/// appears at COMPILE time. This generated file lands on the classpath of both
/// apps at once, which makes the isolation mandatory rather than tidy.
///
/// ─── DECLARATION ORDER IS THE WIRE FORMAT ────────────────────────────────────
///
///   129 ProbeCapabilities   130 CpuCluster       131 CpuInfo
///   132 CpuSample           133 ThermalZone      134 ThermalSample
///   135 BatterySnapshot     136 MemorySnapshot   137 SensorInfo
///   138 DeviceSnapshot     139 StorageAccess
///
/// ADD NEW TYPES AT THE END. Inserting one renumbers everything after it, and a
/// Dart side talking 134 to a Kotlin side hearing 135 fails in the least
/// debuggable way possible.
///
/// ─── THERE ARE NO ENUMS IN THIS SCHEMA, AND THERE NEVER WILL BE ──────────────
///
/// Pigeon numbers enums BEFORE classes. One enum added here would take 129 and
/// push all ten classes up by one. `launcher_api.dart` is already boxed in by
/// its two enums; this schema is deliberately not, so appending is always safe.
///
/// Every enum-shaped value below is a String: cluster label, thermal category,
/// battery status, battery health, sensor category. An unrecognised value must
/// degrade to "show it as-is" rather than fail to parse, because these come from
/// OEM kernels and the set is not knowable in advance.
///
/// ─── METHODS ARE FREE, TYPES ARE NOT ─────────────────────────────────────────
///
/// HostApi METHODS are not codec-numbered, so adding one later costs nothing.
/// That is why sensor streaming is absent here: it needs lifecycle handling that
/// belongs with the sensor detail screen, and adding `startSensorStream` in a
/// later phase moves no ids.
@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/device_probe_api.g.dart',
    kotlinOut:
        'android/src/main/kotlin/com/mindberzerk/device_probe/DeviceProbeApi.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.mindberzerk.device_probe'),
    dartPackageName: 'device_probe',
  ),
)

/// What THIS DEVICE will actually answer. Codec 129.
///
/// A SEPARATE ANSWER FROM A SNAPSHOT OF NULLS. A null in [DeviceSnapshot] is
/// ambiguous: it can mean "this kernel will never tell us" or "not sampled yet",
/// and those need different UI. Permanently absent is a sentence explaining why;
/// pending is a shimmer.
///
/// Probed ONCE natively and cached for the process lifetime. Every field here is
/// the result of an actual attempted read, not a version check, because SELinux
/// policy is per-ROM: the same API level reads core frequencies on a Tecno and
/// refuses on a hardened Samsung.
class ProbeCapabilities {
  ProbeCapabilities({
    required this.coreFrequencies,
    required this.cpuClusters,
    required this.cpuGovernor,
    required this.cpuJiffies,
    required this.thermalZones,
    required this.thermalStatus,
    required this.battery,
    required this.batteryDetail,
    required this.batteryCycleCount,
    required this.memory,
    required this.swap,
    required this.sensorCount,
  });

  /// `scaling_cur_freq` per core. False on most hardened ROMs.
  final bool coreFrequencies;

  /// Whether the kernel published its frequency domains under
  /// `cpufreq/policyN`, in the `related_cpus` file. When false, clusters were
  /// inferred from distinct max frequencies instead, which is a good guess and
  /// not a fact.
  ///
  /// NO SHELL GLOBS IN THIS FILE. See the header: a `*` before a `/` closes the
  /// generated KDoc block early and the rest of the sentence lands inside a
  /// Kotlin constructor.
  final bool cpuClusters;

  final bool cpuGovernor;

  /// Aggregate `/proc/stat`. Almost always false on Android 12+. Kept as an
  /// honest field so the answer is "this device says no" rather than "we never
  /// asked".
  final bool cpuJiffies;

  final bool thermalZones;

  /// `PowerManager.getCurrentThermalStatus()`, API 29+.
  final bool thermalStatus;

  /// Level and charging state. True on effectively every device.
  final bool battery;

  /// Temperature, current draw, voltage. Separate from [battery] because the
  /// sticky broadcast can carry a level while `CURRENT_NOW` returns nothing.
  final bool batteryDetail;

  /// `BATTERY_PROPERTY_CYCLE_COUNT`, API 34+ and OEM-dependent even there.
  final bool batteryCycleCount;

  final bool memory;

  /// zram and swap from `/proc/meminfo`. Usually readable where `/proc/stat`
  /// is not, because meminfo has no per-process information to leak.
  final bool swap;

  /// 0 means the sensor list came back empty, which happens on emulators.
  final int sensorCount;
}

/// One frequency domain. Codec 130.
class CpuCluster {
  CpuCluster({
    required this.label,
    required this.coreIds,
    this.minKhz,
    this.maxKhz,
    this.governor,
  });

  /// "Prime", "Gold", "Silver", "Big", "Mid", "Little", or "CPU".
  ///
  /// A STRING, NOT AN ENUM, for the reason in the file header. Also because the
  /// naming depends on the topology: a 1 + 3 + 4 layout gets Prime/Gold/Silver,
  /// a 4 + 4 gets Big/Little, and a uniform part gets one cluster called CPU.
  final String label;

  /// Zero-based core indices in this domain, ascending.
  final List<int> coreIds;

  final int? minKhz;
  final int? maxKhz;
  final String? governor;
}

/// Static CPU description, read once. Codec 131.
class CpuInfo {
  CpuInfo({
    required this.coreCount,
    required this.clusters,
    this.socModel,
    this.hardware,
    this.abi,
  });

  final int coreCount;

  /// Ordered fastest first. Empty when nothing under `/sys/devices/system/cpu`
  /// could be read, which is not the same as a single-cluster device.
  final List<CpuCluster> clusters;

  /// `Build.SOC_MODEL`, API 31+. Null below that or when the OEM leaves it
  /// unknown, which several Transsion builds do.
  final String? socModel;

  final String? hardware;
  final String? abi;
}

/// Live CPU sample. Codec 132.
///
/// CUMULATIVE COUNTERS, NOT RATES. A rate needs two samples and an interval, and
/// the ticker that owns the interval lives in Dart. Native reads and returns.
/// The delta arithmetic stays in one tested place, and it stays correct when a
/// frame is late because [DeviceSnapshot.elapsedRealtimeMillis] is the divisor.
class CpuSample {
  CpuSample({
    required this.coreKhz,
    required this.coreOnline,
    this.idleJiffies,
    this.totalJiffies,
  });

  /// Per core, index-aligned with [CpuCluster.coreIds]. An entry is null when
  /// the core is offline OR unreadable, which is why [coreOnline] exists
  /// alongside rather than being inferred from a null here.
  final List<int?> coreKhz;

  /// From each core's `online` file. Null where that file itself is
  /// unreadable. Core 0 has no
  /// `online` file on many kernels because it cannot be offlined, and is
  /// reported as true.
  final List<bool?> coreOnline;

  /// Aggregate `cpu` line of `/proc/stat`: idle+iowait, and the grand total.
  /// Both null together or neither.
  final int? idleJiffies;
  final int? totalJiffies;
}

/// One thermal sensor. Codec 133.
class ThermalZone {
  ThermalZone({
    required this.zoneId,
    required this.label,
    required this.category,
    required this.milliCelsius,
  });

  final int zoneId;

  /// The raw `type` file contents, for example "battery" or "mtktsbattery" or
  /// "VIRTUAL-SKIN". Shown verbatim in the detail list because OEM naming is
  /// the only ground truth about what is being measured.
  final String label;

  /// "battery" | "cpu" | "gpu" | "skin" | "modem" | "ambient" | "other".
  /// Derived from [label] by substring match, String for the header's reason.
  /// "other" is common and correct, not a failure.
  final String category;

  /// MILLIDEGREES CELSIUS, normalised here and only here.
  ///
  /// Kernels report this zone in millidegrees, decidegrees or whole degrees with
  /// no way to ask which. Native applies a magnitude heuristic once so every
  /// consumer sees one unit. Dart divides by 1000 at the point of display.
  final int milliCelsius;
}

/// Codec 134.
class ThermalSample {
  ThermalSample({required this.zones, this.status});

  /// Empty when `/sys/class/thermal` is not readable, which is the common case
  /// on recent Samsung and Pixel builds.
  final List<ThermalZone> zones;

  /// `PowerManager.getCurrentThermalStatus()`, 0 (none) to 6 (shutdown).
  /// Available even when [zones] is empty, and often the only thermal signal
  /// a device will give up.
  final int? status;
}

/// Codec 135.
class BatterySnapshot {
  BatterySnapshot({
    this.percent,
    this.charging,
    this.status,
    this.health,
    this.technology,
    this.tempDeciC,
    this.currentMicroA,
    this.voltageMilliV,
    this.cycleCount,
    this.chargeCounterMicroAh,
  });

  /// 0-100, computed from level and scale rather than assuming scale is 100.
  final int? percent;

  final bool? charging;

  /// "charging" | "discharging" | "full" | "notCharging" | "unknown".
  final String? status;

  /// "good" | "overheat" | "dead" | "overVoltage" | "cold" | "failure" |
  /// "unknown". Note that "good" is what almost every device reports right up
  /// until it does not, so this is informational and never a health score.
  final String? health;

  final String? technology;

  /// TENTHS of a degree Celsius, exactly as Android reports it. Kept in the
  /// platform's own unit so the conversion happens once, at display, rather
  /// than rounding twice.
  final int? tempDeciC;

  /// MICROAMPS from `BATTERY_PROPERTY_CURRENT_NOW`.
  ///
  /// THE SIGN IS NOT PORTABLE. Most OEMs report negative while discharging;
  /// several Samsung and Xiaomi builds report positive. Display the MAGNITUDE
  /// and take direction from [charging], which is the one signal that is
  /// consistent everywhere. Do not "fix" this by trusting the sign.
  final int? currentMicroA;

  final int? voltageMilliV;

  /// API 34+, and null on plenty of devices above it.
  final int? cycleCount;

  final int? chargeCounterMicroAh;
}

/// Codec 136.
class MemorySnapshot {
  MemorySnapshot({
    this.totalBytes,
    this.availBytes,
    this.thresholdBytes,
    this.lowMemory,
    this.swapTotalBytes,
    this.swapFreeBytes,
  });

  /// `ActivityManager.MemoryInfo`, NOT `/proc/meminfo`. Same restriction story
  /// as `/proc/stat`, and this one needs no file read at all.
  final int? totalBytes;
  final int? availBytes;

  /// The level at which Android starts killing background processes. Worth
  /// showing because "2 GB free" means nothing without it.
  final int? thresholdBytes;

  final bool? lowMemory;

  /// zram, on nearly every budget device. From `/proc/meminfo`, which is
  /// readable where `/proc/stat` is not.
  final int? swapTotalBytes;
  final int? swapFreeBytes;
}

/// One sensor as the device advertises it. Codec 137.
class SensorInfo {
  SensorInfo({
    required this.handle,
    required this.type,
    required this.name,
    required this.category,
    required this.valueCount,
    required this.wakeUp,
    required this.readable,
    this.vendor,
    this.stringType,
    this.maxRange,
    this.resolution,
    this.powerMilliAmp,
    this.minDelayMicros,
  });

  /// Index into the device's sensor list. Stable for the process only, which is
  /// all a UI session needs, and unlike `Sensor.getId()` it is never 0 for
  /// everything.
  final int handle;

  /// The raw Android type constant. Kept alongside [category] so an unknown
  /// OEM sensor can still be identified in a bug report.
  final int type;

  final String name;

  /// "motion" | "position" | "environment" | "body" | "composite" | "other".
  final String category;

  /// 1 for a scalar such as light, 3 for a vector such as the accelerometer.
  /// Drives whether the UI draws a number or a three-axis sparkline.
  final int valueCount;

  final bool wakeUp;

  /// False when the sensor is present but the app may not register for it,
  /// which is the case for heart rate and other BODY_SENSORS types.
  ///
  /// Reported rather than filtered out. A user looking for their heart rate
  /// sensor needs to see "present, blocked by the system" instead of an
  /// unexplained absence.
  final bool readable;

  final String? vendor;
  final String? stringType;
  final double? maxRange;
  final double? resolution;

  /// Milliamps while active, as declared by the driver. Frequently optimistic.
  final double? powerMilliAmp;

  final int? minDelayMicros;
}

/// One tick. Codec 138.
///
/// A COMPOSITE RATHER THAN FOUR CALLS, because at 2 Hz four channel round trips
/// per tick is four times the platform-thread wakeups for the same data, and
/// the four readings would no longer share a single sample clock.
class DeviceSnapshot {
  DeviceSnapshot({
    required this.elapsedRealtimeMillis,
    this.cpu,
    this.thermal,
    this.battery,
    this.memory,
  });

  /// `SystemClock.elapsedRealtime()`. Milliseconds since boot INCLUDING deep
  /// sleep, which is what makes it usable across a screen-off gap.
  ///
  /// Never null: if this is unavailable the process is not running. It is both
  /// the uptime row AND the divisor every rate is computed against.
  final int elapsedRealtimeMillis;

  final CpuSample? cpu;
  final ThermalSample? thermal;
  final BatterySnapshot? battery;
  final MemorySnapshot? memory;
}


/// WHAT THIS DEVICE WILL LET US TOUCH. Codec 139.
///
/// ─── WHY THIS IS NOT DERIVED FROM A VERSION NUMBER IN DART ──────────────────
///
/// It could be, and it would be wrong about half the time. The API level says
/// which permissions EXIST; it says nothing about which were granted, and a
/// screen that decides what to offer from the level alone offers a restore that
/// then fails at the last step. Both halves are read natively and reported
/// together.
///
/// ─── THE THREE TIERS ARE NOT BETTER AND WORSE ───────────────────────────────
///
/// This app runs from API 24, and the oldest devices have the MOST file access,
/// not the least. Android 11 is what closed per app storage to outside readers.
/// A 2017 phone can read another app's trash folder with a plain storage
/// permission; a 2024 phone cannot at any price.
///
///   legacy   24 to 28, whole volume readable, no platform trash bin
///   scoped   29 exactly, neither legacy access nor all files access exists
///   managed  30 and up, all files access and the trash bin, per app storage
///            closed to direct reads
///
/// 29 is genuinely thin and nothing here can fix it: the platform removed the
/// old route one release before it added the new one. The UI's job is to say so
/// rather than to offer a scan that finds nothing.
class StorageAccess {
  StorageAccess({
    required this.sdkInt,
    required this.tier,
    required this.osTrashBin,
    required this.allFilesAccessPossible,
    required this.allFilesAccessGranted,
    required this.legacyStorageGranted,
    required this.appDataReadable,
    required this.mediaStoreOnly,
  });

  /// `Build.VERSION.SDK_INT`. Reported alongside [tier] rather than instead of
  /// it, because a bug report needs the number and a screen needs the tier.
  final int sdkInt;

  /// "legacy" | "scoped" | "managed". A String for the reason in the file
  /// header, and because a fourth tier is a matter of when rather than if.
  final String tier;

  /// `MediaStore.IS_TRASHED` and the system bin, API 30 and up. The only
  /// recovery route the platform itself blesses.
  final bool osTrashBin;

  /// The All Files Access settings screen exists AND resolves. False below 30,
  /// and false on the handful of ROMs that ship without the screen, where
  /// asking would send the user somewhere that does not open.
  final bool allFilesAccessPossible;

  /// `Environment.isExternalStorageManager()`. THE GRANT, not the possibility.
  /// [allFilesAccessPossible] true with this false is the state that deserves a
  /// button; both false deserves an explanation.
  final bool allFilesAccessGranted;

  /// Read and write to shared storage held on API 24 to 28. Always false above
  /// that, where the permission is either capped in the manifest or no longer
  /// grants what its name suggests.
  final bool legacyStorageGranted;

  /// Whether per app storage can be walked directly. True on the legacy tier
  /// with the grant, false everywhere from API 29. This single field is the
  /// difference between a scan that reaches another app's trash folder and one
  /// that cannot see it at any permission level.
  final bool appDataReadable;

  /// Nothing but MediaStore and whatever a document tree grant provides. True
  /// on the scoped tier, and on the managed tier until the grant is given.
  final bool mediaStoreOnly;
}

@HostApi()
abstract class DeviceProbeHostApi {
  /// Probed once natively, cached for the process. Call this before rendering
  /// anything: it decides which sections exist at all.
  @async
  ProbeCapabilities capabilities();

  /// Static description. Read once per app launch; core topology does not
  /// change while the process is alive.
  @async
  CpuInfo cpuInfo();

  /// The full sensor list including entries this app may not register for.
  /// `@async` because it walks the whole list and resolves permissions.
  @async
  List<SensorInfo> sensors();

  /// One tick of everything live. Called on the sampler's interval.
  ///
  /// Sections that this device refuses come back null rather than as an object
  /// full of nulls, so the UI can drop an entire card instead of drawing an
  /// empty one.
  @async
  DeviceSnapshot readSnapshot();

  /// Which storage tier this device is on and what was actually granted.
  ///
  /// NOT CACHED, unlike [capabilities]. All Files Access can be granted and
  /// revoked from Settings while the process is alive, so a cached answer would
  /// have the app offering a scan the system will refuse, or refusing one it
  /// would now allow. Call it when a screen that depends on it appears, and
  /// again on resume.
  @async
  StorageAccess storageAccess();
}
