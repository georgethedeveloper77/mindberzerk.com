// `unawaited`, for the active-theme push. Not already imported here: every
// other async call in this file is awaited by its caller.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/theme_engine.dart';
import '../../platform/pack_api.g.dart';
import '../prefs/prefs_repository.dart';
import 'pack_auto_update.dart';

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

/// The distro that just updated UNDERNEATH the desktop, or null.
///
/// ─── WHY THIS NEEDS SAYING AT ALL ───────────────────────────────────────────
///
/// A background sync can replace the pack the user is currently wearing while
/// they are looking at it. The wallpaper changes, the palette shifts, the icons
/// re-render, and nothing explains why. Unexplained is the whole problem: an
/// update reads as a glitch, and a launcher that appears to glitch on its own
/// is one people stop trusting with their home screen.
///
/// Set only for the SELECTED distro and only for a BACKGROUND install; see
/// [PackFlutterApiImpl.onPackInstalled] for how those two are told apart. It is
/// a signal rather than a message, so the copy and the chrome belong to
/// whatever is on screen rather than to this layer.
class ActiveDistroUpdated extends Notifier<String?> {
  @override
  String? build() => null;

  void report(String packId) => state = packId;

  /// Called by the displayer once it has said so. Not automatic on a timer:
  /// the launcher can be backgrounded when this fires, and a signal that
  /// expires unseen is a message the user never got.
  void consume() => state = null;
}

final activeDistroUpdatedProvider =
    NotifierProvider<ActiveDistroUpdated, String?>(ActiveDistroUpdated.new);

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
    // ── FOREGROUND OR BACKGROUND, AND THE ANSWER IS ALREADY HERE ─────────
    //
    // Read BEFORE the clear below, because the clear is what destroys the
    // evidence. `PackActions.install` reports 0 the instant the user taps Get,
    // so a progress entry existing means a human started this and is watching a
    // storefront card that will announce the result itself. No entry means
    // `PackSyncWorker` did it with nobody looking, which is the only case that
    // needs a word from us.
    //
    // Cheaper and more honest than threading a flag down through the native
    // bridge: the two paths converge on one Pigeon call on purpose, and adding
    // a parameter to tell them apart would undo that.
    final fromBackground = !_ref.read(packProgressProvider).containsKey(packId);

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
    if (selected == packId) {
      _ref.invalidate(activeThemeSpecProvider);

      // The desktop is about to change shape under someone's hands. See
      // [ActiveDistroUpdated].
      if (fromBackground) {
        _ref.read(activeDistroUpdatedProvider.notifier).report(packId);
      }
    }
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
  ///
  /// STAMPS THE FRESHNESS CLOCK, and does it here rather than in
  /// [catalogueRefreshProvider] so that EVERY route to a fetch resets it. A
  /// pull-to-refresh goes straight to this method, bypassing the provider by
  /// design; without the stamp here, closing the storefront and reopening it a
  /// second later would fetch again immediately.
  ///
  /// Before the await, not after. Two storefronts mounting in the same frame
  /// would otherwise both read a stale timestamp and both fetch.
  Future<bool> refresh() async {
    _lastCatalogueFetch = DateTime.now();
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

  /// Tell native which distro theme is applied.
  ///
  /// ─── THE SECOND HALF OF "IS THIS PACK AVAILABLE" ──────────────────────────
  ///
  /// [pushEntitlements] above answers "has this been paid for". This answers
  /// "did it come free with the distro in use", which is a different question
  /// with a different source: Play owns the first, Dart owns the second, and
  /// native can read neither on its own.
  ///
  /// Both are needed at the same two moments: when the icons screen decides
  /// whether to draw Get or a price, and when `installPack` re-checks
  /// immediately before transferring. Pushing only the first is what made a
  /// Kali device refuse its own Kali icons with "needs to be purchased first"
  /// while the card beside it said Get.
  ///
  /// CALLED ON EVERY THEME CHANGE, including back to a bundled distro. Native
  /// never persists this, so it fails closed on a restart and a missed push
  /// costs an unnecessary purchase prompt rather than a free pack.
  ///
  /// An empty string clears it, which is the honest value while no theme has
  /// resolved yet. Sending nothing at all would leave native holding the
  /// previous distro's answer.
  Future<void> pushActiveTheme(String? themeId) async {
    await _ref.read(packHostApiProvider).setActiveTheme(themeId ?? '');
    // The catalogue's `unlocked` flags are computed natively from this, so the
    // shelf is stale until it is re-read. Same reflex as pushEntitlements.
    _ref.invalidate(catalogueProvider);
  }

  /// Hand native the Remote Config value, so the headless sync worker can read
  /// it with no Firebase dependency of its own.
  Future<void> pushCdnBaseUrl(String url) =>
      _ref.read(packHostApiProvider).setCdnBaseUrl(url);
}

final packActionsProvider = Provider<PackActions>(PackActions.new);

/// Keeps native told which distro is applied.
///
/// ─── THE CALLER THAT WAS MISSING ────────────────────────────────────────────
///
/// [PackActions.pushActiveTheme] existed and nothing called it, so native held
/// null forever and `isIncludedWith` answered false for everything. The result
/// was the worst possible pairing on the icons screen: the CARD said Get,
/// because Dart knows the applied theme, and the INSTALL said "needs to be
/// purchased first", because native did not. Same pack, same second, two
/// answers.
///
/// ─── AND WHY IT WATCHES THE RESOLVED SPEC, NOT THE SELECTION ────────────────
///
/// It watched `selectedThemeIdProvider` and returned early on null, which
/// reintroduced the exact failure above for the users most likely to hit it.
///
/// A null selection is not "no distro". It is the ordinary state of anyone who
/// has never opened the distros screen: `activeThemeSpecProvider` reads that
/// same null, falls through its bundled floor, and resolves Ubuntu. So the
/// device is running Ubuntu, Dart knows it is running Ubuntu, and this pushed
/// nothing at all. Native kept null, `ubuntu-24-04-line` was neither owned nor
/// included, and tapping it answered "Ubuntu Icons needs to be purchased
/// first" on a device running Ubuntu.
///
/// `activeThemeSpecProvider` is the one thing that always has an answer and
/// always has the RIGHT one: it is the id the theme actually resolved to, after
/// the installed-pack lookup, the bundled fallback and the Ubuntu floor. A
/// selection is a request; this is the result, and inclusion is a fact about
/// the result.
///
/// Mirrors the entitlement push in `entitlements.dart` exactly: watch the one
/// source of truth, push on every change including the first, never persist.
/// Ownership and inclusion are different facts from different owners, and both
/// have to reach the same place before an install is allowed.
///
/// WATCHED, not read once. Switching distro is precisely the moment the answer
/// changes, and a stale value here does not degrade gracefully: it refuses a
/// pack the user is entitled to.
final activeThemePushProvider = Provider<void>((ref) {
  // Only a resolved value. `loading` is not "no theme", and pushing empty
  // during startup would clear a correct answer for as long as the read takes.
  final spec = ref.watch(activeThemeSpecProvider).asData?.value;
  if (spec == null) return;
  // Fire and forget is right here, unlike the purchase path: nothing is waiting
  // on this, and the next change pushes again. A dropped push costs one
  // unnecessary purchase prompt, never a pack given away.
  unawaited(ref.read(packActionsProvider).pushActiveTheme(spec.id));
});

/// Refresh the catalogue whenever a storefront is opened, at most once every
/// [_refreshInterval].
///
/// ─── WHY THIS IS NOT `keepAlive` AND NOT ONCE PER RUN ───────────────────────
///
/// It was both, and for a LAUNCHER that is close to never. This process is the
/// home screen: it is started once and lives for days, so "once per app run"
/// meant a distro published on Monday was invisible until the process died.
/// The user would have to pull to refresh to see something they had no reason
/// to believe existed, which is not a discovery mechanism.
///
/// So it AUTO-DISPOSES, which is Riverpod's default and is exactly the behaviour
/// wanted here: the provider lives while a storefront is on screen and is
/// dropped when the last one closes, so the next open re-runs it and re-asks the
/// CDN. Opening Distros IS the refresh.
///
/// ─── THE INTERVAL IS WHAT STOPS THAT BEING RUDE ─────────────────────────────
///
/// Without it, flicking between Distros and Icons, or backing out and returning,
/// would fetch every time. The timestamp is module-level rather than provider
/// state deliberately: it has to survive the disposal that makes the re-run
/// happen at all, so holding it inside the provider would defeat the whole
/// mechanism.
///
/// Twenty seconds is short enough that publishing something and reaching for
/// your phone finds it, and long enough that navigation costs nothing.
///
/// ─── THE FETCH IS CHEAPER THAN IT LOOKS ─────────────────────────────────────
///
/// `refresh` sends an ETag, so the overwhelmingly common answer is a 304 with no
/// body, and `catalogueProvider` is only invalidated when something actually
/// changed. An unchanged catalogue costs one conditional request and no rebuild.
///
/// Its VALUE is deliberately ignored by callers — the invalidate is the point.
/// It returns the bool anyway so a pull-to-refresh can say "up to date" rather
/// than flashing a spinner over an identical list.
DateTime? _lastCatalogueFetch;

/// Long enough that navigating between the two storefronts is free, short enough
/// that a distro published a minute ago is there when you look.
const _refreshInterval = Duration(seconds: 20);

final catalogueRefreshProvider = FutureProvider<bool>((ref) async {
  final last = _lastCatalogueFetch;
  if (last != null && DateTime.now().difference(last) < _refreshInterval) {
    return false;
  }
  // ─── AND INSTALL WHAT WENT STALE ────────────────────────────────────────
  //
  // `refreshAndAutoUpdate` is `refresh()` plus its consequence: a catalogue
  // that MOVED is exactly the moment a pack on disk can have become stale, and
  // the only moment worth walking the list.
  //
  // Here rather than at each screen, because this provider is already the one
  // throttled entry point: it holds `_lastCatalogueFetch` and refuses inside
  // the interval. Wiring the updater into the callers instead would give every
  // storefront its own copy of that decision, and one of them would eventually
  // forget the throttle.
  //
  // Pull-to-refresh does not come through this provider (it bypasses the
  // throttle by design), but it calls the same `refreshAndAutoUpdate`, so every
  // route to a fetch has the same consequence. That is the point: a rule that
  // holds on one path and not another is a rule someone has to remember.
  return refreshAndAutoUpdate(
    ref.read(packActionsProvider),
    ref.read(packAutoUpdaterProvider),
  );
});
