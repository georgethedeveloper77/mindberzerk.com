import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/prefs/prefs_repository.dart';
import 'bangs.dart';
import 'command_router.dart';
import 'search_engines.dart';

/// The person's search choices: which engine the web row uses, and their
/// own bangs.
///
/// Launcher-wide, like the hidden set: a bang typed on Kali works on Garuda.
/// Stored under its own key rather than inside GlobalPrefs, so adding a
/// field here never needs a GlobalPrefs schema bump. Backups carry the key
/// through `PrefsBackup.extraKeys`.
class SearchSettings {
  const SearchSettings({
    this.engineId = 'google',
    this.bangs = const [],
  });

  final String engineId;

  /// In the order they were added. Keys are unique.
  final List<Bang> bangs;

  SearchEngine get engine => SearchEngine.byId(engineId);

  SearchSettings withEngine(String id) =>
      SearchSettings(engineId: SearchEngine.byId(id).id, bangs: bangs);

  /// Adds [bang], or replaces the one it edits. [replacing] is the key the
  /// bang had before an edit, so renaming `!np` to `!npm` does not leave both.
  SearchSettings withBang(Bang bang, {String? replacing}) {
    final target = replacing ?? bang.key;
    final next = <Bang>[];
    var placed = false;
    for (final b in bangs) {
      if (b.key == target) {
        // Edited in place, so the list keeps the order it was built in.
        next.add(bang);
        placed = true;
      } else if (b.key != bang.key) {
        // A different entry already using the new key loses to the edit.
        next.add(b);
      }
    }
    if (!placed) next.add(bang);
    return SearchSettings(engineId: engineId, bangs: next);
  }

  SearchSettings withoutBang(String key) => SearchSettings(
        engineId: engineId,
        bangs: [
          for (final b in bangs)
            if (b.key != key) b,
        ],
      );

  /// Whether one more bang may be added (an edit is always allowed).
  bool get canAdd => bangs.length < BangRules.maxCustom;

  Map<String, dynamic> toJson() => {
        'engine': engineId,
        'bangs': [for (final b in bangs) b.toJson()],
      };

  /// Tolerant: an invalid bang is dropped, duplicates keep the first, and
  /// the list is capped, so a corrupt or hand-edited value still loads.
  static SearchSettings fromJson(Map<String, dynamic> j) {
    final seen = <String>{};
    final bangs = <Bang>[];
    for (final raw in (j['bangs'] as List?) ?? const []) {
      if (raw is! Map) continue;
      final b = Bang.fromJson(raw.cast<String, dynamic>());
      if (b == null || !seen.add(b.key)) continue;
      bangs.add(b);
      if (bangs.length == BangRules.maxCustom) break;
    }
    return SearchSettings(
      engineId: SearchEngine.byId(j['engine'] as String?).id,
      bangs: bangs,
    );
  }
}

class SearchSettingsNotifier extends AsyncNotifier<SearchSettings> {
  static const storageKey = 'search.settings.v1';

  @override
  Future<SearchSettings> build() async {
    final raw = await ref.watch(prefsStoreProvider).read(storageKey);
    if (raw == null) return const SearchSettings();
    try {
      return SearchSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const SearchSettings();
    }
  }

  Future<void> setEngine(String id) => _save((s) => s.withEngine(id));

  Future<void> saveBang(Bang bang, {String? replacing}) =>
      _save((s) => s.withBang(bang, replacing: replacing));

  Future<void> removeBang(String key) => _save((s) => s.withoutBang(key));

  Future<void> _save(SearchSettings Function(SearchSettings) change) async {
    final current = state.hasValue ? state.requireValue : await future;
    final next = change(current);
    state = AsyncData(next);
    await ref
        .read(prefsStoreProvider)
        .write(storageKey, jsonEncode(next.toJson()));
  }
}

final searchSettingsProvider =
    AsyncNotifierProvider<SearchSettingsNotifier, SearchSettings>(
  SearchSettingsNotifier.new,
);

/// The person's bangs, empty while loading. What every router call merges.
final extraBangsProvider = Provider<List<Bang>>(
  (ref) => ref.watch(searchSettingsProvider).asData?.value.bangs ?? const [],
);

/// The engine for the web row, Google while loading.
final searchEngineProvider = Provider<SearchEngine>(
  (ref) =>
      ref.watch(searchSettingsProvider).asData?.value.engine ??
      SearchEngine.google,
);

/// Route a query with the person's bangs merged in, so no surface can forget
/// them. [watchRoute] in build methods, [readRoute] in callbacks.
extension CommandRouteRef on WidgetRef {
  CommandRoute watchRoute(String query) =>
      CommandRouter.route(query, extraBangs: watch(extraBangsProvider));

  CommandRoute readRoute(String query) =>
      CommandRouter.route(query, extraBangs: read(extraBangsProvider));
}
