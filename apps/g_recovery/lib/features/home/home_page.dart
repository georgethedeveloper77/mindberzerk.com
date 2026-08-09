import 'package:device_probe/device_probe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/shell.dart';
import '../../app/theme/tokens.dart';
import '../../bridge/recovery_api.g.dart';
import '../../core/format.dart';
import '../../ui/g_app_bar.dart';
import '../../ui/g_badge.dart';
import '../../ui/g_button.dart';
import '../../ui/g_card.dart';
import '../../ui/g_logo_mark.dart';
import '../../ui/g_info_note.dart';
import '../../ui/g_search_field.dart';
import '../../ui/g_stat.dart';
import '../device/state/device_providers.dart';
import '../device/device_format.dart';
import '../recovery/state/recovery_providers.dart';
import '../learn/state/learn_model.dart';
import '../search/search_page.dart';
import 'widgets/category_grid.dart';
import 'widgets/hero_card.dart';

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
    return GPageBody(
      children: <Widget>[
        GAppBar(
          title: 'This device',
          subtitle: _greeting(DateTime.now()),
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

        const CategoryGrid(),
        const SizedBox(height: GSpace.md - 1),

        const _AccessPrompt(),
        const _DeviceStrip(),

        const SizedBox(height: GSpace.lg),
        GInfoNote(
          text: 'Why some files cannot be recovered',
          chapterId: LearnIds.theTrash,
        ),
      ],
    );
  }

  String _greeting(DateTime now) {
    if (now.hour < 12) return 'Good morning';
    if (now.hour < 18) return 'Good afternoon';
    return 'Good evening';
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

/// Live battery, memory and temperature, from the same probe the Device tab
/// uses.
///
/// The sampler is paused unless the Device tab is showing, so these are the
/// values from the last time it ran rather than a fresh read. That is the right
/// trade: polling sysfs at 2 Hz to decorate a screen about deleted files is
/// exactly the battery drain a device utility has no excuse for.
class _DeviceStrip extends ConsumerWidget {
  const _DeviceStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;
    final ProbeTick? tick = ref.watch(deviceTickProvider).value;
    if (tick == null) return const SizedBox.shrink();

    final BatterySnapshot? battery = tick.current.battery;
    final MemorySnapshot? memory = tick.current.memory;

    // Every value is nullable and GStat renders nothing for a null, so a device
    // that serves two of these four shows two columns rather than four with
    // dashes in them.
    final String? percent =
        battery?.percent == null ? null : '${battery!.percent}%';

    return GCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Device',
                  style: GType.heading.copyWith(color: t.text),
                ),
              ),
              GBadge.live('Live'),
            ],
          ),
          const SizedBox(height: GSpace.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              GStat(label: 'Battery', value: percent),
              GStat(
                label: 'Free memory',
                value: GFormat.bytesOrNull(memory?.availBytes),
              ),
              GStat(
                label: 'Temp',
                value: DeviceFormat.celsiusFromDeci(battery?.tempDeciC),
              ),
              GStat(
                label: 'Swap',
                value: GFormat.bytesOrNull(memory?.swapTotalBytes),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
