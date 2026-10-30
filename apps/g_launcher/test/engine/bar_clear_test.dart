// Guards elementary's see-through wingpanel. `barStyle` carries both the
// tiling bar's `edge` and the aqua bar's `clear`; anything else is the shell's
// own default.
import 'package:flutter_test/flutter_test.dart';
import 'package:g_launcher/engine/theme_spec.dart';

void main() {
  test('clear parses beside edge', () {
    expect(ThemeLayout.fromJson(const {'barStyle': 'clear'}).barStyle, 'clear');
    expect(ThemeLayout.fromJson(const {'barStyle': 'edge'}).barStyle, 'edge');
  });

  test('unknown is the default', () {
    expect(ThemeLayout.fromJson(const {'barStyle': 'glass'}).barStyle, isNull);
  });
}
