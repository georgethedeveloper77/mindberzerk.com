/// Bytes in, screen out.
///
/// The state machine from [AnsiParser], with every sequence it discarded now
/// implemented against [TerminalGrid]. That parser stays exactly as it is and
/// keeps its job: local command output is a list of lines and always will be.
/// This is what a remote session needs, because a remote program draws.
///
/// ─── WHAT IS IMPLEMENTED, AND WHAT IS NOT ───────────────────────────────────
///
/// Implemented: cursor movement and positioning, erase in line and display,
/// insert and delete of lines and characters, scroll regions, the alternate
/// screen, save and restore cursor, autowrap and cursor visibility, index and
/// reverse index, and SGR through the existing style model.
///
/// NOT implemented, and named rather than silently absent: double-width lines,
/// character sets other than the default, mouse reporting, bracketed paste,
/// and wide (CJK) glyphs occupying two cells. The last is the one that will bite
/// first; a CJK character currently takes one cell and the line drifts. Fixing
/// it means a width table, and it is worth doing when someone actually reads
/// Chinese output rather than before.
///
/// Anything unimplemented is CONSUMED, never printed. A terminal that prints
/// `\x1b[?1000h` as ten characters is the loudest way an emulator announces
/// itself.
library;

import 'ansi.dart';
import 'terminal_grid.dart';

/// Drives a grid from a byte stream.
class TerminalEmulator {
  TerminalEmulator({
    required int cols,
    required int rows,
    this.maxScrollback = 5000,
    this.onBell,
    this.onTitle,
  })  : _primary = TerminalGrid(cols: cols, rows: rows),
        _alternate = TerminalGrid(cols: cols, rows: rows);

  final int maxScrollback;
  final void Function()? onBell;

  /// The window title a program set. A phone has no title bar, so this exists
  /// for the session tab to show `vim: file.dart` rather than a hostname.
  final void Function(String title)? onTitle;

  final TerminalGrid _primary;
  final TerminalGrid _alternate;
  bool _onAlternate = false;

  TerminalGrid get grid => _onAlternate ? _alternate : _primary;

  bool get isAlternateScreen => _onAlternate;

  /// Lines that have scrolled off the top of the PRIMARY screen.
  ///
  /// The alternate screen contributes nothing: a full-screen program's
  /// discarded rows are not history, and putting them in scrollback is how
  /// quitting `htop` leaves a thousand junk frames behind it.
  final List<AnsiLine> _scrollback = [];

  List<AnsiLine> get scrollback => List.unmodifiable(_scrollback);

  int _dropped = 0;
  int get droppedLines => _dropped;

  _State _state = _State.ground;
  final StringBuffer _seq = StringBuffer();
  final StringBuffer _osc = StringBuffer();

  void resize({required int cols, required int rows}) {
    _primary.resize(cols: cols, rows: rows);
    _alternate.resize(cols: cols, rows: rows);
  }

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
          _oscByte(ch);
      }
    }
  }

  void _ground(String ch) {
    switch (ch) {
      case '\x1b':
        _state = _State.escape;
      case '\n':
      case '\v':
      case '\f':
        _keep(grid.lineFeed());
      case '\r':
        grid.carriageReturn();
      case '\b':
        grid.backspace();
      case '\t':
        grid.tab();
      case '\x07':
        onBell?.call();
      default:
        if (ch.codeUnitAt(0) < 0x20 || ch == '\x7f') return;
        _keep(grid.write(ch));
    }
  }

  void _escape(String ch) {
    switch (ch) {
      case '[':
        _seq.clear();
        _state = _State.csi;
      case ']':
        _osc.clear();
        _state = _State.osc;
      case 'M':
        // Reverse index. `less` scrolling backwards is this.
        grid.reverseLineFeed();
        _state = _State.ground;
      case 'D':
        _keep(grid.lineFeed());
        _state = _State.ground;
      case 'E':
        grid.carriageReturn();
        _keep(grid.lineFeed());
        _state = _State.ground;
      case '7':
        grid.saveCursor();
        _state = _State.ground;
      case '8':
        grid.restoreCursor();
        _state = _State.ground;
      case 'c':
        // Full reset. Rare, and cheap to honour.
        _primary.reset();
        _alternate.reset();
        _onAlternate = false;
        _state = _State.ground;
      case '\x1b':
        return;
      default:
        // Charset designation and friends. Consumed.
        _state = _State.ground;
    }
  }

  void _csi(String ch) {
    final code = ch.codeUnitAt(0);

    if (code >= 0x20 && code <= 0x3f) {
      _seq.write(ch);
      if (_seq.length > 64) _state = _State.ground;
      return;
    }

    if (code >= 0x40 && code <= 0x7e) {
      _dispatchCsi(ch, _seq.toString());
      _seq.clear();
      _state = _State.ground;
      return;
    }

    _seq.clear();
    _state = _State.ground;
    _ground(ch);
  }

  void _dispatchCsi(String finalByte, String params) {
    final private = params.startsWith('?');
    final body = private ? params.substring(1) : params;
    final args = _args(body);
    int arg(int i, int fallback) =>
        i < args.length && args[i] > 0 ? args[i] : fallback;

    if (private) {
      _privateMode(finalByte, args);
      return;
    }

    switch (finalByte) {
      case 'A':
        grid.moveBy(0, -arg(0, 1));
      case 'B':
        grid.moveBy(0, arg(0, 1));
      case 'C':
        grid.moveBy(arg(0, 1), 0);
      case 'D':
        grid.moveBy(-arg(0, 1), 0);
      case 'E':
        grid.moveTo(0, grid.cursorY + arg(0, 1));
      case 'F':
        grid.moveTo(0, grid.cursorY - arg(0, 1));
      case 'G':
      case '`':
        grid.moveToColumn(arg(0, 1) - 1);
      case 'd':
        grid.moveToRow(arg(0, 1) - 1);
      case 'H':
      case 'f':
        grid.moveTo(arg(1, 1) - 1, arg(0, 1) - 1);
      case 'J':
        grid.eraseInDisplay(args.isEmpty ? 0 : args[0]);
      case 'K':
        grid.eraseInLine(args.isEmpty ? 0 : args[0]);
      case 'L':
        grid.insertLines(arg(0, 1));
      case 'M':
        grid.deleteLines(arg(0, 1));
      case 'P':
        grid.deleteChars(arg(0, 1));
      case '@':
        grid.insertChars(arg(0, 1));
      case 'X':
        grid.eraseChars(arg(0, 1));
      case 'S':
        _keep(grid.scrollUp(arg(0, 1)));
      case 'T':
        grid.scrollDown(arg(0, 1));
      case 'r':
        grid.setScrollRegion(arg(0, 1), arg(1, grid.rows));
      case 's':
        grid.saveCursor();
      case 'u':
        grid.restoreCursor();
      case 'm':
        grid.style = applySgr(grid.style, body);
      // Device status and attribute reports would need a WRITE BACK to the
      // remote, which this class has no channel for. Consumed rather than
      // answered: a wrong answer is worse than none, and the programs that ask
      // fall back to their defaults.
      case 'n':
      case 'c':
        break;
      default:
        break;
    }
  }

  void _privateMode(String finalByte, List<int> args) {
    final set = finalByte == 'h';
    if (finalByte != 'h' && finalByte != 'l') return;

    for (final mode in args) {
      switch (mode) {
        case 1:
          // Application cursor keys. The key row sends CSI forms either way;
          // tracking this properly is what SS3 support would need.
          break;
        case 7:
          grid.autoWrap = set;
        case 25:
          grid.cursorVisible = set;
        case 47:
        case 1047:
        case 1049:
          _switchScreen(set, saveCursor: mode == 1049);
        default:
          // Mouse reporting, bracketed paste, focus events. Consumed, and the
          // program degrades to keyboard input, which is all a phone sends.
          break;
      }
    }
  }

  /// Enter or leave the alternate screen.
  ///
  /// ─── WHY THE PRIMARY IS UNTOUCHED ────────────────────────────────────────
  ///
  /// This is the whole reason quitting `vim` gives you your shell back exactly
  /// as it was. The alternate grid is a second screen; the primary keeps its
  /// content and its cursor, and nothing the program drew ever reaches
  /// scrollback.
  void _switchScreen(bool toAlternate, {required bool saveCursor}) {
    if (toAlternate == _onAlternate) return;

    if (toAlternate) {
      if (saveCursor) _primary.saveCursor();
      _alternate.reset();
      _onAlternate = true;
    } else {
      _onAlternate = false;
      if (saveCursor) _primary.restoreCursor();
    }
  }

  void _oscByte(String ch) {
    if (ch == '\x07') {
      _finishOsc();
      _state = _State.ground;
      return;
    }
    if (ch == '\x1b') {
      _finishOsc();
      // ST is ESC backslash. Going to escape consumes the backslash there.
      _state = _State.escape;
      return;
    }
    _osc.write(ch);
    if (_osc.length > 1024) {
      _osc.clear();
      _state = _State.ground;
    }
  }

  void _finishOsc() {
    final s = _osc.toString();
    _osc.clear();
    // `0;title` and `2;title` both set it. Everything else, including OSC 52
    // clipboard writes, is consumed: a remote host silently writing to the
    // phone's clipboard is something to implement deliberately or not at all.
    final semi = s.indexOf(';');
    if (semi < 0) return;
    final code = s.substring(0, semi);
    if (code == '0' || code == '2') {
      onTitle?.call(s.substring(semi + 1));
    }
  }

  static List<int> _args(String body) {
    if (body.isEmpty) return const [];
    return [
      for (final p in body.split(';')) p.isEmpty ? 0 : (int.tryParse(p) ?? 0),
    ];
  }

  void _keep(List<List<TerminalCell>> evicted) {
    if (evicted.isEmpty || _onAlternate) return;
    for (final line in evicted) {
      _scrollback.add(gridLineToAnsiLine(line));
    }
    if (_scrollback.length > maxScrollback) {
      final excess = _scrollback.length - maxScrollback;
      _scrollback.removeRange(0, excess);
      _dropped += excess;
    }
  }

  /// Drop history and clear the screen. What `clear` means here.
  void reset() {
    _scrollback.clear();
    _primary.reset();
    _alternate.reset();
    _onAlternate = false;
    _state = _State.ground;
    _seq.clear();
    _osc.clear();
  }
}

enum _State { ground, escape, csi, osc }
