import 'package:device_probe/device_probe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/shell.dart';
import '../../app/theme/tokens.dart';
import '../../bridge/recovery_api.g.dart';
import '../../ui/g_app_bar.dart';
import '../../ui/g_button.dart';
import '../../ui/g_card.dart';
import '../../ui/g_logo_mark.dart';
import '../../ui/g_search_field.dart';
// GOverline lives here alongside GStat.
import '../../ui/g_stat.dart';
import '../device/state/identity_providers.dart';
import '../recovery/state/recovery_providers.dart';
import '../search/search_page.dart';
import 'widgets/attention_strip.dart';
import 'widgets/category_grid.dart';
import 'widgets/hero_card.dart';
import 'widgets/home_extras.dart';

/// The real home screen. Replaces the Phase 1 design system gallery.
///
/// Order is deliberate: search, then the one big number, then six tiles, then
/// live device stats. Search is at the top because the most common thing a
/// person knows about a lost file is its name, and burying that in a menu is
/// what every app in this category does.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DeviceIdentity? identity = ref.watch(deviceIdentityProvider).value;

    return GPageBody(
      children: <Widget>[
        // ─── THE PHONE NAMES ITSELF ─────────────────────────────────────────
        //
        // It said "This device" over a greeting. A recovery app is about THIS
        // handset and what it is holding, and the time of day is something the
        // user already knew.
        //
        // deviceTitle and deviceCaption were written for exactly this, and
        // their own header says so. Nothing had ever called them.
        GAppBar(
          title: deviceTitle(identity),
          subtitle: deviceCaption(identity),
          leading: const GLogoMark(),
          actions: <Widget>[
            GIconButton(
              icon: Icons.refresh_rounded,
              onTap: () => ref.invalidate(prescanProvider),
            ),
          ],
        ),

        GSearchField(
          hint: 'Search files, photos, messages',
          leading: '/',
          onTap: () => Navigator.of(context).push(SearchPage.route()),
        ),
        const SizedBox(height: GSpace.md - 1),

        const HeroCard(),
        const SizedBox(height: GSpace.md - 1),

        const _AccessPrompt(),

        // Only what is currently true, expiring first, and nothing at all when
        // nothing is. It never starts a scan to fill itself in.
        const AttentionStrip(),

        GOverline('What can come back'),
        const SizedBox(height: GSpace.sm + 1),
        const CategoryGrid(),

        // ─── TWO SECTIONS, TWO VERBS ────────────────────────────────────────
        //
        // The mosaic answers what has been deleted and can be restored. This
        // answers what is still here and could take less room. A seventh tile
        // inside the grid would make the grid mean two things and would be the
        // only tile whose tap does not open a list of deleted files.
        const SizedBox(height: GSpace.lg),
        GOverline('Make room without deleting'),
        const SizedBox(height: GSpace.sm + 1),
        const CompressRow(),

        const SizedBox(height: GSpace.sm),
        const PillarStats(),

        // ─── THE LEARN LINK IS GONE, AND THAT IS NOT AN OVERSIGHT ───────────
        //
        // GInfoNote was deleted when Learn moved under Browse files, so this
        // row now points at a file that does not exist. Restoring it would mean
        // restoring the widget too, for a link to a chapter that already has a
        // home of its own.
        //
        // The one thing it did that nothing else does is admit, on the main
        // screen, that some files cannot be recovered. That belongs back here
        // eventually, and it belongs as a sentence rather than as a link.
      ],
    );
  }

}

/// Shown only while the permission is missing.
///
/// Not a permanent banner. Once the grant lands this disappears entirely rather
/// than turning into a green "all good" row that occupies space forever.
class _AccessPrompt extends ConsumerWidget {
  const _AccessPrompt();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;
    final RecoveryAccess? access = ref.watch(recoveryAccessProvider).value;
    if (access == null || access.allFilesAccess) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: GSpace.md - 1),
      child: GCard(
        tint: t.warning,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Turn on file access',
              style: GType.heading.copyWith(color: t.text),
            ),
            const SizedBox(height: GSpace.sm - 2),
            Text(
              'Android hides other apps deleted files until you do. Every count '
              'above is a floor until then.',
              style: GType.bodySmall.copyWith(color: t.muted),
            ),
            const SizedBox(height: GSpace.md),
            GButton(
              label: 'Open settings',
              onPressed: () async {
                await ref.read(recoveryBridgeProvider).requestAllFilesAccess();
                ref.invalidate(recoveryAccessProvider);
                ref.invalidate(prescanProvider);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─── _DeviceStrip IS GONE ────────────────────────────────────────────────────
//
// Battery, free memory, temperature and swap sat at the bottom of a screen
// about deleted files: four numbers nobody came for, from a sampler that is
// paused unless the Device tab is showing, so they were usually stale as well.
//
// PillarStats replaces it with three that point somewhere instead of trying to
// be the somewhere.
