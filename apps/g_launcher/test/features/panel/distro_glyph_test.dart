import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g_launcher/features/panel/applets/distro_glyph.dart';

void main() {
  group('GlyphRequest', () {
    test('equal requests share one family entry', () {
      const a = GlyphRequest(kSettingsPackage, 60, 'mint|0');
      const b = GlyphRequest(kSettingsPackage, 60, 'mint|0');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('a pack change is a different request', () {
      const a = GlyphRequest(kSettingsPackage, 60, 'mint|0');
      const b = GlyphRequest(kSettingsPackage, 60, 'mint|1');
      expect(a == b, isFalse);
    });
  });

  test('no style yet answers null without asking native', () async {
    // No launcherHostApiProvider override: if the provider reached native, the
    // missing binary messenger would throw instead of answering null.
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final bytes = await container.read(
      bareGlyphProvider(const GlyphRequest(kSettingsPackage, 60, '')).future,
    );
    expect(bytes, isNull);
  });
}
