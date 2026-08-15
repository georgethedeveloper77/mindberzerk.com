import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g_launcher/engine/terminal_spec.dart';
import 'package:g_launcher/engine/theme_spec.dart';
import 'package:g_launcher/features/terminal/ansi.dart';
import 'package:g_launcher/features/terminal/prompt.dart';
import 'package:g_launcher/features/terminal/terminal_buffer.dart';
import 'package:g_launcher/features/terminal/terminal_key_row.dart';
import 'package:g_launcher/features/terminal/terminal_view.dart';

TerminalPalette get _palette =>
    TerminalSpec.defaultForShell(ShellKind.tui).palette;

TerminalBuffer _bufferOf(String raw, {int maxLines = 100}) {
  final p = AnsiParser()..feed(raw);
  return TerminalBuffer(maxLines: maxLines)..drain(p);
}

Widget _host(Widget child, {bool disableAnimations = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Scaffold(body: child),
      ),
    );

void main() {
  group('renderPrompt', () {
    test('substitutes the tokens', () {
      expect(
        renderPrompt('{user}@{host}:{cwd}\$ ', user: 'g', host: 'pixel'),
        'g@pixel:~\$ ',
      );
    });

    test('an unknown token renders literally rather than vanishing', () {
      // A brace left on screen is a mistake anyone can see and fix. A silently
      // missing segment is one nobody can trace.
      expect(renderPrompt('{user}{colour}\$ ', user: 'g'), 'g{colour}\$ ');
    });

    test('an unterminated brace keeps the rest of the template', () {
      expect(renderPrompt('{user}{cwd', user: 'g'), 'g{cwd');
    });

    test('an absent host takes its separator with it', () {
      // There is no way to get a hostname on Android, so this is the common
      // case. A prompt ending in a bare @ looks broken rather than minimal.
      expect(renderPrompt('{user}@{host}:{cwd}\$ ', user: 'g'), 'g:~\$ ');
      expect(renderPrompt('[{user}@{host} {cwd}]\$ ', user: 'g'), '[g ~]\$ ');
    });

    test('a host that is present keeps the separator', () {
      expect(renderPrompt('{user}@{host}:{cwd}\$ ', user: 'g', host: 'x'),
          'g@x:~\$ ');
    });

    test('exit code is available for a prompt that wants it', () {
      expect(renderPrompt('{exit}> ', exitCode: 130), '130> ');
    });

    test('a template with no tokens is returned unchanged', () {
      expect(renderPrompt('~ \u276f '), '~ \u276f ');
    });

    test('the tui default prompt survives a round trip', () {
      final spec = TerminalSpec.defaultForShell(ShellKind.tui);
      expect(renderPrompt(spec.prompt), '~ \u276f ');
    });
  });

  group('ctrlChord', () {
    test('letters map onto 0x01 to 0x1a', () {
      expect(ctrlChord('c'), '\x03');
      expect(ctrlChord('d'), '\x04');
      expect(ctrlChord('a'), '\x01');
      expect(ctrlChord('z'), '\x1a');
    });

    test('case does not matter', () {
      expect(ctrlChord('C'), ctrlChord('c'));
    });

    test('the punctuation chords that exist', () {
      expect(ctrlChord('['), '\x1b');
      expect(ctrlChord('@'), '\x00');
    });

    test('a meaningless pairing returns null rather than inventing a byte', () {
      // A terminal that turns ctrl-9 into something is a terminal that will one
      // day send the wrong thing to a production host.
      expect(ctrlChord('9'), isNull);
      expect(ctrlChord(''), isNull);
    });
  });

  group('bytesForSpecial', () {
    test('arrows use the CSI forms a shell expects by default', () {
      expect(bytesForSpecial(TerminalSpecialKey.up), '\x1b[A');
      expect(bytesForSpecial(TerminalSpecialKey.down), '\x1b[B');
      expect(bytesForSpecial(TerminalSpecialKey.right), '\x1b[C');
      expect(bytesForSpecial(TerminalSpecialKey.left), '\x1b[D');
    });

    test('escape and tab are the plain bytes', () {
      expect(bytesForSpecial(TerminalSpecialKey.escape), '\x1b');
      expect(bytesForSpecial(TerminalSpecialKey.tab), '\t');
    });

    test('every special key has an encoding', () {
      for (final k in TerminalSpecialKey.values) {
        expect(bytesForSpecial(k), isNotEmpty, reason: k.name);
      }
    });
  });

  group('TerminalView', () {
    testWidgets('renders committed lines', (tester) async {
      await tester.pumpWidget(_host(TerminalView(
        buffer: _bufferOf('one\ntwo\nthree\n'),
        palette: _palette,
      )));

      expect(find.text('one', findRichText: true), findsOneWidget);
      expect(find.text('three', findRichText: true), findsOneWidget);
    });

    testWidgets('a blank line still occupies a row', (tester) async {
      // Rendering an empty span collapses to zero height, which turns
      // deliberate spacing in a program's output into a solid block.
      await tester.pumpWidget(_host(TerminalView(
        buffer: _bufferOf('a\n\nb\n'),
        palette: _palette,
      )));

      final blank = tester.widget<Text>(find.text(' '));
      expect(blank.style?.fontSize, isNotNull);
    });

    testWidgets('the current line renders alongside the committed ones',
        (tester) async {
      final p = AnsiParser()..feed('done\nhalf');
      final buffer = TerminalBuffer(maxLines: 100)..drain(p);

      await tester.pumpWidget(_host(TerminalView(
        buffer: buffer,
        current: p.current,
        palette: _palette,
        showCursor: false,
      )));

      expect(find.text('done', findRichText: true), findsOneWidget);
      expect(find.text('half', findRichText: true), findsOneWidget);
    });

    testWidgets('a truncation notice appears once history has been dropped',
        (tester) async {
      // A terminal that silently forgets is one nobody trusts with a long
      // build log.
      final buffer = _bufferOf(
        '${List.generate(20, (i) => 'line $i').join('\n')}\n',
        maxLines: 5,
      );

      await tester.pumpWidget(
        _host(TerminalView(buffer: buffer, palette: _palette)),
      );

      expect(buffer.droppedLines, 15);
      expect(find.text('[ 15 earlier lines dropped ]'), findsOneWidget);
    });

    testWidgets('no notice when nothing was dropped', (tester) async {
      await tester.pumpWidget(_host(TerminalView(
        buffer: _bufferOf('a\nb\n'),
        palette: _palette,
      )));

      expect(find.textContaining('dropped'), findsNothing);
    });

    testWidgets('the singular is used for one dropped line', (tester) async {
      final buffer = _bufferOf('a\nb\nc\n', maxLines: 2);
      await tester.pumpWidget(
        _host(TerminalView(buffer: buffer, palette: _palette)),
      );

      expect(find.text('[ 1 earlier line dropped ]'), findsOneWidget);
    });

    testWidgets('paints the palette background, not a chrome colour',
        (tester) async {
      await tester.pumpWidget(_host(TerminalView(
        buffer: _bufferOf('x\n'),
        palette: _palette,
      )));

      final box = tester.widget<ColoredBox>(
        find
            .descendant(
              of: find.byType(TerminalView),
              matching: find.byType(ColoredBox),
            )
            .first,
      );
      expect(box.color, _palette.bg);
    });

    testWidgets('an ANSI colour reaches the rendered span', (tester) async {
      await tester.pumpWidget(_host(TerminalView(
        buffer: _bufferOf('\x1b[31mred\n'),
        palette: _palette,
      )));

      final text = tester.widget<Text>(
        find
            .descendant(
              of: find.byType(TerminalView),
              matching: find.byType(Text),
            )
            .first,
      );
      final span = text.textSpan! as TextSpan;
      final first = span.children!.first as TextSpan;
      expect(first.style?.color, _palette.ansi[1]);
    });

    testWidgets('bold renders as weight and keeps the palette colour',
        (tester) async {
      // Mapping bold onto the bright half means a theme's colour 1 never
      // appears the moment any program emits bold red.
      await tester.pumpWidget(_host(TerminalView(
        buffer: _bufferOf('\x1b[1;31mred\n'),
        palette: _palette,
      )));

      final text = tester.widget<Text>(
        find
            .descendant(
              of: find.byType(TerminalView),
              matching: find.byType(Text),
            )
            .first,
      );
      final first = (text.textSpan! as TextSpan).children!.first as TextSpan;
      expect(first.style?.color, _palette.ansi[1]);
      expect(first.style?.fontWeight, FontWeight.w700);
    });

    testWidgets('the cursor holds steady when animations are disabled',
        (tester) async {
      // Someone who turned animations off usually did it because motion is a
      // problem for them. A steady block is still a cursor.
      await tester.pumpWidget(_host(
        TerminalView(
          buffer: _bufferOf(''),
          current: const AnsiLine.empty(),
          palette: _palette,
        ),
        disableAnimations: true,
      ));

      expect(
        find.descendant(
          of: find.byType(TerminalView),
          matching: find.byType(Opacity),
        ),
        findsNothing,
      );
    });

    testWidgets('the cursor blinks when animations are on', (tester) async {
      await tester.pumpWidget(_host(TerminalView(
        buffer: _bufferOf(''),
        current: const AnsiLine.empty(),
        palette: _palette,
      )));

      expect(
        find.descendant(
          of: find.byType(TerminalView),
          matching: find.byType(Opacity),
        ),
        findsOneWidget,
      );
      // Tear the cursor down so the repeating ticker is stopped before the
      // test ends rather than left running into the next one.
      await tester.pumpWidget(_host(const SizedBox()));
    });
  });

  group('TerminalKeyRow', () {
    testWidgets('reports a text key', (tester) async {
      TerminalKeyEvent? got;
      await tester.pumpWidget(_host(TerminalKeyRow(
        palette: _palette,
        onKey: (e) => got = e,
      )));

      await tester.tap(find.text('|'));
      expect(got, isA<TerminalKeyText>());
      expect((got! as TerminalKeyText).text, '|');
    });

    testWidgets('reports a special key', (tester) async {
      TerminalKeyEvent? got;
      await tester.pumpWidget(_host(TerminalKeyRow(
        palette: _palette,
        onKey: (e) => got = e,
      )));

      await tester.tap(find.text('tab'));
      expect((got! as TerminalKeySpecial).key, TerminalSpecialKey.tab);
    });

    testWidgets('reports ctrl as a toggle and decides nothing itself',
        (tester) async {
      // The sticky modifier belongs to the session, which is what has to clear
      // it after the next key.
      TerminalKeyEvent? got;
      await tester.pumpWidget(_host(TerminalKeyRow(
        palette: _palette,
        onKey: (e) => got = e,
      )));

      await tester.tap(find.text('ctrl'));
      expect(got, isA<TerminalKeyCtrl>());
    });

    testWidgets('the armed modifier is filled so its state is readable',
        (tester) async {
      await tester.pumpWidget(_host(TerminalKeyRow(
        palette: _palette,
        ctrlActive: true,
        onKey: (_) {},
      )));

      final label = tester.widget<Text>(find.text('ctrl'));
      expect(label.style?.color, _palette.bg);
      expect(label.style?.fontWeight, FontWeight.w700);
    });

    testWidgets('arrows are present and reachable', (tester) async {
      await tester.pumpWidget(_host(TerminalKeyRow(
        palette: _palette,
        onKey: (_) {},
      )));

      expect(find.byIcon(Icons.keyboard_arrow_up), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_left), findsOneWidget);
    });
  });
}
