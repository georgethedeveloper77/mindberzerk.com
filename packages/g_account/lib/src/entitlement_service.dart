import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

/// PHASE C3 — which Play products this user owns.
///
/// PLAIN DART WITH NO RIVERPOD, on purpose. This package is meant to be lifted
/// into G Recovery, which sells its own unlocks through the same store, and a
/// state-management dependency baked in here would make that lift a rewrite.
/// The Riverpod wiring lives in the app, over this.
///
/// ## The one rule
///
/// **Ownership is Play's answer.** Not the CDN's, which serves the payload and
/// must never also decide who may have it. Not a flag in shared_preferences,
/// which is a claim the device makes about itself and survives exactly as long
/// as nobody looks at it. This class holds the answer in memory, re-asks Play
/// on every start, and persists nothing.
///
/// That means it fails CLOSED. A cold start with no network reports an empty
/// set, so a paid pack is briefly locked until [restore] completes. The
/// alternative — trusting a cached "owned" flag — fails open, and failing open
/// on a paywall is how you find out your app has been on a modding forum.
///
/// ## What this class does NOT know
///
/// What a SKU unlocks. That mapping lives in the signed CDN index, because
/// bundle membership is content and changes constantly, while a Play product ID
/// is immutable and cannot even be reused after deletion. Keeping the two apart
/// is what lets a bundle gain a distro with no Play change and no app release.
///
/// ## The three-day refund trap
///
/// Google AUTO-REFUNDS any purchase not acknowledged within three days. In the
/// `in_app_purchase` plugin, acknowledgement is [InAppPurchase.completePurchase],
/// and it must be called for `restored` as well as `purchased` — a purchase made
/// on another device arrives here as restored, and if it was never acknowledged
/// anywhere it is still on the clock.
///
/// This is the single most common way a working billing integration silently
/// loses money: the purchase succeeds, the user gets the pack, and the refund
/// lands days later with nothing in the logs. [_handle] below calls
/// `completePurchase` on EVERY completed purchase, unconditionally, before it
/// does anything else with it. Do not move that call into a branch.
class EntitlementService {
  EntitlementService({InAppPurchase? iap})
      : _iap = iap ?? InAppPurchase.instance;

  final InAppPurchase _iap;

  StreamSubscription<List<PurchaseDetails>>? _sub;

  final _owned = <String>{};
  final _ownedController = StreamController<Set<String>>.broadcast();

  /// Emits the owned-SKU set whenever it changes. Never emits a partial set:
  /// callers push this straight down to native, so a half-built set would
  /// briefly lock something the user owns.
  Stream<Set<String>> get owned => _ownedController.stream;

  Set<String> get ownedNow => Set.unmodifiable(_owned);

  /// True when the store is reachable. False on a de-Googled ROM, in China, or
  /// on an emulator without Play Services — all real parts of this audience.
  bool get available => _available;
  bool _available = false;

  /// Products, for prices. Keyed by SKU. Empty until [start] resolves.
  Map<String, ProductDetails> get products => Map.unmodifiable(_products);
  final _products = <String, ProductDetails>{};

  /// Fires when a purchase completes, so the caller can kick off a download.
  final _purchasedController = StreamController<String>.broadcast();
  Stream<String> get purchased => _purchasedController.stream;

  /// Fires on a failed or cancelled purchase, with a reason worth showing.
  final _errorController = StreamController<String>.broadcast();
  Stream<String> get errors => _errorController.stream;

  /// Connect, subscribe, load products, restore.
  ///
  /// SUBSCRIBE BEFORE RESTORING. [restorePurchases] delivers its results
  /// through the same stream, so a listener attached afterwards misses every
  /// restored purchase and the user opens a storefront that has forgotten what
  /// they bought.
  Future<void> start(Set<String> skus) async {
    _available = await _iap.isAvailable();
    if (!_available) {
      // Emit anyway. A launcher on a de-Googled ROM must still reach a working
      // storefront that shows everything as locked, rather than a screen stuck
      // on a spinner forever.
      _ownedController.add(ownedNow);
      return;
    }

    _sub ??= _iap.purchaseStream.listen(
      _handle,
      onError: (Object e) => _errorController.add(e.toString()),
    );

    final response = await _iap.queryProductDetails(skus);
    for (final p in response.productDetails) {
      _products[p.id] = p;
    }
    // notFoundIDs is a real signal, not noise: it usually means the product was
    // never created in the console, or the build is not signed with the upload
    // key Play knows. Both look identical on-device — a card with no price.
    if (response.notFoundIDs.isNotEmpty) {
      _errorController.add(
        'Not found in Play: ${response.notFoundIDs.join(', ')}',
      );
    }

    await restore();
  }

  /// Re-ask Play what is owned. Results arrive through [purchased]/[owned].
  ///
  /// Called on every start, and safe to call again from a "Restore purchases"
  /// row in Settings. That row is not optional: a user who reinstalls, or signs
  /// in on a new phone, has no other way to get their packs back, and its
  /// absence generates refund requests.
  Future<void> restore() async {
    if (!_available) return;
    try {
      await _iap.restorePurchases();
    } catch (e) {
      _errorController.add(e.toString());
    }
  }

  /// Start a purchase. Returns false when the product is unknown, which means
  /// [start] has not resolved yet or the SKU does not exist in the console.
  Future<bool> buy(String sku) async {
    final product = _products[sku];
    if (product == null) return false;

    // buyNonConsumable, never buyConsumable. A distro pack is owned forever; a
    // consumable would let Play sell it twice and would make restore return
    // nothing.
    return _iap.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: product),
    );
  }

  void dispose() {
    _sub?.cancel();
    _ownedController.close();
    _purchasedController.close();
    _errorController.close();
  }

  // ── the stream ───────────────────────────────────────────────────────────

  Future<void> _handle(List<PurchaseDetails> purchases) async {
    var changed = false;

    for (final purchase in purchases) {
      // ACKNOWLEDGE FIRST, ALWAYS. Before the status branch, before any
      // entitlement bookkeeping, before anything that could throw. Three days
      // after this point an unacknowledged purchase is automatically refunded,
      // and an exception thrown while updating a Set is not a reason to give
      // someone's money back.
      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }

      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (_owned.add(purchase.productID)) changed = true;
          if (purchase.status == PurchaseStatus.purchased) {
            _purchasedController.add(purchase.productID);
          }

        case PurchaseStatus.error:
          _errorController.add(
            purchase.error?.message ?? 'The purchase could not be completed',
          );

        case PurchaseStatus.canceled:
          // Silent. The user closed the sheet; telling them they did is noise.
          break;

        case PurchaseStatus.pending:
          // Real and common in this market: cash, carrier billing and some
          // wallets settle later. The pack must stay locked, and the UI should
          // say "pending" rather than "failed" — the money may still arrive.
          break;
      }
    }

    // ONE emit per batch, not per purchase. restorePurchases delivers
    // everything at once, and emitting per item would push a growing partial
    // set down to native several times, briefly reporting packs as unowned that
    // the user owns.
    if (changed) _ownedController.add(ownedNow);
  }
}

// ── NOTE ON SERVER-SIDE VERIFICATION ────────────────────────────────────────
//
// There is none yet. `purchase.verificationData` carries a signed payload that
// a backend could check against the Google Play Developer API, and until
// something does, a rooted device running a billing emulator can report
// ownership this app will believe.
//
// That is an accepted trade for now, and worth being explicit about rather than
// discovering later: the goods are cosmetic themes delivered from a public CDN,
// so the realistic loss is a theme someone could have extracted from the APK
// anyway. It would NOT be an acceptable trade for anything with a server cost
// per use.
//
// When the admin backend exists, the check belongs there: post
// `verificationData.serverVerificationData` plus the product id, verify against
// Play, and have the server return the entitlement set. That also removes the
// fail-closed cold-start gap, because the server can cache the answer.
//
// PLAIN `//` COMMENTS, NOT `///`, AND NO `library;`. A `///` block at the end of
// a file is a dangling doc comment with nothing to document, and adding
// `library;` after it is a compile error because a library directive must
// precede every other directive including the imports at the top. This is the
// fourth time that mistake has landed in this codebase; `layout_resolver.dart`
// is the pattern when a file genuinely needs a library doc: doc comment,
// `library;`, then imports, all at the TOP.
