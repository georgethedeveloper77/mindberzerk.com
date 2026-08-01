import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/home/workspaces/workspace_canvas.dart';

import '../engine/effective_theme.dart';
import '../features/drawer/shell_drawer.dart';
import '../features/drawer/drawer_state.dart';
import '../features/gestures/gesture_layer.dart';
import '../features/home/workspaces/workspace_controller.dart';
import '../system/system_stats.dart';

/// A tiling window manager (Arch + Hyprland, i3). The chrome that says "tiling"
/// is a THIN STATUS BAR at the top, waybar-style: numbered workspaces on the
/// left, the window/mode label in the middle, and status modules (cpu, mem,
/// battery, clock) on the right. No dock, no desktop icons: a tiling WM shows
/// its wallpaper when nothing is open, and launches apps from a keybind. Here
/// the launch keybind is the swipe-right the gesture layer already owns, plus a
/// launcher glyph on the bar; both open the shared app drawer.
class TilingShell extends ConsumerStatefulWidget {
  const TilingShell({super.key, required this.theme});

  final EffectiveTheme theme;

  @override
  ConsumerState<TilingShell> createState() => _TilingShellState();
}

class _TilingShellState extends ConsumerState<TilingShell> {
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

    ref.listen<int>(activeWorkspaceProvider, (_, next) {
      if (!_pages.hasClients) return;
      if ((_pages.page ?? 0).round() == next) return;
      _pages.animateToPage(
        next,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });

    return Stack(
      children: [
        Positioned.fill(
          child: GestureLayer(
            theme: theme,
            child: WorkspaceCanvas(controller: _pages, count: count),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(bottom: false, child: _Waybar(theme: theme)),
        ),
        if (activitiesOpen) Positioned.fill(child: _Launcher(theme: theme)),
      ],
    );
  }
}

class _Waybar extends ConsumerWidget {
  const _Waybar({required this.theme});

  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(workspaceCountProvider);
    final active = ref.watch(activeWorkspaceProvider);
    final now = ref.watch(clockProvider).asData?.value ?? DateTime.now();
    final stats = ref.watch(systemStatsProvider).asData?.value;

    final onDark = theme.palette.onDark;
    final accent = theme.palette.accent;
    // A waybar is mono top to bottom, but WHICH mono is the theme's call — a
    // second tiling distro shipping JetBrains Mono should not have to touch
    // this file.
    final mono = theme.typography.mono;

    // Right-hand modules, waybar order. Each nullable stat hides its own module
    // rather than printing a placeholder, the same rule as the conky.
    final modules = <Widget>[
      if (stats?.cpuPercent != null)
        _Module('cpu', '${stats!.cpuPercent}%', onDark, mono),
      if (stats != null && stats.hasMemory)
        _Module('mem', stats.memLabel, onDark, mono),
      if (stats?.batteryPercent != null)
        _Module('bat', '${stats!.batteryPercent}%', onDark, mono),
      _Module(null, formatTime(now), onDark, mono),
    ];

    return Material(
      color: theme.palette.bar.withValues(alpha: 0.92 * theme.barOpacity),
      child: SizedBox(
        height: 30,
        child: Row(
          children: [
            const SizedBox(width: 6),
            // The launcher keybind, made tappable: rofi/wofi, drawer-shaped.
            GestureDetector(
              onTap: () =>
                  ref.read(activitiesOpenProvider.notifier).state = true,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(Icons.terminal, size: 15, color: accent),
              ),
            ),
            for (var i = 0; i < count; i++)
              GestureDetector(
                onTap: () => ref.read(activeWorkspaceProvider.notifier).goTo(i),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: i == active
                        ? accent.withValues(alpha: 0.9)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      fontFamily: mono,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: i == active
                          ? onDark
                          : onDark.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ),
            const Spacer(),
            Text(
              theme.spec.name,
              style: TextStyle(
                fontFamily: mono,
                fontSize: 11.5,
                color: onDark.withValues(alpha: 0.6),
              ),
            ),
            const Spacer(),
            for (final m in modules) m,
            const SizedBox(width: 10),
          ],
        ),
      ),
    );
  }
}

class _Module extends StatelessWidget {
  const _Module(this.label, this.value, this.onDark, this.mono);

  final String? label;
  final String value;
  final Color onDark;

  /// The theme's mono family. Passed rather than read from a constant so a
  /// tiling distro with its own typeface is still a data change.
  final String? mono;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        label == null ? value : '$label $value',
        style: TextStyle(
          fontFamily: mono,
          fontSize: 11.5,
          color: onDark.withValues(alpha: 0.85),
        ),
      ),
    );
  }
}

/// The launcher popup, opened from the bar glyph or a swipe.
///
/// A back contract and nothing else. [ShellDrawer] resolves this shell to the
/// rofi/wofi launcher, which draws its own scrim, its own centred box and its
/// own tap-outside-to-dismiss. Wrapping it in an opaque background would defeat
/// the point: a tiling launcher FLOATS over the desktop, dimming it rather than
/// replacing it.
class _Launcher extends ConsumerWidget {
  const _Launcher({required this.theme});

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
