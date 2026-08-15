import '../prefs/prefs_repository.dart';

/// "Apply this distro once its packs land", across a process death.
///
/// ─── WHY THIS IS ON DISK AND `applyOnPurchaseProvider` WAS NOT ──────────────
///
/// The in-memory version was right about the rule and wrong about the lifetime.
/// The rule is that a purchase should APPLY its distro only when the user is
/// still in the flow they started, because the purchase stream can fire minutes
/// later for the cash and carrier-billing methods this market uses, and swapping
/// someone's whole desktop while they are doing something else is not what they
/// asked for.
///
/// The lifetime was wrong because the download now runs in `PackSyncWorker`,
/// which OUTLIVES the process on purpose. On a 3GB phone, buying and then
/// opening any app can have the launcher killed while the work carries on
/// perfectly well. The pack lands, and there is no Dart alive to apply it, so
/// the user returns to a distro they paid for and a desktop that ignored it.
/// That is the original complaint, moved later and made harder to see.
///
/// ─── AND WHY IT EXPIRES ─────────────────────────────────────────────────────
///
/// An intent with no expiry is a booby trap: buy on Monday, decline the
/// download, open the app on Friday and the desktop changes for reasons nobody
/// can reconstruct. [_window] is the span in which "I just bought this" is still
/// a true description of what the user is thinking. Past it, the purchase is
/// simply owned, the card shows as installed, and a tap does what a tap does.
///
/// FIFTEEN MINUTES rather than the two or three a download takes: a worker
/// deferred by an aggressive OEM battery manager can be slower than the network
/// ever was, and the failure of being too short is exactly the failure this
/// exists to prevent.
class PendingApply {
  const PendingApply._();

  /// `sku|millisSinceEpoch`. One key, because two would be two writes that can
  /// half-fail, and a timestamp with no sku is unreadable anyway.
  static const _key = 'applyOnPurchase.v1';

  static const _window = Duration(minutes: 15);

  /// Record that a purchase of [sku] began with a deliberate tap.
  ///
  /// Called BEFORE Play opens rather than after it returns, because a fast
  /// payment method can complete before that await does, and an intent written
  /// afterwards would arrive too late to be read.
  static Future<void> set(PrefsStore store, String sku) =>
      store.write(_key, '$sku|${DateTime.now().millisecondsSinceEpoch}');

  static Future<void> clear(PrefsStore store) => store.delete(_key);

  /// The sku still owed an apply, or null.
  ///
  /// EXPIRY IS CHECKED ON READ, not by anything that sweeps. There is no moment
  /// a launcher is guaranteed to run cleanup, so a stale record has to be
  /// harmless where it is read rather than removed on a schedule that may never
  /// arrive. A lapsed one is cleared here as a side effect, which is the only
  /// place that reliably happens.
  static Future<String?> take(PrefsStore store) async {
    final raw = await store.read(_key);
    if (raw == null || raw.isEmpty) return null;

    final cut = raw.lastIndexOf('|');
    if (cut <= 0) {
      // Not our shape. Written by an older build, or truncated. Nothing can be
      // done with it and leaving it would make every future read fail the same
      // way, so it goes.
      await clear(store);
      return null;
    }

    final sku = raw.substring(0, cut);
    final at = int.tryParse(raw.substring(cut + 1));
    if (at == null) {
      await clear(store);
      return null;
    }

    final age = DateTime.now().millisecondsSinceEpoch - at;
    // Negative age means the clock moved backwards, which a user changing their
    // timezone does routinely. Treated as fresh rather than as expired: the
    // cost of applying a distro they bought is far smaller than the cost of
    // silently dropping it.
    if (age > _window.inMilliseconds) {
      await clear(store);
      return null;
    }

    return sku;
  }
}
