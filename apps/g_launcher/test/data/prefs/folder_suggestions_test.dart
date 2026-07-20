import 'package:flutter_test/flutter_test.dart';
import 'package:g_launcher/data/prefs/folder_suggestions.dart';
import 'package:g_launcher/data/prefs/launcher_prefs.dart';
import 'package:g_launcher/platform/launcher_api.g.dart';

/// Builds an AppEntry with only the fields the suggester reads; the rest are
/// plausible constants so the test reads as a list of apps, not of plumbing.
AppEntry app(
  String packageName, {
  String? label,
  int category = -1,
  bool isGame = false,
}) {
  final key = '$packageName/.Main#0';
  return AppEntry(
    componentKey: key,
    packageName: packageName,
    className: '.Main',
    userSerial: 0,
    label: label ?? packageName.split('.').last,
    updateToken: 0,
    isWorkProfile: false,
    isSuspended: false,
    isSystem: false,
    category: category,
    isGame: isGame,
  );
}

String keyOf(String packageName) => '$packageName/.Main#0';

void main() {
  var counter = 0;
  String nextId() => 'df${counter++}';
  setUp(() => counter = 0);

  group('games', () {
    test('proposes once three or more games are installed', () {
      final apps = [
        app('com.a.one', isGame: true),
        app('com.b.two', isGame: true),
        app('com.c.three', category: FolderSuggestions.categoryGame),
        app('com.d.notagame'),
      ];

      final s = FolderSuggestions.propose(apps, const LauncherPrefs()).single;
      expect(s.id, 'games');
      expect(s.name, 'Games');
      expect(s.componentKeys, [
        keyOf('com.a.one'),
        keyOf('com.b.two'),
        keyOf('com.c.three'),
      ]);
    });

    test('stays quiet below the threshold', () {
      final apps = [
        app('com.a.one', isGame: true),
        app('com.b.two', isGame: true),
      ];
      expect(FolderSuggestions.propose(apps, const LauncherPrefs()), isEmpty);
    });

    test('the legacy flag counts, not just the modern category', () {
      // Plenty of older games never set android:appCategory. If only the
      // category counted, this list would look like three non-games.
      final apps = [
        app('com.a.one', isGame: true),
        app('com.b.two', isGame: true),
        app('com.c.three', isGame: true),
      ];
      expect(FolderSuggestions.propose(apps, const LauncherPrefs()), hasLength(1));
    });
  });

  group('publisher clusters', () {
    test('groups on the vendor segment once four share it', () {
      final apps = [
        app('com.google.android.youtube'),
        app('com.google.android.gm'),
        app('com.google.android.apps.maps'),
        app('com.google.android.calendar'),
        app('com.other.thing'),
      ];

      final s = FolderSuggestions.propose(apps, const LauncherPrefs()).single;
      expect(s.id, 'pub:google');
      expect(s.name, 'Google');
      expect(s.kind, SuggestionKind.publisher);
      expect(s.size, 4);
    });

    test('com.sec.* joins Samsung rather than making a second folder', () {
      final apps = [
        app('com.sec.android.app.camera'),
        app('com.sec.android.gallery3d'),
        app('com.sec.android.app.myfiles'),
        app('com.sec.android.daemonapp'),
      ];
      final s = FolderSuggestions.propose(apps, const LauncherPrefs()).single;
      expect(s.name, 'Samsung');
    });

    test('never groups the AOSP core', () {
      final apps = [
        app('com.android.dialer'),
        app('com.android.contacts'),
        app('com.android.camera'),
        app('com.android.settings'),
        app('com.android.clock'),
      ];
      expect(FolderSuggestions.propose(apps, const LauncherPrefs()), isEmpty);
    });

    test('unknown vendors are title-cased, not ignored', () {
      final apps = List.generate(4, (i) => app('com.spotify.app$i'));
      final s = FolderSuggestions.propose(apps, const LauncherPrefs()).single;
      expect(s.name, 'Spotify');
    });

    test('a game is claimed by Games, not by its publisher', () {
      final apps = [
        for (var i = 0; i < 4; i++) app('com.zynga.game$i', isGame: true),
      ];
      final out = FolderSuggestions.propose(apps, const LauncherPrefs());
      // Four games from one publisher clears both thresholds; Games wins and
      // the publisher group is left with nothing.
      expect(out.map((s) => s.id), ['games']);
    });
  });

  group('ordering and exclusions', () {
    test('biggest suggestion first', () {
      final apps = [
        for (var i = 0; i < 5; i++) app('com.google.app$i'),
        for (var i = 0; i < 3; i++) app('com.x.game$i', isGame: true),
      ];
      final out = FolderSuggestions.propose(apps, const LauncherPrefs());
      expect(out.map((s) => s.id), ['pub:google', 'games']);
    });

    test('apps already in a folder are not proposed again', () {
      final apps = [
        app('com.a.one', isGame: true),
        app('com.b.two', isGame: true),
        app('com.c.three', isGame: true),
      ];
      final prefs = LauncherPrefs(
        drawerFolders: [
          AppFolder(
            id: 'df0',
            name: 'Mine',
            members: [keyOf('com.a.one'), keyOf('com.b.two')],
          ),
        ],
      );
      // Only one loose game left, well under the threshold.
      expect(FolderSuggestions.propose(apps, prefs), isEmpty);
    });

    test('dismissed groups stay dismissed', () {
      final apps = [
        app('com.a.one', isGame: true),
        app('com.b.two', isGame: true),
        app('com.c.three', isGame: true),
      ];
      const prefs = LauncherPrefs(dismissedSuggestions: {'games'});
      expect(FolderSuggestions.propose(apps, prefs), isEmpty);
    });
  });

  group('accept / dismiss', () {
    final apps = [
      app('com.a.one', isGame: true),
      app('com.b.two', isGame: true),
      app('com.c.three', isGame: true),
    ];

    test('accept creates an ordinary drawer folder', () {
      final s = FolderSuggestions.propose(apps, const LauncherPrefs()).single;
      final p = FolderSuggestions.accept(
        const LauncherPrefs(),
        s,
        newFolderId: nextId,
      );

      expect(p.drawerFolders.single.name, 'Games');
      expect(p.drawerFolders.single.members, hasLength(3));
      // Indistinguishable from a hand-built folder — no suggestion metadata
      // rides along, so rename/ungroup work with no special cases.
      expect(p.dismissedSuggestions, isEmpty);
    });

    test('accept drops members filed elsewhere in the meantime', () {
      final s = FolderSuggestions.propose(apps, const LauncherPrefs()).single;
      final busy = LauncherPrefs(
        drawerFolders: [
          AppFolder(
            id: 'df9',
            name: 'Elsewhere',
            members: [keyOf('com.a.one'), keyOf('com.b.two')],
          ),
        ],
      );
      // Only 'com.c.three' is still loose → one member → not a folder.
      final p = FolderSuggestions.accept(busy, s, newFolderId: nextId);
      expect(identical(busy, p), isTrue);
    });

    test('dismiss records the id and is idempotent', () {
      final s = FolderSuggestions.propose(apps, const LauncherPrefs()).single;
      final once = FolderSuggestions.dismiss(const LauncherPrefs(), s);
      expect(once.dismissedSuggestions, {'games'});

      final twice = FolderSuggestions.dismiss(once, s);
      expect(identical(once, twice), isTrue);
    });

    test('clearDismissals lets them come back', () {
      const p = LauncherPrefs(dismissedSuggestions: {'games'});
      expect(FolderSuggestions.clearDismissals(p).dismissedSuggestions, isEmpty);
    });
  });

  test('dismissals survive a prefs JSON round trip', () {
    const p = LauncherPrefs(dismissedSuggestions: {'games', 'pub:google'});
    final restored = LauncherPrefs.fromJson(p.toJson());
    expect(restored.dismissedSuggestions, {'games', 'pub:google'});
  });
}
