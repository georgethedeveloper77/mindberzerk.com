import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:g_launcher/features/drawer/app_icon.dart';

/// A [size]-square RGBA canvas with an opaque square of side [art], centred.
Uint8List _canvas(int size, int art) {
  final rgba = Uint8List(size * size * 4);
  final from = (size - art) ~/ 2;
  for (var y = from; y < from + art; y++) {
    for (var x = from; x < from + art; x++) {
      rgba[(y * size + x) * 4 + 3] = 255;
    }
  }
  return rgba;
}

void main() {
  test('art at two thirds of the canvas is enlarged to the edge', () {
    final s = fillScaleFor(_canvas(90, 60), width: 90, height: 90);
    expect(s, closeTo(1.5, 0.01));
  });

  test('full-bleed art is left alone', () {
    expect(fillScaleFor(_canvas(90, 90), width: 90, height: 90), 1.0);
  });

  test('tiny art is capped, never blown up past 1.6x', () {
    expect(fillScaleFor(_canvas(90, 20), width: 90, height: 90), 1.6);
  });

  test('an empty canvas is left alone', () {
    expect(fillScaleFor(Uint8List(90 * 90 * 4), width: 90, height: 90), 1.0);
  });
}
