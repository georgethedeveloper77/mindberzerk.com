import 'package:flutter_test/flutter_test.dart';
import 'package:g_launcher/data/prefs/home_layout.dart';
import 'package:g_launcher/data/prefs/launcher_prefs.dart';

const _cap = 20; // 5 rows x 4 cols

const a = 'com.a/.Main#0';
const b = 'com.b/.Main#0';
const c = 'com.c/.Main#0';

String _fixedId() => 'folder-1';

LauncherPrefs _withAppsAt(Map<int, String> slots) => LauncherPrefs(
      homeItems: [
        for (final e in slots.entries)
          HomeItem(page: 0, index: e.key, componentKey: e.value),
      ],
    );

void main() {
  group('addToHome', () {
    test('fills the first free slot', () {
      var p = const LauncherPrefs();
      p = HomeLayout.addToHome(p, a, capacity: _cap);
      p = HomeLayout.addToHome(p, b, capacity: _cap);

      expect(HomeLayout.itemAt(p, 0, 0)?.componentKey, a);
      expect(HomeLayout.itemAt(p, 0, 1)?.componentKey, b);
    });

    test('refuses duplicates', () {
      var p = HomeLayout.addToHome(const LauncherPrefs(), a, capacity: _cap);
      p = HomeLayout.addToHome(p, a, capacity: _cap);
      expect(p.homeItems.length, 1);
    });

    test('reuses a hole left by a removal', () {
      var p = _withAppsAt({0: a, 1: b, 2: c});
      p = HomeLayout.removeFromHome(p, 0, 1);
      p = HomeLayout.addToHome(p, 'com.d/.Main#0', capacity: _cap);

      expect(HomeLayout.itemAt(p, 0, 1)?.componentKey, 'com.d/.Main#0');
    });

    test('no-ops when the page is full', () {
      var p = _withAppsAt({for (var i = 0; i < _cap; i++) i: 'com.x$i/.M#0'});
      p = HomeLayout.addToHome(p, a, capacity: _cap);
      expect(p.homeItems.length, _cap);
    });
  });

  group('move', () {
    test('moves into an empty slot', () {
      var p = _withAppsAt({0: a});
      p = HomeLayout.move(p, fromPage: 0, fromIndex: 0, toPage: 0, toIndex: 7);

      expect(HomeLayout.itemAt(p, 0, 0), isNull);
      expect(HomeLayout.itemAt(p, 0, 7)?.componentKey, a);
    });

    test('refuses to move onto an occupied slot', () {
      var p = _withAppsAt({0: a, 1: b});
      p = HomeLayout.move(p, fromPage: 0, fromIndex: 0, toPage: 0, toIndex: 1);

      // Occupied targets are mergeOrSwap's job — move must not clobber.
      expect(HomeLayout.itemAt(p, 0, 0)?.componentKey, a);
      expect(HomeLayout.itemAt(p, 0, 1)?.componentKey, b);
    });
  });

  group('mergeOrSwap', () {
    test('app onto app creates a folder in the TARGET slot', () {
      var p = _withAppsAt({0: a, 5: b});
      p = HomeLayout.mergeOrSwap(
        p,
        fromPage: 0,
        fromIndex: 0,
        toPage: 0,
        toIndex: 5,
        newFolderId: _fixedId,
      );

      expect(p.folders.single.members, [b, a],
          reason: 'target first — it was already there');

      // The folder takes the target's slot; the dragged app leaves its own.
      expect(HomeLayout.itemAt(p, 0, 5)?.folderId, 'folder-1');
      expect(HomeLayout.itemAt(p, 0, 0), isNull);
    });

    test('app onto folder joins it, and the app leaves home', () {
      var p = const LauncherPrefs(
        folders: [
          AppFolder(id: 'f', name: 'Work', members: [a, b])
        ],
        homeItems: [
          HomeItem(page: 0, index: 3, folderId: 'f'),
          HomeItem(page: 0, index: 4, componentKey: c),
        ],
      );

      p = HomeLayout.mergeOrSwap(
        p,
        fromPage: 0,
        fromIndex: 4,
        toPage: 0,
        toIndex: 3,
        newFolderId: _fixedId,
      );

      expect(p.folders.single.members, [a, b, c]);
      expect(HomeLayout.itemAt(p, 0, 4), isNull);
      expect(p.folders.length, 1, reason: 'no new folder');
    });

    test('folder onto app is refused — no nested folders', () {
      const before = LauncherPrefs(
        folders: [
          AppFolder(id: 'f', name: 'Work', members: [a, b])
        ],
        homeItems: [
          HomeItem(page: 0, index: 0, folderId: 'f'),
          HomeItem(page: 0, index: 1, componentKey: c),
        ],
      );

      final after = HomeLayout.mergeOrSwap(
        before,
        fromPage: 0,
        fromIndex: 0,
        toPage: 0,
        toIndex: 1,
        newFolderId: _fixedId,
      );

      expect(after.folders.length, 1);
      expect(after.homeItems.length, 2, reason: 'nothing moved, nothing lost');
    });

    test('an app already in the folder is not added twice', () {
      var p = const LauncherPrefs(
        folders: [
          AppFolder(id: 'f', name: 'Work', members: [a])
        ],
        homeItems: [
          HomeItem(page: 0, index: 0, folderId: 'f'),
          HomeItem(page: 0, index: 1, componentKey: a),
        ],
      );

      p = HomeLayout.mergeOrSwap(
        p,
        fromPage: 0,
        fromIndex: 1,
        toPage: 0,
        toIndex: 0,
        newFolderId: _fixedId,
      );

      expect(p.folders.single.members, [a]);
    });
  });

  group('removeFromFolder', () {
    test('keeps the folder while 2+ members remain', () {
      var p = const LauncherPrefs(
        folders: [
          AppFolder(id: 'f', name: 'W', members: [a, b, c])
        ],
        homeItems: [HomeItem(page: 0, index: 2, folderId: 'f')],
      );

      p = HomeLayout.removeFromFolder(p, 'f', c, capacity: _cap);

      expect(p.folders.single.members, [a, b]);
      expect(HomeLayout.itemAt(p, 0, 2)?.folderId, 'f');
    });

    test('dissolves at one member — the survivor inherits the slot', () {
      var p = const LauncherPrefs(
        folders: [
          AppFolder(id: 'f', name: 'W', members: [a, b])
        ],
        homeItems: [HomeItem(page: 0, index: 2, folderId: 'f')],
      );

      p = HomeLayout.removeFromFolder(p, 'f', b, capacity: _cap);

      // A one-app folder is pointless UI. The survivor must NOT vanish.
      expect(p.folders, isEmpty);
      expect(HomeLayout.itemAt(p, 0, 2)?.componentKey, a);
    });
  });

  group('prune', () {
    test('drops uninstalled apps from home, folders and favourites', () {
      var p = const LauncherPrefs(
        favourites: [a, b],
        folders: [
          AppFolder(id: 'f', name: 'W', members: [a, b, c])
        ],
        homeItems: [
          HomeItem(page: 0, index: 0, componentKey: a),
          HomeItem(page: 0, index: 1, componentKey: b),
          HomeItem(page: 0, index: 2, folderId: 'f'),
        ],
      );

      // b was uninstalled.
      p = HomeLayout.prune(p, {a, c});

      expect(p.favourites, [a]);
      expect(p.folders.single.members, [a, c]);
      expect(p.homeItems.any((i) => i.componentKey == b), isFalse);
    });

    test('a folder gutted below 2 members disappears', () {
      var p = const LauncherPrefs(
        folders: [
          AppFolder(id: 'f', name: 'W', members: [a, b])
        ],
        homeItems: [HomeItem(page: 0, index: 0, folderId: 'f')],
      );

      p = HomeLayout.prune(p, {a});

      // A ghost folder that outlives its apps is worse than no folder.
      expect(p.folders, isEmpty);
      expect(p.homeItems, isEmpty);
    });
  });
}
