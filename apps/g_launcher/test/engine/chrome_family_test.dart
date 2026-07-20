// Guards the step-2 contract: the chrome-family default map and parse rules.
//
// NOTE: assumes the pubspec package name is `g_launcher`. If it differs, fix
// this one import line — nothing else here depends on the name.
import 'package:flutter_test/flutter_test.dart';
import 'package:g_launcher/engine/theme_spec.dart';

void main() {
  group('ChromeFamily.defaultForShell — the bundled-theme map', () {
    test('gnome -> adwaita (Ubuntu, Fedora)', () {
      expect(ChromeFamily.defaultForShell(ShellKind.gnome), ChromeFamily.adwaita);
    });
    test('plasma -> breeze (KDE)', () {
      expect(ChromeFamily.defaultForShell(ShellKind.plasma), ChromeFamily.breeze);
    });
    test('tiling -> generic (Arch)', () {
      expect(ChromeFamily.defaultForShell(ShellKind.tiling), ChromeFamily.generic);
    });
    test('tui -> generic (terminal)', () {
      expect(ChromeFamily.defaultForShell(ShellKind.tui), ChromeFamily.generic);
    });
  });

  group('ChromeFamily.parse', () {
    test('round-trips every known value', () {
      expect(ChromeFamily.parse('adwaita'), ChromeFamily.adwaita);
      expect(ChromeFamily.parse('breeze'), ChromeFamily.breeze);
      expect(ChromeFamily.parse('aqua'), ChromeFamily.aqua);
      expect(ChromeFamily.parse('generic'), ChromeFamily.generic);
    });

    test('unknown / absent yields null so the caller falls back to the shell default', () {
      expect(ChromeFamily.parse(null), isNull);
      expect(ChromeFamily.parse(''), isNull);
      expect(ChromeFamily.parse('gnome'), isNull); // shell name is not a family
      expect(ChromeFamily.parse('Adwaita'), isNull); // case-sensitive by design
    });
  });
}
