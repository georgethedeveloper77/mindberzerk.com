import 'package:flutter_test/flutter_test.dart';
import 'package:g_launcher/data/prefs/launcher_prefs.dart';
import 'package:g_launcher/data/prefs/prefs_repository.dart';
import 'package:g_launcher/engine/effective_theme.dart';
import 'package:g_launcher/engine/theme_spec.dart';
import 'package:g_launcher/platform/launcher_api.g.dart' as api;

/// Stands in for assets/themes/ubuntu-24-04/theme.json.
ThemeSpec _ubuntu() => ThemeSpec.fromJson({
      'id': 'ubuntu-24-04',
      'name': 'Ubuntu',
      'version': '24.04',
      'shell': 'gnome',
      'tier': 'free',
      'palette': {'accent': '#E95420'},
      'typography': {'display': 'Ubuntu', 'mono': 'UbuntuMono'},
      'layout': {
        'dock': 'left',
        'topBar': true,
        'grid': {'rows': 5, 'cols': 4},
      },
      'icons': {
        'treatment': 'roundedSquare',
        'cornerRadius': 0.22,
        'foregroundScale': 0.62,
        'heroPack': 'yaru',
      },
      'minAppVersion': 6,
    });

void main() {
  group('LauncherPrefs', () {
    test('round-trips through JSON', () {
      const original = LauncherPrefs(
        cols: 6,
        iconTreatment: 'circle',
        labelLines: 2,
        hiddenApps: {'com.foo/.Main#0'},
        favourites: ['com.bar/.Main#0'],
        folders: [
          AppFolder(id: 'f1', name: 'Work', members: ['com.baz/.Main#0']),
        ],
      );

      final restored = LauncherPrefs.fromJson(original.toJson());

      expect(restored.cols, 6);
      expect(restored.iconTreatment, 'circle');
      expect(restored.labelLines, 2);
      expect(restored.hiddenApps, {'com.foo/.Main#0'});
      expect(restored.favourites, ['com.bar/.Main#0']);
      expect(restored.folders.single.name, 'Work');
      expect(restored.folders.single.members, ['com.baz/.Main#0']);
    });

    test('unset fields stay null — null means INHERIT, not a default', () {
      final p = LauncherPrefs.fromJson(const LauncherPrefs().toJson());
      expect(p.cols, isNull);
      expect(p.dockSide, isNull);
      expect(p.iconTreatment, isNull);
    });

    test('prefs from a NEWER schema reset instead of throwing', () {
      // A downgrade must not black-screen the home screen.
      final p = LauncherPrefs.fromJson({'schemaVersion': 999, 'cols': 9});
      expect(p.cols, isNull);
    });

    test('clearing() resets a field to null — copyWith cannot', () {
      const p = LauncherPrefs(cols: 6, rows: 7);
      expect(p.copyWith().cols, 6);
      expect(p.clearing(cols: true).cols, isNull);
      expect(p.clearing(cols: true).rows, 7, reason: 'only clears what is asked');
    });
  });

  group('PrefsRepository', () {
    test('persists and reloads per theme', () async {
      final repo = PrefsRepository(MemoryPrefsStore());

      await repo.save('ubuntu-24-04', const LauncherPrefs(cols: 6));
      await repo.save('kde-plasma-6', const LauncherPrefs(cols: 3));

      expect((await repo.load('ubuntu-24-04')).cols, 6);
      expect((await repo.load('kde-plasma-6')).cols, 3);
    });

    test('themes do not clobber each other — §5.3', () async {
      final repo = PrefsRepository(MemoryPrefsStore());

      await repo.save('ubuntu-24-04', const LauncherPrefs(cols: 6));
      await repo.save('kde-plasma-6', const LauncherPrefs(cols: 3));
      await repo.save('kde-plasma-6', const LauncherPrefs(cols: 2));

      // Switching to KDE, fiddling, and switching back must return you to YOUR
      // Ubuntu setup.
      expect((await repo.load('ubuntu-24-04')).cols, 6);
    });

    test('unknown theme loads defaults, does not throw', () async {
      final repo = PrefsRepository(MemoryPrefsStore());
      expect((await repo.load('never-seen')).cols, isNull);
    });

    test('corrupt prefs fall back to defaults', () async {
      final store = MemoryPrefsStore();
      await store.write('prefs.v1.ubuntu-24-04', 'not json {{{');

      final prefs = await PrefsRepository(store).load('ubuntu-24-04');
      expect(prefs.cols, isNull, reason: 'must not take the home screen down');
    });
  });

  group('EffectiveTheme', () {
    test('with no overrides, the theme wins', () {
      final e = EffectiveTheme.resolve(_ubuntu(), const LauncherPrefs());

      expect(e.dock, DockSide.left);
      expect(e.topBar, isTrue);
      expect(e.rows, 5);
      expect(e.cols, 4);
      expect(e.icons.treatment, api.IconTreatment.roundedSquare);
      expect(e.icons.cornerRadius, 0.22);
      expect(e.icons.heroPack, 'yaru');
    });

    test('user overrides beat the theme', () {
      final e = EffectiveTheme.resolve(
        _ubuntu(),
        const LauncherPrefs(
          cols: 6,
          dockSide: 'bottom',
          iconTreatment: 'circle',
          cornerRadius: 0.5,
        ),
      );

      expect(e.cols, 6);
      expect(e.dock, DockSide.bottom);
      expect(e.icons.treatment, api.IconTreatment.circle);
      expect(e.icons.cornerRadius, 0.5);

      // Not overridden -> still the theme's.
      expect(e.rows, 5);
      expect(e.icons.heroPack, 'yaru');
      expect(e.icons.foregroundScale, 0.62);
    });

    test('iconCacheId changes when the shape changes', () {
      // THE test for the icon-shape picker. If this id does not move, native
      // serves the cached old shape forever and the setting looks broken.
      final a = EffectiveTheme.resolve(_ubuntu(), const LauncherPrefs());
      final b = EffectiveTheme.resolve(
        _ubuntu(),
        const LauncherPrefs(iconTreatment: 'circle'),
      );
      final c = EffectiveTheme.resolve(
        _ubuntu(),
        const LauncherPrefs(cornerRadius: 0.4),
      );

      expect(a.iconCacheId, isNot(b.iconCacheId));
      expect(a.iconCacheId, isNot(c.iconCacheId));
    });

    test('drawerCols defaults to the same width as home', () {
      final e = EffectiveTheme.resolve(_ubuntu(), const LauncherPrefs());
      expect(e.cols, 4);
      expect(e.drawerCols, 4,
          reason: 'drawer defaults to the same width as home, not home + 1');

      // Widening home widens the drawer with it, UNLESS the user set the drawer
      // explicitly — then their choice sticks.
      final wider = EffectiveTheme.resolve(_ubuntu(), const LauncherPrefs(cols: 6));
      expect(wider.drawerCols, 6);

      final pinned = EffectiveTheme.resolve(
        _ubuntu(),
        const LauncherPrefs(cols: 6, drawerCols: 4),
      );
      expect(pinned.drawerCols, 4);
    });

    test('iconCacheId is stable when nothing icon-related changed', () {
      final a = EffectiveTheme.resolve(_ubuntu(), const LauncherPrefs());
      final b = EffectiveTheme.resolve(_ubuntu(), const LauncherPrefs(cols: 6));

      // Changing the grid must NOT invalidate 200 cached icons.
      expect(a.iconCacheId, b.iconCacheId);
    });
  });
}
