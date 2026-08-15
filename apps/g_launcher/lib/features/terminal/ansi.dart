/// Turning bytes a program emitted into text with colour on it.
///
/// ─── WHAT THIS IS, AND WHAT IT DELIBERATELY IS NOT ──────────────────────────
///
/// A LINE-ORIENTED parser. It understands the escape sequences that decide how
/// text LOOKS: colour, bold, underline, inverse, and the control characters
/// that move within or end a line.
///
/// It does NOT understand the sequences that move a cursor around a grid:
/// absolute positioning, scroll regions, the alternate screen. Those are what
/// `vim`, `htop` and `less` need, and supporting them means a different data
/// structure entirely, a fixed cell grid with a cursor, rather than a list of
/// lines. Building the grid first would be building for a feature that does not
/// exist yet, and building it badly, because the requirements only become real
/// once there is a remote session to test against.
///
/// So unimplemented sequences are CONSUMED AND DISCARDED rather than printed.
/// That distinction is the whole reason this is a state machine and not a
/// regular expression: a terminal that prints `\x1b[2J` as five visible
/// characters looks broken in a way that is impossible to misread, and it is
/// the single most common way a naive implementation announces itself.
///
/// ─── FEEDING IS INCREMENTAL ─────────────────────────────────────────────────
///
/// [AnsiParser.feed] can be called with any chunk boundary, including one that
/// lands in the middle of an escape sequence. A network read does exactly that,
/// and a parser that resets its state per chunk drops the colour of whatever
/// straddled the boundary. The state survives between calls, which is why this
/// is an object and not a function.
///
/// No `dart:ui` import, on purpose. Colour RESOLUTION needs a palette and
/// belongs in the layer that has one; see ansi_palette.dart. Keeping this file
/// free of Flutter is what lets the whole parser be tested as plain Dart.
library;

import 'package:collection/collection.dart';

/// A colour as the escape sequence expressed it, before a palette is involved.
sealed class AnsiColor {
  const AnsiColor();
}

/// Whatever the terminal considers its default foreground or background.
class AnsiDefaultColor extends AnsiColor {
  const AnsiDefaultColor();

  @override
  bool operator ==(Object other) => other is AnsiDefaultColor;

  @override
  int get hashCode => 0;
}

/// A palette slot, 0 to 255.
///
/// 0 to 15 are the sixteen the theme authors. 16 to 231 are the 6x6x6 cube and
/// 232 to 255 the greyscale ramp, both of which are FIXED by the xterm spec and
/// therefore computed rather than authored: a theme that could redefine them
/// would be redefining arithmetic.
class AnsiIndexedColor extends AnsiColor {
  const AnsiIndexedColor(this.index);

  final int index;

  @override
  bool operator ==(Object other) =>
      other is AnsiIndexedColor && other.index == index;

  @override
  int get hashCode => index;
}

/// A direct 24-bit colour, from `38;2;r;g;b`.
class AnsiRgbColor extends AnsiColor {
  const AnsiRgbColor(this.r, this.g, this.b);

  final int r;
  final int g;
  final int b;

  @override
  bool operator ==(Object other) =>
      other is AnsiRgbColor && other.r == r && other.g == g && other.b == b;

  @override
  int get hashCode => Object.hash(r, g, b);
}

/// How a run of text is drawn.
class AnsiStyle {
  const AnsiStyle({
    this.fg = const AnsiDefaultColor(),
    this.bg = const AnsiDefaultColor(),
    this.bold = false,
    this.faint = false,
    this.italic = false,
    this.underline = false,
    this.inverse = false,
    this.strike = false,
    this.hidden = false,
  });

  static const AnsiStyle none = AnsiStyle();

  final AnsiColor fg;
  final AnsiColor bg;
  final bool bold;
  final bool faint;
  final bool italic;
  final bool underline;

  /// Swap foreground and background AT RENDER TIME, not here. Resolving it
  /// early would lose the information, and a later `27` has to be able to put
  /// it back.
  final bool inverse;

  final bool strike;

  /// `8`. The text occupies its cells and paints nothing, which is how a shell
  /// hides a password echo. Rendering it as invisible rather than dropping it
  /// keeps the column count honest.
  final bool hidden;

  AnsiStyle copyWith({
    AnsiColor? fg,
    AnsiColor? bg,
    bool? bold,
    bool? faint,
    bool? italic,
    bool? underline,
    bool? inverse,
    bool? strike,
    bool? hidden,
  }) =>
      AnsiStyle(
        fg: fg ?? this.fg,
        bg: bg ?? this.bg,
        bold: bold ?? this.bold,
        faint: faint ?? this.faint,
        italic: italic ?? this.italic,
        underline: underline ?? this.underline,
        inverse: inverse ?? this.inverse,
        strike: strike ?? this.strike,
        hidden: hidden ?? this.hidden,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnsiStyle &&
          other.fg == fg &&
          other.bg == bg &&
          other.bold == bold &&
          other.faint == faint &&
          other.italic == italic &&
          other.underline == underline &&
          other.inverse == inverse &&
          other.strike == strike &&
          other.hidden == hidden;

  @override
  int get hashCode => Object.hash(
        fg, bg, bold, faint, italic, underline, inverse, strike, hidden,
      );
}

/// A run of text sharing one style.
class AnsiSpan {
  const AnsiSpan(this.text, this.style);

  final String text;
  final AnsiStyle style;

  @override
  bool operator ==(Object other) =>
      other is AnsiSpan && other.text == text && other.style == style;

  @override
  int get hashCode => Object.hash(text, style);

  @override
  String toString() => 'AnsiSpan(${_esc(text)})';

  static String _esc(String s) => s.replaceAll('\n', r'\n');
}

/// One line of output.
class AnsiLine {
  const AnsiLine(this.spans);

  const AnsiLine.empty() : spans = const [];

  final List<AnsiSpan> spans;

  /// The line with no styling, for tests, for search and for copy.
  String get text => spans.map((s) => s.text).join();

  int get length => spans.fold(0, (n, s) => n + s.text.length);

  bool get isEmpty => spans.isEmpty;

  @override
  bool operator ==(Object other) =>
      other is AnsiLine &&
      const ListEquality<AnsiSpan>().equals(other.spans, spans);

  @override
  int get hashCode => const ListEquality<AnsiSpan>().hash(spans);

  @override
  String toString() => 'AnsiLine("$text")';
}

/// The incremental parser.
///
/// Call [feed] with whatever arrived, then read [committed] for finished lines
/// and [current] for the line still being written. [takeCommitted] drains.
class AnsiParser {
  AnsiParser({
    this.tabWidth = 8,
    this.maxLineLength = 8192,
    this.onBell,
  });

  /// Where the tab stops are. Eight since the teletype.
  final int tabWidth;

  /// A hard wrap, not a display width.
  ///
  /// A runaway process emitting megabytes with no newline would otherwise build
  /// one unbounded line, and every re-render would lay out the whole thing. The
  /// real wrap point is the widget's, which knows the font and the viewport;
  /// this only stops a single logical line from being able to exhaust memory.
  final int maxLineLength;

  /// `\a`. Whether that becomes a haptic, a sound or nothing is the theme's
  /// business (`TerminalSpec.defaults.bell`), so the parser only reports it.
  final void Function()? onBell;

  final List<AnsiLine> _committed = [];
  final List<AnsiSpan> _spans = [];
  final StringBuffer _run = StringBuffer();

  AnsiStyle _style = AnsiStyle.none;
  _State _state = _State.ground;
  final StringBuffer _seq = StringBuffer();

  /// Set by `\r`. The next printable character clears the line first.
  ///
  /// A carriage return means "go back to column zero", and what a progress bar
  /// does next is overwrite. Committing the line instead would leave one row
  /// per redraw and turn a download into a hundred lines of history.
  bool _pendingReturn = false;

  /// Lines finished so far, oldest first.
  List<AnsiLine> get committed => List.unmodifiable(_committed);

  /// The line still being written. Empty when there is none.
  AnsiLine get current => AnsiLine(_snapshotSpans());

  /// The style the next character would be drawn with.
  AnsiStyle get style => _style;

  /// Drain finished lines. The parser keeps the unfinished one.
  List<AnsiLine> takeCommitted() {
    final out = List<AnsiLine>.unmodifiable(_committed);
    _committed.clear();
    return out;
  }

  /// Forget everything, including any half-read escape sequence.
  ///
  /// Style is reset too. A `clear` that left the next line bold because the
  /// cleared output happened to end mid-attribute would be a puzzling thing to
  /// debug later.
  void reset() {
    _committed.clear();
    _spans.clear();
    _run.clear();
    _seq.clear();
    _style = AnsiStyle.none;
    _state = _State.ground;
    _pendingReturn = false;
  }

  /// Feed a chunk. Any boundary is safe, including mid-sequence.
  void feed(String chunk) {
    for (var i = 0; i < chunk.length; i++) {
      final ch = chunk[i];
      switch (_state) {
        case _State.ground:
          _ground(ch);
        case _State.escape:
          _escape(ch);
        case _State.csi:
          _csi(ch);
        case _State.osc:
          _osc(ch);
      }
    }
  }

  void _ground(String ch) {
    switch (ch) {
      case '\x1b':
        _state = _State.escape;
      case '\n':
        _commitLine();
      case '\r':
        _pendingReturn = true;
      case '\b':
        _backspace();
      case '\t':
        _write(' ' * _toNextTabStop());
      // 0x07, WRITTEN AS HEX AND NOT AS AN ESCAPE.
      //
      // Dart has no `\a`. An unrecognised escape drops the backslash and
      // leaves the bare character, so `case '\a'` matched the LETTER a: every
      // a in a program's output was swallowed and rang the bell. `free: cannot
      // read memory info` came out as `free: cnnot red memory info`.
      //
      // It compiles, it analyses clean, and no bracket or balance check can
      // see it. The only thing that catches it is knowing Dart's escape list.
      case '\x07':
        onBell?.call();
      case '\v':
      case '\f':
        // Vertical tab and form feed both move down a line in practice, and
        // treating them as a newline is what every terminal on a phone can
        // usefully do with them.
        _commitLine();
      default:
        // Other C0 controls are dropped rather than drawn. A NUL rendered as a
        // box is noise, and a SO/SI charset shift drawn literally is worse.
        if (ch.codeUnitAt(0) < 0x20 || ch == '\x7f') return;
        _write(ch);
    }
  }

  void _escape(String ch) {
    switch (ch) {
      case '[':
        _seq.clear();
        _state = _State.csi;
      case ']':
        _seq.clear();
        _state = _State.osc;
      case '\x1b':
        // Two escapes running. Stay here rather than treating the second as a
        // parameter of the first.
        return;
      default:
        // Everything else is a two or three character sequence we do not
        // implement: charset selection `ESC ( B`, `ESC =`, `ESC 7` and friends.
        // Consumed, not printed.
        //
        // The intermediate byte of `ESC ( B` is swallowed by the same rule on
        // the next character, which prints a stray `B` in the strictest
        // reading. Accepted knowingly: implementing charset designation to
        // avoid one wrong character in a sequence nothing on this platform
        // emits is not a trade worth making today.
        _state = _State.ground;
    }
  }

  void _csi(String ch) {
    final code = ch.codeUnitAt(0);

    // Parameter and intermediate bytes accumulate.
    if (code >= 0x20 && code <= 0x3f) {
      _seq.write(ch);
      // A sequence long past any real parameter list is malformed. Bail rather
      // than buffering forever on a binary stream that happened to contain an
      // escape byte.
      if (_seq.length > 64) _state = _State.ground;
      return;
    }

    // A final byte, 0x40 to 0x7e, ends it.
    if (code >= 0x40 && code <= 0x7e) {
      if (ch == 'm') _applySgr(_seq.toString());
      // Every other final byte is a cursor or screen operation this parser does
      // not implement. Consumed silently: see the library doc.
      _seq.clear();
      _state = _State.ground;
      return;
    }

    // A control character inside a sequence. Real terminals execute it and stay
    // in the sequence; the pragmatic answer here is to abandon the sequence,
    // since the alternative is holding state on almost certainly corrupt input.
    _seq.clear();
    _state = _State.ground;
    _ground(ch);
  }

  void _osc(String ch) {
    // `ESC ] 0 ; title BEL`, or terminated by ST (`ESC \`). Window titles,
    // clipboard writes, hyperlinks. All consumed: a phone terminal has no
    // window to title, and an OSC 52 clipboard write from a remote host is
    // something to implement deliberately or not at all.
    if (ch == '\x07') {
      _seq.clear();
      _state = _State.ground;
      return;
    }
    if (ch == '\x1b') {
      // ST is TWO characters, ESC then backslash. Dropping straight to ground
      // here leaves the backslash to be printed, which is how an OSC title ends
      // up putting a stray `\` on screen.
      _seq.clear();
      _state = _State.escape;
      return;
    }
    _seq.write(ch);
    if (_seq.length > 1024) {
      _seq.clear();
      _state = _State.ground;
    }
  }

  /// Select Graphic Rendition, the only sequence family that changes how text
  /// LOOKS rather than where it goes, which is why it is the only one here.
  ///
  /// Delegates to [applySgr] so the grid emulator shares exactly this
  /// implementation. Two readings of `ESC[1;31m` in one app would eventually
  /// disagree, and the disagreement would only show up on a remote session.
  void _applySgr(String params) {
    _flushRun();
    _style = applySgr(_style, params);
  }

  void _write(String ch) {
    if (_pendingReturn) {
      _pendingReturn = false;
      _spans.clear();
      _run.clear();
    }
    if (_lineLength() >= maxLineLength) {
      _commitLine();
    }
    _run.write(ch);
  }

  void _backspace() {
    if (_run.isNotEmpty) {
      final s = _run.toString();
      _run
        ..clear()
        ..write(s.substring(0, s.length - 1));
      return;
    }
    // The run is empty, so the last character is at the end of the last span.
    // A style change closes a span, so this is the path taken by anything of
    // the form `text ESC[..m BACKSPACE`.
    if (_spans.isNotEmpty) {
      final last = _spans.removeLast();
      if (last.text.length > 1) {
        _spans.add(
          AnsiSpan(last.text.substring(0, last.text.length - 1), last.style),
        );
      }
    }
  }

  int _toNextTabStop() {
    final col = _lineLength();
    final w = tabWidth <= 0 ? 1 : tabWidth;
    return w - (col % w);
  }

  int _lineLength() =>
      _spans.fold(0, (n, s) => n + s.text.length) + _run.length;

  void _flushRun() {
    if (_run.isEmpty) return;
    final text = _run.toString();
    _run.clear();
    // Merge into the previous span when the style is unchanged, so a line does
    // not become one span per feed boundary.
    if (_spans.isNotEmpty && _spans.last.style == _style) {
      final last = _spans.removeLast();
      _spans.add(AnsiSpan(last.text + text, _style));
      return;
    }
    _spans.add(AnsiSpan(text, _style));
  }

  List<AnsiSpan> _snapshotSpans() {
    if (_run.isEmpty) return List.unmodifiable(_spans);
    final out = List<AnsiSpan>.from(_spans);
    if (out.isNotEmpty && out.last.style == _style) {
      final last = out.removeLast();
      out.add(AnsiSpan(last.text + _run.toString(), _style));
    } else {
      out.add(AnsiSpan(_run.toString(), _style));
    }
    return List.unmodifiable(out);
  }

  void _commitLine() {
    _flushRun();
    _committed.add(AnsiLine(List.unmodifiable(_spans)));
    _spans.clear();
    _pendingReturn = false;
    // Style deliberately SURVIVES a newline. A program that sets red and then
    // prints three lines expects three red lines, and resetting here is a
    // classic way to get only the first one coloured.
  }
}

enum _State { ground, escape, csi, osc }

/// Apply an SGR parameter string to a style.
///
/// Shared by [AnsiParser] and the grid emulator. Pure, so the whole colour
/// vocabulary can be tested without either.
///
/// An unparseable or unimplemented parameter is SKIPPED rather than abandoning
/// the rest: dropping a colour because something later in the same sequence was
/// malformed is the wrong failure.
AnsiStyle applySgr(AnsiStyle current, String params) {
  // `ESC[m` is `ESC[0m`.
  if (params.isEmpty) return AnsiStyle.none;

  // A private marker is not an SGR at all.
  if (params.startsWith('?') ||
      params.startsWith('>') ||
      params.startsWith('<') ||
      params.startsWith('=')) {
    return current;
  }

  // Colons appear inside a single 38:2:... parameter in the newer spelling.
  // Flattening them handles both, since the code sequence that follows is
  // identical.
  final parts = params.replaceAll(':', ';').split(';');
  final codes = <int>[
    // An empty parameter defaults to zero: `ESC[;31m` is a reset then red.
    for (final p in parts) p.isEmpty ? 0 : (int.tryParse(p) ?? -1),
  ];

  var style = current;

  for (var i = 0; i < codes.length; i++) {
    final c = codes[i];
    switch (c) {
      case -1:
        continue;
      case 0:
        style = AnsiStyle.none;
      case 1:
        style = style.copyWith(bold: true);
      case 2:
        style = style.copyWith(faint: true);
      case 3:
        style = style.copyWith(italic: true);
      case 4:
        style = style.copyWith(underline: true);
      case 7:
        style = style.copyWith(inverse: true);
      case 8:
        style = style.copyWith(hidden: true);
      case 9:
        style = style.copyWith(strike: true);
      case 21:
      case 22:
        style = style.copyWith(bold: false, faint: false);
      case 23:
        style = style.copyWith(italic: false);
      case 24:
        style = style.copyWith(underline: false);
      case 27:
        style = style.copyWith(inverse: false);
      case 28:
        style = style.copyWith(hidden: false);
      case 29:
        style = style.copyWith(strike: false);
      case 39:
        style = style.copyWith(fg: const AnsiDefaultColor());
      case 49:
        style = style.copyWith(bg: const AnsiDefaultColor());
      default:
        if (c >= 30 && c <= 37) {
          style = style.copyWith(fg: AnsiIndexedColor(c - 30));
        } else if (c >= 40 && c <= 47) {
          style = style.copyWith(bg: AnsiIndexedColor(c - 40));
        } else if (c >= 90 && c <= 97) {
          style = style.copyWith(fg: AnsiIndexedColor(c - 90 + 8));
        } else if (c >= 100 && c <= 107) {
          style = style.copyWith(bg: AnsiIndexedColor(c - 100 + 8));
        } else if (c == 38 || c == 48) {
          final result = _extendedColour(style, codes, i, foreground: c == 38);
          if (result == null) return style; // Malformed; the rest is unreliable.
          style = result.style;
          i += result.consumed;
        }
    }
  }

  return style;
}

/// `38;5;n` and `38;2;r;g;b`.
({AnsiStyle style, int consumed})? _extendedColour(
  AnsiStyle style,
  List<int> codes,
  int i, {
  required bool foreground,
}) {
  if (i + 1 >= codes.length) return null;
  final mode = codes[i + 1];

  if (mode == 5) {
    if (i + 2 >= codes.length) return null;
    final n = codes[i + 2];
    if (n < 0 || n > 255) return null;
    final col = AnsiIndexedColor(n);
    return (
      style: foreground ? style.copyWith(fg: col) : style.copyWith(bg: col),
      consumed: 2,
    );
  }

  if (mode == 2) {
    if (i + 4 >= codes.length) return null;
    final r = codes[i + 2], g = codes[i + 3], b = codes[i + 4];
    if (r < 0 || r > 255 || g < 0 || g > 255 || b < 0 || b > 255) return null;
    final col = AnsiRgbColor(r, g, b);
    return (
      style: foreground ? style.copyWith(fg: col) : style.copyWith(bg: col),
      consumed: 4,
    );
  }

  return null;
}
