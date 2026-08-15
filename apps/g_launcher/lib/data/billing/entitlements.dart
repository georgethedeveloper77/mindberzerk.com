import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g_account/g_account.dart';

// The cycle with terminal_entitlement.dart is deliberate and harmless: it reads
// this file's providers, this file reads its sku constant, and Dart resolves
// both lazily. boot_spec.dart and theme_spec.dart already pair the same way.
import '../../features/terminal/terminal_entitlement.dart';
import '../../platform/pack_api.g.dart';
import '../cdn/pack_repository.dart';
import '../prefs/prefs_repository.dart';
import 'pending_apply.dart';

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

    // ─── A PRODUCT THAT IS NOT IN THE CATALOGUE ────────────────────────────
    //
    // Everything above is derived from the signed index, which is the whole
    // argument for a catalogue rather than a compiled-in list: publish a paid
    // distro, attach its product ID, and it is purchasable with no app release.
    //
    // Terminal Pro is not a pack. It downloads nothing, it is signed by
    // nothing, and it appears nowhere in the index, so nothing above can name
    // it and Play would never be asked about it. No price would render and
    // `buy()` would return false, which presents as the product not existing.
    //
    // This is a constant and the doc on `kProductSkus` warned about exactly
    // that, so the distinction is worth being precise about: that constant was
    // wrong because it DERIVED what unlocks what, in a second place, from
    // stale strings. This only says "also ask Play about this product". The
    // ownership rule for packs is untouched and still lives once, natively.
    //
    // A second feature product goes here too. A second product that unlocks a
    // PACK does not: that is an index entitlement.
    kTerminalProSku,
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

/// Honour a purchase that was owed an apply, at startup.
///
/// ─── THE CASE THIS EXISTS FOR ───────────────────────────────────────────────
///
/// Buy Kali, open a game, and Android reclaims the launcher. `PackSyncWorker`
/// carries on and the pack lands correctly, because outliving the process is
/// the entire reason it is a worker. But the apply lived in Dart, and Dart is
/// gone, so the user comes back to a distro they paid for and a desktop that
/// ignored it. That is the original complaint, moved later and made harder to
/// see.
///
/// ─── AND WHY APPLYING AT LAUNCH IS NOT THE THING I ARGUED AGAINST ───────────
///
/// The objection to auto-applying is about swapping someone's desktop while
/// they are mid-task. It does not hold here: a launcher IS the home screen, so
/// at this moment they are looking at it deliberately, and finding what they
/// bought already on is the promise being kept.
///
/// [PendingApply] carries the expiry. Past its window the record lapses, the
/// card reads as installed, and a tap does what a tap does.
Future<void> _resumePendingApply(Ref ref) async {
  final store = ref.read(prefsStoreProvider);
  final sku = await PendingApply.take(store);
  if (sku == null) return;

  List<PackInfo> packs;
  try {
    packs = await ref.read(catalogueProvider.future);
  } catch (_) {
    // The catalogue could not be read, so the sku cannot be resolved to a
    // pack. The record is already consumed by `take`, which is right: a
    // retry loop over an intent nobody can see would be worse than one
    // missed apply that a single tap fixes.
    return;
  }

  for (final p in packs) {
    // INSTALLED, not merely owned. The worker may still be running, or may
    // have been deferred by an OEM battery manager for longer than the
    // download ever takes. Applying a theme whose pack is not on disk
    // resolves to nothing and falls back to Ubuntu, which is a worse outcome
    // than not applying at all.
    if (p.sku == sku && p.packType == 'theme' && p.installedVersion > 0) {
      await ref.read(selectedThemeIdProvider.notifier).select(p.packId);
      return;
    }
  }
}

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

  // ── A COMPLETED PURCHASE STARTS THE DOWNLOAD ITSELF ──────────────────────
  //
  // The comment here said this for months and the code did not do it: it
  // pushed entitlements, invalidated the catalogue, and stopped. So a purchase
  // unlocked a card and left it sitting there, and the user had to find the
  // theme again and tap Get. Paying and then being handed back an unchanged
  // screen reads as a failed transaction, which is the worst thing a paywall
  // can do.
  //
  // ─── EVERY PACK THE SKU UNLOCKS, NOT JUST THE THEME ──────────────────────
  //
  // `distro_kali` grants the theme AND its icon pack, and someone who bought
  // Kali bought Kali, not "a theme, with icons arriving in a couple of hours".
  // `PackInfo.sku` is already on every entry, so the catalogue answers this
  // without a second source of truth: install everything carrying this sku.
  //
  // The push is AWAITED first, unlike the fire-and-forget it replaces. Native
  // re-checks entitlement before downloading, so installing before the push
  // lands returns notEntitled and the user is back to tapping. That race was
  // acceptable when nothing auto-installed; it is the whole operation now.
  final service = ref.read(entitlementServiceProvider);
  final sub = service.purchased.listen((sku) async {
    await ref.read(packActionsProvider).pushEntitlements(service.ownedNow);
    ref.invalidate(catalogueProvider);

    List<PackInfo> packs;
    try {
      packs = await ref.read(catalogueProvider.future);
    } catch (_) {
      // The catalogue could not be read, so there is nothing to resolve the
      // sku against. The entitlement is pushed and permanent, so the card is
      // unlocked and one tap still works. Silence beats a message about an
      // internal step nobody initiated.
      return;
    }

    final mine = [for (final p in packs) if (p.sku == sku) p];
    if (mine.isEmpty) return;

    // Sequential: each install verifies signatures and writes to disk, and two
    // at once on a budget phone is how a download that would have worked runs
    // out of memory instead.
    final actions = ref.read(packActionsProvider);
    for (final p in mine) {
      await actions.install(p.packId);
    }

    // ── AND APPLY, ONLY IF THEY ARE STILL IN THE FLOW THEY STARTED ─────────
    //
    // See [PendingApply]. Consumed here whether or not a theme was among the
    // packs, because an intent that outlives its own purchase would fire on
    // the next unrelated one.
    final store = ref.read(prefsStoreProvider);
    final wanted = await PendingApply.take(store);
    if (wanted != sku) return;

    for (final p in mine) {
      // The THEME pack, not the icon pack. `installedPackDir` is what the
      // engine resolves a selection against, and selecting an icon pack id
      // would resolve to nothing and fall back to Ubuntu.
      if (p.packType == 'theme') {
        await ref.read(selectedThemeIdProvider.notifier).select(p.packId);
        break;
      }
    }
  });
  ref.onDispose(sub.cancel);

  // ── ONCE, AT STARTUP ─────────────────────────────────────────────────────
  //
  // In this provider's BODY rather than in `_Root.build`, because build runs
  // on every rebuild and this must run once. `keepAlive` above makes the
  // provider's lifetime the container's, so its body is the one place in this
  // app that is genuinely a single startup hook.
  //
  // Unawaited: nothing should wait on it, and it resolves against the
  // catalogue which the storefront is loading anyway.
  unawaited(_resumePendingApply(ref));
});
