import 'package:flutter_test/flutter_test.dart';
import 'package:g_launcher/data/search/search_text.dart';

void main() {
  group('SearchText.typoDistance', () {
    test('one typo is forgiven from four characters', () {
      expect(SearchText.typoDistance('Telegram', 'telgram'), 1);
      expect(SearchText.typoDistance('Spotify Lite', 'spotfiy'), 1);
      expect(SearchText.typoDistance('Gmail', 'gmial'), 1);
      expect(SearchText.typoDistance('Maps', 'mpas'), 1);
    });

    test('two typos only from eight characters', () {
      expect(SearchText.typoDistance('Calculator', 'calcualtr'), 2);
      expect(SearchText.typoDistance('Chrome', 'chrxmx'), isNull);
    });

    test('short queries and garbage get nothing', () {
      expect(SearchText.typoDistance('Files', 'fi'), isNull);
      expect(SearchText.typoDistance('Chrome', 'xyzw'), isNull);
    });
  });
}
