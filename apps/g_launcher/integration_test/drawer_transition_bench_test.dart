/// PHASE 1: how much does a transition actually cost.
///
/// ─── WHY THIS EXISTS BEFORE ANY NEW STYLE IS WRITTEN ────────────────────────
///
/// A review said the drawer's side swipe is jerky and the cube is smooth. Those
/// two share every line except one `Matrix4`, so either the report is about a
/// different screen entirely, or something in the paged path costs far more
/// than reading it suggests. Adding six more transitions on top of an
/// unexplained stutter would be building on sand.
///
/// It also has to keep answering the question. "Is cylinder more expensive than
/// cube" will come up once per style added, and the honest answer is a number
/// from the same swipe on the same device, not an argument from construction.
///
/// ─── THE TILE IS HELD CONSTANT, AND THAT IS THE EXPERIMENT ──────────────────
///
/// A real drawer tile is an `AppIcon`, which is a `ConsumerWidget` watching four
/// providers and awaiting a bitmap from native. That cost is IDENTICAL across
/// every transition, so including it would add a large constant to all eight
/// numbers and bury the differences under it. It would also drag a platform
/// channel into a test that has no native side.
///
/// So the tile here is a coloured box and a label: the same widget count and
/// roughly the same paint as a real one, and the same in every run. What varies
/// is exactly the thing under test.
///
/// That means this measures the TRANSITION, not the drawer. For absolute
/// numbers on the real app, see the gfxinfo note at the bottom of this file.
///
/// ─── RUNNING IT ─────────────────────────────────────────────────────────────
///
///   flutter drive \
///     --driver=test_driver/integration_test.dart \
///     --target=integration_test/drawer_transition_bench_test.dart \
///     --profile
///
/// PROFILE, never debug. A debug build runs unoptimised Dart with assertions on
/// every frame, so its numbers are three to five times worse and, worse than
/// that, wrong in different proportions for different work. Benchmarking a
/// debug build is how you optimise the thing that was never slow.
///
/// The driver prints a comparison table and writes one JSON summary per style
/// into `build/`.
///
/// ─── AND RUN IT ON THE SLOW PHONE ───────────────────────────────────────────
///
/// An S22 at 120Hz has 8.3ms per frame and will pass everything here. The number
/// that transfers is the RATIO between styles on one device: a style rastering
/// at 1.5ms has five times the headroom it needs and survives a phone a third as
/// fast, and one at 5ms passes on your desk with almost nothing left. That
/// second one is what reads as jerky in Lagos.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g_launcher/design/drawer_transition.dart';
import 'package:g_launcher/features/drawer/drawer_pager.dart';
import 'package:integration_test/integration_test.dart';

/// Enough apps for five pages at 4x5, so a fling crosses real page boundaries
/// rather than bouncing at an edge.
const _itemCount = 96;

/// How many flings per style. Enough that one slow first frame, which every
/// style pays while its pages build, does not dominate the average.
const _flings = 8;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// One style's harness.
  ///
  /// No ProviderScope and no MaterialApp theming beyond a background: anything
  /// this puts above the pager is cost the pager does not have in the app, and
  /// it would land on every style equally while making all of them look worse.
  Widget harness(DrawerTransition transition) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF101014),
        body: DrawerPager(
          itemCount: _itemCount,
          columns: 4,
          // The drawer's own tile aspect. A different one here would change the
          // row count and therefore how many tiles are painted per page, which
          // is the one thing that must not vary between runs.
          aspectRatio: 0.78,
          transition: transition,
          itemBuilder: (context, i) => _BenchTile(index: i),
        ),
      ),
    );
  }

  /// The vertical drawer, which is a different widget rather than a different
  /// transform.
  ///
  /// Included as the FLOOR. It has no page transition at all, so whatever it
  /// costs is what a scrolling grid of this many tiles costs on this device, and
  /// every paged number should be read against it rather than against zero.
  Widget verticalHarness() {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF101014),
        body: GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            childAspectRatio: 0.78,
            crossAxisSpacing: 10,
            mainAxisSpacing: 14,
          ),
          itemCount: _itemCount,
          itemBuilder: (context, i) => _BenchTile(index: i),
        ),
      ),
    );
  }

  /// Fling the pager sideways [_flings] times and let each settle.
  ///
  /// ─── SIDEWAYS, WITH A REAL VELOCITY ───────────────────────────────────────
  ///
  /// 800 is roughly what a deliberate thumb flick produces. Far higher and the
  /// PageView clamps to one page anyway while the settle animation runs shorter,
  /// which measures fewer frames of the thing under test.
  ///
  /// `pumpAndSettle` with a 16ms step rather than the default: the default
  /// pumps in 100ms jumps, which is six frames of animation collapsed into one
  /// and produces a frame count that has nothing to do with what a phone draws.
  /// One fling that is NOT measured.
  ///
  /// ─── WHY THE FIRST ONE HAS TO BE THROWN AWAY ──────────────────────────────
  ///
  /// Every arm pumps a fresh widget tree, so the first swipe pays for building
  /// the pages either side of the start, and that single frame lands in the
  /// trace as `worst_frame_build_time_millis`. It made the column unreadable:
  /// the vertical list, which drops no frames at all, reported worst builds of
  /// 3.96, 7.17 and 11.31 across three otherwise identical runs.
  ///
  /// The warmup moves that cost outside `watchPerformance`, so `worst` starts
  /// meaning what it should: the slowest frame of a swipe on a drawer that is
  /// already up.
  Future<void> warmUp(WidgetTester tester, Finder target, Offset by) async {
    await tester.fling(target, by, 800);
    await tester.pumpAndSettle(const Duration(milliseconds: 16));
  }

  Future<void> flingAcross(WidgetTester tester, Finder target) async {
    for (var i = 0; i < _flings; i++) {
      await tester.fling(target, const Offset(-300, 0), 800);
      await tester.pumpAndSettle(const Duration(milliseconds: 16));
    }
  }

  Future<void> flingDown(WidgetTester tester, Finder target) async {
    for (var i = 0; i < _flings; i++) {
      await tester.fling(target, const Offset(0, -400), 800);
      await tester.pumpAndSettle(const Duration(milliseconds: 16));
    }
  }

  testWidgets('vertical: a scrolling grid, as the floor', (tester) async {
    await tester.pumpWidget(verticalHarness());
    await tester.pumpAndSettle();
    await warmUp(tester, find.byType(GridView), const Offset(0, -400));

    await binding.watchPerformance(
      () async => flingDown(tester, find.byType(GridView)),
      reportKey: 'transition_vertical',
    );
  });

  /// One arm per style.
  ///
  /// Identical apart from the value handed to the pager, which is the entire
  /// point: the tile, the item count, the fling and the warmup are held still,
  /// so the only thing that differs between two rows of the table is the
  /// matrix. A run that changed the tile to "make it more realistic" would
  /// silently invalidate every earlier measurement.
  void benchmark(String label, DrawerTransition transition) {
    testWidgets(label, (tester) async {
      await tester.pumpWidget(harness(transition));
      await tester.pumpAndSettle();
      await warmUp(tester, find.byType(PageView), const Offset(-300, 0));

      await binding.watchPerformance(
        () async => flingAcross(tester, find.byType(PageView)),
        reportKey: 'transition_${transition.name}',
      );
    });
  }

  benchmark('slide: no transform, the baseline', DrawerTransition.slide);
  benchmark('cube: the one that already shipped', DrawerTransition.cube);
  benchmark('cylinder: the cube, softened', DrawerTransition.cylinder);
  benchmark('sphere: the cube, pinched', DrawerTransition.sphere);
  benchmark('depth: scale and fade, no rotation', DrawerTransition.depth);
  benchmark('stack: one page holds still', DrawerTransition.stack);

  // A style added to `DrawerTransition` needs one more `benchmark(...)` line
  // above and nothing else. The driver picks up any report key starting with
  // `transition_`, so the table grows on its own.
}

/// A stand-in for one app tile.
///
/// Same shape as the real thing, an icon box over a label, so the paint cost per
/// tile is in the right neighbourhood. Deliberately NOT an `AppIcon`: see the
/// file header for why holding it constant is the experiment rather than a
/// shortcut.
///
/// `const` where it can be, and the colour derived arithmetically rather than
/// from a list, so nothing here allocates per frame and adds noise to the very
/// thing being measured.
class _BenchTile extends StatelessWidget {
  const _BenchTile({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    // A spread of hues, so the pages are visually distinguishable when watching
    // a run, and so no two adjacent tiles composite identically in a way a GPU
    // could shortcut.
    final hue = (index * 37) % 360;
    final color = HSLColor.fromAHSL(1, hue.toDouble(), 0.55, 0.55).toColor();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: AspectRatio(
            aspectRatio: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'App $index',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, color: Colors.white70),
        ),
      ],
    );
  }
}

// ── ABSOLUTE NUMBERS, FROM THE REAL APP ─────────────────────────────────────
//
// Everything above is RELATIVE: same tile, same fling, same device, so the only
// thing that differs between two runs is the transform. That answers "is
// cylinder more expensive than cube" and deliberately does not answer "is the
// real drawer smooth on a Tecno", because the real drawer also pays for
// AppIcon, the icon cache, the app list and whatever else is on screen.
//
// For that, drive the real app by hand on the real phone and ask the OS:
//
//   adb shell dumpsys gfxinfo com.mindhunter.g_launcher reset
//   ... swipe the drawer for ten seconds ...
//   adb shell dumpsys gfxinfo com.mindhunter.g_launcher framestats
//
// That needs no Flutter tooling, works on a borrowed device, and reports what
// SurfaceFlinger actually saw rather than what the framework believes it drew.
// The line worth reading is the janky-frame percentage and the 95th percentile,
// not the average: jank is a tail problem, and an average hides exactly the
// frames a person notices.
