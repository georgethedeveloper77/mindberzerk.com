/// A screen of cells, with a cursor.
///
/// ─── WHY THE LINE MODEL HAD TO GO ───────────────────────────────────────────
///
/// [AnsiParser] models output as a list of lines that only ever grows, which is
/// exactly right for a shell printing results and exactly wrong for anything
/// that draws. `vim`, `htop`, `less` and `top` do not append: they position the
/// cursor and overwrite, they scroll a region while leaving the rest still, and
/// they switch to a second screen and hand the first one back untouched when
/// they exit.
///
/// None of that can be expressed as a list of finished lines, so this is a
/// fixed grid of [rows] by [cols] cells with a cursor that moves. The line
/// model is not deleted: lines that scroll off the top become scrollback, and
/// scrollback is still a list of lines because that is what history is.
///
/// ─── PURE, AND NOT AS A STYLE PREFERENCE ────────────────────────────────────
///
/// No parsing here and no Flutter. This file is where "the cursor was at the
/// last column and one more character arrived" is decided, and that class of
/// bug is invisible on a screen and obvious in a test.
library;

import 'ansi.dart';

/// One cell.
///
/// [char] empty means never written. That is distinct from a space: erasing
/// with a background colour set has to paint the background, so a blanked cell
/// keeps its style while losing its character.
class TerminalCell {
  const TerminalCell(this.char, this.style);

  static const TerminalCell blank = TerminalCell('', AnsiStyle.none);

  final String char;
  final AnsiStyle style;

  bool get isEmpty => char.isEmpty;

  @override
  bool operator ==(Object other) =>
      other is TerminalCell && other.char == char && other.style == style;

  @override
  int get hashCode => Object.hash(char, style);

  @override
  String toString() => char.isEmpty ? ' ' : char;
}

/// The screen.
class TerminalGrid {
  TerminalGrid({required int cols, required int rows})
      : _cols = cols < 1 ? 1 : cols,
        _rows = rows < 1 ? 1 : rows {
    _lines = List.generate(_rows, (_) => _blankLine());
    _scrollBottom = _rows - 1;
  }

  int _cols;
  int _rows;
  late List<List<TerminalCell>> _lines;

  int get cols => _cols;
  int get rows => _rows;

  int cursorX = 0;
  int cursorY = 0;

  /// Where a save put it. `ESC 7` and `CSI s`.
  int _savedX = 0;
  int _savedY = 0;
  AnsiStyle _savedStyle = AnsiStyle.none;

  /// The current pen.
  AnsiStyle style = AnsiStyle.none;

  bool cursorVisible = true;
  bool autoWrap = true;

  /// The scrolling region, inclusive. `CSI r` sets it, and everything that
  /// scrolls respects it: that is how `less` keeps a status line still while
  /// the text above it moves.
  int _scrollTop = 0;
  int _scrollBottom = 0;

  int get scrollTop => _scrollTop;
  int get scrollBottom => _scrollBottom;

  /// ─── THE DEFERRED WRAP, WHICH EVERY NAIVE EMULATOR GETS WRONG ────────────
  ///
  /// Writing to the last column does NOT move the cursor to the next line. It
  /// leaves the cursor on that last column with a wrap PENDING, and the line
  /// only breaks when another character actually arrives.
  ///
  /// The difference is visible: a program that fills a line exactly and then
  /// positions the cursor elsewhere must not have caused a scroll. Wrapping
  /// eagerly inserts a blank line into every full-width redraw, which is what
  /// makes a naive emulator jitter under `htop`.
  bool _wrapPending = false;

  List<TerminalCell> _blankLine() =>
      List.filled(_cols, TerminalCell.blank, growable: false);

  /// A blank cell carrying the CURRENT background, which is what erasing means
  /// when a background colour is set. Erasing with plain blanks would leave
  /// holes in a program that paints a coloured panel.
  TerminalCell get _erasure => TerminalCell(
        '',
        AnsiStyle(bg: style.bg),
      );

  List<TerminalCell> _erasedLine() =>
      List.filled(_cols, _erasure, growable: false);

  List<TerminalCell> lineAt(int row) => _lines[row.clamp(0, _rows - 1)];

  /// Every row, top to bottom.
  List<List<TerminalCell>> get lines => List.unmodifiable(_lines);

  // ── writing ────────────────────────────────────────────────────────────────

  /// Put one character at the cursor.
  ///
  /// Returns lines evicted from the top, which happens when writing at the
  /// bottom of the scroll region forces a scroll. The caller decides whether
  /// they become scrollback; the alternate screen throws them away.
  List<List<TerminalCell>> write(String char) {
    var evicted = const <List<TerminalCell>>[];

    if (_wrapPending && autoWrap) {
      _wrapPending = false;
      cursorX = 0;
      evicted = _cursorDown();
    }

    if (cursorX >= _cols) cursorX = _cols - 1;

    _lines[cursorY][cursorX] = TerminalCell(char, style);

    if (cursorX == _cols - 1) {
      // Stay put, remember the wrap. See the note above.
      _wrapPending = true;
    } else {
      cursorX++;
    }

    return evicted;
  }

  /// Line feed. Scrolls the region when already at its bottom.
  List<List<TerminalCell>> lineFeed() {
    _wrapPending = false;
    return _cursorDown();
  }

  List<List<TerminalCell>> _cursorDown() {
    if (cursorY == _scrollBottom) return scrollUp(1);
    if (cursorY < _rows - 1) cursorY++;
    return const [];
  }

  /// Reverse line feed, `ESC M`. Scrolls the region down at its top.
  void reverseLineFeed() {
    _wrapPending = false;
    if (cursorY == _scrollTop) {
      scrollDown(1);
    } else if (cursorY > 0) {
      cursorY--;
    }
  }

  void carriageReturn() {
    _wrapPending = false;
    cursorX = 0;
  }

  void backspace() {
    _wrapPending = false;
    if (cursorX > 0) cursorX--;
  }

  /// Tab to the next multiple of eight. Stops at the last column rather than
  /// wrapping, which is what a real terminal does.
  void tab({int width = 8}) {
    _wrapPending = false;
    final w = width < 1 ? 1 : width;
    final next = ((cursorX ~/ w) + 1) * w;
    cursorX = next >= _cols ? _cols - 1 : next;
  }

  // ── movement ───────────────────────────────────────────────────────────────

  void moveTo(int x, int y) {
    _wrapPending = false;
    cursorX = x.clamp(0, _cols - 1);
    cursorY = y.clamp(0, _rows - 1);
  }

  void moveBy(int dx, int dy) {
    _wrapPending = false;
    cursorX = (cursorX + dx).clamp(0, _cols - 1);
    // Movement does NOT scroll: `CSI A` at the top of the region stays there.
    // Only a line feed scrolls, which is the distinction that keeps a status
    // line still while text moves above it.
    cursorY = (cursorY + dy).clamp(0, _rows - 1);
  }

  void moveToColumn(int x) => moveTo(x, cursorY);
  void moveToRow(int y) => moveTo(cursorX, y);

  void saveCursor() {
    _savedX = cursorX;
    _savedY = cursorY;
    _savedStyle = style;
  }

  void restoreCursor() {
    cursorX = _savedX.clamp(0, _cols - 1);
    cursorY = _savedY.clamp(0, _rows - 1);
    style = _savedStyle;
    _wrapPending = false;
  }

  // ── erasing ────────────────────────────────────────────────────────────────

  /// `CSI J`. 0 to end, 1 to start, 2 or 3 all.
  void eraseInDisplay(int mode) {
    _wrapPending = false;
    switch (mode) {
      case 0:
        _eraseLineRange(cursorY, cursorX, _cols - 1);
        for (var y = cursorY + 1; y < _rows; y++) {
          _lines[y] = _erasedLine();
        }
      case 1:
        _eraseLineRange(cursorY, 0, cursorX);
        for (var y = 0; y < cursorY; y++) {
          _lines[y] = _erasedLine();
        }
      case 2:
      case 3:
        for (var y = 0; y < _rows; y++) {
          _lines[y] = _erasedLine();
        }
      default:
        break;
    }
  }

  /// `CSI K`. 0 to end of line, 1 to start, 2 whole line.
  void eraseInLine(int mode) {
    _wrapPending = false;
    switch (mode) {
      case 0:
        _eraseLineRange(cursorY, cursorX, _cols - 1);
      case 1:
        _eraseLineRange(cursorY, 0, cursorX);
      case 2:
        _lines[cursorY] = _erasedLine();
      default:
        break;
    }
  }

  /// `CSI X`. Blank n cells from the cursor WITHOUT moving anything.
  void eraseChars(int n) {
    _wrapPending = false;
    final end = (cursorX + (n < 1 ? 1 : n) - 1).clamp(0, _cols - 1);
    _eraseLineRange(cursorY, cursorX, end);
  }

  void _eraseLineRange(int row, int from, int to) {
    final line = List<TerminalCell>.from(_lines[row]);
    for (var x = from.clamp(0, _cols - 1); x <= to.clamp(0, _cols - 1); x++) {
      line[x] = _erasure;
    }
    _lines[row] = line;
  }

  // ── editing ────────────────────────────────────────────────────────────────

  /// `CSI @`. Shift the rest of the line right, blanking what arrives.
  void insertChars(int n) {
    _wrapPending = false;
    final count = (n < 1 ? 1 : n).clamp(0, _cols - cursorX);
    final line = List<TerminalCell>.from(_lines[cursorY]);
    for (var x = _cols - 1; x >= cursorX + count; x--) {
      line[x] = line[x - count];
    }
    for (var x = cursorX; x < cursorX + count; x++) {
      line[x] = _erasure;
    }
    _lines[cursorY] = line;
  }

  /// `CSI P`. Pull the rest of the line left.
  void deleteChars(int n) {
    _wrapPending = false;
    final count = (n < 1 ? 1 : n).clamp(0, _cols - cursorX);
    final line = List<TerminalCell>.from(_lines[cursorY]);
    for (var x = cursorX; x < _cols - count; x++) {
      line[x] = line[x + count];
    }
    for (var x = _cols - count; x < _cols; x++) {
      line[x] = _erasure;
    }
    _lines[cursorY] = line;
  }

  /// `CSI L`. Open blank lines at the cursor, within the region.
  void insertLines(int n) {
    _wrapPending = false;
    if (cursorY < _scrollTop || cursorY > _scrollBottom) return;
    final count = (n < 1 ? 1 : n).clamp(0, _scrollBottom - cursorY + 1);
    for (var i = 0; i < count; i++) {
      _lines.removeAt(_scrollBottom);
      _lines.insert(cursorY, _erasedLine());
    }
  }

  /// `CSI M`. Close lines at the cursor, within the region.
  void deleteLines(int n) {
    _wrapPending = false;
    if (cursorY < _scrollTop || cursorY > _scrollBottom) return;
    final count = (n < 1 ? 1 : n).clamp(0, _scrollBottom - cursorY + 1);
    for (var i = 0; i < count; i++) {
      _lines.removeAt(cursorY);
      _lines.insert(_scrollBottom, _erasedLine());
    }
  }

  // ── scrolling ──────────────────────────────────────────────────────────────

  /// Move the region up, returning what fell off the top.
  ///
  /// Only lines leaving the TOP OF THE SCREEN are history. A region that starts
  /// lower is a program managing a panel, and its discarded lines were never
  /// output in the sense scrollback means.
  List<List<TerminalCell>> scrollUp(int n) {
    final count = (n < 1 ? 1 : n).clamp(0, _scrollBottom - _scrollTop + 1);
    final evicted = <List<TerminalCell>>[];
    for (var i = 0; i < count; i++) {
      final gone = _lines.removeAt(_scrollTop);
      if (_scrollTop == 0) evicted.add(gone);
      _lines.insert(_scrollBottom, _erasedLine());
    }
    return evicted;
  }

  void scrollDown(int n) {
    final count = (n < 1 ? 1 : n).clamp(0, _scrollBottom - _scrollTop + 1);
    for (var i = 0; i < count; i++) {
      _lines.removeAt(_scrollBottom);
      _lines.insert(_scrollTop, _erasedLine());
    }
  }

  /// `CSI r`, one-based and inclusive. Resets to the whole screen when the
  /// bounds are absent or nonsensical, and homes the cursor as the spec says.
  void setScrollRegion(int top, int bottom) {
    var t = top - 1;
    var b = bottom - 1;
    if (t < 0) t = 0;
    if (b > _rows - 1 || b < 0) b = _rows - 1;
    if (t >= b) {
      t = 0;
      b = _rows - 1;
    }
    _scrollTop = t;
    _scrollBottom = b;
    moveTo(0, 0);
  }

  // ── resize ─────────────────────────────────────────────────────────────────

  /// Change the geometry, keeping what fits.
  ///
  /// Content is kept from the TOP, and the cursor is clamped. Reflowing text to
  /// a new width is what a scrollback does; a live screen belongs to the
  /// program drawing it, and that program will redraw once it is told the size
  /// changed. Reflowing here would fight it.
  void resize({required int cols, required int rows}) {
    final c = cols < 1 ? 1 : cols;
    final r = rows < 1 ? 1 : rows;
    if (c == _cols && r == _rows) return;

    final next = <List<TerminalCell>>[];
    for (var y = 0; y < r; y++) {
      final old = y < _lines.length ? _lines[y] : const <TerminalCell>[];
      next.add(List.generate(
        c,
        (x) => x < old.length ? old[x] : TerminalCell.blank,
        growable: false,
      ));
    }

    _cols = c;
    _rows = r;
    _lines = next;
    _scrollTop = 0;
    _scrollBottom = _rows - 1;
    cursorX = cursorX.clamp(0, _cols - 1);
    cursorY = cursorY.clamp(0, _rows - 1);
    _wrapPending = false;
  }

  /// Wipe everything, for the alternate screen being entered.
  void reset() {
    _lines = List.generate(_rows, (_) => _blankLine());
    cursorX = 0;
    cursorY = 0;
    _scrollTop = 0;
    _scrollBottom = _rows - 1;
    style = AnsiStyle.none;
    _wrapPending = false;
  }

  /// One row as styled spans, merging runs.
  ///
  /// Trailing blanks are dropped so a mostly empty row is one short span rather
  /// than eighty cells, which matters when every frame of `htop` rebuilds the
  /// whole screen.
  AnsiLine toAnsiLine(int row) => gridLineToAnsiLine(_lines[row]);

  /// The visible screen as text, for tests and for copy.
  String get text => [
        for (var y = 0; y < _rows; y++) toAnsiLine(y).text,
      ].join('\n');
}

/// A row of cells as styled spans.
AnsiLine gridLineToAnsiLine(List<TerminalCell> cells) {
  // Trailing blanks carry no information unless they carry a background, and
  // one that does is worth keeping. Anything past the last meaningful cell is
  // dropped.
  var end = cells.length;
  while (end > 0) {
    final c = cells[end - 1];
    if (!c.isEmpty || c.style.bg is! AnsiDefaultColor) break;
    end--;
  }
  if (end == 0) return const AnsiLine.empty();

  final spans = <AnsiSpan>[];
  final run = StringBuffer();
  AnsiStyle? runStyle;

  void flush() {
    final style = runStyle;
    if (run.isEmpty || style == null) return;
    spans.add(AnsiSpan(run.toString(), style));
    run.clear();
  }

  for (var x = 0; x < end; x++) {
    final cell = cells[x];
    // An unwritten cell renders as a space, so columns line up. The style
    // rides along because an erased cell can carry a background.
    final ch = cell.isEmpty ? ' ' : cell.char;
    if (runStyle == null || cell.style != runStyle) {
      flush();
      runStyle = cell.style;
    }
    run.write(ch);
  }
  flush();

  return AnsiLine(List.unmodifiable(spans));
}
