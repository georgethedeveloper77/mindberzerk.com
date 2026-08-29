import 'package:flutter_test/flutter_test.dart';
import 'package:g_launcher/features/terminal/term_command.dart';
import 'package:g_launcher/features/terminal/term_host.dart';
import 'package:g_launcher/features/terminal/term_output.dart';
import 'package:g_launcher/features/terminal/term_path.dart';
import 'package:g_launcher/features/terminal/term_registry.dart';
import 'package:g_launcher/features/terminal/term_vfs.dart';

import 'fake_host.dart';

void main() {
  late FakeHost host;
  late TermContext context;
  const TermEngine engine = TermEngine();

  setUp(() {
    host = FakeHost();
    context = TermContext(
      cwd: TermPath.appsRoot,
      vfs: TermVfs(host),
      host: host,
      aliases: <String, String>{},
      history: <String>[],
    );
  });

  Future<List<String>> run(String line) async {
    final TermResult result = await engine.execute(line, context);
    return result.textLines.map((TermLine l) => l.plain).toList();
  }

  group('the two roots', () {
    test('slash holds exactly the two namespaces', () async {
      final List<String> out = await run('ls /');
      expect(out, <String>['apps/', 'sdcard/']);
    });

    test('the shell starts in /apps, so the first ls needs no grant', () async {
      host.granted = false;
      final List<String> out = await run('ls');
      expect(out, contains('firefox'));
    });

    test('an app carries no trailing slash, because cd would refuse it',
        () async {
      final List<String> listing = await run('ls');
      expect(listing, <String>['firefox', 'signal', 'settings']);

      // The two halves of the same fact. A slash in the listing above would be
      // a promise this next line breaks.
      final List<String> entered = await run('cd /apps/firefox');
      expect(entered.first, contains('not a directory'));
    });

    test('a real folder does carry one', () async {
      final List<String> out = await run('ls /');
      expect(out, <String>['apps/', 'sdcard/']);
    });

    test('apps list as entries and cat reads one', () async {
      final List<String> out = await run('cat /apps/firefox');
      expect(out.first, contains('Firefox'));
      expect(out.join('\n'), contains('org.mozilla.firefox'));
    });

    test('a bare app name still launches, behind the command table', () async {
      await run('firefox');
      expect(host.launched, <String>['org.mozilla.firefox']);
    });

    test('settings is the command, not the app, which is the whole point',
        () async {
      await run('settings');
      expect(host.launched, isEmpty);
    });
  });

  group('cd', () {
    test('bare cd goes to storage', () async {
      await run('cd');
      expect(context.cwd, TermPath.filesRoot);
    });

    test('an app is a leaf and cannot be entered', () async {
      final List<String> out = await run('cd /apps/firefox');
      expect(out.first, contains('not a directory'));
      expect(context.cwd, TermPath.appsRoot);
    });

    test('a chain sees the folder the earlier stage moved to', () async {
      final List<String> out = await run('cd ~ && cd Download && ls');
      expect(context.cwd, const TermPath(<String>['sdcard', 'Download']));
      expect(out, contains('notes.txt'));
    });
  });

  group('the wrong namespace is a sentence, not a silence', () {
    test('rm in /apps names the verb that works', () async {
      final List<String> out = await run('rm /apps/firefox');
      expect(out.first, contains('installed, not written'));
      expect(out.last, contains('pm uninstall'));
    });

    test('cp out of /apps refuses with the reason', () async {
      final List<String> out = await run('cp /apps/firefox ~/Download');
      expect(out.first, contains('not a file you can move'));
    });

    test('writing to slash explains what slash is', () async {
      final List<String> out = await run('mkdir /nope');
      expect(out.first, contains('namespaces'));
    });

    test('without a grant, storage asks rather than failing silently',
        () async {
      host.granted = false;
      final List<String> out = await run('ls ~');
      expect(out.first, contains('no folder granted'));
    });
  });

  group('pipes and chains', () {
    test('grep filters on plain text', () async {
      final List<String> out = await run('apps | grep signal');
      expect(out.length, 1);
      expect(out.first, contains('Signal'));
    });

    test('a miss inside a pipe says so rather than printing nothing', () async {
      final List<String> out = await run('apps | grep zzz');
      expect(out, <String>['no match']);
    });

    test('wc counts what reached it', () async {
      final List<String> out = await run('apps | wc -l');
      expect(out, <String>['3']);
    });

    test('head reads a file at the head of a line', () async {
      final List<String> out = await run('cd ~/Download && head -2 notes.txt');
      expect(out, <String>['one', 'two']);
    });

    test('head filters when it follows a pipe', () async {
      final List<String> out = await run('apps | head 1');
      expect(out.length, 1);
    });

    test('a command that cannot read a pipe says which ones can', () async {
      final List<String> out = await run('apps | ls');
      expect(out.first, contains('cannot read a pipe'));
    });
  });

  group('a filter sees the whole list, not a truncated one', () {
    setUp(() {
      // A phone with 247 apps, which is ordinary. Zoom sits at 112, well past
      // where the old forty-row cap cut the list off.
      host.manyApps = <TermApp>[
        for (var i = 0; i < 247; i++)
          TermApp(
            slug: i == 112 ? 'zoom' : 'app-$i',
            label: i == 112 ? 'Zoom' : 'App $i',
            packageName: i == 112 ? 'us.zoom.videomeetings' : 'com.example.a$i',
          ),
      ];
    });

    test('apps lists every one', () async {
      final List<String> out = await run('apps');
      expect(out.length, 247);
    });

    test('grep finds an app past where the cap used to be', () async {
      final List<String> out = await run('apps | grep zoom');
      expect(out.length, 1);
      expect(out.first, contains('Zoom'));
    });

    test('wc counts all of them', () async {
      final List<String> out = await run('apps | wc -l');
      expect(out, <String>['247']);
    });

    test('head still takes the first few', () async {
      final List<String> out = await run('apps | head 5');
      expect(out.length, 5);
    });

    test('ls in /apps lists every one too', () async {
      final List<String> out = await run('ls');
      expect(out.length, 247);
    });

    test('a runaway is trimmed once, at the end, and says how much', () async {
      host.manyApps = <TermApp>[
        for (var i = 0; i < kOutputCeiling + 30; i++)
          TermApp(
            slug: 'app-$i',
            label: 'App $i',
            packageName: 'com.example.a$i',
          ),
      ];
      final List<String> out = await run('apps');
      expect(out.length, kOutputCeiling + 1);
      expect(out.last, '30 more lines not shown');
    });
  });

  group('misses', () {
    test('a near miss suggests the real command', () async {
      final List<String> out = await run('dff');
      expect(out.first, contains('command not found'));
      expect(out.last, contains('df'));
    });

    test('a wild miss suggests nothing rather than something wrong', () async {
      final List<String> out = await run('qqqqqqzzz');
      expect(out.last, contains('? lists every command'));
    });
  });

  group('readings', () {
    test('df reports what was measured', () async {
      final List<String> out = await run('df');
      expect(out.join('\n'), contains('119G'));
    });

    test('a null reading prints no row at all', () async {
      final List<String> out = await run('net');
      // The fake reports no upload rate, so there must be no up row and no
      // placeholder standing in for it.
      expect(out.join('\n').contains('up '), isFalse);
      expect(out.join('\n'), contains('wifi'));
    });

    test('a refused uninstall prints the reason the system gave', () async {
      host.uninstallRefusal = 'a preinstalled app cannot be uninstalled';
      final List<String> out = await run('pm uninstall settings');
      expect(out.first, contains('preinstalled'));
      expect(host.uninstalled, isEmpty);
    });

    test('du omits what it could not measure and says how many', () async {
      final List<String> out = await run('cd ~ && du');
      expect(out.join('\n'), contains('total in ~'));
    });
  });

  group('aliases', () {
    test('an alias set in one line is usable in the next', () async {
      await run("alias ll='ls -l'");
      expect(context.aliases['ll'], 'ls -l');
      final List<String> out = await run('ll');
      expect(out.join('\n'), contains('org.mozilla.firefox'));
    });
  });

  group('nothing claims to have happened when it did not', () {
    test('an unwired torch says so instead of blaming the hardware', () async {
      host.unwiredNames = <String>{'torch'};
      final List<String> out = await run('torch on');
      expect(out.first, contains('not available in this build'));
      expect(out.first.contains('flash unit'), isFalse);
      expect(host.torchOn, isFalse);
    });

    test('a wired torch reports the state it set', () async {
      final List<String> out = await run('torch on');
      expect(out.first, contains('torch'));
      expect(host.torchOn, isTrue);
    });

    test('settings opens the page rather than printing that it did', () async {
      final List<String> out = await run('settings');
      expect(host.opened, <TermLauncherPage>[TermLauncherPage.settings]);
      expect(out.first, contains('opening'));
    });

    test('a page this build cannot reach says where it lives', () async {
      // `wall` is hidden from every discovery surface, but typing it must still
      // resolve and explain itself rather than answering "command not found".
      host.pageRefusal = 'the wallpaper and icon pickers live inside Settings';
      final List<String> out = await run('wall');
      expect(out.first, contains('inside Settings'));
      expect(TermRegistry.instance.lookup('wall'), isNotNull);
    });

    test('a terminal with no navigator refuses rather than pretending',
        () async {
      host.hasNavigator = false;
      final List<String> out = await run('themes');
      expect(out.first, contains('no navigator'));
      expect(host.opened, isEmpty);
    });
  });

  test('clear empties the scrollback through a flag, not a chunk', () async {
    final TermResult result = await engine.execute('clear', context);
    expect(result.clearScrollback, isTrue);
    expect(result.chunks, isEmpty);
  });

  test('every registered command has a help line and a unique name', () {
    final Set<String> names = <String>{};
    for (final TermCommand command in TermRegistry.instance.all) {
      expect(command.help.trim(), isNotEmpty, reason: command.name);
      expect(names.add(command.name), isTrue, reason: 'duplicate ${command.name}');
    }
  });
}
