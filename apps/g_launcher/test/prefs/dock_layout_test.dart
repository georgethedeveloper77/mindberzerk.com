import 'package:flutter_test/flutter_test.dart';
import 'package:g_launcher/data/prefs/home_layout.dart';
import 'package:g_launcher/data/prefs/launcher_prefs.dart';

void main() {
  group('pin / unpin', () {
    test('pin appends in order', () {
      var p = const LauncherPrefs();
      p = HomeLayout.pinToDock(p, 'a', capacity: 5);
      p = HomeLayout.pinToDock(p, 'b', capacity: 5);
      expect(p.favourites, ['a', 'b']);
    });

    test('duplicate pin is refused, identically', () {
      var p = const LauncherPrefs(favourites: ['a']);
      final after = HomeLayout.pinToDock(p, 'a', capacity: 5);
      expect(identical(p, after), isTrue);
    });

    test('pin over capacity is refused, identically — caller can detect and say "full"',
        () {
      const p = LauncherPrefs(favourites: ['a', 'b', 'c']);
      final after = HomeLayout.pinToDock(p, 'd', capacity: 3);
      expect(identical(p, after), isTrue);
    });

    test('unpin removes only the target', () {
      var p = const LauncherPrefs(favourites: ['a', 'b', 'c']);
      p = HomeLayout.unpinFromDock(p, 'b');
      expect(p.favourites, ['a', 'c']);
    });
  });

  group('reorder', () {
    test('moves with after-removal semantics (ReorderableListView convention)',
        () {
      var p = const LauncherPrefs(favourites: ['a', 'b', 'c', 'd']);
      // Drag 'a' (0) to after 'c': onReorder gives to=3 pre-removal, callers
      // pass newIndex>oldIndex ? newIndex-1 : newIndex → 2 here.
      p = HomeLayout.reorderDock(p, 0, 2);
      expect(p.favourites, ['b', 'c', 'a', 'd']);
    });

    test('out-of-range from is a no-op, not a crash', () {
      const p = LauncherPrefs(favourites: ['a']);
      expect(identical(HomeLayout.reorderDock(p, 5, 0), p), isTrue);
      expect(identical(HomeLayout.reorderDock(p, -1, 0), p), isTrue);
    });

    test('to is clamped', () {
      var p = const LauncherPrefs(favourites: ['a', 'b']);
      p = HomeLayout.reorderDock(p, 0, 99);
      expect(p.favourites, ['b', 'a']);
    });
  });

  group('dockKeys — the pins-or-frequent contract', () {
    const frequent = ['f1', 'f2', 'f3', 'f4'];

    test('nothing pinned → frequent apps', () {
      const p = LauncherPrefs();
      expect(
        HomeLayout.dockKeys(p, frequent: frequent, capacity: 3),
        ['f1', 'f2', 'f3'],
      );
    });

    test('ANYTHING pinned → pins only. No frequent padding — no haunted dock.',
        () {
      const p = LauncherPrefs(favourites: ['mine']);
      expect(
        HomeLayout.dockKeys(p, frequent: frequent, capacity: 3),
        ['mine'],
      );
    });

    test('unpinning the last app returns to frequent, so the dock is never empty',
        () {
      var p = const LauncherPrefs(favourites: ['mine']);
      p = HomeLayout.unpinFromDock(p, 'mine');
      expect(
        HomeLayout.dockKeys(p, frequent: frequent, capacity: 2),
        ['f1', 'f2'],
      );
    });

    test('pins beyond capacity are truncated for display, not lost', () {
      const p = LauncherPrefs(favourites: ['a', 'b', 'c', 'd', 'e']);
      expect(
        HomeLayout.dockKeys(p, frequent: frequent, capacity: 3),
        ['a', 'b', 'c'],
      );
      // The data survives — move the dock to the left (higher capacity) and
      // d, e appear.
      expect(p.favourites.length, 5);
    });
  });

  group('serialisation', () {
    test('dockGridButton round-trips and its absence parses', () {
      const p = LauncherPrefs(dockGridButton: 'start');
      final back = LauncherPrefs.fromJson(p.toJson());
      expect(back.dockGridButton, 'start');

      // Old prefs file without the field: additive change, no schema bump.
      final old = LauncherPrefs.fromJson(const {'schemaVersion': 1});
      expect(old.dockGridButton, isNull);
    });

    test('clearing(dockGridButton: true) resets to theme default', () {
      const p = LauncherPrefs(dockGridButton: 'start');
      expect(p.clearing(dockGridButton: true).dockGridButton, isNull);
    });

    test('prune cleans favourites of uninstalled apps (pre-existing behaviour, still true)',
        () {
      const p = LauncherPrefs(favourites: ['live', 'dead']);
      final pruned = HomeLayout.prune(p, {'live'});
      expect(pruned.favourites, ['live']);
    });
  });
}
