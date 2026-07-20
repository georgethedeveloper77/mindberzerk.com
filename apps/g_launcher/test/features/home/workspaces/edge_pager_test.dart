import 'package:flutter_test/flutter_test.dart';
import 'package:g_launcher/features/home/workspaces/edge_pager.dart';

/// Every test here maps to a bug the naive implementation has. Folder rules got
/// pure functions with tests because "I dragged an app into a folder and it
/// vanished" uninstalls a launcher; "I can't drop anything in the right-hand
/// column" is the same class of bug.
void main() {
  const width = 400.0;
  const cfg = EdgePagerConfig(
    edgeWidth: 56,
    dwell: Duration(milliseconds: 400),
    cooldown: Duration(milliseconds: 650),
  );

  EdgePager pager() => EdgePager(config: cfg);

  EdgePagerAction drag(
    EdgePager p, {
    required double x,
    required int ms,
    bool left = true,
    bool right = true,
  }) =>
      p.update(
        x: x,
        width: width,
        now: Duration(milliseconds: ms),
        canPageLeft: left,
        canPageRight: right,
      );

  test('does nothing in the middle of the desktop', () {
    final p = pager();
    expect(drag(p, x: 200, ms: 0), EdgePagerAction.none);
    expect(drag(p, x: 200, ms: 5000), EdgePagerAction.none);
  });

  test('does not flip before the dwell elapses — the edge column stays usable',
      () {
    final p = pager();
    expect(drag(p, x: 380, ms: 0), EdgePagerAction.none);
    expect(drag(p, x: 380, ms: 200), EdgePagerAction.none);
    expect(drag(p, x: 380, ms: 399), EdgePagerAction.none);
  });

  test('flips right after dwelling on the right edge', () {
    final p = pager();
    drag(p, x: 380, ms: 0);
    expect(drag(p, x: 380, ms: 400), EdgePagerAction.pageRight);
  });

  test('flips left after dwelling on the left edge', () {
    final p = pager();
    drag(p, x: 20, ms: 0);
    expect(drag(p, x: 20, ms: 450), EdgePagerAction.pageLeft);
  });

  test('does NOT machine-gun through workspaces while held at the edge', () {
    final p = pager();
    drag(p, x: 380, ms: 0);
    expect(drag(p, x: 380, ms: 400), EdgePagerAction.pageRight);

    // Held, not moved. Nothing more until the cooldown is fully done.
    for (var t = 410; t < 1050; t += 16) {
      expect(drag(p, x: 380, ms: t), EdgePagerAction.none,
          reason: 'unexpected flip at ${t}ms');
    }
  });

  test('a sustained hold re-arms once, after cooldown + a fresh dwell', () {
    final p = pager();
    drag(p, x: 380, ms: 0);
    expect(drag(p, x: 380, ms: 400), EdgePagerAction.pageRight);

    // Cooldown ends at 1050 and the dwell restarts from there.
    expect(drag(p, x: 380, ms: 1060), EdgePagerAction.none);
    expect(drag(p, x: 380, ms: 1200), EdgePagerAction.none);
    expect(drag(p, x: 380, ms: 1470), EdgePagerAction.pageRight);
  });

  test('leaving and re-entering the zone re-arms the dwell, not an instant flip',
      () {
    final p = pager();
    drag(p, x: 380, ms: 0);
    expect(drag(p, x: 380, ms: 400), EdgePagerAction.pageRight);

    drag(p, x: 200, ms: 500); // out
    expect(p.zone, EdgeZone.none);

    expect(drag(p, x: 380, ms: 600), EdgePagerAction.none); // back in, re-armed
    expect(drag(p, x: 380, ms: 900), EdgePagerAction.none); // still in cooldown
    expect(drag(p, x: 380, ms: 1100), EdgePagerAction.pageRight);
  });

  test('crossing straight from one edge to the other restarts the dwell', () {
    final p = pager();
    drag(p, x: 380, ms: 0);
    drag(p, x: 380, ms: 399); // nearly there
    drag(p, x: 20, ms: 400); // jumped to the other edge
    expect(drag(p, x: 20, ms: 500), EdgePagerAction.none,
        reason: 'the right-edge dwell must not fire a left flip');
  });

  test('never pages past the last workspace', () {
    final p = pager();
    drag(p, x: 380, ms: 0, right: false);
    expect(drag(p, x: 380, ms: 1000, right: false), EdgePagerAction.none);
  });

  test('never pages before the first workspace', () {
    final p = pager();
    drag(p, x: 20, ms: 0, left: false);
    expect(drag(p, x: 20, ms: 1000, left: false), EdgePagerAction.none);
  });

  test('reset clears the spent flag so the next drag is not swallowed', () {
    final p = pager();
    drag(p, x: 380, ms: 0);
    expect(drag(p, x: 380, ms: 400), EdgePagerAction.pageRight);

    p.reset(); // drag ended

    // A brand-new drag. Its first dwell must work, cooldown or not.
    drag(p, x: 380, ms: 500);
    expect(drag(p, x: 380, ms: 900), EdgePagerAction.pageRight);
  });

  test('zone boundaries are inclusive at exactly edgeWidth', () {
    final p = pager();
    expect(drag(p, x: 56, ms: 0), EdgePagerAction.none);
    expect(p.zone, EdgeZone.left);

    p.reset();
    drag(p, x: 344, ms: 0); // width - edgeWidth
    expect(p.zone, EdgeZone.right);

    p.reset();
    drag(p, x: 57, ms: 0);
    expect(p.zone, EdgeZone.none);
  });
}
