import 'dart:ui' show Rect;

import '../../data/prefs/launcher_prefs.dart' show Desklet;

/// Desklets and the dock: the dock is a BOX, not a strip.
///
/// The desklet grid runs edge to edge, and only the cells the dock actually
/// covers (plus a small gap) are unavailable. An empty dock reserves only its
/// apps button; a bottom dock leaves the corners free.
///
/// The dock never rewrites anyone's layout. A desklet whose saved spot is
/// under the dock is SHOWN at the nearest free spot, and its saved position is
/// left alone, so it returns by itself when the dock shrinks. If the user
/// drags it while it is moved aside, the drop is saved like any other move:
/// that becomes their chosen spot.

typedef CellPos = ({int col, int row});

/// Cell indices (`row * cols + col`) under [dock], in grid coordinates.
Set<int> dockCells(
  Rect? dock, {
  required double cellW,
  required double cellH,
  required int cols,
  required int rows,
  double gap = 4,
}) {
  if (dock == null || dock.isEmpty || cellW <= 0 || cellH <= 0) return const {};
  final zone = dock.inflate(gap);
  final out = <int>{};
  for (var r = 0; r < rows; r++) {
    for (var c = 0; c < cols; c++) {
      final cell = Rect.fromLTWH(c * cellW, r * cellH, cellW, cellH);
      if (cell.overlaps(zone)) out.add(r * cols + c);
    }
  }
  return out;
}

/// The cells a footprint covers, or null when it does not fit the grid.
Set<int>? footprint(
    int col, int row, int spanX, int spanY, int cols, int rows) {
  if (col < 0 || row < 0 || col + spanX > cols || row + spanY > rows)
    return null;
  return {
    for (var r = row; r < row + spanY; r++)
      for (var c = col; c < col + spanX; c++) r * cols + c,
  };
}

/// The free spot nearest ([col], [row]) for a [spanX] x [spanY] footprint,
/// avoiding [blocked] and [taken]; null when the page has no room.
CellPos? nearestClear({
  required int col,
  required int row,
  required int spanX,
  required int spanY,
  required int cols,
  required int rows,
  required Set<int> blocked,
  Set<int> taken = const {},
}) {
  CellPos? best;
  var bestScore = 1 << 30;
  for (var r = 0; r + spanY <= rows; r++) {
    for (var c = 0; c + spanX <= cols; c++) {
      final cells = footprint(c, r, spanX, spanY, cols, rows)!;
      if (cells.any(blocked.contains) || cells.any(taken.contains)) continue;
      // Rows weigh a little more than columns: sliding sideways off a side
      // dock reads as "moved aside", jumping down the page as "lost".
      final score = (c - col) * (c - col) * 2 + (r - row) * (r - row) * 3;
      if (score < bestScore) {
        bestScore = score;
        best = (col: c, row: r);
      }
    }
  }
  return best;
}

/// Where each desklet on one page is SHOWN. Desklets clear of the dock stay
/// exactly where they are saved; the rest, in a stable order, take the
/// nearest free spot. A desklet with no room anywhere keeps its saved spot.
Map<String, CellPos> placeAroundDock(
  List<Desklet> items, {
  required int cols,
  required int rows,
  required Set<int> blocked,
}) {
  final shown = <String, CellPos>{};
  if (blocked.isEmpty) {
    for (final d in items) {
      shown[d.id] = (col: d.col, row: d.row);
    }
    return shown;
  }
  final taken = <int>{};
  final displaced = <Desklet>[];
  for (final d in items) {
    final cells = footprint(d.col, d.row, d.spanX, d.spanY, cols, rows);
    if (cells == null || cells.any(blocked.contains)) {
      displaced.add(d);
    } else {
      shown[d.id] = (col: d.col, row: d.row);
      taken.addAll(cells);
    }
  }
  displaced.sort((a, b) =>
      a.row != b.row ? a.row.compareTo(b.row) : a.col.compareTo(b.col));
  for (final d in displaced) {
    final spot = nearestClear(
      col: d.col,
      row: d.row,
      spanX: d.spanX,
      spanY: d.spanY,
      cols: cols,
      rows: rows,
      blocked: blocked,
      taken: taken,
    );
    final at = spot ?? (col: d.col, row: d.row);
    shown[d.id] = at;
    taken.addAll(
        footprint(at.col, at.row, d.spanX, d.spanY, cols, rows) ?? const {});
  }
  return shown;
}
