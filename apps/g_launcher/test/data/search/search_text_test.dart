import 'package:flutter_test/flutter_test.dart';
import 'package:g_launcher/data/search/search_text.dart';
import 'package:g_launcher/features/palette/fuzzy.dart';

void main() {
  group('SearchText.contains', () {
    test('spacing and case variants are one term', () {
      for (final q in ['g vpn', 'gvpn', 'GVPN', 'G VPN', 'g-vpn', 'G_VPN']) {
        expect(SearchText.contains('G VPN', q), isTrue, reason: q);
        expect(SearchText.contains('GVPN', q), isTrue, reason: q);
      }
    });

    test('diacritics fold', () {
      expect(SearchText.contains('Cámara', 'camara'), isTrue);
      expect(SearchText.contains('Configurações', 'configuracoes'), isTrue);
    });

    test('separator-only query matches nothing, empty matches all', () {
      expect(SearchText.contains('Files', '  '), isFalse);
      expect(SearchText.contains('Files', ''), isTrue);
    });
  });

  group('SearchText.rank', () {
    test('prefix, word start, anywhere', () {
      expect(SearchText.rank('G VPN', 'gv'), 0);
      expect(SearchText.rank('G VPN', 'vpn'), 1);
      expect(SearchText.rank('WhatsApp', 'app'), 1);
      expect(SearchText.rank('Firefox', 'fox'), 2);
      expect(SearchText.rank('Firefox', 'zz'), -1);
    });
  });

  group('SearchText.sameName', () {
    test('whole name only', () {
      expect(SearchText.sameName('G VPN', 'gvpn'), isTrue);
      expect(SearchText.sameName('G VPN', 'g vp'), isFalse);
      expect(SearchText.sameName('#', '#'), isTrue);
      expect(SearchText.sameName('#', ''), isFalse);
    });
  });

  group('Fuzzy with folded query', () {
    test('spaced query still finds the unspaced label', () {
      expect(Fuzzy.match('GVPN', 'g vpn').matched, isTrue);
      expect(Fuzzy.match('G VPN', 'gvpn').matched, isTrue);
    });

    test('highlight indices still point into the original label', () {
      final m = Fuzzy.match('G VPN', 'gvpn');
      expect(m.indices, [0, 2, 3, 4]);
    });
  });
}
