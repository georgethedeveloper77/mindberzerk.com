import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'global_prefs.dart';
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

  /// The GLOBAL bucket, above the per-theme store exactly like
  /// `selectedThemeId` is, and for the same reason: it is one fact about the
  /// launcher rather than one theme's worth of overrides. See [GlobalPrefs].
  ///
  /// Returns null when nothing has ever been written, which the notifier below
  /// uses to tell a first run from a user who has deliberately cleared every
  /// setting back to its distro default.
  static const globalKey = 'prefs.global.v1';

  Future<GlobalPrefs?> loadGlobal() async {
    final raw = await _store.read(globalKey);
    if (raw == null) return null;

    try {
      return GlobalPrefs.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Same contract as `load`: corrupt settings must not take the home screen
      // down. Distro defaults and carry on.
      return const GlobalPrefs();
    }
  }

  Future<void> saveGlobal(GlobalPrefs prefs) =>
      _store.write(globalKey, jsonEncode(prefs.toJson()));
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

  /// The theme's own file, WITHOUT the global overlay.
  ///
  /// Held because a write has to save the per-theme half unpolluted: saving the
  /// merged object would copy every global value into every theme's file, and
  /// the promotion would silently undo itself the first time the global bucket
  /// was cleared.
  LauncherPrefs _own = const LauncherPrefs();

  @override
  Future<LauncherPrefs> build() async {
    final repo = ref.watch(prefsRepositoryProvider);

    // Watched, not read: a global write invalidates this provider for EVERY
    // theme, which is what makes "set it once, it applies everywhere" true
    // rather than true-after-a-restart.
    final global = await ref.watch(globalPrefsProvider.future);

    _own = await repo.load(themeId);
    return global.applyTo(_own);
  }

  /// Optimistic: state moves immediately, disk catches up. A settings toggle
  /// that waits on a disk write before it flips feels broken.
  ///
  /// ─── WHY THIS SPLITS THE WRITE ────────────────────────────────────────
  ///
  /// Callers hand in a mutation over the merged prefs and know nothing about
  /// there being two stores. That is deliberate: there are fifty-odd
  /// `copyWith` call sites across settings, the drawer and the shells, and
  /// requiring each to know which bucket its field lives in would mean fifty
  /// chances to pick wrong, silently, with the symptom being a setting that
  /// only sticks on one distro.
  ///
  /// So the routing happens here, once, by comparing the promoted fields before
  /// and after. See [promotedChanged].
  Future<void> edit(LauncherPrefs Function(LauncherPrefs) mutate) async {
    final repo = ref.read(prefsRepositoryProvider);

    // hasValue, not asData. asData is null while this notifier RELOADS, and a
    // global write reloads it, so two edits in quick succession could see null
    // here and mutate `const LauncherPrefs()` instead of the real prefs. That
    // would not be a stale read, it would be a wipe: every folder, every
    // arrangement, every pinned app, replaced by defaults and then saved.
    final snapshot = state;
    final current =
        snapshot.hasValue ? snapshot.requireValue : const LauncherPrefs();
    final next = mutate(current);

    state = AsyncData(next);

    // ── THE THEME'S HALF GOES FIRST, AND THE ORDER IS THE POINT ──────────
    //
    // Writing global first would invalidate this provider (build watches it),
    // so `build` would re-run and reload the theme file from disk BEFORE the
    // line below had written it. The non-promoted half of this edit would
    // vanish from state while sitting correctly on disk, and would not come
    // back until something else forced a reload. Saving first means the reload
    // reads the file this edit produced.
    //
    // The promoted fields in that file are left exactly as they were, because
    // they are ignored on load and rewriting them would make the file look
    // authoritative about settings it no longer owns.
    _own = _withOwn(_own, next);
    await repo.save(themeId, _own);

    if (promotedChanged(current, next)) {
      // Straight to the notifier so every other theme's prefs re-resolve too.
      await ref.read(globalPrefsProvider.notifier).write(GlobalPrefs.from(next));
    }
  }

  /// Take the non-promoted fields from [merged] and leave [own]'s promoted
  /// fields untouched.
  ///
  /// Implemented as "overlay own's promoted fields back onto merged", which
  /// reuses [GlobalPrefs.applyTo] rather than enumerating the per-theme fields
  /// a second time. Enumerating them twice is how a newly added field ends up
  /// saved in one path and dropped in the other.
  static LauncherPrefs _withOwn(LauncherPrefs own, LauncherPrefs merged) =>
      GlobalPrefs.from(own).applyTo(merged);

  Future<void> resetAll() async {
    state = const AsyncData(LauncherPrefs());
    _own = const LauncherPrefs();
    await ref.read(prefsRepositoryProvider).reset(themeId);
  }
}

/// The launcher's own settings, shared by every distro. See [GlobalPrefs].
class GlobalPrefsNotifier extends AsyncNotifier<GlobalPrefs> {
  @override
  Future<GlobalPrefs> build() async {
    final repo = ref.watch(prefsRepositoryProvider);
    final stored = await repo.loadGlobal();
    if (stored != null) return stored;

    // ── ONE-TIME MIGRATION ────────────────────────────────────────────────
    //
    // Nothing has ever been written here, so this is either a fresh install or
    // an existing user upgrading into the split. Seed from the ACTIVE theme's
    // file, which is the one whose settings they have actually been looking at,
    // so an upgrade preserves the icon shape and label length they chose rather
    // than resetting both to distro defaults on the first launch after update.
    //
    // A fresh install reads an absent file, gets all-null, and writes an empty
    // bucket. Harmless, and it means the migration runs exactly once either way.
    final themeId = await ref.watch(selectedThemeIdProvider.future);
    final seed = themeId == null
        ? const GlobalPrefs()
        : GlobalPrefs.from(await repo.load(themeId));

    await repo.saveGlobal(seed);
    return seed;
  }

  Future<void> write(GlobalPrefs next) async {
    state = AsyncData(next);
    await ref.read(prefsRepositoryProvider).saveGlobal(next);
  }
}

final globalPrefsProvider =
    AsyncNotifierProvider<GlobalPrefsNotifier, GlobalPrefs>(
  GlobalPrefsNotifier.new,
);

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
