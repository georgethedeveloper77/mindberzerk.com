/// Keeps Crashlytics' custom keys current, from one place.
///
/// ─── WHY THIS FILE EXISTS: setContext HAD NEVER RUN ─────────────────────────
///
/// `Crash.setContext` and `Crash.setKey` were written, correct, documented, and
/// called from nowhere. A grep across `lib/` returned only their definitions.
/// That is the fourth instance of this exact shape in this codebase, after
/// `IconPackPage`, `ThemeSource` and the twin of `app_icon.dart` that held the
/// `IconRequest.cacheId` fix and that nothing imported.
///
/// The consequence is specific rather than general. There are fourteen live
/// distros, themes are DATA, and the same stack inside the icon pipeline means
/// something different under Kali's stroked brand pack than under Ubuntu's
/// generated icons. Without these keys a report is a count, and a count cannot
/// be acted on.
///
/// ─── WHY ONE PROVIDER AND NOT setKey AT THE CALL SITES ──────────────────────
///
/// `crash.dart` already argues this about event names: a key spelled `shell` in
/// one place and `shellId` in another splits one field into two columns and
/// neither is complete. Scattering `setKey` across the theme resolve, the pack
/// installer, the drawer and the shells would be fourteen places to spell it,
/// and thirteen places for the next distro to be forgotten.
///
/// So the vocabulary lives in `Crash.setContext` and the WATCHING lives here,
/// mounted once beside `packBridgeProvider` for exactly the reason that one is
/// mounted at the root: a provider nothing watches is a provider that never
/// runs, which is the failure this file was written to fix.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/app_repository.dart';
import '../engine/effective_theme.dart';
import 'crash.dart';

/// Watch once, from `_Root`. Returns nothing; it exists for its side effect.
final crashContextProvider = Provider<void>((ref) {
  _watchTheme(ref);
  _watchAppCount(ref);
});

// ---- the theme ------------------------------------------------------------

/// What the launcher is currently wearing.
///
/// ─── THE SELECTOR IS THE WHOLE COST CONTROL ─────────────────────────────────
///
/// `effectiveThemeProvider` re-emits on EVERY prefs write: hiding an app,
/// nudging a drawer column, moving the dock, toggling verbose boot. Watching it
/// whole would mean five `setCustomKey` calls, each a platform channel round
/// trip, every time the user touches a setting.
///
/// A record has structural equality, so selecting down to one rebuilds this
/// only when a field we actually report has changed. Same technique
/// `app_icon.dart` uses for `iconCacheId`, and for the same reason.
///
/// `hasValue`, NOT `asData`, and that distinction is a bug fix rather than a
/// preference. `asData` is null while a FutureProvider is REFRESHING, not only
/// while it is loading for the first time, and this one awaits a platform call
/// on every prefs write. With `asData` every setting change would blank these
/// keys for the length of a round trip, and a crash landing inside that window
/// would report `theme_id: unknown` on a device whose theme is perfectly well
/// known. `hasValue` stays true through a refresh because Riverpod carries the
/// previous value into the loading state.
void _watchTheme(Ref ref) {
  final ctx = ref.watch(
    effectiveThemeProvider.select((async) {
      if (!async.hasValue) return null;
      final t = async.requireValue;
      return (
        themeId: t.spec.id,
        shell: t.shell.name,
        chrome: t.chromeFamily.name,
        // '-' rather than null so the key is always PRESENT. An absent key and
        // a key reading "no third-party pack" are different facts, and a
        // dashboard filter cannot tell them apart if one of them is a gap.
        iconPack: t.prefs.systemIconPack ?? '-',
        dark: t.dark,
      );
    }),
  );

  if (ctx == null) return;

  Crash.setContext(
    themeId: ctx.themeId,
    shell: ctx.shell,
    chromeFamily: ctx.chrome,
    iconPackId: ctx.iconPack,
    dark: ctx.dark,
  );

  // A BREADCRUMB AS WELL AS A KEY, and they answer different questions. The key
  // says what the launcher was wearing when it died. This says what it was
  // wearing five minutes earlier, which is what makes a freeze that only
  // happens on the FIRST paint after a switch legible at all. A theme switch is
  // rare enough that this cannot crowd the rolling 64KB log.
  Crash.log('theme: ${ctx.themeId} shell=${ctx.shell} chrome=${ctx.chrome}');
}

// ---- how many apps --------------------------------------------------------

/// `crash.dart` names this one specifically: the same stack inside the icon
/// cache means something different with 261 apps than with 40.
///
/// Selected down to the LENGTH, so a package change that swaps the list for an
/// equal-length one costs nothing, and `hasValue` for the same refresh reason
/// as above. `appListProvider` re-emits wholesale on every install, uninstall,
/// update and suspend.
void _watchAppCount(Ref ref) {
  final count = ref.watch(
    appListProvider
        .select((async) => async.hasValue ? async.requireValue.length : null),
  );
  if (count == null) return;
  Crash.setContext(appCount: count);
}

// ---- WHY THERE IS NO pack_version KEY -------------------------------------
//
// There was one, and it read the active distro's `installedVersion` out of
// `catalogueProvider`. It was the most useful key on this list, because a distro
// can be republished over the CDN without an app update and two devices on the
// same `theme_id` can be running different artwork entirely.
//
// IT IS GONE, AND IT MUST NOT COME BACK THIS WAY.
//
// `crashContextProvider` is a synchronous Provider. `icon_theme_screen.dart`
// documents, at the top of `_Screen.build`, what happens when a synchronous
// Provider watches the async `catalogueProvider`: it is mounted mid-build the
// first time something asks, the catalogue emits during that same flush, and
// the resulting `invalidateSelf` lands inside the build phase, which Riverpod
// forbids. That screen hit it and moved the filter inline to escape it.
//
// Mounting the same shape in `_Root` is strictly worse than the original bug.
// `_Root` outlives every screen, so `catalogueProvider` stops auto-disposing and
// gets pinned to whatever it resolved at process start, BEFORE
// `catalogueRefreshProvider` has run. Every consumer downstream then reads a
// stale index: wrong `state`, wrong `unlocked`, missing previews, and cards
// offering to Get a pack the device already has.
//
// A diagnostic must not be able to change the behaviour of the thing it is
// diagnosing. If this key is worth having, it has to come from somewhere that is
// already resolved for another reason, not from waking the storefront's
// catalogue at boot.
