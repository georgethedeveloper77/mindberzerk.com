import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g_account/g_account.dart';

import '../cdn/pack_repository.dart';

/// PHASE C3 — the app-side wiring over `g_account`.
///
/// The service itself is plain Dart in a shared package so G Recovery can lift
/// it. Everything Riverpod-shaped, and everything that knows about the pack
/// pipeline, lives here.
///
/// ## The flow, in one line
///
/// Play → EntitlementService → this file → `setOwnedSkus` → native →
/// `CdnIndex.isUnlocked` → `PackInfo.unlocked` → the storefront card.
///
/// Note what is NOT in that chain: any Dart code deciding what a SKU unlocks.
/// The ownership rule exists once, natively, in `CdnIndex.isUnlocked`, tested
/// in `EntitlementTest`. Re-deriving it here from `sku` plus the owned set
/// would be a second implementation in a second language that nothing tests
/// together, and the day they disagree one gives a pack away and the other
/// charges twice for it.

/// Every SKU this build knows how to sell.
///
/// MUST match `backend/content/products.json` and the product IDs created in
/// Play Console. A SKU listed here but absent from the console comes back in
/// `notFoundIDs` and its card renders with no price; a SKU in the console but
/// missing here is simply never queried, so a user who owns it appears not to.
///
/// Singles are carried on each pack's own `sku` field in the index; the three
/// bundles also appear in the index's `entitlements` block.
const kProductSkus = <String>{
  'distro_pack_kali',
  'distro_pack_arch',
  'distro_pack_garuda',
  'distro_pack_elementary',
  'distro_pack_mint',
  'distro_pack_popos',
  'distro_pack_debian',
  'bundle_tiling',
  'bundle_classic',
  'distro_pack_all',
};

final entitlementServiceProvider = Provider<EntitlementService>((ref) {
  final service = EntitlementService();
  ref.onDispose(service.dispose);
  return service;
});

/// The owned-SKU set, live.
///
/// Starts EMPTY and stays empty until Play answers, which is the correct
/// direction to fail. A paid pack is briefly locked on a cold start with no
/// network; the alternative is trusting a cached flag, and failing open on a
/// paywall is how an app ends up on a modding forum.
final ownedSkusProvider = StreamProvider<Set<String>>((ref) {
  final service = ref.watch(entitlementServiceProvider);

  // Push down to native on every change, INCLUDING the empty first emit.
  // Native starts empty and never persists, so a missed push after a purchase
  // leaves someone who has paid staring at a download that refuses.
  final sub = service.owned.listen((skus) {
    ref.read(packActionsProvider).pushEntitlements(skus);
  });
  ref.onDispose(sub.cancel);

  // Fire and forget: start() does network work and nothing should wait on it.
  // The storefront renders from the cached catalogue meanwhile.
  unawaited(service.start(kProductSkus));

  return service.owned;
});

/// Product prices for the storefront, keyed by SKU.
///
/// LOCALISED STRINGS FROM PLAY, never a formatted number of our own. Play
/// returns the price already rendered for the user's country and currency, and
/// a hand-formatted "$1.49" would be wrong in every market this launcher
/// actually targets.
final productPriceProvider = Provider.family<String?, String?>((ref, sku) {
  if (sku == null) return null;
  // Depend on the stream so prices appear as soon as start() resolves.
  ref.watch(ownedSkusProvider);
  return ref.watch(entitlementServiceProvider).products[sku]?.price;
});

/// Kick off a purchase. Returns false when the product is not loaded, which
/// means Play is unreachable or the SKU does not exist in the console.
final buyProvider = Provider<Future<bool> Function(String)>((ref) {
  return (sku) => ref.read(entitlementServiceProvider).buy(sku);
});

/// "Restore purchases", for a Settings row.
///
/// THAT ROW IS NOT OPTIONAL. A user who reinstalls, or signs in on a new phone,
/// has no other way to get their packs back, and its absence generates refund
/// requests from people who did nothing wrong.
final restorePurchasesProvider = Provider<Future<void> Function()>((ref) {
  return () => ref.read(entitlementServiceProvider).restore();
});

/// Registers the native callbacks and the purchase-completion listener.
///
/// WATCH THIS ONCE, AT THE APP ROOT. Pigeon's `setUp` replaces any previous
/// handler on the channel, so registering from a widget's `initState` would
/// silently unhook whichever instance registered before it, and the symptom is
/// a progress bar that works until you open a second screen. A provider is
/// registered once for the life of the container and cannot be double-installed.
///
/// It cannot live in `bootstrap()`: there is no ProviderContainer yet at that
/// point, because `runApp(ProviderScope(...))` has not been called.
final packBridgeProvider = Provider<void>((ref) {
  // KEPT ALIVE EXPLICITLY. Riverpod 3 auto-disposes a provider the moment its
  // last listener goes, and this one's VALUE is void — nothing reads it, so
  // nothing holds it beyond `_Root`'s watch. That watch is stable today, but a
  // provider whose entire purpose is a side effect must not depend on somebody
  // remembering to keep watching it: disposal here silently unhooks the
  // platform channel and every `onPackInstalled` fires into nowhere again.
  ref.keepAlive();

  registerPackFlutterApi(ref);

  // A completed purchase should start the download immediately. Making someone
  // pay, then find the theme and tap Get, is a second step for something they
  // have already committed to.
  //
  // Fire-and-forget with a guard: the entitlement push and this listener race,
  // and native re-checks entitlement before downloading anyway, so a download
  // that arrives a beat early simply reports notEntitled and the user taps
  // once. Awaiting the push here would serialise the two and make the common
  // case slower to protect the rare one.
  final service = ref.read(entitlementServiceProvider);
  final sub = service.purchased.listen((sku) async {
    await ref.read(packActionsProvider).pushEntitlements(service.ownedNow);
    ref.invalidate(catalogueProvider);
  });
  ref.onDispose(sub.cancel);
});
