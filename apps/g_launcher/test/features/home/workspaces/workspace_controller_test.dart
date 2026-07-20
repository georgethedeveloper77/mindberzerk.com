import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g_launcher/data/prefs/prefs_repository.dart';
import 'package:g_launcher/engine/theme_engine.dart';
import 'package:g_launcher/engine/theme_spec.dart';
import 'package:g_launcher/features/home/workspaces/workspace_controller.dart';

/// A minimal active theme so the per-theme providers resolve. workspaceCount is
/// no longer a standalone value: it is read from and written to the ACTIVE
/// theme's prefs JSON, so a container with no theme has nothing to count. These
/// tests seed one.
ThemeSpec _spec() => ThemeSpec.fromJson({
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
      'icons': {'treatment': 'roundedSquare'},
      'minAppVersion': 6,
    });

void main() {
  late ProviderContainer c;

  setUp(() {
    c = ProviderContainer(overrides: [
      // Real per-theme prefs, backed by memory — no device needed.
      prefsStoreProvider.overrideWithValue(MemoryPrefsStore()),
      // Skip asset loading: hand the engine a resolved spec directly.
      activeThemeSpecProvider.overrideWith((ref) => _spec()),
    ]);
  });
  tearDown(() => c.dispose());

  /// Force the async deps (theme spec + its prefs) to resolve, so the sync
  /// workspace notifiers read real values instead of the loading-time fallback.
  Future<void> warm() async {
    await c.read(activeThemeSpecProvider.future);
    await c.read(prefsProvider('ubuntu-24-04').future);
  }

  test('starts on workspace 1 and does not throw on first read', () async {
    await warm();
    // The regression test. The old build() read `state` before it existed and
    // threw "Tried to read the state of an uninitialized provider".
    expect(c.read(activeWorkspaceProvider), 0);
  });

  test('goTo clamps to the available range', () async {
    await warm();
    final ws = c.read(activeWorkspaceProvider.notifier);
    ws.goTo(2);
    expect(c.read(activeWorkspaceProvider), 2);

    ws.goTo(99);
    expect(c.read(activeWorkspaceProvider), 2, reason: 'count is 3');

    ws.goTo(-4);
    expect(c.read(activeWorkspaceProvider), 0);
  });

  test('shrinking the count clamps the active workspace', () async {
    await warm();
    // Listeners only fire while something is subscribed.
    final sub = c.listen(activeWorkspaceProvider, (_, __) {});
    addTearDown(sub.close);

    c.read(activeWorkspaceProvider.notifier).goTo(2);
    expect(c.read(activeWorkspaceProvider), 2);

    await c.read(workspaceCountProvider.notifier).set(1);
    expect(c.read(activeWorkspaceProvider), 0,
        reason: 'workspace 3 no longer exists');
  });

  test('growing the count leaves the active workspace alone', () async {
    await warm();
    final sub = c.listen(activeWorkspaceProvider, (_, __) {});
    addTearDown(sub.close);

    c.read(activeWorkspaceProvider.notifier).goTo(1);
    await c.read(workspaceCountProvider.notifier).set(5);

    // The old ref.watch version would have reset this to 0 — a rebuilt notifier
    // throws its state away.
    expect(c.read(activeWorkspaceProvider), 1);
  });

  test('count is capped at 5 and floored at 1', () async {
    await warm();
    final count = c.read(workspaceCountProvider.notifier);
    await count.set(99);
    expect(c.read(workspaceCountProvider), 5);
    await count.set(0);
    expect(c.read(workspaceCountProvider), 1);
  });

  test('reset returns to workspace 1', () async {
    await warm();
    final ws = c.read(activeWorkspaceProvider.notifier);
    ws.goTo(2);
    ws.reset();
    expect(c.read(activeWorkspaceProvider), 0);
  });
}
