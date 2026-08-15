// The grid is where "the cursor was at the last column and one more character
// arrived" is decided. That class of bug is invisible on a screen and obvious
// in a test, which is the whole reason this file is longer than the widget one.
import 'package:flutter_test/flutter_test.dart';
import 'package:g_launcher/features/terminal/ansi.dart';
import 'package:g_launcher/features/terminal/terminal_emulator.dart';
import 'package:g_launcher/features/terminal/terminal_grid.dart';

TerminalEmulator emu({int cols = 10, int rows = 4, String? feed}) {
  final e = TerminalEmulator(cols: cols, rows: rows);
  if (feed != null) e.feed(feed);
  return e;
}

/// The visible screen with trailing blanks stripped per row, for readable
/// expectations.
List<String> screen(TerminalEmulator e) =>
    [for (var y = 0; y < e.grid.rows; y++) e.grid.toAnsiLine(y).text];

void main() {
  group('writing', () {
    test('lands where the cursor is', () {
      final e = emu(feed: 'abc');
      expect(screen(e).first, 'abc');
      expect(e.grid.cursorX, 3);
    });

    test('newline moves down without moving the column back', () {
      // A bare \\n is a LINE FEED. Only \\r returns to column zero, which is
      // why a program sending \\n alone produces a staircase on a real
      // terminal too.
      final e = emu(feed: 'ab\ncd');
      expect(e.grid.cursorY, 1);
      expect(e.grid.cursorX, 4);
    });

    test('carriage return plus line feed starts the next line', () {
      final e = emu(feed: 'ab\r\ncd');
      expect(screen(e)[0], 'ab');
      expect(screen(e)[1], 'cd');
    });

    test('carriage return overwrites in place', () {
      final e = emu(feed: 'hello\rbye');
      expect(screen(e).first, 'byelo');
    });

    test('backspace moves without erasing, as a terminal does', () {
      // `\\b` alone does not delete. A shell erases by sending backspace,
      // space, backspace, and an emulator that deletes on backspace shows one
      // character too few.
      final e = emu(feed: 'abc\b');
      expect(screen(e).first, 'abc');
      expect(e.grid.cursorX, 2);
      // The space is a WRITTEN cell, so the row is 'ab ' and not 'ab'. Only
      // never-written cells strip as trailing blanks, which is the distinction
      // that lets an erase with a background colour still paint.
      e.feed(' \b');
      expect(screen(e).first, 'ab ');
    });
  });

  group('the deferred wrap', () {
    test('filling the last column does not move the cursor', () {
      // THE detail a naive emulator gets wrong. Wrapping eagerly inserts a
      // blank line into every full-width redraw, which is what makes htop
      // jitter.
      final e = emu(cols: 5, feed: 'abcde');
      expect(e.grid.cursorY, 0);
      expect(screen(e).first, 'abcde');
    });

    test('the next character is what breaks the line', () {
      final e = emu(cols: 5, feed: 'abcdef');
      expect(screen(e)[0], 'abcde');
      expect(screen(e)[1], 'f');
      expect(e.grid.cursorY, 1);
    });

    test('positioning the cursor cancels a pending wrap', () {
      // Fill the line exactly, then move. Nothing should have scrolled.
      final e = emu(cols: 5, rows: 3, feed: 'abcde\x1b[2;1Hx');
      expect(screen(e)[0], 'abcde');
      expect(screen(e)[1], 'x');
    });

    test('autowrap off overwrites the last column instead', () {
      final e = emu(cols: 5, feed: '\x1b[?7labcdefgh');
      expect(screen(e)[0].length, 5);
      expect(screen(e)[1], isEmpty);
    });
  });

  group('cursor movement', () {
    test('absolute positioning is one-based', () {
      final e = emu(feed: '\x1b[2;3Hx');
      expect(e.grid.cursorY, 1);
      expect(screen(e)[1], '  x');
    });

    test('relative movement clamps at the edges rather than wrapping', () {
      final e = emu(feed: '\x1b[10A\x1b[10D');
      expect(e.grid.cursorX, 0);
      expect(e.grid.cursorY, 0);
    });

    test('movement never scrolls', () {
      // Only a line feed scrolls. This is what keeps a status line still while
      // text moves above it.
      final e = emu(rows: 3, feed: 'top\r\n\x1b[1;1H\x1b[5A');
      expect(screen(e)[0], 'top');
      expect(e.grid.cursorY, 0);
    });

    test('save and restore, both spellings', () {
      final e = emu(feed: '\x1b[3;4H\x1b7\x1b[1;1H\x1b8x');
      expect(e.grid.cursorY, 2);
      expect(screen(e)[2], '   x');

      final e2 = emu(feed: '\x1b[2;2H\x1b[s\x1b[1;1H\x1b[uy');
      expect(screen(e2)[1], ' y');
    });
  });

  group('erasing', () {
    test('erase to end of line', () {
      final e = emu(feed: 'abcdef\x1b[1;4H\x1b[K');
      expect(screen(e).first, 'abc');
    });

    test('erase to start of line keeps the tail', () {
      final e = emu(feed: 'abcdef\x1b[1;3H\x1b[1K');
      expect(screen(e).first.substring(3), 'def');
    });

    test('erase display clears everything and leaves the cursor put', () {
      final e = emu(feed: 'a\r\nb\r\nc\x1b[2J');
      expect(screen(e).every((l) => l.isEmpty), isTrue);
      expect(e.grid.cursorY, 2);
    });

    test('erase characters blanks in place without pulling the tail left', () {
      final e = emu(feed: 'abcdef\x1b[1;2H\x1b[2X');
      expect(screen(e).first, 'a  def');
    });
  });

  group('editing', () {
    test('delete characters pulls the rest of the line left', () {
      final e = emu(feed: 'abcdef\x1b[1;2H\x1b[2P');
      expect(screen(e).first, 'adef');
    });

    test('insert characters pushes the rest right', () {
      final e = emu(cols: 10, feed: 'abcdef\x1b[1;2H\x1b[2@');
      expect(screen(e).first, 'a  bcdef');
    });

    test('insert lines opens a gap inside the region', () {
      final e = emu(rows: 4, feed: 'a\r\nb\r\nc\x1b[2;1H\x1b[L');
      expect(screen(e)[0], 'a');
      expect(screen(e)[1], isEmpty);
      expect(screen(e)[2], 'b');
    });

    test('delete lines closes one', () {
      final e = emu(rows: 4, feed: 'a\r\nb\r\nc\x1b[2;1H\x1b[M');
      expect(screen(e)[0], 'a');
      expect(screen(e)[1], 'c');
    });
  });

  group('scroll regions', () {
    test('a region confines scrolling, leaving the rest still', () {
      // This is `less` keeping its status line while the text moves.
      final e = emu(rows: 4);
      e.feed('\x1b[1;3r'); // rows 1..3 scroll, row 4 is fixed
      e.feed('\x1b[4;1Hstatus');
      e.feed('\x1b[1;1Ha\r\nb\r\nc\r\nd');

      expect(screen(e)[3], 'status');
      expect(screen(e)[0], 'b');
      expect(screen(e)[2], 'd');
    });

    test('setting a region homes the cursor, as the spec says', () {
      final e = emu(rows: 4, feed: '\x1b[3;4Hx\x1b[1;2r');
      expect(e.grid.cursorX, 0);
      expect(e.grid.cursorY, 0);
    });

    test('a nonsensical region resets to the whole screen', () {
      final e = emu(rows: 4, feed: '\x1b[3;2r');
      expect(e.grid.scrollTop, 0);
      expect(e.grid.scrollBottom, 3);
    });
  });

  group('scrollback', () {
    test('lines leaving the top of the screen become history', () {
      final e = emu(rows: 2, feed: 'one\r\ntwo\r\nthree');
      expect(e.scrollback.map((l) => l.text), ['one']);
      expect(screen(e), ['two', 'three']);
    });

    test('a region that does not start at the top contributes nothing', () {
      // A program managing a panel is not producing output in the sense
      // scrollback means.
      final e = emu(rows: 4);
      e.feed('\x1b[2;4r\x1b[2;1Ha\r\nb\r\nc\r\nd');
      expect(e.scrollback, isEmpty);
    });

    test('it is capped, and says how much it dropped', () {
      final e = TerminalEmulator(cols: 10, rows: 2, maxScrollback: 3);
      for (var i = 0; i < 10; i++) {
        e.feed('line$i\r\n');
      }
      expect(e.scrollback.length, 3);
      expect(e.droppedLines, greaterThan(0));
    });
  });

  group('the alternate screen', () {
    test('entering it leaves the primary untouched', () {
      // The whole reason quitting vim gives you your shell back.
      // 20 columns, because 'shell output' is 12 characters and would
      // otherwise wrap, and this test is about the alternate screen.
      final e = emu(cols: 20, rows: 3, feed: 'shell output\x1b[?1049h');
      expect(e.isAlternateScreen, isTrue);
      expect(screen(e).every((l) => l.isEmpty), isTrue);

      e.feed('~\r\n~\r\n~');
      e.feed('\x1b[?1049l');

      expect(e.isAlternateScreen, isFalse);
      expect(screen(e)[0], 'shell output');
    });

    test('nothing drawn on it reaches scrollback', () {
      // Otherwise quitting htop leaves a thousand junk frames behind it.
      final e = emu(rows: 2, feed: '\x1b[?1049h');
      for (var i = 0; i < 20; i++) {
        e.feed('frame$i\r\n');
      }
      expect(e.scrollback, isEmpty);

      e.feed('\x1b[?1049l');
      expect(e.scrollback, isEmpty);
    });

    test('the cursor comes back where it was', () {
      final e = emu(rows: 4, feed: '\x1b[3;5H\x1b[?1049h\x1b[1;1H\x1b[?1049l');
      expect(e.grid.cursorY, 2);
      expect(e.grid.cursorX, 4);
    });
  });

  group('sequences that are consumed, not printed', () {
    test('mouse reporting', () {
      final e = emu(feed: '\x1b[?1000hhello');
      expect(screen(e).first, 'hello');
    });

    test('bracketed paste', () {
      final e = emu(feed: '\x1b[?2004hhello\x1b[?2004l');
      expect(screen(e).first, 'hello');
    });

    test('a device status request is not answered with nonsense', () {
      // Answering needs a write back to the remote, which this class has no
      // channel for. A wrong answer is worse than none.
      final e = emu(feed: '\x1b[6nhello');
      expect(screen(e).first, 'hello');
    });

    test('a window title is reported rather than drawn', () {
      String? seen;
      final e = TerminalEmulator(cols: 20, rows: 2, onTitle: (t) => seen = t);
      e.feed('\x1b]0;vim: main.dart\x07ok');
      expect(seen, 'vim: main.dart');
      expect(screen(e).first, 'ok');
    });
  });

  group('style', () {
    test('colour survives cursor movement', () {
      final e = emu(feed: '\x1b[31m\x1b[2;1Hred');
      final span = e.grid.toAnsiLine(1).spans.first;
      expect(span.style.fg, const AnsiIndexedColor(1));
    });

    test('erasing paints the current background', () {
      // Otherwise a program drawing a coloured panel gets holes in it.
      final e = emu(feed: '\x1b[41m\x1b[2K');
      final line = e.grid.lineAt(0);
      expect(line.first.style.bg, const AnsiIndexedColor(1));
    });

    test('the shared SGR is the same one the line parser uses', () {
      // Two readings of ESC[1;31m in one app would eventually disagree, and
      // only on a remote session.
      final viaEmulator = emu(feed: '\x1b[1;31mx').grid.lineAt(0).first.style;
      final viaParser = (AnsiParser()..feed('\x1b[1;31mx')).style;
      expect(viaEmulator.fg, viaParser.fg);
      expect(viaEmulator.bold, viaParser.bold);
    });
  });

  group('resize', () {
    test('keeps content from the top and clamps the cursor', () {
      final e = emu(cols: 10, rows: 4, feed: 'abc\r\ndef');
      e.resize(cols: 6, rows: 2);
      expect(screen(e)[0], 'abc');
      expect(e.grid.cursorY, lessThan(2));
      expect(e.grid.cols, 6);
    });

    test('does not reflow, because the program will redraw', () {
      final e = emu(cols: 10, rows: 2, feed: 'abcdefghij');
      e.resize(cols: 5, rows: 2);
      // Truncated, not wrapped onto a second row.
      expect(screen(e)[0], 'abcde');
      expect(screen(e)[1], isEmpty);
    });

    test('resets the scroll region to the new full screen', () {
      final e = emu(rows: 4, feed: '\x1b[1;2r');
      e.resize(cols: 10, rows: 6);
      expect(e.grid.scrollBottom, 5);
    });
  });

  group('chunk boundaries', () {
    test('a sequence split across feeds still applies', () {
      final e = emu();
      e.feed('\x1b[2;');
      e.feed('3Hx');
      expect(e.grid.cursorY, 1);
      expect(screen(e)[1], '  x');
    });

    test('character by character gives the same screen', () {
      const input = '\x1b[31mred\r\n\x1b[1;1H\x1b[Kok';
      final whole = emu(feed: input);
      final piece = emu();
      for (final ch in input.split('')) {
        piece.feed(ch);
      }
      expect(screen(piece), screen(whole));
    });
  });

  group('gridLineToAnsiLine', () {
    test('merges runs of one style', () {
      final cells = [
        const TerminalCell('a', AnsiStyle.none),
        const TerminalCell('b', AnsiStyle.none),
      ];
      expect(gridLineToAnsiLine(cells).spans.length, 1);
      expect(gridLineToAnsiLine(cells).text, 'ab');
    });

    test('drops trailing blanks so an empty row is cheap', () {
      final cells = [
        const TerminalCell('a', AnsiStyle.none),
        ...List.filled(79, TerminalCell.blank),
      ];
      expect(gridLineToAnsiLine(cells).text, 'a');
    });

    test('keeps a trailing blank that carries a background', () {
      // It is painted, so it is not nothing.
      final cells = [
        const TerminalCell('a', AnsiStyle.none),
        const TerminalCell('', AnsiStyle(bg: AnsiIndexedColor(4))),
      ];
      expect(gridLineToAnsiLine(cells).text.length, 2);
    });

    test('an unwritten cell in the middle renders as a space', () {
      final cells = [
        const TerminalCell('a', AnsiStyle.none),
        TerminalCell.blank,
        const TerminalCell('c', AnsiStyle.none),
      ];
      expect(gridLineToAnsiLine(cells).text, 'a c');
    });
  });
}
