// Guards Fedora's two layout capabilities: the workspace pill and GNOME's
// overview. Both default off, so Ubuntu and Zorin keep "Activities" and the
// app grid.
import 'package:flutter_test/flutter_test.dart';
import 'package:g_launcher/engine/theme_spec.dart';

void main() {
  test('activitiesStyle and overviewStyle parse', () {
    final l = ThemeLayout.fromJson(
      const {'activitiesStyle': 'pill', 'overviewStyle': 'gnome'},
    );
    expect(l.activitiesStyle, 'pill');
    expect(l.overviewStyle, 'gnome');
  });

  test('absent or unknown is off', () {
    final l = ThemeLayout.fromJson(
      const {'activitiesStyle': 'word', 'overviewStyle': 'kde'},
    );
    expect(l.activitiesStyle, isNull);
    expect(l.overviewStyle, isNull);
    final none = ThemeLayout.fromJson(const {});
    expect(none.activitiesStyle, isNull);
    expect(none.overviewStyle, isNull);
  });
}
