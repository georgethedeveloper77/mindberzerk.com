import 'package:flutter/foundation.dart';

/// The fuzzy matcher behind the terminal's command palette.
///
/// This is the flagship feature's actual engine, so it is pure Dart with tests
/// and no Flutter in it. Everything above it — the green text, the block cursor,
/// the fastfetch header — is chrome. This is the part that has to feel *right*,
/// and "right" here is a very specific thing: **`fi` must put Firefox first.**
///
/// Not "somewhere in the list". First. Every time. On a terminal whose whole
/// pitch is "type two letters and hit enter", the top match being wrong once is
/// enough for someone to stop trusting it and go back to the drawer — and then
/// the flagship feature is dead weight.
///
/// So the scoring is deliberately opinionated:
///
///  - **Subsequence, not substring.** `gpl` matches "Google Play". This is what
///    makes it a fuzzy matcher rather than the drawer's search box (which is a
///    substring filter, and should stay one — do not merge them).
///  - **Consecutive runs are worth much more than scattered hits.** `fi` matching
///    "FIrefox" beats `fi` matching "F(iles) → no", and crucially beats a
///    scattered match like "Fitness Ins**i**ghts".
///  - **Word starts are worth a lot.** People type initials: `vs` → "VLC Stream",
///    `gm` → "Google Maps". Camel humps and post-space/dash/underscore positions
///    all count as word starts.
///  - **A prefix match is worth the most.** If you typed the beginning of the
///    name, you almost certainly mean that app.
///  - **Shorter names win ties.** `cal` should give you "Calculator" over
///    "Calendar Sync Pro Deluxe". Length is a proxy for "how much of the name did
///    you actually type", which is a decent proxy for intent.
///
/// Returns the matched character indices as well as a score, because the mockup
/// highlights the typed substring in amber and you cannot do that from a bool.

@immutable
class FuzzyMatch {
  const FuzzyMatch({required this.score, required this.indices});

  final int score;

  /// Indices into the *original* label of every matched character, ascending.
  /// The terminal paints these amber.
  final List<int> indices;

  static const none = FuzzyMatch(score: -1, indices: []);
  bool get matched => score >= 0;
}

abstract final class Fuzzy {
  // Tuned by feel against a real ~140-app list, not derived from anything.
  static const _scoreMatch = 16;
  static const _bonusConsecutive = 22;
  static const _bonusWordStart = 30;
  static const _bonusPrefix = 40;
  static const _bonusEarly = 25; // still matching from position qi, i.e. a run from the start
  static const _penaltyLeadingGap = 3; // per char skipped before the first hit
  static const _penaltyGap = 4; // per char skipped between hits
  static const _maxLeadingPenalty = 30;
  static const _neg = -1 << 30;

  /// Scores [query] against [label]. Empty query matches everything, score 0.
  ///
  /// **This is a DP, not a greedy scan, and that was not gold-plating.** A query
  /// can usually be aligned to a label several ways, and greedy picks the wrong
  /// one in both directions:
  ///
  ///   - Greedy forward matches "fox" against "Firefox" as F‧‧‧‧ox — it grabs the
  ///     first `f` and never reconsiders, missing the tight `fox` run at the end.
  ///   - Greedy backward (pull every hit as late as possible, which is fzf's
  ///     tightening trick) fixes that — and then matches "gps" against "Google
  ///     Play Store" starting at the SECOND g, because it drags the `g` off the
  ///     capital and onto "Goo(g)le".
  ///
  /// Both alignments match. They just score differently, and the highlight the
  /// user sees is whichever one you picked. So compute all of them and take the
  /// best: `best[qi][li]` = the best score for matching `query[0..qi]` with
  /// `query[qi]` landing on `label[li]`.
  ///
  /// O(label × query). Labels are app names and queries are a few characters, so
  /// this is nothing — and it runs on every keystroke over ~140 apps, which is
  /// still nothing.
  static FuzzyMatch match(String label, String query) {
    if (query.isEmpty) return const FuzzyMatch(score: 0, indices: []);

    final n = label.length;
    final m = query.length;
    if (m > n) return FuzzyMatch.none;

    final l = label.toLowerCase();
    final q = query.toLowerCase();

    final best = List.generate(m, (_) => List.filled(n, _neg));
    final from = List.generate(m, (_) => List.filled(n, -1));

    // First query character: no predecessor, only a leading-gap penalty.
    for (var li = 0; li < n; li++) {
      if (l.codeUnitAt(li) != q.codeUnitAt(0)) continue;

      var s = _scoreMatch;
      if (_isWordStart(label, li)) s += _bonusWordStart;
      if (li == 0) s += _bonusEarly;

      // How far in did we have to go to find it? Capped, or a long label with a
      // late first hit goes hopelessly negative and sorts below garbage.
      final leading = li * _penaltyLeadingGap;
      s -= leading > _maxLeadingPenalty ? _maxLeadingPenalty : leading;

      best[0][li] = s;
    }

    for (var qi = 1; qi < m; qi++) {
      for (var li = qi; li < n; li++) {
        if (l.codeUnitAt(li) != q.codeUnitAt(qi)) continue;

        var bestScore = _neg;
        var bestFrom = -1;

        for (var lj = qi - 1; lj < li; lj++) {
          if (best[qi - 1][lj] == _neg) continue;

          var s = best[qi - 1][lj] + _scoreMatch;

          if (lj == li - 1) {
            s += _bonusConsecutive;
          } else {
            s -= (li - lj - 1) * _penaltyGap;
          }

          if (_isWordStart(label, li)) s += _bonusWordStart;
          if (li == qi) s += _bonusEarly;

          if (s > bestScore) {
            bestScore = s;
            bestFrom = lj;
          }
        }

        best[qi][li] = bestScore;
        from[qi][li] = bestFrom;
      }
    }

    var endIndex = -1;
    var score = _neg;
    for (var li = m - 1; li < n; li++) {
      if (best[m - 1][li] > score) {
        score = best[m - 1][li];
        endIndex = li;
      }
    }

    // Not a subsequence.
    if (endIndex < 0 || score == _neg) return FuzzyMatch.none;

    // Walk the DP back out to get the winning alignment — these are the
    // characters the terminal paints amber.
    final indices = List<int>.filled(m, 0);
    var li = endIndex;
    for (var qi = m - 1; qi >= 0; qi--) {
      indices[qi] = li;
      li = from[qi][li];
    }

    if (l.startsWith(q)) score += _bonusPrefix;

    // Shorter labels win ties: "cal" should give Calendar before Calculator, and
    // neither before "Calendar Sync Pro Deluxe". Small — it breaks ties, it does
    // not dominate.
    score -= label.length ~/ 4;

    return FuzzyMatch(score: score, indices: indices);
  }

  /// A word start is: index 0, a character after a separator, or a camel hump.
  ///
  /// The camel rule is what makes `gm` find "GMail" and `vs` find "VLC Stream",
  /// and it must read the ORIGINAL label, not the lowercased one — the sort of
  /// thing that works perfectly on your test data and quietly dies on a phone
  /// full of oddly-cased OEM apps.
  static bool _isWordStart(String label, int i) {
    if (i == 0) return true;

    final prev = label[i - 1];
    if (prev == ' ' ||
        prev == '-' ||
        prev == '_' ||
        prev == '.' ||
        prev == '&' ||
        prev == '(') {
      return true;
    }

    final ch = label[i];
    final isUpper = ch.toUpperCase() == ch && ch.toLowerCase() != ch;
    final prevIsLower = prev.toLowerCase() == prev && prev.toUpperCase() != prev;
    return isUpper && prevIsLower;
  }

  /// Ranks [items] by [label] against [query]. Non-matches are dropped.
  ///
  /// Stable: equal scores keep their input order, so passing an alphabetised list
  /// in gives you an alphabetised tiebreak out for free. (When usage counts land
  /// — the Frequent/All toggle needs them anyway — sort the input by launch count
  /// and this immediately becomes frecency-ranked with no change here.)
  static List<Ranked<T>> rank<T>(
    Iterable<T> items,
    String query, {
    required String Function(T) label,
  }) {
    final out = <Ranked<T>>[];

    for (final item in items) {
      final m = match(label(item), query);
      if (m.matched) out.add(Ranked(item: item, match: m));
    }

    // mergeSort semantics: List.sort is NOT guaranteed stable in Dart, so do the
    // tiebreak explicitly rather than relying on it.
    out.sort((a, b) {
      final byScore = b.match.score.compareTo(a.match.score);
      if (byScore != 0) return byScore;
      return label(a.item).length.compareTo(label(b.item).length);
    });

    return out;
  }
}

@immutable
class Ranked<T> {
  const Ranked({required this.item, required this.match});

  final T item;
  final FuzzyMatch match;
}
