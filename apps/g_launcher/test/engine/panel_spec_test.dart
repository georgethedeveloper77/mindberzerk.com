/// Parse-level tests for the panel vocabulary.
///
/// These exist because `tray` is now the one authored word that does not map to
/// one module, and the rule for when it splits is an edge test that no shell
/// can see. A pack author writing `tray` on a bottom panel and getting a dead
/// cluster is the bug this replaced, and it was invisible until somebody tapped
/// the battery glyph on a phone.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:g_launcher/engine/theme_spec.dart';

void main() {
  group('PanelItem.parseAll', () {
    test('tray becomes wifi, volume and battery on a bottom panel', () {
      final items = PanelItem.parseAll(
        const ['kickoff', 'tasks', 'spacer', 'tray', 'clock'],
        side: TopBarSide.bottom,
      );

      expect(items.map((e) => e.kind), [
        PanelModule.kickoff,
        PanelModule.tasks,
        PanelModule.spacer,
        PanelModule.wifi,
        PanelModule.volume,
        PanelModule.battery,
        PanelModule.clock,
      ]);
    });

    test('the expansion lands in place, not at the end', () {
      final items = PanelItem.parseAll(
        const ['tray', 'clock'],
        side: TopBarSide.bottom,
      );

      expect(items.last.kind, PanelModule.clock);
      expect(items.first.kind, PanelModule.wifi);
    });

    test('a vertical panel expands too', () {
      for (final side in [TopBarSide.left, TopBarSide.right]) {
        final items = PanelItem.parseAll(const ['tray'], side: side);
        expect(items.length, 3, reason: 'expanded on ${side.name}');
      }
    });

    test('a top bar keeps the tray whole', () {
      final items = PanelItem.parseAll(const ['tray'], side: TopBarSide.top);

      expect(items.single.kind, PanelModule.tray);
    });

    test('two trays expand twice, because removal is by index', () {
      final items = PanelItem.parseAll(
        const ['tray', 'spacer', 'tray'],
        side: TopBarSide.bottom,
      );

      expect(items.length, 7);
    });

    test('an app keeps its package', () {
      final items = PanelItem.parseAll(
        const ['app:com.example.files'],
        side: TopBarSide.bottom,
      );

      expect(items.single.kind, PanelModule.app);
      expect(items.single.package, 'com.example.files');
    });

    test('an unknown module is dropped rather than fatal', () {
      final items = PanelItem.parseAll(
        const ['kickoff', 'hologram', 'clock'],
        side: TopBarSide.bottom,
      );

      expect(items.map((e) => e.kind), [
        PanelModule.kickoff,
        PanelModule.clock,
      ]);
    });

    test('an app with no package is dropped', () {
      expect(
        PanelItem.parseAll(const ['app:'], side: TopBarSide.bottom),
        isEmpty,
      );
    });

    test('the expansion is what the Add sheet offers', () {
      expect(
        PanelItem.trayExpansion.map((e) => e.kind),
        [PanelModule.wifi, PanelModule.volume, PanelModule.battery],
      );
    });
  });

  group('PanelModule.parse', () {
    test('volume is a word a pack can author', () {
      expect(PanelModule.parse('volume'), PanelModule.volume);
    });

    test('storage round-trips through toStorage', () {
      for (final m in PanelModule.values) {
        if (m == PanelModule.app) continue;
        expect(PanelModule.parse(PanelItem(m).toStorage()), m);
      }
    });

    test('an app round-trips with its package', () {
      const item = PanelItem(PanelModule.app, 'com.example.files');
      expect(PanelItem.parse(item.toStorage()), item);
    });
  });

  group('PanelSpec.fromJson', () {
    test('reads the side before the modules, so the tray splits correctly', () {
      final spec = PanelSpec.fromJson(const {
        'side': 'bottom',
        'modules': ['kickoff', 'tray'],
      });

      expect(spec, isNotNull);
      expect(spec!.modules, [
        PanelModule.kickoff,
        PanelModule.wifi,
        PanelModule.volume,
        PanelModule.battery,
      ]);
    });

    test('a panel with nothing on it is null, not empty', () {
      expect(
        PanelSpec.fromJson(const {'side': 'bottom', 'modules': []}),
        isNull,
      );
    });

    test('a panel of only unknown modules is null too', () {
      expect(
        PanelSpec.fromJson(const {
          'side': 'bottom',
          'modules': ['hologram'],
        }),
        isNull,
      );
    });

    test('height stays optional', () {
      final spec = PanelSpec.fromJson(const {
        'side': 'top',
        'modules': ['tray'],
      });

      expect(spec!.height, isNull);
      expect(spec.side, TopBarSide.top);
    });
  });
}
