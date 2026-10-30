import 'package:flutter_test/flutter_test.dart';
import 'package:g_launcher/data/prefs/layout_snapshots.dart';
import 'package:g_launcher/data/prefs/prefs_repository.dart';
import 'package:g_launcher/features/terminal/command_registry.dart';
import 'package:g_launcher/features/terminal/fun_commands.dart';
import 'package:g_launcher/features/terminal/package_commands.dart';

const _apps = [
  PackageApp(
    label: 'Telegram',
    packageName: 'org.telegram.messenger',
    componentKey: 'tg',
  ),
  PackageApp(
    label: 'G VPN',
    packageName: 'com.mindberzerk.gvpn',
    componentKey: 'gvpn',
  ),
];

void main() {
  group('PackageCommands', () {
    test('apt install opens Play on the term', () {
      final p = PackageCommands.run('apt', 'install signal', _apps, sudo: true);
      expect((p.effect as PlaySearch).query, 'signal');
    });

    test('already installed is said, not reopened', () {
      final p = PackageCommands.run('apt', 'install gvpn', _apps, sudo: true);
      expect(p.effect, isA<NoEffect>());
      expect(p.lines.join(), contains('already the newest version'));
    });

    test('pacman grammar', () {
      expect(PackageCommands.run('pacman', '-Syu', _apps, sudo: true).effect,
          isA<PlayUpdates>());
      expect(
          PackageCommands.run('pacman', '-S telegram', _apps, sudo: true)
              .effect,
          isA<NoEffect>());
      expect(
          PackageCommands.run('pacman', '-Ss vpn', _apps, sudo: false).effect,
          isA<PlaySearch>());
      final r =
          PackageCommands.run('pacman', '-Rns telegram', _apps, sudo: true);
      expect((r.effect as Uninstall).componentKey, 'tg');
    });

    test('remove of an unknown app fails in the manager voice', () {
      final p = PackageCommands.run('apt', 'remove nope', _apps, sudo: true);
      expect(p.lines.single, 'E: Unable to locate package nope');
    });
  });

  group('FunCommands', () {
    test('cowsay wraps and frames', () {
      final out = FunCommands.cowsay('hello');
      expect(out[1], '< hello >');
    });

    test('make me a sandwich needs sudo', () {
      expect(FunCommands.make('me a sandwich', sudo: false).single,
          'What? Make it yourself.');
      expect(FunCommands.make('me a sandwich', sudo: true).single,
          contains('Okay.'));
    });

    test('rm -rf / is refused', () {
      expect(FunCommands.rm('-rf /').first, contains('dangerous'));
    });
  });

  group('TUI hand-over', () {
    test('only with arguments, never bare', () {
      expect(TerminalRegistry.handsOver('apt install telegram'), isTrue);
      expect(TerminalRegistry.handsOver('sl'), isFalse);
      expect(TerminalRegistry.handsOver('snap'), isFalse);
      expect(TerminalRegistry.handsOver('settings now'), isFalse);
    });

    test('Terminal-only names do not resolve on the TUI', () {
      expect(TerminalRegistry.resolve('sl'), isNull);
      expect(TerminalRegistry.resolve('sl', surface: CommandSurface.terminal),
          'sl');
    });
  });

  group('LayoutSnapshots', () {
    test('commit, no-op commit, apply', () async {
      final store = MemoryPrefsStore();
      final prefs = <String, dynamic>{
        'favourites': ['a', 'b'],
        'homeItems': <dynamic>[],
        'iconTreatment': 'circle',
      };
      final s1 = await LayoutSnapshots.commit(store, 'ubuntu', prefs,
          message: 'two apps');
      expect(s1, isNotNull);
      expect(
        await LayoutSnapshots.commit(store, 'ubuntu', prefs, message: 'again'),
        isNull,
      );

      final changed = {
        ...prefs,
        'favourites': ['c'],
        'iconTreatment': 'square'
      };
      final restored = LayoutSnapshots.apply(changed, s1!);
      expect(restored['favourites'], ['a', 'b']);
      // Not a layout field: left as the person set it.
      expect(restored['iconTreatment'], 'square');
    });

    test('find by prefix and by index', () async {
      final store = MemoryPrefsStore();
      final a = await LayoutSnapshots.commit(
          store,
          't',
          {
            'favourites': ['a']
          },
          message: 'a');
      await LayoutSnapshots.commit(
          store,
          't',
          {
            'favourites': ['b']
          },
          message: 'b');
      final list = await LayoutSnapshots.load(store, 't');
      expect(list.first.message, 'b');
      expect(LayoutSnapshots.find(list, 'HEAD~1')!.id, a!.id);
      expect(LayoutSnapshots.find(list, a.id.substring(0, 4))!.message, 'a');
    });
  });
}
