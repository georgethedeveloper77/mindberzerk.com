/// "Make sure this distro's packs are actually on the device."
///
/// ─── THE SENTENCE NOBODY WAS SAYING ─────────────────────────────────────────
///
/// Every piece of this already existed. `PackActions.refresh` fetches the
/// signed index behind an ETag, `install` downloads and verifies one pack,
/// `pushActiveTheme` tells native which distro is worn so an included pack
/// stops reading as unpaid, and `EffectiveTheme.resolve` derives the icon pack
/// a distro wants through `defaultLinePackFor`. What was missing is the line
/// that runs them in order, at the two moments a distro becomes the one you are
/// looking at.
///
/// So the same three failures kept appearing in different clothes:
///
///   1. FIRST RUN HAD NO CATALOGUE AT ALL. `PackHostApiImpl.catalogue` reads
///      `downloader.cachedIndex()`, which is null until something fetches, and
///      the only fetchers were `catalogueRefreshProvider` (auto-dispose, alive
///      only while a storefront is on screen), a pull-to-refresh, and
///      `PackSyncWorker`, whose periodic schedule carries an initial delay. Set
///      up a phone and nothing in the wizard opens a storefront, so for that
///      whole delay the app believed the catalogue was the five bundled ids.
///      Every pack lookup during setup silently answered "not in the
///      catalogue" and every caller `continue`d.
///
///   2. APPLYING A DISTRO NEVER FETCHED ITS ICONS. `_apply` in `theme_actions`
///      wrote the selection and returned. `resolve` then asked for
///      `kde-plasma-6-line`, `BrandIconResolver` found nothing on disk, and the
///      generator drew. The only thing that ever installed those was
///      `SetupScreen._installDistroIcons`, which ran once, at the end of setup,
///      for one distro. Hence "the icons do not ALWAYS apply": they applied for
///      whichever distro you finished setup on, and for anything you had since
///      tapped on the icons screen.
///
///   3. THE ENTITLEMENT PUSH WAS RACED. Native gates a download on
///      `index.isAvailable(packId, ownedSkus, activeThemeId)`, and
///      `activeThemePushProvider` sends the theme id through `unawaited`. An
///      install fired straight after a switch can reach native before the push
///      lands and come back `notEntitled` for a pack that comes free with the
///      distro. Intermittent, which is why it reads as flaky rather than wrong.
///      [DistroPacks] awaits the push before installing anything.
///
/// ─── IT IS CHEAP, WHICH IS WHY IT CAN BE UNCONDITIONAL ──────────────────────
///
/// A brand line pack is `{v, id, name, extends, tint, license, attribution}`
/// and nothing else: it inherits its geometry from `simple-icons`, which ships
/// in the APK. `arch-linux-line` is 491 bytes. A distro theme pack with its
/// wallpapers is around 140KB. So the whole of this, on a switch, is a
/// conditional index request and well under a kilobyte of icon pack.
///
/// ─── AND WHY ICONS ARE A SEPARATE SCOPE ─────────────────────────────────────
///
/// A brand line pack really is 491 bytes, and that is exactly what makes it
/// dangerous to fetch silently. It is `{ id, name, extends, tint }` and nothing
/// more: all fourteen point at `arcticons-line`, which carries the 13,622
/// drawings they share and weighs 10.58 MB. The index declares that in
/// `requires`, and `PackDownloader.syncPack` walks it recursively BEFORE
/// transferring, refusing the pointer if the base fails rather than installing
/// something that would verify and render nothing.
///
/// So asking for a 491-byte pack is asking for ten megabytes, once, and the
/// audience this app targets is on mobile data more often than not. That is not
/// a decision to make on somebody's behalf during a setup wizard.
///
/// Hence [DistroPackScope]. The theme pack is small, unavoidable and the thing
/// the desktop is drawn from, so it goes without asking. The icon pack is a
/// question, and setup's icon step is where it gets asked.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/effective_theme.dart' show defaultLinePackFor;
import '../../engine/theme_engine.dart';
import '../../engine/theme_spec.dart';
import '../../platform/pack_api.g.dart';
import 'pack_repository.dart';

/// What [DistroPacks] is doing right now.
enum DistroPackPhase {
  /// Nothing has been asked for yet.
  idle,

  /// Fetching the signed index. Two kilobytes behind an ETag, and on a fresh
  /// device the only reason anything else in this file can work.
  refreshing,

  /// Downloading packs, one at a time.
  installing,

  /// Everything this distro needs is on disk, or is not in the catalogue and
  /// never will be. Both are finished states: see [DistroPackState.themeReady].
  done,
}

/// The progress of one [DistroPacks.ensure] pass, for a screen that wants to
/// show it. Nothing is required to.
@immutable
class DistroPackState {
  const DistroPackState({
    this.themeId,
    this.phase = DistroPackPhase.idle,
    this.themeReady = false,
    this.label,
    this.done = 0,
    this.total = 0,
  });

  /// The distro this pass is for. A screen must compare this against its own
  /// selection rather than trusting the phase: a swipe supersedes the pass in
  /// flight, and for a frame or two the state still describes the old one.
  final String? themeId;

  final DistroPackPhase phase;

  /// Is the DISTRO's own pack settled?
  ///
  /// ─── THE ONLY THING WORTH BLOCKING ON ─────────────────────────────────
  ///
  /// True once the theme pack is installed, already current, or absent from the
  /// catalogue. Setup gates Continue on this and nothing else, because a theme
  /// pack is what decides whether the desktop draws at all, while an icon pack
  /// arriving four seconds later just means four seconds of generated icons.
  ///
  /// Holding the wizard until every pack landed would make a slow connection
  /// look like a hang on the one screen where the user has no idea what the app
  /// is waiting for.
  final bool themeReady;

  /// The pack being fetched, for a status line. Null while refreshing.
  final String? label;

  final int done;
  final int total;

  bool get busy =>
      phase == DistroPackPhase.refreshing || phase == DistroPackPhase.installing;

  DistroPackState copyWith({
    String? themeId,
    DistroPackPhase? phase,
    bool? themeReady,
    String? label,
    int? done,
    int? total,
  }) =>
      DistroPackState(
        themeId: themeId ?? this.themeId,
        phase: phase ?? this.phase,
        themeReady: themeReady ?? this.themeReady,
        label: label ?? this.label,
        done: done ?? this.done,
        total: total ?? this.total,
      );
}

class DistroPacks extends Notifier<DistroPackState> {
  @override
  DistroPackState build() => const DistroPackState();

  /// Supersedes an in-flight pass rather than cancelling it.
  ///
  /// A user swiping the distro deck changes their mind faster than a download
  /// finishes, and `PackActions.install` has no cancellation this side of the
  /// native `cancelInstall`. So a newer call takes the token and the older one
  /// keeps running to completion while writing no more state. The stale pass
  /// still finishes its install, which is the right outcome: the bytes are
  /// already paid for and a distro the user may swipe back to is now on disk.
  int _token = 0;

  /// Has the index been fetched at least once in this process?
  ///
  /// Not the same question as `catalogueRefreshProvider`'s twenty-second clock.
  /// That one throttles a storefront being reopened; this one exists so a swipe
  /// through three distros does not fetch three times, while still guaranteeing
  /// the very first call fetches on a device that has never had an index.
  bool _refreshed = false;

  /// Everything [themeId] needs at this [scope], in the order it needs it.
  ///
  /// Never throws and never reports a failure. A pack that will not download is
  /// a distro that renders from the APK or draws generated icons, which is the
  /// same floor the app has always guaranteed, and a message about a background
  /// step the user did not start is how a launcher teaches people to ignore it.
  /// The storefront still says Update, and tapping it gives the real error with
  /// the real copy.
  Future<void> ensure(
    String themeId, {
    DistroPackScope scope = DistroPackScope.all,
    bool force = false,
  }) async {
    final token = ++_token;
    void publish(DistroPackState next) {
      if (token == _token) state = next;
    }

    publish(DistroPackState(themeId: themeId, phase: DistroPackPhase.refreshing));

    final actions = ref.read(packActionsProvider);

    // ── THE INDEX FIRST, BECAUSE EVERYTHING BELOW READS IT ───────────────
    //
    // `refresh` stamps its own freshness clock and sends an ETag, so the
    // overwhelmingly common answer is a 304 with no body. The `_refreshed`
    // guard is about not making three round trips for three swipes, not about
    // the cost of one.
    if (force || !_refreshed) {
      _refreshed = true;
      try {
        await actions.refresh();
      } catch (_) {
        // Offline. Everything below falls through to "not in the catalogue",
        // which is the same answer this app gave before any of this existed.
      }
    }

    // ── WHAT THIS DISTRO ASKS FOR ────────────────────────────────────────
    //
    // Read off the SPEC rather than off `EffectiveTheme`, and the difference
    // matters at exactly one call site. `resolve` folds `prefs.iconPackId` and
    // `prefs.iconBrandPackId` over the theme's own answers, so a resolved theme
    // names whatever the user last chose on the icons screen. That is the right
    // thing to RENDER and the wrong thing to fetch here: this is "make the
    // distro whole", not "re-download a choice the user already made and which
    // was installed at the moment they made it".
    //
    // The `??` tail repeats `resolve`'s own fallback rather than sharing it,
    // for the reason that file gives at length: both call `defaultLinePackFor`,
    // so there is one rule and two readers.
    final spec = await _specFor(themeId);
    final wanted = <String>[
      if (scope != DistroPackScope.iconsOnly) themeId,
      if (scope != DistroPackScope.themeOnly) ...[
        if (spec?.icons.heroPack case final hero? when hero.isNotEmpty) hero,
        spec?.icons.brandPack ?? defaultLinePackFor(themeId),
      ],
    ];

    List<PackInfo> packs;
    try {
      packs = await ref.read(catalogueProvider.future);
    } catch (_) {
      publish(DistroPackState(
        themeId: themeId,
        phase: DistroPackPhase.done,
        themeReady: true,
      ));
      return;
    }

    final byId = {for (final p in packs) p.packId: p};

    // ── WHAT IS ACTUALLY MISSING ─────────────────────────────────────────
    //
    // A pack absent from the catalogue is skipped, not failed: a theme naming
    // an id the CDN does not carry is a stale reference, and the generator
    // covers it exactly as it does today. `bundled` and `installed` are already
    // on the device. A paid pack the user does not own is left for the
    // storefront, where a purchase is a decision rather than a surprise.
    final todo = <PackInfo>[];
    for (final id in wanted) {
      final p = byId[id];
      if (p == null) continue;
      if (p.state == 'installed' || p.state == 'bundled') continue;
      if (p.sku != null && !p.unlocked) continue;
      todo.add(p);
    }

    if (todo.isEmpty) {
      publish(DistroPackState(
        themeId: themeId,
        phase: DistroPackPhase.done,
        themeReady: true,
      ));
      return;
    }

    // ── THE PUSH IS AWAITED, NOT RACED ───────────────────────────────────
    //
    // See the file doc. `activeThemePushProvider` fires this through
    // `unawaited` on every theme change, which is correct for keeping native
    // current and useless as a precondition: native re-checks
    // `isAvailable(packId, ownedSkus, activeThemeId)` immediately before the
    // transfer, so an install that overtakes the push is refused as
    // `notEntitled` for a pack that comes free with the distro being worn.
    //
    // Pushed for THIS distro rather than for the resolved one, because on the
    // setup deck the selection has moved and the resolve may not have caught up
    // yet. They converge within a frame; this cannot wait for that.
    try {
      await actions.pushActiveTheme(themeId);
    } catch (_) {
      // Native unreachable. The installs below will fail for the same reason
      // and land on the same silent floor.
    }

    publish(DistroPackState(
      themeId: themeId,
      phase: DistroPackPhase.installing,
      total: todo.length,
      label: todo.first.title.isEmpty ? todo.first.packId : todo.first.title,
    ));

    var done = 0;
    for (final p in todo) {
      publish(DistroPackState(
        themeId: themeId,
        phase: DistroPackPhase.installing,
        themeReady: done > 0 || p.packId != themeId,
        label: p.title.isEmpty ? p.packId : p.title,
        done: done,
        total: todo.length,
      ));

      try {
        // SEQUENTIAL, deliberately. Each install verifies signatures and writes
        // to disk, and two at once on a 3GB phone is how a download that would
        // have worked runs out of memory instead. Same rule as the purchase
        // path in `entitlements.dart` and the sweep in `pack_auto_update.dart`.
        await actions.install(p.packId);
      } catch (_) {
        // Swallowed per the doc above. The pack keeps the version it had.
      }

      done++;
      // The theme pack is always first in `wanted`, so anything after it having
      // started means the gate can open.
      publish(DistroPackState(
        themeId: themeId,
        phase: DistroPackPhase.installing,
        themeReady: p.packId == themeId || done > 0,
        label: p.title.isEmpty ? p.packId : p.title,
        done: done,
        total: todo.length,
      ));
    }

    publish(DistroPackState(
      themeId: themeId,
      phase: DistroPackPhase.done,
      themeReady: true,
      done: done,
      total: todo.length,
    ));
  }

  /// The spec for [themeId], if it is the one currently resolved.
  ///
  /// ─── WHY THIS IS ALLOWED TO ANSWER NULL ─────────────────────────────────
  ///
  /// Both callers select the distro before calling, so `activeThemeSpecProvider`
  /// is either already on it or one microtask away. But `select` is optimistic
  /// and the resolve is a platform call, so a fast second swipe can land here
  /// while the provider still holds the previous distro. Returning the wrong
  /// spec would fetch the wrong distro's icon pack, which is worse than
  /// fetching none: the derived `defaultLinePackFor(themeId)` below is right
  /// for every distro whose theme.json does not override it, which is all three
  /// bundled ones and most of the CDN ones.
  Future<ThemeSpec?> _specFor(String themeId) async {
    try {
      final spec = await ref.read(activeThemeSpecProvider.future);
      return spec.id == themeId ? spec : null;
    } catch (_) {
      return null;
    }
  }
}

final distroPacksProvider =
    NotifierProvider<DistroPacks, DistroPackState>(DistroPacks.new);

/// Which of a distro's packs a sweep is allowed to fetch.
///
/// ─── THE SPLIT IS ABOUT BYTES, NOT ABOUT TIDINESS ───────────────────────────
///
/// A distro theme pack is around 140KB and there is nothing to ask about: it is
/// what the desktop is drawn from, the user has just chosen it, and the
/// alternative is rendering the APK's older copy.
///
/// An icon pack is 491 bytes that `requires` 10.58 MB. Same call, three orders
/// of magnitude apart, and the difference is invisible from the catalogue entry
/// because `sizeBytes` describes the pointer rather than what it pulls in.
enum DistroPackScope {
  /// Setup's opening sweep, and anything else that runs without being asked.
  themeOnly,

  /// The icon step, once the user has said yes.
  iconsOnly,

  /// A deliberate distro switch in Settings. The user picked this distro, so
  /// its icons come with it, and after the first time `arcticons-line` is on
  /// disk and every other distro's pack really is 491 bytes.
  all,
}
