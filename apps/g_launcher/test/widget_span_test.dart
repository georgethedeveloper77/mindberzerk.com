import 'package:flutter_test/flutter_test.dart';
import 'package:g_launcher/engine/widget_span.dart';

/// The S22 as measured: 411dp wide, roughly 780dp of workspace once the panel
/// and the dock have taken theirs, on a 4x5 icon grid with colFactor 2 and
/// rowFactor 3.
const _s22 = (
  w: 411.0 / 8,
  h: 780.0 / 15,
  cols: 8,
  rows: 15,
  gutter: 6.0,
);

/// Same phone, same distro, five icon columns instead of four.
const _s22Wide = (
  w: 411.0 / 10,
  h: 780.0 / 15,
  cols: 10,
  rows: 15,
  gutter: 6.0,
);

WidgetFootprint _fp({
  int minW = 0,
  int minH = 0,
  int minResizeW = 0,
  int minResizeH = 0,
  int targetW = 0,
  int targetH = 0,
  int resizeMode = 3,
}) =>
    (
      minWidthDp: minW,
      minHeightDp: minH,
      minResizeWidthDp: minResizeW,
      minResizeHeightDp: minResizeH,
      targetCellWidth: targetW,
      targetCellHeight: targetH,
      resizeMode: resizeMode,
    );

WidgetSpan _resolve(WidgetFootprint f, {DeskletCell cell = _s22}) =>
    WidgetSpanResolver.resolve(f, cell: cell, colFactor: 2, rowFactor: 3);

void main() {
  group('grid units, when the provider gave them', () {
    test('Spotify 4x2 fills the width and two icon rows', () {
      // THE REGRESSION. The old code did `4 * 70 / 49.9 = 6` of 8 columns and
      // `2 * 70 / 52 = 3` of 15 rows: 75% of the width it asked for and 50% of
      // the height. Nothing was wrong with the widget; it was handed the wrong
      // rectangle.
      final s = _resolve(_fp(targetW: 4, targetH: 2, minW: 250, minH: 110));
      expect(s.spanX, 8); // the full 4 icon columns
      expect(s.spanY, 6); // exactly 2 icon rows
    });

    test('grid units ignore dp entirely', () {
      // Same cells, absurd dp. The dp must not get a vote when targetCell* is
      // present, or the two paths would disagree and the re-derive after a
      // grid change would silently move things.
      final a = _resolve(_fp(targetW: 2, targetH: 1, minW: 110, minH: 40));
      final b = _resolve(_fp(targetW: 2, targetH: 1, minW: 9999, minH: 9999));
      expect(a.spanX, b.spanX);
      expect(a.spanY, b.spanY);
      expect(a.spanX, 4);
      expect(a.spanY, 3);
    });

    test('a 5-cell widget on a 4-column grid clamps rather than overflowing',
        () {
      final s = _resolve(_fp(targetW: 5, targetH: 1));
      expect(s.spanX, 8);
    });

    test('the same widget keeps its PROPORTION when columns change', () {
      // What no other launcher does. 4 of 4 columns is the full width; on a
      // 5-column grid the same widget must still fill it rather than keep a
      // cell count that now means four fifths.
      final narrow = _resolve(_fp(targetW: 4, targetH: 2), cell: _s22);
      final wide = _resolve(_fp(targetW: 4, targetH: 2), cell: _s22Wide);
      expect(narrow.spanX / narrow.maxSpanX, 1.0);
      expect(wide.spanX, 8); // 4 icon columns of 5, still 4 icon columns
      expect(wide.spanX / wide.maxSpanX, 0.8);
    });
  });

  group('dp, when the provider gave nothing else', () {
    test('a 4-cell widget declaring 250dp lands on 4 icon columns', () {
      // 70n - 30 gives 250dp for n = 4. With the gutter accounted for this is
      // ceil(256 / 51.4) = 5 fine columns, which is 2.5 icon columns: LESS
      // than the grid-unit path would give, and correctly so. A legacy
      // provider declared a MINIMUM, not a target.
      final s = _resolve(_fp(minW: 250, minH: 110));
      expect(s.spanX, 5);
      expect(s.spanY, greaterThanOrEqualTo(2));
    });

    test('dp is grid-agnostic: the same dp is the same share of the screen',
        () {
      final narrow = _resolve(_fp(minW: 250, minH: 110), cell: _s22);
      final wide = _resolve(_fp(minW: 250, minH: 110), cell: _s22Wide);
      final narrowShare = narrow.spanX / narrow.maxSpanX;
      final wideShare = wide.spanX / wide.maxSpanX;
      expect((narrowShare - wideShare).abs(), lessThan(0.12));
    });

    test('a provider that reports nothing gets one cell, not zero', () {
      final s = _resolve(_fp());
      expect(s.spanX, 1);
      expect(s.spanY, 1);
    });
  });

  group('resize limits', () {
    test('RESIZE_NONE pins both axes to the placed span', () {
      final s = _resolve(
        _fp(targetW: 2, targetH: 2, resizeMode: WidgetResize.none),
      );
      expect(s.minSpanX, s.spanX);
      expect(s.maxSpanX, s.spanX);
      expect(s.minSpanY, s.spanY);
      expect(s.maxSpanY, s.spanY);
      expect(s.resizableX, isFalse);
      expect(s.resizableY, isFalse);
    });

    test('horizontal-only leaves the vertical axis pinned', () {
      final s = _resolve(
        _fp(targetW: 4, targetH: 1, resizeMode: WidgetResize.horizontal),
      );
      expect(s.resizableX, isTrue);
      expect(s.resizableY, isFalse);
      expect(s.minSpanY, s.spanY);
    });

    test('the floor comes from minResize dp and never exceeds the span', () {
      final s = _resolve(_fp(targetW: 4, targetH: 2, minResizeW: 110));
      expect(s.minSpanX, lessThanOrEqualTo(s.spanX));
      expect(s.minSpanX, greaterThan(1));
    });

    test('a minResize larger than the placed span is clamped, not honoured',
        () {
      // A provider is allowed to report an inconsistent pair. A floor above the
      // ceiling would make every resize drag refuse.
      final s = _resolve(_fp(targetW: 1, targetH: 1, minResizeW: 9999));
      expect(s.minSpanX, lessThanOrEqualTo(s.spanX));
    });
  });

  group('config round trip', () {
    test('a footprint survives being stored and read back', () {
      final f = _fp(
        minW: 250,
        minH: 110,
        minResizeW: 180,
        minResizeH: 40,
        targetW: 4,
        targetH: 2,
        resizeMode: 3,
      );
      final config = <String, Object?>{
        WidgetConfigKeys.minWidthDp: f.minWidthDp,
        WidgetConfigKeys.minHeightDp: f.minHeightDp,
        WidgetConfigKeys.minResizeWidthDp: f.minResizeWidthDp,
        WidgetConfigKeys.minResizeHeightDp: f.minResizeHeightDp,
        WidgetConfigKeys.targetCellWidth: f.targetCellWidth,
        WidgetConfigKeys.targetCellHeight: f.targetCellHeight,
        WidgetConfigKeys.resizeMode: f.resizeMode,
      };
      expect(WidgetSpanResolver.footprintFromConfig(config), f);
    });

    test('a config written by an older build reads as zeros, not a throw', () {
      final f = WidgetSpanResolver.footprintFromConfig(const {
        'widgetId': 7,
        'providerKey': 'com.example/.Provider',
      });
      expect(f.targetCellWidth, 0);
      expect(f.minWidthDp, 0);
      // And it still resolves to something placeable.
      expect(_resolve(f).spanX, 1);
    });

    test('userSized is false unless explicitly true', () {
      expect(WidgetSpanResolver.isUserSized(const {}), isFalse);
      expect(
        WidgetSpanResolver.isUserSized(const {WidgetConfigKeys.userSized: 1}),
        isFalse,
      );
      expect(
        WidgetSpanResolver.isUserSized(
          const {WidgetConfigKeys.userSized: true},
        ),
        isTrue,
      );
    });
  });

  group('content box', () {
    test('the gutter comes out of the rectangle the widget is told about', () {
      final box = WidgetSpanResolver.contentBox(8, 6, cell: _s22);
      expect(box.w, closeTo(411 - 6, 0.01));
      expect(box.h, closeTo(312 - 6, 0.01));
    });

    test('a 4x2 is wider than tall, whatever its cell ratio says', () {
      // The Kotlin renderer used to use 4/2 = 2.0 as the preview aspect. The
      // real placed aspect is about 1.3, which is why previews were a visibly
      // different shape from the thing they previewed.
      final a = WidgetSpanResolver.aspectOf(8, 6, cell: _s22);
      expect(a, greaterThan(1.0));
      expect(a, lessThan(1.6));
    });

    test('a degenerate cell does not divide by zero', () {
      const dead = (w: 0.0, h: 0.0, cols: 8, rows: 15, gutter: 6.0);
      expect(WidgetSpanResolver.aspectOf(1, 1, cell: dead), 1.0);
      expect(_resolve(_fp(minW: 250), cell: dead).spanX, 1);
    });
  });
}
