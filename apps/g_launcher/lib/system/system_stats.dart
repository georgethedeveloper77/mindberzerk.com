import 'dart:async';
import 'dart:io';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the top bar tray and the conky tile need.
///
/// Everything here is nullable, and every consumer hides the row when the value
/// is null. That is not defensiveness for its own sake — CPU and memory come
/// from `/proc`, which OEMs restrict inconsistently, and a conky that renders
/// `cpu --%` on a Tecno is worse than a conky with one fewer line.

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
  });

  final int? batteryPercent;
  final int? cpuPercent;
  final double? memUsedGb;
  final double? memTotalGb;
  final double? netDownBytesPerSec;
  final double? netUpBytesPerSec;
  final bool wifiConnected;
  final bool muted;

  bool get hasMemory => memUsedGb != null && memTotalGb != null;
  bool get hasNet => netDownBytesPerSec != null && netUpBytesPerSec != null;

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
}

/// Live device stats, polled from Dart.
///
/// Sources, and why each is where it is:
///   battery  battery_plus (BatteryManager under the hood). Always available.
///   memory   /proc/meminfo. World-readable on effectively every Android build,
///            so this is the reliable /proc line.
///   cpu      /proc/stat, as a busy/total delta between two ticks. SELinux on
///            some Infinix/Tecno/Xiaomi ROMs blocks proc_stat for untrusted
///            apps, so this read is the one most likely to come back null, and
///            that is fine, the row just hides.
///   net      NOT here. /proc/net/dev is uid-scoped on modern Android and
///            returns nothing useful to a sandboxed app, so an honest launcher
///            leaves the net rows absent rather than showing a fabricated 0.
///            It needs a native TrafficStats channel; that is the one piece of
///            this tile that stays native.
///
/// Every read is wrapped: any failure becomes null, which is the whole contract
/// the SystemStats consumers are built around. On a locked-down ROM the conky
/// quietly shows battery + RAM and drops CPU, instead of lying.
///
/// Poll at ~3s, not 1s: the conky is on screen whenever the phone is, and a
/// 1-second poll is a permanent wakeup, a measurable battery cost on the exact
/// budget devices this app is for. 3 seconds still looks live. The first tick
/// has no CPU value (a delta needs two samples), so CPU appears on the second.
final systemStatsProvider = StreamProvider<SystemStats>((ref) async* {
  final battery = Battery();
  _CpuTimes? prevCpu;

  while (true) {
    final results = await Future.wait([
      _readBatteryPercent(battery),
      _readMemory(),
      _readCpuTimes(),
    ]);

    final batteryPercent = results[0] as int?;
    final mem = results[1] as _Mem?;
    final cpuNow = results[2] as _CpuTimes?;

    final cpuPercent = _cpuPercent(prevCpu, cpuNow);
    if (cpuNow != null) prevCpu = cpuNow;

    yield SystemStats(
      batteryPercent: batteryPercent,
      cpuPercent: cpuPercent,
      memUsedGb: mem?.usedGb,
      memTotalGb: mem?.totalGb,
      // net intentionally left null; see the doc above.
    );

    await Future<void>.delayed(const Duration(seconds: 3));
  }
});

Future<int?> _readBatteryPercent(Battery battery) async {
  try {
    final level = await battery.batteryLevel;
    return (level < 0 || level > 100) ? null : level;
  } catch (_) {
    return null;
  }
}

class _Mem {
  const _Mem(this.usedGb, this.totalGb);
  final double usedGb;
  final double totalGb;
}

Future<_Mem?> _readMemory() async {
  try {
    final lines = await File('/proc/meminfo').readAsLines();
    int? totalKb;
    int? availKb;
    for (final line in lines) {
      if (line.startsWith('MemTotal:')) {
        totalKb = _firstInt(line);
      } else if (line.startsWith('MemAvailable:')) {
        availKb = _firstInt(line);
      }
      if (totalKb != null && availKb != null) break;
    }
    if (totalKb == null || availKb == null) return null;

    final usedKb = (totalKb - availKb).clamp(0, totalKb);
    const kbPerGb = 1024 * 1024;
    return _Mem(usedKb / kbPerGb, totalKb / kbPerGb);
  } catch (_) {
    return null;
  }
}

/// The idle and grand-total jiffy counters from the aggregate `cpu` line of
/// /proc/stat. Meaningless on their own; a percentage falls out of the delta
/// between two of these.
class _CpuTimes {
  const _CpuTimes(this.idle, this.total);
  final int idle;
  final int total;
}

Future<_CpuTimes?> _readCpuTimes() async {
  try {
    final content = await File('/proc/stat').readAsString();
    final firstLine = content.split('\n').first;
    if (!firstLine.startsWith('cpu ')) return null;

    final nums = firstLine
        .trim()
        .split(RegExp(r'\s+'))
        .skip(1) // drop the "cpu" label
        .map(int.tryParse)
        .whereType<int>()
        .toList();
    if (nums.length < 4) return null;

    // Fields: user nice system idle iowait irq softirq steal ...
    // Idle time is idle + iowait; everything summed is the total.
    final idle = nums[3] + (nums.length > 4 ? nums[4] : 0);
    final total = nums.fold<int>(0, (a, b) => a + b);
    return _CpuTimes(idle, total);
  } catch (_) {
    return null;
  }
}

int? _cpuPercent(_CpuTimes? prev, _CpuTimes? cur) {
  if (prev == null || cur == null) return null;
  final totalDelta = cur.total - prev.total;
  final idleDelta = cur.idle - prev.idle;
  if (totalDelta <= 0) return null; // clock unchanged or counters reset
  final busy = (totalDelta - idleDelta) / totalDelta * 100;
  return busy.clamp(0, 100).round();
}

int? _firstInt(String line) {
  final match = RegExp(r'(\d+)').firstMatch(line);
  return match == null ? null : int.tryParse(match.group(1)!);
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
