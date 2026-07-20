import 'package:flutter_test/flutter_test.dart';
import 'package:g_launcher/data/prefs/launcher_prefs.dart';
import 'package:g_launcher/engine/layout_resolver.dart';
import 'package:g_launcher/engine/theme_spec.dart';

/// A minimal ThemeSpec built through the real parser, so the fixture can't drift
/// from how a bundled theme.json actually decodes.
ThemeSpec makeSpec({
  String dock = 'left',
  bool topBar = true,
  int rows = 5,
  int cols = 4,
}) =>
    ThemeSpec.fromJson(<String, dynamic>{
      'id': 'ubuntu-24-04',
      'name': 'Ubuntu',
      'version': '24.04',
      'shell': 'gnome',
      'tier': 'free',
      'palette': <String, dynamic>{},
      'layout': <String, dynamic>{
        'dock': dock,
        'topBar': topBar,
        'grid': <String, dynamic>{'rows': rows, 'cols': cols},
      },
    });

void main() {
  group('LayoutResolver.resolve', () {
    test('with no overrides, every field inherits the theme default', () {
      final r = LayoutResolver.resolve(
        makeSpec(dock: 'left', topBar: true, rows: 5, cols: 4),
        const LauncherPrefs(),
      );

      expect(r.dock, DockSide.left);
      expect(r.topBar, isTrue);
      expect(r.rows, 5);
      expect(r.cols, 4);
      // Drawer defaults to the SAME width as home (4), NOT home+1. This is the
      // behaviour the old prefs_test still asserts as 5; that assertion is the
      // stale one, the source is correct.
      expect(r.drawerCols, 4);
      expect(r.iconSizeDp, LayoutResolver.defaultIconSizeDp); // 52
      expect(r.labelLines, LayoutResolver.defaultLabelLines); // 2
      expect(r.textScale, LayoutResolver.defaultTextScale); // 1.0
    });

    test('a set override always beats the theme default', () {
      final r = LayoutResolver.resolve(
        makeSpec(dock: 'left', topBar: true, rows: 5, cols: 4),
        const LauncherPrefs(
          dockSide: 'bottom',
          topBar: false,
          rows: 6,
          cols: 5,
          iconSizeDp: 60,
          labelLines: 1,
          textScale: 1.2,
        ),
      );

      expect(r.dock, DockSide.bottom);
      expect(r.topBar, isFalse);
      expect(r.rows, 6);
      expect(r.cols, 5);
      expect(
          r.drawerCols, 5); // no explicit drawerCols, tracks the cols override
      expect(r.iconSizeDp, 60);
      expect(r.labelLines, 1);
      expect(r.textScale, 1.2);
    });

    test('an explicit drawerCols beats the home-cols fallback', () {
      final r = LayoutResolver.resolve(
        makeSpec(cols: 4),
        const LauncherPrefs(cols: 4, drawerCols: 6),
      );
      expect(r.cols, 4);
      expect(r.drawerCols, 6);
    });

    test('an unknown dockSide string falls back to the theme default', () {
      final r = LayoutResolver.resolve(
        makeSpec(dock: 'bottom'),
        const LauncherPrefs(dockSide: 'sideways'),
      );
      expect(r.dock, DockSide.bottom);
    });

    test('a null dockSide falls back to the theme default', () {
      expect(
        LayoutResolver.resolve(makeSpec(dock: 'off'), const LauncherPrefs())
            .dock,
        DockSide.off,
      );
    });

    test('the same empty prefs read each theme own default (per-theme story)',
        () {
      // The resolver reads the ACTIVE theme's default when that theme's prefs
      // are empty. Storage keeps prefs per theme (prefs_repository), so a bottom
      // dock set on Ubuntu never leaks onto a fresh KDE, and vice versa; here we
      // show the merge half: empty prefs => the theme's own default wins.
      final ubuntu = LayoutResolver.resolve(
        makeSpec(dock: 'left'),
        const LauncherPrefs(),
      );
      final kde = LayoutResolver.resolve(
        makeSpec(dock: 'bottom'),
        const LauncherPrefs(),
      );
      expect(ubuntu.dock, DockSide.left);
      expect(kde.dock, DockSide.bottom);
    });

    test('ResolvedLayout has value equality', () {
      final spec = makeSpec();
      const prefs = LauncherPrefs(cols: 5);
      expect(
        LayoutResolver.resolve(spec, prefs),
        LayoutResolver.resolve(spec, prefs),
      );
    });
  });
}
