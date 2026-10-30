/// A conkyrc `conky.text` body, rendered against live readings.
///
/// Pure Dart, no Flutter, so the vocabulary is unit-tested in one place and
/// the desklet only has to draw what this returns.
///
/// ─── THE SUBSET, AND WHY THESE ──────────────────────────────────────────────
///
/// Real conky variable names, so a config pasted from r/unixporn mostly just
/// works: `${nodename}`, `${uptime}`, `${mem}`, `${fs_used}`, `${downspeed}`,
/// `${time %a %d %b}`, plus the layout controls `${alignr}`, `${hr}` and
/// `${color}`. Only readings Android gives a launcher without a permission
/// are offered; there is no `${top}` because other apps' CPU use is not ours
/// to read.
///
/// ─── A LINE WITH NO READING IS DROPPED ──────────────────────────────────────
///
/// The rule every desklet follows: a missing value removes its row instead
/// of printing `--`. A known variable whose reading is null (`${cpu}` on most
/// phones) takes its whole line with it. An UNKNOWN variable is printed as
/// typed, so a typo shows up rather than silently eating a line.
library;

/// A colour slot. Conky's `${color}` resets, `${color1}` and `${color2}` are
/// the two a phone theme can honestly map: the accent and a muted ink.
enum ConkyInk { normal, accent, muted }

sealed class ConkyPiece {
  const ConkyPiece(this.ink);

  final ConkyInk ink;
}

class ConkyText extends ConkyPiece {
  const ConkyText(this.text, super.ink);

  final String text;

  @override
  bool operator ==(Object other) =>
      other is ConkyText && other.text == text && other.ink == ink;

  @override
  int get hashCode => Object.hash(text, ink);

  @override
  String toString() => 'ConkyText($text, $ink)';
}

/// A bar, 0 to 1, drawn across the rest of its side of the line.
class ConkyBar extends ConkyPiece {
  const ConkyBar(this.fraction, super.ink);

  final double fraction;

  @override
  bool operator ==(Object other) =>
      other is ConkyBar && other.fraction == fraction && other.ink == ink;

  @override
  int get hashCode => Object.hash(fraction, ink);
}

/// One rendered line: what sits on the left, what `${alignr}` pushed right,
/// or a horizontal rule.
class ConkyLine {
  const ConkyLine({
    this.left = const [],
    this.right = const [],
    this.rule = false,
  });

  final List<ConkyPiece> left;
  final List<ConkyPiece> right;
  final bool rule;

  bool get isEmpty => !rule && left.isEmpty && right.isEmpty;

  /// The line as plain text, for tests and the terminal.
  String get plain => rule
      ? '---'
      : [
          for (final p in [...left, ...right])
            if (p is ConkyText) p.text,
        ].join();
}

/// What the desklet hands in. Null means "this device will not say".
class ConkyReadings {
  const ConkyReadings({
    required this.now,
    this.text = const {},
    this.bars = const {},
  });

  final DateTime now;

  /// Text variables, by conky name.
  final Map<String, String?> text;

  /// Bar variables, by conky name, each 0 to 1.
  final Map<String, double?> bars;
}

abstract final class ConkyTemplate {
  /// The variables the editor offers and the renderer understands.
  static const textVariables = <String>[
    'nodename',
    'sysname',
    'user_names',
    'uptime',
    'uptime_short',
    'time',
    'battery_percent',
    'battery_status',
    'acpitemp',
    'cpu',
    'mem',
    'memmax',
    'memperc',
    'fs_used',
    'fs_size',
    'fs_free',
    'fs_used_perc',
    'downspeed',
    'upspeed',
    'apps',
  ];

  static const barVariables = <String>[
    'battery_bar',
    'membar',
    'fs_bar',
    'cpubar',
  ];

  static const controls = <String>['alignr', 'hr', 'color', 'color1', 'color2'];

  static const maxLength = 4000;
  static const maxLines = 40;

  /// What a new conky desklet shows, and what Reset goes back to.
  static const defaultRc =
      r'''${color1}${nodename}${color}${alignr}${time %a %d %b}
${hr}
uptime${alignr}${uptime_short}
battery${alignr}${battery_percent}%
${battery_bar}
ram${alignr}${mem} / ${memmax}
${membar}
storage${alignr}${fs_used} / ${fs_size}
${fs_bar}
net${alignr}↓ ${downspeed}  ↑ ${upspeed}
temp${alignr}${acpitemp}°C''';

  /// `${name arg}` or the bare `$name` form.
  static final _token =
      RegExp(r'\$\{([a-z_][a-z0-9_]*)(?:\s+([^}]*))?\}|\$([a-z_][a-z0-9_]*)');

  /// Whether rendering [src] needs a tick every second (a `%S` in a time).
  static bool needsSeconds(String src) =>
      RegExp(r'\$\{time\s[^}]*%[ST]').hasMatch(src);

  static List<ConkyLine> render(String src, ConkyReadings r) {
    final body = src.length > maxLength ? src.substring(0, maxLength) : src;
    final out = <ConkyLine>[];
    for (final raw in body.split('\n').take(maxLines)) {
      final line = _renderLine(raw.replaceAll('\r', ''), r);
      if (line != null) out.add(line);
    }
    return out;
  }

  /// Null when the line is dropped: a known reading was missing.
  static ConkyLine? _renderLine(String raw, ConkyReadings r) {
    if (raw.trim() == r'${hr}' || raw.trim() == r'$hr') {
      return const ConkyLine(rule: true);
    }

    final left = <ConkyPiece>[];
    final right = <ConkyPiece>[];
    var side = left;
    var ink = ConkyInk.normal;
    var at = 0;

    void literal(String t) {
      if (t.isNotEmpty) side.add(ConkyText(t, ink));
    }

    for (final m in _token.allMatches(raw)) {
      literal(raw.substring(at, m.start));
      at = m.end;
      final name = m.group(1) ?? m.group(3)!;
      final arg = m.group(2)?.trim();

      switch (name) {
        case 'alignr':
          side = right;
        case 'hr':
          // Mid-line rules have no honest phone equivalent; treat as a gap.
          literal(' ');
        case 'color' || 'color0':
          // `${color red}` names a colour we cannot promise; the accent is
          // the nearest thing a theme owns.
          ink = arg == null || arg.isEmpty ? ConkyInk.normal : ConkyInk.accent;
        case 'color1':
          ink = ConkyInk.accent;
        case 'color2':
          ink = ConkyInk.muted;
        case 'time':
          literal(strftime(arg == null || arg.isEmpty ? '%H:%M' : arg, r.now));
        default:
          if (barVariables.contains(name)) {
            final v = r.bars[name];
            if (v == null) return null;
            side.add(ConkyBar(v.clamp(0.0, 1.0), ConkyInk.accent));
          } else if (textVariables.contains(name)) {
            final v = r.text[name];
            if (v == null) return null;
            literal(v);
          } else {
            literal(m.group(0)!);
          }
      }
    }
    literal(raw.substring(at));

    final line = ConkyLine(left: left, right: right);
    // A line that was only controls (a bare `${color1}`) draws nothing, but
    // a blank line in the rc is spacing the author asked for.
    if (line.isEmpty && raw.trim().isNotEmpty) return null;
    return line;
  }

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _daysLong = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  static const _monthsLong = [
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

  /// The strftime subset conkyrcs actually use. Unknown directives are kept
  /// as typed, the same rule as unknown variables.
  static String strftime(String format, DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    final b = StringBuffer();
    for (var i = 0; i < format.length; i++) {
      final ch = format[i];
      if (ch != '%' || i == format.length - 1) {
        b.write(ch);
        continue;
      }
      final d = format[++i];
      final h12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
      b.write(switch (d) {
        'H' => two(t.hour),
        'I' => two(h12),
        'l' => '$h12',
        'M' => two(t.minute),
        'S' => two(t.second),
        'T' => '${two(t.hour)}:${two(t.minute)}:${two(t.second)}',
        'R' => '${two(t.hour)}:${two(t.minute)}',
        'p' => t.hour < 12 ? 'AM' : 'PM',
        'd' => two(t.day),
        'e' => '${t.day}',
        'm' => two(t.month),
        'y' => two(t.year % 100),
        'Y' => '${t.year}',
        'a' => _days[t.weekday - 1],
        'A' => _daysLong[t.weekday - 1],
        'b' || 'h' => _months[t.month - 1],
        'B' => _monthsLong[t.month - 1],
        '%' => '%',
        _ => '%$d',
      });
    }
    return b.toString();
  }
}
