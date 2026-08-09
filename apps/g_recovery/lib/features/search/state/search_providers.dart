import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bridge/recovery_api.g.dart';
import '../../recovery/state/recovery_providers.dart';

/// The current query. Debounced by the page, not here.
class SearchQueryController extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) {
    if (value == state) return;
    state = value;
  }

  void clear() => state = '';
}

final NotifierProvider<SearchQueryController, String> searchQueryProvider =
    NotifierProvider<SearchQueryController, String>(SearchQueryController.new);

/// Results for the current query, grouped by the caller.
///
/// Two characters is the floor. A single-letter query matches most of a camera
/// roll, and returning three thousand rows to render is slower and less useful
/// than returning nothing.
final FutureProvider<List<RecoverableItem>> searchResultsProvider =
    FutureProvider<List<RecoverableItem>>((Ref ref) async {
  final String query = ref.watch(searchQueryProvider);
  if (query.trim().length < 2) return const <RecoverableItem>[];
  await ref.watch(trashMapReadyProvider.future);
  return ref.watch(recoveryBridgeProvider).search(query, 120);
});

/// Search results split into the two groups the UI shows.
///
/// Deleted first, always. It is the reason the app is open, and a list that
/// leads with files the user already has buries the answer they came for.
class SearchGroups {
  const SearchGroups({required this.deleted, required this.live});

  final List<RecoverableItem> deleted;
  final List<RecoverableItem> live;

  bool get isEmpty => deleted.isEmpty && live.isEmpty;
  int get total => deleted.length + live.length;
}

final Provider<SearchGroups> searchGroupsProvider =
    Provider<SearchGroups>((Ref ref) {
  final List<RecoverableItem> all =
      ref.watch(searchResultsProvider).value ?? const <RecoverableItem>[];
  return SearchGroups(
    deleted: all
        .where((RecoverableItem item) => item.sourceId != 'live_files')
        .toList(),
    live: all
        .where((RecoverableItem item) => item.sourceId == 'live_files')
        .toList(),
  );
});

/// Recent searches, in memory only for now.
///
/// Deliberately NOT persisted yet. Search terms are among the most sensitive
/// things this app could store, and an app whose pitch is no accounts and no
/// tracking should not quietly keep a list of what its user was looking for
/// without deciding that on purpose. Persisting it is a Phase 9 privacy
/// decision, not a Phase 4 convenience.
class RecentSearches extends Notifier<List<String>> {
  @override
  List<String> build() => const <String>[];

  void remember(String term) {
    final String value = term.trim();
    if (value.length < 2) return;
    final List<String> next = <String>[
      value,
      ...state.where((String existing) => existing != value),
    ];
    state = next.take(6).toList();
  }

  void clear() => state = const <String>[];
}

final NotifierProvider<RecentSearches, List<String>> recentSearchesProvider =
    NotifierProvider<RecentSearches, List<String>>(RecentSearches.new);
