import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'pack_repository.dart';

/// Installs updates for packs already on the device, without being asked.
///
/// ─── WHY THIS IS NOT A NEW MECHANISM ────────────────────────────────────────
///
/// Everything it needs exists. `refreshCatalogue` reports whether the index
/// moved, the native side already computes `updateAvailable` per pack, and
/// `PackActions.install` already downloads, verifies, installs and invalidates.
/// This is the missing sentence between them: WHEN the catalogue changes, run
/// the install the user would otherwise have had to tap.
///
/// It deliberately does not recompute what an update is. The state string comes
/// from `PackHostApiImpl.stateOf`, and a second opinion here would be a second
/// place to get the version comparison wrong.
///
/// ─── THREE RULES, AND EACH ONE IS A FAILURE IT AVOIDS ───────────────────────
///
///   * ONLY WHAT IS ALREADY INSTALLED. `updateAvailable` means on disk and
///     stale. A pack at `available` is one the user has never taken, and
///     fetching it would be a download they did not ask for, measured in
///     megabytes on a phone that may be on mobile data.
///
///   * ONE AT A TIME. Fifteen concurrent downloads is the failure this app
///     exists to avoid on the hardware it targets. Sequential also means the
///     progress reporter shows one pack rather than fifteen fighting over the
///     same row.
///
///   * NEVER TWICE AT ONCE. A refresh can fire from the storefront mounting and
///     from a pull-to-refresh in the same second. Without the guard both would
///     walk the same list and install every pack twice.
///
/// ─── AND IT NEVER SPEAKS ────────────────────────────────────────────────────
///
/// No toast, no message, no error. A background update that succeeds is not
/// news, and one that fails is not actionable: the pack stays at the version it
/// had, the card still says Update, and tapping it gives the real error with the
/// real copy. Announcing a failure the user did not cause and cannot fix is how
/// a launcher teaches people to ignore it.
class PackAutoUpdater {
  PackAutoUpdater(this._ref);

  final Ref _ref;

  /// Guards against two refreshes racing. See the class doc.
  bool _running = false;

  /// Install every stale pack, oldest call wins.
  ///
  /// Returns the number installed, which is for tests and logs; nothing in the
  /// UI reads it, by design.
  Future<int> run() async {
    if (_running) return 0;
    _running = true;
    try {
      // READ, not watch. This is a one-shot pass over the catalogue as it
      // stands, and watching would restart it on the invalidate that its own
      // first install triggers.
      final packs = await _ref.read(catalogueProvider.future);

      final stale = [
        for (final p in packs)
          if (p.state == 'updateAvailable') p.packId,
      ];
      if (stale.isEmpty) return 0;

      var done = 0;
      for (final id in stale) {
        // Sequential on purpose: see the class doc. `await` in a loop is the
        // point here, not an oversight.
        final result = await _ref.read(packActionsProvider).install(id);
        // A STRING, not an enum, matching every other caller. `pack_repository`
        // documents why: the status is what the caller branches on and the
        // detail is for logs.
        if (result.status == 'installed') done++;
        // Everything else is swallowed deliberately. `notEntitled` on a pack
        // the user owned yesterday means a refund or a lapsed grant, and the
        // card will say so; `rejected` is a signature failure that must not be
        // retried; `noSpace` is real and the user will meet it the moment they
        // tap Update themselves, with copy that explains it.
      }
      return done;
    } finally {
      _running = false;
    }
  }
}

final packAutoUpdaterProvider =
    Provider<PackAutoUpdater>(PackAutoUpdater.new);

/// Refresh the catalogue, then install anything that went stale.
///
/// ─── THIS IS THE ONLY NEW CALL SITE ─────────────────────────────────────────
///
/// `PackActions.refresh` already returns whether the index moved, and it stamps
/// its own freshness clock so this cannot become a second fetch path. All this
/// adds is the consequence: a changed catalogue is exactly the moment a pack
/// can have become stale, and the only moment worth walking the list.
///
/// `unawaited` because the caller is a UI route that must not wait on a
/// download. Failures are already swallowed inside [PackAutoUpdater.run], so
/// there is no rejected future to lose.
///
/// ─── IT TAKES THE OBJECTS, NOT A `ref` ──────────────────────────────────────
///
/// The two callers hold different things: `catalogueRefreshProvider` has a
/// `Ref` and the storefront's pull-to-refresh has a `WidgetRef`, and those do
/// not share a supertype. My first attempt took `read` as a generic function
/// typed `ProviderListenable`, which is a Riverpod 2 name that no longer
/// exists.
///
/// Taking the two objects is better than finding the v3 spelling anyway: this
/// function needs a thing that refreshes and a thing that updates, and naming
/// the container they came out of is a detail it has no reason to know. Each
/// caller reads them with whichever ref it has.
Future<bool> refreshAndAutoUpdate(
  PackActions actions,
  PackAutoUpdater updater,
) async {
  final changed = await actions.refresh();
  if (changed) unawaited(updater.run());
  return changed;
}
