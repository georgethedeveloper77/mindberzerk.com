import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../prefs/prefs_repository.dart';

/// Launch counts.
///
/// **Not per-theme.** Everything else in prefs is keyed by theme (§5.3 — your
/// Ubuntu grid is not your KDE grid), but how often you open WhatsApp is a fact
/// about *you*, not about a colour scheme. Switching themes must not reset it.
/// Hence its own storage key and its own notifier, sharing only the PrefsStore.
///
/// One repository, three features — which is why it's worth building now rather
/// than when each one comes up:
///   1. the dock's default contents (nothing pinned → most-used apps)
///   2. the drawer's Frequent / All toggle (handoff §3, still open)
///   3. frecency-ranking the terminal palette — `Fuzzy.rank` is stable, so
///      handing it a usage-sorted list IS the change. Zero new code there.
@immutable
class UsageStats {
  const UsageStats({this.counts = const {}, this.lastUsed = const {}});

  /// componentKey -> total launches
  final Map<String, int> counts;

  /// componentKey -> ms since epoch of the last launch
  final Map<String, int> lastUsed;

  /// Most-used first — by **frecency, not frequency**.
  ///
  /// A raw count is a museum: the app you opened forty times last March
  /// outranks the one you've used daily this week, forever, and the dock
  /// ossifies around your past self. So each count is decayed by recency,
  /// halving every ~2 weeks.
  ///
  /// Decay rather than pure recency, because a dock that reshuffles after every
  /// launch is intolerable for a surface whose entire job is muscle memory.
  /// Stable — but it does eventually let go.
  List<String> ranked({DateTime? now}) {
    final t = (now ?? DateTime.now()).millisecondsSinceEpoch;

    final scored = counts.entries.map((e) {
      final last = lastUsed[e.key] ?? 0;
      final ageDays = last == 0 ? 365.0 : (t - last) / Duration.millisecondsPerDay;
      final decay = math.pow(0.5, ageDays / 14).toDouble();
      return MapEntry(e.key, e.value * decay);
    }).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return [for (final e in scored) e.key];
  }

  /// Most-RECENTLY launched first. Pure recency, no decay maths.
  ///
  /// Deliberately not [ranked]. Frecency answers "what do you reach for?" and is
  /// right for the dock, whose whole job is muscle memory — it must stay still.
  /// Recency answers "what were you just doing?", which is what a search screen
  /// wants: you opened a bank app two minutes ago, you probably want it again
  /// now, even though it will never out-rank WhatsApp on frequency.
  ///
  /// Apps launched before we started recording (or never launched) simply are
  /// not here; the caller decides what to show instead.
  List<String> recent() {
    final entries = lastUsed.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return [for (final e in entries) e.key];
  }

  UsageStats record(String componentKey, {DateTime? now}) {
    final t = (now ?? DateTime.now()).millisecondsSinceEpoch;
    return UsageStats(
      counts: {...counts, componentKey: (counts[componentKey] ?? 0) + 1},
      lastUsed: {...lastUsed, componentKey: t},
    );
  }

  /// Uninstalled apps must not haunt the frequent list. Call alongside
  /// `HomeLayout.prune` whenever the app list changes.
  UsageStats prune(Set<String> liveKeys) => UsageStats(
        counts: {
          for (final e in counts.entries)
            if (liveKeys.contains(e.key)) e.key: e.value,
        },
        lastUsed: {
          for (final e in lastUsed.entries)
            if (liveKeys.contains(e.key)) e.key: e.value,
        },
      );

  Map<String, dynamic> toJson() => {'counts': counts, 'lastUsed': lastUsed};

  static UsageStats fromJson(Map<String, dynamic> j) => UsageStats(
        counts: ((j['counts'] as Map?) ?? const {})
            .map((k, v) => MapEntry(k as String, (v as num).toInt())),
        lastUsed: ((j['lastUsed'] as Map?) ?? const {})
            .map((k, v) => MapEntry(k as String, (v as num).toInt())),
      );
}

const _usageKey = 'usage.v1';

final usageProvider =
    AsyncNotifierProvider<UsageNotifier, UsageStats>(UsageNotifier.new);

class UsageNotifier extends AsyncNotifier<UsageStats> {
  @override
  Future<UsageStats> build() async {
    final raw = await ref.watch(prefsStoreProvider).read(_usageKey);
    if (raw == null) return const UsageStats();
    try {
      return UsageStats.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Corrupt usage data costs a dock ordering, not the home screen.
      return const UsageStats();
    }
  }

  /// Called on every launch, from every surface — dock, drawer, palette,
  /// gesture-bound app.
  ///
  /// Named `record`, deliberately NOT `update`: `AsyncNotifier` already defines
  /// `update()`, and a mutator whose name collides with an inherited method that
  /// looks like a save but isn't is precisely the bug that cost this project
  /// every persisted preference. See scripts/no_bare_update.sh.
  Future<void> record(String componentKey) =>
      _write((u) => u.record(componentKey));

  Future<void> pruneTo(Set<String> liveKeys) =>
      _write((u) => u.prune(liveKeys));

  Future<void> _write(UsageStats Function(UsageStats) mutate) async {
    final next = mutate(state.asData?.value ?? const UsageStats());
    state = AsyncData(next); // optimistic — disk catches up
    await ref
        .read(prefsStoreProvider)
        .write(_usageKey, jsonEncode(next.toJson()));
  }
}

/// Most-recently-launched componentKeys, newest first. Empty until the first
/// launch is recorded. Feeds the search page's "Suggested apps" block, which
/// wants what you were just doing rather than what you use most.
final recentAppsProvider = Provider<List<String>>(
  (ref) => ref.watch(usageProvider).asData?.value.recent() ?? const [],
);

/// Most-used componentKeys, most-used first. Empty until launches accumulate,
/// which is fine: `HomeLayout.dockKeys` then yields an empty dock list and the
/// dock widget can fall back to the alphabetical head for the very first run.
final frequentAppsProvider = Provider<List<String>>(
  (ref) => ref.watch(usageProvider).asData?.value.ranked() ?? const [],
);
