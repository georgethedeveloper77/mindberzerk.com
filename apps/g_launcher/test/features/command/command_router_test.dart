import 'package:flutter_test/flutter_test.dart';
import 'package:g_launcher/data/prefs/query_learning.dart';
import 'package:g_launcher/features/command/bangs.dart';
import 'package:g_launcher/features/command/calc.dart';
import 'package:g_launcher/features/command/command_router.dart';
import 'package:g_launcher/features/command/units.dart';

void main() {
  group('Calc', () {
    test('precedence, power, percent, unary', () {
      expect(Calc.tryEval('1250*3.5'), 4375);
      expect(Calc.tryEval('2+3*4'), 14);
      expect(Calc.tryEval('(2+3)*4'), 20);
      expect(Calc.tryEval('2^3^2'), 512);
      expect(Calc.tryEval('200*15%'), 30);
      expect(Calc.tryEval('-3+5'), 2);
      expect(Calc.tryEval('6 × 7'), 42);
      expect(Calc.tryEval('3x4'), 12);
      expect(Calc.tryEval('9 ÷ 3'), 3);
    });

    test('thousands commas and decimal commas', () {
      expect(Calc.tryEval('1,250*2'), 2500);
      expect(Calc.tryEval('2,5*2'), 5);
    });

    test('rejects incomplete and non-finite input', () {
      expect(Calc.tryEval('2+'), isNull);
      expect(Calc.tryEval('(2+3'), isNull);
      expect(Calc.tryEval('1/0'), isNull);
      expect(Calc.tryEval('abc'), isNull);
    });

    test('app names never look like sums', () {
      expect(Calc.looksLikeMath('2048'), isFalse);
      expect(Calc.looksLikeMath('7-Zip'), isFalse);
      expect(Calc.looksLikeMath('x'), isFalse);
      expect(Calc.looksLikeMath('12*4'), isTrue);
    });

    test('format', () {
      expect(Calc.format(4375), '4,375');
      expect(Calc.format(-1234567), '-1,234,567');
      expect(Calc.format(0.1 + 0.2), '0.3');
      expect(Calc.format(3.1068559611866697), '3.106855961');
    });
  });

  group('Units', () {
    test('converts within a dimension', () {
      expect(Units.tryConvert('5 km in mi')!.result, closeTo(3.10686, 1e-4));
      expect(Units.tryConvert('30 c to f')!.result, closeTo(86, 1e-9));
      expect(Units.tryConvert('1 GiB MB')!.result, closeTo(1073.741824, 1e-6));
      expect(Units.tryConvert('8 b to B')!.result, 1);
      expect(Units.tryConvert('100 kmh mph')!.result, closeTo(62.137, 1e-3));
    });

    test('refuses across dimensions and unknown units', () {
      expect(Units.tryConvert('5 km in kg'), isNull);
      expect(Units.tryConvert('5 parsecs in m'), isNull);
    });

    test('needs a joining word to trigger without the prefix', () {
      expect(Units.looksLikeConversion('5 Minute Crafts'), isFalse);
      expect(Units.looksLikeConversion('5 km in mi'), isTrue);
    });
  });

  group('Bangs', () {
    test('leading and trailing forms', () {
      expect(Bangs.resolve('!yt linux rice')!.url,
          'https://www.youtube.com/results?search_query=linux+rice');
      expect(Bangs.resolve('hyprland !aw')!.bang.label, 'Arch Wiki');
      expect(Bangs.resolve('!nope x'), isNull);
      expect(Bangs.resolve('!yt'), isNull);
    });

    test('suggest while the key is typed', () {
      expect(Bangs.suggest('!y').map((b) => b.key), contains('yt'));
      expect(Bangs.suggest('!yt x'), isEmpty);
    });
  });

  group('CommandRouter', () {
    test('explicit modes replace the app search', () {
      final r = CommandRouter.route('=2+2');
      expect(r.searchApps, isFalse);
      expect((r.hits.single as CalcHit).value, 4);
      expect(CommandRouter.route(':5 km mi').searchApps, isFalse);
      expect(CommandRouter.route('!yt cats').hits.single, isA<BangSearchHit>());
      expect(CommandRouter.route('!y').hits.single, isA<BangHintHit>());
    });

    test('implicit answers sit beside apps', () {
      final r = CommandRouter.route('12*4');
      expect(r.searchApps, isTrue);
      expect((r.hits.single as CalcHit).value, 48);
      expect(CommandRouter.route('telegram').hits, isEmpty);
    });
  });

  group('QueryLearning', () {
    test('two launches teach, compacted query, reorders only', () {
      var l = const QueryLearning({});
      l = l.record('bank', 'equity').record('Bank', 'equity');
      expect(l.learnedFor('b a n k'), ['equity']);
      final out = l.boost(['bankapp', 'equity', 'other'], 'bank', (s) => s);
      expect(out, ['equity', 'bankapp', 'other']);
      // A learned key absent from the list is not invented.
      expect(l.boost(['bankapp'], 'bank', (s) => s), ['bankapp']);
    });

    test('one tap is not enough', () {
      final l = const QueryLearning({}).record('bank', 'equity');
      expect(l.learnedFor('bank'), isEmpty);
    });
  });
}
