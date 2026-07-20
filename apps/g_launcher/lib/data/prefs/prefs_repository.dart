import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'launcher_prefs.dart';

/// Storage backend. An interface so the tests can run without a platform
/// channel — SharedPreferences needs a real Android under it, and a prefs test
/// that requires a device is a test that never gets run.
abstract class PrefsStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SharedPrefsStore implements PrefsStore {
  SharedPrefsStore(this._prefs);
  final SharedPreferences _prefs;

  @override
  Future<String?> read(String key) async => _prefs.getString(key);

  @override
  Future<void> write(String key, String value) async =>
      _prefs.setString(key, value);

  @override
  Future<void> delete(String key) async => _prefs.remove(key);
}

/// In-memory. Tests, and nothing else.
class MemoryPrefsStore implements PrefsStore {
  final Map<String, String> _data = {};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async => _data[key] = value;

  @override
  Future<void> delete(String key) async => _data.remove(key);
}

/// Overridden in main() once SharedPreferences has resolved. Left throwing so a
/// missing override fails loudly at startup rather than silently persisting
/// nothing — a launcher that forgets your settings on every reboot and never
/// says why is a miserable bug to chase.
final prefsStoreProvider = Provider<PrefsStore>((ref) {
  throw UnimplementedError('prefsStoreProvider must be overridden in main()');
});

class PrefsRepository {
  PrefsRepository(this._store);
  final PrefsStore _store;

  /// Keyed BY THEME. Ubuntu's grid and KDE's grid are different settings, and
  /// switching between them must not clobber either. Plan §5.3.
  String _key(String themeId) => 'prefs.v1.$themeId';

  Future<LauncherPrefs> load(String themeId) async {
    final raw = await _store.read(_key(themeId));
    if (raw == null) return const LauncherPrefs();

    try {
      return LauncherPrefs.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Corrupt prefs must never take the home screen down with them. Defaults
      // and carry on; the user loses their grid size, not their phone.
      return const LauncherPrefs();
    }
  }

  Future<void> save(String themeId, LauncherPrefs prefs) =>
      _store.write(_key(themeId), jsonEncode(prefs.toJson()));

  Future<void> reset(String themeId) => _store.delete(_key(themeId));
}

final prefsRepositoryProvider = Provider<PrefsRepository>(
  (ref) => PrefsRepository(ref.watch(prefsStoreProvider)),
);

/// The live prefs for one theme. Watch it; mutate through the notifier.
///
/// Riverpod 3 dropped FamilyAsyncNotifier: a family notifier is a plain
/// AsyncNotifier whose CONSTRUCTOR takes the family argument. There is no `arg`
/// getter anymore — hold it as a field.
class PrefsNotifier extends AsyncNotifier<LauncherPrefs> {
  PrefsNotifier(this.themeId);

  final String themeId;

  @override
  Future<LauncherPrefs> build() =>
      ref.watch(prefsRepositoryProvider).load(themeId);

  /// Optimistic: state moves immediately, disk catches up. A settings toggle
  /// that waits on a disk write before it flips feels broken.
  Future<void> edit(LauncherPrefs Function(LauncherPrefs) mutate) async {
    final current = state.asData?.value ?? const LauncherPrefs();
    final next = mutate(current);
    state = AsyncData(next);
    await ref.read(prefsRepositoryProvider).save(themeId, next);
  }

  Future<void> resetAll() async {
    state = const AsyncData(LauncherPrefs());
    await ref.read(prefsRepositoryProvider).reset(themeId);
  }
}

final prefsProvider =
    AsyncNotifierProvider.family<PrefsNotifier, LauncherPrefs, String>(
  PrefsNotifier.new,
);

// ─────────────────────────────────────────────────────────────────────────────
// Theme SELECTION.
//
// This is deliberately NOT a LauncherPrefs field. LauncherPrefs is keyed BY
// theme (`prefs.v1.<themeId>`): it holds one theme's overrides. The selection
// is the single pointer that decides WHICH theme's prefs are live, so it must
// live ABOVE the per-theme store. Putting it inside a theme's prefs would be
// circular: you'd need to know the active theme to read which theme is active.
//
// One plain string under one top-level key. Empty/absent = nothing chosen yet,
// which the engine resolves to bundled Ubuntu.
// ─────────────────────────────────────────────────────────────────────────────

const _selectedThemeKey = 'selectedThemeId.v1';

class SelectedThemeNotifier extends AsyncNotifier<String?> {
  @override
  Future<String?> build() => ref.watch(prefsStoreProvider).read(_selectedThemeKey);

  /// Optimistic, same contract as [PrefsNotifier.edit]: state moves now, disk
  /// catches up. The shell watches [activeThemeSpecProvider] (which watches
  /// this), so the desktop repaints the instant the state flips rather than
  /// waiting on a write.
  Future<void> select(String themeId) async {
    state = AsyncData(themeId);
    await ref.read(prefsStoreProvider).write(_selectedThemeKey, themeId);
  }

  /// Back to "nothing chosen" → the engine falls to bundled Ubuntu.
  Future<void> clear() async {
    state = const AsyncData(null);
    await ref.read(prefsStoreProvider).delete(_selectedThemeKey);
  }
}

/// The globally-selected theme id, or null before the user has ever picked one.
final selectedThemeIdProvider =
    AsyncNotifierProvider<SelectedThemeNotifier, String?>(
  SelectedThemeNotifier.new,
);
