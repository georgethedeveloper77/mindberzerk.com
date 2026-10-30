import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../search/search_text.dart';
import 'prefs_repository.dart';

/// Which app a typed query ends up launching, learned the way KRunner does.
///
/// Type "bank" and open Equity a few times, and Equity becomes the first
/// result for "bank" even though "bank" is nowhere in its name, and even
/// over an app that starts with "bank". Keyed by the COMPACTED query, so
/// "g vpn" and "gvpn" teach the same lesson.
///
/// ─── WHAT IT REMEMBERS, AND FOR HOW LONG ────────────────────────────────────
///
/// Counts per (query, app), capped at [_maxQueries] queries by most recent
/// use, so it can never grow into a log of everything ever typed. Local only,
/// never in backups (the key is outside `prefs.`), and wiped by "Clear recent
/// searches" with the rest of the search history.
///
/// Admission is unchanged: learning only REORDERS apps a surface already
/// returned. A hidden app is never surfaced by it, because the hidden rule
/// runs first and a learned key that is not in the list goes nowhere.
class QueryLearning {
  const QueryLearning(this.byQuery);

  /// compacted query -> componentKey -> launches
  final Map<String, Map<String, int>> byQuery;

  /// Keys learned for [query], strongest first. Needs two launches, so one
  /// mistaken tap does not rewrite the top result.
  List<String> learnedFor(String query) {
    final m = byQuery[SearchText.compact(query)];
    if (m == null) return const [];
    final e = m.entries.where((x) => x.value >= 2).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return [for (final x in e) x.key];
  }

  /// [items] with the learned ones for [query] moved to the front, in learned
  /// order, everything else in its original order.
  List<T> boost<T>(List<T> items, String query, String Function(T) keyOf) {
    final learned = learnedFor(query);
    if (learned.isEmpty || items.isEmpty) return items;
    final rank = {for (var i = 0; i < learned.length; i++) learned[i]: i};
    final front = [
      for (final it in items)
        if (rank.containsKey(keyOf(it))) it,
    ]..sort((a, b) => rank[keyOf(a)]!.compareTo(rank[keyOf(b)]!));
    if (front.isEmpty) return items;
    return [
      ...front,
      for (final it in items)
        if (!rank.containsKey(keyOf(it))) it,
    ];
  }

  QueryLearning record(String query, String componentKey) {
    final q = SearchText.compact(query);
    if (q.isEmpty) return this;
    final next = <String, Map<String, int>>{
      // Re-inserted last, so map order doubles as recency for the cap.
      for (final e in byQuery.entries)
        if (e.key != q) e.key: e.value,
      q: {
        ...?byQuery[q],
        componentKey: (byQuery[q]?[componentKey] ?? 0) + 1,
      },
    };
    while (next.length > _maxQueries) {
      next.remove(next.keys.first);
    }
    return QueryLearning(next);
  }

  static const _maxQueries = 200;

  Map<String, dynamic> toJson() => byQuery;

  static QueryLearning fromJson(Map<String, dynamic> j) => QueryLearning({
        for (final e in j.entries)
          if (e.value is Map)
            e.key: (e.value as Map).map(
              (k, v) => MapEntry(k as String, (v as num).toInt()),
            ),
      });
}

class QueryLearningNotifier extends AsyncNotifier<QueryLearning> {
  static const storageKey = 'search.learned.v1';

  @override
  Future<QueryLearning> build() async {
    final raw = await ref.watch(prefsStoreProvider).read(storageKey);
    if (raw == null) return const QueryLearning({});
    try {
      return QueryLearning.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const QueryLearning({});
    }
  }

  Future<void> record(String query, String componentKey) async {
    final current = state.hasValue ? state.requireValue : await future;
    final next = current.record(query, componentKey);
    state = AsyncData(next);
    await ref
        .read(prefsStoreProvider)
        .write(storageKey, jsonEncode(next.toJson()));
  }

  Future<void> clear() async {
    state = const AsyncData(QueryLearning({}));
    await ref.read(prefsStoreProvider).delete(storageKey);
  }
}

final queryLearningProvider =
    AsyncNotifierProvider<QueryLearningNotifier, QueryLearning>(
  QueryLearningNotifier.new,
);
