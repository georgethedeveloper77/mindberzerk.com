import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/app_repository.dart';
import '../usage/usage_repository.dart';
import 'prefs_repository.dart';

/// When each app was first seen by this launcher, and which of them are new.
///
/// ─── WHY FIRST SEEN AND NOT INSTALL TIME ────────────────────────────────────
///
/// `AppEntry` carries no install time, and adding one is a Pigeon schema change
/// (four files, append-only). First seen is the same answer for every app that
/// arrives while G Launcher is the home app, which is the only case "new app"
/// means anything for: native pushes the full list on every install, so a new
/// componentKey shows up here within a frame of the package landing.
///
/// ─── THE FIRST RUN SEEDS, IT DOES NOT ANNOUNCE ──────────────────────────────
///
/// With nothing stored, every app on the phone is recorded at time 0. Otherwise
/// a fresh install of the launcher would call the user's whole phone new.
///
/// ─── UNINSTALLS ARE FORGOTTEN ───────────────────────────────────────────────
///
/// Keys that leave the list are dropped, so reinstalling an app counts as new
/// again, which is what the user just did.
class NewAppsNotifier extends AsyncNotifier<Map<String, int>> {
  static const storageKey = 'apps.firstSeen.v1';

  @override
  Future<Map<String, int>> build() async {
    final store = ref.watch(prefsStoreProvider);
    final raw = await store.read(storageKey);

    Map<String, int>? stored;
    if (raw != null) {
      try {
        stored = (jsonDecode(raw) as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, (v as num).toInt()));
      } catch (_) {
        stored = null;
      }
    }

    // Watched: every install or uninstall pushes a new list and rebuilds this.
    final apps = ref.watch(appListProvider);
    if (!apps.hasValue) return stored ?? const {};

    final live = {for (final a in apps.requireValue) a.componentKey};
    final seedAt = stored == null ? 0 : DateTime.now().millisecondsSinceEpoch;
    final base = stored ?? const <String, int>{};

    final next = <String, int>{
      for (final k in live) k: base[k] ?? seedAt,
    };

    // Written only when the set actually changed, so unrelated rebuilds stay
    // off storage.
    if (stored == null ||
        next.length != stored.length ||
        next.keys.any((k) => !stored!.containsKey(k))) {
      await store.write(storageKey, jsonEncode(next));
    }
    return next;
  }
}

final newAppsFirstSeenProvider =
    AsyncNotifierProvider<NewAppsNotifier, Map<String, int>>(
  NewAppsNotifier.new,
);

/// How long an app stays "new" if it is never opened.
const kNewAppWindow = Duration(days: 3);

/// ComponentKeys of apps that arrived recently and have not been opened since,
/// newest first. Opening an app ends its newness, the same rule One UI and
/// Pixel use for the blue dot.
final newAppsProvider = Provider<List<String>>((ref) {
  final seen = ref.watch(newAppsFirstSeenProvider).asData?.value;
  if (seen == null || seen.isEmpty) return const [];

  final lastUsed =
      ref.watch(usageProvider).asData?.value.lastUsed ?? const <String, int>{};
  final cutoff = DateTime.now().subtract(kNewAppWindow).millisecondsSinceEpoch;

  final fresh = [
    for (final e in seen.entries)
      if (e.value > 0 && e.value >= cutoff && (lastUsed[e.key] ?? 0) < e.value)
        e,
  ]..sort((a, b) => b.value.compareTo(a.value));

  return [for (final e in fresh) e.key];
});
