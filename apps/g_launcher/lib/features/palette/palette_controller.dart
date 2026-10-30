import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../data/prefs/hidden_apps.dart';
import '../../data/prefs/query_learning.dart';
import '../../data/repositories/app_repository.dart';
import '../../data/repositories/shell_apps.dart';
import '../../data/search/search_text.dart';
import '../../data/usage/usage_repository.dart';
import '../../engine/effective_theme.dart';
import '../../platform/launcher_api.g.dart';
import '../command/command_router.dart';
import '../command/search_settings.dart';
import 'fuzzy.dart';

/// What's typed at the prompt.
final paletteQueryProvider = StateProvider.autoDispose<String>((ref) => '');

/// The ranked match list.
///
/// **Now frecency-aware, for free.** `Fuzzy.rank` is stable — equal scores keep
/// their input order — so feeding it a usage-sorted list means ties break toward
/// the app you actually use. Type `ph` and Phone beats Photos *if Phone is what
/// you open*, with zero changes to the matcher. This is why usage sorting
/// happens HERE and not inside Fuzzy.
///
/// Deliberately separate from the drawer's `_filter` (substring, browsing
/// surface). Do not merge them — fuzzy results jumping around a browsing grid
/// are actively worse.
final paletteResultsProvider =
    Provider.family<List<Ranked<AppEntry>>, EffectiveTheme>((ref, theme) {
  final query = ref.watch(paletteQueryProvider);
  final apps = ref.watch(shellAppsProvider(theme));
  final frequent = ref.watch(frequentAppsProvider);

  if (query.isEmpty) return const [];

  // An explicit command mode (`=`, `:`, `!`) is not an app search.
  final extra = ref.watch(extraBangsProvider);
  if (!CommandRouter.route(query, extraBangs: extra).searchApps) {
    return const [];
  }

  // ── HIDDEN APPS ────────────────────────────────────────────────────────────
  //
  // `shellAppsProvider` has ALREADY removed them, so the palette used to be the
  // one surface where hiding actually held — and it held too hard: a hidden app
  // was unreachable from the terminal even by typing its full name, which on the
  // flagship "type two letters and hit enter" screen reads as the app being
  // gone. So the hidden ones are put back as candidates here, and
  // [HiddenApps.admits] decides. It admits nothing on a partial query, which is
  // what keeps `ti` from surfacing a hidden TikTok in a rofi box the whole point
  // of which is that it is fast and public.
  //
  // The re-add is skipped entirely when nothing is hidden, so the common case
  // costs one Set.isEmpty per keystroke.
  final hiddenPrefs = theme.prefs;
  final candidates = hiddenPrefs.hiddenApps.isEmpty
      ? apps
      : [
          ...apps,
          for (final a
              in ref.watch(appListProvider).asData?.value ?? const <AppEntry>[])
            if (hiddenPrefs.hiddenApps.contains(a.componentKey) &&
                HiddenApps.admits(hiddenPrefs, a, query))
              a,
        ];

  // Usage-first, alphabetical tail. O(n) with a rank map, not a sort-by-indexOf
  // (which is O(n²) and runs on every keystroke).
  final order = {for (var i = 0; i < frequent.length; i++) frequent[i]: i};
  final sorted = [...candidates]..sort((a, b) {
      final ia = order[a.componentKey] ?? 1 << 30;
      final ib = order[b.componentKey] ?? 1 << 30;
      if (ia != ib) return ia.compareTo(ib);
      return a.label.toLowerCase().compareTo(b.label.toLowerCase());
    });

  final fuzzy = Fuzzy.rank(sorted, query, label: (a) => a.label);

  // Typo tier, appended. Fuzzy forgives MISSING letters (it is a
  // subsequence match) but not wrong or swapped ones, so "telgram" found
  // Telegram and "telgeram" did not. These rank after every fuzzy hit and
  // carry an empty highlight, because no letter of the label was typed.
  final matched = {for (final r in fuzzy) r.item.componentKey};
  final typos = <(AppEntry, int)>[
    for (final a in sorted)
      if (!matched.contains(a.componentKey))
        if (SearchText.typoDistance(a.label, query) case final d?) (a, d),
  ]..sort((x, y) => x.$2.compareTo(y.$2));
  final ranked = [
    ...fuzzy,
    for (final t in typos)
      Ranked(item: t.$1, match: const FuzzyMatch(score: 0, indices: [])),
  ];
  final learning = ref.watch(queryLearningProvider).asData?.value;
  return learning == null
      ? ranked
      : learning.boost(ranked, query, (r) => r.item.componentKey);
});

/// Enter launches the top match. The entire promise of the screen, so it lives
/// in one place and the keyboard action and the tap path both go through it.
///
/// Returns false when there is nothing to launch — the caller stays quiet
/// rather than firing a toast at someone mid-typo.
bool launchTopMatch(WidgetRef ref, EffectiveTheme theme) {
  final results = ref.read(paletteResultsProvider(theme));
  if (results.isEmpty) return false;

  final app = results.first.item;
  ref
      .read(queryLearningProvider.notifier)
      .record(ref.read(paletteQueryProvider), app.componentKey);
  ref.read(appListProvider.notifier).launch(app);
  ref.read(usageProvider.notifier).record(app.componentKey);
  ref.read(paletteQueryProvider.notifier).state = '';
  return true;
}
