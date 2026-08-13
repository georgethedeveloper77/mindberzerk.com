import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../core/logging.dart';
import '../../../core/prefs/prefs_keys.dart';
import '../../../core/prefs/prefs_store.dart';

/// WHETHER THIS ACCOUNT HAS PRO, ACCORDING TO PLAY.
///
/// ─── PLAY IS THE TRUTH, PREFERENCES ARE A CACHE OF IT ────────────────────────
///
/// The stored flag exists so the first frame after a cold start knows the
/// answer without waiting on a network round trip. It is never the record. Play
/// is asked on every launch and whatever it says overwrites the cache, in both
/// directions: a purchase made on another device turns it on, and a refund
/// turns it off.
///
/// A preference is editable by anyone with a rooted phone. As a cache of a
/// verified purchase that costs nothing; as the only evidence it would be the
/// whole lock.
///
/// ─── AND THERE IS NO SERVER, WHICH IS A REAL LIMIT ───────────────────────────
///
/// Play's own guidance is to verify a purchase token on a backend. There is no
/// backend, so verification here is what the client can see. For a one time
/// unlock on a utility app that is a defensible trade: the worst case is
/// somebody who was never going to pay uses a feature, and the cost of the
/// alternative is running a server for the life of the product.
class ProState {
  const ProState({
    required this.unlocked,
    required this.storeAvailable,
    this.price,
    this.busy = false,
    this.problem,
  });

  final bool unlocked;

  /// False on a device with no Play, and while the check is still running.
  /// The screen says so rather than showing a button that cannot work.
  final bool storeAvailable;

  /// From Play, in the user's own currency, or null until it answers.
  ///
  /// ─── NEVER A LITERAL IN THE UI ───────────────────────────────────────────
  ///
  /// The first version of the Pro screen printed "KSh 349". That is wrong in
  /// every country but one, wrong again the moment the price changes in
  /// Console, and wrong in a way nobody testing in Kenya would ever notice.
  final String? price;

  final bool busy;

  /// Set when a purchase failed for a reason worth showing. Null when the user
  /// simply cancelled, which is not an error and deserves no message.
  final String? problem;

  ProState copyWith({
    bool? unlocked,
    bool? storeAvailable,
    String? price,
    bool? busy,
    String? problem,
    bool clearProblem = false,
  }) => ProState(
    unlocked: unlocked ?? this.unlocked,
    storeAvailable: storeAvailable ?? this.storeAvailable,
    price: price ?? this.price,
    busy: busy ?? this.busy,
    problem: clearProblem ? null : (problem ?? this.problem),
  );
}

class ProController extends Notifier<ProState> {
  static const String sku = 'pro_unlock';

  StreamSubscription<List<PurchaseDetails>>? _purchases;

  @override
  ProState build() {
    final PrefsStore prefs = ref.watch(prefsStoreProvider);

    // Captured now, not read in the disposer. Reading ref during dispose throws
    // in Riverpod, and a subscription that outlives its notifier keeps
    // delivering into a dead state object.
    final StreamSubscription<List<PurchaseDetails>>? held = _purchases;
    ref.onDispose(() {
      held?.cancel();
      _purchases?.cancel();
    });

    // Started, not awaited. build must return synchronously so the cached
    // answer paints on the first frame, and Play arrives a moment later.
    unawaited(_connect());

    return ProState(
      unlocked: prefs.readBool(GPrefsKeys.proUnlocked),
      storeAvailable: false,
    );
  }

  Future<void> _connect() async {
    final InAppPurchase store = InAppPurchase.instance;

    final bool available = await store.isAvailable();
    if (!available) {
      // A device with no Play Store, which is a real configuration and not an
      // error. Anything already unlocked stays unlocked.
      state = state.copyWith(storeAvailable: false);
      return;
    }

    // ─── THE STREAM IS LISTENED TO BEFORE ANYTHING IS BOUGHT ─────────────────
    //
    // Every outcome arrives here: a purchase completed now, one completed on
    // another device, one restored, and one that was interrupted mid flow and
    // is delivered on the next launch. Subscribing only around a buy call would
    // miss the last two entirely, which is exactly how a person ends up charged
    // with nothing unlocked.
    _purchases ??= store.purchaseStream.listen(
      _apply,
      onError: (Object error) {
        GLog.w('purchase stream failed', scope: 'pro', cause: error);
      },
    );

    state = state.copyWith(storeAvailable: true);

    final ProductDetailsResponse products = await store.queryProductDetails(
      <String>{sku},
    );
    final ProductDetails? product = products.productDetails
        .where((ProductDetails p) => p.id == sku)
        .firstOrNull;

    if (product == null) {
      // The SKU exists in Console and this build cannot see it. Almost always
      // an unsigned build or a track the account is not a tester on, and worth
      // logging loudly because it looks identical to a network failure.
      GLog.w('product $sku not returned by the store', scope: 'pro');
    }

    state = state.copyWith(price: product?.price);

    // Asked on every launch, not just when a user taps restore.
    //
    // It is how a reinstall, a new device and a refund all reach this app, and
    // it costs one cached call. The stream above receives whatever comes back.
    await store.restorePurchases();
  }

  /// Handles everything Play sends, whatever prompted it.
  Future<void> _apply(List<PurchaseDetails> purchases) async {
    for (final PurchaseDetails purchase in purchases) {
      if (purchase.productID != sku) continue;

      switch (purchase.status) {
        case PurchaseStatus.pending:
          state = state.copyWith(busy: true, clearProblem: true);

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _grant(true);
          state = state.copyWith(busy: false, clearProblem: true);

        case PurchaseStatus.canceled:
          // Not a failure. Somebody looked at the sheet and changed their mind,
          // and telling them about it would be scolding.
          state = state.copyWith(busy: false, clearProblem: true);

        case PurchaseStatus.error:
          state = state.copyWith(
            busy: false,
            problem:
                purchase.error?.message ??
                'The purchase could not be completed.',
          );
      }

      // ─── COMPLETED, OR PLAY TAKES THE MONEY BACK ─────────────────────────
      //
      // A purchase left unacknowledged is refunded automatically after three
      // days and the entitlement disappears. This is the single most important
      // line in the file, and its absence is invisible until somebody's unlock
      // vanishes at the end of the week.
      if (purchase.pendingCompletePurchase) {
        await InAppPurchase.instance.completePurchase(purchase);
      }
    }
  }

  Future<void> _grant(bool unlocked) async {
    await ref
        .read(prefsStoreProvider)
        .writeBool(GPrefsKeys.proUnlocked, value: unlocked);
    state = state.copyWith(unlocked: unlocked);
  }

  /// Opens Play's purchase sheet. The answer arrives through the stream.
  Future<void> buy() async {
    if (state.busy) return;

    final InAppPurchase store = InAppPurchase.instance;
    state = state.copyWith(busy: true, clearProblem: true);

    final ProductDetailsResponse products = await store.queryProductDetails(
      <String>{sku},
    );
    final ProductDetails? product = products.productDetails
        .where((ProductDetails p) => p.id == sku)
        .firstOrNull;

    if (product == null) {
      state = state.copyWith(
        busy: false,
        problem: 'This purchase is not available on this device right now.',
      );
      return;
    }

    // Non consumable. A one time unlock is bought once and owned forever, and
    // buying it as a consumable would let Play sell it again.
    await store.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: product),
    );
  }

  /// Asks Play again, for a person who paid on another device.
  Future<void> restore() async {
    state = state.copyWith(busy: true, clearProblem: true);
    await InAppPurchase.instance.restorePurchases();

    // Nothing to await. Anything owned comes back through the stream, and
    // nothing coming back is the correct answer for an account that never
    // bought it, so this clears the spinner rather than reporting a failure.
    state = state.copyWith(busy: false);
  }
}

final NotifierProvider<ProController, ProState> proProvider =
    NotifierProvider<ProController, ProState>(ProController.new);

/// The single question every gated surface asks.
///
/// Derived, so that when the answer stops being one boolean there is one place
/// to change rather than a gate on every screen reaching into a field.
final Provider<bool> proUnlockedProvider = Provider<bool>(
  (Ref ref) => ref.watch(proProvider).unlocked,
);
