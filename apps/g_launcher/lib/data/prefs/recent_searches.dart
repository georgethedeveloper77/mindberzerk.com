import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'prefs_repository.dart';

/// Recent search terms from the app drawer's search page, most-recent-first.
///
/// GLOBAL, not per-theme. [LauncherPrefs] is keyed by theme so each distro keeps
/// its own layout; your search history is your behaviour, not a theme
/// customisation. Storing it per-theme would wipe it every time you switched
/// distro, which nobody expects. So it lives ABOVE the per-theme store, under
/// one top-level key, exactly like `selectedThemeId`.
///
/// Plain Riverpod 3 AsyncNotifier, optimistic writes (state moves now, disk
/// catches up), same contract as [SelectedThemeNotifier].
const _recentSearchesKey = 'recentSearches.v1';

/// How many terms we keep. The search page shows a handful; beyond that the
/// list stops being "recent" and becomes clutter you have to clear.
const _recentSearchesCap = 8;

class RecentSearchesNotifier extends AsyncNotifier<List<String>> {
  @override
  Future<List<String>> build() async {
    final raw = await ref.watch(prefsStoreProvider).read(_recentSearchesKey);
    if (raw == null) return const <String>[];
    try {
      final list = (jsonDecode(raw) as List).cast<String>();
      // Cap on read too: a file hand-edited, or written by a future build with a
      // larger cap, must not blow the list up here.
      return list.take(_recentSearchesCap).toList();
    } catch (_) {
      // Corrupt history is not worth taking anything down for. Start empty.
      return const <String>[];
    }
  }

  Future<void> _persist(List<String> list) =>
      ref.read(prefsStoreProvider).write(_recentSearchesKey, jsonEncode(list));

  /// Record a term the user searched. Trims, ignores blanks, de-dupes
  /// case-insensitively (re-searching a term moves it to the front instead of
  /// stacking a duplicate), and caps the list.
  Future<void> record(String query) async {
    final term = query.trim();
    if (term.isEmpty) return;

    final current = state.asData?.value ?? const <String>[];
    final next = <String>[
      term,
      for (final e in current)
        if (e.toLowerCase() != term.toLowerCase()) e,
    ].take(_recentSearchesCap).toList();

    state = AsyncData(next);
    await _persist(next);
  }

  /// Drop one term — the chip's X.
  Future<void> remove(String term) async {
    final current = state.asData?.value ?? const <String>[];
    if (!current.contains(term)) return;
    final next = current.where((e) => e != term).toList();
    state = AsyncData(next);
    await _persist(next);
  }

  /// Clear the lot — the trash icon. Deletes the key so a cleared history is
  /// indistinguishable from a fresh install (both read back as empty).
  Future<void> clear() async {
    if ((state.asData?.value ?? const <String>[]).isEmpty) return;
    state = const AsyncData(<String>[]);
    await ref.read(prefsStoreProvider).delete(_recentSearchesKey);
  }
}

/// Global recent search terms, most-recent-first. Empty before any search.
final recentSearchesProvider =
    AsyncNotifierProvider<RecentSearchesNotifier, List<String>>(
  RecentSearchesNotifier.new,
);
