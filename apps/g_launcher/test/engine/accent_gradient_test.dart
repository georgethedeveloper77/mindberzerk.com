// Guards the two Garuda additions: the `title` panel module and the optional
// `accentGradient`, which must reach the device intact or not at all.
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:g_launcher/engine/theme_spec.dart';

Map<String, dynamic> _theme([Object? gradient]) => {
      'id': 'x',
      'name': 'X',
      'shell': 'plasma',
      'palette': {
        'bgTop': '#000000',
        'bgBottom': '#000000',
        'bar': '#000000',
        'dock': '#000000',
        'accent': '#FF0F7B',
        'onDark': '#FFFFFF',
      },
      if (gradient != null) 'accentGradient': gradient,
    };

void main() {
  group('accentGradient', () {
    test('three stops parse in order', () {
      final g = ThemeSpec.fromJson(
        _theme(['#FF0F7B', '#A044FF', '#2CD7F5']),
      ).accentGradient;
      expect(g, const [Color(0xFFFF0F7B), Color(0xFFA044FF), Color(0xFF2CD7F5)]);
    });

    test('absent is empty, so every other distro is untouched', () {
      expect(ThemeSpec.fromJson(_theme()).accentGradient, isEmpty);
    });

    test('one stop, four stops or a bad colour drop the whole list', () {
      expect(ThemeSpec.fromJson(_theme(['#FF0F7B'])).accentGradient, isEmpty);
      expect(
        ThemeSpec.fromJson(_theme(['#000000', '#111111', '#222222', '#333333']))
            .accentGradient,
        isEmpty,
      );
      expect(
        ThemeSpec.fromJson(_theme(['#FF0F7B', 'pink'])).accentGradient,
        isEmpty,
      );
    });
  });

  test('`title` is a panel module', () {
    expect(PanelModule.parse('title'), PanelModule.title);
  });

  test("COSMIC's three modules parse by their stored names", () {
    expect(PanelModule.parse('workspacesButton'), PanelModule.workspacesButton);
    expect(PanelModule.parse('appsButton'), PanelModule.appsButton);
    expect(PanelModule.parse('tiling'), PanelModule.tiling);
  });
}
