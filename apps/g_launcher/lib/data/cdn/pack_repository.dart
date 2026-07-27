import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/theme_engine.dart';
import '../../platform/pack_api.g.dart';
import '../prefs/prefs_repository.dart';

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
///
/// ─── THIS FILE ABSORBED `data/repositories/pack_repository.dart` ────────────
///
/// There were TWO of these, and they were not a layering — they were the same
/// job written twice, each with a `packProgressProvider`, each with a catalogue,
/// each with a `PackFlutterApi.setUp`. Both files' own docblocks warned at
/// length that `setUp` REPLACES rather than adds and that exactly one place may
/// call it. Two files each obeying that rule internally still register twice.
///
/// `_Root` in app.dart watched the OTHER one, so the live registration was the
/// repositories copy and this one's was dead code. What that cost, concretely:
///
///   1. THE PROGRESS BAR NEVER MOVED. Native reported into the repositories
///      notifier; `themes_screen` read this one. The bar sat at 0% for an entire
///      download and then vanished, which reads exactly like a hung transfer.
///   2. A HEADLESS INSTALL NEVER REPAINTED THE STOREFRONT. `PackSyncWorker`
///      lands packs with no store screen open; the invalidate went to the
///      catalogue nothing was watching.
///   3. A COMPLETED PURCHASE DID NOT START ITS DOWNLOAD, because that listener
///      lives in `entitlements.packBridgeProvider`, which nothing watched.
///
/// It also only COMPILED because no single file imported both: they export the
/// same top-level names, so the first file to need both would have failed on an
/// ambiguous `packBridgeProvider`.
///
/// This one survived because it carries [packActionsProvider], [bundlesProvider]
/// and [packProvider], and because `entitlements.dart` already depended on it.
/// What came across from the other: [iconPackGenerationProvider], and the two
/// extra jobs [PackFlutterApiImpl.onPackInstalled] has to do.

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
    // Clamped, because the value is derived from a byte count and a signed
    // total, and a progress bar that renders past its own track because of a
    // rounding artefact looks broken in a way nobody can explain.
    state = {...state, packId: fraction.clamp(0.0, 1.0)};
  }

  void clear(String packId) {
    if (!state.containsKey(packId)) return;
    final next = {...state}..remove(packId);
    state = next;
  }
}

final packProgressProvider =
    NotifierProvider<PackProgressNotifier, Map<String, double>>(
  PackProgressNotifier.new,
);

/// Moves every time a pack lands. Part of the Dart icon cache key.
///
/// ─── WHY A COUNTER AND NOT SOMETHING MORE PRECISE ───────────────────────────
///
/// A hero or brand pack keeps its id across an update — that is what an update
/// is — so nothing in `EffectiveTheme.iconCacheId` changes when one installs,
/// and no Riverpod key moves. Meanwhile `IconCache.onPackChanged` has just
/// wiped native's memory AND disk tiers, because the pack id is in its key but
/// the pack VERSION is not. So native is ready to draw the new artwork and Dart
/// never asks, and the launcher shows the old icons until the process dies.
///
/// BUMPED ON EVERY INSTALL, including theme packs that cannot affect icons.
/// That looks over-eager and is exactly right: native clears its caches on every
/// install too, so after any pack lands every icon has to be re-rendered
/// regardless. Being cleverer here would make Dart and native disagree about
/// when a re-render is needed, which is the whole class of bug this counter
/// exists to end.
///
/// Moved here from `data/repositories/pack_repository.dart` when the two
/// storefronts merged. `AppIcon` reads it; see the note on [IconRequest.cacheId].
final iconPackGenerationProvider =
    NotifierProvider<IconPackGeneration, int>(IconPackGeneration.new);

class IconPackGeneration extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}

/// Receives native callbacks. Registered ONCE, from [packBridgeProvider] in
/// `data/billing/entitlements.dart`, which `_Root` watches.
///
/// Pigeon's `setUp` replaces any previous handler on the channel, so
/// registering this from a widget's initState would silently unhook whichever
/// instance registered before it — and the symptom is a progress bar that works
/// until you open a second screen. That is not hypothetical: it is what the
/// duplicate file described at the top of this one actually did.
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

    // ── EVERY ICON HAS TO BE RE-REQUESTED ────────────────────────────────
    //
    // Came across in the merge. Native clears BOTH its cache tiers on any
    // install, so the bitmaps Dart is holding no longer correspond to anything
    // native would draw — but no Riverpod key moved, because a pack keeps its
    // id across an update. Without this bump the launcher shows the old artwork
    // until the process dies, which is indistinguishable from the download
    // having failed. See [iconPackGenerationProvider].
    _ref.read(iconPackGenerationProvider.notifier).bump();

    // The catalogue's state strings (installed / updateAvailable) are computed
    // natively from what is on disk, so a re-read is the only way the card
    // learns it changed.
    _ref.invalidate(catalogueProvider);

    // ── THE LINE THAT MAKES A PURCHASE VISIBLE ───────────────────────────
    //
    // Also from the merge, and the most valuable line in the file.
    // `activeThemeSpecProvider` resolved once, at startup or at the last theme
    // switch, and cached the answer. A theme pack landing on disk after that is
    // invisible to it: the selection has not changed, so nothing re-runs, and
    // the phone keeps rendering the Ubuntu fallback it correctly resolved when
    // the pack was not yet there.
    //
    // GATED ON THE SELECTION rather than invalidated unconditionally. Rebuilding
    // the theme cascades into `effectiveThemeProvider`, which re-pushes the icon
    // style, re-keys every app-list family and re-checks the wallpaper. Doing
    // all that because an unrelated pack finished downloading in the background
    // is a visible hitch on the home screen for nothing.
    //
    // The case it catches is the ordinary one: select a distro you do not own
    // yet, the launcher falls back to Ubuntu, you install it, and the desktop
    // becomes the thing you chose.
    final selected = _ref.read(selectedThemeIdProvider).asData?.value;
    if (selected == packId) _ref.invalidate(activeThemeSpecProvider);
  }
}

/// Call once from [packBridgeProvider], after the container exists.
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

    // Uninstalling the pack you are WEARING is legitimate: the pack goes, the
    // selection stays, and `activeThemeSpecProvider` falls back to bundled
    // Ubuntu on the next resolve. That is the same guaranteed floor a corrupt
    // pack or a downgrade lands on — but it only happens if something asks it
    // to resolve again, which is this line.
    if (ok) {
      final selected = _ref.read(selectedThemeIdProvider).asData?.value;
      if (selected == packId) _ref.invalidate(activeThemeSpecProvider);
    }
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

/// ONE network refresh per app run, fired the first time a storefront is opened.
///
/// ─── WITHOUT THIS, NOTHING PUBLISHED EVER REACHES A PHONE ───────────────────
///
/// [catalogueProvider] reads the CACHED index and deliberately never touches the
/// network, which is what makes the storefront open instantly and work on a
/// plane. [PackActions.refresh] is the explicit fetch. Nothing called it.
///
/// `themes_screen`'s own docblock claimed "a refresh runs in the background on
/// open", and it was the only description of a behaviour that did not exist. On
/// a device with an empty cache — every device, on first install — the
/// catalogue was empty, no card could appear, and the entire publishing
/// pipeline was invisible. `PackSyncWorker` would have papered over it
/// eventually, on its own schedule, which is worse: intermittent rather than
/// absent.
///
/// A PROVIDER RATHER THAN AN initState, so both storefronts share one
/// implementation and cannot drift, and so the fetch happens exactly once
/// however many times either screen is opened. [ref.keepAlive] is what makes
/// that true: without it Riverpod disposes the provider when the last screen
/// closes and the next open re-fetches.
///
/// Its VALUE is deliberately ignored by callers — `refresh()` already
/// invalidates [catalogueProvider] when something actually changed, so watching
/// this is enough. It returns the bool anyway so a pull-to-refresh can say "up
/// to date" rather than flashing a spinner over an identical list.
final catalogueRefreshProvider = FutureProvider<bool>((ref) async {
  ref.keepAlive();
  return ref.read(packActionsProvider).refresh();
});
