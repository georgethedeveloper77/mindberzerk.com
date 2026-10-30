// Guards Pocket's iOS 26 build: icon looks merge over the base icons block,
// and the three glass layout fields parse and default off.
import 'package:flutter_test/flutter_test.dart';
import 'package:g_launcher/engine/theme_spec.dart';

ThemeSpec _spec(Map<String, dynamic> extra) => ThemeSpec.fromJson({
      'id': 'x',
      'name': 'X',
      'shell': 'aqua',
      'palette': <String, dynamic>{},
      'icons': {'treatment': 'squircle', 'cornerRadius': 0.3},
      ...extra,
    });

void main() {
  group('icon looks', () {
    test('a look overrides only what it names', () {
      final s = _spec({
        'iconLooks': [
          {
            'id': 'clear',
            'name': 'Clear',
            'icons': {'brandTreatment': 'glass', 'backgroundColor': '#38FFFFFF'},
          },
        ],
      });
      final clear = s.iconsFor('clear');
      expect(clear.brandTreatment, 'glass');
      expect(clear.cornerRadius, 0.3);
      expect(clear.backgroundColor, 0x38FFFFFF);
    });

    test('an unknown or absent look is the base block', () {
      final s = _spec({});
      expect(s.iconLooks, isEmpty);
      expect(s.iconsFor('clear').cornerRadius, 0.3);
      expect(s.iconsFor(null).brandTreatment, isNull);
    });

    test('a look with no id or name is dropped', () {
      final s = _spec({
        'iconLooks': [
          {'id': '', 'name': 'Nameless'},
          {'id': 'dark', 'name': ''},
        ],
      });
      expect(s.iconLooks, isEmpty);
    });
  });

  test('glass layout fields parse and default off', () {
    final on = ThemeLayout.fromJson(const {
      'material': 'glass',
      'homeSearch': 'pill',
      'folderStyle': 'glass',
    });
    expect(on.material, 'glass');
    expect(on.homeSearch, 'pill');
    expect(on.folderStyle, 'glass');
    expect(on.dockLauncher, isTrue);
    expect(ThemeLayout.fromJson(const {'dockLauncher': false}).dockLauncher,
        isFalse);
    final off = ThemeLayout.fromJson(const {'material': 'frosted'});
    expect(off.material, isNull);
    expect(off.homeSearch, isNull);
    expect(off.folderStyle, isNull);
  });
}
