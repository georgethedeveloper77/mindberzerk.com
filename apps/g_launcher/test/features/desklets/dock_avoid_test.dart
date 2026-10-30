import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:g_launcher/data/prefs/launcher_prefs.dart' show Desklet;
import 'package:g_launcher/features/desklets/dock_avoid.dart';

Desklet d(String id, int col, int row, [int sx = 4, int sy = 2]) => Desklet(
    id: id, kind: 'clock', page: 0, col: col, row: row, spanX: sx, spanY: sy);

void main() {
  // An 8 x 14 grid of 47 x 56 cells; a left dock 75 wide, rows 4 to 10.
  const cols = 8, rows = 14;
  const cw = 47.0, ch = 56.0;
  const sideDock = Rect.fromLTWH(3, 4 * ch + 10, 75, 6 * ch);

  test('only cells under the dock are blocked; the top-left corner stays free',
      () {
    final b = dockCells(sideDock, cellW: cw, cellH: ch, cols: cols, rows: rows);
    expect(b.contains(0), isFalse, reason: 'row 0, col 0 is above the dock');
    expect(b.contains(4 * cols + 0), isTrue);
    expect(b.contains(4 * cols + 3), isFalse,
        reason: 'columns past the dock are free');
    expect(
        dockCells(null, cellW: cw, cellH: ch, cols: cols, rows: rows), isEmpty);
  });

  test('a desklet clear of the dock stays where it is saved', () {
    final b = dockCells(sideDock, cellW: cw, cellH: ch, cols: cols, rows: rows);
    final shown =
        placeAroundDock([d('vpn', 0, 0)], cols: cols, rows: rows, blocked: b);
    expect(shown['vpn'], (col: 0, row: 0));
  });

  test('a desklet under the dock is shown beside it, saved spot untouched', () {
    final b = dockCells(sideDock, cellW: cw, cellH: ch, cols: cols, rows: rows);
    final clock = d('clock', 0, 5);
    final shown = placeAroundDock([clock], cols: cols, rows: rows, blocked: b);
    expect(shown['clock']!.col, greaterThan(1));
    expect(shown['clock']!.row, 5, reason: 'moves sideways first');
    expect(clock.col, 0, reason: 'the saved desklet is never changed');
  });

  test('a moved desklet never lands on another one', () {
    final b = dockCells(sideDock, cellW: cw, cellH: ch, cols: cols, rows: rows);
    final shown = placeAroundDock([d('a', 0, 5), d('b', 2, 5)],
        cols: cols, rows: rows, blocked: b);
    final a = footprint(shown['a']!.col, shown['a']!.row, 4, 2, cols, rows)!;
    final bb = footprint(shown['b']!.col, shown['b']!.row, 4, 2, cols, rows)!;
    expect(a.intersection(bb), isEmpty);
  });

  test('no dock: everything as saved', () {
    final shown = placeAroundDock([d('a', 0, 5)],
        cols: cols, rows: rows, blocked: const {});
    expect(shown['a'], (col: 0, row: 5));
  });
}
