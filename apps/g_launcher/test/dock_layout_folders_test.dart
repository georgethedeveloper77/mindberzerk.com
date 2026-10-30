import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:g_launcher/data/prefs/home_layout.dart';
import 'package:g_launcher/data/prefs/launcher_prefs.dart';
import 'package:g_launcher/engine/splash_spec.dart';
import 'package:g_launcher/engine/theme_spec.dart';

/// Build 42: the Pocket dock. Positioned pins, dock folders, the role seed,
/// and the three layout fields that switch them on.
const a = 'com.a/.Main#0';
const b = 'com.b/.Main#0';
const c = 'com.c/.Main#0';
const d = 'com.d/.Main#0';
const e = 'com.e/.Main#0';

String _id() => 'f1';

LauncherPrefs _dock(List<String> keys) => LauncherPrefs(favourites: keys);

void main() {
  group('dock folder keys', () {
    test('round trip, and a component key is never a folder', () {
      final k = HomeLayout.dockFolderKey('f9');
      expect(k, 'folder:f9');
      expect(HomeLayout.dockFolderIdOf(k), 'f9');
      expect(HomeLayout.dockFolderIdOf(a), isNull);
    });
  });

  group('pinToDockAt', () {
    test('inserts before a key', () {
      final p = HomeLayout.pinToDockAt(_dock([a, b]), c,
          beforeKey: b, capacity: 4);
      expect(p.favourites, [a, c, b]);
    });

    test('inserts after a key when there is nothing before', () {
      final p = HomeLayout.pinToDockAt(_dock([a, b]), c,
          afterKey: b, capacity: 4);
      expect(p.favourites, [a, b, c]);
    });

    test('a pinned key MOVES and never counts against capacity', () {
      final full = _dock([a, b, c, d]);
      final p = HomeLayout.pinToDockAt(full, a, afterKey: d, capacity: 4);
      expect(p.favourites, [b, c, d, a]);
    });

    test('a new arrival on a full dock is refused by identity', () {
      final full = _dock([a, b, c, d]);
      expect(
        identical(HomeLayout.pinToDockAt(full, e, capacity: 4), full),
        isTrue,
      );
    });
  });

  group('adoptDock', () {
    test('an auto-filled dock becomes the pins it showed', () {
      final p = HomeLayout.adoptDock(const LauncherPrefs(), [a, b]);
      expect(p.favourites, [a, b]);
    });

    test('a pinned dock is left alone', () {
      final pinned = _dock([c]);
      expect(identical(HomeLayout.adoptDock(pinned, [a, b]), pinned), isTrue);
    });
  });

  group('dockFolder', () {
    test('app onto app: a folder takes the target slot', () {
      final p = HomeLayout.dockFolder(
        _dock([a, b, c]),
        ontoKey: b,
        dropKey: c,
        newFolderId: _id,
      );
      expect(p.favourites, [a, 'folder:f1']);
      expect(HomeLayout.folder(p, 'f1')!.members, [b, c]);
    });

    test('app from the grid onto a dock folder joins it and leaves the grid',
        () {
      const start = LauncherPrefs(
        favourites: [a, 'folder:f1'],
        folders: [
          AppFolder(id: 'f1', name: 'Folder', members: [b, c]),
        ],
        homeItems: [HomeItem(page: 0, index: 3, componentKey: d)],
      );
      final p = HomeLayout.dockFolder(
        start,
        ontoKey: 'folder:f1',
        dropKey: d,
        newFolderId: _id,
      );
      expect(HomeLayout.folder(p, 'f1')!.members, [b, c, d]);
      expect(p.homeItems, isEmpty);
      expect(p.favourites, [a, 'folder:f1']);
    });

    test('no folders inside folders, and no target outside the dock', () {
      final start = _dock([a, b]);
      expect(
        identical(
          HomeLayout.dockFolder(start,
              ontoKey: a, dropKey: 'folder:f1', newFolderId: _id),
          start,
        ),
        isTrue,
      );
      expect(
        identical(
          HomeLayout.dockFolder(start,
              ontoKey: c, dropKey: a, newFolderId: _id),
          start,
        ),
        isTrue,
      );
    });
  });

  group('dock folders and the folder rules', () {
    LauncherPrefs withFolder(List<String> members) => LauncherPrefs(
          favourites: const [a, 'folder:f1'],
          folders: [AppFolder(id: 'f1', name: 'Folder', members: members)],
        );

    test('taking the second-to-last app out leaves the survivor in the dock',
        () {
      final p = HomeLayout.removeFromFolder(withFolder([b, c]), 'f1', c,
          capacity: 20);
      expect(p.favourites, [a, b]);
      expect(p.folders, isEmpty);
      expect(p.homeItems, isEmpty);
    });

    test('ungrouping a dock folder sends its apps to the grid', () {
      final p = HomeLayout.dissolve(withFolder([b, c]), 'f1', capacity: 20);
      expect(p.favourites, [a]);
      expect(p.homeItems.map((i) => i.componentKey), containsAll([b, c]));
    });

    test('prune keeps a live dock folder and unwraps a one-app one', () {
      final live = HomeLayout.prune(withFolder([b, c]), {a, b, c});
      expect(live.favourites, [a, 'folder:f1']);

      final one = HomeLayout.prune(withFolder([b, c]), {a, b});
      expect(one.favourites, [a, b]);
      expect(one.folders, isEmpty);
    });

    test('a dock folder moves to the grid and leaves the dock', () {
      final p = HomeLayout.placeFolderAt(withFolder([b, c]), 'f1',
          page: 0, index: 2, capacity: 20, cols: 4);
      expect(p.favourites, [a]);
      expect(p.homeItems.single.folderId, 'f1');
      expect(p.homeItems.single.index, 2);
    });

    test('takeOffHome removes a folder tile by id', () {
      final p = HomeLayout.takeOffHome(
        const LauncherPrefs(
          homeItems: [HomeItem(page: 0, index: 0, folderId: 'f1')],
        ),
        'folder:f1',
      );
      expect(p.homeItems, isEmpty);
    });
  });

  group('seedDock', () {
    test('pins one app per resolved role, in order, once', () {
      final p = HomeLayout.seedDock(
        const LauncherPrefs(),
        packages: const ['com.a', null, 'com.b', 'com.a'],
        keyByPackage: const {'com.a': a, 'com.b': b},
        capacity: 4,
      );
      expect(p.favourites, [a, b]);
      expect(p.dockInitialized, isTrue);
      expect(identical(HomeLayout.seedDock(p, packages: const ['com.c'],
              keyByPackage: const {'com.c': c}, capacity: 4), p), isTrue);
    });

    test('an arranged dock is marked done and left alone', () {
      final p = HomeLayout.seedDock(
        _dock([c]),
        packages: const ['com.a'],
        keyByPackage: const {'com.a': a},
        capacity: 4,
      );
      expect(p.favourites, [c]);
      expect(p.dockInitialized, isTrue);
    });

    test('the flag survives a JSON round trip', () {
      final p = const LauncherPrefs().copyWith(dockInitialized: true);
      final json = jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>;
      expect(LauncherPrefs.fromJson(json).dockInitialized, isTrue);
    });
  });

  group('layout fields', () {
    test('parse, clamp and drop strangers', () {
      final on = ThemeLayout.fromJson(const {
        'dockCapacity': 40,
        'dockSeed': ['dialer', 'fax', 'camera'],
        'dockFolders': true,
      });
      expect(on.dockCapacity, 8);
      expect(on.dockSeed, ['dialer', 'camera']);
      expect(on.dockFolders, isTrue);

      final off = ThemeLayout.fromJson(const {});
      expect(off.dockCapacity, isNull);
      expect(off.dockSeed, isEmpty);
      expect(off.dockFolders, isFalse);
    });
  });

  group('hello splash', () {
    test('parses, and an older style list still degrades', () {
      expect(SplashStyle.parse('hello'), SplashStyle.hello);
      expect(SplashStyle.parse('later'), SplashStyle.spinner);
    });

    test('helloShown survives a JSON round trip', () {
      final p = const LauncherPrefs().copyWith(helloShown: true);
      final json = jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>;
      expect(LauncherPrefs.fromJson(json).helloShown, isTrue);
    });
  });
}
