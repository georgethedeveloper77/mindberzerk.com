import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g_launcher/platform/launcher_api.g.dart';
import '../features/home/workspaces/workspace_canvas.dart';

import '../../../data/prefs/home_layout.dart';
import '../../../data/repositories/app_repository.dart';
import '../../../data/repositories/shell_apps.dart';
import '../../../data/usage/usage_repository.dart';
import '../../../engine/effective_theme.dart';
import '../../../features/dock/dock_metrics.dart';
import '../../../features/drawer/shell_drawer.dart';
import '../../../features/drawer/app_icon.dart';
import '../../../features/drawer/drawer_state.dart';
import '../../../features/gestures/gesture_layer.dart';
import '../../../features/home/workspaces/workspace_controller.dart';
import '../../../system/system_stats.dart';

/// KDE Plasma 6 (Breeze). The chrome that says "KDE" is a BOTTOM PANEL: a
/// kickoff app launcher on the left, a task strip of pinned/frequent apps, a
/// virtual-desktop pager, a small system tray, and a digital clock on the right.
/// Above it, the desktop is wallpaper (drawn natively) plus the same vertical
/// workspaces the GNOME shell uses. One shell metaphor, painted from the
/// ThemeSpec's palette, so any Breeze-family distro is a data change, not code.
class PlasmaShell extends ConsumerStatefulWidget {
  const PlasmaShell({super.key, required this.theme});

  final EffectiveTheme theme;

  @override
  ConsumerState<PlasmaShell> createState() => _PlasmaShellState();
}

class _PlasmaShellState extends ConsumerState<PlasmaShell> {
  late final PageController _pages =
      PageController(initialPage: ref.read(activeWorkspaceProvider));

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final count = ref.watch(workspaceCountProvider);
    final activitiesOpen = ref.watch(activitiesOpenProvider);

    // The controller follows the workspace controller: a pager tap or a HOME
    // press moves the page too, not just a swipe.
    ref.listen<int>(activeWorkspaceProvider, (_, next) {
      if (!_pages.hasClients) return;
      if ((_pages.page ?? 0).round() == next) return;
      _pages.animateToPage(
        next,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });

    final insets = MediaQuery.viewPaddingOf(context);

    return Stack(
      children: [
        Positioned.fill(
          child: GestureLayer(
            theme: theme,
            child: WorkspaceCanvas(controller: _pages, count: count),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _PlasmaPanel(theme: theme, bottomInset: insets.bottom),
        ),
        if (activitiesOpen) Positioned.fill(child: _Kickoff(theme: theme)),
      ],
    );
  }
}

/// The Breeze panel.
class _PlasmaPanel extends ConsumerWidget {
  const _PlasmaPanel({required this.theme, required this.bottomInset});

  final EffectiveTheme theme;
  final double bottomInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apps = ref.watch(shellAppsProvider(theme));
    final frequent = ref.watch(frequentAppsProvider);
    final byKey = {for (final a in apps) a.componentKey: a};

    // Same source of truth as the GNOME dock: pins, else most-used, else the
    // alphabetical head so the task strip is never empty on first run.
    var keys = HomeLayout.dockKeys(
      theme.prefs,
      frequent: frequent,
      capacity: 8,
      defaultLimit: DockMetrics.defaultCount,
    );
    if (keys.isEmpty) {
      keys = [
        for (final a in apps.take(DockMetrics.defaultCount)) a.componentKey,
      ];
    }
    final taskKeys = [
      for (final k in keys)
        if (byKey[k] != null) k,
    ];

    return Material(
      color: theme.palette.bar.withValues(alpha: 0.96),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SizedBox(
          height: 48,
          child: Row(
            children: [
              _KickoffButton(
                accent: theme.palette.accent,
                onTap: () =>
                    ref.read(activitiesOpenProvider.notifier).state = true,
              ),
              const SizedBox(width: 2),
              Expanded(
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final k in taskKeys)
                      _TaskButton(
                        entry: byKey[k]!,
                        onTap: () {
                          ref.read(appListProvider.notifier).launch(byKey[k]!);
                          ref.read(usageProvider.notifier).record(k);
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              _Pager(theme: theme),
              const SizedBox(width: 10),
              _Tray(theme: theme),
              const SizedBox(width: 10),
              _PanelClock(onDark: theme.palette.onDark),
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _KickoffButton extends StatelessWidget {
  const _KickoffButton({required this.accent, required this.onTap});

  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Center(
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.grid_view_rounded, size: 20, color: accent),
          ),
        ),
      ),
    );
  }
}

class _TaskButton extends StatelessWidget {
  const _TaskButton({required this.entry, required this.onTap});

  final AppEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Center(child: AppIcon(entry: entry, size: 30)),
      ),
    );
  }
}

/// KDE's virtual-desktop pager applet, in the panel: numbered squares, the
/// active one filled with the accent.
class _Pager extends ConsumerWidget {
  const _Pager({required this.theme});

  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(workspaceCountProvider);
    final active = ref.watch(activeWorkspaceProvider);
    final onDark = theme.palette.onDark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          GestureDetector(
            onTap: () => ref.read(activeWorkspaceProvider.notifier).goTo(i),
            child: Container(
              width: 16,
              height: 16,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: i == active
                    ? theme.palette.accent.withValues(alpha: 0.9)
                    : Colors.transparent,
                border: Border.all(color: onDark.withValues(alpha: 0.35)),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                '${i + 1}',
                style: TextStyle(
                  fontFamily: theme.typography.mono,
                  fontSize: 9,
                  color: i == active
                      ? onDark
                      : onDark.withValues(alpha: 0.7),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// A small tray: wifi, volume, and battery when it can be read. Nullable stats
/// hide their glyph rather than showing a placeholder.
class _Tray extends ConsumerWidget {
  const _Tray({required this.theme});

  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final battery = ref.watch(systemStatsProvider).asData?.value.batteryPercent;
    final c = theme.palette.onDark.withValues(alpha: 0.75);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.wifi, size: 15, color: c),
        const SizedBox(width: 8),
        Icon(Icons.volume_up_outlined, size: 15, color: c),
        if (battery != null) ...[
          const SizedBox(width: 8),
          Icon(Icons.battery_std, size: 15, color: c),
          const SizedBox(width: 2),
          Text(
            '$battery%',
            style: TextStyle(
              fontFamily: theme.typography.mono,
              fontSize: 11,
              color: c,
            ),
          ),
        ],
      ],
    );
  }
}

class _PanelClock extends ConsumerWidget {
  const _PanelClock({required this.onDark});

  final Color onDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider).asData?.value ?? DateTime.now();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          formatTime(now),
          style: TextStyle(
            color: onDark,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1.0,
          ),
        ),
        Text(
          formatDateShort(now),
          style: TextStyle(
            color: onDark.withValues(alpha: 0.7),
            fontSize: 9.5,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

/// Kickoff, opened from the panel button.
///
/// A back contract and nothing else: [ShellDrawer] resolves this shell to the
/// Kickoff presentation (rail + list + system footer), and that widget paints
/// its own solid panel-attached surface. No wrapper background and no back
/// arrow — KDE closes Kickoff by pressing the launcher again or clicking away,
/// and Android's back gesture stands in for that here.
class _Kickoff extends ConsumerWidget {
  const _Kickoff({required this.theme});

  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          ref.read(activitiesOpenProvider.notifier).state = false;
        }
      },
      child: ShellDrawer(theme: theme),
    );
  }
}
