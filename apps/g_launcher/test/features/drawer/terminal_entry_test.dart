// The migration is the risky half of this change: it moves stored positions on
// devices that already have an arrangement, and the failure mode is silent.
// An app that is still in storage but never rendered does not throw, does not
// log, and looks exactly like the launcher having lost it.
import 'package:flutter_test/flutter_test.dart';
import 'package:g_launcher/data/prefs/drawer_slots.dart';
import 'package:g_launcher/data/prefs/launcher_prefs.dart';
import 'package:g_launcher/features/drawer/drawer_items.dart';

LauncherPrefs _prefs(List<DrawerSlot> slots) => const LauncherPrefs().copyWith(
      drawerSortMode: 'custom',
      drawerSlots: slots,
      drawerSlotCols: 4,
      drawerSlotRows: 5,
    );

DrawerSlot _app(int page, int index, String key) =>
    DrawerSlot(page: page, index: index, componentKey: key);

Set<String> _keys(LauncherPrefs p) => {
      for (final s in p.drawerSlots)
        if (s.componentKey != null) s.componentKey!,
    };

List<String> _order(LauncherPrefs p) {
  final sorted = [...p.drawerSlots]..sort(
      (a, b) => DrawerSlots.flatOf(p, a.page, a.index)
          .compareTo(DrawerSlots.flatOf(p, b.page, b.index)),
    );
  return [for (final s in sorted) s.componentKey ?? s.folderId!];
}

void main() {
  group('reservedSlots', () {
    test('is three, matching the pinned entries', () {
      // Settings, Device Settings, Terminal. If this ever changes again,
      // migrateReserved is what makes it safe.
      expect(DrawerSlots.reservedSlots, 3);
    });
  });

  group('needsReservedMigration', () {
    test('true for an arrangement written under the smaller block', () {
      final p = _prefs([_app(0, 2, 'a'), _app(0, 3, 'b')]);
      expect(DrawerSlots.needsReservedMigration(p), isTrue);
    });

    test('false once nothing sits inside the reserved block', () {
      final p = _prefs([_app(0, 3, 'a'), _app(0, 4, 'b')]);
      expect(DrawerSlots.needsReservedMigration(p), isFalse);
    });

    test('false for an empty arrangement', () {
      expect(DrawerSlots.needsReservedMigration(_prefs(const [])), isFalse);
    });
  });

  group('migrateReserved', () {
    test('shifts everything clear of the reserved block, order intact', () {
      final p = _prefs([
        _app(0, 2, 'a'),
        _app(0, 3, 'b'),
        _app(0, 4, 'c'),
      ]);

      final out = DrawerSlots.migrateReserved(
        p,
        liveAppKeys: {'a', 'b', 'c'},
        liveFolderIds: const {},
      );

      expect(_order(out), ['a', 'b', 'c']);
      expect(DrawerSlots.flatOf(out, out.drawerSlots.first.page,
          out.drawerSlots.first.index), 3);
    });

    test('is idempotent, so it can run on every layout pass', () {
      final p = _prefs([_app(0, 2, 'a'), _app(0, 3, 'b')]);
      final once = DrawerSlots.migrateReserved(
        p,
        liveAppKeys: {'a', 'b'},
        liveFolderIds: const {},
      );
      final twice = DrawerSlots.migrateReserved(
        once,
        liveAppKeys: {'a', 'b'},
        liveFolderIds: const {},
      );

      expect(DrawerSlots.needsReservedMigration(once), isFalse);
      expect(_order(twice), _order(once));
    });

    test('leaves an already-clear arrangement completely alone', () {
      // Gaps someone carved are theirs. An arrangement that never sat inside
      // the reserved block has nothing to fix and must not be compacted.
      final p = _prefs([_app(0, 5, 'a'), _app(0, 9, 'b')]);
      final out = DrawerSlots.migrateReserved(
        p,
        liveAppKeys: {'a', 'b'},
        liveFolderIds: const {},
      );
      expect(identical(out, p), isTrue);
    });

    test('order survives, gaps do not', () {
      // The same trade reflow already makes, and for the same reason: a gap's
      // cell no longer means what it meant.
      final p = _prefs([_app(0, 2, 'a'), _app(0, 6, 'b'), _app(0, 11, 'c')]);
      final out = DrawerSlots.migrateReserved(
        p,
        liveAppKeys: {'a', 'b', 'c'},
        liveFolderIds: const {},
      );

      expect(_order(out), ['a', 'b', 'c']);
      final flats = [
        for (final s in out.drawerSlots) DrawerSlots.flatOf(out, s.page, s.index),
      ]..sort();
      expect(flats, [3, 4, 5]);
    });

    test('drops entries whose app is gone rather than carrying them across', () {
      final p = _prefs([_app(0, 2, 'a'), _app(0, 3, 'gone'), _app(0, 4, 'b')]);
      final out = DrawerSlots.migrateReserved(
        p,
        liveAppKeys: {'a', 'b'},
        liveFolderIds: const {},
      );
      expect(_keys(out), {'a', 'b'});
    });

    test('does not clear the page count', () {
      // cleanUp deliberately does. Taking away pages someone grew the drawer
      // to is a side effect they did not ask for, and this operation is a move
      // and nothing else.
      final p = _prefs([_app(0, 2, 'a')]).copyWith(drawerPageCount: 4);
      final out = DrawerSlots.migrateReserved(
        p,
        liveAppKeys: {'a'},
        liveFolderIds: const {},
      );
      expect(out.drawerPageCount, 4);
    });

    test('spills onto the next page when the first is full', () {
      // 4x5 is twenty per page, so the last item cannot stay on page zero once
      // everything shifts by one.
      final slots = [for (var i = 2; i < 20; i++) _app(0, i, 'app$i')];
      final p = _prefs(slots);
      final out = DrawerSlots.migrateReserved(
        p,
        liveAppKeys: {for (var i = 2; i < 20; i++) 'app$i'},
        liveFolderIds: const {},
      );

      expect(_order(out), [for (var i = 2; i < 20; i++) 'app$i']);
      expect(out.drawerSlots.any((s) => s.page == 1), isTrue);
    });
  });

  group('TerminalDrawerItem', () {
    test('carries its label rather than exposing a fixed title', () {
      // The name is TerminalSpec.appLabel, so Kali says "Kali Terminal". A
      // static title would be a place for that name to be wrong.
      expect(const TerminalDrawerItem('Kali Terminal').label, 'Kali Terminal');
      expect(const TerminalDrawerItem().label, TerminalDrawerItem.defaultTitle);
    });

    test('compares by label, so two entries for one theme are equal', () {
      expect(
        const TerminalDrawerItem('Konsole'),
        const TerminalDrawerItem('Konsole'),
      );
      expect(
        const TerminalDrawerItem('Konsole'),
        isNot(const TerminalDrawerItem('Terminal')),
      );
    });
  });

  group('launcherItemsMatching', () {
    test('finds the terminal by its label', () {
      final hits = launcherItemsMatching('term', terminalLabel: 'Kali Terminal');
      expect(hits.whereType<TerminalDrawerItem>(), isNotEmpty);
    });

    test('finds it by the words people actually type', () {
      // A KDE user types konsole, someone who lives in a shell types bash.
      for (final q in ['shell', 'konsole', 'bash', 'ssh', 'cmd']) {
        expect(
          launcherItemsMatching(q).whereType<TerminalDrawerItem>(),
          isNotEmpty,
          reason: q,
        );
      }
    });

    test('an empty query returns nothing', () {
      expect(launcherItemsMatching(''), isEmpty);
    });

    test('the label passed is the label returned', () {
      final hits = launcherItemsMatching('term', terminalLabel: 'COSMIC Terminal');
      expect(hits.whereType<TerminalDrawerItem>().single.label,
          'COSMIC Terminal');
    });
  });
}
