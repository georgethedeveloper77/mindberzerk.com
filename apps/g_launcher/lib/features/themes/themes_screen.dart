import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/billing/entitlements.dart';
import '../../data/prefs/prefs_repository.dart';
import '../../design/branded_message.dart';
import '../../design/components/components.dart';
import '../../design/tokens/typography.dart';
import '../../engine/effective_theme.dart';
import 'theme_catalog.dart';

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
class ThemesScreen extends ConsumerWidget {
  const ThemesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeSpec = ref.watch(effectiveThemeProvider).asData?.value.spec;
    final cards =
        ref.watch(themeCatalogProvider).asData?.value ?? const <ThemeCard>[];
    final more = ref.watch(themeMoreProvider);
    final progress = ref.watch(packProgressProvider);
    // Watched here so a price arriving from Play repaints the whole grid at
    // once, rather than each card independently re-reading a provider family.
    ref.watch(ownedSkusProvider);

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
      final result =
          await ref.read(packActionsProvider).install(c.packIdOrSpec);
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
          context
              .showMessage('${c.name} failed verification and was discarded');
        default:
          context.showMessage('Could not download ${c.name}, try again');
      }
    }

    Future<void> tapCard(ThemeCard c) async {
      if (isActive(c)) {
        context.showMessage('${c.name} is your current theme');
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
          final started = await ref.read(buyProvider)(c.sku!);
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

    return ThemedScaffold(
      body: ListView(
        padding: EdgeInsets.only(
          top: MediaQuery.viewPaddingOf(context).top,
          bottom: 28,
        ),
        children: [
          // ── Header ──────────────────────────────────────────────────────
          const _Header(),

          // ── Grid ────────────────────────────────────────────────────────
          GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cards.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              mainAxisExtent: 150,
            ),
            itemBuilder: (context, i) {
              final c = cards[i];
              return _ThemeCard(
                card: c,
                active: isActive(c),
                // null when nothing is in flight for this pack, which is the
                // normal case; the card only grows a bar while it is downloading.
                progress: progress[c.packIdOrSpec],
                onTap: () => tapCard(c),
              );
            },
          ),

          // ── More ────────────────────────────────────────────────────────
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
                            ? '${m.name} is a Pro theme, coming soon'
                            : '${m.name} ships in an update, coming soon',
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card
// ─────────────────────────────────────────────────────────────────────────────

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
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _ThemePreview(card.preview),
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
                        backgroundColor: c.onSurface.withValues(alpha: 0.15),
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
                        const SizedBox(height: 1),
                        Text(
                          card.version,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          // Mono, from the chrome's value ramp — the version
                          // line reads like a package string on any distro.
                          style: d.text.value.copyWith(
                            fontSize: 11,
                            color: c.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _Trailing(card: card, active: active),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The right-hand meta element: the active check, a Pro badge, or the DE tag.
class _Trailing extends StatelessWidget {
  const _Trailing({required this.card, required this.active});

  final ThemeCard card;
  final bool active;

  @override
  Widget build(BuildContext context) {
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
    if (!active && card.status == CardStatus.locked) return const _ProBadge();
    if (!active && card.status == CardStatus.available) {
      return _MiniLabel('Get', c.accent);
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
    if (card.tier == ThemeTier.pro) return const _ProBadge();
    return _Tag(card.tag);
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

class _Tag extends StatelessWidget {
  const _Tag(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = ChromeScope.of(context).colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: c.line,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
          color: c.textMuted,
        ),
      ),
    );
  }
}

class _ProBadge extends StatelessWidget {
  const _ProBadge();

  @override
  Widget build(BuildContext context) {
    final c = ChromeScope.of(context).colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.accent,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        'Pro',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: c.onAccent,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// The mini-desktop preview. Pure decoration driven by ThemePreviewSpec.
// ─────────────────────────────────────────────────────────────────────────────

class _ThemePreview extends StatelessWidget {
  const _ThemePreview(this.spec);

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
          // Top bar — every layout has one.
          Positioned(
            left: 9,
            right: 9,
            top: 9,
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

  List<Widget> _layout() {
    switch (spec.layout) {
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
                  'firefox files…',
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
              if (entry.pro)
                const _ProBadge()
              else
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
          Text('Themes', style: d.text.display),
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
        'More themes — pushed via updates',
        style: d.text.label.copyWith(fontSize: 11.5, letterSpacing: 0.5),
      ),
    );
  }
}
