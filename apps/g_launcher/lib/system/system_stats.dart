import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../platform/launcher_api.g.dart' as api;

/// What the conky tile and every monitor desklet read.
///
/// ─── WHY THIS FILE STOPPED READING /proc (PHASE D1) ─────────────────────────
///
/// It used to open `/proc/meminfo` and `/proc/stat` directly. On a Galaxy S22
/// `/proc/stat` returns nothing, and that is not a bug with a fix: SELinux has
/// progressively restricted proc access and OEMs restrict further on top.
///
/// There is NO permission-free system-wide CPU API on modern Android. Not
/// restricted — absent. So the CPU row is genuinely unavailable on most current
/// hardware, the read is still ATTEMPTED once (budget Infinix/Tecno/Xiaomi ROMs
/// are frequently laxer than Samsung, and those are the target devices), and
/// when it fails the row is absent rather than fabricated.
///
/// Everything else moved to APIs that still work and have no Dart equivalent:
/// ActivityManager for memory, StatFs for storage, TrafficStats for network,
/// BatteryManager for the detail rows. Hence `DeviceStatsReader` on the native
/// side and this file as a thin consumer of it.
///
/// ─── EVERY FIELD IS STILL NULLABLE, FOR THE SAME REASON ─────────────────────
///
/// Null means "this device will not tell us" and the consumer hides the row.
/// A conky rendering `cpu --%` is worse than a conky with one fewer line.
/// Use [statCapabilitiesProvider] to tell "never" from "not sampled yet".

@immutable
class SystemStats {
  const SystemStats({
    this.batteryPercent,
    this.cpuPercent,
    this.memUsedGb,
    this.memTotalGb,
    this.netDownBytesPerSec,
    this.netUpBytesPerSec,
    this.wifiConnected = true,
    this.muted = false,
    this.batteryCharging,
    this.batteryTempC,
    this.batteryCurrentMa,
    this.storageUsedBytes,
    this.storageTotalBytes,
    this.thermalStatus,
    this.transport,
    this.uptime,
  });

  // ── original surface, unchanged ────────────────────────────────────────────
  // Every field below this comment predates D1 and keeps its exact name, type
  // and meaning. The rewrite is ADDITIVE on the value type for the same reason
  // it is additive on the Pigeon schema: existing call sites must not need a
  // single edit to keep compiling.

  final int? batteryPercent;
  final int? cpuPercent;
  final double? memUsedGb;
  final double? memTotalGb;
  final double? netDownBytesPerSec;
  final double? netUpBytesPerSec;
  final bool wifiConnected;
  final bool muted;

  // ── added in D1 ────────────────────────────────────────────────────────────

  final bool? batteryCharging;

  /// Degrees Celsius. Native reports tenths; the single conversion happens on
  /// the way in so nothing downstream has to remember the unit.
  final double? batteryTempC;

  /// MILLIAMPS, MAGNITUDE ONLY, always positive.
  ///
  /// The platform's sign is not portable — most OEMs report negative while
  /// discharging, several Samsung and Xiaomi builds report positive. Direction
  /// comes from [batteryCharging], which is consistent everywhere. Do not
  /// reintroduce the sign here.
  final int? batteryCurrentMa;

  /// Data partition. The same number Settings shows, and the same one G
  /// Recovery will report — a storage tile that disagrees with the OS is a
  /// storage tile nobody trusts.
  final int? storageUsedBytes;
  final int? storageTotalBytes;

  /// 0 (none) to 6 (shutdown). API 29+.
  final int? thermalStatus;

  /// "wifi" | "cellular" | "ethernet" | "vpn" | "none".
  ///
  /// The transport, never the SSID: reading the network NAME needs location
  /// permission on Android 10+, and this ecosystem does not ask for location to
  /// draw a desktop widget.
  final String? transport;

  final Duration? uptime;

  bool get hasMemory => memUsedGb != null && memTotalGb != null;
  bool get hasNet => netDownBytesPerSec != null && netUpBytesPerSec != null;
  bool get hasStorage => storageUsedBytes != null && storageTotalBytes != null;

  /// `3.1/8G` — the mockup's format exactly.
  String get memLabel => hasMemory
      ? '${memUsedGb!.toStringAsFixed(1)}/${memTotalGb!.round()}G'
      : '';

  /// `4.2M`, `0.8M`, `47K`.
  ///
  /// The M threshold is 0.1 MB, not 1.0 — a test caught this against the
  /// mockup, which shows `↑ 0.8M`. The old `mb >= 1` rendered that as `819K`,
  /// which is technically fine and looks wrong next to a `↓ 4.2M`: mixed units
  /// on one line make the eye do arithmetic. Below 0.1M (≈100KB/s) kilobytes
  /// genuinely read better than `0.0M`.
  static String rate(double? bytesPerSec) {
    if (bytesPerSec == null) return '—';
    final mb = bytesPerSec / (1024 * 1024);
    if (mb >= 0.1) return '${mb.toStringAsFixed(1)}M';
    final kb = bytesPerSec / 1024;
    return '${kb.toStringAsFixed(0)}K';
  }

  /// `12.4G` / `118G`. Shared by the storage desklet and the terminal's `df -h`.
  static String bytes(int? b) {
    if (b == null) return '—';
    const gb = 1024 * 1024 * 1024;
    if (b >= gb) {
      final g = b / gb;
      return g >= 100 ? '${g.round()}G' : '${g.toStringAsFixed(1)}G';
    }
    return '${(b / (1024 * 1024)).round()}M';
  }
}

/// What this specific device will actually serve.
///
/// Asked ONCE. The native side probes by really reading each source (a version
/// check tells you what the API level promises; only the read tells you what
/// this ROM allows) and caches the answer for the process.
///
/// A desklet needs this to tell "this phone never provides CPU" from "the rate
/// has not been sampled yet" — both are null in a snapshot, and they deserve
/// different UI. Without it, a half-empty panel is indistinguishable from a bug.
final statCapabilitiesProvider = FutureProvider<api.StatCapabilities>((ref) {
  return api.LauncherHostApi().getStatCapabilities();
});

/// How often the ticker samples while the launcher is on screen.
///
/// 3 seconds, not 1. The home screen is visible whenever the phone is, so a
/// 1-second poll is a permanent wakeup and a measurable battery cost on exactly
/// the budget devices this app targets. 3s still reads as live.
const _interval = Duration(seconds: 3);

/// Live device stats. ONE ticker for every desklet on screen.
///
/// ─── LIFECYCLE PAUSE IS THE POINT ───────────────────────────────────────────
///
/// This is the single biggest perf trap in the desklet phase. The launcher is
/// the app that is always "open", so a naive poll runs 28,800 times a day
/// whether or not anyone is looking at it. The ticker stops on
/// [AppLifecycleState.paused] and resumes with an immediate sample, so a phone
/// in a pocket costs nothing.
///
/// Still a `StreamProvider<SystemStats>` with the same name and type it has
/// always had, deliberately: every existing consumer keeps compiling untouched.
final systemStatsProvider = StreamProvider<SystemStats>((ref) {
  final poller = _StatsPoller();
  ref.onDispose(poller.dispose);
  poller.start();
  return poller.stream;
});

class _StatsPoller {
  _StatsPoller();

  final _host = api.LauncherHostApi();
  final _out = StreamController<SystemStats>.broadcast();

  Timer? _timer;
  AppLifecycleListener? _lifecycle;
  api.DeviceStats? _prev;
  bool _reading = false;

  Stream<SystemStats> get stream => _out.stream;

  void start() {
    _lifecycle = AppLifecycleListener(
      onPause: _stopTimer,
      onHide: _stopTimer,
      // An immediate sample on the way back, so returning to the desktop does
      // not show a stale panel for up to three seconds.
      onResume: () {
        // DROP THE PREVIOUS SAMPLE. The counters kept climbing while the screen
        // was off, so a delta across the gap would report the average network
        // rate over an entire night as if it were happening now. One skipped
        // rate reading is the honest price.
        _prev = null;
        _startTimer();
        unawaited(_tick());
      },
    );
    _startTimer();
    unawaited(_tick());
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) => unawaited(_tick()));
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _tick() async {
    // A slow read must never queue up behind itself. On a cold cache the first
    // StatFs can take longer than the interval, and without this guard the
    // timer would stack calls until they all land at once.
    if (_reading || _out.isClosed) return;
    _reading = true;
    try {
      final now = await _host.readStats();
      if (_out.isClosed) return;
      _out.add(_toStats(_prev, now));
      _prev = now;
    } catch (e) {
      // A failed bridge call must not kill the stream — the desktop keeps its
      // last good panel and tries again in three seconds.
      debugPrint('stats: read failed ($e)');
    } finally {
      _reading = false;
    }
  }

  void dispose() {
    _stopTimer();
    _lifecycle?.dispose();
    _out.close();
  }
}

/// Native returns CUMULATIVE COUNTERS; the rates are computed here.
///
/// All delta arithmetic lives on this side because a rate needs two samples and
/// an interval, and the ticker owns the interval. Keeping it in one place also
/// keeps it testable without a device, which the old CPU code already proved
/// was worth it.
SystemStats _toStats(api.DeviceStats? prev, api.DeviceStats now) {
  final elapsedMs = prev == null
      ? null
      : now.elapsedRealtimeMillis - prev.elapsedRealtimeMillis;

  // A non-positive interval means the clock did not advance between samples —
  // impossible in normal operation, catastrophic as a divisor.
  final seconds =
      (elapsedMs == null || elapsedMs <= 0) ? null : elapsedMs / 1000.0;

  const bytesPerGb = 1024 * 1024 * 1024;
  final memTotal = now.memTotalBytes;
  final memAvail = now.memAvailBytes;

  final storageTotal = now.storageTotalBytes;
  final storageFree = now.storageFreeBytes;

  return SystemStats(
    batteryPercent: now.batteryPercent,
    batteryCharging: now.batteryCharging,
    batteryTempC:
        now.batteryTempDeciC == null ? null : now.batteryTempDeciC! / 10.0,
    // Magnitude only; see the field doc. Microamps to milliamps.
    batteryCurrentMa: now.batteryCurrentMicroA == null
        ? null
        : (now.batteryCurrentMicroA!.abs() / 1000).round(),

    cpuPercent: _cpuPercent(prev, now),

    memUsedGb: (memTotal == null || memAvail == null)
        ? null
        : (memTotal - memAvail).clamp(0, memTotal) / bytesPerGb,
    memTotalGb: memTotal == null ? null : memTotal / bytesPerGb,

    storageUsedBytes: (storageTotal == null || storageFree == null)
        ? null
        : (storageTotal - storageFree).clamp(0, storageTotal),
    storageTotalBytes: storageTotal,

    netDownBytesPerSec: _rate(prev?.netRxBytes, now.netRxBytes, seconds),
    netUpBytesPerSec: _rate(prev?.netTxBytes, now.netTxBytes, seconds),

    transport: now.netTransport,
    // Preserved for existing consumers. Unknown transport keeps the old
    // optimistic default rather than drawing a disconnected icon on a device
    // that simply would not answer.
    wifiConnected: now.netTransport == null ? true : now.netTransport != 'none',

    thermalStatus: now.thermalStatus,
    uptime: Duration(milliseconds: now.elapsedRealtimeMillis),
  );
}

double? _rate(int? prev, int? now, double? seconds) {
  if (prev == null || now == null || seconds == null) return null;
  final delta = now - prev;
  // A negative delta means the counter reset (reboot, or TrafficStats rolling).
  // Publishing it would draw a downward spike on a graph that cannot go down.
  if (delta < 0) return null;
  return delta / seconds;
}

int? _cpuPercent(api.DeviceStats? prev, api.DeviceStats now) {
  final pIdle = prev?.cpuIdleJiffies;
  final pTotal = prev?.cpuTotalJiffies;
  final nIdle = now.cpuIdleJiffies;
  final nTotal = now.cpuTotalJiffies;
  if (pIdle == null || pTotal == null || nIdle == null || nTotal == null) {
    return null;
  }
  final totalDelta = nTotal - pTotal;
  final idleDelta = nIdle - pIdle;
  if (totalDelta <= 0) return null; // clock unchanged or counters reset
  final busy = (totalDelta - idleDelta) / totalDelta * 100;
  return busy.clamp(0, 100).round();
}

/// The clock. Separate from stats because it is pure Dart, it is the ONE thing
/// the conky can always show, and it must tick ON the minute rather than on a
/// 60s timer started at an arbitrary moment — otherwise the display can lag the
/// real minute by up to 59 seconds, which people notice immediately on a clock
/// that is 30px tall.
final clockProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();

  while (true) {
    final now = DateTime.now();
    final nextMinute = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute + 1,
    );
    await Future<void>.delayed(nextMinute.difference(now));
    yield DateTime.now();
  }
});

/// `19:42` — 24-hour, always. GNOME's default, and the mockup's.
String formatTime(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _daysLong = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// `Thu 18 Jun` — top bar.
String formatDateShort(DateTime t) =>
    '${_days[t.weekday - 1]} ${t.day} ${_months[t.month - 1].substring(0, 3)}';

/// `Thursday, 18 June` — conky.
String formatDateLong(DateTime t) =>
    '${_daysLong[t.weekday - 1]}, ${t.day} ${_months[t.month - 1]}';

/// `3d 4h 12m` — the fastfetch uptime row, and the terminal's `uptime`.
///
/// This REPLACES the deferred `g_launcher/uptime` MethodChannel. Uptime now
/// rides the stats snapshot (it is `elapsedRealtimeMillis`, which the snapshot
/// already carries as its sample clock), so the separate channel is strictly
/// less code for the same value and should not be added.
String formatUptime(Duration? d) {
  if (d == null) return '—';
  final days = d.inDays;
  final hours = d.inHours % 24;
  final minutes = d.inMinutes % 60;
  if (days > 0) return '${days}d ${hours}h ${minutes}m';
  if (hours > 0) return '${hours}h ${minutes}m';
  return '${minutes}m';
}
