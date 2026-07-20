import 'package:flutter_test/flutter_test.dart';
import 'package:g_launcher/features/dock/dock_metrics.dart';

/// Re-baselined for the fit-to-run dock (minSlot 46, maxSlot 64, glyph ratios
/// 0.86 / 0.52, taper 4dp per app past 4, bottom hard-cap 6). Every expected
/// number here is derived from those constants, not the old fixed-52 slot.
///
/// Pure functions, so no widget/device: this is the unit half. The dock golden
/// is regenerated separately with `flutter test --update-goldens`.
void main() {
  group('DockSide.parse', () {
    test('maps the known strings', () {
      expect(DockSide.parse('bottom'), DockSide.bottom);
      expect(DockSide.parse('off'), DockSide.off);
      expect(DockSide.parse('left'), DockSide.left);
    });

    test('null and anything unknown default to left (Ubuntu default)', () {
      expect(DockSide.parse(null), DockSide.left);
      expect(DockSide.parse('sideways'), DockSide.left);
    });

    test('only a left dock is vertical', () {
      expect(DockSide.left.isVertical, isTrue);
      expect(DockSide.bottom.isVertical, isFalse);
      expect(DockSide.off.isVertical, isFalse);
    });
  });

  group('GridButtonPosition.parse', () {
    test('maps the known strings', () {
      expect(GridButtonPosition.parse('start'), GridButtonPosition.start);
      expect(GridButtonPosition.parse('off'), GridButtonPosition.off);
      expect(GridButtonPosition.parse('end'), GridButtonPosition.end);
    });

    test('null and anything unknown default to end (Ubuntu default)', () {
      expect(GridButtonPosition.parse(null), GridButtonPosition.end);
      expect(GridButtonPosition.parse('middle'), GridButtonPosition.end);
    });
  });

  group('DockMetrics.slotFor', () {
    test('a 4-app dock with room lands at maxSlot', () {
      expect(
        DockMetrics.slotFor(count: 4, available: 1000, hasGridButton: false),
        moreOrLessEquals(64.0, epsilon: 0.01),
      );
      // The grid button costs a slot but there is still room, so still maxSlot.
      expect(
        DockMetrics.slotFor(count: 4, available: 1000, hasGridButton: true),
        moreOrLessEquals(64.0, epsilon: 0.01),
      );
    });

    test('the count taper shrinks the slot past 4 apps even with room to spare',
        () {
      // 6 apps: maxSlot - (6-4)*4 = 56, and fit is far larger so taper wins.
      expect(
        DockMetrics.slotFor(count: 6, available: 2000, hasGridButton: false),
        moreOrLessEquals(56.0, epsilon: 0.01),
      );
    });

    test('fit-to-run bottoms out at minSlot on a narrow dock', () {
      // 6 apps + grid button crammed into 360dp: fit ≈ 39.7, clamped up to 46.
      expect(
        DockMetrics.slotFor(count: 6, available: 360, hasGridButton: true),
        moreOrLessEquals(46.0, epsilon: 0.01),
      );
      // Extreme: many apps, little room, still never below the floor.
      expect(
        DockMetrics.slotFor(count: 12, available: 400, hasGridButton: true),
        moreOrLessEquals(46.0, epsilon: 0.01),
      );
    });

    test('a single app does not blow past maxSlot', () {
      expect(
        DockMetrics.slotFor(count: 1, available: 1000, hasGridButton: false),
        moreOrLessEquals(64.0, epsilon: 0.01),
      );
    });

    test('the empty-dock guard returns maxSlot, never a divide-by-zero', () {
      expect(
        DockMetrics.slotFor(count: 0, available: 500, hasGridButton: false),
        moreOrLessEquals(64.0, epsilon: 0.01),
      );
    });

    test('slot stays within [minSlot, maxSlot] across a width sweep', () {
      for (var w = 200.0; w <= 3000.0; w += 40) {
        for (final count in const [0, 1, 4, 6, 9, 12]) {
          for (final grid in const [true, false]) {
            final slot = DockMetrics.slotFor(
              count: count,
              available: w,
              hasGridButton: grid,
            );
            expect(slot, greaterThanOrEqualTo(46.0));
            expect(slot, lessThanOrEqualTo(64.0));
          }
        }
      }
    });
  });

  group('DockMetrics.capacityFor', () {
    test('a tall left dock reaches the max capacity', () {
      expect(
        DockMetrics.capacityFor(available: 1200, hasGridButton: false),
        12,
      );
      expect(
        DockMetrics.capacityFor(available: 1200, hasGridButton: true),
        12,
      );
    });

    test('a bottom dock is hard-capped at maxBottomApps', () {
      expect(
        DockMetrics.capacityFor(
          available: 1200,
          hasGridButton: false,
          isBottom: true,
        ),
        6,
      );
      expect(
        DockMetrics.capacityFor(
          available: 800,
          hasGridButton: true,
          isBottom: true,
        ),
        6,
      );
    });

    test('capacity never drops below minCapacity, even on a tiny run', () {
      expect(DockMetrics.capacityFor(available: 200, hasGridButton: false), 3);
      expect(DockMetrics.capacityFor(available: 100, hasGridButton: false), 3);
    });

    test('capacity stays within [minCapacity, maxCapacity] across a sweep', () {
      for (var w = 80.0; w <= 3000.0; w += 40) {
        for (final grid in const [true, false]) {
          for (final bottom in const [true, false]) {
            final cap = DockMetrics.capacityFor(
              available: w,
              hasGridButton: grid,
              isBottom: bottom,
            );
            expect(cap, greaterThanOrEqualTo(3));
            expect(cap, lessThanOrEqualTo(bottom ? 6 : 12));
          }
        }
      }
    });
  });

  group('DockMetrics glyph ratios', () {
    test('an app glyph nearly fills its slot; the grid glyph is smaller', () {
      expect(
          DockMetrics.appGlyphFor(64), moreOrLessEquals(55.04, epsilon: 0.01));
      expect(
          DockMetrics.gridGlyphFor(64), moreOrLessEquals(33.28, epsilon: 0.01));
      expect(
          DockMetrics.appGlyphFor(50), moreOrLessEquals(43.0, epsilon: 0.01));
      expect(
          DockMetrics.gridGlyphFor(50), moreOrLessEquals(26.0, epsilon: 0.01));
    });

    test('for any slot, the app glyph is larger than the grid glyph', () {
      for (var slot = 46.0; slot <= 64.0; slot += 2) {
        expect(
          DockMetrics.appGlyphFor(slot),
          greaterThan(DockMetrics.gridGlyphFor(slot)),
        );
      }
    });
  });
}
