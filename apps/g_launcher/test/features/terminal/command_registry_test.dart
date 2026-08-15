import 'package:flutter_test/flutter_test.dart';
import 'package:g_launcher/features/terminal/command_registry.dart';

/// These tests exist to pin BEHAVIOUR THAT ALREADY SHIPPED, not to describe a
/// new feature. The registry replaced three const collections and a hand-rolled
/// matcher on the flagship screen, and the only acceptable outcome of that
/// refactor is that nobody can tell.
///
/// So most of what follows asserts the old table's exact quirks, including the
/// one that is arguably a bug (`df` and `du` collapsing). A refactor that
/// quietly improves the thing it was supposed to preserve is still a change to
/// the flagship screen, and it would have shipped unannounced.
void main() {
  group('canonical', () {
    test('strips flags, because `free -h` is `free`', () {
      expect(TerminalRegistry.canonical('free -h'), 'free');
      expect(TerminalRegistry.canonical('ls -la'), 'ls');
    });

    test('lowercases and trims', () {
      expect(TerminalRegistry.canonical('  SETTINGS  '), 'settings');
    });

    test('empty input stays empty rather than throwing', () {
      expect(TerminalRegistry.canonical('   '), '');
    });
  });

  group('resolve', () {
    test('exact name', () {
      expect(TerminalRegistry.resolve('settings'), 'settings');
    });

    test('exact alias', () {
      expect(TerminalRegistry.resolve('prefs'), 'prefs');
      expect(TerminalRegistry.resolve('?'), '?');
    });

    test('unique prefix runs, so `se` opens settings', () {
      expect(TerminalRegistry.resolve('se'), 'settings');
    });

    test('ambiguous prefix runs NOTHING, so the app matcher gets it', () {
      // config, conky, cal and clear all start with c. Resolving to any one of
      // them would surprise the user with which of four fired.
      expect(TerminalRegistry.resolve('c'), isNull);
    });

    test('unknown text is not a command', () {
      expect(TerminalRegistry.resolve('spotify'), isNull);
      expect(TerminalRegistry.resolve(''), isNull);
    });

    test('flags do not defeat resolution', () {
      expect(TerminalRegistry.resolve('free -h'), 'free');
    });
  });

  group('matching', () {
    test('exact hit sorts above longer commands that start with it', () {
      // `ip` is an alias of ifstat and also a prefix of nothing else, but the
      // ordering rule matters wherever a full word is also a prefix.
      final hits = TerminalRegistry.matching('help');
      expect(hits.first, 'help');
    });

    test('aliases collapse when they would print the same description twice',
        () {
      // settings, gsettings, config and prefs all describe themselves as
      // "G Launcher Settings". One row, not four.
      final hits = TerminalRegistry.matching('s');
      final settingsRows =
          hits.where((h) => TerminalRegistry.describe(h) == 'G Launcher Settings');
      expect(settingsRows.length, 1);
    });

    test('an alias still gets its own row when typed toward directly', () {
      // Nobody who typed `pr` wants to be shown `settings` instead.
      expect(TerminalRegistry.matching('pr'), contains('prefs'));
    });

    test('df and du collapse, which is inherited and deliberate', () {
      // Both describe themselves as "Storage, live", so typing `d` shows one
      // storage row. Asserted so that the day someone gives `du` its own
      // wording, this test fails and the change is a decision rather than a
      // side effect.
      final hits = TerminalRegistry.matching('d');
      final storageRows =
          hits.where((h) => TerminalRegistry.describe(h) == 'Storage, live');
      expect(storageRows.length, 1);
      expect(TerminalRegistry.resolve('du'), 'du');
    });

    test('empty query matches nothing', () {
      expect(TerminalRegistry.matching(''), isEmpty);
    });
  });

  group('table integrity', () {
    test('no name or alias is claimed twice', () {
      final seen = <String>{};
      for (final n in TerminalRegistry.names) {
        expect(seen.add(n), isTrue, reason: 'duplicate command name: $n');
      }
    });

    test('every spawn command names a desklet kind', () {
      for (final c in TerminalRegistry.all) {
        if (c.action == CommandAction.spawnDesklet) {
          expect(c.spawnKind, isNotNull, reason: c.name);
        }
      }
    });

    test('every spawn kind is one the theme schema enumerates', () {
      // Mirrors schema/theme.schema.json's kindId enum. A spawn command naming
      // a kind the schema does not know would place a desklet the picker cannot
      // show and validate_themes.sh would never catch it, because the command
      // table is not a theme.
      const kinds = {
        'glance', 'clock', 'monitor', 'fastfetch', 'network', 'storage',
        'battery', 'notes', 'search',
        'free', 'df', 'ls', 'uptime',
      };
      for (final c in TerminalRegistry.all) {
        if (c.spawnKind != null) {
          expect(kinds, contains(c.spawnKind), reason: c.name);
        }
      }
    });

    test('key is the only Pro command, and it is still visible', () {
      // The gate is at EXECUTION. A Pro command still resolves, still
      // completes, and still appears in help wearing a lock, because a feature
      // nobody can find is a feature nobody buys.
      final pro = [
        for (final c in TerminalRegistry.all)
          if (c.tier == CommandTier.pro) c.name,
      ];
      expect(pro, ['key']);

      expect(
        TerminalRegistry.resolve('key', surface: CommandSurface.terminal),
        'key',
      );
      expect(TerminalRegistry.matching('k', surface: CommandSurface.terminal),
          contains('key'));
    });

    test('every action id is unique and stable', () {
      // The ids are the wire format a theme's terminal profile will bind an
      // alias to. Renaming one orphans every pack that used it.
      final ids = CommandAction.values.map((a) => a.id).toList();
      expect(ids.toSet().length, ids.length);
      for (final a in CommandAction.values) {
        expect(CommandAction.byId(a.id), a);
      }
    });

    test('an unknown action id degrades to null rather than throwing', () {
      // A pack authored against a newer app names an action this build has
      // never heard of. Everywhere else in the theme layer that degrades.
      expect(CommandAction.byId('launcher.timeTravel'), isNull);
      expect(CommandAction.byId(null), isNull);
    });

    test('helpLine names only commands that exist', () {
      for (final n in TerminalRegistry.helpLine.split(' \u00b7 ')) {
        expect(TerminalRegistry.command(n), isNotNull, reason: n);
      }
    });

    test('hintLine names only commands that exist', () {
      // The pre-typing hint used to be a string literal in tui_shell, which is
      // how it drifted from the table in the first place.
      for (final n in TerminalRegistry.hintLine.split(' \u00b7 ')) {
        expect(TerminalRegistry.command(n), isNotNull, reason: n);
      }
    });

    test('only `terminal` is surface-restricted, and it is TUI shell only', () {
      // The remote commands WERE restricted the other way, on the reasoning
      // that this shell has no scrollback and could not render a session. The
      // reasoning held; the conclusion did not. Typing `ssh myserver` at the
      // home prompt of the Terminal distro and getting silence is indefensible
      // on the one distro whose entire pitch is that it has a shell, so the
      // shell hands the line over instead of refusing it.
      //
      // `terminal` goes the other way and stays restricted: it opens the
      // Terminal app, which is meaningless once you are in it.
      const tuiOnly = {'terminal'};

      for (final c in TerminalRegistry.all) {
        expect(
          c.appearsOn(CommandSurface.terminal),
          !tuiOnly.contains(c.name),
          reason: c.name,
        );
        expect(c.appearsOn(CommandSurface.tui), isTrue, reason: c.name);
      }
    });

    test('the Terminal app is reachable from the TUI shell', () {
      // The gap this closes was found on a device: on the Terminal distro the
      // app had no entry point at all, because every other shell reaches it
      // through the drawer and that one has none.
      expect(
        TerminalRegistry.resolve('terminal', surface: CommandSurface.tui),
        'terminal',
      );
      expect(
        TerminalRegistry.command('terminal')!.action,
        CommandAction.openTerminal,
      );
    });

    test('it is named in the hint line, since nothing else advertises it', () {
      expect(TerminalRegistry.hintLine, contains('terminal'));
    });

    test('the TUI shell resolves the remote commands and hands them over', () {
      for (final name in const ['ssh', 'hosts', 'host']) {
        expect(
          TerminalRegistry.resolve(name, surface: CommandSurface.tui),
          name,
          reason: name,
        );
      }
    });

    test('the arguments survive, because for these commands they are the point',
        () {
      // `ssh` alone is a usage message; `ssh myserver` is the instruction. The
      // TUI dispatcher hands over the RAW line for that reason, and `canonical`
      // is only ever used to find the command name.
      expect(TerminalRegistry.canonical('ssh myserver'), 'ssh');
      expect(
        TerminalRegistry.resolve('ssh myserver', surface: CommandSurface.tui),
        'ssh',
      );
    });

    test('`s` still resolves to settings on the TUI shell', () {
      // The behaviour that a badly chosen alias would have broken. Asserted
      // because it is the single most used two-keystroke path on the flagship
      // screen and nothing else guards it.
      expect(
        TerminalRegistry.resolve('s', surface: CommandSurface.tui),
        'settings',
      );
      expect(
        TerminalRegistry.resolve('te', surface: CommandSurface.tui),
        'terminal',
      );
    });
  });
}
