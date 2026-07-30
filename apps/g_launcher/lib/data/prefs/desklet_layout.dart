import '../../engine/desklet_spec.dart';
import 'launcher_prefs.dart';

/// Every desklet placement mutation, as pure functions. PHASE D2.
///
/// Pure for the same reason [HomeLayout] is, with the stakes raised: a desklet
/// occupies a rectangle rather than a cell, so "it landed on top of my monitor"
/// and "resizing it ate the tile next to it" are both real bugs that a widget
/// tree makes almost impossible to test. All of this is tested without a phone.
///
/// Widgets do gestures. This does state.
///
/// ─── THE FUNCTION THAT IS NOT HERE, AND WHY ─────────────────────────────────
///
/// There is no `prune()`, and the plan said there would be. Writing it made the
/// case against it: pruning means deleting placements whose kind is not in the
/// registry, and that is exactly the behaviour the whole schema is built to
/// avoid. A CDN pack can offer a kind a shipped APK has never heard of; if an
/// older build prunes it, the user's desktop is quietly destroyed and updating
/// the app does not bring it back.
///
/// [renderable] replaces it. It is a QUERY, not a mutation: it answers "what can
/// I draw right now" and leaves storage untouched. Unknown kinds are invisible
/// and immortal, which is the correct pair.
///
/// [normalise] is the one thing that does rewrite, and only for data that is
/// structurally impossible rather than merely unrecognised: duplicate ids and
/// out-of-range spans, both of which can arrive from a hand-edited starter
/// desktop.
class DeskletLayout {
  const DeskletLayout._();

  // ─── QUERIES ───────────────────────────────────────────────────────────────

  static List<Desklet> onPage(LauncherPrefs p, int page) =>
      p.desklets.where((d) => d.page == page).toList();

  static Desklet? byId(LauncherPrefs p, String id) {
    for (final d in p.desklets) {
      if (d.id == id) return d;
    }
    return null;
  }

  /// Whatever covers cell (col, row), or null.
  static Desklet? at(LauncherPrefs p, int page, int col, int row) {
    for (final d in p.desklets) {
      if (d.page != page) continue;
      if (col >= d.col && col < d.right && row >= d.row && row < d.bottom) {
        return d;
      }
    }
    return null;
  }

  /// What can actually be drawn on [page] right now.
  ///
  /// Drops kinds this build does not know WITHOUT touching storage, and drops
  /// [DeskletKind.paneOnly] kinds when the surface is a grid (a `df -h` block
  /// belongs in the terminal's scrollback, not floating on a GNOME desktop).
  /// Pass `pane: true` from the TUI shell and both filters relax to the pane's
  /// own rule: order is the layout, position is ignored.
  static List<Desklet> renderable(
    LauncherPrefs p,
    int page, {
    bool pane = false,
  }) {
    return p.desklets.where((d) {
      if (d.page != page) return false;
      final kind = DeskletKinds.byId(d.kind);
      if (kind == null) return false; // unknown: invisible, but still stored
      if (kind.paneOnly && !pane) return false;
      return true;
    }).toList();
  }

  /// Would a rectangle at (col,row) fit on [page] without overlapping anything?
  ///
  /// [ignoreId] excludes a desklet from the test, which is what makes move and
  /// resize work: a tile is allowed to overlap the space it already occupies.
  /// Forgetting it means nothing can ever be nudged one cell.
  static bool fits(
    LauncherPrefs p, {
    required int page,
    required int col,
    required int row,
    required int spanX,
    required int spanY,
    required int cols,
    required int rows,
    String? ignoreId,
  }) {
    if (col < 0 || row < 0 || spanX < 1 || spanY < 1) return false;
    if (col + spanX > cols || row + spanY > rows) return false;

    final probe = Desklet(
      id: '__probe__',
      kind: '__probe__',
      page: page,
      col: col,
      row: row,
      spanX: spanX,
      spanY: spanY,
    );

    for (final d in p.desklets) {
      if (d.id == ignoreId) continue;
      if (d.overlaps(probe)) return false;
    }
    return true;
  }

  /// First free top-left cell for a spanX by spanY rectangle, scanning rows
  /// then columns. Null when the page is full.
  ///
  /// Row-major so placement reads top-to-bottom, left-to-right — the order a
  /// desktop fills naturally. Column-major would put the second tile below the
  /// first, which looks like a bug even though it is a valid packing.
  static ({int col, int row})? firstFreeCell(
    LauncherPrefs p, {
    required int page,
    required int spanX,
    required int spanY,
    required int cols,
    required int rows,
  }) {
    for (var r = 0; r + spanY <= rows; r++) {
      for (var c = 0; c + spanX <= cols; c++) {
        if (fits(
          p,
          page: page,
          col: c,
          row: r,
          spanX: spanX,
          spanY: spanY,
          cols: cols,
          rows: rows,
        )) {
          return (col: c, row: r);
        }
      }
    }
    return null;
  }

  // ─── MUTATIONS ─────────────────────────────────────────────────────────────

  /// Add a desklet at the first cell it fits.
  ///
  /// Returns [p] UNCHANGED when the page has no room, and the caller compares
  /// identity and tells the user. Same contract as `HomeLayout.pinToDock`: a
  /// silently dropped placement is worse than a refused one, because the user
  /// watches the picker close and nothing appear.
  static LauncherPrefs place(
    LauncherPrefs p, {
    required String kindId,
    required int page,
    required int cols,
    required int rows,
    required String Function() newId,
    Map<String, Object?> config = const {},
    int? spanX,
    int? spanY,
  }) {
    final kind = DeskletKinds.byId(kindId);
    if (kind == null) return p;

    // Clamp BEFORE searching. Asking for space the kind is not allowed to
    // occupy and then shrinking would place it somewhere the clamped size did
    // not need to be.
    final sx = _clampSpanX(kind, spanX ?? kind.defaultSpanX, cols);
    final sy = _clampSpanY(kind, spanY ?? kind.defaultSpanY, rows);

    final cell = firstFreeCell(
      p,
      page: page,
      spanX: sx,
      spanY: sy,
      cols: cols,
      rows: rows,
    );
    if (cell == null) return p;

    return p.copyWith(
      desklets: [
        ...p.desklets,
        Desklet(
          id: newId(),
          kind: kindId,
          page: page,
          col: cell.col,
          row: cell.row,
          spanX: sx,
          spanY: sy,
          config: config,
        ),
      ],
    );
  }

  /// Place at an exact cell. Refuses rather than relocating.
  ///
  /// Used by starter desktops, where an authored layout that silently reflows
  /// is worse than one that reports a bad cell: the whole point of shipping a
  /// starter desktop is that it looks like the screenshot.
  static LauncherPrefs placeAt(
    LauncherPrefs p, {
    required String kindId,
    required int page,
    required int col,
    required int row,
    required int cols,
    required int rows,
    required String Function() newId,
    Map<String, Object?> config = const {},
    int? spanX,
    int? spanY,
  }) {
    final kind = DeskletKinds.byId(kindId);
    if (kind == null) return p;

    final sx = _clampSpanX(kind, spanX ?? kind.defaultSpanX, cols);
    final sy = _clampSpanY(kind, spanY ?? kind.defaultSpanY, rows);

    if (!fits(
      p,
      page: page,
      col: col,
      row: row,
      spanX: sx,
      spanY: sy,
      cols: cols,
      rows: rows,
    )) {
      return p;
    }

    return p.copyWith(
      desklets: [
        ...p.desklets,
        Desklet(
          id: newId(),
          kind: kindId,
          page: page,
          col: col,
          row: row,
          spanX: sx,
          spanY: sy,
          config: config,
        ),
      ],
    );
  }

  /// Drag to a new cell, possibly on another workspace. Refuses a collision.
  static LauncherPrefs move(
    LauncherPrefs p, {
    required String id,
    required int toPage,
    required int toCol,
    required int toRow,
    required int cols,
    required int rows,
  }) {
    final d = byId(p, id);
    if (d == null) return p;

    if (!fits(
      p,
      page: toPage,
      col: toCol,
      row: toRow,
      spanX: d.spanX,
      spanY: d.spanY,
      cols: cols,
      rows: rows,
      ignoreId: id,
    )) {
      return p;
    }

    return _replace(p, d.copyWith(page: toPage, col: toCol, row: toRow));
  }

  /// Resize from the bottom-right handle: the top-left stays put.
  ///
  /// CLAMPS RATHER THAN REFUSES, which is the opposite of [move] and is
  /// deliberate. A drag past the kind's maximum should stop growing, not snap
  /// back to where it started — a resize handle that undoes itself feels
  /// broken. A clamped size that then COLLIDES is still refused, because
  /// silently overlapping a neighbour is not a smaller failure.
  static LauncherPrefs resize(
    LauncherPrefs p, {
    required String id,
    required int spanX,
    required int spanY,
    required int cols,
    required int rows,
  }) {
    final d = byId(p, id);
    if (d == null) return p;
    final kind = DeskletKinds.byId(d.kind);
    if (kind == null) return p; // unknown kind: no limits to clamp against

    var sx = _clampSpanX(kind, spanX, cols);
    var sy = _clampSpanY(kind, spanY, rows);

    // Also bounded by the grid edge from where it currently sits.
    sx = sx.clamp(kind.minSpanX, (cols - d.col).clamp(1, cols));
    sy = sy.clamp(kind.minSpanY, (rows - d.row).clamp(1, rows));

    if (sx == d.spanX && sy == d.spanY) return p;

    if (!fits(
      p,
      page: d.page,
      col: d.col,
      row: d.row,
      spanX: sx,
      spanY: sy,
      cols: cols,
      rows: rows,
      ignoreId: id,
    )) {
      return p;
    }

    return _replace(p, d.copyWith(spanX: sx, spanY: sy));
  }

  static LauncherPrefs remove(LauncherPrefs p, String id) => p.copyWith(
        desklets: p.desklets.where((d) => d.id != id).toList(),
      );

  /// MERGES config keys rather than replacing the map.
  ///
  /// A settings sheet that writes one key must not drop the others, and it will
  /// not always know what the others are — a newer build may have written a key
  /// this one has never heard of, and replacing wholesale would erase it.
  static LauncherPrefs configure(
    LauncherPrefs p,
    String id,
    Map<String, Object?> patch,
  ) {
    final d = byId(p, id);
    if (d == null) return p;
    return _replace(p, d.copyWith(config: {...d.config, ...patch}));
  }

  /// Reorder on the PANE surface, where list order is the layout.
  ///
  /// [to] is the index AFTER removal, the ReorderableListView convention that
  /// `HomeLayout.reorderDock` already follows. Getting it wrong shifts every
  /// downward drag by one, which reads as "the list ignores me".
  ///
  /// Reorders within one page and leaves every other page's relative order
  /// alone, which is why it rebuilds from the page slice rather than sorting
  /// the whole list.
  static LauncherPrefs reorderPane(
    LauncherPrefs p,
    int page,
    int from,
    int to,
  ) {
    final slice = onPage(p, page);
    if (from < 0 || from >= slice.length) return p;

    final moved = [...slice];
    final item = moved.removeAt(from);
    moved.insert(to.clamp(0, moved.length), item);

    var i = 0;
    return p.copyWith(
      desklets: [
        for (final d in p.desklets)
          if (d.page == page) moved[i++] else d,
      ],
    );
  }

  /// The desklet grid's density relative to the icon grid.
  ///
  /// ─── WHY TWO DIFFERENT FACTORS ──────────────────────────────────────────
  ///
  /// The icon grid's cell is shaped for an app icon with a two-line label under
  /// it: on a 1080 by 2340 phone that is about 83 wide by 140 tall, an aspect
  /// of 1.7. Android widgets are authored against a launcher cell that is
  /// roughly square, so a weather strip asking for 74dp of height could not ask
  /// for less than 140 and came out nearly twice as tall as it wanted.
  ///
  /// DOUBLING BOTH AXES WOULD HAVE FIXED NOTHING. 8 by 10 has exactly the same
  /// 1.7 aspect and exactly the same problem, one step smaller. Tripling the
  /// rows is what squares the cell: 8 by 15 measures 42 by 47, and the same
  /// weather widget lands within a quarter of its natural height instead of
  /// within a factor of two.
  static const int colFactor = 2;
  static const int rowFactor = 3;

  /// The current [LauncherPrefs.deskletGridVersion]. Bump only alongside a
  /// migration below.
  static const int gridVersion = 1;

  /// Rescale every placement from the icon grid to the fine grid, ONCE.
  ///
  /// Returns [p] unchanged when the marker already says it has run, which is
  /// what makes this safe to call on every theme resolve. Without that guard a
  /// desktop would double in width and triple in height on every launch until
  /// everything clamped to the edges.
  ///
  /// Spans scale with positions. A tile that filled the width still fills it, a
  /// tile that was half as tall is still half as tall, and nobody's desktop
  /// moves. Clamping is deliberately NOT done here: `normalise` already clamps
  /// against the kind and the grid, and doing it in two places would mean two
  /// answers when they disagree.
  static LauncherPrefs migrateToFineGrid(LauncherPrefs p) {
    if ((p.deskletGridVersion ?? 0) >= gridVersion) return p;

    return p.copyWith(
      deskletGridVersion: gridVersion,
      desklets: [
        for (final d in p.desklets)
          d.copyWith(
            col: d.col * colFactor,
            row: d.row * rowFactor,
            spanX: d.spanX * colFactor,
            spanY: d.spanY * rowFactor,
          ),
      ],
    );
  }

  /// Repair structurally impossible data. NOT a prune.
  ///
  /// Two things only, and both can arrive from a hand-edited theme.json or an
  /// admin-authored starter desktop rather than from this app:
  ///   * duplicate ids, first occurrence wins (a duplicate id makes [byId],
  ///     [remove] and every edit ambiguous)
  ///   * spans outside the kind's limits or off the grid, clamped
  ///
  /// Unknown kinds are LEFT ALONE, spans and all. There is nothing to clamp
  /// against and no reason to touch them.
  ///
  /// Overlaps are deliberately not resolved. Reflowing someone's desktop on
  /// load, with no gesture behind it, is more alarming than two tiles briefly
  /// sharing a cell — and an overlap can only arise from data this app did not
  /// write.
  static LauncherPrefs normalise(
    LauncherPrefs p, {
    required int cols,
    required int rows,
  }) {
    final seen = <String>{};
    final out = <Desklet>[];

    for (final d in p.desklets) {
      if (!seen.add(d.id)) continue;

      final kind = DeskletKinds.byId(d.kind);
      if (kind == null) {
        out.add(d);
        continue;
      }

      final sx = _clampSpanX(kind, d.spanX, cols);
      final sy = _clampSpanY(kind, d.spanY, rows);
      out.add(sx == d.spanX && sy == d.spanY
          ? d
          : d.copyWith(spanX: sx, spanY: sy));
    }

    // Identity-stable when nothing changed, so this can be called on every load
    // without invalidating LauncherPrefs equality and re-churning the theme.
    return const _DeskletListEq().equals(out, p.desklets)
        ? p
        : p.copyWith(desklets: out);
  }

  // ─── INTERNAL ──────────────────────────────────────────────────────────────

  static LauncherPrefs _replace(LauncherPrefs p, Desklet next) => p.copyWith(
        desklets: [
          for (final d in p.desklets)
            if (d.id == next.id) next else d,
        ],
      );

  /// A span is bounded by the kind AND by the grid. A theme with 3 columns
  /// cannot host a 4-wide fastfetch however generous the kind's maximum is, and
  /// the grid always wins.
  static int _clampSpanX(DeskletKind k, int want, int cols) {
    final max = k.maxSpanX < cols ? k.maxSpanX : cols;
    final min = k.minSpanX < max ? k.minSpanX : max;
    return want.clamp(min, max);
  }

  static int _clampSpanY(DeskletKind k, int want, int rows) {
    final max = k.maxSpanY < rows ? k.maxSpanY : rows;
    final min = k.minSpanY < max ? k.minSpanY : max;
    return want.clamp(min, max);
  }
}

/// Local list equality, so this file does not pull in package:collection for
/// one call. Desklet already has value equality.
class _DeskletListEq {
  const _DeskletListEq();

  bool equals(List<Desklet> a, List<Desklet> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
