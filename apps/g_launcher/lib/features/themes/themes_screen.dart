import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../data/prefs/prefs_repository.dart';
import '../../design/branded_message.dart';
import '../../design/components/components.dart';
import '../../design/tokens/typography.dart';
import '../../engine/effective_theme.dart';
import '../../data/billing/entitlements.dart';
import '../../data/billing/pending_apply.dart';
import '../../data/cdn/pack_auto_update.dart';
import '../../data/cdn/pack_repository.dart';
import 'theme_catalog.dart';
import 'theme_detail_screen.dart';

/// The theme storefront. A header, a 2-col grid of mini-desktop preview cards,
/// and a "more" list of themes that arrive over the CDN.
///
/// This screen's chrome is now the ACTIVE theme's (Phase B, B2): the frame,
/// cards, tags and buttons read the derived chrome via [ChromeScope], so the
/// gallery is dressed in whatever distro is applied — the same rule as Settings.
/// This reverses the earlier "neutral house chrome" decision. The mini-desktop
/// PREVIEWS are the deliberate exception: each paints a specific distro from
/// [ThemePreviewSpec] catalog data (colours and its mono labels), independent of
/// the active theme, because a preview must depict the distro it advertises, not
/// the one you're currently running.
///
/// **PHASE C: the CDN registry landed, so this is now live.** Tapping a card
/// does whatever its [CardStatus] says: apply, download, update, buy, or tell
/// the user to update the app. Nothing is faked any more.
///
/// The one rule that survived from the honest-placeholder era and still
/// matters: **an action that cannot succeed must not present as a button.** A
/// `requiresAppUpdate` card showing Get would leave someone tapping at a
/// download that never arrives and concluding the app is broken, which is
/// exactly the failure the old "coming soon" message existed to avoid. So it
/// draws its own label instead.
///
/// The catalogue is read from the CACHED index, so this screen opens instantly
/// and works offline; a refresh runs in the background on open and re-reads
/// only if something actually changed.
/// Which slice of the catalogue the storefront is showing.
///
/// ─── WHY THERE IS NO "POPULAR" ──────────────────────────────────────────────
///
/// It was asked for and it cannot be built honestly yet. Nothing counts distro
/// installs: that is Phase 6 and it is blocked on the launcher emitting
/// `app_present` and on BigQuery export. A tab labelled Popular would be
/// ordered by nothing, and on a STORE screen that is not a harmless placeholder
/// but an implicit claim that other people bought these.
///
/// [paid] is the honest tab that works today, derived from `sku != null` with
/// no new data, and it is the same axis the admin panel already filters on.
///
/// The other honest version is Featured, an authored flag set per distro in the
/// panel. It is editorial rather than measured, which is fine and true, but it
/// needs the signed index to carry the flag, so it would list only bundled
/// distros until that lands. Swapping this arm for it is one filter and one
/// label.
enum ThemeTab {
  all,
  installed,
  paid;

  String get label => switch (this) {
        ThemeTab.all => 'All',
        ThemeTab.installed => 'Installed',
        ThemeTab.paid => 'Paid',
      };

  bool matches(ThemeCard c) => switch (this) {
        ThemeTab.all => true,
        ThemeTab.installed => c.status.onDevice,
        ThemeTab.paid => c.sku != null,
      };
}

/// AUTO-DISPOSES, so closing the storefront resets it to All.
///
/// Deliberate: a tab is a filter you applied a moment ago, not a preference.
/// Coming back days later to a Paid-only list, having forgotten you narrowed
/// it, reads as distros having disappeared.
final themeTabProvider = StateProvider.autoDispose<ThemeTab>(
  (ref) => ThemeTab.all,
);

class ThemesScreen extends ConsumerWidget {
  const ThemesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeSpec = ref.watch(effectiveThemeProvider).asData?.value.spec;
    final cards = ref.watch(themeCatalogProvider).asData?.value ?? const <ThemeCard>[];
    final more = ref.watch(themeMoreProvider);
    final progress = ref.watch(packProgressProvider);

    // THE FETCH. `catalogueProvider` is the cached index and never hits the
    // network; this is the one thing that asks the CDN whether anything is new.
    // Watched rather than read so the grid rebuilds when the answer lands, and
    // fired once per app run — see `catalogueRefreshProvider`.
    ref.watch(catalogueRefreshProvider);
    // Watched here so a price arriving from Play repaints the whole grid at
    // once, rather than each card independently re-reading a provider family.
    ref.watch(ownedSkusProvider);

    final tab = ref.watch(themeTabProvider);

    // Filtered for display only. `cards` stays whole for the counts on the
    // tabs, which have to say how many are in each slice rather than how many
    // are in the slice you are already looking at.
    final shown = [
      for (final c in cards)
        if (tab.matches(c)) c,
    ];

    final activeId = activeSpec?.id;
    // If nothing string-matches the loaded spec, the bundled card (Ubuntu) is
    // the active one — the ring never simply fails to appear over an id typo.
    final anyMatch = cards.any((c) => c.specId == activeId);
    bool isActive(ThemeCard c) =>
        (c.specId != null && c.specId == activeId) || (!anyMatch && c.bundled);

    Future<void> apply(ThemeCard c) async {
      await ref.read(selectedThemeIdProvider.notifier).select(c.specId!);
      if (context.mounted) context.showMessage('${c.name} applied');
    }

    /// Download, then report per STATUS, never per detail string.
    ///
    /// Each branch says something different because each needs a different
    /// action from the user. Folding them into one "Download failed" is the
    /// message that tells nobody anything, and it is the reason `PackResult`
    /// carries a status at all.
    Future<void> download(ThemeCard c, {required bool thenApply}) async {
      final result = await ref.read(packActionsProvider).install(c.packIdOrSpec);
      if (!context.mounted) return;

      switch (result.status) {
        case 'installed':
          if (thenApply && c.specId != null) {
            await apply(c);
          } else {
            context.showMessage('${c.name} updated');
          }
        case 'upToDate':
          // The common case on a re-tap. Deliberately silent: telling someone
          // nothing happened is noise.
          break;
        case 'notEntitled':
          context.showMessage('${c.name} needs to be purchased first');
        case 'appTooOld':
          context.showMessage('${c.name} needs a newer version of G Launcher');
        case 'noSpace':
          context.showMessage('Not enough free space for ${c.name}');
        case 'cancelled':
          break;
        case 'rejected':
          // A signature or hash check failed. NOT retryable, and worth saying
          // plainly rather than dressing up as a network blip — retrying a bad
          // signature produces the same answer and burns someone's data.
          context.showMessage('${c.name} failed verification and was discarded');
        default:
          context.showMessage('Could not download ${c.name}, try again');
      }
    }

    Future<void> tapCard(ThemeCard c) async {
      if (isActive(c)) {
        // The one useful thing a tap on the ACTIVE card can still do: pull the
        // newer copy the catalogue is advertising. The early return used to
        // swallow exactly this case, so the distro someone actually runs was
        // the only one they could not update from this screen. `thenApply` is
        // false because it is already applied; the engine resolves installed
        // over bundled, so the repaint happens the moment the install lands.
        if (c.status == CardStatus.updateAvailable ||
            c.status == CardStatus.available) {
          await download(c, thenApply: false);
          return;
        }
        context.showMessage('${c.name} is your current distro');
        return;
      }

      switch (c.status) {
        // On the device already: apply it. Bundled themes live in the APK, so
        // the selection flips, activeThemeSpecProvider re-resolves, and the
        // desktop repaints with no network involved.
        case CardStatus.bundled:
        case CardStatus.installed:
          if (c.specId != null) await apply(c);

        // On the device but stale. Apply FIRST, update after: the user asked to
        // see this theme, and making them wait on a download to see something
        // they already have is the wrong trade.
        case CardStatus.updateAvailable:
          if (c.specId != null) await apply(c);
          await download(c, thenApply: false);

        case CardStatus.available:
          await download(c, thenApply: true);

        case CardStatus.locked:
          // Play's own sheet. The download is NOT started here: the purchase
          // stream fires asynchronously, possibly minutes later for the cash
          // and carrier-billing methods this market actually uses, and
          // packBridgeProvider is listening for exactly that. Kicking off a
          // download on the return of buy() would race the entitlement push and
          // usually lose.
          // ── RECORD THE INTENT BEFORE OPENING PLAY ──────────────────
          //
          // A tap on a locked card is "I want to wear this", not "I would like
          // to own this". The download happens either way once the entitlement
          // lands; this is what tells the app to APPLY the distro too, and only
          // for a purchase that started with a deliberate tap.
          //
          // Set BEFORE `buy()` rather than after, because a purchase can
          // complete before that await returns on a fast payment method, and an
          // intent recorded afterwards would arrive too late to be read.
          //
          // ON DISK, not in memory: the install now runs in a worker that
          // outlives this process, so an intent that does not is an intent that
          // is missing exactly when the download took the scenic route. See
          // [PendingApply] for the expiry that keeps that honest.
          final store = ref.read(prefsStoreProvider);
          await PendingApply.set(store, c.sku!);

          final started = await ref.read(buyProvider)(c.sku!);
          if (!started) {
            // OUTSIDE the mounted check, deliberately. Play never opened, so
            // nothing will ever consume the intent, and one left on disk would
            // apply this distro at the next launch inside the window. Tying
            // that cleanup to whether this screen is still mounted would leave
            // it armed in exactly the case where the user navigated away.
            await PendingApply.clear(store);
          }
          if (!started && context.mounted) {
            // Either Play is unreachable (de-Googled ROM, no Play Services) or
            // the product does not exist in the console. Both render as a card
            // with no price, so say something honest rather than nothing.
            context.showMessage('${c.name} is not available to buy right now');
          }

        case CardStatus.requiresAppUpdate:
          context.showMessage(
            '${c.name} needs a newer version of G Launcher',
          );
      }
    }

    /// What a tap on the card BODY does.
    ///
    /// ─── ROUTED BY STATUS, NOT UNIFORMLY ──────────────────────────────────
    ///
    /// Anything already on the device applies on one tap, as it always has.
    /// Switching distros is the frequent action on this screen, and the detail
    /// page has nothing to tell an owner that Settings cannot, so growing it a
    /// tap would be the wrong trade for the common case.
    ///
    /// `locked` and `available` open the page instead. Those are the two states
    /// where a tap COMMITS: one opens Play's payment sheet, the other starts a
    /// download measured in megabytes, and until now both did it with no screen
    /// in between saying what the distro is or what is in it.
    ///
    /// `requiresAppUpdate` deliberately stays on the storefront. Its message is
    /// one line and there is no action behind it, so a page whose only button
    /// is disabled would be a longer way to say the same thing.
    ///
    /// DECLARED AFTER `tapCard` because it calls it. A local function cannot be
    /// referenced above its own declaration in the same block.
    ///
    /// A consequence worth knowing while testing: on a device where every
    /// distro is already installed, nothing routes to the detail page at all.
    void onCardTap(ThemeCard c) {
      final opensDetail = !isActive(c) &&
          (c.status == CardStatus.locked ||
              c.status == CardStatus.available);

      if (!opensDetail) {
        // Deliberately not awaited: this is a tap handler, and `tapCard`
        // already reports everything it does.
        unawaited(tapCard(c));
        return;
      }

      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ThemeDetailScreen(
            // packIdOrSpec, never `id`: they differ on the bundled distros and
            // the pack pipeline knows only the second.
            packId: c.packIdOrSpec,
            // THE ACTION STAYS HERE. `tapCard` records a purchase intent before
            // Play opens, branches on six install statuses and reports each one
            // differently. A second copy of that on the detail page would be a
            // second thing to keep correct, and the one that drifts is always
            // the copy. The page pops itself before calling this, so the
            // messages land on a screen the user can see.
            onAction: tapCard,
          ),
        ),
      );
    }

    return ThemedScaffold(
      // Pull to refresh. The automatic fetch above runs once per app run, which
      // is right for the common case and useless in the one that matters: you
      // have just published something and want it NOW. `refresh()` sends an
      // ETag, so a pull that finds nothing new costs a 304 with no body.
      //
      // Colours passed explicitly because RefreshIndicator otherwise reads
      // `Theme.of`, which this screen deliberately does not have — see
      // no_constants.sh's settings scope.
      body: RefreshIndicator(
        color: ChromeScope.of(context).colors.accent,
        backgroundColor: ChromeScope.of(context).colors.line,
        // ─── A PULL UPDATES TOO ───────────────────────────────────────
        //
        // This called `refresh()` alone, which fetched the index and left any
        // pack that had just gone stale sitting there saying Update.
        //
        // I originally exempted a manual pull on the reasoning that it is
        // someone asking to SEE the catalogue rather than to download fifteen
        // packs. That is the wrong reading: a pull is a person saying "check
        // for changes", and finding one and then not acting on it is the
        // launcher deciding for them. Every route to a fetch now has the same
        // consequence, which is also one fewer rule to remember.
        onRefresh: () => refreshAndAutoUpdate(
              ref.read(packActionsProvider),
              ref.read(packAutoUpdaterProvider),
            ),
        child: ListView(
        padding: EdgeInsets.only(
          top: MediaQuery.viewPaddingOf(context).top,
          bottom: 28,
        ),
        children: [
          // ── Header ──────────────────────────────────────────────────────
          const _Header(),

          // ── Grid ────────────────────────────────────────────────────────
          _Tabs(cards: cards),

          // A filter can legitimately be empty: Paid before any paid distro is
          // published, for one. Says so rather than showing a blank page, which
          // is indistinguishable from a catalogue that failed to load.
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 28, 16, 28),
              child: Text(
                // Literal, like every other string on this screen. Three
                // `context.t` keys here would be the only localised text in the
                // file and would need keys that do not exist yet; the screen
                // localises as a unit or not at all.
                switch (tab) {
                  ThemeTab.installed => 'Nothing installed yet.',
                  ThemeTab.paid => 'No paid distros yet.',
                  ThemeTab.all => 'No distros to show.',
                },
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ChromeScope.of(context).colors.textMuted,
                  fontSize: 12.5,
                ),
              ),
            ),

          // ─── ONE COLUMN, AND SIZED BY ITS CONTENT ─────────────────────
          //
          // This was a two-up grid of 150dp cells, which gives a preview about
          // 100dp tall and 150 wide. At that size a mini desktop can show a
          // colour and very little else, so every CDN distro read as a coloured
          // rectangle with a price beside it, and the distro being charged for
          // was the emptiest thing on the screen.
          //
          // A full-width card gives the preview 152dp of height and the whole
          // width, which is enough to draw a panel, a dock, windows and icons:
          // the distro's signature rather than its palette. It also leaves room
          // under the meta row for what the card is actually for, which is
          // saying what this distro DOES.
          //
          // ─── AND WHY IT IS NOT A GridView ANY MORE ────────────────────────
          //
          // It was, with a fixed `mainAxisExtent`, on the reasoning that cards
          // of differing heights make a list that jumps about as the catalogue
          // loads. That reasoning was wrong the moment feature rows existed:
          // the three bundled distros carry two rows and a CDN pack carries
          // none, so the cards ALWAYS differ. Fixing the height did not make
          // them uniform, it just forced variable text into a constant box, and
          // it overflowed by 3dp at the default font size. At a system text
          // scale of 1.3 it would have overflowed by thirty.
          //
          // A Column of self-sizing cards has no such cliff. The preview stays
          // fixed at 152 so every card shows the same size picture; everything
          // below it takes the height its text actually needs.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                for (var i = 0; i < shown.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  _ThemeCard(
                    card: shown[i],
                    active: isActive(shown[i]),
                    // null when nothing is in flight for this pack, which is
                    // the normal case; the card only grows a bar while it is
                    // downloading.
                    progress: progress[shown[i].packIdOrSpec],
                    onTap: () => onCardTap(shown[i]),
                  ),
                ],
              ],
            ),
          ),

          // ── More ────────────────────────────────────────────────────────
          //
          // RENDERS NOTHING WHEN EMPTY, header included. `themeMoreProvider`
          // returns no entries now that the storefront shows only what is
          // actually available, and a lone "More themes" heading over blank
          // space reads as a list that failed to load. The grid above already
          // carries every theme the signed index advertises, so an empty
          // section here is the correct and complete state, not a gap.
          if (more.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _MoreHeader(),
                  for (final m in more)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: _MoreRow(
                        entry: m,
                        onGet: () => context.showMessage(
                          m.pro
                              ? '${m.name} is a paid distro, coming soon'
                              : '${m.name} ships in an update, coming soon',
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card
// ─────────────────────────────────────────────────────────────────────────────

/// The filter strip.
///
/// Counts come from the WHOLE list, not the filtered one, because the number on
/// a tab has to say how many are in that slice rather than how many are in the
/// slice already on screen. A Paid tab reading 0 while showing nine paid
/// distros is the version of this that gets shipped by accident.
class _Tabs extends ConsumerWidget {
  const _Tabs({required this.cards});

  final List<ThemeCard> cards;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeTabProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Row(
        children: [
          for (final t in ThemeTab.values) ...[
            if (t != ThemeTab.values.first) const SizedBox(width: 8),
            _TabChip(
              label: t.label,
              // No count on All: it is the total, and a number there is the one
              // figure on the strip that tells you nothing you can act on.
              count: t == ThemeTab.all
                  ? null
                  : cards.where(t.matches).length,
              selected: t == current,
              onTap: () => ref.read(themeTabProvider.notifier).state = t,
            ),
          ],
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = ChromeScope.of(context).colors;

    return Material(
      color: selected ? c.accent : c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(color: selected ? c.accent : c.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                  color: selected ? c.onAccent : c.text,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 6),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: selected
                        ? c.onAccent.withValues(alpha: 0.75)
                        : c.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    this.progress,
    required this.card,
    required this.active,
    required this.onTap,
  });

  final ThemeCard card;
  final bool active;
  final VoidCallback onTap;

  /// 0.0-1.0 while downloading, null otherwise.
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    final c = d.colors;
    return Material(
      color: c.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: active ? c.accent : c.line,
          width: active ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          // MIN, now that nothing above fixes this card's height. Without it
          // the Column takes the unbounded height a Column parent offers and
          // the card stretches to whatever the page can give it.
          mainAxisSize: MainAxisSize.min,
          children: [
            // FIXED, not Expanded. The card's height is fixed by the grid, so
            // an Expanded preview would eat whatever the feature rows did not
            // use and a distro with no features would get a taller picture than
            // one with two. Same picture on every card, regardless of how much
            // it has to say.
            SizedBox(
              height: 152,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ThemePreview(card.preview),
                  // Over the preview, not under the title: the preview is the
                  // part of the card the eye is already on, and a bar tucked
                  // into the meta row competes with the tag for two-thirds of
                  // the width.
                  if (progress != null)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: LinearProgressIndicator(
                        // Indeterminate until the first real chunk arrives.
                        // Showing 0% for the DNS lookup and TLS handshake reads
                        // as stalled, which is when people tap again.
                        value: progress! <= 0 ? null : progress,
                        minHeight: 3,
                        backgroundColor: c.line,
                        valueColor: AlwaysStoppedAnimation(c.accent),
                      ),
                    ),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: c.line)),
              ),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          card.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: c.text,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        // ─── NOTHING, WHEN THERE IS NOTHING TO SAY ───────
                        //
                        // This used to print the pack version whenever the
                        // summary was empty, and the catalogue currently ships
                        // fourteen empty summaries, so every card in the store
                        // read `v1787590303`. A build number is a developer
                        // lever and the storefront is not the place for it.
                        //
                        // The gap is deliberate: a name alone is plain, a name
                        // over a timestamp is broken.
                        if (card.subtitle.isNotEmpty) ...[
                          const SizedBox(height: 1),
                          Text(
                            card.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            // Mono, from the chrome's value ramp, so the meta
                            // line reads like a package string on any distro.
                            style: d.text.value.copyWith(
                              fontSize: 11,
                              color: c.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _Trailing(card: card, active: active),
                ],
              ),
            ),

            // ─── WHAT THIS DISTRO DOES ──────────────────────────────────
            //
            // The first two EXCLUSIVE features, in authored order, so the order
            // written in the panel is the order they sell in. Skin entries are
            // filtered out here rather than being shown last: a card with two
            // rows has room to say something the settings cannot already do,
            // and "Noto Sans, squircle icons" is not that.
            //
            // Renders NOTHING when the list is empty, which is every CDN pack
            // until the signed index carries a features block. An empty gap is
            // honest; invented rows on a paid product are not.
            ..._featureRows(context),

            // ─── AND WHAT IS IN THE BOX ─────────────────────────────────
            //
            // The rows above are EDITORIAL: someone has to have something true
            // to write, and for four distros nobody does. Manjaro, Fedora,
            // Zorin and Deepin have no honest exclusive claim, two of them are
            // paid, and until now their cards were a name over a rectangle
            // with a price beside it.
            //
            // This strip is MECHANICAL and counted at publish, so it cannot be
            // blank on a pack that has contents and cannot flatter one that
            // does not. It sits BELOW the features on purpose: a reason to buy
            // outranks a bill of materials, and the card should read in that
            // order even on the distros that have both.
            //
            // Renders nothing at all until the index carries the fields, which
            // is every pack today. See [ThemeCard.contentsChips].
            ..._contentsStrip(context),
          ],
        ),
      ),
    );
  }

  /// The contents chips, or nothing.
  ///
  /// Reads the scope from context for the same reason [_featureRows] does: the
  /// type of `d.colors` is not named anywhere in this file, and inventing a
  /// signature for it here would be guessing at an API for one call site.
  List<Widget> _contentsStrip(BuildContext context) {
    final d = ChromeScope.of(context);
    final c = d.colors;

    final chips = card.contentsChips;
    if (chips.isEmpty) return const [];

    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 11),
        child: Wrap(
          spacing: 5,
          runSpacing: 5,
          children: [
            for (final chip in chips)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: c.line,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  chip,
                  // Mono, from the chrome's value ramp, the same face the
                  // subtitle uses. These are quantities and package names, and
                  // they should read as the meta line's continuation rather
                  // than as more prose competing with the feature rows.
                  style: d.text.value.copyWith(
                    fontSize: 10.5,
                    height: 1.1,
                    color: c.textMuted,
                  ),
                ),
              ),
          ],
        ),
      ),
    ];
  }

  /// Takes the context and re-reads the scope rather than accepting the colours
  /// as a parameter. `d.colors`' type is not named anywhere in this file, and
  /// naming it here to write a signature would be guessing at an API for the
  /// sake of one call site.
  List<Widget> _featureRows(BuildContext context) {
    final c = ChromeScope.of(context).colors;
    final shown = [
      for (final f in card.features)
        if (f.exclusive) f,
    ].take(2).toList();

    if (shown.isEmpty) return const [];

    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final f in shown)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // The accent dot carries the "exclusive" claim without a
                    // tag: every row here is exclusive by construction, so a
                    // label reading EX on all of them would say nothing.
                    Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.only(top: 5, right: 7),
                      decoration: BoxDecoration(
                        color: c.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${f.title}. ',
                              style: TextStyle(
                                color: c.text,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            TextSpan(
                              text: f.body,
                              style: TextStyle(color: c.textMuted),
                            ),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ];
  }
}

/// The right-hand meta element: the active check, a price, or the DE tag.
///
/// ─── THE PRO BADGE IS GONE, AND IT WAS WRONG TWICE ──────────────────────────
///
/// There is no Pro tier. Every launcher FEATURE is free — the boot-log editor,
/// scheduled switching, the cube transition, all of it — and what is sold is
/// whole distros and icon packs. A badge reading "Pro" was the last piece of UI
/// still describing a model that was dropped, and it was the only word on this
/// screen implying some capability was withheld.
///
/// It was also useless as an affordance. "Pro" tells you a thing costs money and
/// refuses to say how much, so the only way to find out was to tap, get Play's
/// sheet, and read the number there. A price is the same amount of pixels and
/// answers the question.
///
/// A ConsumerWidget now, because the price comes from Play through
/// `productPriceProvider` — a LOCALISED string Play formats for the user's
/// country and currency, never a number formatted here, which would be wrong in
/// every market this launcher actually targets.
class _Trailing extends ConsumerWidget {
  const _Trailing({required this.card, required this.active});

  final ThemeCard card;
  final bool active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ChromeScope.of(context).colors;

    // ORDER MATTERS, and this is the order:
    //   active > requiresAppUpdate > update > locked > available > tag
    //
    // requiresAppUpdate sits above everything except the active ring because it
    // is the one state where every other affordance would be a lie. A Pro badge
    // on a theme this build cannot run invites a purchase that installs
    // nothing, which is the worst outcome on this screen.
    if (!active && card.status == CardStatus.requiresAppUpdate) {
      return _MiniLabel('Update app', c.textMuted);
    }
    if (!active && card.status == CardStatus.updateAvailable) {
      return _MiniLabel('Update', c.accent);
    }
    if (!active && card.status == CardStatus.locked) {
      // The price when Play has answered, the word Buy when it has not.
      //
      // Null is the ordinary state in three real cases: the build is not on a
      // Play track yet, the device has no Play Services, or the product does not
      // exist in the console. All three render a card with no price, so a
      // fallback word is what stops the trailing slot going blank and reading as
      // a card that failed to load.
      return _MiniLabel(ref.watch(productPriceProvider(card.sku)) ?? 'Buy', c.accent);
    }
    if (!active && card.status == CardStatus.available) {
      return _MiniLabel('Get', c.accent);
    }

    // THE ACTIVE CARD SHOWS ITS UPDATE. Every branch above is `!active`
    // guarded, which meant the distro someone actually runs was the one card
    // that could never say a newer version exists - the user had to switch
    // distros just to see the chip. Tap already pulls it; now the eye is told.
    if (active &&
        (card.status == CardStatus.updateAvailable ||
            card.status == CardStatus.available)) {
      return _MiniLabel('Update', c.accent);
    }

    if (active) {
      return Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: c.accent,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(Icons.check, size: 11, color: c.onAccent),
      );
    }
    // ─── EVERYTHING LEFT IS ON THE DEVICE AND NOT WORN ────────────────────
    //
    // Bundled or installed, not active, nothing to buy and nothing to fetch.
    // The only thing a tap can do here is apply it, so the slot says so.
    //
    // ─── THIS SLOT USED TO DRAW THE DE TAG, AND MOSTLY DREW NOTHING ───────
    //
    // It read `card.tag`, which `_cardFromPack` sets to null on every CDN
    // entry, so eleven of fourteen installed cards rendered an empty corner:
    // no price, no action, no chip. A card with a picture, a name and a blank
    // third element reads as one that failed to load rather than one that is
    // simply ready.
    //
    // The three cards that DID have a tag lost nothing worth keeping. Ubuntu's
    // said GNOME directly above a subtitle reading `24.04 · GNOME`, which is
    // the same duplication `_cardFromPack` removed the tag for in the first
    // place. `ThemeCard.tag` is now read by nothing; it is left on the class
    // rather than deleted in a pass about something else.
    //
    // Word, not an icon, for the reason [_MiniLabel] gives: Apply, Get and
    // Update are three different promises and a single glyph would collapse
    // them into the ambiguity this whole state machine exists to remove.
    return _MiniLabel('Apply', c.accent);
  }
}

/// A short coloured word in the trailing slot: Get, Update, Update app.
///
/// Text rather than an icon because these three mean genuinely different things
/// and a download glyph would collapse them into one, which is the ambiguity
/// this whole state machine exists to remove.
class _MiniLabel extends StatelessWidget {
  const _MiniLabel(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          fontSize: 10,
          height: 1,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      );
}


// ─────────────────────────────────────────────────────────────────────────────
// The mini-desktop preview. Pure decoration driven by ThemePreviewSpec.
// ─────────────────────────────────────────────────────────────────────────────

/// Where a preview's bar sits, if it has one.
///
/// Three values because there are three truths: seven of fifteen distros were
/// drawn with a top bar they do not have, and four of those have one along the
/// bottom instead.
enum _Bar { top, bottom, none }

class ThemePreview extends StatelessWidget {
  const ThemePreview(this.spec, {super.key});

  final ThemePreviewSpec spec;

  static const _white55 = Color(0x8CFFFFFF);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: spec.radial
            ? RadialGradient(
                center: const Alignment(0.56, -0.76), // 78% 12%
                radius: 1.1,
                colors: spec.bg,
              )
            : LinearGradient(
                begin: Alignment.topRight, // ~160deg
                end: Alignment.bottomLeft,
                colors: spec.bg,
              ),
      ),
      child: Stack(
        children: [
          // ─── THE BAR IS NOT UNCONDITIONAL ANY MORE ────────────────────
          //
          // This said "every layout has one" and painted it at the top. Four
          // distros have their bar along the BOTTOM and three have none at
          // all, so for seven of fifteen the first thing the card drew was
          // wrong.
          if (_bar != _Bar.none)
            Positioned(
              left: 9,
              right: 9,
              top: _bar == _Bar.top ? 9 : null,
              bottom: _bar == _Bar.bottom ? 9 : null,
              child: Container(
                height: 7,
                decoration: BoxDecoration(
                  color: spec.bar,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ..._layout(),
        ],
      ),
    );
  }

  /// Where this layout puts its bar. See the Stack above.
  _Bar get _bar => switch (spec.layout) {
        PreviewLayout.barBottom => _Bar.bottom,
        // A phone has Android's status bar, not the launcher's, and a terminal
        // has none either. Drawing one would be the only untrue thing on those
        // two cards.
        PreviewLayout.terminal => _Bar.none,
        _ => _Bar.top,
      };

  List<Widget> _layout() {
    switch (spec.layout) {
      // ─── THE FIVE ADDED WHEN THE LAYOUT STOPPED BEING THE SHELL ───────
      //
      // Each is a variation on a shape this widget already drew, which is why
      // the fix was a derivation change rather than a new preview system.
      case PreviewLayout.dockFlat:
        return [
          Positioned(
            left: 9,
            right: 9,
            top: 26,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: _tiles(18),
            ),
          ),
          // ON the edge, square where it meets. `dockBottom` floats clear of
          // it; that gap is the whole difference between Plank and a Latte
          // dock and it is visible at this size.
          Positioned(
            left: 34,
            right: 34,
            bottom: 0,
            child: Container(
              height: 12,
              decoration: BoxDecoration(
                color: spec.dockBg ?? _white55,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ),
          ),
        ];

      case PreviewLayout.noDock:
        // Tiles and a bar, and nothing else. The absence IS the picture.
        return [
          Positioned(
            left: 9,
            right: 9,
            top: 30,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: _tiles(18),
            ),
          ),
        ];

      case PreviewLayout.barBottom:
        // The bar moved in the Stack above, so this only has to leave room at
        // the foot instead of at the head.
        return [
          Positioned(
            left: 9,
            right: 9,
            top: 14,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: _tiles(18),
            ),
          ),
        ];

      case PreviewLayout.dash:
        return [
          Positioned(
            left: 9,
            right: 9,
            top: 26,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: _tiles(18),
            ),
          ),
          // DASHED, because it is not there until you ask. A solid strip would
          // say the opposite of what this distro is selling.
          Positioned(
            left: 40,
            right: 40,
            bottom: 11,
            child: Container(
              height: 10,
              decoration: BoxDecoration(
                color: (spec.accent ?? _white55).withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: _white55, width: 0.8),
              ),
            ),
          ),
        ];

      case PreviewLayout.tiled:
        return [
          // Edge to edge with hairline gaps, which is what a tiling desktop
          // looks like from across a room and the one thing no other card here
          // shows.
          Positioned(
            left: 9,
            right: 9,
            top: 24,
            bottom: 11,
            child: GridView.count(
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
              children: [
                for (var i = 0; i < 4; i++)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: (spec.icons.isNotEmpty
                              ? spec.icons[i % spec.icons.length]
                              : _white55)
                          .withValues(alpha: 0.5),
                      border: Border.all(color: _white55, width: 0.7),
                    ),
                  ),
              ],
            ),
          ),
        ];

      case PreviewLayout.dockLeft:
        return [
          // Left dock strip with three dots; the first is the accent launcher.
          Positioned(
            left: 9,
            top: 26,
            bottom: 9,
            width: 13,
            child: Container(
              decoration: BoxDecoration(
                color: spec.dockBg,
                borderRadius: BorderRadius.circular(5),
              ),
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  _dot(spec.accent ?? _white55),
                  const SizedBox(height: 4),
                  _dot(_white55),
                  const SizedBox(height: 4),
                  _dot(_white55),
                ],
              ),
            ),
          ),
          Positioned(
            left: 29,
            top: 25,
            child: Row(mainAxisSize: MainAxisSize.min, children: _tiles(18)),
          ),
        ];

      case PreviewLayout.dockBottom:
        return [
          Positioned(
            left: 9,
            right: 9,
            bottom: 9,
            child: Container(
              decoration: BoxDecoration(
                color: spec.dockBg,
                borderRadius: BorderRadius.circular(5),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(children: _tiles(14)),
            ),
          ),
        ];

      case PreviewLayout.iconsCentered:
        return [
          Positioned(
            left: 9,
            right: 9,
            top: 27,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: _tiles(18),
            ),
          ),
        ];

      case PreviewLayout.iconsLeft:
        return [
          Positioned(
            left: 9,
            top: 27,
            child: Row(mainAxisSize: MainAxisSize.min, children: _tiles(18)),
          ),
          if (spec.corner != null)
            Positioned(
              right: 9,
              bottom: 8,
              child: Text(
                spec.corner!,
                style: TextStyle(
                  fontFamily: GType.mono,
                  fontSize: 9,
                  color: spec.icons.isNotEmpty ? spec.icons.last : _white55,
                ),
              ),
            ),
        ];

      case PreviewLayout.dockMagnified:
        return [
          Positioned(
            left: 0,
            right: 0,
            bottom: 8,
            child: Center(
              child: Container(
                decoration: BoxDecoration(
                  color: spec.dockBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: const EdgeInsets.fromLTRB(5, 4, 5, 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  // Bottom-aligned and centre-magnified, matching the real dock:
                  // a swollen icon grows UPWARD while its feet stay on the line.
                  // Drawing them all the same size would make this preview a
                  // KDE panel with different colours.
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: _magnifiedTiles(),
                ),
              ),
            ),
          ),
        ];

      // PHASE C. A catalogue theme whose colours we do not have yet.
      //
      // A DELIBERATE BLANK, not a generic desktop. The temptation is to draw a
      // plausible dock and bar so the grid looks even, but that invents a look
      // for a theme nobody has seen, and the first thing the user does after
      // downloading is compare it to the preview that lied. An empty frame says
      // "we do not know yet", which is true and costs nothing.
      case PreviewLayout.unknown:
        return const [];

      case PreviewLayout.terminal:
        return [
          Positioned(
            left: 9,
            right: 9,
            top: 25,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      '~ ❯ ',
                      style: TextStyle(
                        fontFamily: GType.mono,
                        fontSize: 10,
                        color: Color(0xFF52F088),
                      ),
                    ),
                    Container(
                        width: 6, height: 10, color: const Color(0xFF52F088)),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  'firefox files',
                  style: TextStyle(
                    fontFamily: GType.mono,
                    fontSize: 10,
                    color: Color(0xFF2E7A48),
                  ),
                ),
              ],
            ),
          ),
        ];
    }
  }

  Widget _dot(Color c) => Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(2),
        ),
      );

  /// The magnifying dock's preview tiles: the middle one large, its neighbours
  /// tapering. Sized by hand rather than by AquaDockMetrics — this is a 120px
  /// thumbnail, not the dock, and importing the real geometry here would couple
  /// the storefront to the shell for no gain.
  List<Widget> _magnifiedTiles() {
    const sizes = <double>[10, 17, 10];
    final out = <Widget>[];
    for (var i = 0; i < spec.icons.length; i++) {
      if (i > 0) out.add(const SizedBox(width: 4));
      final size = sizes[i % sizes.length];
      out.add(
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: spec.icons[i],
            borderRadius: BorderRadius.circular(size * 0.28),
          ),
        ),
      );
    }
    return out;
  }

  List<Widget> _tiles(double size) {
    final out = <Widget>[];
    for (var i = 0; i < spec.icons.length; i++) {
      if (i > 0) out.add(const SizedBox(width: 5));
      out.add(
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: spec.icons[i],
            borderRadius: BorderRadius.circular(5),
          ),
        ),
      );
    }
    return out;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// More-list row
// ─────────────────────────────────────────────────────────────────────────────

class _MoreRow extends StatelessWidget {
  const _MoreRow({required this.entry, required this.onGet});

  final ThemeMoreEntry entry;
  final VoidCallback onGet;

  @override
  Widget build(BuildContext context) {
    final c = ChromeScope.of(context).colors;
    return Material(
      color: c.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
        side: BorderSide(color: c.line),
      ),
      child: InkWell(
        onTap: onGet,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: entry.swatch,
                  ),
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.name,
                      style: TextStyle(
                        color: c.text,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      entry.subtitle,
                      style: TextStyle(
                        color: c.textMuted,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // ONE BUTTON, whether or not the entry is paid. The Pro badge that
              // used to sit here is gone with the rest of them: nothing on this
              // screen advertises a tier any more, and this row is unreachable
              // regardless while `themeMoreProvider` returns nothing.
              //
              // getbtn: outlined, transparent. "Get" — active voice, names
              // exactly what tapping does.
              OutlinedButton(
                  onPressed: onGet,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: c.text,
                    side: BorderSide(color: c.line),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  child: const Text(
                    'Get',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Headers — widgets (not inline in build) so they render UNDER the ThemedScaffold
// scope and read the live chrome instead of a house constant.
// ─────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Distros', style: d.text.display),
          const SizedBox(height: 3),
          Text(
            'Your phone, as a Linux desktop. Named by the real distro version.',
            style: d.text.caption.copyWith(fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _MoreHeader extends StatelessWidget {
  const _MoreHeader();

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        'More distros — pushed via updates',
        style: d.text.label.copyWith(fontSize: 11.5, letterSpacing: 0.5),
      ),
    );
  }
}
