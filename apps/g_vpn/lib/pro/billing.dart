import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

/// The one Pro product: a subscription with `monthly` and `yearly` base plans,
/// created in Play Console. Product IDs are permanent: never rename this.
const proProductId = 'gvpn_pro';

/// Sales stay CLOSED until G Servers exist. Selling a subscription for servers
/// that are not running is a refund queue and a Play policy problem. Opened
/// per build once they are:
///   flutter run --dart-define=PRO_SALES_OPEN=true
const proSalesOpen = bool.fromEnvironment('PRO_SALES_OPEN');

/// One way to buy Pro: a base plan, or an offer on it (a free trial, say).
class ProPlan {
  const ProPlan({
    required this.basePlanId,
    required this.offerId,
    required this.price,
    required this.priceMicros,
    required this.period,
    required this.trialDays,
    required this.details,
  });

  final String basePlanId;
  final String? offerId;

  /// The recurring price, formatted by Play in the user's currency.
  final String price;
  final int priceMicros;

  /// ISO 8601 billing period from Play: P1M, P1Y.
  final String period;

  /// Days free before the first charge, when the offer has a free phase.
  final int? trialDays;
  final ProductDetails details;

  bool get yearly => period == 'P1Y';

  /// What a month costs on this plan, for the "save N%" label.
  double get monthlyMicros => yearly ? priceMicros / 12 : priceMicros.toDouble();
}

/// Reads the live plans from Play. An empty list means the product is not set
/// up (or not yet active) in Play Console, which the Pro screen says plainly.
final proPlansProvider = FutureProvider.autoDispose<List<ProPlan>>((ref) async {
  final iap = InAppPurchase.instance;
  if (!await iap.isAvailable()) throw const BillingUnavailable();
  final response = await iap.queryProductDetails({proProductId});
  if (response.error != null) throw BillingUnavailable(response.error!.message);

  final byBasePlan = <String, ProPlan>{};
  for (final d in response.productDetails.whereType<GooglePlayProductDetails>()) {
    final index = d.subscriptionIndex;
    final offers = d.productDetails.subscriptionOfferDetails;
    if (index == null || offers == null || index >= offers.length) continue;
    final offer = offers[index];
    final phases = offer.pricingPhases;
    if (phases.isEmpty) continue;
    final recurring = phases.last;
    final free = phases.length > 1 && phases.first.priceAmountMicros == 0 ? phases.first : null;
    final plan = ProPlan(
      basePlanId: offer.basePlanId,
      offerId: offer.offerId,
      price: recurring.formattedPrice,
      priceMicros: recurring.priceAmountMicros,
      period: recurring.billingPeriod,
      trialDays: free == null ? null : _days(free.billingPeriod),
      details: d,
    );
    // One entry per base plan: prefer the offer with a trial when there is one.
    final existing = byBasePlan[offer.basePlanId];
    if (existing == null || (existing.trialDays == null && plan.trialDays != null)) {
      byBasePlan[offer.basePlanId] = plan;
    }
  }
  final plans = byBasePlan.values.toList()..sort((a, b) => a.yearly == b.yearly ? 0 : (a.yearly ? 1 : -1));
  return plans;
});

int? _days(String isoPeriod) {
  final m = RegExp(r'^P(\d+)([DWM])$').firstMatch(isoPeriod);
  if (m == null) return null;
  final n = int.parse(m.group(1)!);
  return switch (m.group(2)) { 'D' => n, 'W' => n * 7, _ => n * 30 };
}

class BillingUnavailable implements Exception {
  const BillingUnavailable([this.detail]);

  final String? detail;

  @override
  String toString() => detail ?? 'Google Play billing is not available on this phone.';
}

class BillingState {
  const BillingState({this.owned = false, this.pending = false, this.error});

  /// Play says this phone's account holds an active gvpn_pro. CLIENT-SIDE
  /// ONLY for now: when G Servers launch, the backend verifies the purchase
  /// token with Google before issuing a server key, and that check is the
  /// one that counts.
  final bool owned;
  final bool pending;
  final String? error;
}

/// App-wide purchase listener. Play can deliver a purchase at ANY launch (a
/// slow card approval, a purchase made on another device), so this starts
/// with the app and never with a screen.
final billingProvider = NotifierProvider<BillingController, BillingState>(BillingController.new);

class BillingController extends Notifier<BillingState> {
  StreamSubscription<List<PurchaseDetails>>? _sub;

  @override
  BillingState build() {
    _sub = InAppPurchase.instance.purchaseStream.listen(
      _onPurchases,
      onError: (Object e) => state = BillingState(owned: state.owned, error: '$e'),
    );
    ref.onDispose(() => _sub?.cancel());
    // Re-derives ownership from Play on every launch: nothing local to forge.
    Future.microtask(() => InAppPurchase.instance.restorePurchases());
    return const BillingState();
  }

  Future<void> buy(ProPlan plan) async {
    if (!proSalesOpen) return;
    state = BillingState(owned: state.owned, pending: true);
    try {
      // Subscriptions go through buyNonConsumable; the offer is carried by
      // the product details' subscriptionIndex.
      await InAppPurchase.instance.buyNonConsumable(
        purchaseParam: GooglePlayPurchaseParam(productDetails: plan.details),
      );
    } on Exception catch (e) {
      state = BillingState(owned: state.owned, error: '$e');
    }
  }

  Future<void> restore() => InAppPurchase.instance.restorePurchases();

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    var owned = state.owned;
    String? error;
    var pending = false;
    for (final p in purchases) {
      if (p.productID != proProductId) continue;
      switch (p.status) {
        case PurchaseStatus.pending:
          pending = true;
        case PurchaseStatus.purchased || PurchaseStatus.restored:
          owned = true;
        case PurchaseStatus.error:
          error = p.error?.message ?? 'The purchase did not go through.';
        case PurchaseStatus.canceled:
          break;
      }
      // Play REFUNDS any purchase not acknowledged within three days.
      if (p.pendingCompletePurchase) await InAppPurchase.instance.completePurchase(p);
    }
    state = BillingState(owned: owned, pending: pending, error: error);
  }
}
