/// Readings and controls.
///
/// Every value here is nullable at the host, and a null prints NO ROW. That is
/// the same rule the waybar modules and the conky keep, and it is the reason
/// this shell can be trusted with a storage figure at all.
library;

import '../term_command.dart';
import '../term_host.dart';
import '../term_output.dart';

class DfCommand extends TermCommand {
  const DfCommand();

  @override
  String get name => 'df';
  @override
  TermGroup get group => TermGroup.system;
  @override
  String get help => 'storage, measured';

  @override
  Future<TermResult> run(TermInvocation inv) async {
    final TermStorage? s = await inv.context.host.storage();
    if (s == null) return TermResult.line('storage unreadable', TermInk.dim);
    final String percent = (s.fraction * 100).toStringAsFixed(1);
    return TermResult(<TermChunk>[
      TermLiveChunk(
        TermLiveKind.storage,
        <TermLine>[
          TermLine.pair('size', humanBytes(s.totalBytes), width: 6),
          TermLine(<TermSpan>[
            const TermSpan('used  ', TermInk.key),
            TermSpan(humanBytes(s.usedBytes)),
            TermSpan('  $percent%', TermInk.dim),
          ]),
          TermLine.pair('free', humanBytes(s.freeBytes), width: 6),
        ],
        fraction: s.fraction,
      ),
    ]);
  }
}

class FreeCommand extends TermCommand {
  const FreeCommand();

  @override
  String get name => 'free';
  @override
  TermGroup get group => TermGroup.system;
  @override
  String get help => 'memory, measured';

  @override
  Future<TermResult> run(TermInvocation inv) async {
    final TermMemory? m = await inv.context.host.memory();
    if (m == null) return TermResult.line('memory unreadable', TermInk.dim);
    return TermResult(<TermChunk>[
      TermLiveChunk(
        TermLiveKind.memory,
        <TermLine>[
          TermLine(<TermSpan>[
            TermSpan(
              '${''.padRight(6)}${'total'.padRight(8)}${'used'.padRight(8)}${'free'.padRight(8)}${m.cachedMb == null ? '' : 'cached'}',
              TermInk.dim,
            ),
          ]),
          TermLine.of(
            '${'Mem:'.padRight(6)}${'${m.totalMb}M'.padRight(8)}${'${m.usedMb}M'.padRight(8)}${'${m.freeMb}M'.padRight(8)}${m.cachedMb == null ? '' : '${m.cachedMb}M'}',
          ),
        ],
        fraction: m.fraction,
      ),
    ]);
  }
}

class TopCommand extends TermCommand {
  const TopCommand();

  @override
  String get name => 'top';
  @override
  TermGroup get group => TermGroup.system;
  @override
  String get help => 'live cpu and memory';

  @override
  Future<TermResult> run(TermInvocation inv) async {
    final int? cpu = await inv.context.host.cpuPercent();
    final TermMemory? memory = await inv.context.host.memory();
    if (cpu == null && memory == null) {
      return TermResult.line('nothing sampled', TermInk.dim);
    }
    final List<TermSpan> spans = <TermSpan>[];
    if (cpu != null) {
      spans.add(const TermSpan('cpu ', TermInk.key));
      spans.add(TermSpan('$cpu%'));
    }
    if (memory != null) {
      if (spans.isNotEmpty) spans.add(const TermSpan('   '));
      spans.add(const TermSpan('mem ', TermInk.key));
      spans.add(TermSpan('${(memory.fraction * 100).round()}%'));
    }
    return TermResult(<TermChunk>[
      TermLiveChunk(
        TermLiveKind.cpu,
        <TermLine>[TermLine(spans)],
        fraction: cpu == null ? null : cpu / 100,
      ),
    ]);
  }
}

class UptimeCommand extends TermCommand {
  const UptimeCommand();

  @override
  String get name => 'uptime';
  @override
  TermGroup get group => TermGroup.system;
  @override
  String get help => 'time since boot';

  @override
  Future<TermResult> run(TermInvocation inv) async {
    final Duration? up = inv.context.host.uptime;
    if (up == null) return TermResult.line('uptime unreadable', TermInk.dim);
    return TermResult.line('up ${formatShellUptime(up)}');
  }
}

/// NOT `formatUptime`. `system_stats.dart` already exports one, and a file
/// importing both would fail to compile on a collision nobody chose. This one
/// exists separately because the command layer must not import Flutter, and
/// that file does.
String formatShellUptime(Duration d) {
  final int days = d.inDays;
  final int hours = d.inHours % 24;
  final int minutes = d.inMinutes % 60;
  if (days > 0) return '${days}d ${hours}h';
  if (hours > 0) return '${hours}h ${minutes}m';
  return '${minutes}m';
}

class DateCommand extends TermCommand {
  const DateCommand();

  @override
  String get name => 'date';
  @override
  TermGroup get group => TermGroup.system;
  @override
  String get help => 'the date and time';

  @override
  Future<TermResult> run(TermInvocation inv) async {
    final DateTime now = DateTime.now();
    const List<String> days = <String>[
      'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
    ];
    const List<String> months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final String hh = now.hour.toString().padLeft(2, '0');
    final String mm = now.minute.toString().padLeft(2, '0');
    final String ss = now.second.toString().padLeft(2, '0');
    return TermResult.line(
      '${days[now.weekday - 1]} ${months[now.month - 1]} ${now.day} $hh:$mm:$ss ${now.year}',
    );
  }
}

class BatteryCommand extends TermCommand {
  const BatteryCommand();

  @override
  String get name => 'battery';
  @override
  TermGroup get group => TermGroup.system;
  @override
  String get help => 'level, temperature, health';

  @override
  Future<TermResult> run(TermInvocation inv) async {
    final TermBattery? b = await inv.context.host.battery();
    if (b == null) return TermResult.line('battery unreadable', TermInk.dim);
    final List<TermLine> lines = <TermLine>[
      if (b.percent != null) TermLine.pair('level', '${b.percent}%'),
      if (b.charging != null)
        TermLine.pair('status', b.charging! ? 'charging' : 'discharging'),
      if (b.celsius != null)
        TermLine.pair('temp', '${b.celsius!.toStringAsFixed(1)} C'),
      if (b.health != null) TermLine.pair('health', b.health!),
    ];
    if (lines.isEmpty) return TermResult.line('battery unreadable', TermInk.dim);
    return TermResult.lines(lines);
  }
}

class NetCommand extends TermCommand {
  const NetCommand();

  @override
  String get name => 'net';
  @override
  TermGroup get group => TermGroup.system;
  @override
  String get help => 'the interface that is up';

  @override
  Future<TermResult> run(TermInvocation inv) async {
    final TermNetwork? n = await inv.context.host.network();
    if (n == null) return TermResult.line('network unreadable', TermInk.dim);
    final List<TermLine> lines = <TermLine>[
      if (n.transport != null) TermLine.pair('transport', n.transport!),
      if (n.connected != null)
        TermLine.pair('state', n.connected! ? 'up' : 'down'),
      if (n.downBytesPerSec != null)
        TermLine.pair('down', '${humanBytes(n.downBytesPerSec!.round())}/s'),
      if (n.upBytesPerSec != null)
        TermLine.pair('up', '${humanBytes(n.upBytesPerSec!.round())}/s'),
    ];
    if (lines.isEmpty) return TermResult.line('nothing measured yet', TermInk.dim);
    return TermResult.lines(lines);
  }
}

class FetchCommand extends TermCommand {
  const FetchCommand();

  @override
  String get name => 'fetch';
  @override
  TermGroup get group => TermGroup.system;
  @override
  String get help => 'the header block again';

  @override
  Future<TermResult> run(TermInvocation inv) async {
    final TermHost host = inv.context.host;
    final TermDevice device = host.device;
    final List<TermApp> apps = await host.apps();
    final Duration? up = host.uptime;
    return TermResult.lines(<TermLine>[
      // NO VERSION. The convention across this ecosystem is that a version
      // number is never shown to a user, and a fetch header is the most
      // tempting place in the app to break it.
      TermLine.pair('os', 'G Launcher'),
      if (device.model != null) TermLine.pair('device', device.model!),
      if (device.androidRelease != null)
        TermLine.pair(
          'android',
          '${device.androidRelease}${device.sdkInt == null ? '' : ' (SDK ${device.sdkInt})'}',
        ),
      TermLine.pair('apps', '${apps.length} installed'),
      if (up != null) TermLine.pair('uptime', formatShellUptime(up)),
    ]);
  }
}

class TorchCommand extends TermCommand {
  const TorchCommand();

  @override
  String get name => 'torch';
  @override
  TermGroup get group => TermGroup.device;
  @override
  String get help => 'torch on, torch off';
  @override
  String? get usage => 'torch on|off';

  @override
  Future<TermResult> run(TermInvocation inv) async {
    final bool on = inv.target != 'off';
    final TermOutcome outcome = await inv.context.host.setTorch(on: on);
    // The REASON, whatever it was. This used to print "no flash unit on this
    // device" for a build where the torch was simply not wired, which is a
    // confident sentence about hardware the shell had not asked about.
    if (outcome.failed) {
      return TermResult.line(outcome.message ?? 'torch unavailable', TermInk.dim);
    }
    return TermResult.lines(<TermLine>[
      TermLine(<TermSpan>[
        const TermSpan('torch ', TermInk.dim),
        TermSpan(on ? 'on' : 'off', on ? TermInk.accent : TermInk.dim),
      ]),
    ]);
  }
}

class VolumeCommand extends TermCommand {
  const VolumeCommand();

  @override
  String get name => 'vol';
  @override
  TermGroup get group => TermGroup.device;
  @override
  String get help => 'vol up, vol down, vol mute';
  @override
  String? get usage => 'vol up|down|mute';

  @override
  Future<TermResult> run(TermInvocation inv) async {
    final int steps = switch (inv.target) {
      'up' => 1,
      'down' => -1,
      'mute' => -100,
      _ => 0,
    };
    final TermOutcome outcome = await inv.context.host.nudgeVolume(steps);
    return TermResult.line(
      outcome.message ?? (outcome.failed ? 'volume unavailable' : 'volume set'),
      TermInk.dim,
    );
  }
}

/// The panels Android stopped letting an app operate.
///
/// These exist as commands so the shell can SAY that, at the moment the user
/// asks. Leaving the words out would look like the shell is incomplete, and
/// pretending would be worse than both.
class PanelCommand extends TermCommand {
  const PanelCommand.wifi()
      : commandName = 'wifi',
        panel = TermSystemPanel.wifi,
        note = 'opens the wifi panel. Android stopped letting apps toggle it at 10';
  const PanelCommand.bluetooth()
      : commandName = 'bt',
        panel = TermSystemPanel.bluetooth,
        note = 'opens the bluetooth panel, same rule as wifi';
  const PanelCommand.doNotDisturb()
      : commandName = 'dnd',
        panel = TermSystemPanel.doNotDisturb,
        note = 'opens do not disturb, which needs policy access once';

  final String commandName;
  final TermSystemPanel panel;
  final String note;

  @override
  String get name => commandName;
  @override
  TermGroup get group => TermGroup.device;
  @override
  String get help => note;

  @override
  Future<TermResult> run(TermInvocation inv) async {
    final TermOutcome outcome = await inv.context.host.openSystemPanel(panel);
    if (outcome.failed) {
      return TermResult.line(outcome.message ?? 'unavailable', TermInk.dim);
    }
    return TermResult.line(note, TermInk.dim);
  }
}

class LauncherPageCommand extends TermCommand {
  const LauncherPageCommand.settings()
      : commandName = 'settings',
        page = TermLauncherPage.settings,
        note = 'launcher settings';
  const LauncherPageCommand.themes()
      : commandName = 'themes',
        page = TermLauncherPage.themes,
        note = 'the distro picker';
  const LauncherPageCommand.wallpaper()
      : commandName = 'wall',
        page = TermLauncherPage.wallpaper,
        note = 'the wallpaper picker';
  const LauncherPageCommand.icons()
      : commandName = 'icons',
        page = TermLauncherPage.icons,
        note = 'the icon pack picker';

  final String commandName;
  final TermLauncherPage page;
  final String note;

  @override
  String get name => commandName;
  @override
  TermGroup get group => TermGroup.launcher;
  @override
  String get help => note;

  @override
  Future<TermResult> run(TermInvocation inv) async {
    final TermOutcome outcome = await inv.context.host.openLauncherPage(page);
    // These four WORK today, through TerminalCommands. Shipping them as a
    // silent no-op would be a regression dressed as a feature, so the adapter
    // cannot be constructed without a navigator and this branch is what would
    // say so if one ever went missing.
    if (outcome.failed) {
      return TermResult.error(outcome.message ?? '$commandName is unavailable');
    }
    return TermResult.line('opening $note', TermInk.dim);
  }
}
