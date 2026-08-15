import 'dart:io' show File;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/billing/entitlements.dart';
import '../../data/cdn/pack_repository.dart';
import '../../data/prefs/prefs_repository.dart';
import '../../data/repositories/app_repository.dart';
import '../../design/branded_message.dart';
import '../../design/components/components.dart';
import '../../engine/effective_theme.dart';
import '../../platform/launcher_api.g.dart';
import '../../platform/pack_api.g.dart';
import '../drawer/app_icon.dart';
import 'icon_appearance_rows.dart';
import '../themes/theme_catalog.dart' show CardStatus;

/// One native handle for the preview lookup, mirroring theme_engine's rule:
/// a new Pigeon wrapper per card is a new codec instance for no reason.
final _previewApi = PackHostApi();

/// Where a pack's preview.png can be drawn from, or null for the schematic.
///
/// Watches the catalogue so the URL flips from the CDN copy to the installed
/// `file://` copy the moment an install lands, without any card doing its own
/// bookkeeping. Any channel failure is "no preview", never an error: a store
/// card must render something regardless of what the bridge is doing.
final packPreviewUrlProvider =
    FutureProvider.family<String?, String>((ref, packId) async {
  ref.watch(catalogueProvider);
  try {
    return await _previewApi.packPreviewUrl(packId);
  } catch (_) {
    return null;
  }
});

/// ICON THEMES — the distros screen's sibling.
///
/// In Linux an icon set is an ICON THEME (`/usr/share/icons`,
/// `gtk-icon-theme-name`), which is what Yaru, Breeze, Papirus and Numix all
/// call themselves. Keeping that word costs nothing and is accurate: a distro
/// and an icon theme genuinely are different objects, and mixing them is the
/// whole point of this screen.
///
/// ─── TWO SOURCES, TWO SELECTIONS, AND THEY LAYER ────────────────────────────
///
/// This is the thing to understand before changing anything here. There are two
/// prefs and they are NOT alternatives:
///
///   prefs.iconPackId      OURS. A `hero` pack that arrived over the CDN,
///                         signed, sometimes sold. Feeds `IconStyle.heroPack`
///                         in `EffectiveTheme.resolve` and is rendered by the
///                         native icon pipeline.
///   prefs.systemIconPack  THEIRS. A Nova/ADW-format APK installed from Play,
///                         including anything exported from Icon Pack Studio.
///                         Pushed separately by `setIconPack` and read by
///                         `IconPackApps`. Never part of `IconStyle`.
///
/// Native layers the third-party pack ABOVE hero: a Nova pack covers the apps
/// it has art for, the distro's hero art fills the rest, the CC0 brand glyphs
/// fill the rest of that, and the generator catches everything left. So both
/// can be set, `LauncherPrefs.systemIconPack` says so explicitly, and the first
/// draft of this screen got it wrong by making them mutually exclusive.
///
/// Hence two grids, two independent choices, and a line of copy explaining the
/// layering — because a user with both set and no explanation will reasonably
/// conclude one of them is broken.
///
/// ─── WHY `simple-icons` NEVER APPEARS HERE ──────────────────────────────────
///
/// It is a `brand` pack, not a `hero` pack: the CC0 glyph layer underneath
/// everything, not a set anyone chooses. The `packType == 'hero'` filter below
/// excludes it by construction rather than by name, so a second brand pack
/// cannot leak in later.
///
/// ─── SUPERSEDES `features/settings/icon_pack_page.dart` ─────────────────────
///
/// That page handled `systemIconPack` only, as a one-column list, and NOTHING
/// EVER IMPORTED IT — it has never been reachable. Grep for `IconPackPage`
/// before deleting it.

/// Third-party icon packs installed as APKs: package name -> label.
///
/// AN EMPTY MAP IS A REAL ANSWER and draws the empty state, never an error. Note
/// while debugging that empty is ALSO what a missing `<queries>` declaration
/// produces on Android 11+, silently, on a phone with forty packs installed.
/// Check the manifest before this file.
///
/// A FutureProvider rather than widget state so it survives a rebuild, and so
/// `ref.invalidate` is the whole of "refresh" when someone installs a pack and
/// comes back.
final installedIconThemesProvider =
    FutureProvider<Map<String, String>>((ref) {
  return ref.read(launcherHostApiProvider).installedIconPacks();
});

/// The installed APK behind a third-party pack, so its own launcher icon can be
/// the preview.
///
/// This is the one honest preview available for a third-party pack and it costs
/// nothing: those apps almost always put a sample of their art on their own
/// icon, and `AppIcon` already knows how to draw one. `componentKey` is
/// `package/class`, so the match is on the segment before the slash.
///
/// Null when the pack is not in the app list, which happens for a pack that has
/// no launcher activity. The card falls back to the schematic.
final iconThemeAppProvider =
    Provider.family<AppEntry?, String>((ref, packageName) {
  final apps = ref.watch(appListProvider).asData?.value ?? const <AppEntry>[];
  for (final a in apps) {
    if (a.componentKey.split('/').first == packageName) return a;
  }
  return null;
});

class IconThemeScreen extends ConsumerWidget {
  const IconThemeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeAsync = ref.watch(effectiveThemeProvider);

    return themeAsync.when(
      // The theme is resolved long before anything can navigate here, so these
      // are formalities. They render nothing rather than a spinner, because a
      // flash of unthemed chrome on the way into a settings page is worse than
      // a frame of nothing — the same call `themes_screen` makes.
      loading: () =>
          const ThemedScaffold(title: 'Icons', body: SizedBox.shrink()),
      error: (_, __) =>
          const ThemedScaffold(title: 'Icons', body: SizedBox.shrink()),
      data: (theme) => _Screen(theme: theme),
    );
  }
}

class _Screen extends ConsumerWidget {
  const _Screen({required this.theme});

  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // THE FETCH. Same gap the distros grid had: `catalogueProvider` is the
    // cached index and never hits the network, so a hero pack published five
    // minutes ago is invisible until something asks. Fired once per app run and
    // shared with the distros screen, so opening both does not fetch twice.
    ref.watch(catalogueRefreshProvider);

    // ── FILTERED HERE, NOT IN A DERIVED PROVIDER ────────────────────────────
    //
    // This was a `Provider<List<PackInfo>>` watching `catalogueProvider`, and it
    // CRASHED THE SCREEN on first open:
    //
    //   setState() or markNeedsBuild() called during build
    //   ... iconThemePacksProvider -> Ref.watch -> Ref._invalidateSelf
    //
    // A synchronous Provider that watches an ASYNC one gets mounted mid-build
    // the first time this screen opens, the catalogue emits during that same
    // flush, and the resulting `invalidateSelf` lands inside the build phase —
    // which Riverpod forbids. `themeCatalogProvider` avoids it by being a
    // FutureProvider awaiting `catalogueProvider.future`; a plain Provider has
    // no such escape.
    //
    // The filter is three lines and has no reason to be a provider at all. Doing
    // it here removes the mount and the whole class of ordering bug with it.
    final catalogue =
        ref.watch(catalogueProvider).asData?.value ?? const <PackInfo>[];
    final packs = [
      // `hero` only. See the note at the top of the file about `simple-icons`.
      for (final p in catalogue)
        if (p.packType == 'hero') p,
    ]..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

    // ── grouped by distro, via the id prefix convention ────────────────────
    //
    // A hero pack belongs to the distro whose base id prefixes its own:
    // `kali-2024-icons` and `kali-2024-neon-icons` both belong to
    // `kali-2024-theme`. Derived from ids alone, deliberately: Dart can only
    // read the ACTIVE distro's theme.json, so every other distro is just a
    // theme pack in the catalogue, and its id is the one fact always present.
    // Longest base wins, so a distro named `ubuntu` could not claim
    // `ubuntu-24-04-icons` away from `ubuntu-24-04`.
    final distroTitles = <String, String>{};
    for (final p in catalogue) {
      if (p.packType != 'theme') continue;
      final base = p.packId.endsWith('-theme')
          ? p.packId.substring(0, p.packId.length - '-theme'.length)
          : p.packId;
      distroTitles[base] = p.title.isEmpty ? base : p.title;
    }
    final currentBase = theme.spec.id.endsWith('-theme')
        ? theme.spec.id.substring(0, theme.spec.id.length - '-theme'.length)
        : theme.spec.id;
    // The active distro may be bundled and never republished, so it can be
    // absent from the catalogue. It still owns its packs.
    distroTitles.putIfAbsent(currentBase, () => theme.spec.name);

    String? distroOf(String packId) {
      String? best;
      for (final base in distroTitles.keys) {
        if (packId.startsWith('$base-') &&
            (best == null || base.length > best.length)) {
          best = base;
        }
      }
      return best;
    }

    // What the DISTRO itself asks for, in its own theme.json. Read HERE rather
    // than further down, because the partition below has to know it.
    final distroPack = theme.spec.icons.heroPack;

    final currentPacks = <PackInfo>[];
    final byDistro = <String, List<PackInfo>>{};
    final standalone = <PackInfo>[];
    PackInfo? namedByDistro;
    for (final p in packs) {
      // ── THE PACK THE DISTRO NAMES BELONGS TO NO SHELF ──────────────────
      //
      // It is drawn by the Distro default card below, which carries its
      // preview, its progress and its Get affordance. Letting it fall through
      // to a shelf as well draws THE SAME PACK TWICE: once as the selected
      // default and once as an uninstalled card offering to Get something the
      // device is already wearing.
      //
      // This used to be handled by `if (p.packId != distroPack)` at the
      // currentPacks call site alone, which was correct only while the named
      // pack always carried the distro's own id prefix. That is not a rule:
      // `icons.heroPack` may name ANY pack, and a distro naming a STANDALONE
      // one is a supported case that Ubuntu now uses. Such a pack took the
      // `base == null` branch, missed the guard, and duplicated. Excluding it
      // once here covers all three shelves instead of one.
      //
      // It is also where the default card's own pack is found, because
      // searching `currentPacks` for it had the same prefix assumption baked
      // in: a standalone default was never found, so the card fell back to the
      // generator schematic and offered no way to install what it named.
      if (distroPack != null && p.packId == distroPack) {
        namedByDistro = p;
        continue;
      }
      final base = distroOf(p.packId);
      if (base == null) {
        standalone.add(p);
      } else if (base == currentBase) {
        currentPacks.add(p);
      } else {
        (byDistro[base] ??= <PackInfo>[]).add(p);
      }
    }
    // FINAL, so the analyzer's promotion holds inside the card builder below.
    final PackInfo? defaultPack = namedByDistro;
    final otherDistros = byDistro.keys.toList()
      ..sort((a, b) => distroTitles[a]!
          .toLowerCase()
          .compareTo(distroTitles[b]!.toLowerCase()));

    final installed = ref.watch(installedIconThemesProvider);
    final progress = ref.watch(packProgressProvider);

    // Watched here so a price arriving from Play repaints the whole grid at
    // once, rather than every card independently re-reading a provider family.
    ref.watch(ownedSkusProvider);

    final prefs = ref.read(prefsProvider(theme.spec.id).notifier);

    final selectedHero = theme.prefs.iconPackId;
    final selectedSystem = theme.prefs.systemIconPack;

    // ── the two writes ──────────────────────────────────────────────────────
    //
    // `.edit`, never `.update`. `.update` is an inherited name collision on
    // AsyncNotifier that mutates in memory without touching disk, so the choice
    // would look applied and revert on the next cold start.
    //
    // `clearing()`, not `copyWith(x: null)`. copyWith reads a null argument as
    // "leave it alone", so the reset rows would silently do nothing — and only
    // for the one value that needs them to work.
    Future<void> chooseHero(String? packId) => prefs.edit(
          (p) => packId == null
              ? p.clearing(iconPackId: true)
              : p.copyWith(iconPackId: packId),
        );

    Future<void> chooseSystem(String? packageName) => prefs.edit(
          (p) => packageName == null
              ? p.clearing(systemIconPack: true)
              : p.copyWith(systemIconPack: packageName),
        );

    // `setIconTheme` and `setIconPack` are deliberately NOT called from here.
    // `effectiveThemeProvider` watches prefs and pushes both, so there is
    // exactly one writer; a second one here would race it and lose about half
    // the time. The grid repaints on its own: these prefs are inside
    // `EffectiveTheme.==`, `AppIcon` folds them into its cache key, and both
    // therefore re-key every icon the moment one changes.

    /// Download, then report per STATUS, never per detail string.
    ///
    /// Lifted from `themes_screen.tapCard` deliberately, message for message.
    /// Each branch needs a different action from the user, and folding them into
    /// one "Download failed" is the message that tells nobody anything — which
    /// is the reason `PackResult` carries a status at all.
    Future<void> download(PackInfo p, {required bool thenApply}) async {
      final result = await ref.read(packActionsProvider).install(p.packId);
      if (!context.mounted) return;

      switch (result.status) {
        case 'installed':
          if (thenApply) {
            await chooseHero(p.packId);
            if (context.mounted) context.showMessage('${p.title} applied');
          } else {
            context.showMessage('${p.title} updated');
          }
        case 'upToDate':
          // The common case on a re-tap. Silent on purpose: telling someone
          // nothing happened is noise.
          break;
        case 'notEntitled':
          context.showMessage('${p.title} needs to be purchased first');
        case 'appTooOld':
          context.showMessage('${p.title} needs a newer version of G Launcher');
        case 'noSpace':
          context.showMessage('Not enough free space for ${p.title}');
        case 'cancelled':
          break;
        case 'rejected':
          // A signature or hash check failed. NOT retryable, and worth saying
          // plainly rather than dressing up as a network blip — retrying a bad
          // signature produces the same answer and burns someone's data.
          context.showMessage('${p.title} failed verification and was discarded');
        default:
          context.showMessage('Could not download ${p.title}, try again');
      }
    }

    Future<void> tapPack(PackInfo p, CardStatus status) async {
      if (selectedHero == p.packId) {
        context.showMessage('${p.title} is already your icon theme');
        return;
      }

      switch (status) {
        // On the device already. The selection flips, prefs writes, and every
        // icon re-requests because the pack id is in AppIcon's cache key.
        case CardStatus.bundled:
        case CardStatus.installed:
          await chooseHero(p.packId);
          if (context.mounted) context.showMessage('${p.title} applied');

        // On the device but stale. Apply FIRST, update after: the user asked to
        // see this artwork, and making them wait on a download to see something
        // they already have is the wrong trade.
        case CardStatus.updateAvailable:
          await chooseHero(p.packId);
          await download(p, thenApply: false);

        case CardStatus.available:
          await download(p, thenApply: true);

        case CardStatus.locked:
          // Play's own sheet. The download is NOT started here: the purchase
          // stream fires asynchronously, possibly minutes later for the cash
          // and carrier-billing methods this market actually uses, and
          // `packBridgeProvider` is listening for exactly that. Kicking off a
          // download on the return of buy() would race the entitlement push and
          // usually lose.
          final started = await ref.read(buyProvider)(p.sku!);
          if (!started && context.mounted) {
            context.showMessage('${p.title} is not available to buy right now');
          }

        case CardStatus.requiresAppUpdate:
          context.showMessage('${p.title} needs a newer version of G Launcher');
      }
    }

    // One grid shape for every section, so the shelves read as one storefront.
    Widget packGrid(List<Widget> children) => GridView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            // The same fixed extent the distros grid uses, so the two screens
            // read as siblings rather than as two people's work.
            mainAxisExtent: 150,
          ),
          children: children,
        );

    return ThemedScaffold(
      title: 'Icons',
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          // ── ours, grouped by distro ───────────────────────────────────────
          //
          // One shelf per distro rather than one flat sea of cards. The first
          // shelf is the active distro: its default card plus every pack whose
          // id it owns. Other distros' packs follow, then packs that belong to
          // no distro at all. The grouping is the prefix rule above, so
          // publishing a pack under a distro's id is the whole of putting it
          // on that distro's shelf; free or paid falls out of each card's own
          // sku and entitlement, which `PackInfo.unlocked` already resolved.
          ...iconAppearanceRows(context, ref, theme),

          ThemedSectionHeader('Comes with ${theme.spec.name}'),

          packGrid([
            // ── THE DEFAULT CARD AND THE PACK IT NAMES ARE ONE CARD ─────────
            //
            // They used to be two: "Distro default" beside a _PackCard for the
            // very pack the default resolves to. Selecting the pack left the
            // default looking unselected, selecting the default never
            // installed the pack behind it, and the shelf showed the same
            // artifact twice. Now the default card carries the named pack's
            // preview, progress, and Get/Update affordance, `currentPacks`
            // skips it below, and choosing the default also installs it,
            // because the named pack IS what "default" means and leaving the
            // generator running after that tap reads as the choice failing.
            Builder(builder: (context) {
              final c = ChromeScope.of(context).colors;
              final st = defaultPack == null
                  ? null
                  : CardStatus.parse(
                      defaultPack.state,
                      unlocked: defaultPack.unlocked,
                      free: defaultPack.sku == null,
                    );
              return _Card(
                title: 'Distro default',
                // Naming the pack the distro actually asks for, so "default"
                // is a fact rather than a shrug. Falls back to the generator's
                // own name when a distro authors none, which is what runs.
                subtitle: distroPack ?? 'Adaptive, every app covered',
                // Selecting the named pack by hand and selecting the default
                // are the same choice, so both light this card.
                active: selectedHero == null ||
                    (distroPack != null && selectedHero == distroPack),
                progress:
                    defaultPack == null ? null : progress[defaultPack.packId],
                preview: defaultPack == null
                    ? _Schematic(theme: theme, accent: true)
                    : _PackPreview(theme: theme, packId: defaultPack.packId),
                trailing: switch (st) {
                  CardStatus.available => _Mini('Get', c.accent),
                  CardStatus.updateAvailable => _Mini('Update', c.accent),
                  _ => null,
                },
                onTap: () async {
                  // A stable local, so promotion holds inside this closure
                  // regardless of how the analyzer treats the captured var.
                  final dp = defaultPack;
                  if (dp != null &&
                      (st == CardStatus.available ||
                          st == CardStatus.updateAvailable)) {
                    await download(dp, thenApply: false);
                  }
                  if (selectedHero != null) {
                    await chooseHero(null);
                    if (context.mounted) {
                      context.showMessage('Using the distro’s own icons');
                    }
                  }
                },
              );
            }),
            // No `p.packId != distroPack` guard here any more. The partition
            // above removes the named pack from every shelf, so a second rule
            // at one call site would be a copy that only covers one of three.
            for (final p in currentPacks)
              _PackCard(
                theme: theme,
                pack: p,
                active: selectedHero == p.packId,
                progress: progress[p.packId],
                onTap: (status) => tapPack(p, status),
              ),
          ]),

          for (final base in otherDistros) ...[
            ThemedSectionHeader('${distroTitles[base]} packs'),
            packGrid([
              for (final p in byDistro[base]!)
                _PackCard(
                  theme: theme,
                  pack: p,
                  active: selectedHero == p.packId,
                  progress: progress[p.packId],
                  onTap: (status) => tapPack(p, status),
                ),
            ]),
          ],

          if (standalone.isNotEmpty) ...[
            const ThemedSectionHeader('Standalone packs'),
            packGrid([
              for (final p in standalone)
                _PackCard(
                  theme: theme,
                  pack: p,
                  active: selectedHero == p.packId,
                  progress: progress[p.packId],
                  onTap: (status) => tapPack(p, status),
                ),
            ]),
          ],

          if (packs.isEmpty)
            const _Note(
              text: 'Icon themes arrive with distros. Each one ships its own '
                  'set, and they can be mixed: run the Kali desktop with '
                  'Ubuntu icons if you want.',
            ),

          // ── theirs ────────────────────────────────────────────────────────
          const ThemedSectionHeader('Installed packs'),

          installed.when(
            loading: () => const SizedBox(height: 12),
            // A failed query is indistinguishable from none installed as far as
            // what the user can do about it, so it draws the same thing.
            // Inventing an error state would offer a retry button for a
            // package-manager call that does not fail transiently.
            error: (_, __) => const _Note(text: _emptyPacks),
            data: (map) => map.isEmpty
                ? const _Note(text: _emptyPacks)
                : GridView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      mainAxisExtent: 150,
                    ),
                    children: [
                      _Card(
                        title: 'None',
                        subtitle: 'Distro icons only',
                        active: selectedSystem == null,
                        preview: _Schematic(theme: theme, accent: false),
                        onTap: () async {
                          if (selectedSystem == null) return;
                          await chooseSystem(null);
                        },
                      ),
                      for (final e in map.entries)
                        _SystemCard(
                          theme: theme,
                          packageName: e.key,
                          label: e.value,
                          active: selectedSystem == e.key,
                          onTap: () async {
                            if (selectedSystem == e.key) return;
                            await chooseSystem(e.key);
                            if (context.mounted) {
                              context.showMessage('${e.value} applied');
                            }
                          },
                        ),
                    ],
                  ),
          ),

          // ── the layering, said out loud ───────────────────────────────────
          //
          // Both selections are live at once, and without this line someone who
          // has picked from both grids sees half their icons come from one and
          // reasonably concludes the other did not work.
          const _Disclosure(
            title: 'How the layers combine',
            text: 'An installed pack covers the apps it has art for. Anything '
                'it misses falls back to the icon theme, then to the distro’s '
                'own icons.',
          ),
        ],
      ),
    );
  }
}

const _emptyPacks = 'No icon packs installed. Anything in Nova or ADW format '
    'works, including your own exports from Icon Pack Studio.';

/// A card in either grid: preview on top, name and trailing beneath.
///
/// Deliberately shaped like `_ThemeCard` on the distros screen — same 150pt
/// extent, same two-band layout, same active ring — because these are two
/// halves of one storefront and a user moves between them in one sitting.
class _Card extends StatelessWidget {
  const _Card({
    required this.title,
    required this.subtitle,
    required this.active,
    required this.preview,
    required this.onTap,
    this.trailing,
    this.progress,
  });

  final String title;
  final String subtitle;
  final bool active;
  final Widget preview;
  final VoidCallback onTap;
  final Widget? trailing;

  /// 0.0 to 1.0 while this pack is downloading, null otherwise. The bar only
  /// exists during a transfer; a permanent empty track reads as a broken one.
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    final c = d.colors;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? c.accent : c.line,
            width: active ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: preview),
            if (progress != null)
              // Hand-drawn rather than a Material indicator: those read the
              // ambient ThemeData, which this screen deliberately does not have
              // (see no_constants.sh's settings scope).
              SizedBox(
                height: 3,
                child: Stack(
                  children: [
                    Positioned.fill(child: ColoredBox(color: c.line)),
                    // FractionallySizedBox rather than two Expandeds: a flex of
                    // zero is an assertion failure, and progress is legitimately
                    // 0.0 for the first frame of every download.
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: progress!.clamp(0.0, 1.0),
                      child: ColoredBox(color: c.accent),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: d.text.title,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: d.text.caption,
                        ),
                      ],
                    ),
                  ),
                  if (active)
                    Icon(Icons.check_circle, size: 18, color: c.accent)
                  else if (trailing != null) ...[
                    const SizedBox(width: 6),
                    trailing!,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One of ours, from the signed catalogue.
class _PackCard extends ConsumerWidget {
  const _PackCard({
    required this.theme,
    required this.pack,
    required this.active,
    required this.progress,
    required this.onTap,
  });

  final EffectiveTheme theme;
  final PackInfo pack;
  final bool active;
  final double? progress;
  final void Function(CardStatus) onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ChromeScope.of(context).colors;

    // The SAME derivation the distros grid uses, reused rather than re-written.
    // Ownership arrives already resolved on `PackInfo.unlocked`, from
    // `CdnIndex.isUnlocked` against the signed grants — never re-derived in
    // Dart from sku plus a local owned-set, which would be a second
    // implementation of the ownership rule in a second language.
    final status = CardStatus.parse(
      pack.state,
      unlocked: pack.unlocked,
      free: pack.sku == null,
    );

    // A price from Play, already localised for the user's country and currency.
    // Never a number formatted here: "$1.49" is wrong in every market this
    // launcher actually targets.
    final price = ref.watch(productPriceProvider(pack.sku));

    return _Card(
      title: pack.title,
      subtitle: pack.summary.isEmpty ? 'v${pack.version}' : pack.summary,
      active: active,
      progress: progress,
      preview: _PackPreview(theme: theme, packId: pack.packId),
      trailing: switch (status) {
        // "Update app" rather than Get, because the action is on the app and a
        // Get button here would fail in a way the user cannot diagnose.
        CardStatus.requiresAppUpdate => _Mini('Update app', c.textMuted),
        CardStatus.updateAvailable => _Mini('Update', c.accent),
        // The price when Play has answered, a neutral word when it has not.
        // A card that renders nothing at all reads as a card that failed.
        CardStatus.locked => _Mini(price ?? 'Buy', c.accent),
        CardStatus.available => _Mini('Get', c.accent),
        CardStatus.bundled || CardStatus.installed => null,
      },
      onTap: () => onTap(status),
    );
  }
}

/// The pack's own art, exactly as the admin grid composites it at publish.
///
/// The schematic stays as the honest fallback for packs published before
/// previews existed, for a dead network, and for the frame before the image
/// arrives, so a card never shows a broken-image glyph or an empty box.
class _PackPreview extends ConsumerWidget {
  const _PackPreview({required this.theme, required this.packId});

  final EffectiveTheme theme;
  final String packId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = ref.watch(packPreviewUrlProvider(packId)).asData?.value;
    if (url == null) return _Schematic(theme: theme, accent: false);

    final ImageProvider provider = url.startsWith('file://')
        ? FileImage(File(url.substring('file://'.length)))
        : NetworkImage(url);

    return Padding(
      padding: const EdgeInsets.all(10),
      child: Image(
        image: provider,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _Schematic(theme: theme, accent: false),
      ),
    );
  }
}

/// One of theirs, previewed with the pack app's own launcher icon.
class _SystemCard extends ConsumerWidget {
  const _SystemCard({
    required this.theme,
    required this.packageName,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final EffectiveTheme theme;
  final String packageName;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = ref.watch(iconThemeAppProvider(packageName));

    return _Card(
      title: label,
      // The package name, because that is what it is and it is the only way to
      // tell two similarly-named packs apart.
      subtitle: packageName,
      active: active,
      preview: entry == null
          // No launcher activity, so no icon to borrow. The schematic is the
          // honest answer rather than an empty box.
          ? _Schematic(theme: theme, accent: false)
          : Center(child: AppIcon(entry: entry, size: 46)),
      onTap: onTap,
    );
  }
}

/// A neutral stand-in for artwork we cannot show.
///
/// ─── WHY THERE IS NO REAL PREVIEW FOR ONE OF OURS ───────────────────────────
///
/// The signed index carries a title, a summary, a size and a sku. It carries no
/// pixels, which is the same gap the distros grid has with
/// `PreviewLayout.unknown`, and the same fix applies later: an optional preview
/// block on the index entry. Until then this admits it does not know rather
/// than inventing something that will not match what downloads.
///
/// It DOES track the active icon shape, which is real information and free: the
/// tiles are drawn with the same corner treatment the launcher is currently
/// applying, so the schematic at least tells the truth about that.
class _Schematic extends StatelessWidget {
  const _Schematic({required this.theme, required this.accent});

  final EffectiveTheme theme;

  /// Tint one tile with the theme accent. Used on Distro default so the card
  /// that is almost always selected does not look like the emptiest one.
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final c = ChromeScope.of(context).colors;

    // 2x2, because that is the smallest arrangement that reads as "a set of
    // icons" rather than "one icon".
    const tile = 22.0;
    final radius = tile * _shapeFraction(theme);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var row = 0; row < 2; row++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var col = 0; col < 2; col++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Container(
                        width: tile,
                        height: tile,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(radius),
                          color: accent && row == 0 && col == 0
                              ? c.accent
                              : c.line,
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

  /// Corner radius as a fraction of the tile, from the icon shape in force.
  ///
  /// Mirrors `folderCornerRadius`'s mapping without reusing it: that one reads
  /// `prefs.folderShape` first, which is a different setting and would make a
  /// folder preference change the look of an icon-theme card.
  static double _shapeFraction(EffectiveTheme theme) =>
      switch (theme.icons.treatment) {
        IconTreatment.circle => 0.5,
        IconTreatment.square => 0.0,
        IconTreatment.squircle => 0.30,
        // A teardrop has no single radius; a circle is the closest honest
        // approximation and beats a square sitting among teardrops.
        IconTreatment.teardrop => 0.5,
        // `original` keeps each app's own artwork, so there is no shape to
        // match — fall back to the neutral default.
        IconTreatment.original => 0.22,
        IconTreatment.roundedSquare => theme.icons.cornerRadius,
      };
}

/// A short coloured word in a card's trailing slot: Get, Update, a price.
///
/// Text rather than an icon because these mean genuinely different things and a
/// download glyph would collapse them into one, which is the ambiguity the
/// status machine exists to remove.
class _Mini extends StatelessWidget {
  const _Mini(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: d.text.label.copyWith(color: color, fontSize: 11.5),
    );
  }
}

/// A quiet paragraph between sections. Not a card, not a row: it is prose, and
/// dressing it as either would suggest it does something when tapped.
class _Note extends StatelessWidget {
  const _Note({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 6),
      child: Text(text, style: d.text.caption.copyWith(height: 1.45)),
    );
  }
}

/// A caption that starts as one tappable line and expands on demand.
///
/// The store screens had grown paragraphs of standing explanation, which read
/// as clutter to everyone except the one person who needed them. Empty states
/// keep the plain [_Note], because an empty state IS the explanation; this is
/// for prose that accompanies content that already speaks for itself.
class _Disclosure extends StatefulWidget {
  const _Disclosure({required this.title, required this.text});

  final String title;
  final String text;

  @override
  State<_Disclosure> createState() => _DisclosureState();
}

class _DisclosureState extends State<_Disclosure> {
  var _open = false;

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => setState(() => _open = !_open),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _open ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: d.colors.textMuted,
                ),
                const SizedBox(width: 6),
                Text(widget.title, style: d.text.caption),
              ],
            ),
            if (_open)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 22),
                child: Text(
                  widget.text,
                  style: d.text.caption.copyWith(height: 1.45),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
