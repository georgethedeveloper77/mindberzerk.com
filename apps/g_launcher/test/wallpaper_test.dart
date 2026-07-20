import 'package:flutter_test/flutter_test.dart';
import 'package:g_launcher/engine/theme_spec.dart';
import 'package:g_launcher/features/settings/wallpaper_screen.dart';

void main() {
  group('ThemeSpec wallpapers', () {
    test('reads a wallpapers list', () {
      final s = ThemeSpec.fromJson({
        'id': 'x',
        'name': 'X',
        'shell': 'gnome',
        'palette': <String, dynamic>{},
        'wallpapers': ['assets/a.webp', 'assets/b.webp'],
      });
      expect(s.wallpapers, ['assets/a.webp', 'assets/b.webp']);
    });

    test('still reads the OLD single wallpaper.asset', () {
      // A theme already on someone's phone must not break because we changed
      // the manifest shape.
      final s = ThemeSpec.fromJson({
        'id': 'x',
        'name': 'X',
        'shell': 'gnome',
        'palette': <String, dynamic>{},
        'wallpaper': {'asset': 'assets/old.webp'},
      });
      expect(s.wallpapers, ['assets/old.webp']);
    });

    test('no wallpapers at all is empty, not null', () {
      final s = ThemeSpec.fromJson({
        'id': 'x',
        'name': 'X',
        'shell': 'gnome',
        'palette': <String, dynamic>{},
      });
      expect(s.wallpapers, isEmpty);
    });
  });

  group('source schemes', () {
    test('a theme can mix bundled and CDN wallpapers', () {
      // The whole point: two bundled so it looks right offline and on first
      // run, the rest served — no Play release to add a wallpaper.
      final s = ThemeSpec.fromJson({
        'id': 'x',
        'name': 'X',
        'shell': 'gnome',
        'palette': <String, dynamic>{},
        'wallpapers': [
          'assets/themes/x/wallpapers/a.webp',
          'https://cdn.example.com/x/b.webp',
        ],
      });

      expect(s.wallpapers.length, 2);
      expect(s.wallpapers.first.startsWith('assets/'), isTrue);
      expect(s.wallpapers.last.startsWith('https://'), isTrue);
    });
  });

  group('rotation options', () {
    test('nothing shorter than WorkManager\'s 15-minute floor is offered', () {
      // Offering "every 5 minutes" and delivering 15 is lying about a setting
      // the user can watch not happening.
      for (final minutes in rotationOptions.values) {
        if (minutes == null) continue;
        expect(minutes, greaterThanOrEqualTo(15));
      }
    });

    test('Off is available', () {
      expect(rotationOptions['Off'], isNull);
    });
  });
}
