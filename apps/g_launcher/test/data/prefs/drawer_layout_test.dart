import 'package:flutter_test/flutter_test.dart';
import 'package:g_launcher/data/prefs/drawer_layout.dart';
import 'package:g_launcher/data/prefs/launcher_prefs.dart';

void main() {
  // Deterministic ids so expectations can name them.
  var counter = 0;
  String nextId() => 'df${counter++}';

  setUp(() => counter = 0);

  LauncherPrefs withFolder({List<String> members = const ['a', 'b']}) =>
      LauncherPrefs(
        drawerFolders: [
          AppFolder(id: 'df0', name: 'Folder', members: members),
        ],
      );

  group('mergeApps', () {
    test('two loose apps become one folder holding both', () {
      final p = DrawerLayout.mergeApps(
        const LauncherPrefs(),
        'a', // dragged
        'b', // target
        newFolderId: nextId,
      );

      expect(p.drawerFolders, hasLength(1));
      // Target first: it is the app that stayed put.
      expect(p.drawerFolders.single.members, ['b', 'a']);
      expect(p.drawerFolders.single.name, 'Folder');
    });

    test('refuses to fold an app into itself', () {
      const before = LauncherPrefs();
      final after =
          DrawerLayout.mergeApps(before, 'a', 'a', newFolderId: nextId);
      expect(identical(before, after), isTrue);
    });

    test('refuses when either app is already filed', () {
      final before = withFolder(); // a and b are folded
      final after =
          DrawerLayout.mergeApps(before, 'a', 'c', newFolderId: nextId);
      expect(identical(before, after), isTrue);

      final after2 =
          DrawerLayout.mergeApps(before, 'c', 'a', newFolderId: nextId);
      expect(identical(before, after2), isTrue);
    });
  });

  group('addToFolder', () {
    test('files a loose app into an existing folder', () {
      final p = DrawerLayout.addToFolder(withFolder(), 'df0', 'c');
      expect(p.drawerFolders.single.members, ['a', 'b', 'c']);
    });

    test('refuses duplicates and unknown folders', () {
      final before = withFolder();
      expect(identical(DrawerLayout.addToFolder(before, 'df0', 'a'), before),
          isTrue);
      expect(identical(DrawerLayout.addToFolder(before, 'nope', 'c'), before),
          isTrue);
    });
  });

  group('removeFromFolder', () {
    test('keeps the folder while two or more remain', () {
      final p = DrawerLayout.removeFromFolder(
        withFolder(members: ['a', 'b', 'c']),
        'df0',
        'c',
      );
      expect(p.drawerFolders.single.members, ['a', 'b']);
    });

    test('dissolves at one survivor — no app is lost', () {
      final p = DrawerLayout.removeFromFolder(withFolder(), 'df0', 'b');
      // Folder gone; 'a' is simply unfolded and the flat list picks it up.
      expect(p.drawerFolders, isEmpty);
      expect(DrawerLayout.foldedKeys(p), isEmpty);
    });
  });

  test('dissolve returns every member to the list', () {
    final p = DrawerLayout.dissolve(
      withFolder(members: ['a', 'b', 'c']),
      'df0',
    );
    expect(p.drawerFolders, isEmpty);
  });

  group('rename', () {
    test('trims and stores', () {
      final p = DrawerLayout.rename(withFolder(), 'df0', '  Games  ');
      expect(p.drawerFolders.single.name, 'Games');
    });

    test('refuses a blank name', () {
      final before = withFolder();
      expect(identical(DrawerLayout.rename(before, 'df0', '   '), before),
          isTrue);
    });
  });

  group('prune', () {
    test('drops uninstalled members', () {
      final p = DrawerLayout.prune(
        withFolder(members: ['a', 'b', 'gone']),
        {'a', 'b'},
      );
      expect(p.drawerFolders.single.members, ['a', 'b']);
    });

    test('dissolves a folder left with one survivor', () {
      final p = DrawerLayout.prune(withFolder(), {'a'});
      expect(p.drawerFolders, isEmpty);
    });
  });

  test('folderOf / foldedKeys report membership', () {
    final p = withFolder(members: ['a', 'b']);
    expect(DrawerLayout.folderOf(p, 'a')?.id, 'df0');
    expect(DrawerLayout.folderOf(p, 'zzz'), isNull);
    expect(DrawerLayout.foldedKeys(p), {'a', 'b'});
  });

  test('drawer folders survive a prefs JSON round trip', () {
    final p = withFolder(members: ['a', 'b']);
    final restored = LauncherPrefs.fromJson(p.toJson());
    expect(restored.drawerFolders.single.members, ['a', 'b']);
    // And they stay independent of home-screen folders.
    expect(restored.folders, isEmpty);
  });
}
