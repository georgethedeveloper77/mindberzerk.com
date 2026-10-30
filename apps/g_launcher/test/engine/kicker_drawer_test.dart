// Guards Manjaro's Application Menu. `kicker` must survive both allow-lists:
// the parse in `ThemeLayout.fromJson` and the resolver's set. A value in one
// and not the other resolves to the default drawer forever, silently.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:g_launcher/engine/theme_spec.dart';

void main() {
  test('kicker parses', () {
    final l = ThemeLayout.fromJson(const {'appDrawer': 'kicker'});
    expect(l.appDrawer, 'kicker');
  });

  test('the resolver allow-list carries kicker', () {
    // Read as text, because the set is a const inside a method. Cheap, and it
    // fails loudly the day someone adds a drawer to one list only.
    const path = 'lib/engine/layout_resolver.dart';
    final src = File(path).readAsStringSync();
    expect(src.contains("'kicker'"), isTrue);
  });
}
