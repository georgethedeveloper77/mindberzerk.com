import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../platform/pack_api.g.dart';

/// PHASE C — the Dart side of the store.
///
/// A repository, not direct Pigeon calls from widgets. Same rule the app list
/// follows: a screen that holds a host API can be mocked in exactly one way,
/// which is not at all.
///
/// WHAT THIS LAYER DOES NOT DO, and it is the important part: it does not
/// decide what is unlocked. `PackInfo.unlocked` arrives already resolved, from
/// `CdnIndex.isUnlocked` against the signed entitlement grants. Re-deriving it
/// here from `sku` plus a local owned-set would be a second implementation of
/// the ownership rule, in a different language, that nothing tests together —
/// and the day they disagree, one of them gives a pack away and the other
/// charges twice for it.

final packHostApiProvider = Provider<PackHostApi>((ref) => PackHostApi());

/// The catalogue. Cached index only, no network, so the storefront opens
/// instantly and works offline.
///
/// `ref.invalidate(catalogueProvider)` after a refresh or an install.
final catalogueProvider = FutureProvider<List<PackInfo>>((ref) async {
  final api = ref.watch(packHostApiProvider);
  final packs = await api.catalogue();
  // Pigeon's generated list is nullable-element typed; drop nulls once, here,
  // so no caller downstream has to think about it.
  return packs.whereType<PackInfo>().toList();
});

final bundlesProvider = FutureProvider<List<BundleInfo>>((ref) async {
  final api = ref.watch(packHostApiProvider);
  final bundles = await api.bundles();
  return bundles.whereType<BundleInfo>().toList();
});

/// One pack by id, or null. Derived from [catalogueProvider] rather than its own
/// bridge call, so a card and the sheet it opens can never disagree.
final packProvider = Provider.family<PackInfo?, String>((ref, packId) {
  final packs = ref.watch(catalogueProvider).asData?.value ?? const [];
  for (final p in packs) {
    if (p.packId == packId) return p;
  }
  return null;
});

/// Live download progress, 0.0 to 1.0, keyed by packId.
///
/// A plain Notifier holding a map rather than a family of providers: downloads
/// are serialised natively, so there is at most one live entry, and a family
/// would leak a provider per pack the user ever tapped.
class PackProgressNotifier extends Notifier<Map<String, double>> {
  @override
  Map<String, double> build() => const {};

  void report(String packId, double fraction) {
    state = {...state, packId: fraction};
  }

  void clear(String packId) {
    final next = {...state}..remove(packId);
    state = next;
  }
}

final packProgressProvider =
    NotifierProvider<PackProgressNotifier, Map<String, double>>(
  PackProgressNotifier.new,
);

/// Receives native callbacks. Registered ONCE, from bootstrap.
///
/// Pigeon's `setUp` replaces any previous handler on the channel, so
/// registering this from a widget's initState would silently unhook whichever
/// instance registered before it — and the symptom is a progress bar that works
/// until you open a second screen.
class PackFlutterApiImpl extends PackFlutterApi {
  PackFlutterApiImpl(this._ref);

  final Ref _ref;

  @override
  void onPackProgress(PackProgress progress) {
    if (progress.bytesTotal <= 0) return;
    _ref.read(packProgressProvider.notifier).report(
          progress.packId,
          progress.bytesDone / progress.bytesTotal,
        );
  }

  @override
  void onPackInstalled(String packId, int version) {
    _ref.read(packProgressProvider.notifier).clear(packId);
    // The catalogue's state strings (installed / updateAvailable) are computed
    // natively from what is on disk, so a re-read is the only way the card
    // learns it changed.
    _ref.invalidate(catalogueProvider);
  }
}

/// Call once from bootstrap, after the engine is up.
void registerPackFlutterApi(Ref ref) {
  PackFlutterApi.setUp(PackFlutterApiImpl(ref));
}

/// Actions. Deliberately functions rather than a controller: each one is a
/// single bridge call whose result the caller decides what to do with, and a
/// controller would only add a state machine nobody needs.
class PackActions {
  const PackActions(this._ref);
  final Ref _ref;

  /// Returns true when the catalogue changed and the UI should re-read.
  Future<bool> refresh() async {
    final changed = await _ref.read(packHostApiProvider).refreshCatalogue();
    if (changed) _ref.invalidate(catalogueProvider);
    return changed;
  }

  /// Download and install. The returned [PackResult.status] is what the caller
  /// branches on — never the detail string, which is for logs.
  ///
  /// Statuses worth distinct copy: `noSpace` and `appTooOld` are actionable,
  /// `notEntitled` means buy it first, `rejected` means a signature failed and
  /// must not be retried, `failed` is the only one worth a retry button, and
  /// `upToDate` is the common case and should say nothing at all.
  Future<PackResult> install(String packId) async {
    _ref.read(packProgressProvider.notifier).report(packId, 0);
    try {
      final result = await _ref.read(packHostApiProvider).installPack(packId);
      _ref.invalidate(catalogueProvider);
      return result;
    } finally {
      _ref.read(packProgressProvider.notifier).clear(packId);
    }
  }

  Future<void> cancel(String packId) =>
      _ref.read(packHostApiProvider).cancelInstall(packId);

  Future<bool> uninstall(String packId) async {
    final ok = await _ref.read(packHostApiProvider).uninstallPack(packId);
    _ref.invalidate(catalogueProvider);
    return ok;
  }

  /// Push the owned-SKU set down to native.
  ///
  /// Called after every Play Billing query, INCLUDING the one that comes back
  /// empty. Native starts with an empty set and never persists one, so it fails
  /// closed; forgetting to push after a purchase leaves the user having paid
  /// for a pack the download path still refuses.
  Future<void> pushEntitlements(Set<String> skus) async {
    await _ref.read(packHostApiProvider).setOwnedSkus(skus.toList());
    _ref.invalidate(catalogueProvider);
  }

  /// Hand native the Remote Config value, so the headless sync worker can read
  /// it with no Firebase dependency of its own.
  Future<void> pushCdnBaseUrl(String url) =>
      _ref.read(packHostApiProvider).setCdnBaseUrl(url);
}

final packActionsProvider = Provider<PackActions>(PackActions.new);
