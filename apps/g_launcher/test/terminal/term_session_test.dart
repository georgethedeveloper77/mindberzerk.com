import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g_launcher/features/terminal/term_command.dart';
import 'package:g_launcher/features/terminal/term_output.dart';
import 'package:g_launcher/features/terminal/term_path.dart';
import 'package:g_launcher/features/terminal/term_registry.dart';
import 'package:g_launcher/features/terminal/term_session.dart';
import 'package:g_launcher/features/terminal/term_vfs.dart';

import 'fake_host.dart';

/// Three bugs that a single-command test cannot see, because all three are
/// about what happens the SECOND time, or the twentieth.
void main() {
  group('the folder picker is opened once per line', () {
    late FakeHost host;
    late TermVfs vfs;
    late TermContext context;
    const TermEngine engine = TermEngine();

    setUp(() {
      // Declines the grant, which is the case that used to loop.
      host = FakeHost(granted: false);
      vfs = TermVfs(host);
      context = TermContext(
        cwd: TermPath.filesRoot,
        vfs: vfs,
        host: host,
        aliases: <String, String>{},
        history: <String>[],
      );
    });

    test('one storage verb asks once', () async {
      await engine.execute('ls', context);
      expect(host.grantRequests, 1);
    });

    test('a walk that touches many folders still asks once', () async {
      // find recurses, and every level used to reach _requireGrant on its own.
      await engine.execute('find img', context);
      expect(host.grantRequests, 1);
    });

    test('a chain asks once across all of its stages', () async {
      await engine.execute('ls && du && tree', context);
      expect(host.grantRequests, 1);
    });

    test('but a NEW line asks again, because the user asked again', () async {
      await engine.execute('ls', context);
      await engine.execute('ls', context);
      expect(host.grantRequests, 2);
    });

    test('and a host that already holds a folder is never asked', () async {
      host.granted = true;
      await engine.execute('ls && du && find img', context);
      // filesGranted short circuits the gate before it can ask.
      expect(host.grantRequests, 0);
    });
  });

  group('the session writes only what changed', () {
    late FakeHost host;
    late ProviderContainer container;

    setUp(() {
      host = FakeHost();
      container = ProviderContainer(
        overrides: [termHostProvider.overrideWithValue(host)],
      );
      addTearDown(container.dispose);
    });

    Future<void> settle() => Future<void>.delayed(Duration.zero);

    test('an ordinary command writes no aliases', () async {
      final TermSession session =
          container.read(termSessionProvider.notifier);
      await settle();
      await session.run('ls');
      await session.run('df');
      await session.run('apps');
      expect(host.aliasWrites, 0);
    });

    test('setting an alias writes once, and only then', () async {
      final TermSession session =
          container.read(termSessionProvider.notifier);
      await settle();
      await session.run('ls');
      expect(host.aliasWrites, 0);
      await session.run("alias ll='ls -l'");
      expect(host.aliasWrites, 1);
      await session.run('ll');
      expect(host.aliasWrites, 1);
    });

    test('the run count stops being written once nothing reads it', () async {
      final TermSession session =
          container.read(termSessionProvider.notifier);
      await settle();
      for (var i = 0; i < kTeachingRuns + 5; i++) {
        await session.run('date');
      }
      // One write per run up to the boundary, one past it, and then silence.
      expect(host.runCountWrites, kTeachingRuns);
      expect(container.read(termSessionProvider).showsSuggestions, isFalse);
    });
  });

  group('a command that beats the restore does not lose its work', () {
    test('an alias set before the disk read survives it', () async {
      final FakeHost host = FakeHost();
      host.savedAliases['gg'] = 'apps | grep g';

      final ProviderContainer container = ProviderContainer(
        overrides: [termHostProvider.overrideWithValue(host)],
      );
      addTearDown(container.dispose);

      final TermSession session = container.read(termSessionProvider.notifier);
      // Deliberately NOT settled: this runs inside the window where the disk
      // read has not landed, which is the whole bug. `run` now waits for it.
      await session.run("alias ll='ls -l'");

      final TermSessionState state = container.read(termSessionProvider);
      expect(state.aliases['ll'], 'ls -l', reason: 'the user typed this');
      expect(state.aliases['gg'], 'apps | grep g', reason: 'this was on disk');
    });
  });

  test('the shell starts in /apps, not in storage', () {
    final FakeHost host = FakeHost(granted: false);
    final ProviderContainer container = ProviderContainer(
      overrides: [termHostProvider.overrideWithValue(host)],
    );
    addTearDown(container.dispose);
    expect(container.read(termSessionProvider).cwd, TermPath.appsRoot);
  });

  test('scrollback keeps the folder each command ran in', () async {
    final FakeHost host = FakeHost();
    final ProviderContainer container = ProviderContainer(
      overrides: [termHostProvider.overrideWithValue(host)],
    );
    addTearDown(container.dispose);

    final TermSession session = container.read(termSessionProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    await session.run('cd ~');

    final TermSessionState state = container.read(termSessionProvider);
    expect(state.cwd, TermPath.filesRoot);
    // The echo belongs where it was TYPED, which was /apps.
    expect(state.blocks.single.cwd, TermPath.appsRoot);
  });

  test('clear empties the blocks and keeps the history', () async {
    final FakeHost host = FakeHost();
    final ProviderContainer container = ProviderContainer(
      overrides: [termHostProvider.overrideWithValue(host)],
    );
    addTearDown(container.dispose);

    final TermSession session = container.read(termSessionProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    await session.run('apps');
    await session.run('clear');

    final TermSessionState state = container.read(termSessionProvider);
    expect(state.blocks, isEmpty, reason: 'clear leaves an empty screen');
    expect(state.history, <String>['apps', 'clear']);
  });

  test('unwired commands reach the session so the view can hide them', () async {
    final FakeHost host = FakeHost();
    host.unwiredNames = <String>{'torch', 'vol'};
    final ProviderContainer container = ProviderContainer(
      overrides: [termHostProvider.overrideWithValue(host)],
    );
    addTearDown(container.dispose);

    final TermSessionState state = container.read(termSessionProvider);
    expect(state.offers('torch'), isFalse);
    expect(state.offers('ls'), isTrue);

    final List<TermCommand> suggested =
        container.read(termSessionProvider.notifier).suggestions();
    expect(suggested.map((TermCommand c) => c.name), isNot(contains('torch')));
    expect(suggested.length, 6);
    // And it still resolves, so typing it explains itself.
    expect(TermRegistry.instance.lookup('torch'), isNotNull);
  });

  test('the scrollback is capped rather than growing forever', () async {
    final FakeHost host = FakeHost();
    final ProviderContainer container = ProviderContainer(
      overrides: [termHostProvider.overrideWithValue(host)],
    );
    addTearDown(container.dispose);

    final TermSession session = container.read(termSessionProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    for (var i = 0; i < kScrollbackLimit + 10; i++) {
      await session.run('echo $i');
    }

    final TermSessionState state = container.read(termSessionProvider);
    expect(state.blocks.length, kScrollbackLimit);
    // The OLDEST are the ones dropped.
    expect(state.blocks.first.line, 'echo 10');
    expect(
      state.blocks.last.chunks
          .whereType<TermTextChunk>()
          .single
          .lines
          .single
          .plain,
      '${kScrollbackLimit + 9}',
    );
  });
}
