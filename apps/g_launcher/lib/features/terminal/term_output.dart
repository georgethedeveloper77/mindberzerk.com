/// What a command returns.
///
/// THE STRUCTURAL CHANGE. Output used to be a `DeskletPane`, which made every
/// command a widget somebody hand built, which is why the vocabulary stopped at
/// eight words. A command now returns LINES, and the paint happens once in the
/// view. Pipes, grep, wc, scrollback, history and search all fall out of that
/// for free, and a new command is a class with a `run`, not a new widget.
///
/// [TermInk] is a ROLE, not a colour. The view maps a role onto
/// `EffectiveTheme.palette`, so Kali's terminal and Ubuntu's terminal are the
/// same code and different data. Nothing in this layer knows a hex value.
///
/// Pure Dart. No Flutter import, deliberately: a command file that cannot reach
/// a `Color` cannot hardcode one.
library;

enum TermInk {
  /// Body text.
  text,

  /// A label or a directory name. The `key` in `key ~ value`.
  key,

  /// Secondary detail: package names, sizes, byte counts, notes.
  dim,

  /// The thing the eye should land on. Totals, the active value.
  accent,

  /// Something the user should read before acting.
  warn,

  /// A failure.
  bad,
}

class TermSpan {
  const TermSpan(this.text, [this.ink = TermInk.text]);

  final String text;
  final TermInk ink;

  @override
  String toString() => text;
}

/// One printed line.
class TermLine {
  const TermLine(this.spans);

  factory TermLine.of(String text, [TermInk ink = TermInk.text]) =>
      TermLine(<TermSpan>[TermSpan(text, ink)]);

  static const TermLine blank = TermLine(<TermSpan>[]);

  /// `label   value`, the shape the fetch header and every stat block use.
  factory TermLine.pair(String label, String value, {int width = 8}) =>
      TermLine(<TermSpan>[
        TermSpan(label.padRight(width), TermInk.key),
        TermSpan(value),
      ]);

  final List<TermSpan> spans;

  /// The line as plain text. This is what `grep` matches and `wc` counts, so
  /// filtering can never depend on how the line happens to be painted.
  String get plain => spans.map((TermSpan s) => s.text).join();

  @override
  String toString() => plain;
}

/// A block of output. Either lines, or a block that keeps updating.
sealed class TermChunk {
  const TermChunk();
}

class TermTextChunk extends TermChunk {
  const TermTextChunk(this.lines);

  final List<TermLine> lines;
}

/// `top`, `free` and `df` keep sampling while they are on screen.
///
/// The lines are the reading AT THE MOMENT THE COMMAND RAN, so scrollback stays
/// truthful once the block stops updating. The view decides whether a live kind
/// it does not recognise simply renders its lines, which is what keeps a new
/// kind from being a breaking change.
enum TermLiveKind { memory, storage, cpu }

class TermLiveChunk extends TermChunk {
  const TermLiveChunk(this.kind, this.lines, {this.fraction});

  final TermLiveKind kind;
  final List<TermLine> lines;

  /// 0 to 1 for the bar, or null when the reading was unavailable, in which
  /// case the view draws no bar rather than an empty one.
  final double? fraction;
}

/// The result of one line the user pressed enter on.
class TermResult {
  const TermResult(this.chunks, {this.clearScrollback = false});

  const TermResult.none() : this(const <TermChunk>[]);

  factory TermResult.lines(List<TermLine> lines) =>
      TermResult(<TermChunk>[TermTextChunk(lines)]);

  factory TermResult.line(String text, [TermInk ink = TermInk.text]) =>
      TermResult.lines(<TermLine>[TermLine.of(text, ink)]);

  factory TermResult.error(String text) =>
      TermResult.lines(<TermLine>[TermLine.of(text, TermInk.bad)]);

  final List<TermChunk> chunks;

  /// `clear` empties the scrollback. It is a flag rather than a chunk because
  /// it is the one command whose output is the absence of output.
  final bool clearScrollback;

  /// Every text line across every chunk, for the pipe stages.
  List<TermLine> get textLines => <TermLine>[
        for (final TermChunk c in chunks)
          if (c is TermTextChunk) ...c.lines else if (c is TermLiveChunk) ...c.lines,
      ];

  bool get isEmpty => chunks.isEmpty;
}

/// Bytes as a shell prints them. Always measured, never rounded up to sound
/// better, and never a placeholder when the reading is missing.
String humanBytes(int bytes) {
  if (bytes < 1024) return '${bytes}B';
  const List<String> units = <String>['K', 'M', 'G', 'T'];
  var value = bytes / 1024;
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final String text =
      value >= 10 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
  return '$text${units[unit]}';
}

/// A runaway guard on ONE command's output. Not a listing limit.
///
/// ─── THE BUG THIS REPLACES: THE CAP RAN BEFORE THE PIPE ─────────────────────
///
/// `ls` and `apps` used to cut themselves to forty rows and print "247 entries,
/// showing 40, pipe to grep or head". The cut happened INSIDE the command, so
/// the pipe it recommended only ever saw those forty: on a phone with 247 apps,
/// `apps | grep zoom` answered "no match" while Zoom sat at position 112. The
/// advice and the bug were the same line.
///
/// A shell does not truncate `ls`. It prints every entry and you scroll or you
/// filter, and the scrollback is a scrolling list, so 247 lines costs a scroll
/// rather than a flood. What survives is a ceiling far above any real listing,
/// to stop a runaway from locking up the view, and it is applied ONCE at the
/// end of the whole line, after every filter has had the full input.
const int kOutputCeiling = 500;
