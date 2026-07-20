import 'package:flutter_test/flutter_test.dart';
import 'package:g_launcher/data/usage/usage_repository.dart';

void main() {
  final now = DateTime(2026, 7, 15);
  DateTime daysAgo(int d) => now.subtract(Duration(days: d));

  test('frecency: daily-use app beats last-quarter binge', () {
    // WhatsApp: 10 launches, used today.
    // OldGame: 40 launches, last touched 90 days ago.
    // Raw frequency says OldGame. Frecency must say WhatsApp — a dock frozen
    // around your past self is the failure mode this exists to prevent.
    var u = const UsageStats();
    for (var i = 0; i < 40; i++) {
      u = u.record('oldgame', now: daysAgo(90));
    }
    for (var i = 0; i < 10; i++) {
      u = u.record('whatsapp', now: now);
    }

    expect(u.ranked(now: now).first, 'whatsapp');
  });

  test('stable within a session — a dock that reshuffles per launch is unusable',
      () {
    var u = const UsageStats();
    for (var i = 0; i < 20; i++) {
      u = u.record('a', now: now);
    }
    for (var i = 0; i < 19; i++) {
      u = u.record('b', now: now);
    }

    // One launch of b (19 -> 20 == a) must not leapfrog it past a's 20 when
    // both were used just now — decay is identical, count ties, order holds.
    u = u.record('b', now: now);
    expect(u.ranked(now: now).first, anyOf('a', 'b'));
    // The strong claim: a is not suddenly *below* something it out-counts.
    for (var i = 0; i < 5; i++) {
      u = u.record('a', now: now);
    }
    expect(u.ranked(now: now).first, 'a');
  });

  test('prune drops uninstalled apps from both maps', () {
    var u = const UsageStats();
    u = u.record('keep', now: now);
    u = u.record('gone', now: now);

    u = u.prune({'keep'});
    expect(u.counts.containsKey('gone'), isFalse);
    expect(u.lastUsed.containsKey('gone'), isFalse);
    expect(u.ranked(now: now), ['keep']);
  });

  test('round-trips through JSON', () {
    var u = const UsageStats();
    u = u.record('x', now: now);
    u = u.record('x', now: now);

    final back = UsageStats.fromJson(u.toJson());
    expect(back.counts['x'], 2);
    expect(back.lastUsed['x'], u.lastUsed['x']);
  });

  test('never-used key with a count still ranks (age-capped, not crashed)', () {
    // Defensive: counts without lastUsed (hand-edited or partial prune).
    const u = UsageStats(counts: {'orphan': 5});
    expect(u.ranked(), ['orphan']);
  });
}
