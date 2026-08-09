import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/shell.dart';
import '../../app/theme/accent.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/theme_controller.dart';
import '../../app/theme/tokens.dart';
import '../../core/messenger/g_message.dart';
import '../../core/messenger/g_messenger.dart';
import '../../ui/g_app_bar.dart';
import '../../ui/g_card.dart';
import '../../ui/g_chip.dart';
import '../../bridge/content_api.g.dart';
import '../../core/content/content_store.dart';
import '../../ui/g_badge.dart';
import '../../ui/g_stat.dart';
import '../onboarding/state/onboarding_providers.dart';
import '../learn/learn_page.dart';
import '../placeholder_panel.dart';

class MorePage extends ConsumerWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GPageBody(
      children: <Widget>[
        GestureDetector(
          // Long press resets first run, so onboarding can be re-tested without
          // reinstalling. Debug affordance, removed before 1.0 ships.
          onLongPress: () => ref.read(onboardingDoneProvider.notifier).reset(),
          child: GAppBar(title: 'More'),
        ),
        GOverline('Appearance'),
        const SizedBox(height: GSpace.sm + 1),
        const AppearanceCard(),
        const SizedBox(height: GSpace.lg),
        GOverline('Learn'),
        const SizedBox(height: GSpace.sm + 1),
        GCard(
          onTap: () => Navigator.of(context).push(LearnPage.route()),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'How Android storage works',
                      style: GType.heading.copyWith(color: context.g.text),
                    ),
                    Text(
                      'Seven chapters on where files live and what deleting does',
                      style: GType.micro.copyWith(color: context.g.muted),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: context.g.dim,
                size: 20,
              ),
            ],
          ),
        ),
        const SizedBox(height: GSpace.lg),
        GOverline('Content'),
        const SizedBox(height: GSpace.sm + 1),
        const ContentCard(),
        const SizedBox(height: GSpace.lg),
        GOverline('Coming next'),
        const SizedBox(height: GSpace.sm + 1),
        PlaceholderPanel(
          phase: 'Phase 9',
          title: 'Pro',
          detail:
              'One time unlock. No subscription, no ads, no account. Covers '
              'compression, PDF export, and scheduled backups.',
        ),
      ],
    );
  }
}

/// Theme mode and accent. This is the permanent home for both controls, and it
/// is the same controller the onboarding picker will drive in Phase 4.
class AppearanceCard extends ConsumerWidget {
  const AppearanceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;
    final GThemeState theme = ref.watch(gThemeProvider);
    final GThemeController controller = ref.read(gThemeProvider.notifier);

    return GCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Theme', style: GType.heading.copyWith(color: t.text)),
          const SizedBox(height: GSpace.md),
          Row(
            children: <Widget>[
              for (final ThemeMode mode in ThemeMode.values)
                Padding(
                  padding: const EdgeInsets.only(right: GSpace.sm),
                  child: GChip(
                    label: _modeLabel(mode),
                    selected: theme.mode == mode,
                    onTap: () => controller.setMode(mode),
                  ),
                ),
            ],
          ),
          const GCardDivider(),
          Text('Accent', style: GType.heading.copyWith(color: t.text)),
          const SizedBox(height: GSpace.md),
          Row(
            children: <Widget>[
              for (final GAccent accent in gAccentOrder)
                Expanded(
                  child: _AccentSwatch(
                    accent: accent,
                    selected: theme.accent == accent,
                    onTap: () {
                      controller.setAccent(accent);
                      GMessenger.show(
                        context,
                        GMessage.success('Accent set to ${accent.label}'),
                      );
                    },
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static String _modeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'Auto';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
    }
  }
}

class _AccentSwatch extends StatelessWidget {
  const _AccentSwatch({
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final GAccent accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    return Semantics(
      label: accent.label,
      selected: selected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: AnimatedContainer(
            duration: GMotion.fast,
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.base,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? t.text : const Color(0x00000000),
                width: 2,
              ),
            ),
            child: selected
                ? Icon(Icons.check_rounded, size: 18, color: t.onAccent)
                : null,
          ),
        ),
      ),
    );
  }
}

/// What content is installed, and a way to force a check.
///
/// Visible on purpose. The pipeline's whole value is that coverage improves
/// without a release, and a user who reports "it still misses my Tecno's
/// recycle bin" needs to be able to say which registry version they have.
class ContentCard extends ConsumerWidget {
  const ContentCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;
    final List<ContentPackInfo> packs =
        ref.watch(installedPacksProvider).value ?? const <ContentPackInfo>[];
    final ContentSyncResult? sync = ref.watch(contentSyncProvider).value;

    return GCard(
      onTap: () {
        ref.invalidate(contentSyncProvider);
        ref.invalidate(installedPacksProvider);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Recovery coverage',
                  style: GType.heading.copyWith(color: t.text),
                ),
              ),
              if (sync != null) _statusBadge(sync.status),
            ],
          ),
          const SizedBox(height: GSpace.sm - 2),
          Text(
            packs.isEmpty
                // Not a failure. It is what every phone shows until the first
                // successful sync, and the app works exactly the same either
                // way.
                ? 'Using the copy built into this version. Tap to check for '
                    'updates.'
                : 'Updated without needing a new app version. Tap to check '
                    'again.',
            style: GType.bodySmall.copyWith(color: t.muted),
          ),
          if (packs.isNotEmpty) ...<Widget>[
            const GCardDivider(),
            for (final ContentPackInfo pack in packs)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        pack.packId,
                        style: GType.bodySmall.copyWith(color: t.muted),
                      ),
                    ),
                    Text(
                      'v${pack.installedVersion}',
                      style: GType.monoSmall.copyWith(color: t.text),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    switch (status) {
      case 'updated':
        return GBadge.full('Updated');
      case 'upToDate':
        return GBadge.full('Current');
      case 'offline':
        // Offline is ORDINARY, not an error. A phone in a lift, or a first
        // launch on aeroplane mode, and the app is entirely fine.
        return GBadge(label: 'Offline');
      case 'rejected':
        return GBadge.partial('Rejected');
      default:
        return GBadge.partial('Retry');
    }
  }
}
