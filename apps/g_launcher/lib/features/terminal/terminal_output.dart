/// What a command PRINTS, as opposed to what it places.
///
/// ─── ONE COMMAND, TWO RENDERINGS ────────────────────────────────────────────
///
/// On the TUI shell `free` places a live desklet into the pane, which is right
/// there: the output stays current and survives a restart, and the pane
/// renderer is the one the graphical desktops already use.
///
/// The Terminal app has no pane. It has scrollback, which is a record of what
/// was true when you asked. So the same command has to print instead, and this
/// is where that rendering lives.
///
/// `DeskletBody` anticipated exactly this: its doc says every kind declares its
/// command line even though only the terminal surface draws it, precisely so
/// one kind can serve more than one surface. This is the third surface.
///
/// ─── THE OUTPUT CARRIES ITS OWN ESCAPE SEQUENCES ────────────────────────────
///
/// These functions return strings with real ANSI in them, and the session feeds
/// them through [AnsiParser] rather than styling them directly. That looks like
/// a detour and is the point: local output and a remote SSH session then take
/// exactly the same path to the screen, so a colour bug can only exist in one
/// place, and the parser is exercised constantly by local use rather than only
/// once SSH ships.
///
/// ─── SILENCE IS A BUG, NOT AN EMPTY RESULT ──────────────────────────────────
///
/// A command that prints nothing at all is indistinguishable from a command
/// that never ran, and on a shell that is the one failure you cannot debug. So
/// an unavailable stat prints to stderr in the way the real tool would, which
/// is the same rule `DeskletBody.emptyNote` states for the pane.
///
/// This does not breach the nullable-stats rule. An absent ROW is still absent;
/// an error line is not a placeholder value. `mem --%` would be a lie,
/// `cannot read meminfo` is a fact.
library;

import '../../engine/theme_spec.dart';
import '../../platform/launcher_api.g.dart';
import '../../system/system_stats.dart';

/// SGR helpers, kept short because they appear inline all over this file.
const _reset = '\x1b[0m';
const _bold = '\x1b[1m';
const _dim = '\x1b[90m';
const _red = '\x1b[31m';
const _green = '\x1b[32m';
const _yellow = '\x1b[33m';
const _cyan = '\x1b[36m';

String _head(String s) => '$_dim$s$_reset';
String _err(String s) => '$_red$s$_reset';

/// Everything the printing commands can read.
///
/// A record of what was true at the moment the command ran, gathered by the
/// caller. Passing a snapshot rather than a `WidgetRef` keeps every function
/// below pure and testable, which matters more here than usual: this is the
/// code that decides whether a number on screen is honest.
class TerminalFacts {
  const TerminalFacts({
    this.stats,
    this.apps = const [],
    this.allApps = const [],
    this.spec,
    this.now,
    this.deviceModel,
    this.androidRelease,
  });

  final SystemStats? stats;

  /// What the drawer would show: hidden apps already removed by
  /// `shellAppsProvider`.
  final List<AppEntry> apps;

  /// Everything installed, hidden ones included. Only `ls -a` reads it.
  ///
  /// SEPARATE rather than a flag on the list, because hiding an app is a
  /// per-theme preference and `ls` must not quietly undo it. You get the hidden
  /// ones when you ask for them, which is what `-a` has always meant.
  final List<AppEntry> allApps;
  final ThemeSpec? spec;
  final DateTime? now;
  final String? deviceModel;
  final String? androidRelease;
}

/// The lines a desklet kind prints on the Terminal app.
///
/// Keyed by the SAME kind id the registry already carries, so a command cannot
/// print one thing and place another.
List<String> outputForKind(String kind, TerminalFacts f, {String args = ''}) =>
    switch (kind) {
      'free' => _free(f),
      'df' || 'storage' => _df(f),
      'uptime' => _uptime(f),
      'monitor' => _monitor(f),
      'fastfetch' => _fetch(f),
      'clock' => _clock(f),
      'network' => _network(f),
      'battery' => _battery(f),
      'ls' => _ls(f, args),
      // A kind with no printed form is a gap in this table, not a silent
      // no-op. Naming the kind is what makes it a one-line fix.
      _ => [_err('$kind: no output on this surface')],
    };

List<String> _free(TerminalFacts f) {
  final s = f.stats;
  if (s == null || !s.hasMemory) {
    return [_err('free: cannot read memory info')];
  }
  final total = s.memTotalGb!;
  final used = s.memUsedGb!;
  final avail = total - used;
  String g(double v) => '${v.toStringAsFixed(1)}Gi';

  return [
    _head('               total        used       avail'),
    'Mem:      ${g(total).padLeft(10)}${g(used).padLeft(12)}'
        '${g(avail).padLeft(12)}',
  ];
}

List<String> _df(TerminalFacts f) {
  final s = f.stats;
  if (s == null || !s.hasStorage) {
    return [_err('df: cannot stat /data')];
  }
  final total = s.storageTotalBytes!;
  final used = s.storageUsedBytes!;
  final pct = total == 0 ? 0 : (used * 100 / total).round();

  // Above ninety percent turns red, which is the one place this file colours a
  // number by its value. A full disk is the only storage fact worth
  // interrupting someone for.
  final pctText = pct > 90 ? '$_red$pct%$_reset' : '$pct%';

  return [
    _head('Filesystem      Size  Used  Use%  Mounted on'),
    '/dev/block      ${SystemStats.bytes(total).padLeft(4)}  '
        '${SystemStats.bytes(used).padLeft(4)}  $pctText  /data',
  ];
}

List<String> _uptime(TerminalFacts f) {
  final s = f.stats;
  final now = f.now;
  if (s?.uptime == null) {
    return [_err('uptime: no stats channel')];
  }
  final time = now == null ? '' : '${formatTime(now)}  ';
  return ['$time up ${formatUptime(s!.uptime)}'];
}

List<String> _monitor(TerminalFacts f) {
  final s = f.stats;
  if (s == null) return [_err('top: no stats channel')];

  final out = <String>[];
  if (s.cpuPercent != null) {
    out.add('%Cpu(s): $_bold${s.cpuPercent}$_reset us');
  }
  if (s.hasMemory) {
    out.add('MiB Mem : ${s.memLabel}');
  }
  if (s.thermalStatus != null) {
    out.add('Thermal : ${s.thermalStatus}');
  }
  // Every field absent is not an empty result, it is a device that will not
  // report. Say which.
  return out.isEmpty ? [_err('top: no readable counters')] : out;
}

List<String> _fetch(TerminalFacts f) {
  final rows = <String>[
    if (f.spec != null) '${_cyan}distro$_reset   ${f.spec!.name}',
    if (f.deviceModel != null) '${_cyan}device$_reset   ${f.deviceModel}',
    if (f.androidRelease != null)
      '${_cyan}android$_reset  ${f.androidRelease}',
    if (f.apps.isNotEmpty) '${_cyan}apps$_reset     ${f.apps.length} installed',
    if (f.stats?.uptime != null)
      '${_cyan}uptime$_reset   ${formatUptime(f.stats!.uptime)}',
  ];
  return rows.isEmpty ? [_err('fastfetch: nothing to report')] : rows;
}

List<String> _clock(TerminalFacts f) {
  final now = f.now;
  if (now == null) return [_err('date: no clock')];
  // The shape `date` actually prints, rather than a locale format. Someone who
  // types `date` in a Linux launcher knows what it looks like.
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  String two(int n) => n.toString().padLeft(2, '0');
  return [
    '${days[now.weekday - 1]} ${months[now.month - 1]} '
        '${two(now.day)} ${two(now.hour)}:${two(now.minute)}:'
        '${two(now.second)} ${now.year}',
  ];
}

List<String> _network(TerminalFacts f) {
  final s = f.stats;
  if (s == null) return [_err('ip: no stats channel')];

  final out = <String>[];
  if (s.transport != null) {
    out.add('${_cyan}transport$_reset  ${s.transport}');
  }
  if (s.hasNet) {
    out.add('${_green}down$_reset       ${SystemStats.rate(s.netDownBytesPerSec)}/s');
    out.add('${_yellow}up$_reset         ${SystemStats.rate(s.netUpBytesPerSec)}/s');
  }
  // The SSID is deliberately absent and stays absent: reading the network name
  // needs location permission on Android 10 and above, and this launcher does
  // not ask for location to print a throughput figure.
  return out.isEmpty ? [_err('ip: no network counters')] : out;
}

List<String> _battery(TerminalFacts f) {
  final s = f.stats;
  if (s == null || s.batteryPercent == null) {
    return [_err('acpi: no battery information')];
  }

  final charging = s.batteryCharging;
  final state = charging == null
      ? 'Unknown'
      : (charging ? 'Charging' : 'Discharging');

  final out = <String>['Battery 0: $state, $_bold${s.batteryPercent}%$_reset'];
  if (s.batteryTempC != null) {
    out.add('           ${s.batteryTempC!.toStringAsFixed(1)}C');
  }
  if (s.batteryCurrentMa != null) {
    // Magnitude only. The platform's sign is not portable, so direction comes
    // from the charging flag above and never from the number.
    out.add('           ${s.batteryCurrentMa} mA');
  }
  return out;
}

/// `ls`, over the only filesystem a launcher has: the app list.
///
/// ─── WHY THERE IS NO pwd AND NO cd ──────────────────────────────────────────
///
/// Scoped storage means this app sees its own sandbox and whatever the media
/// permissions expose, and nothing else. A `pwd` printing a path you cannot
/// usefully explore is the half-truth the nullable-stats rule exists to
/// prevent, so the directory commands are not missing, they are declined.
///
/// What a launcher DOES have is an inventory, and it is genuinely worth
/// listing: what is installed, what is hidden, what came with the phone, what
/// is suspended. So `ls` is the real command here and its flags are the ones
/// that answer those questions.
///
///   ls          what the drawer shows, in columns
///   ls -a       hidden apps too, marked
///   ls -l       one per line with package name and flags
///   ls -1       one per line, names only
///   ls -s       system apps only
///   ls -u       user-installed only
///
/// Flags combine. Unknown flags are REPORTED rather than ignored, because a
/// silently dropped flag is a command that lied about what it did.
List<String> _ls(TerminalFacts f, String args) {
  final flags = <String>{};
  final bad = <String>[];

  for (final token in args.split(RegExp(r'\s+'))) {
    if (token.isEmpty || !token.startsWith('-')) continue;
    for (final ch in token.substring(1).split('')) {
      if ('alsu1'.contains(ch)) {
        flags.add(ch);
      } else {
        bad.add(ch);
      }
    }
  }
  if (bad.isNotEmpty) {
    return [_err("ls: unknown option -- '${bad.first}'"), _head('try: ls -a -l -1 -s -u')];
  }

  final all = flags.contains('a');
  final source = all && f.allApps.isNotEmpty ? f.allApps : f.apps;
  if (source.isEmpty) return [_err('ls: app list not loaded')];

  final visible = {for (final a in f.apps) a.componentKey};

  var apps = [...source];
  if (flags.contains('s')) apps = apps.where((a) => a.isSystem).toList();
  if (flags.contains('u')) apps = apps.where((a) => !a.isSystem).toList();

  apps.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));

  if (apps.isEmpty) {
    return [_head('ls: nothing matches')];
  }

  if (flags.contains('l')) return _lsLong(apps, visible, all);
  if (flags.contains('1')) {
    return [for (final a in apps) _lsName(a, visible, all)];
  }
  return _lsColumns(apps, visible, all);
}

/// A name that reads like a filename.
///
/// Lowercased with spaces stripped, because "Google Play Store" does not look
/// like something in a directory. The pane's `ls` makes the same
/// transformation, so the two surfaces agree.
String _lsPlain(AppEntry a) => a.label.toLowerCase().replaceAll(' ', '-');

/// The name, coloured by what it is.
///
/// A hidden app shown under `-a` is DIMMED and prefixed with a dot, the way a
/// hidden file is. That is not decoration: the whole reason `-a` exists is that
/// its results are different from the default, and a list where they look
/// identical is a list you have to count.
String _lsName(AppEntry a, Set<String> visible, bool showingAll) {
  final name = _lsPlain(a);
  final hidden = showingAll && !visible.contains(a.componentKey);
  if (hidden) return '$_dim.$name$_reset';
  if (a.isSuspended) return '$_yellow$name$_reset';
  if (a.isSystem) return '$_cyan$name$_reset';
  return name;
}

List<String> _lsColumns(List<AppEntry> apps, Set<String> visible, bool all) {
  // Four to a line. A real `ls` fills the width; a phone listing 260 apps one
  // per line is a scroll, not a listing.
  const perLine = 4;
  const width = 20;

  final out = <String>[];
  for (var i = 0; i < apps.length; i += perLine) {
    final row = apps.skip(i).take(perLine).toList();
    final cells = <String>[];
    for (final a in row) {
      var name = _lsPlain(a);
      final hidden = all && !visible.contains(a.componentKey);
      if (hidden) name = '.$name';
      // Padded on the PLAIN text, then coloured, because an escape sequence has
      // no width and padding the coloured string leaves the columns ragged by
      // exactly the length of the escapes.
      final clipped =
          name.length > width - 2 ? '${name.substring(0, width - 3)}~' : name;
      final padded = clipped.padRight(width);
      cells.add(_lsTint(a, hidden, padded));
    }
    out.add(cells.join().trimRight());
  }
  return out;
}

String _lsTint(AppEntry a, bool hidden, String text) {
  if (hidden) return '$_dim$text$_reset';
  if (a.isSuspended) return '$_yellow$text$_reset';
  if (a.isSystem) return '$_cyan$text$_reset';
  return text;
}

/// The long form: flags, package, name.
///
/// Shaped like `ls -l`, with the mode column replaced by the four things
/// Android actually knows about an app. A column of `drwxr-xr-x` would be a
/// costume; this is the real metadata.
///
///   s  system, came with the phone
///   u  user installed
///   h  hidden from this distro's drawer
///   x  suspended, so tapping it does nothing
///   w  work profile
List<String> _lsLong(List<AppEntry> apps, Set<String> visible, bool all) {
  final out = <String>[
    _head('flags  package                              name'),
  ];

  for (final a in apps) {
    final hidden = !visible.contains(a.componentKey);
    final mode = StringBuffer()
      ..write(a.isSystem ? 's' : 'u')
      ..write(hidden ? 'h' : '-')
      ..write(a.isSuspended ? 'x' : '-')
      ..write(a.isWorkProfile ? 'w' : '-');

    final pkg = a.packageName.length > 36
        ? '${a.packageName.substring(0, 35)}~'
        : a.packageName;

    out.add(
      '$_dim$mode$_reset   ${pkg.padRight(37)}${_lsName(a, visible, all)}',
    );
  }
  return out;
}

/// The `help` output, grouped the way the registry groups itself.
///
/// Printed rather than shown in a message, unlike the TUI shell: that shell has
/// no scrollback so a wall of text has nowhere to go, and here it does. This is
/// the one place the two surfaces deliberately answer the same command
/// differently, and the reason is the surface, not the command.
List<String> helpOutput(
  Iterable<({String category, String name, String description, bool locked})>
      rows,
) {
  final out = <String>[];
  String? group;
  for (final r in rows) {
    if (r.category != group) {
      if (out.isNotEmpty) out.add('');
      out.add(_head(r.category.toUpperCase()));
      group = r.category;
    }
    final lock = r.locked ? ' $_yellow[pro]$_reset' : '';
    out.add('  $_bold${r.name.padRight(12)}$_reset${r.description}$lock');
  }
  return out;
}
