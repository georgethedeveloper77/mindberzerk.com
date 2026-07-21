import 'package:flutter_test/flutter_test.dart';
import 'package:g_launcher/data/prefs/desklet_layout.dart';
import 'package:g_launcher/data/prefs/launcher_prefs.dart';
import 'package:g_launcher/engine/desklet_spec.dart';

/// PHASE D2. The engine is pure, so all of this runs without a phone — which is
/// the entire reason it is pure. Rectangle packing is where "it landed on top of
/// my monitor" bugs live, and those are miserable to find on a device.

/// A 5-wide, 4-tall desktop grid, roughly what a theme actually ships.
const cols = 5;
const rows = 4;

int _n = 0;
String _id() => 'd${_n++}';

LauncherPrefs _empty() {
  _n = 0;
  return const LauncherPrefs();
}

LauncherPrefs _with(List<Desklet> ds) => LauncherPrefs(desklets: ds);

Desklet _d(
  String id,
  String kind, {
  int page = 0,
  int col = 0,
  int row = 0,
  int spanX = 1,
  int spanY = 1,
  Map<String, Object?> config = const {},
}) =>
    Desklet(
      id: id,
      kind: kind,
      page: page,
      col: col,
      row: row,
      spanX: spanX,
      spanY: spanY,
      config: config,
    );

void main() {
  group('Desklet geometry', () {
    test('right and bottom are half-open', () {
      final d = _d('a', 'clock', col: 2, row: 1, spanX: 2, spanY: 3);
      expect(d.right, 4);
      expect(d.bottom, 4);
    });

    test('touching edges do not overlap', () {
      final a = _d('a', 'clock', col: 0, row: 0, spanX: 2, spanY: 1);
      final b = _d('b', 'clock', col: 2, row: 0, spanX: 2, spanY: 1);
      expect(a.overlaps(b), isFalse);
      expect(b.overlaps(a), isFalse);
    });

    test('one shared cell is an overlap', () {
      final a = _d('a', 'clock', col: 0, row: 0, spanX: 2, spanY: 2);
      final b = _d('b', 'clock', col: 1, row: 1, spanX: 2, spanY: 2);
      expect(a.overlaps(b), isTrue);
    });

    test('same rectangle on a different page never overlaps', () {
      final a = _d('a', 'clock', page: 0, spanX: 2, spanY: 2);
      final b = _d('b', 'clock', page: 1, spanX: 2, spanY: 2);
      expect(a.overlaps(b), isFalse);
    });
  });

  group('place', () {
    test('lands at the origin on an empty page with the kind default span', () {
      final p = DeskletLayout.place(
        _empty(),
        kindId: 'clock',
        page: 0,
        cols: cols,
        rows: rows,
        newId: _id,
      );
      expect(p.desklets, hasLength(1));
      final d = p.desklets.single;
      expect(d.col, 0);
      expect(d.row, 0);
      expect(d.spanX, DeskletKinds.clock.defaultSpanX);
      expect(d.spanY, DeskletKinds.clock.defaultSpanY);
    });

    test('fills row-major, not column-major', () {
      var p = _empty();
      // Three 2x1 clocks on a 5-wide grid: two fit on row 0, the third wraps.
      for (var i = 0; i < 3; i++) {
        p = DeskletLayout.place(
          p,
          kindId: 'clock',
          page: 0,
          cols: cols,
          rows: rows,
          newId: _id,
        );
      }
      expect(p.desklets[0].row, 0);
      expect(p.desklets[1].row, 0);
      expect(p.desklets[1].col, 2);
      expect(p.desklets[2].row, 1, reason: 'third clock must wrap to row 1');
      expect(p.desklets[2].col, 0);
    });

    test('an unknown kind is refused, not stored', () {
      final p = DeskletLayout.place(
        _empty(),
        kindId: 'nope',
        page: 0,
        cols: cols,
        rows: rows,
        newId: _id,
      );
      expect(p.desklets, isEmpty);
    });

    test('a full page returns prefs unchanged by identity', () {
      // One monitor is 2x3 at minimum; fill the grid with 1x1 notes instead.
      var p = _empty();
      for (var r = 0; r < rows; r++) {
        for (var c = 0; c < cols; c++) {
          p = DeskletLayout.placeAt(
            p,
            kindId: 'notes',
            page: 0,
            col: c,
            row: r,
            cols: cols,
            rows: rows,
            newId: _id,
            spanX: 1,
            spanY: 1,
          );
        }
      }
      expect(p.desklets, hasLength(cols * rows));

      final after = DeskletLayout.place(
        p,
        kindId: 'notes',
        page: 0,
        cols: cols,
        rows: rows,
        newId: _id,
      );
      expect(identical(after, p), isTrue,
          reason: 'refusal must be identity-stable so callers can detect it');
    });

    test('a full page 0 does not block page 1', () {
      var p = _empty();
      for (var r = 0; r < rows; r++) {
        for (var c = 0; c < cols; c++) {
          p = DeskletLayout.placeAt(
            p,
            kindId: 'notes',
            page: 0,
            col: c,
            row: r,
            cols: cols,
            rows: rows,
            newId: _id,
            spanX: 1,
            spanY: 1,
          );
        }
      }
      final after = DeskletLayout.place(
        p,
        kindId: 'clock',
        page: 1,
        cols: cols,
        rows: rows,
        newId: _id,
      );
      expect(DeskletLayout.onPage(after, 1), hasLength(1));
    });

    test('requested span is clamped to the kind maximum', () {
      final p = DeskletLayout.place(
        _empty(),
        kindId: 'clock',
        page: 0,
        cols: cols,
        rows: rows,
        newId: _id,
        spanX: 99,
        spanY: 99,
      );
      final d = p.desklets.single;
      expect(d.spanX, DeskletKinds.clock.maxSpanX);
      expect(d.spanY, DeskletKinds.clock.maxSpanY);
    });

    test('span is clamped to the GRID even when the kind allows more', () {
      // notes allows 5x5; a 3-column grid must still cap at 3.
      final p = DeskletLayout.place(
        _empty(),
        kindId: 'notes',
        page: 0,
        cols: 3,
        rows: 2,
        newId: _id,
        spanX: 5,
        spanY: 5,
      );
      final d = p.desklets.single;
      expect(d.spanX, 3);
      expect(d.spanY, 2);
    });

    test('a kind whose minimum exceeds the grid still fits inside it', () {
      // fastfetch has minSpanX 3; a 2-column grid cannot honour that, and the
      // grid must win rather than the desklet hanging off the edge.
      final p = DeskletLayout.place(
        _empty(),
        kindId: 'fastfetch',
        page: 0,
        cols: 2,
        rows: 2,
        newId: _id,
      );
      final d = p.desklets.single;
      expect(d.spanX, lessThanOrEqualTo(2));
      expect(d.col + d.spanX, lessThanOrEqualTo(2));
    });
  });

  group('placeAt', () {
    test('refuses a collision rather than relocating', () {
      final p = _with([_d('a', 'clock', col: 0, row: 0, spanX: 2, spanY: 1)]);
      final after = DeskletLayout.placeAt(
        p,
        kindId: 'clock',
        page: 0,
        col: 1,
        row: 0,
        cols: cols,
        rows: rows,
        newId: _id,
      );
      expect(identical(after, p), isTrue);
    });

    test('refuses a rectangle that runs off the grid', () {
      final after = DeskletLayout.placeAt(
        _empty(),
        kindId: 'clock',
        page: 0,
        col: 4,
        row: 0,
        cols: cols,
        rows: rows,
        newId: _id,
        spanX: 2,
        spanY: 1,
      );
      expect(after.desklets, isEmpty);
    });
  });

  group('move', () {
    test('moves to a free cell', () {
      final p = _with([_d('a', 'clock', col: 0, row: 0, spanX: 2, spanY: 1)]);
      final after = DeskletLayout.move(
        p,
        id: 'a',
        toPage: 0,
        toCol: 3,
        toRow: 2,
        cols: cols,
        rows: rows,
      );
      final d = DeskletLayout.byId(after, 'a')!;
      expect(d.col, 3);
      expect(d.row, 2);
    });

    test('a one-cell nudge is allowed to overlap its own old position', () {
      // The self-exclusion bug: without ignoreId nothing can ever be nudged,
      // because the tile collides with where it currently is.
      final p = _with([_d('a', 'clock', col: 0, row: 0, spanX: 2, spanY: 1)]);
      final after = DeskletLayout.move(
        p,
        id: 'a',
        toPage: 0,
        toCol: 1,
        toRow: 0,
        cols: cols,
        rows: rows,
      );
      expect(DeskletLayout.byId(after, 'a')!.col, 1);
    });

    test('refuses a collision with another desklet', () {
      final p = _with([
        _d('a', 'clock', col: 0, row: 0, spanX: 2, spanY: 1),
        _d('b', 'clock', col: 3, row: 0, spanX: 2, spanY: 1),
      ]);
      final after = DeskletLayout.move(
        p,
        id: 'a',
        toPage: 0,
        toCol: 2,
        toRow: 0,
        cols: cols,
        rows: rows,
      );
      expect(identical(after, p), isTrue);
    });

    test('moves across workspaces', () {
      final p = _with([_d('a', 'clock', page: 0, spanX: 2)]);
      final after = DeskletLayout.move(
        p,
        id: 'a',
        toPage: 2,
        toCol: 0,
        toRow: 0,
        cols: cols,
        rows: rows,
      );
      expect(DeskletLayout.onPage(after, 0), isEmpty);
      expect(DeskletLayout.onPage(after, 2), hasLength(1));
    });

    test('a same-cell occupant on ANOTHER page is not a collision', () {
      final p = _with([
        _d('a', 'clock', page: 0, col: 0, row: 0, spanX: 2),
        _d('b', 'clock', page: 1, col: 0, row: 0, spanX: 2),
      ]);
      final after = DeskletLayout.move(
        p,
        id: 'a',
        toPage: 0,
        toCol: 2,
        toRow: 0,
        cols: cols,
        rows: rows,
      );
      expect(DeskletLayout.byId(after, 'a')!.col, 2);
    });

    test('an unknown id is a no-op', () {
      final p = _with([_d('a', 'clock')]);
      expect(
        identical(
          DeskletLayout.move(
            p,
            id: 'zzz',
            toPage: 0,
            toCol: 1,
            toRow: 1,
            cols: cols,
            rows: rows,
          ),
          p,
        ),
        isTrue,
      );
    });
  });

  group('resize', () {
    test('grows from the top-left, which stays put', () {
      final p = _with([_d('a', 'notes', col: 1, row: 1, spanX: 1, spanY: 1)]);
      final after = DeskletLayout.resize(
        p,
        id: 'a',
        spanX: 3,
        spanY: 2,
        cols: cols,
        rows: rows,
      );
      final d = DeskletLayout.byId(after, 'a')!;
      expect(d.col, 1);
      expect(d.row, 1);
      expect(d.spanX, 3);
      expect(d.spanY, 2);
    });

    test('clamps past the maximum instead of refusing', () {
      // A resize handle that snaps back to the start feels broken; it should
      // stop growing. This is the deliberate difference from move().
      final p = _with([_d('a', 'clock', spanX: 2, spanY: 1)]);
      final after = DeskletLayout.resize(
        p,
        id: 'a',
        spanX: 99,
        spanY: 99,
        cols: cols,
        rows: rows,
      );
      final d = DeskletLayout.byId(after, 'a')!;
      expect(d.spanX, DeskletKinds.clock.maxSpanX);
      expect(d.spanY, DeskletKinds.clock.maxSpanY);
    });

    test('clamps to the grid edge from where it sits', () {
      final p = _with([_d('a', 'notes', col: 3, row: 0, spanX: 1, spanY: 1)]);
      final after = DeskletLayout.resize(
        p,
        id: 'a',
        spanX: 5,
        spanY: 1,
        cols: cols,
        rows: rows,
      );
      final d = DeskletLayout.byId(after, 'a')!;
      expect(d.col + d.spanX, lessThanOrEqualTo(cols));
    });

    test('will not shrink below the kind minimum', () {
      final p = _with([_d('a', 'monitor', spanX: 2, spanY: 3)]);
      final after = DeskletLayout.resize(
        p,
        id: 'a',
        spanX: 1,
        spanY: 1,
        cols: cols,
        rows: rows,
      );
      final d = DeskletLayout.byId(after, 'a')!;
      expect(d.spanX, DeskletKinds.monitor.minSpanX);
      expect(d.spanY, DeskletKinds.monitor.minSpanY);
    });

    test('a clamped size that still collides is refused', () {
      final p = _with([
        _d('a', 'notes', col: 0, row: 0, spanX: 1, spanY: 1),
        _d('b', 'notes', col: 1, row: 0, spanX: 1, spanY: 1),
      ]);
      final after = DeskletLayout.resize(
        p,
        id: 'a',
        spanX: 2,
        spanY: 1,
        cols: cols,
        rows: rows,
      );
      expect(identical(after, p), isTrue);
    });

    test('a no-op resize is identity-stable', () {
      final p = _with([_d('a', 'clock', spanX: 2, spanY: 1)]);
      expect(
        identical(
          DeskletLayout.resize(
            p,
            id: 'a',
            spanX: 2,
            spanY: 1,
            cols: cols,
            rows: rows,
          ),
          p,
        ),
        isTrue,
      );
    });
  });

  group('remove and configure', () {
    test('remove takes exactly one', () {
      final p = _with([_d('a', 'clock'), _d('b', 'clock', col: 2)]);
      final after = DeskletLayout.remove(p, 'a');
      expect(after.desklets, hasLength(1));
      expect(after.desklets.single.id, 'b');
    });

    test('configure MERGES and does not drop unknown keys', () {
      // The key case: a newer build wrote a key this one has never heard of,
      // and a settings sheet writing `format` must not erase it.
      final p = _with([
        _d('a', 'clock', config: const {'format': '24h', 'fromFuture': 7}),
      ]);
      final after = DeskletLayout.configure(p, 'a', {'format': '12h'});
      final c = DeskletLayout.byId(after, 'a')!.config;
      expect(c['format'], '12h');
      expect(c['fromFuture'], 7);
    });
  });

  group('renderable', () {
    test('hides an unknown kind but never deletes it', () {
      final p = _with([_d('a', 'clock'), _d('b', 'from-a-future-pack')]);
      expect(DeskletLayout.renderable(p, 0), hasLength(1));
      expect(p.desklets, hasLength(2),
          reason: 'storage must be untouched: the pack may install later');
    });

    test('pane-only kinds are hidden on a grid surface and shown on a pane', () {
      final p = _with([_d('a', 'clock'), _d('b', 'free')]);
      expect(DeskletLayout.renderable(p, 0).map((d) => d.id), ['a']);
      expect(
        DeskletLayout.renderable(p, 0, pane: true).map((d) => d.id),
        ['a', 'b'],
      );
    });

    test('only the requested page', () {
      final p = _with([_d('a', 'clock', page: 0), _d('b', 'clock', page: 1)]);
      expect(DeskletLayout.renderable(p, 1).single.id, 'b');
    });
  });

  group('reorderPane', () {
    test('reorders within a page using the after-removal index', () {
      final p = _with([
        _d('a', 'free', page: 0),
        _d('b', 'df', page: 0),
        _d('c', 'free', page: 0),
      ]);
      final after = DeskletLayout.reorderPane(p, 0, 0, 2);
      expect(DeskletLayout.onPage(after, 0).map((d) => d.id), ['b', 'c', 'a']);
    });

    test('leaves other pages untouched and in place', () {
      final p = _with([
        _d('a', 'free', page: 0),
        _d('x', 'free', page: 1),
        _d('b', 'df', page: 0),
      ]);
      final after = DeskletLayout.reorderPane(p, 0, 0, 1);
      expect(after.desklets.map((d) => d.id), ['b', 'x', 'a']);
      expect(DeskletLayout.onPage(after, 1).single.id, 'x');
    });
  });

  group('normalise', () {
    test('drops duplicate ids, first wins', () {
      final p = _with([
        _d('a', 'clock', col: 0),
        _d('a', 'clock', col: 3),
      ]);
      final after = DeskletLayout.normalise(p, cols: cols, rows: rows);
      expect(after.desklets, hasLength(1));
      expect(after.desklets.single.col, 0);
    });

    test('clamps an out-of-range span from hand-authored data', () {
      final p = _with([_d('a', 'clock', spanX: 40, spanY: 40)]);
      final after = DeskletLayout.normalise(p, cols: cols, rows: rows);
      expect(after.desklets.single.spanX, DeskletKinds.clock.maxSpanX);
    });

    test('leaves unknown kinds completely alone', () {
      final p = _with([_d('a', 'future-kind', spanX: 40, spanY: 40)]);
      final after = DeskletLayout.normalise(p, cols: cols, rows: rows);
      expect(after.desklets.single.spanX, 40);
    });

    test('is identity-stable when there is nothing to repair', () {
      final p = _with([_d('a', 'clock', spanX: 2, spanY: 1)]);
      expect(
        identical(DeskletLayout.normalise(p, cols: cols, rows: rows), p),
        isTrue,
        reason: 'called on every load; must not churn LauncherPrefs equality',
      );
    });
  });

  group('persistence', () {
    test('a desklet round-trips through JSON', () {
      final d = _d(
        'a',
        'clock',
        page: 2,
        col: 1,
        row: 3,
        spanX: 2,
        spanY: 1,
        config: const {'format': '12h', 'showSeconds': true},
      );
      expect(Desklet.fromJson(d.toJson()), d);
    });

    test('empty config is omitted from JSON but round-trips', () {
      final d = _d('a', 'clock');
      expect(d.toJson().containsKey('config'), isFalse);
      expect(Desklet.fromJson(d.toJson()), d);
    });

    test('a missing span reads as 1 rather than throwing', () {
      final d = Desklet.fromJson(const {'id': 'a', 'kind': 'clock'});
      expect(d.spanX, 1);
      expect(d.spanY, 1);
      expect(d.page, 0);
    });

    test('desklets survive a LauncherPrefs round trip', () {
      final p = _with([_d('a', 'clock', page: 1, spanX: 2)]);
      expect(LauncherPrefs.fromJson(p.toJson()), p);
    });

    test('prefs written before D2 parse as no desklets', () {
      final old = const LauncherPrefs(cols: 4).toJson()..remove('desklets');
      expect(LauncherPrefs.fromJson(old).desklets, isEmpty);
    });

    test('an unknown kind survives a full prefs round trip', () {
      // The forward-compatibility promise, end to end: an APK that has never
      // heard of this kind must hand it back unchanged after an update.
      final p = _with([_d('a', 'kind-from-2027', config: const {'x': 1})]);
      final back = LauncherPrefs.fromJson(p.toJson());
      expect(back.desklets.single.kind, 'kind-from-2027');
      expect(back.desklets.single.config['x'], 1);
    });
  });

  group('LauncherPrefs equality', () {
    test('desklets participate in ==', () {
      expect(_with([_d('a', 'clock')]) == _with([_d('a', 'clock')]), isTrue);
      expect(
        _with([_d('a', 'clock')]) == _with([_d('a', 'clock', col: 1)]),
        isFalse,
      );
    });

    test('folderOrderCustom now participates in hashCode too', () {
      // Regression: it was in operator== but missing from hashCode, so these
      // two compared unequal yet hashed identically.
      const a = LauncherPrefs(folderOrderCustom: true);
      const b = LauncherPrefs(folderOrderCustom: false);
      expect(a == b, isFalse);
      expect(a.hashCode == b.hashCode, isFalse);
    });

    test('clearing() no longer drops drawerScrollStyle', () {
      // Regression: the field was absent from clearing()'s constructor call, so
      // clearing ANY setting silently reset the drawer scroll style.
      const p = LauncherPrefs(drawerScrollStyle: 'cube', cols: 5);
      expect(p.clearing(cols: true).drawerScrollStyle, 'cube');
    });
  });

  group('DeskletKinds', () {
    test('byId is null for an unknown id, which is not an error', () {
      expect(DeskletKinds.byId('clock'), isNotNull);
      expect(DeskletKinds.byId('nope'), isNull);
    });

    test('resolveOffers drops unknown ids from the PICKER only', () {
      final offers = DeskletKinds.resolveOffers(['clock', 'nope', 'monitor']);
      expect(offers.map((k) => k.id), ['clock', 'monitor']);
    });

    test('read falls back on a missing key and on a wrong type', () {
      const k = DeskletKinds.clock;
      expect(k.read<String>(const {}, 'format', '24h'), '24h');
      expect(k.read<String>(const {'format': '12h'}, 'format', '24h'), '12h');
      expect(k.read<String>(const {'format': 7}, 'format', '24h'), '24h');
    });

    test('every kind id is unique and every default span is within its limits',
        () {
      final ids = DeskletKinds.all.map((k) => k.id).toList();
      expect(ids.toSet().length, ids.length);

      for (final k in DeskletKinds.all) {
        expect(k.minSpanX, lessThanOrEqualTo(k.maxSpanX), reason: k.id);
        expect(k.minSpanY, lessThanOrEqualTo(k.maxSpanY), reason: k.id);
        expect(k.defaultSpanX, inInclusiveRange(k.minSpanX, k.maxSpanX),
            reason: k.id);
        expect(k.defaultSpanY, inInclusiveRange(k.minSpanY, k.maxSpanY),
            reason: k.id);
      }
    });
  });
}
