/// The page a card opens before you pay for it.
///
/// ─── WHY THE LIST COULD NOT CARRY THIS ──────────────────────────────────────
///
/// A storefront card is a picture, a name, two rows and a strip of chips, and
/// that is already the most a list item can hold before fifteen of them become
/// a scroll nobody finishes. What it has to leave out is everything a person
/// actually wants before spending money: the rest of the feature rows, which of
/// them the free settings could reproduce anyway, what is in the download, and
/// what the purchase covers.
///
/// ─── IT IS REACHED FROM TWO STATES, NOT FIVE ────────────────────────────────
///
/// Only `locked` and `available` cards open this. Everything already on the
/// device keeps its one-tap apply, because switching distros is the frequent
/// action on that screen and growing it a tap to accommodate the rare one would
/// be the wrong trade. See `tapCard` in `themes_screen.dart`.
///
/// A consequence worth knowing while testing: on a device where every distro is
/// installed, nothing routes here at all.
///
/// ─── PRESENTATION ONLY ──────────────────────────────────────────────────────
///
/// [onAction] is the storefront's own `tapCard`, passed in. This page does not
/// buy, download or apply anything, and that is deliberate rather than lazy:
/// the purchase flow records a [PendingApply] intent before opening Play,
/// branches on six `PackResult` statuses and reports each one differently, and a
/// second copy of it here would be a second thing to keep correct.
///
/// The storefront pops this page before running the action, so its messages land
/// on a screen the user can see.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/billing/entitlements.dart';
import '../../design/components/components.dart';
import 'theme_catalog.dart';
import 'themes_screen.dart';

class ThemeDetailScreen extends ConsumerWidget {
  const ThemeDetailScreen({
    super.key,
    required this.packId,
    required this.onAction,
  });

  /// The card's [ThemeCard.packIdOrSpec], not its `id`.
  ///
  /// The two differ on the bundled distros ('ubuntu' against 'ubuntu-24-04')
  /// and the pack pipeline knows only the second, so keying this page on `id`
  /// would look right and find nothing the moment a floor card reached it.
  final String packId;

  /// Runs the card's primary action. Supplied by the storefront.
  final void Function(ThemeCard) onAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ChromeScope.of(context);
    final c = d.colors;

    // WATCHED, so the page follows the catalogue rather than a snapshot taken
    // when it opened. A purchase completing invalidates `catalogueProvider`,
    // and this page is the screen the user is looking at when that happens: it
    // has to stop saying Buy.
    final cards =
        ref.watch(themeCatalogProvider).asData?.value ?? const <ThemeCard>[];

    ThemeCard? found;
    for (final entry in cards) {
      if (entry.packIdOrSpec == packId) {
        found = entry;
        break;
      }
    }

    // AN EARLY RETURN, not a ternary around the whole body. `found` is a
    // reassigned local, and reading one inside the action closure below would
    // leave the rest of this method working with a nullable it has to bang at
    // every use. One final binding after the guard is promoted everywhere.
    if (found == null) {
      return ThemedScaffold(
        body: _Missing(top: MediaQuery.viewPaddingOf(context).top),
      );
    }
    final card = found;

    return ThemedScaffold(
      body: ListView(
        padding: EdgeInsets.only(
          top: MediaQuery.viewPaddingOf(context).top,
          bottom: 32,
        ),
        children: [
          const _BackRow(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              // TALLER THAN THE CARD'S 152, and that is the whole visual
              // argument for a second screen: the miniature is the only picture
              // of this distro that exists, so the page selling it should show
              // the biggest version of it.
              child: SizedBox(
                height: 220,
                child: ThemePreview(card.preview),
              ),
            ),
          ),
          _Title(card: card),
          ..._featureSection(
            context,
            title: 'What only this distro does',
            rows: [
              for (final f in card.features)
                if (f.exclusive) f,
            ],
            accented: true,
          ),
          ..._featureSection(
            context,
            title: 'Look and feel',
            rows: [
              for (final f in card.features)
                if (!f.exclusive) f,
            ],
            accented: false,
          ),
          _Contents(card: card),
          if (card.status == CardStatus.locked) const _Terms(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
            child: _ActionButton(
              card: card,
              onTap: () {
                // POP FIRST. The storefront owns the flow and reports into its
                // own context, so running it under this page would put every
                // message behind the screen the user is reading.
                Navigator.of(context).pop();
                onAction(card);
              },
            ),
          ),
        ],
      ),
    );
  }

  /// A titled block of feature rows, or nothing when there are none.
  ///
  /// ─── THE SPLIT IS THE PRICE ARGUMENT, MADE VISIBLE ────────────────────────
  ///
  /// [ThemeFeature.exclusive] has always decided which two rows the card shows,
  /// and it was invisible to the person reading it: an exclusive row and a
  /// palette row looked identical. Here they are separated and labelled, so
  /// "what only this distro does" is a heading with either something under it
  /// or nothing.
  ///
  /// A distro whose entire list is inexclusive therefore renders a page with no
  /// first block, which is exactly what it should look like. If that distro is
  /// also paid, the page is saying so plainly, and the fix is to build
  /// something rather than to word it better.
  List<Widget> _featureSection(
    BuildContext context, {
    required String title,
    required List<ThemeFeature> rows,
    required bool accented,
  }) {
    if (rows.isEmpty) return const [];
    final c = ChromeScope.of(context).colors;

    return [
      _SectionHeading(title),
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final f in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.only(top: 6, right: 8),
                      decoration: BoxDecoration(
                        // The accent marks the rows that cost money. A muted
                        // dot on the second block says the same thing its
                        // heading does without repeating the word.
                        color: accented ? c.accent : c.textMuted,
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
                        // NO maxLines. The card truncates at two because it is
                        // a list item; this page has the room and truncating
                        // here would hide the half of the sentence that says
                        // what the thing actually does.
                        style: const TextStyle(fontSize: 13, height: 1.4),
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

// ─────────────────────────────────────────────────────────────────────────────
// Pieces
// ─────────────────────────────────────────────────────────────────────────────

class _BackRow extends StatelessWidget {
  const _BackRow();

  @override
  Widget build(BuildContext context) {
    final c = ChromeScope.of(context).colors;
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.of(context).pop(),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chevron_left, size: 20, color: c.textMuted),
                const SizedBox(width: 2),
                Text(
                  'Distros',
                  style: TextStyle(fontSize: 13.5, color: c.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title({required this.card});

  final ThemeCard card;

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(card.name, style: d.text.display),
          if (card.subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              card.subtitle,
              style: d.text.value.copyWith(
                fontSize: 12.5,
                color: d.colors.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The contents table.
///
/// Every row is nullable and an absent value draws NO ROW, never a placeholder.
/// That is the same rule [ThemeCard.contentsChips] follows on the card and the
/// same one the rest of this app follows for nullable stats: a table reading
/// `Typeface  --` is worse than a table with three rows.
///
/// A pack that published none of the block therefore shows the download size
/// alone, which is the honest state of every pack in the catalogue until it is
/// republished.
class _Contents extends StatelessWidget {
  const _Contents({required this.card});

  final ThemeCard card;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[];

    if (card.subtitle.isNotEmpty) rows.add(('Desktop', card.subtitle));

    final icons = card.iconPackTitle;
    if (icons != null && icons.isNotEmpty) rows.add(('Icon pack', icons));

    final walls = card.wallpaperCount;
    // Zero IS printed here, unlike on the card. A chip reading "0 wallpapers"
    // is noise in a strip of three; a table row saying it is an answer to a
    // question the reader is deliberately looking down a list for.
    if (walls != null) rows.add(('Wallpapers', '$walls'));

    final font = card.fontName;
    if (font != null && font.isNotEmpty) rows.add(('Typeface', font));

    if (rows.isEmpty) return const SizedBox.shrink();

    final d = ChromeScope.of(context);
    final c = d.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeading('What you get'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            children: [
              for (final (label, value) in rows)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: c.line)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(fontSize: 13, color: c.textMuted),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Flexible(
                        child: Text(
                          value,
                          textAlign: TextAlign.right,
                          style: d.text.value.copyWith(
                            fontSize: 12.5,
                            color: c.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// What the money buys, on the only screen where that question is being asked.
///
/// Shown for a LOCKED card and nothing else. On a card the user already owns it
/// would be answering a question they settled by paying, and on a free distro
/// it would be describing a transaction that is not happening.
class _Terms extends StatelessWidget {
  const _Terms();

  @override
  Widget build(BuildContext context) {
    final c = ChromeScope.of(context).colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeading('Good to know'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Text(
            'One time purchase, yours on every device signed in to this Play '
            'account. Every launcher feature stays free. Switch back to a free '
            'distro whenever you like.',
            style: TextStyle(fontSize: 12.5, height: 1.5, color: c.textMuted),
          ),
        ),
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 10),
      child: Text(
        text,
        style: d.text.label.copyWith(fontSize: 11, letterSpacing: 0.7),
      ),
    );
  }
}

/// The one action, named for what it does.
///
/// The label follows [CardStatus] on the same ordering the storefront's trailing
/// slot uses, and for the same reason: an action that cannot succeed must not
/// present as one. `requiresAppUpdate` gets a flat label rather than a button,
/// because tapping it downloads nothing and the app looks broken rather than out
/// of date.
class _ActionButton extends ConsumerWidget {
  const _ActionButton({required this.card, required this.onTap});

  final ThemeCard card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ChromeScope.of(context).colors;

    if (card.status == CardStatus.requiresAppUpdate) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: c.line),
        ),
        child: Text(
          'Needs a newer version of G Launcher',
          style: TextStyle(fontSize: 13, color: c.textMuted),
        ),
      );
    }

    // WATCHED UNCONDITIONALLY, not inside the `locked` arm below. A `ref.watch`
    // that only runs on some branches means the page stops rebuilding when the
    // status changes under it, which is precisely the moment this page needs to
    // repaint. The provider already answers null for a null sku, so a free card
    // costs nothing here.
    //
    // Null is ORDINARY, not an error: no Play Services, no Play track yet, or a
    // product missing from the console. The plain word is what stops the button
    // going blank, exactly as the card's trailing slot does it.
    final price = ref.watch(productPriceProvider(card.sku));

    final label = switch (card.status) {
      CardStatus.locked => price == null ? 'Buy' : 'Buy $price',
      CardStatus.available => 'Get',
      CardStatus.updateAvailable => 'Update',
      _ => 'Apply',
    };

    return Material(
      color: c.accent,
      borderRadius: BorderRadius.circular(11),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: c.onAccent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The pack went away while this page was open.
///
/// Rare and real: an unpublish lands between opening the page and the next
/// catalogue refresh. Says so rather than rendering an empty page, which is
/// indistinguishable from one that failed to load.
class _Missing extends StatelessWidget {
  const _Missing({required this.top});

  final double top;

  @override
  Widget build(BuildContext context) {
    final c = ChromeScope.of(context).colors;
    return ListView(
      padding: EdgeInsets.only(top: top, bottom: 32),
      children: [
        const _BackRow(),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 40, 18, 0),
          child: Text(
            'This distro is no longer in the catalogue.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: c.textMuted),
          ),
        ),
      ],
    );
  }
}
