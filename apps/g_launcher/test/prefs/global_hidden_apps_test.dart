import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:g_launcher/data/prefs/global_prefs.dart';
import 'package:g_launcher/data/prefs/launcher_prefs.dart';
import 'package:g_launcher/data/prefs/prefs_repository.dart';

void main() {
  group('hidden apps are global (GlobalPrefs schema 3)', () {
    test('the global set overrides every theme file', () {
      const theme = LauncherPrefs(hiddenApps: {'ubuntu/only'});
      final global = const GlobalPrefs().withHiddenApps({'a', 'b'});
      expect(global.applyTo(theme).hiddenApps, {'a', 'b'});
    });

    test('a reset bucket hides nothing', () {
      const theme = LauncherPrefs(hiddenApps: {'stale'});
      expect(const GlobalPrefs().applyTo(theme).hiddenApps, isEmpty);
    });

    test('v3 top-up fills only an empty bucket', () {
      expect(const GlobalPrefs().withV3HiddenApps({'x'}).hiddenApps, {'x'});
      final kept = const GlobalPrefs().withHiddenApps({'y'});
      expect(kept.withV3HiddenApps({'x'}).hiddenApps, {'y'});
    });

    test('equality ignores set order and survives JSON', () {
      final a = const GlobalPrefs().withHiddenApps({'b', 'a'});
      final b = GlobalPrefs.fromJson(
        jsonDecode(jsonEncode(
                const GlobalPrefs().withHiddenApps({'a', 'b'}).toJson()))
            as Map<String, dynamic>,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('union across every stored distro', () async {
      final store = MemoryPrefsStore();
      final repo = PrefsRepository(store);
      await repo.save('ubuntu', const LauncherPrefs(hiddenApps: {'tiktok'}));
      await repo.save('kali', const LauncherPrefs(hiddenApps: {'bank'}));
      expect(await repo.hiddenAcrossThemes(), {'tiktok', 'bank'});
    });
  });
}
