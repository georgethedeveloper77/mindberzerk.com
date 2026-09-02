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
/// alternative, trusting a cached "owned" flag, fails open, and failing open on
/// a paywall is how you find out your app has been on a modding forum.
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
/// and it must be called for `restored` as well as `purchased`: a purchase made
/// on another device arrives here as restored, and if it was never acknowledged
/// anywhere it is still on the clock.
///
/// This is the single most common way a working billing integration silently
/// loses money: the purchase succeeds, the user gets the pack, and the refund
/// lands days later with nothing in the logs. [_handle] below calls
/// `completePurchase` on EVERY completed purchase, unconditionally, before it
/// does anything else with it. Do not move that call into a branch.
///
/// ## START IS CHEAP AFTER THE FIRST CALL, AND IT DID NOT USED TO BE
///
/// The caller derives its SKU set from the signed catalogue, so `start` is
/// called at least twice per run by construction: once with the cold cache and
/// again when the index lands. It was also called afresh every time the
/// storefront reopened, because the provider holding this object auto-disposed.
///
/// Each of those calls ran the whole sequence: `isAvailable`, a full
/// `queryProductDetails`, and a full `restorePurchases`. Those serialise on one
/// billing client, so a `buyNonConsumable` issued while one was in flight
/// waited behind it, and the user's report was that Play's sheet took a very
/// long time to appear. The logs showed the other half: `Billing service
/// disconnected`, twice, as connections were made and torn down.
///
/// So the sequence is now split by what it costs and guarded by what has
/// already happened:
///
///   * the CONNECTION is established once per instance;
///   * the SUBSCRIPTION is attached once, before anything can deliver to it;
///   * PRODUCTS are queried only for ids not already held;
///   * RESTORE runs once, and again only when something asks for it.
///
/// The app is responsible for the other half of this: the provider that owns
/// this object must be kept alive, or a disposed instance takes its purchase
/// stream with it and the listener waiting for a completed purchase is bound to
/// an object nobody will ever emit on again.
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
  /// on an emulator without Play Services, all real parts of this audience.
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

  /// Ids Play has already been asked about, whether or not it found them.
  ///
  /// SEPARATE FROM [_products], and that difference is the whole point: a SKU
  /// that came back in `notFoundIDs` is absent from products, so keying the
  /// "have I asked" question on products would re-ask Play about every missing
  /// product on every call, forever, over the same billing client the purchase
  /// sheet needs.
  final _queried = <String>{};

  /// Whether the connection check has been made at least once and succeeded.
  bool _connected = false;

  /// Whether a restore has been run for this instance. See [start].
  bool _restored = false;

  bool _disposed = false;

  /// Connect, subscribe, load products, restore.
  ///
  /// SUBSCRIBE BEFORE RESTORING. [restorePurchases] delivers its results
  /// through the same stream, so a listener attached afterwards misses every
  /// restored purchase and the user opens a storefront that has forgotten what
  /// they bought.
  ///
  /// Safe and cheap to call repeatedly. See the note on the class: the caller
  /// calls this once with a cold catalogue and again when the index lands, and
  /// the second call must not re-run a restore that is already in flight.
  Future<void> start(Set<String> skus) async {
    if (_disposed) return;

    // RE-CHECKED WHILE FALSE, cached once true. Play Services can arrive after
    // first launch (a system update, a user finishing device setup), so a
    // permanent false on the first miss would leave the storefront unbuyable
    // for the life of the process. A true answer does not go back.
    if (!_connected) {
      _available = await _iap.isAvailable();
      if (_disposed) return;
      _connected = _available;
    }

    if (!_available) {
      // Emit anyway. A launcher on a de-Googled ROM must still reach a working
      // storefront that shows everything as locked, rather than a screen stuck
      // on a spinner forever.
      _emitOwned();
      return;
    }

    // BEFORE the queries below, so nothing a restore delivers can land before
    // there is somewhere for it to go.
    _sub ??= _iap.purchaseStream.listen(
      _handle,
      onError: (Object e) => _emitError(e.toString()),
    );

    // AN EMPTY SET IS LEGITIMATE, and this guard is what makes it so.
    //
    // The caller derives its SKUs from the signed catalogue rather than from a
    // constant, so on a cold start with an empty cache there is nothing to ask
    // about yet, and an app whose catalogue simply has nothing priced is the
    // same shape. `queryProductDetails` with no ids is a billing call with no
    // answer to give and errors on some Play versions.
    //
    // Everything else still runs. Connecting, subscribing and restoring with no
    // products loaded is not wasted: `_handle` records a restored purchase by
    // its product id whether or not this build has queried it, so a returning
    // user's ownership is known before the catalogue arrives.
    await _ensureProducts(skus);
    if (_disposed) return;

    // ─── ONCE, NOT PER CALL ────────────────────────────────────────────────
    //
    // `restorePurchases` walks every purchase on the account and replays them
    // all through `purchaseStream`. Running it again on each `start` cost a
    // full round trip on the billing client for an answer that had not changed,
    // and it is the call a purchase sheet ends up queued behind.
    //
    // The flag is set BEFORE the await rather than after, so a second `start`
    // arriving while the first restore is still in flight does not start a
    // second one. The explicit Settings row calls [restore] directly and is
    // unaffected: a person asking to restore gets a restore.
    if (!_restored) {
      _restored = true;
      await restore();
    }
  }

  /// Ask Play about any of [skus] it has not already been asked about.
  ///
  /// Returns without touching the network when there is nothing new, which is
  /// the common case on every call after the first.
  Future<void> _ensureProducts(Set<String> skus) async {
    if (_disposed || !_available) return;

    final missing = skus.difference(_queried);
    if (missing.isEmpty) return;

    // Marked BEFORE the await. Two callers arriving in the same frame (the
    // catalogue landing while a tap is in flight) would otherwise both see the
    // same gap and issue the same query.
    _queried.addAll(missing);

    try {
      final response = await _iap.queryProductDetails(missing);
      if (_disposed) return;
      for (final p in response.productDetails) {
        _products[p.id] = p;
      }
      // notFoundIDs is a real signal, not noise: it usually means the product
      // was never created in the console, or the build is not signed with the
      // upload key Play knows. Both look identical on-device, as a card with no
      // price.
      if (response.notFoundIDs.isNotEmpty) {
        _emitError('Not found in Play: ${response.notFoundIDs.join(', ')}');
      }
    } catch (e) {
      // The ids go back in the pool. A query that failed on a dropped
      // connection is one worth making again, unlike one that answered
      // `notFound`, which will answer the same thing forever.
      _queried.removeAll(missing);
      _emitError(e.toString());
    }
  }

  /// Re-ask Play what is owned. Results arrive through [purchased]/[owned].
  ///
  /// Called once from [start], and safe to call again from a "Restore
  /// purchases" row in Settings. That row is not optional: a user who
  /// reinstalls, or signs in on a new phone, has no other way to get their
  /// packs back, and its absence generates refund requests.
  Future<void> restore() async {
    if (_disposed || !_available) return;
    _restored = true;
    try {
      await _iap.restorePurchases();
    } catch (e) {
      _emitError(e.toString());
    }
  }

  /// Start a purchase.
  ///
  /// ─── IT LOADS THE PRODUCT RATHER THAN REFUSING ──────────────────────────
  ///
  /// This returned false whenever `_products[sku]` was empty, and the caller
  /// renders that as "not available to buy right now". Which is what a user
  /// saw for a perfectly real product, because the product map is populated by
  /// [start], [start] is driven by the catalogue, and a tap can easily land
  /// before either has resolved. A review reported exactly that sentence.
  ///
  /// So a missing product is now a reason to ask Play, not a reason to refuse.
  /// One query for one id is a fast call, it happens at most once per SKU per
  /// process, and the overwhelmingly common path still finds the product
  /// already loaded and does no work at all.
  ///
  /// False now means what the caller's message says: Play is unreachable, or
  /// this product genuinely does not exist in the console.
  Future<bool> buy(String sku) async {
    if (_disposed) return false;

    // A tap can be the first thing that ever needs billing: someone opens the
    // storefront on a cold cache and goes straight for a distro. Connect here
    // rather than assuming `start` got there first.
    if (!_connected) {
      _available = await _iap.isAvailable();
      if (_disposed) return false;
      _connected = _available;
    }
    if (!_available) return false;

    // Guarded the same way `start` guards it, because a purchase arriving
    // through the sheet needs somewhere to be delivered.
    _sub ??= _iap.purchaseStream.listen(
      _handle,
      onError: (Object e) => _emitError(e.toString()),
    );

    var product = _products[sku];
    if (product == null) {
      // Not `_ensureProducts`: this SKU may already be in `_queried` from a
      // failed or partial earlier pass, and the user is asking for it NOW.
      _queried.remove(sku);
      await _ensureProducts({sku});
      if (_disposed) return false;
      product = _products[sku];
    }
    if (product == null) return false;

    // buyNonConsumable, never buyConsumable. A distro pack is owned forever; a
    // consumable would let Play sell it twice and would make restore return
    // nothing.
    return _iap.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: product),
    );
  }

  void dispose() {
    // FIRST, so anything still in flight above returns instead of emitting on a
    // controller that is about to close. Every await in this class re-checks
    // it, because a billing round trip easily outlives the widget that started
    // it and `add` on a closed controller throws.
    _disposed = true;
    _sub?.cancel();
    _ownedController.close();
    _purchasedController.close();
    _errorController.close();
  }

  // ── the stream ───────────────────────────────────────────────────────────

  void _emitOwned() {
    if (_disposed || _ownedController.isClosed) return;
    _ownedController.add(ownedNow);
  }

  void _emitError(String detail) {
    if (_disposed || _errorController.isClosed) return;
    _errorController.add(detail);
  }

  Future<void> _handle(List<PurchaseDetails> purchases) async {
    var changed = false;

    for (final purchase in purchases) {
      // ACKNOWLEDGE FIRST, ALWAYS. Before the status branch, before any
      // entitlement bookkeeping, before anything that could throw. Three days
      // after this point an unacknowledged purchase is automatically refunded,
      // and an exception thrown while updating a Set is not a reason to give
      // someone's money back.
      //
      // NOT GUARDED BY `_disposed`, deliberately, and it is the one thing here
      // that is not. A disposed service is a screen that closed; the money is
      // still real and the clock is still running.
      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }

      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (_owned.add(purchase.productID)) changed = true;
          if (purchase.status == PurchaseStatus.purchased &&
              !_disposed &&
              !_purchasedController.isClosed) {
            _purchasedController.add(purchase.productID);
          }

        case PurchaseStatus.error:
          _emitError(
            purchase.error?.message ?? 'The purchase could not be completed',
          );

        case PurchaseStatus.canceled:
          // Silent. The user closed the sheet; telling them they did is noise.
          break;

        case PurchaseStatus.pending:
          // Real and common in this market: cash, carrier billing and some
          // wallets settle later. The pack must stay locked, and the UI should
          // say "pending" rather than "failed", because the money may still
          // arrive.
          break;
      }
    }

    // ONE emit per batch, not per purchase. restorePurchases delivers
    // everything at once, and emitting per item would push a growing partial
    // set down to native several times, briefly reporting packs as unowned that
    // the user owns.
    if (changed) _emitOwned();
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
