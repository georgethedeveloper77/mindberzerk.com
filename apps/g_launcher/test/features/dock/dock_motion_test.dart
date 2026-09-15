/// Every dock motion, built and thrown away.
///
/// ─── WHAT THIS CATCHES, AND WHAT IT CANNOT ─────────────────────────────────
///
/// It cannot tell you whether `tilt` looks right. Nothing can, short of a
/// device and an opinion.
///
/// What it catches is the class of bug that has actually cost time here: a mode
/// that throws on one path nobody walks. `DockPressMotion` built its
/// `AnimationController` with `late final`, and `sink` returns from `build`
/// before touching it, so the first access was `dispose()` and Flutter asserted
/// on a ticker created during teardown. Seventeen modes shipped and the one
/// that crashed was the DEFAULT, because the other sixteen all touched the
/// controller and hid it.
///
/// So: every mode, both orientations, with a focus and without, built, pumped
/// and disposed. Fifty-one combinations, none of them interesting individually.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g_launcher/features/dock/dock_animations.dart';
import 'package:g_launcher/features/dock/dock_motion.dart';

void main() {
  /// A slot, at a position, with or without a finger near it.
  Widget harness({
    required Widget child,
    required bool vertical,
  }) =>
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: SizedBox(width: 48, height: 48, child: child)),
      );

  const focus = DockFocus(position: 60, spread: 140);
  const pressedFocus =
      DockFocus(position: 60, spread: 140, pressed: true);

  group('DockSlotMotion', () {
    for (final mode in dockHoverModes) {
      for (final vertical in [false, true]) {
        testWidgets(
          '${mode.id} builds ${vertical ? 'vertical' : 'horizontal'}',
          (tester) async {
            for (final f in [null, focus]) {
              await tester.pumpWidget(
                harness(
                  vertical: vertical,
                  child: DockSlotMotion(
                    mode: mode.id,
                    focus: f,
                    // Deliberately OFF the focus, so the falloff is partial
                    // rather than 0 or 1. The interesting arithmetic is in the
                    // middle, and a slot sitting exactly under the finger
                    // exercises none of it.
                    centre: 92,
                    slotSize: 48,
                    vertical: vertical,
                    child: const SizedBox.expand(),
                  ),
                ),
              );
              expect(tester.takeException(), isNull);
            }
          },
        );
      }
    }

    testWidgets('an unknown mode rests rather than throwing', (tester) async {
      await tester.pumpWidget(
        harness(
          vertical: false,
          child: const DockSlotMotion(
            // A pack written against a newer build. The contract everywhere in
            // the theme layer is drop-not-fatal, and this is where it is proven
            // for motion.
            mode: 'hologram',
            focus: focus,
            centre: 92,
            slotSize: 48,
            vertical: false,
            child: SizedBox.expand(),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('DockPressMotion', () {
    for (final mode in dockPressModes) {
      testWidgets('${mode.id} presses, releases and disposes', (tester) async {
        Widget build(DockFocus? f) => harness(
              vertical: false,
              child: DockPressMotion(
                mode: mode.id,
                focus: f,
                centre: 60,
                vertical: false,
                child: const SizedBox.expand(),
              ),
            );

        // Rest, press, release: the transition that fires every mode. It is
        // `didUpdateWidget` that starts them, so a single pump would test
        // nothing.
        await tester.pumpWidget(build(null));
        await tester.pumpWidget(build(pressedFocus));
        await tester.pumpWidget(build(focus));
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.takeException(), isNull);

        // ─── THE ONE THAT MATTERED ──────────────────────────────────────
        //
        // Replacing the subtree disposes the state. `sink` never touches its
        // controller during build, so this is the only line in the file that
        // would have caught the ticker-on-a-dead-element assert.
        await tester.pumpWidget(const SizedBox.shrink());
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('disposed mid-animation without throwing', (tester) async {
      // `wave` waits before it starts, so its timer can outlive the widget.
      // Anything awaiting after an await has to check `mounted`, and this is
      // where that is proven rather than asserted in a comment.
      Widget build(DockFocus? f) => harness(
            vertical: false,
            child: DockPressMotion(
              mode: 'wave',
              focus: f,
              centre: 200,
              vertical: false,
              child: const SizedBox.expand(),
            ),
          );

      await tester.pumpWidget(build(pressedFocus));
      await tester.pumpWidget(build(focus));
      await tester.pump(const Duration(milliseconds: 40));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
    });
  });

  // ─── THE GROUP THAT WOULD HAVE CAUGHT THE REAL BUG ───────────────────────
  //
  // Everything above asserts that nothing throws, and the bug that shipped
  // threw nothing at all: both widgets returned a bare child at rest and a
  // wrapped one under a finger, so the slot was REPARENTED the instant a finger
  // landed and its gesture recognizer was disposed halfway through the gesture
  // it was recognising. Taps stopped completing and no app would open.
  //
  // A suite that cannot see that is a suite that gives false confidence, which
  // is worse than no suite. The only honest assertion is that a real button,
  // wrapped in a real motion, still fires when tapped.
  group('a slot inside a motion still answers a tap', () {
    /// A button under a motion, with the focus supplied by the harness rather
    /// than by a tracker, so each test controls exactly when it arrives.
    Widget slot({
      required String hover,
      required String press,
      required DockFocus? focus,
      required VoidCallback onTap,
    }) =>
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 48,
              height: 48,
              child: DockSlotMotion(
                mode: hover,
                focus: focus,
                centre: 60,
                slotSize: 48,
                vertical: false,
                child: DockPressMotion(
                  mode: press,
                  focus: focus,
                  centre: 60,
                  vertical: false,
                  child: GestureDetector(
                    onTap: onTap,
                    behavior: HitTestBehavior.opaque,
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
          ),
        );

    for (final hover in dockHoverModes) {
      testWidgets('${hover.id} hover does not eat the tap', (tester) async {
        var taps = 0;

        // Rest, then a finger arrives mid-gesture, which is the exact sequence
        // that broke: the down was delivered to one element and the up to a
        // different one.
        await tester.pumpWidget(
          slot(
            hover: hover.id,
            press: 'sink',
            focus: null,
            onTap: () => taps++,
          ),
        );

        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(GestureDetector)),
        );
        await tester.pump();

        await tester.pumpWidget(
          slot(
            hover: hover.id,
            press: 'sink',
            focus: const DockFocus(
              position: 60,
              spread: 140,
              pressed: true,
            ),
            onTap: () => taps++,
          ),
        );
        await tester.pump();

        await gesture.up();
        await tester.pump();

        expect(taps, 1, reason: '${hover.id} reparented the slot mid-gesture');
      });
    }

    for (final press in dockPressModes) {
      testWidgets('${press.id} press does not eat the tap', (tester) async {
        var taps = 0;

        await tester.pumpWidget(
          slot(
            hover: 'none',
            press: press.id,
            focus: null,
            onTap: () => taps++,
          ),
        );

        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(GestureDetector)),
        );
        await tester.pump();

        await tester.pumpWidget(
          slot(
            hover: 'none',
            press: press.id,
            focus: const DockFocus(
              position: 60,
              spread: 140,
              pressed: true,
            ),
            onTap: () => taps++,
          ),
        );
        await tester.pump();

        await gesture.up();
        await tester.pump(const Duration(milliseconds: 500));

        expect(taps, 1, reason: '${press.id} reparented the slot mid-gesture');
      });
    }

    testWidgets('the state under a motion survives a focus change',
        (tester) async {
      // A second proof of the same property, without a gesture. If the element
      // is preserved then so is its State, and a `StatefulWidget` that is
      // rebuilt rather than remounted keeps its `initState` count at one.
      //
      // This is what a recognizer is: State that has to live across the down
      // and the up.
      final key = GlobalKey();

      Widget build(DockFocus? f) => Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: SizedBox(
                width: 48,
                height: 48,
                child: DockSlotMotion(
                  mode: 'magnify',
                  focus: f,
                  centre: 60,
                  slotSize: 48,
                  vertical: false,
                  child: SizedBox.expand(key: key),
                ),
              ),
            ),
          );

      await tester.pumpWidget(build(null));
      final before = key.currentContext;

      await tester.pumpWidget(
        build(const DockFocus(position: 60, spread: 140)),
      );
      final after = key.currentContext;

      expect(after, isNotNull);
      expect(
        identical(before, after),
        isTrue,
        reason: 'the element was replaced when the focus arrived',
      );
    });
  });

  group('DockFocusTracker', () {
    testWidgets('reports null at rest and a position under a finger',
        (tester) async {
      DockFocus? seen;
      var builds = 0;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 200,
              height: 60,
              child: DockFocusTracker(
                enabled: true,
                vertical: false,
                spread: 140,
                builder: (context, f) {
                  seen = f;
                  builds++;
                  return const SizedBox.expand();
                },
              ),
            ),
          ),
        ),
      );

      // Rest is NULL, not a position at zero. A surface that confused the two
      // would magnify its first icon permanently.
      expect(seen, isNull);

      final gesture = await tester.startGesture(const Offset(420, 300));
      await tester.pump();
      expect(seen, isNotNull);
      expect(seen!.pressed, isTrue);

      await gesture.up();
      await tester.pump();
      expect(seen, isNull);

      expect(builds, greaterThan(1));
    });

    testWidgets('a cancelled pointer clears the focus', (tester) async {
      // The handler every hand-rolled tracker forgets. Without it the dock
      // stays magnified after a call arrives or a parent claims the gesture.
      DockFocus? seen;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 200,
              height: 60,
              child: DockFocusTracker(
                enabled: true,
                vertical: false,
                spread: 140,
                builder: (context, f) {
                  seen = f;
                  return const SizedBox.expand();
                },
              ),
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(const Offset(420, 300));
      await tester.pump();
      expect(seen, isNotNull);

      await gesture.cancel();
      await tester.pump();
      expect(seen, isNull);
    });

    testWidgets('disabled never wraps a Listener', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: DockFocusTracker(
            enabled: false,
            vertical: false,
            spread: 140,
            builder: (context, f) {
              expect(f, isNull);
              return const SizedBox.expand();
            },
          ),
        ),
      );

      // Not merely inert: ABSENT. A tracker that listened and did nothing would
      // still set state on every pointer move and still contend for gestures
      // that belong to the slots underneath.
      expect(find.byType(Listener), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
