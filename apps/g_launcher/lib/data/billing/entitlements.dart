import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g_account/g_account.dart';

import '../../platform/pack_api.g.dart';
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

/// Every SKU worth asking Play about, DERIVED FROM THE SIGNED INDEX.
///
/// ─── THIS REPLACES A HARDCODED SET, AND THE SET WAS WRONG ───────────────────
///
/// `kProductSkus` used to be a const of ten strings — `distro_pack_kali`,
/// `bundle_tiling`, `distro_pack_all` and friends. Not one of them exists in
/// the Play console, which lists `distro_kali`, `icons_kali`,
/// `bundle_all_distros` and four others. Every product came back in
/// `notFoundIDs`, so no price ever rendered and no purchase could be observed.
/// The panel's `skus.ts` had the right scheme the whole time; only the app
/// disagreed.
///
/// Correcting the constant would have worked until the eighth distro. The list
/// belongs in the index because that is where a sku is ATTACHED: the panel
/// writes `"sku": "distro_kali"` onto a pack, signs the index, and the phone
/// reads it. Publish a paid distro, attach its product ID, and it is
/// purchasable — no app release, which is the entire argument for a signed
/// catalogue rather than a compiled-in one.
///
/// ─── WHY A STRING AND NOT A Set ─────────────────────────────────────────────
///
/// Riverpod collapses a no-op re-emit by comparing with `==`, and `Set` in Dart
/// uses IDENTITY equality. Returning a Set here would produce a brand-new object
/// on every catalogue rebuild, `ownedSkusProvider` would re-run, and `start()`
/// would re-query Play and re-restore on every pack install. A sorted joined
/// string compares by value, so this only moves when the SKUs genuinely change.
///
/// Bundles are included: `bundle_all_distros` is a product a user can own, and
/// `CdnIndex.isUnlocked` checks entitlement grants against exactly that.
final productSkusProvider = Provider<String>((ref) {
  final packs = ref.watch(catalogueProvider).asData?.value ?? const <PackInfo>[];
  final bundles = ref.watch(bundlesProvider).asData?.value ?? const <BundleInfo>[];

  final skus = <String>{
    for (final p in packs)
      if (p.sku != null && p.sku!.isNotEmpty) p.sku!,
    for (final b in bundles)
      if (b.sku.isNotEmpty) b.sku,
  };

  final sorted = skus.toList()..sort();
  return sorted.join(',');
});

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

  // WATCHED, so this re-runs when the catalogue names a sku it did not before.
  // That is the whole mechanism: publish a paid distro, the index changes, the
  // next refresh brings it down, and Play is asked about it without a release.
  final joined = ref.watch(productSkusProvider);
  final skus = joined.isEmpty ? <String>{} : joined.split(',').toSet();

  // Push down to native on every change, INCLUDING the empty first emit.
  // Native starts empty and never persists, so a missed push after a purchase
  // leaves someone who has paid staring at a download that refuses.
  final sub = service.owned.listen((owned) {
    ref.read(packActionsProvider).pushEntitlements(owned);
  });
  ref.onDispose(sub.cancel);

  // CALLED EVEN WITH AN EMPTY SET, and that is deliberate. On the very first
  // launch the cached catalogue is empty, so nothing is priced yet — but a
  // returning user still owns what they own, and `start` connects, subscribes
  // and restores regardless. `EntitlementService` skips only the product query
  // when there is nothing to query.
  //
  // Called AGAIN when the catalogue lands, which is safe by construction: the
  // purchase subscription is guarded by `??=`, products merge rather than
  // replace, and restore is documented as repeatable.
  //
  // Fire and forget: start() does network work and nothing should wait on it.
  // The storefront renders from the cached catalogue meanwhile.
  unawaited(service.start(skus));

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
