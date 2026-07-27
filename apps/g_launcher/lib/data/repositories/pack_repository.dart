/// THE DART HALF OF THE STOREFRONT.
///
/// Native could already download, verify and install a pack, and Dart could
/// already read one back off disk. What was missing is the wire between them:
/// nothing implemented [PackFlutterApi], so `onPackInstalled` fired into
/// nowhere. A theme could be fetched, verified and written to the packs root,
/// and the desktop would keep rendering whatever it resolved at startup until
/// the process died. To a user that is indistinguishable from the download
/// having failed, which is the single most expensive bug shape in this whole
/// pipeline: everything worked, and nothing happened.
///
/// ─── FREE PACKS NEED NO BILLING ─────────────────────────────────────────────
///
/// Worth stating because it is the thing that makes a free release useful.
/// `CdnIndex.isUnlocked` returns true for any pack with no SKU, and native
/// starts with an EMPTY owned-SKU set and fails closed. So free CDN distros —
/// Mint, Fedora, Debian, anything the panel publishes without a price — install
/// and render with zero billing code on either side. `setOwnedSkus` stays
/// unwired until there is something to sell.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/theme_engine.dart';
import '../../platform/pack_api.g.dart';
import '../prefs/prefs_repository.dart';

/// The store's native handle. Separate schema, separate codec, separate impl
/// from [launcherHostApiProvider]; see `pigeons/pack_api.dart` for why.
final packHostApiProvider = Provider<PackHostApi>((ref) => PackHostApi());

/// In-flight downloads: packId -> 0.0 to 1.0. Absent means not downloading.
///
/// SEPARATE FROM THE CATALOGUE, deliberately. Progress ticks roughly every 2%
/// (native throttles it), and folding it into the catalogue's state would
/// rebuild every card in the list fifty times per install so that one of them
/// could move a bar.
final packProgressProvider =
    NotifierProvider<PackProgressNotifier, Map<String, double>>(
  PackProgressNotifier.new,
);

class PackProgressNotifier extends Notifier<Map<String, double>> {
  @override
  Map<String, double> build() => const {};

  void report(String packId, double fraction) {
    state = {...state, packId: fraction.clamp(0.0, 1.0)};
  }

  void done(String packId) {
    if (!state.containsKey(packId)) return;
    state = {...state}..remove(packId);
  }
}

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
final iconPackGenerationProvider =
    NotifierProvider<IconPackGeneration, int>(IconPackGeneration.new);

class IconPackGeneration extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}

/// The catalogue, merged with what is on disk.
///
/// A PURE READER. It does NOT register [PackFlutterApi] — `packBridgeProvider`
/// does, and the separation is not tidiness.
///
/// Pigeon's `setUp` REPLACES whatever handler is on the channel. If this
/// registered as well, then whichever of the two resolved last would silently
/// unhook the other, and the symptom is a progress bar that works until you
/// open a second screen. Exactly one place may call it.
///
/// It also decouples lifetime from interest: the bridge must be listening while
/// the background sync worker installs a pack with no storefront open, and
/// tying that to whether anyone is looking at a catalogue is how it stops
/// happening.
final packCatalogueProvider =
    AsyncNotifierProvider<PackCatalogue, List<PackInfo>>(PackCatalogue.new);

class PackCatalogue extends AsyncNotifier<List<PackInfo>> {
  @override
  Future<List<PackInfo>> build() {
    // The CACHED index only. No network, so the store opens instantly and works
    // on a plane; [refresh] is the explicit fetch.
    return ref.read(packHostApiProvider).catalogue();
  }

  /// Ask the CDN for a newer index, then re-read if it changed.
  ///
  /// Returns whether anything moved, so a pull-to-refresh can say "up to date"
  /// rather than flashing a spinner and leaving the list identical.
  Future<bool> refresh() async {
    final changed = await ref.read(packHostApiProvider).refreshCatalogue();
    if (changed) ref.invalidateSelf();
    return changed;
  }

  /// Download, verify and install.
  ///
  /// The result is RETURNED rather than swallowed, because the statuses are not
  /// interchangeable: `upToDate` must be silent, `noSpace` and `appTooOld` need
  /// their own copy, `rejected` means a signature failed and must never offer a
  /// retry. The caller branches on `status`. See `PackResult` in the schema.
  ///
  /// No `invalidateSelf` here: a successful install fires `onPackInstalled`,
  /// which `packBridgeProvider` handles. Doing both would re-read the catalogue
  /// twice per install.
  Future<PackResult> install(String packId) {
    return ref.read(packHostApiProvider).installPack(packId);
  }

  Future<void> cancel(String packId) async {
    await ref.read(packHostApiProvider).cancelInstall(packId);
    ref.read(packProgressProvider.notifier).done(packId);
  }

  /// Remove an installed pack.
  ///
  /// Uninstalling the theme you are WEARING is legitimate: the pack goes, the
  /// selection stays, and `activeThemeSpecProvider` falls back to bundled Ubuntu
  /// on the next resolve. That is the same guaranteed floor a corrupt pack or a
  /// downgrade lands on, so it needs no special case here beyond re-resolving.
  Future<bool> uninstall(String packId) async {
    final ok = await ref.read(packHostApiProvider).uninstallPack(packId);
    if (!ok) return false;

    ref.invalidateSelf();
    final selected = ref.read(selectedThemeIdProvider).asData?.value;
    if (selected == packId) ref.invalidate(activeThemeSpecProvider);
    return true;
  }
}
