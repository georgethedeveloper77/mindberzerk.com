// The parser is the piece with the most ways to be quietly wrong, so most of
// this is adversarial rather than illustrative: split sequences, malformed
// parameters, control characters inside escapes, and the specific behaviours a
// naive implementation gets backwards.
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:g_launcher/engine/terminal_spec.dart';
import 'package:g_launcher/engine/theme_spec.dart';
import 'package:g_launcher/features/terminal/ansi.dart';
import 'package:g_launcher/features/terminal/ansi_palette.dart';
import 'package:g_launcher/features/terminal/terminal_buffer.dart';

/// Feed a whole string and return every line, finished and unfinished.
List<AnsiLine> parse(String input) {
  final p = AnsiParser()..feed(input);
  final out = [...p.committed];
  if (!p.current.isEmpty) out.add(p.current);
  return out;
}

String plain(String input) => parse(input).map((l) => l.text).join('\n');

void main() {
  group('plain text', () {
    test('passes through', () {
      expect(plain('hello'), 'hello');
    });

    test('newline commits a line', () {
      expect(parse('a\nb').map((l) => l.text), ['a', 'b']);
    });

    test('a trailing newline leaves no phantom line', () {
      final p = AnsiParser()..feed('a\n');
      expect(p.committed.length, 1);
      expect(p.current.isEmpty, isTrue);
    });

    test('tabs expand to the next stop, not to a fixed width', () {
      expect(plain('a\tb'), 'a       b');
      expect(plain('abcdefg\th'), 'abcdefg h');
      expect(plain('abcdefgh\ti'), 'abcdefgh        i');
    });

    test('backspace removes the last character', () {
      expect(plain('abc\b\bx'), 'ax');
    });

    test('backspace reaches back into a previous span', () {
      // The style change closes a span, so the character to delete is not in
      // the run being built at all. An implementation that only trims the run
      // leaves the character on screen.
      expect(plain('ab\x1b[31m\bc'), 'ac');
      // And the whole span goes when it held a single character.
      expect(plain('a\x1b[31m\bc'), 'c');
    });

    test('stray control characters are dropped, not drawn', () {
      expect(plain('a\x00b\x7fc'), 'abc');
    });
  });

  group('carriage return', () {
    test('overwrites the line rather than committing it', () {
      // A progress bar redraws with \r. Committing would leave one line per
      // redraw and turn a download into a hundred lines of history.
      expect(parse('50%\r100%').map((l) => l.text), ['100%']);
    });

    test('CRLF still ends the line exactly once', () {
      expect(parse('a\r\nb').map((l) => l.text), ['a', 'b']);
    });
  });

  group('SGR', () {
    test('sets a foreground colour', () {
      final line = parse('\x1b[31mred').single;
      expect(line.spans.single.style.fg, const AnsiIndexedColor(1));
    });

    test('bright foreground maps to the upper eight', () {
      final line = parse('\x1b[91mred').single;
      expect(line.spans.single.style.fg, const AnsiIndexedColor(9));
    });

    test('reset clears everything', () {
      final line = parse('\x1b[1;31mA\x1b[0mB').single;
      expect(line.spans.first.style.bold, isTrue);
      expect(line.spans.last.style, AnsiStyle.none);
    });

    test('an empty parameter list is a reset', () {
      final line = parse('\x1b[31mA\x1b[mB').single;
      expect(line.spans.last.style.fg, const AnsiDefaultColor());
    });

    test('an empty parameter defaults to zero', () {
      // ESC[;31m is a reset followed by red, not a malformed sequence.
      final line = parse('\x1b[1mA\x1b[;31mB').single;
      expect(line.spans.last.style.bold, isFalse);
      expect(line.spans.last.style.fg, const AnsiIndexedColor(1));
    });

    test('256 colour', () {
      final line = parse('\x1b[38;5;208mx').single;
      expect(line.spans.single.style.fg, const AnsiIndexedColor(208));
    });

    test('24 bit colour', () {
      final line = parse('\x1b[38;2;12;34;56mx').single;
      expect(line.spans.single.style.fg, const AnsiRgbColor(12, 34, 56));
    });

    test('the colon spelling of extended colour parses the same', () {
      final line = parse('\x1b[38:2:12:34:56mx').single;
      expect(line.spans.single.style.fg, const AnsiRgbColor(12, 34, 56));
    });

    test('a truncated extended colour does not eat the text', () {
      expect(plain('\x1b[38;5mhello'), 'hello');
    });

    test('an unknown code is ignored without dropping the ones around it', () {
      final line = parse('\x1b[31;99;1mx').single;
      expect(line.spans.single.style.fg, const AnsiIndexedColor(1));
      expect(line.spans.single.style.bold, isTrue);
    });

    test('style survives a newline', () {
      // A program that sets red then prints three lines expects three red
      // lines. Resetting at the newline is the classic way to colour only one.
      final lines = parse('\x1b[31ma\nb');
      expect(lines[1].spans.single.style.fg, const AnsiIndexedColor(1));
    });

    test('inverse is kept as an attribute so 27 can undo it', () {
      final line = parse('\x1b[7mA\x1b[27mB').single;
      expect(line.spans.first.style.inverse, isTrue);
      expect(line.spans.last.style.inverse, isFalse);
    });

    test('runs with the same style merge into one span', () {
      final line = parse('\x1b[31ma\x1b[31mb').single;
      expect(line.spans.length, 1);
      expect(line.spans.single.text, 'ab');
    });
  });

  group('sequences that are consumed, not printed', () {
    test('clear screen leaves no visible characters', () {
      // The single loudest sign of a naive implementation is ESC[2J appearing
      // on screen as five characters.
      expect(plain('\x1b[2Jhello'), 'hello');
    });

    test('cursor positioning is swallowed', () {
      expect(plain('\x1b[10;20Hhello'), 'hello');
    });

    test('a private mode set is swallowed', () {
      expect(plain('\x1b[?25lhi\x1b[?25h'), 'hi');
    });

    test('an OSC title ending in BEL is swallowed', () {
      expect(plain('\x1b]0;my title\x07hello'), 'hello');
    });

    test('an OSC ending in ST is swallowed', () {
      expect(plain('\x1b]0;t\x1b\\hello'), 'hello');
    });

    test('a runaway OSC gives up rather than buffering forever', () {
      final junk = 'x' * 2000;
      expect(plain('\x1b]0;$junk'), isNot(contains('\x1b')));
    });

    test('a runaway CSI gives up rather than buffering forever', () {
      final junk = '1;' * 100;
      expect(() => parse('\x1b[${junk}m'), returnsNormally);
    });
  });

  group('chunk boundaries', () {
    test('a sequence split across two feeds still applies', () {
      // A network read lands wherever it lands. A parser that resets per chunk
      // drops the colour of whatever straddled the boundary.
      final p = AnsiParser()
        ..feed('\x1b[3')
        ..feed('1mred');
      expect(p.current.spans.single.style.fg, const AnsiIndexedColor(1));
    });

    test('a sequence split character by character still applies', () {
      final p = AnsiParser();
      for (final ch in '\x1b[1;38;5;208mx'.split('')) {
        p.feed(ch);
      }
      expect(p.current.spans.single.style.fg, const AnsiIndexedColor(208));
      expect(p.current.spans.single.style.bold, isTrue);
    });

    test('text split mid-word does not fragment into many spans', () {
      final p = AnsiParser()
        ..feed('hel')
        ..feed('lo');
      expect(p.current.spans.length, 1);
      expect(p.current.spans.single.text, 'hello');
    });
  });

  group('limits', () {
    test('a line longer than the cap wraps rather than growing without bound', () {
      final p = AnsiParser(maxLineLength: 10)..feed('x' * 25);
      expect(p.committed.length, 2);
      expect(p.committed.first.length, 10);
    });

    test('the bell is reported, not drawn', () {
      var rung = 0;
      final p = AnsiParser(onBell: () => rung++)..feed('a\x07b');
      expect(rung, 1);
      expect(p.current.text, 'ab');
    });
  });

  group('TerminalBuffer', () {
    test('keeps lines in order', () {
      final b = TerminalBuffer(maxLines: 10)
        ..addAll(parse('a\nb\nc').take(3));
      expect(b.text, 'a\nb\nc');
    });

    test('evicts the oldest past the cap and counts what it dropped', () {
      final b = TerminalBuffer(maxLines: 2)
        ..addAll([for (var i = 0; i < 5; i++) AnsiLine([AnsiSpan('$i', AnsiStyle.none)])]);
      expect(b.length, 2);
      expect(b.text, '3\n4');
      expect(b.droppedLines, 3);
    });

    test('shrinking the cap evicts immediately', () {
      // The setting exists for memory, and a cap that takes effect eventually
      // does not relieve anything now.
      final b = TerminalBuffer(maxLines: 100)
        ..addAll([for (var i = 0; i < 50; i++) AnsiLine([AnsiSpan('$i', AnsiStyle.none)])]);
      b.setMaxLines(10);
      expect(b.length, 10);
    });

    test('drain moves finished lines and leaves the unfinished one', () {
      final p = AnsiParser()..feed('one\ntwo\nthr');
      final b = TerminalBuffer(maxLines: 100)..drain(p);
      expect(b.text, 'one\ntwo');
      expect(p.current.text, 'thr');
    });

    test('draining twice does not duplicate', () {
      final p = AnsiParser()..feed('one\n');
      final b = TerminalBuffer(maxLines: 100)
        ..drain(p)
        ..drain(p);
      expect(b.length, 1);
    });

    test('clear does not reset the dropped count', () {
      // Dropped counts what was lost to the cap. A clear is the user choosing
      // to discard, and conflating them makes the truncation notice lie.
      final b = TerminalBuffer(maxLines: 1)
        ..addAll([for (var i = 0; i < 4; i++) const AnsiLine.empty()]);
      final dropped = b.droppedLines;
      b.clear();
      expect(b.droppedLines, dropped);
    });
  });

  group('palette resolution', () {
    final palette = TerminalSpec.defaultForShell(ShellKind.tui).palette;

    test('the sixteen come from the theme', () {
      expect(palette.resolveAnsi(const AnsiIndexedColor(2)), palette.ansi[2]);
    });

    test('default resolves differently for foreground and background', () {
      expect(palette.resolveAnsi(const AnsiDefaultColor()), palette.fg);
      expect(
        palette.resolveAnsi(const AnsiDefaultColor(), isBackground: true),
        palette.bg,
      );
    });

    test('the 6x6x6 cube uses xterm levels, not an even ramp', () {
      // 16 is the corner of the cube and is pure black.
      expect(palette.resolveAnsi(const AnsiIndexedColor(16)),
          const Color(0xFF000000));
      // 231 is the opposite corner and is pure white.
      expect(palette.resolveAnsi(const AnsiIndexedColor(231)),
          const Color(0xFFFFFFFF));
      // 208 is xterm's orange: level 5, level 2, level 0.
      expect(palette.resolveAnsi(const AnsiIndexedColor(208)),
          const Color(0xFFFF8700));
    });

    test('the greyscale ramp stops short of both extremes', () {
      expect(palette.resolveAnsi(const AnsiIndexedColor(232)),
          const Color(0xFF080808));
      expect(palette.resolveAnsi(const AnsiIndexedColor(255)),
          const Color(0xFFEEEEEE));
    });

    test('an out of range index stays readable', () {
      expect(palette.resolveAnsi(const AnsiIndexedColor(999)), palette.fg);
    });

    test('inverse swaps foreground and background at render time', () {
      final s = palette.resolveStyle(
        const AnsiStyle(fg: AnsiIndexedColor(1), inverse: true),
      );
      expect(s.bg, palette.ansi[1]);
      expect(s.fg, palette.bg);
    });

    test('bold is weight, never a brighter colour', () {
      // Mapping bold onto the bright half means a theme's colour 1 never
      // appears the moment any program emits bold red, which is most of them.
      final s = palette.resolveStyle(
        const AnsiStyle(fg: AnsiIndexedColor(1), bold: true),
      );
      expect(s.fg, palette.ansi[1]);
      expect(s.bold, isTrue);
    });

    test('a default background paints nothing rather than filling every cell', () {
      // The terminal runs over the theme's own surface, and an opaque fill
      // behind every character would flatten it.
      expect(palette.resolveStyle(AnsiStyle.none).bg, isNull);
    });

    test('hidden text keeps its cells and paints nothing', () {
      final s = palette.resolveStyle(const AnsiStyle(hidden: true));
      expect(s.fg.a, 0.0);
    });
  });
}
