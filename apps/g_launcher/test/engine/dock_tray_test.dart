// Guards Deepin's two layout capabilities: the dock's own tray and quick
// settings from the right. Both default off, so no other distro moves.
import 'package:flutter_test/flutter_test.dart';
import 'package:g_launcher/engine/theme_spec.dart';

void main() {
  test('dockTray and quickSettings parse', () {
    final l = ThemeLayout.fromJson(
      const {'dockTray': true, 'quickSettings': 'side'},
    );
    expect(l.dockTray, isTrue);
    expect(l.quickSettings, 'side');
  });

  test('absent or unknown is off', () {
    final l = ThemeLayout.fromJson(const {'quickSettings': 'top'});
    expect(l.dockTray, isFalse);
    expect(l.quickSettings, isNull);
  });

  test('barStyle and windowTitles parse, and default off', () {
    final l = ThemeLayout.fromJson(
      const {'barStyle': 'edge', 'windowTitles': true},
    );
    expect(l.barStyle, 'edge');
    expect(l.windowTitles, isTrue);
    final none = ThemeLayout.fromJson(const {'barStyle': 'round'});
    expect(none.barStyle, isNull);
    expect(none.windowTitles, isFalse);
  });
}
