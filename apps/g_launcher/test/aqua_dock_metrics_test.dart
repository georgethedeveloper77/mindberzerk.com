import 'package:flutter_test/flutter_test.dart';
import 'package:g_launcher/features/dock/aqua_dock_metrics.dart';

/// Pure math, so these run without a device — the point of keeping
/// aqua_dock_metrics.dart free of Flutter imports.
///
/// The assertions that matter are the CLIPPING ones. A magnifying dock that
/// overflows its own bounds is the failure mode this file exists to prevent, and
/// it only shows up at specific combinations of app count and finger position,
/// which is exactly the kind of thing nobody finds by hand on a phone.
void main() {
  const width = 380.0; // a typical budget-phone dock run

  group('capacity', () {
    test('is clamped to a usable range', () {
      expect(AquaDockMetrics.capacityFor(width), lessThanOrEqualTo(AquaDockMetrics.maxApps));
      expect(AquaDockMetrics.capacityFor(width), greaterThanOrEqualTo(AquaDockMetrics.minCapacity));
    });

    test('a tiny dock still reports the minimum rather than zero', () {
      expect(AquaDockMetrics.capacityFor(40), AquaDockMetrics.minCapacity);
    });
  });

  group('falloff', () {
    test('is 1 at the focus and 0 at the edge of the spread', () {
      expect(AquaDockMetrics.falloff(0), 1.0);
      expect(AquaDockMetrics.falloff(1), 0.0);
      expect(AquaDockMetrics.falloff(2), 0.0);
    });

    test('is flat at both ends, so the swell has no visible corner', () {
      // A linear ramp would give equal deltas; the raised cosine must not.
      final nearPeak = AquaDockMetrics.falloff(0.0) - AquaDockMetrics.falloff(0.1);
      final middle = AquaDockMetrics.falloff(0.45) - AquaDockMetrics.falloff(0.55);
      expect(nearPeak, lessThan(middle));
    });

    test('decreases monotonically', () {
      var previous = 1.0;
      for (var d = 0.0; d <= 1.0; d += 0.05) {
        final v = AquaDockMetrics.falloff(d);
        expect(v, lessThanOrEqualTo(previous + 1e-9));
        previous = v;
      }
    });
  });

  group('layout at rest', () {
    test('every slot is the same size', () {
      for (final n in [3, 4, 5, 6, 8]) {
        final slots = AquaDockMetrics.layout(count: n, available: width);
        final first = slots.first.size;
        for (final s in slots) {
          expect(s.size, closeTo(first, 1e-9), reason: '$n apps');
        }
      }
    });

    test('the row is centred', () {
      final slots = AquaDockMetrics.layout(count: 5, available: width);
      final left = slots.first.center - slots.first.size / 2;
      final right = width - (slots.last.center + slots.last.size / 2);
      expect(left, closeTo(right, 1e-6));
    });

    test('an empty dock lays out nothing rather than throwing', () {
      expect(AquaDockMetrics.layout(count: 0, available: width), isEmpty);
    });
  });

  group('magnification', () {
    test('the peak lands on the focused slot, not a neighbour', () {
      // The regression this guards: measuring distance in un-centred coordinates
      // put the swell one slot away from the finger.
      final rest = AquaDockMetrics.layout(count: 6, available: width);
      for (var i = 0; i < rest.length; i++) {
        final slots = AquaDockMetrics.layout(
          count: 6,
          available: width,
          focus: rest[i].center,
        );
        final sizes = [for (final s in slots) s.size];
        final peak = sizes.reduce((a, b) => a > b ? a : b);
        expect(sizes.indexOf(peak), i, reason: 'focus on slot $i');
      }
    });

    test('falls off symmetrically around a central focus', () {
      final rest = AquaDockMetrics.layout(count: 5, available: width);
      final slots = AquaDockMetrics.layout(
        count: 5,
        available: width,
        focus: rest[2].center,
      );
      expect(slots[1].size, closeTo(slots[3].size, 0.01));
      expect(slots[0].size, closeTo(slots[4].size, 0.01));
    });

    test('decreases with distance from the focus', () {
      final rest = AquaDockMetrics.layout(count: 6, available: width);
      final slots = AquaDockMetrics.layout(
        count: 6,
        available: width,
        focus: rest.first.center,
      );
      for (var i = 1; i < slots.length; i++) {
        expect(slots[i].size, lessThanOrEqualTo(slots[i - 1].size + 1e-9));
      }
    });

    test('never exceeds the peak', () {
      final rest = AquaDockMetrics.layout(count: 5, available: width);
      final slots = AquaDockMetrics.layout(
        count: 5,
        available: width,
        focus: rest[2].center,
      );
      for (final s in slots) {
        expect(s.size, lessThanOrEqualTo(AquaDockMetrics.peakSlot + 1e-9));
      }
    });
  });

  group('the dock never clips', () {
    test('at any app count and any focus position', () {
      for (var n = AquaDockMetrics.minCapacity;
          n <= AquaDockMetrics.capacityFor(width);
          n++) {
        final rest = AquaDockMetrics.layout(count: n, available: width);

        // Focus on each slot centre, and between them, and past both ends.
        final probes = <double>[
          -50,
          0,
          for (final s in rest) s.center,
          for (var i = 0; i < rest.length - 1; i++)
            (rest[i].center + rest[i + 1].center) / 2,
          width,
          width + 50,
        ];

        for (final focus in probes) {
          final slots =
              AquaDockMetrics.layout(count: n, available: width, focus: focus);
          final left = slots.first.center - slots.first.size / 2;
          final right = slots.last.center + slots.last.size / 2;

          expect(left, greaterThanOrEqualTo(-1e-6),
              reason: '$n apps, focus $focus');
          expect(right, lessThanOrEqualTo(width + 1e-6),
              reason: '$n apps, focus $focus');
        }
      }
    });

    test('on a narrow screen', () {
      const narrow = 240.0;
      for (var n = AquaDockMetrics.minCapacity;
          n <= AquaDockMetrics.capacityFor(narrow);
          n++) {
        final slots = AquaDockMetrics.layout(
          count: n,
          available: narrow,
          focus: narrow / 2,
        );
        expect(AquaDockMetrics.runLengthOf(slots),
            lessThanOrEqualTo(narrow + 1e-6));
      }
    });
  });

  group('runLengthOf', () {
    test('is zero for an empty dock', () {
      expect(AquaDockMetrics.runLengthOf(const []), 0);
    });

    test('spans outer edge to outer edge', () {
      final slots = AquaDockMetrics.layout(count: 4, available: width);
      final expected = 4 * slots.first.size + 3 * AquaDockMetrics.gap;
      expect(AquaDockMetrics.runLengthOf(slots), closeTo(expected, 1e-6));
    });
  });
}
