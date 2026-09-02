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
/// ─── IT RUNS THE ACTION IN PLACE, AND IT USED TO POP FIRST ──────────────────
///
/// This page took the flow as an `onAction` callback and called
/// `Navigator.pop()` before invoking it, so that the storefront's messages
/// would land on a visible screen. The cost was the thing a review reported:
/// you read the page, decide to buy, tap, and are thrown back to the list
/// before Play's sheet arrives. On a slow payment method the two look
/// unrelated — the page vanished, and some time later a sheet appeared over
/// something else.
///
/// `runThemeCardAction` now takes a context, so this page passes its own and
/// stays where it is. There is still exactly one copy of the flow, which was
/// the whole reason for the callback; only the navigation side effect is gone.
///
/// The page WATCHES the catalogue, so the button relabels itself under the
/// user's thumb: Buy becomes Get becomes Apply as the purchase and the download
/// land, with no navigation at all.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/billing/entitlements.dart';
import '../../design/components/components.dart';
import '../../design/device_preview.dart';
import 'store_preview.dart';
import 'theme_actions.dart';
import 'theme_catalog.dart';
import 'theme_peek.dart';
import 'themes_screen.dart';

class ThemeDetailScreen extends ConsumerWidget {
  const ThemeDetailScreen({super.key, required this.packId});

  /// The card's [ThemeCard.packIdOrSpec], not its `id`.
  ///
  /// The two differ on the bundled distros ('ubuntu' against 'ubuntu-24-04')
  /// and the pack pipeline knows only the second, so keying this page on `id`
  /// would look right and find nothing the moment a floor card reached it.
  final String packId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ChromeScope.of(context);
    d.colors;

    // WATCHED, so the page follows the catalogue rather than a snapshot taken
    // when it opened. A purchase completing invalidates `catalogueProvider`,
    // and this page is the screen the user is looking at when that happens: it
    // has to stop saying Buy.
    // ─── .value, NOT asData ───────────────────────────────────────────────
    //
    // `asData` is null while the provider is reloading, even though that state
    // carries the previous value. Every pack install invalidates the catalogue,
    // so mid-refresh this page found no matching card and rendered "no longer
    // in the catalogue" at somebody who was about to pay.
    final cards =
        ref.watch(themeCatalogProvider).value ?? const <ThemeCard>[];

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

    // ─── A COLUMN, NOT ONE LIST ────────────────────────────────────────────
    //
    // The action used to be the last item in the ListView, which was fine while
    // the picture was 220dp. It is about half the screen now, so on every
    // distro with more than two feature rows the only button on the page starts
    // below the fold, and a store page whose Buy button has to be scrolled to
    // is a store page that loses the sale.
    //
    // So the scroller keeps everything that is READING material and the action
    // is pinned under it. That also fixes a smaller thing: the button no longer
    // moves as the catalogue fills in the contents table.
    return ThemedScaffold(
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.only(
                top: MediaQuery.viewPaddingOf(context).top,
                bottom: 8,
              ),
              children: [
                  const _BackRow(),
                  _Hero(card: card),
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
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              12 + MediaQuery.viewPaddingOf(context).bottom,
            ),
            child: _ActionButton(
              card: card,
              // NO POP. Play's sheet opens over this page, the messages land
              // here, and the button relabels itself as the catalogue changes.
              onTap: () => unawaited(runThemeCardAction(context, ref, card)),
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

/// The picture, and the three views of it.
///
/// ─── ABOUT HALF THE SCREEN, AND WHY THAT IS NOT VANITY ──────────────────────
///
/// This was a 220dp box, which is a card with more pixels. The page exists
/// because a card cannot answer "what am I buying", and the honest answer to
/// that is a picture big enough to read: where the panel is, what is in it,
/// which edge the dock takes, how the icons are shaped. Half the viewport is
/// what makes those legible, and everything under it is a caption on the
/// picture rather than the other way round.
///
/// A FRACTION of the viewport rather than a constant, because a 220dp box is a
/// third of a small phone and a fifth of a large one, and this is the one
/// element on the page whose whole job is being big.
///
/// ─── THREE MODES, AND THEY ARE THE THREE THINGS A DISTRO CHANGES ───────────
///
/// Desktop, drawer, folder. [DevicePreviewMode] already had exactly these, and
/// they are not an arbitrary tour: the desktop is the panel and the dock, the
/// drawer is the grid and its density, and the folder is the sheet. A distro
/// that only differs in one of them is a distro whose page shows you that.
///
/// STATIC, not interactive. A tappable preview that opened the real drawer
/// would be the strongest sales tool on the page and is close to handing the
/// distro over for browsing, and it would be a second app drawer to keep
/// working.
class _Hero extends ConsumerStatefulWidget {
  const _Hero({required this.card});

  final ThemeCard card;

  @override
  ConsumerState<_Hero> createState() => _HeroState();
}

class _HeroState extends ConsumerState<_Hero> {
  DevicePreviewMode _mode = DevicePreviewMode.desktop;

  static const _modes = <(DevicePreviewMode, String)>[
    (DevicePreviewMode.desktop, 'Desktop'),
    (DevicePreviewMode.drawer, 'App drawer'),
    (DevicePreviewMode.folder, 'Folder'),
  ];

  @override
  Widget build(BuildContext context) {
    final card = widget.card;

    final peeked = ref
        .watch(
          peekedThemeProvider(
            (packId: card.packIdOrSpec, version: card.remoteVersion),
          ),
        )
        .value;

    // Half the viewport, floored and capped. The floor stops a landscape or
    // split-screen window collapsing it to a strip; the cap stops a tablet
    // giving it the whole page.
    //
    // ─── IT IS A HEIGHT, AND THE PANE'S WIDTH FOLLOWS FROM IT ──────────────
    //
    // This used to be the whole box, full width, and `StorePreview` filled it:
    // 328 x 390 on an S22, an aspect of 1.0 against a device's 0.462, so the
    // hero stretched the wallpaper by 2.2x for the same reason the card
    // stretched it by 4.7. `PreviewStrip` now derives a device-shaped pane
    // from this height and centres it over the distro's gradient, so the
    // number below still decides how big the picture is and no longer decides
    // what shape a phone is.
    final height =
        (MediaQuery.sizeOf(context).height * 0.5).clamp(240.0, 520.0);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: height,
              // The index preview until the peek lands, and for good if it never
              // does. Same floor the card uses, same reason: a blank picture on
              // a page asking for money is worse than a less specific one.
              child: StorePreview(
                card: card,
                // ── ONE MODE, WHICH IS THE ONLY THING THIS PAGE CHANGES ────
                //
                // A card passes nothing and gets all three panes. This page
                // has a strip for choosing, so it passes the chosen one and
                // gets a single large pane through the same widget and the
                // same resolution. That is what keeps the picture on the card
                // and the picture on the page it opens from drifting.
                modes: [_mode],
                fallback: ThemePreview(card.preview),
              ),
            ),
          ),
        ),
        // ─── THE STRIP ONLY EXISTS WHEN THERE IS SOMETHING TO SWITCH ───────
        //
        // `ThemePreview` draws one thing and has no drawer or folder to show,
        // so three tabs over it would be three tabs that do nothing. Hidden
        // rather than disabled: a control that cannot act should not be on the
        // screen at all, which is the same rule the storefront's trailing slot
        // follows for `requiresAppUpdate`.
        if (peeked != null) _ModeStrip(
          mode: _mode,
          modes: _modes,
          onPick: (m) => setState(() => _mode = m),
        ),
      ],
    );
  }
}

class _ModeStrip extends StatelessWidget {
  const _ModeStrip({
    required this.mode,
    required this.modes,
    required this.onPick,
  });

  final DevicePreviewMode mode;
  final List<(DevicePreviewMode, String)> modes;
  final ValueChanged<DevicePreviewMode> onPick;

  @override
  Widget build(BuildContext context) {
    final c = ChromeScope.of(context).colors;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final (m, label) in modes) ...[
            if (m != modes.first.$1) const SizedBox(width: 6),
            Material(
              color: m == mode ? c.surface : Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
                side: BorderSide(color: m == mode ? c.accent : c.line),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onPick(m),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight:
                          m == mode ? FontWeight.w600 : FontWeight.w400,
                      color: m == mode ? c.text : c.textMuted,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

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
