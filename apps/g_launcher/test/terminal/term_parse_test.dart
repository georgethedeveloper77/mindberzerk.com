import 'package:flutter_test/flutter_test.dart';
import 'package:g_launcher/features/terminal/term_parse.dart';

void main() {
  const TermParser parser = TermParser();

  group('tokenize', () {
    test('splits on whitespace', () {
      expect(TermParser.tokenize('ls -l Download'),
          <String>['ls', '-l', 'Download']);
    });

    test('quotes hold a space together and are stripped', () {
      expect(TermParser.tokenize('echo "hello there"'),
          <String>['echo', 'hello there']);
      expect(TermParser.tokenize("alias ll='ls -l'"),
          <String>['alias', 'll=ls -l']);
    });

    test('an empty quoted argument survives as an empty word', () {
      expect(TermParser.tokenize('echo ""'), <String>['echo', '']);
    });
  });

  group('flags', () {
    test('short flags explode to letters', () {
      final TermStage stage = parser.parse('ls -la').chunks.first.first;
      expect(stage.flags, <String>{'l', 'a'});
      expect(stage.positionals, isEmpty);
    });

    test('long flags stay whole', () {
      final TermStage stage = parser.parse('du --human').chunks.first.first;
      expect(stage.flags, <String>{'human'});
    });

    test('a negative number is an argument, not five flags', () {
      final TermStage stage = parser.parse('head -5 notes.txt').chunks.first.first;
      expect(stage.flags, isEmpty);
      expect(stage.positionals, <String>['-5', 'notes.txt']);
    });
  });

  group('pipes and chains', () {
    test('a pipe makes two stages in one chunk', () {
      final TermParsed parsed = parser.parse('apps | grep sig');
      expect(parsed.chunks.length, 1);
      expect(parsed.chunks.first.length, 2);
      expect(parsed.chunks.first.last.name, 'grep');
      expect(parsed.chunks.first.last.target, 'sig');
    });

    test('and and makes two chunks', () {
      final TermParsed parsed = parser.parse('cd .. && ls');
      expect(parsed.chunks.length, 2);
      expect(parsed.chunks.first.first.name, 'cd');
      expect(parsed.chunks.last.first.name, 'ls');
    });

    test('both together nest correctly', () {
      final TermParsed parsed = parser.parse('cd ~ && ls -l | grep apk');
      expect(parsed.chunks.length, 2);
      expect(parsed.chunks.last.length, 2);
      expect(parsed.chunks.last.first.flags, contains('l'));
    });

    test('a separator inside quotes is not a separator', () {
      final TermParsed parsed = parser.parse('echo "a && b"');
      expect(parsed.chunks.length, 1);
      expect(parsed.chunks.first.first.positionals, <String>['a && b']);
    });

    test('empty stages are dropped rather than run', () {
      expect(parser.parse('   ').isEmpty, isTrue);
      expect(parser.parse('ls && ').chunks.length, 1);
    });
  });

  group('aliases', () {
    test('the head word expands and keeps the typed arguments', () {
      final TermStage stage = parser
          .parse('ll Download', aliases: <String, String>{'ll': 'ls -l'})
          .chunks
          .first
          .first;
      expect(stage.name, 'ls');
      expect(stage.flags, contains('l'));
      expect(stage.positionals, <String>['Download']);
    });

    test('an alias naming itself expands once and does not loop', () {
      final TermStage stage = parser
          .parse('ls', aliases: <String, String>{'ls': 'ls -a'})
          .chunks
          .first
          .first;
      expect(stage.name, 'ls');
      expect(stage.flags, <String>{'a'});
    });

    test('only the head word expands, never an argument', () {
      final TermStage stage = parser
          .parse('cat ll', aliases: <String, String>{'ll': 'ls -l'})
          .chunks
          .first
          .first;
      expect(stage.positionals, <String>['ll']);
    });
  });
}
