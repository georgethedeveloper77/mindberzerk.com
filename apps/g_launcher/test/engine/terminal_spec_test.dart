// Guards the terminal block: parse, degrade, clamp, and the schema-to-enum
// contract that nothing else can check.
//
// The parse tests exist because this block is the first one in the theme layer
// whose failure is invisible. A wrong boot line looks wrong; a terminal palette
// that silently fell back to the shell default looks like a terminal.
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:g_launcher/engine/terminal_spec.dart';
import 'package:g_launcher/engine/theme_spec.dart';
import 'package:g_launcher/features/terminal/command_registry.dart';

Map<String, dynamic> _palette({int count = 16}) => {
      'bg': '#080D08',
      'fg': '#52F088',
      'ansi': List<String>.filled(count, '#123456'),
    };

void main() {
  group('TerminalPalette.fromJson', () {
    test('parses sixteen colours', () {
      final p = TerminalPalette.fromJson(_palette());
      expect(p, isNotNull);
      expect(p!.ansi.length, 16);
      expect(p.bg, const Color(0xFF080D08));
    });

    test('a short ansi array fails the palette rather than padding it', () {
      // Padding would put some escape codes on a colour nobody chose, which
      // reads as a rendering bug. Failing falls back to the whole shell default,
      // which is louder and traceable.
      expect(TerminalPalette.fromJson(_palette(count: 15)), isNull);
      expect(TerminalPalette.fromJson(_palette(count: 17)), isNull);
    });

    test('one unparseable colour fails the palette', () {
      final j = _palette();
      (j['ansi'] as List)[7] = 'not-a-colour';
      expect(TerminalPalette.fromJson(j), isNull);
    });

    test('missing bg or fg fails the palette', () {
      expect(TerminalPalette.fromJson(_palette()..remove('bg')), isNull);
      expect(TerminalPalette.fromJson(_palette()..remove('fg')), isNull);
    });

    test('role colours are read out of ansi, never authored', () {
      final j = _palette();
      final ansi = j['ansi'] as List<String>;
      ansi[1] = '#FF0000';
      ansi[2] = '#00FF00';
      ansi[3] = '#FFFF00';
      ansi[8] = '#555555';

      final p = TerminalPalette.fromJson(j)!;
      expect(p.err, const Color(0xFFFF0000));
      expect(p.ok, const Color(0xFF00FF00));
      expect(p.warn, const Color(0xFFFFFF00));
      expect(p.dim, const Color(0xFF555555));
    });

    test('cursor falls back to bright green, as a block cursor has since VT100',
        () {
      final j = _palette();
      (j['ansi'] as List)[10] = '#7DF5A8';
      expect(TerminalPalette.fromJson(j)!.cursor, const Color(0xFF7DF5A8));
    });

    test('an authored cursor wins over the fallback', () {
      final j = _palette()..['cursor'] = '#E8B84B';
      expect(TerminalPalette.fromJson(j)!.cursor, const Color(0xFFE8B84B));
    });

    test('accepts the AARRGGBB form the rest of the theme layer uses', () {
      final j = _palette()..['selection'] = '#2152F088';
      expect(TerminalPalette.fromJson(j)!.selection, const Color(0x2152F088));
    });
  });

  group('TerminalSpec.fromJson', () {
    test('absent block yields null so the caller falls back to the shell', () {
      expect(TerminalSpec.fromJson(null), isNull);
    });

    test('a bad palette fails the whole block', () {
      // Without sixteen usable colours there is no terminal to draw, so a
      // half-built block is worse than none.
      expect(
        TerminalSpec.fromJson({
          'appLabel': 'Terminal',
          'palette': _palette(count: 4),
        }),
        isNull,
      );
    });

    test('a missing appLabel fails the block, since the drawer needs a label',
        () {
      expect(
        TerminalSpec.fromJson({'palette': _palette()}),
        isNull,
      );
      expect(
        TerminalSpec.fromJson({'appLabel': '   ', 'palette': _palette()}),
        isNull,
      );
    });

    test('an empty prompt falls back to the default rather than rendering bare',
        () {
      final s = TerminalSpec.fromJson({
        'appLabel': 'Terminal',
        'prompt': '',
        'palette': _palette(),
      })!;
      expect(s.prompt, TerminalSpec.defaultPrompt);
    });

    test('scrollback is clamped, not trusted', () {
      // A CDN theme cannot decide your phone holds fifty thousand lines.
      TerminalSpec build(int n) => TerminalSpec.fromJson({
            'appLabel': 'Terminal',
            'scrollbackLines': n,
            'palette': _palette(),
          })!;

      expect(build(10).scrollbackLines, TerminalSpec.minScrollback);
      expect(build(999999).scrollbackLines, TerminalSpec.maxScrollback);
      expect(build(8000).scrollbackLines, 8000);
    });
  });

  group('TerminalAlias', () {
    Map<String, dynamic> spec(List<Map<String, dynamic>> aliases) => {
          'appLabel': 'Terminal',
          'palette': _palette(),
          'aliases': aliases,
        };

    test('names are lowercased, so the terminal is not fussy about case', () {
      final s = TerminalSpec.fromJson(spec([
        {'name': 'Tile', 'action': 'terminal.clear'},
      ]))!;
      expect(s.aliases.single.name, 'tile');
    });

    test('a bad alias drops only itself', () {
      // The other nine are still perfectly good. This is the opposite of the
      // palette rule, and deliberately so.
      final s = TerminalSpec.fromJson(spec([
        {'name': '', 'action': 'terminal.clear'},
        {'name': 'wipe', 'action': 'terminal.clear'},
        {'action': 'terminal.help'},
        {'name': 'tweak', 'action': 'launcher.openSettings'},
      ]))!;
      expect(s.aliases.map((a) => a.name), ['wipe', 'tweak']);
    });

    test('an unknown action id survives parse and fails to bind later', () {
      // The engine is a dumb carrier here, exactly like ThemeSpec.gestures.
      // validate_themes.sh is what rejects this over themes we wrote.
      final s = TerminalSpec.fromJson(spec([
        {'name': 'x', 'action': 'launcher.timeTravel'},
      ]))!;
      expect(s.aliases.single.actionId, 'launcher.timeTravel');
      expect(CommandAction.byId(s.aliases.single.actionId), isNull);
    });

    test('duplicates collapse, first declaration wins', () {
      final s = TerminalSpec.fromJson(spec([
        {'name': 'wipe', 'action': 'terminal.clear'},
        {'name': 'wipe', 'action': 'launcher.openSettings'},
      ]))!;
      expect(s.aliases.length, 1);
      expect(s.aliases.single.actionId, CommandAction.clearPane.id);
    });

    test('args keep scalars and drop everything else', () {
      // A nested structure would be a small language, and a small language in a
      // downloadable pack is how this stops being data.
      final s = TerminalSpec.fromJson(spec([
        {
          'name': 'x',
          'action': 'desklet.spawn',
          'args': {
            'kind': 'monitor',
            'page': 0,
            'live': true,
            'nested': {'shell': 'rm -rf /'},
            'list': ['rm', '-rf'],
          },
        },
      ]))!;
      expect(s.aliases.single.args, {'kind': 'monitor', 'page': 0, 'live': true});
    });
  });

  group('defaultForShell', () {
    test('every shell has a terminal, including the ones that are not tui', () {
      // Kali is shell: gnome and needs one, because the Terminal app is a
      // drawer entry and gnome distros have drawers.
      for (final shell in ShellKind.values) {
        final s = TerminalSpec.defaultForShell(shell);
        expect(s.palette.ansi.length, 16, reason: shell.name);
        expect(s.appLabel, isNotEmpty, reason: shell.name);
      }
    });

    test('aqua stays light, because Terminal.app Basic is black on white', () {
      final aqua = TerminalSpec.defaultForShell(ShellKind.aqua);
      expect(aqua.palette.bg, const Color(0xFFFFFFFF));
      expect(aqua.palette.fg, const Color(0xFF000000));
    });

    test('the tui default keeps the desaturated green background', () {
      // NOT black. That five-point shift is most of why the screen reads as a
      // terminal rather than as a dark-mode app, and it is the first thing
      // someone "corrects" to #000.
      expect(
        TerminalSpec.defaultForShell(ShellKind.tui).palette.bg,
        const Color(0xFF080D08),
      );
    });
  });

  group('ThemeSpec integration', () {
    Map<String, dynamic> theme(Map<String, dynamic>? terminal) => {
          'id': 'x',
          'name': 'X',
          'shell': 'gnome',
          'palette': {
            'bgTop': '#000000',
            'bgBottom': '#000000',
            'bar': '#000000',
            'dock': '#000000',
            'accent': '#FFFFFF',
            'onDark': '#FFFFFF',
          },
          if (terminal != null) 'terminal': terminal,
        };

    test('a theme predating the block still parses', () {
      expect(ThemeSpec.fromJson(theme(null)).terminal, isNull);
    });

    test('a theme carrying the block exposes it', () {
      final spec = ThemeSpec.fromJson(theme({
        'appLabel': 'Kali Terminal',
        'palette': _palette(),
      }));
      expect(spec.terminal, isNotNull);
      expect(spec.terminal!.appLabel, 'Kali Terminal');
    });

    test('a malformed block degrades to null rather than throwing', () {
      // A downgrade must never black-screen someone's home screen, which is the
      // contract the whole theme layer parses under.
      expect(ThemeSpec.fromJson(theme({'appLabel': 'X'})).terminal, isNull);
    });
  });

  group('the schema-to-enum contract', () {
    test('every CommandAction id is in the schema action enum, and vice versa',
        () {
      // The schema cannot read a Dart enum and the runtime keeps an unknown id
      // rather than throwing, so without this assertion the two drift and a
      // typo in a pack we wrote goes unnoticed. Same arrangement kindId has.
      //
      // Transcribed from schema/theme.schema.json, $defs.terminalAlias.action.
      const inSchema = {
        'launcher.openSettings',
        'launcher.openThemes',
        'desklet.spawn',
        'terminal.clear',
        'terminal.help',
        'remote.ssh',
        'remote.hosts',
        'remote.host',
        'terminal.open',
        'remote.key',
      };
      final inCode = CommandAction.values.map((a) => a.id).toSet();
      expect(inCode, inSchema);
    });
  });
}
