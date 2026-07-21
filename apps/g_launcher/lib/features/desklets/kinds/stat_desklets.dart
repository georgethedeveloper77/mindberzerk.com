import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/prefs/launcher_prefs.dart';
import '../../../data/repositories/shell_apps.dart';
import '../../../design/terminal_tokens.dart' show deviceInfoProvider;
import '../../../engine/desklet_skin.dart';
import '../../../engine/effective_theme.dart';
import '../../../system/system_stats.dart';
import '../desklet_frame.dart';

/// The stats-backed desklets. PHASE D5.
///
/// Five kinds, one file, because they are five queries against the SAME
/// snapshot and splitting them across five files would mostly duplicate
/// imports. Each is a function from stats to rows; [DeskletFrame] draws them.
///
/// ─── THE RULE EVERY ROW HERE OBEYS ──────────────────────────────────────────
///
/// A desklet earns its place only if Android does not already show it at a
/// glance. The status bar owns the clock, the battery PERCENTAGE and the
/// connection state, which is exactly why this launcher's own top bar is
/// transparent and empty.
///
/// So the battery desklet is not a percentage: it is draw in mA, cell
/// temperature and thermal state. The network desklet is not "connected": it is
/// live throughput. Anything one swipe away does not ship.
///
/// ─── AND THE ONE ABOUT NULLS ────────────────────────────────────────────────
///
/// A missing stat REMOVES ITS ROW. There is no `--%` anywhere, and
/// [DeskletRow.value] has no way to express absence precisely so that a caller
/// cannot invent one. On a locked-down Galaxy the monitor shows five good rows
/// instead of six, and the sixth was never promised.
///
/// [statCapabilitiesProvider] is deliberately NOT consulted here. The debug
/// screen needs to distinguish "this device refuses" from "not sampled yet"; a
/// desklet does not, because both answers render identically. Asking would add
/// a second async dependency to every tile for no visible difference.

// ─── monitor (the conky) ─────────────────────────────────────────────────────

/// REPLACES `features/home/gnome/conky_tile.dart`, which was nailed to the top
/// right of one shell and read `Ubuntu.*` tokens directly. Same information,
/// placeable, resizable, and skinned per distro. Delete the old one.
class MonitorDesklet extends ConsumerWidget {
  const MonitorDesklet({
    super.key,
    required this.theme,
    required this.desklet,
    required this.skin,
  });

  final EffectiveTheme theme;
  final Desklet desklet;
  final DeskletSkin skin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(systemStatsProvider).asData?.value;

    final rows = <DeskletRow>[
      if (s?.cpuPercent != null)
        DeskletRow('cpu', value: '${s!.cpuPercent}%', accent: true),
      if (s?.hasMemory ?? false)
        DeskletRow(
          'mem',
          value: s!.memLabel,
          fraction: s.memTotalGb == null || s.memTotalGb == 0
              ? null
              : s.memUsedGb! / s.memTotalGb!,
        ),
      if (s?.hasStorage ?? false)
        DeskletRow(
          'disk',
          value: '${SystemStats.bytes(s!.storageUsedBytes)}'
              ' / ${SystemStats.bytes(s.storageTotalBytes)}',
          fraction: s.storageTotalBytes == 0
              ? null
              : s.storageUsedBytes! / s.storageTotalBytes!,
        ),
      if (s?.hasNet ?? false)
        DeskletRow(
          'net',
          value: '\u2193 ${SystemStats.rate(s!.netDownBytesPerSec)}'
              '  \u2191 ${SystemStats.rate(s.netUpBytesPerSec)}',
        ),
      if (s?.batteryPercent != null)
        DeskletRow(
          'bat',
          value: s!.batteryCurrentMa == null
              ? '${s.batteryPercent}%'
              : '${s.batteryPercent}%  ${_signed(s)}mA',
        ),
      if (thermalLabel(s?.thermalStatus) != null)
        DeskletRow('temp', value: thermalLabel(s!.thermalStatus)),
      if (s?.uptime != null)
        DeskletRow('up', value: formatUptime(s!.uptime)),
    ];

    return DeskletFrame(
      theme: theme,
      skin: skin,
      body: DeskletBody(
        title: skin.flag('showTitle', false) ? 'system' : null,
        command: 'conky',
        rows: rows,
      ),
    );
  }
}

/// Direction from the CHARGING FLAG, never from the platform's sign, which is
/// negative-while-discharging on most OEMs and positive on several Samsung and
/// Xiaomi builds. `SystemStats.batteryCurrentMa` is already a magnitude.
String _signed(SystemStats s) =>
    '${s.batteryCharging == true ? '+' : '-'}${s.batteryCurrentMa}';

/// `PowerManager.THERMAL_STATUS_*`, named. Null below API 29 and on a device
/// that will not answer, in which case the row is absent.
String? thermalLabel(int? v) => switch (v) {
      0 => 'nominal',
      1 => 'light',
      2 => 'moderate',
      3 => 'severe',
      4 => 'critical',
      5 => 'emergency',
      6 => 'shutdown',
      _ => null,
    };

// ─── network ─────────────────────────────────────────────────────────────────

class NetworkDesklet extends ConsumerWidget {
  const NetworkDesklet({
    super.key,
    required this.theme,
    required this.desklet,
    required this.skin,
  });

  final EffectiveTheme theme;
  final Desklet desklet;
  final DeskletSkin skin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(systemStatsProvider).asData?.value;

    return DeskletFrame(
      theme: theme,
      skin: skin,
      body: DeskletBody(
        title: skin.flag('showTitle', false) ? 'network' : null,
        command: 'ifstat',
        rows: [
          // The transport, never the SSID. Reading the network NAME needs
          // location permission on Android 10+, and this ecosystem does not ask
          // for location to draw a widget.
          if (s?.transport != null)
            DeskletRow('link', value: s!.transport, accent: true),
          if (s?.netDownBytesPerSec != null)
            DeskletRow('down',
                value: SystemStats.rate(s!.netDownBytesPerSec)),
          if (s?.netUpBytesPerSec != null)
            DeskletRow('up', value: SystemStats.rate(s!.netUpBytesPerSec)),
        ],
      ),
    );
  }
}

// ─── storage ─────────────────────────────────────────────────────────────────

/// The first ecosystem hook. This is `StatFs` on the data partition, which is
/// the number Settings shows and the number G Recovery will report. Those three
/// agreeing matters more than technical completeness: a storage tile that
/// disagrees with the OS is a storage tile nobody trusts, and the whole G
/// Recovery pitch is that it tells the truth about space.
class StorageDesklet extends ConsumerWidget {
  const StorageDesklet({
    super.key,
    required this.theme,
    required this.desklet,
    required this.skin,
  });

  final EffectiveTheme theme;
  final Desklet desklet;
  final DeskletSkin skin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(systemStatsProvider).asData?.value;
    if (s == null || !s.hasStorage) {
      return DeskletFrame(theme: theme, skin: skin, body: const DeskletBody());
    }

    final used = s.storageUsedBytes!;
    final total = s.storageTotalBytes!;
    final free = total - used;

    return DeskletFrame(
      theme: theme,
      skin: skin,
      body: DeskletBody(
        title: skin.flag('showTitle', true) ? 'storage' : null,
        command: 'df -h',
        rows: [
          DeskletRow(
            'used',
            value: '${SystemStats.bytes(used)} / ${SystemStats.bytes(total)}',
            fraction: total == 0 ? null : used / total,
          ),
          DeskletRow('free', value: SystemStats.bytes(free), accent: true),
        ],
      ),
    );
  }
}

// ─── battery detail ──────────────────────────────────────────────────────────

/// NOT a percentage. Android's status bar already shows one, so a desklet that
/// repeated it would fail the earn-its-place rule outright.
///
/// Draw in mA, cell temperature and thermal state are none of them one swipe
/// away, and on a budget phone they are the numbers that actually answer "why
/// is this thing dying". The percentage appears only as context beside them.
class BatteryDesklet extends ConsumerWidget {
  const BatteryDesklet({
    super.key,
    required this.theme,
    required this.desklet,
    required this.skin,
  });

  final EffectiveTheme theme;
  final Desklet desklet;
  final DeskletSkin skin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(systemStatsProvider).asData?.value;

    return DeskletFrame(
      theme: theme,
      skin: skin,
      body: DeskletBody(
        title: skin.flag('showTitle', true) ? 'battery' : null,
        command: 'acpi -V',
        rows: [
          if (s?.batteryPercent != null)
            DeskletRow(
              'level',
              value: '${s!.batteryPercent}%',
              fraction: s.batteryPercent! / 100,
            ),
          if (s?.batteryCurrentMa != null)
            DeskletRow('draw', value: '${_signed(s!)} mA', accent: true),
          if (s?.batteryTempC != null)
            DeskletRow('temp',
                value: '${s!.batteryTempC!.toStringAsFixed(1)} C'),
          if (s?.batteryCharging != null)
            DeskletRow('state',
                value: s!.batteryCharging! ? 'charging' : 'discharging'),
        ],
      ),
    );
  }
}

// ─── fastfetch ───────────────────────────────────────────────────────────────

/// Mostly static, so it costs nothing to leave on screen.
///
/// Uptime comes from the STATS snapshot, not from `deviceInfoProvider`: D1's
/// `elapsedRealtimeMillis` doubles as the sample clock and the uptime row, so
/// the separate `g_launcher/uptime` MethodChannel that was once planned is not
/// needed and should not be added.
class FastfetchDesklet extends ConsumerWidget {
  const FastfetchDesklet({
    super.key,
    required this.theme,
    required this.desklet,
    required this.skin,
  });

  final EffectiveTheme theme;
  final Desklet desklet;
  final DeskletSkin skin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final device = ref.watch(deviceInfoProvider).asData?.value;
    final apps = ref.watch(shellAppsProvider(theme));
    final s = ref.watch(systemStatsProvider).asData?.value;

    return DeskletFrame(
      theme: theme,
      skin: skin,
      body: DeskletBody(
        command: 'fastfetch',
        rows: [
          const DeskletRow('os', value: 'G Launcher'),
          // The THEME's name, not a hardcoded string: the terminal shell will
          // eventually back more than one theme (Kali is a terminal too), and
          // hardcoding here is how a data-driven layer stops being one.
          DeskletRow('theme', value: theme.spec.name, accent: true),
          if (device?.deviceModel != null)
            DeskletRow('device', value: device!.deviceModel!),
          DeskletRow('apps', value: '${apps.length} installed'),
          if (s?.memTotalGb != null)
            DeskletRow('memory',
                value: '${s!.memTotalGb!.round()} GB'),
          if (s?.uptime != null)
            DeskletRow('uptime', value: formatUptime(s!.uptime)),
        ],
      ),
    );
  }
}
