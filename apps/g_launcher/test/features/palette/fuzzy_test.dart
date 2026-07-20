import 'package:flutter_test/flutter_test.dart';
import 'package:g_launcher/features/palette/fuzzy.dart';

/// A realistic app list. Deliberately includes the traps: two apps starting
/// "Cal", an OEM app with a long name, a camelCase one, and something that
/// contains the query letters scattered.
const _apps = [
  'Calculator',
  'Calendar',
  'Camera',
  'Chrome',
  'Clock',
  'Files',
  'Firefox',
  'Fitness Insights',
  'GMail',
  'Google Maps',
  'Google Play Store',
  'Instagram',
  'Phone',
  'Photos',
  'Settings',
  'Terminal',
  'VLC Stream',
  'WhatsApp',
  'XOS Launcher Assistant',
];

List<String> top(String query, {int n = 3}) => Fuzzy.rank(
      _apps,
      query,
      label: (s) => s,
    ).take(n).map((r) => r.item).toList();

void main() {
  group('the one that matters', () {
    test('"fi" surfaces Files and Firefox above everything else', () {
      // Both are prefix matches and they tie on score; Files is shorter so it
      // leads. That's fine — "fi" → Files is a perfectly good answer. What must
      // NOT happen is a longer or looser match displacing either of them.
      expect(top('fi', n: 2), containsAll(['Firefox', 'Files']));
    });

    test('a longer prefix match ranks below a shorter one', () {
      final ranked = Fuzzy.rank(_apps, 'fi', label: (s) => s);
      final files = ranked.indexWhere((r) => r.item == 'Files');
      final fitness = ranked.indexWhere((r) => r.item == 'Fitness Insights');
      expect(files, lessThan(fitness));
    });

    test('"fire" is unambiguous', () {
      expect(top('fire').first, 'Firefox');
    });
  });

  group('subsequence, not substring', () {
    test('"gpl" finds Google Play Store', () {
      expect(top('gpl').first, 'Google Play Store');
    });

    test('"wa" finds WhatsApp', () {
      expect(top('wa').first, 'WhatsApp');
    });

    test('a query that is not a subsequence does not match', () {
      expect(Fuzzy.match('Firefox', 'fxq').matched, isFalse);
    });

    test('order matters — "xof" is not "fox"', () {
      expect(Fuzzy.match('Firefox', 'fox').matched, isTrue);
      expect(Fuzzy.match('Firefox', 'xof').matched, isFalse);
    });
  });

  group('word starts — people type initials', () {
    test('"gm" finds GMail on the camel hump, Google Maps right behind', () {
      expect(top('gm', n: 2), ['GMail', 'Google Maps']);
    });

    test('"vs" finds VLC Stream across the space', () {
      expect(top('vs').first, 'VLC Stream');
    });

    test('"xla" finds the OEM app across word starts', () {
      expect(top('xla').first, 'XOS Launcher Assistant');
    });
  });

  group('ties and lengths', () {
    test('"cal" gives Calculator and Calendar, shortest first', () {
      final t = top('cal', n: 2);
      expect(t, ['Calendar', 'Calculator']);
    });

    test('"c" does not explode', () {
      expect(Fuzzy.rank(_apps, 'c', label: (s) => s), isNotEmpty);
    });
  });

  group('indices — the amber highlight', () {
    test('reports the winning alignment, not the first one found', () {
      // Firefox = F i r e f o x
      //           0 1 2 3 4 5 6
      // The DP picks F(0) o(5) x(6): the F is a word start and worth more than
      // the tighter-but-anonymous f(4) o(5) x(6) run. Whichever way the weights
      // fall, the point is that it EVALUATED both — a greedy scan would have
      // taken the first `f` and never looked at the second.
      final m = Fuzzy.match('Firefox', 'fox');
      expect(m.matched, isTrue);
      expect(m.indices, orderedEquals([0, 5, 6]));
    });

    test('"gps" highlights the capitals, not the second g', () {
      // Google Play Store — the regression that killed the greedy-backward
      // version. It dragged the `g` off the capital G and onto "Goo(g)le".
      final m = Fuzzy.match('Google Play Store', 'gps');
      expect(m.indices, orderedEquals([0, 7, 12]));
    });

    test('indices are ascending and within bounds', () {
      const label = 'Google Play Store';
      final m = Fuzzy.match(label, 'gps');
      expect(m.matched, isTrue);
      for (var i = 1; i < m.indices.length; i++) {
        expect(m.indices[i], greaterThan(m.indices[i - 1]));
      }
      expect(m.indices.last, lessThan(label.length));
    });

    test('case-insensitive matching, case-preserving indices', () {
      // WhatsApp -> W(0) ... A(5), the camel hump. Not the 'a' at index 2.
      final m = Fuzzy.match('WhatsApp', 'WA');
      expect(m.matched, isTrue);
      expect(m.indices, orderedEquals([0, 5]));
    });
  });

  group('edges', () {
    test('empty query matches everything with score 0', () {
      final m = Fuzzy.match('Firefox', '');
      expect(m.matched, isTrue);
      expect(m.score, 0);
      expect(m.indices, isEmpty);
      expect(Fuzzy.rank(_apps, '', label: (s) => s).length, _apps.length);
    });

    test('a query longer than the label cannot match', () {
      expect(Fuzzy.match('Clock', 'clockwork').matched, isFalse);
    });

    test('the whole label as the query matches', () {
      expect(Fuzzy.match('Clock', 'clock').matched, isTrue);
    });
  });
}
