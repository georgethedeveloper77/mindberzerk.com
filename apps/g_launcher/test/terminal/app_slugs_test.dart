import 'package:flutter_test/flutter_test.dart';
import 'package:g_launcher/features/terminal/adapter/app_slugs.dart';

void main() {
  group('appSlug', () {
    test('lowercases and joins words with one dash', () {
      expect(appSlug('Fitness Insights'), 'fitness-insights');
      expect(appSlug('K-9 Mail'), 'k-9-mail');
    });

    test('punctuation collapses rather than doubling up', () {
      expect(appSlug('Files  (Beta)'), 'files-beta');
      expect(appSlug('G Recovery!'), 'g-recovery');
    });

    test('a label with nothing sluggable still gets a name', () {
      expect(appSlug('微信'), 'app');
      expect(appSlug('!!!'), 'app');
    });
  });

  group('assignSlugs', () {
    test('unique labels keep their plain slug', () {
      expect(
        assignSlugs(<String>['Firefox', 'Signal']),
        <String>['firefox', 'signal'],
      );
    });

    test('a collision numbers from the second, never the first', () {
      // The Transsion case: two apps really are both called Camera, so the
      // first keeps the name a user would type and the second is reachable
      // rather than shadowed.
      expect(
        assignSlugs(<String>['Camera', 'Camera', 'Camera']),
        <String>['camera', 'camera-2', 'camera-3'],
      );
    });

    test('collisions across different labels that slug the same', () {
      expect(
        assignSlugs(<String>['My App', 'my-app']),
        <String>['my-app', 'my-app-2'],
      );
    });

    test('unsluggable labels do not collapse into one unreachable name', () {
      final List<String> slugs = assignSlugs(<String>['微信', '支付宝']);
      expect(slugs.toSet().length, 2);
    });
  });

  group('packageOfComponentKey', () {
    test('takes the package half of a component key', () {
      expect(
        packageOfComponentKey('org.mozilla.firefox/org.mozilla.fenix.HomeActivity'),
        'org.mozilla.firefox',
      );
    });

    test('drops a work profile suffix', () {
      expect(
        packageOfComponentKey('com.whatsapp/com.whatsapp.Main#10'),
        'com.whatsapp',
      );
      expect(packageOfComponentKey('com.whatsapp#10'), 'com.whatsapp');
    });

    test('a key with no separator comes back whole rather than empty', () {
      expect(packageOfComponentKey('com.termux'), 'com.termux');
    });
  });
}
