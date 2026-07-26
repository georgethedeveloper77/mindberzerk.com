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

/// The catalogue, merged with what is on disk.
///
/// ─── SOMETHING MUST WATCH THIS, OR THE WIRE IS NOT CONNECTED ────────────────
///
/// Riverpod providers are lazy, and [build] is where [PackFlutterApi] gets
/// registered. If no widget ever watches this provider, the registration never
/// runs and `onPackInstalled` goes back to firing into nowhere — which is
/// exactly the bug this file exists to fix, reintroduced by absence rather than
/// by a mistake anyone can see in a diff.
///
/// The background sync worker can install a pack while the app is foregrounded
/// and no storefront is open, so this must be warmed at startup rather than
/// when a store screen mounts. A `ref.watch(packCatalogueProvider)` in the root
/// widget is enough.
final packCatalogueProvider =
    AsyncNotifierProvider<PackCatalogue, List<PackInfo>>(PackCatalogue.new);

class PackCatalogue extends AsyncNotifier<List<PackInfo>> {
  @override
  Future<List<PackInfo>> build() async {
    // Registered BEFORE the first host call, the same ordering `AppList.build`
    // uses and for the same reason: an install completing mid-startup must not
    // be dropped on the floor.
    PackFlutterApi.setUp(_PackSink(onProgress: _onProgress, onInstalled: _onInstalled));

    // The CACHED index only. No network, so the store opens instantly and works
    // on a plane; [refresh] is the explicit fetch.
    return ref.read(packHostApiProvider).catalogue();
  }

  void _onProgress(PackProgress p) {
    if (p.bytesTotal <= 0) return;
    ref.read(packProgressProvider.notifier).report(
          p.packId,
          p.bytesDone / p.bytesTotal,
        );
  }

  void _onInstalled(String packId, int version) {
    ref.read(packProgressProvider.notifier).done(packId);

    // Re-read what is installed, so the card flips from Get to Installed.
    ref.invalidateSelf();

    // ─── THE LINE THAT MAKES A PURCHASE VISIBLE ────────────────────────────
    //
    // `activeThemeSpecProvider` resolved once, at startup or at the last theme
    // switch, and cached the answer. A theme pack landing on disk after that is
    // invisible to it: the selection has not changed, so nothing re-runs, and
    // the phone keeps rendering the Ubuntu fallback it correctly resolved
    // when the pack was not yet there.
    //
    // GATED ON THE SELECTION rather than invalidated unconditionally. Rebuilding
    // the theme cascades into `effectiveThemeProvider`, which re-pushes the icon
    // style, re-keys every app-list family and re-checks the wallpaper. Doing
    // all that because an unrelated pack finished downloading in the background
    // is a visible hitch on the home screen for no reason.
    //
    // The case this catches is the important one and it is the ordinary one:
    // select a distro you do not own yet, the launcher falls back to Ubuntu,
    // you install it, and the desktop becomes the thing you chose.
    final selected = ref.read(selectedThemeIdProvider).asData?.value;
    if (selected == packId) ref.invalidate(activeThemeSpecProvider);
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
  /// which does it. Doing both would re-read the catalogue twice per install.
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

/// Native's callbacks, adapted onto the notifier.
///
/// A plain class rather than the notifier implementing [PackFlutterApi] itself,
/// mirroring `_AppListSink`. Pigeon's generated interface grows methods over
/// time and a notifier that also implements it starts failing to compile for
/// reasons that have nothing to do with state management.
class _PackSink implements PackFlutterApi {
  _PackSink({required this.onProgress, required this.onInstalled});

  final void Function(PackProgress) onProgress;
  final void Function(String packId, int version) onInstalled;

  @override
  void onPackProgress(PackProgress progress) => onProgress(progress);

  @override
  void onPackInstalled(String packId, int version) => onInstalled(packId, version);
}
