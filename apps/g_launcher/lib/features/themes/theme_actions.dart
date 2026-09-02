/// The one copy of "what a tap on a distro does".
///
/// ─── WHY THIS WAS EXTRACTED ─────────────────────────────────────────────────
///
/// It used to be a closure inside `ThemesScreen.build`, and the detail page
/// reached it by taking a `void Function(ThemeCard)` parameter and calling
/// `Navigator.pop()` FIRST so the flow's messages would land somewhere visible.
///
/// That pop is the bug in the review. Someone reads the page, decides to buy,
/// taps, and is thrown back to the list before Play's sheet arrives. The
/// purchase then completes over a screen they did not choose, and if Play is
/// slow the two events look unrelated: the page vanished, and some time later a
/// sheet appeared.
///
/// The flow could not simply stay on the page, because it closed over the
/// storefront's `BuildContext`. So it lives here instead and takes a context,
/// and each screen passes its own. Nothing pops, messages land wherever the
/// user actually is, and the detail page's Buy button turns into Apply under
/// their thumb because it already watches the catalogue.
///
/// ─── IT IS STILL ONE COPY ───────────────────────────────────────────────────
///
/// That was the reason for passing the callback down, and it was a good one:
/// this flow records a purchase intent before Play opens, branches on six
/// install statuses and reports each differently, and a second copy on the
/// detail page would be a second thing to keep correct. A shared function keeps
/// that property and drops the navigation side effect that came with it.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/billing/entitlements.dart';
import '../../data/billing/pending_apply.dart';
import '../../data/cdn/distro_packs.dart';
import '../../data/cdn/pack_repository.dart';
import '../../data/prefs/prefs_repository.dart';
import '../../design/branded_message.dart';
import '../../engine/effective_theme.dart';
import 'theme_catalog.dart';

/// Is this the distro currently being worn.
///
/// ─── READ WITH .value, NEVER asData ─────────────────────────────────────────
///
/// `asData` is null for `AsyncLoading`, INCLUDING the loading state Riverpod
/// produces on a refresh, which carries the previous value along with it. So
/// every catalogue invalidate, and there is one per pack install, made this
/// answer false for every card, and the active ring blinked off and back on.
///
/// `AsyncValue.value` is nullable in Riverpod 3 and hands back that retained
/// value, so the ring simply stays put. It is NOT `valueOrNull`: that was the
/// 2.x spelling and does not exist here.
bool themeCardIsActive(WidgetRef ref, ThemeCard card) => _active(
      card,
      ref.watch(effectiveThemeProvider).value?.spec.id,
      ref.watch(themeCatalogProvider).value ?? const <ThemeCard>[],
    );

/// The same question, asked from a TAP HANDLER rather than from `build`.
///
/// ─── read, NOT watch, AND THE DIFFERENCE IS AN ASSERTION ────────────────────
///
/// `WidgetRef.watch` outside a build method asserts in debug and is undefined
/// in release: a subscription created from a callback has no element to
/// rebuild. [runThemeCardAction] runs from an `onTap`, so it needs the value,
/// not a dependency on it. Two entry points, one rule below, so the storefront
/// ring and the action can never disagree about which distro is worn.
bool _themeCardIsActiveNow(WidgetRef ref, ThemeCard card) => _active(
      card,
      ref.read(effectiveThemeProvider).value?.spec.id,
      ref.read(themeCatalogProvider).value ?? const <ThemeCard>[],
    );

bool _active(ThemeCard card, String? activeId, List<ThemeCard> cards) {
  // If nothing string-matches the resolved spec, the bundled card is the active
  // one, so the ring never simply fails to appear over an id typo.
  final anyMatch = cards.any((c) => c.specId == activeId);
  return (card.specId != null && card.specId == activeId) ||
      (!anyMatch && card.bundled);
}

/// Apply a distro that is already on the device.
///
/// ─── AND FETCH THE ICONS IT COMES WITH ──────────────────────────────────────
///
/// This used to be the two lines above [_ensurePacks] and nothing else, which
/// is the whole of the "applying a distro does not always bring its icons"
/// report. `EffectiveTheme.resolve` derives `kde-plasma-6-line` through
/// `defaultLinePackFor` the instant the selection flips, native's
/// `BrandIconResolver` looks for it on disk, finds nothing, and the generator
/// draws. Nothing in this path had ever downloaded it.
///
/// The only thing that ever did was `SetupScreen._installDistroIcons`, once, at
/// the end of setup, for one distro. So the icons were right for whichever
/// distro you finished setup on and for anything you had since tapped on the
/// icons screen, and wrong for every other switch. Intermittent by
/// construction, which is exactly how it was described.
///
/// UNAWAITED, and the message does not wait for it. A brand line pack is under
/// a kilobyte (it inherits its geometry from the bundled `simple-icons`), so
/// this is normally over before the drawer has finished repainting, but a
/// distro that is applied and visible must not sit behind a network call on a
/// bad connection. The icons appear when they land: `onPackInstalled` bumps
/// `iconPackGenerationProvider`, which re-keys every icon in the app.
Future<void> _apply(
  BuildContext context,
  WidgetRef ref,
  ThemeCard card,
) async {
  await ref.read(selectedThemeIdProvider.notifier).select(card.specId!);
  _ensurePacks(ref, card.specId!);
  if (context.mounted) context.showMessage('${card.name} applied');
}

/// Fire the pack sweep for [themeId] without waiting on it.
///
/// `read`, not `watch`: this runs from a tap handler, where `watch` asserts in
/// debug and is undefined in release. The notifier supersedes its own in-flight
/// pass, so tapping through three distros leaves one sweep running for the last
/// one rather than three fighting over the same disk.
void _ensurePacks(WidgetRef ref, String themeId) {
  unawaited(ref.read(distroPacksProvider.notifier).ensure(themeId));
}

/// Download, then report per STATUS, never per detail string.
///
/// Each branch says something different because each needs a different action
/// from the user. Folding them into one "Download failed" is the message that
/// tells nobody anything, and it is the reason `PackResult` carries a status.
Future<void> _download(
  BuildContext context,
  WidgetRef ref,
  ThemeCard card, {
  required bool thenApply,
}) async {
  final result = await ref.read(packActionsProvider).install(card.packIdOrSpec);
  if (!context.mounted) return;

  switch (result.status) {
    case 'installed':
      if (thenApply && card.specId != null) {
        await _apply(context, ref, card);
      } else {
        context.showMessage('${card.name} updated');
      }
    case 'upToDate':
      // The common case on a re-tap. Deliberately silent: telling someone
      // nothing happened is noise.
      break;
    case 'notEntitled':
      context.showMessage('${card.name} needs to be purchased first');
    case 'appTooOld':
      context.showMessage('${card.name} needs a newer version of G Launcher');
    case 'noSpace':
      context.showMessage('Not enough free space for ${card.name}');
    case 'cancelled':
      break;
    case 'rejected':
      // A signature or hash check failed. NOT retryable, and worth saying
      // plainly rather than dressing up as a network blip: retrying a bad
      // signature produces the same answer and burns someone's data.
      context.showMessage('${card.name} failed verification and was discarded');
    default:
      context.showMessage('Could not download ${card.name}, try again');
  }
}

/// The primary action for a card, run in the caller's own context.
///
/// [ref] must belong to a widget that is still mounted for the duration, which
/// both call sites satisfy: the storefront stays put, and the detail page no
/// longer pops itself before calling this.
Future<void> runThemeCardAction(
  BuildContext context,
  WidgetRef ref,
  ThemeCard card,
) async {
  if (_themeCardIsActiveNow(ref, card)) {
    // The one useful thing a tap on the ACTIVE card can still do: pull the
    // newer copy the catalogue is advertising. `thenApply` is false because it
    // is already applied; the engine resolves installed over bundled, so the
    // repaint happens the moment the install lands.
    if (card.status == CardStatus.updateAvailable ||
        card.status == CardStatus.available) {
      await _download(context, ref, card, thenApply: false);
      return;
    }
    context.showMessage('${card.name} is your current distro');
    return;
  }

  switch (card.status) {
    // On the device already: apply it. Bundled themes live in the APK, so the
    // selection flips, activeThemeSpecProvider re-resolves, and the desktop
    // repaints with no network involved.
    case CardStatus.bundled:
    case CardStatus.installed:
      if (card.specId != null) await _apply(context, ref, card);

    // On the device but stale. Apply FIRST, update after: the user asked to see
    // this theme, and making them wait on a download to see something they
    // already have is the wrong trade.
    case CardStatus.updateAvailable:
      if (card.specId != null) await _apply(context, ref, card);
      if (!context.mounted) return;
      await _download(context, ref, card, thenApply: false);

    case CardStatus.available:
      await _download(context, ref, card, thenApply: true);

    case CardStatus.locked:
      // ── RECORD THE INTENT BEFORE OPENING PLAY ──────────────────────────
      //
      // A tap on a locked card is "I want to wear this", not "I would like to
      // own this". The download happens either way once the entitlement lands;
      // this is what tells the app to APPLY the distro too, and only for a
      // purchase that started with a deliberate tap.
      //
      // Set BEFORE `buy()` rather than after, because a purchase can complete
      // before that await returns on a fast payment method, and an intent
      // recorded afterwards would arrive too late to be read.
      //
      // ON DISK, not in memory: the install runs in a worker that outlives this
      // process, so an intent that does not is an intent that is missing
      // exactly when the download took the scenic route.
      final store = ref.read(prefsStoreProvider);
      await PendingApply.set(store, card.sku!);

      final started = await ref.read(buyProvider)(card.sku!);
      if (!started) {
        // OUTSIDE the mounted check, deliberately. Play never opened, so
        // nothing will ever consume the intent, and one left on disk would
        // apply this distro at the next launch inside the window.
        await PendingApply.clear(store);
      }
      if (!started && context.mounted) {
        // Either Play is unreachable or the product does not exist in the
        // console. Both render as a card with no price, so say something honest
        // rather than nothing.
        context.showMessage('${card.name} is not available to buy right now');
      }

    case CardStatus.requiresAppUpdate:
      context.showMessage('${card.name} needs a newer version of G Launcher');
  }
}
