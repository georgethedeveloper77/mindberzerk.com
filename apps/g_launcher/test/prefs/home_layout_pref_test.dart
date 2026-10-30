// Guards the `homeLayout` prefs arm the tiling toggle writes: it must survive
// a JSON round trip and clear back to the theme's own answer.
import 'package:flutter_test/flutter_test.dart';
import 'package:g_launcher/data/prefs/launcher_prefs.dart';

void main() {
  test('homeLayout round-trips through JSON', () {
    const p = LauncherPrefs(homeLayout: 'grid');
    expect(LauncherPrefs.fromJson(p.toJson()).homeLayout, 'grid');
  });

  test('clearing returns it to the theme', () {
    const p = LauncherPrefs(homeLayout: 'tiled');
    expect(p.clearing(homeLayout: true).homeLayout, isNull);
  });
}
