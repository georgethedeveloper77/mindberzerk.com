import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'safe_page.dart';
import '../features/home/workspaces/workspace_canvas.dart';

import '../engine/effective_theme.dart';
// PanelSpec, PanelModule and TopBarSide: the bar is built from the distro's
// authored panel now, not from a list in this file.
import '../engine/theme_spec.dart';
import '../features/drawer/shell_drawer.dart';
import '../features/drawer/drawer_state.dart';
import '../features/gestures/gesture_layer.dart';
import '../features/home/desktop_hold.dart';
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
      // `pageOrNull`, not `hasClients` plus `page`. That pair reads as a guard
      // and is not one: `hasClients` is `positions.isNotEmpty`, so it passes
      // with TWO pagers attached and `page` then throws `Too many elements`
      // out of `positions.single`. See `safe_page.dart`.
      //
      // Null means the pager cannot be read this frame, and `animateToPage`
      // would fail on exactly the same getter, so there is nothing to do but
      // return. `activeWorkspaceProvider` stays the source of truth and the
      // pager catches up on the next change.
      final current = _pages.pageOrNull;
      if (current == null) return;
      if (current.round() == next) return;
      _pages.animateToPage(
        next,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });

    return Stack(
      children: [
        // ─── THE BAR IS A SIBLING OF THE WORKSPACE, NOT A LID ON IT ───────
        //
        // Same change, same reason, as the Plasma panel: the workspace used to
        // draw nothing, so a bar floating over a filled canvas cost nothing.
        // Now that desklets render here, a tile in the top row would sit under
        // the waybar, placed and saved and unreadable.
        Column(
          children: [
            SafeArea(bottom: false, child: _Waybar(theme: theme)),
            Expanded(
              // removeTop, because the SafeArea above has already consumed the
              // status-bar inset for the bar. The desklet surface reads the
              // window's view padding directly, so without this it adds a
              // second status-bar gutter below a bar that is already clear of
              // it, and every top-row tile sits a status bar too low.
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: GestureLayer(
                  theme: theme,
                  // Same gap as Plasma had: no long press at all, so the
                  // desktop menu was unreachable from this shell. A tiling WM
                  // has no dock and no desktop icons, which makes the hold the
                  // ONLY pointer route to wallpaper and themes here.
                  child: DesktopHold(
                    theme: theme,
                    child: WorkspaceCanvas(
                      theme: theme,
                      controller: _pages,
                      count: count,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        // ShellDrawer directly; `_Launcher` was a back contract and nothing
        // else, and that contract moved to home_screen. The rofi-shaped
        // presentation comes from ShellDrawer, not from the wrapper.
        if (activitiesOpen) Positioned.fill(child: ShellDrawer(theme: theme)),
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

    // ─── THE DISTRO'S OWN BAR, OR THE ONE EVERY TILING DISTRO SHARED ────
    //
    // These four modules were a hardcoded list, which made `PanelModule`'s
    // ten-value vocabulary a thing gnome and plasma could author and tiling
    // could not. Two tiling distros therefore had the identical status bar
    // whatever their theme.json said, and a waybar is the one piece of chrome
    // its author definitely did configure: that is what waybar IS.
    //
    // An authored TOP panel supplies the modules in order. A distro that
    // authors none keeps exactly the bar it had, which is what the fallback
    // below is and why no tiling distro shipping today moves.
    PanelSpec? authored;
    for (final p in theme.panels) {
      if (p.side == TopBarSide.top) {
        authored = p;
        break;
      }
    }

    // ONE builder for both paths, so the fallback cannot drift from the
    // authored bar the way two literal lists would.
    Widget? build(PanelModule m) => switch (m) {
          // The launcher keybind, made tappable: rofi/wofi, drawer-shaped.
          PanelModule.activities => GestureDetector(
              onTap: () => openApps(ref),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(Icons.terminal, size: 15, color: accent),
              ),
            ),
          PanelModule.pager => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < count; i++)
                  _Workspace(
                    index: i,
                    active: active,
                    accent: accent,
                    onDark: onDark,
                    mono: mono,
                    onTap: () =>
                        ref.read(activeWorkspaceProvider.notifier).goTo(i),
                  ),
              ],
            ),
          PanelModule.spacer => const Spacer(),
          // Each nullable stat hides its own module rather than printing a
          // placeholder, the same rule as the conky. A hidden module returns
          // null and is dropped, so an authored bar does not carry a gap where
          // a reading was unavailable.
          PanelModule.network => stats?.cpuPercent == null
              ? null
              : _Module('cpu', '${stats!.cpuPercent}%', onDark, mono),
          PanelModule.memory => (stats != null && stats.hasMemory)
              ? _Module('mem', stats.memLabel, onDark, mono)
              : null,
          PanelModule.storage => stats?.batteryPercent == null
              ? null
              : _Module('bat', '${stats!.batteryPercent}%', onDark, mono),
          PanelModule.clock => _Module(null, formatTime(now), onDark, mono),
          // A waybar has no application menu, no window-button strip and no
          // system tray, and inventing one would put a Plasma affordance on a
          // desktop that has never had it. Authored, they are dropped rather
          // than fatal, the same contract PanelModule.parse keeps.
          PanelModule.kickoff ||
          PanelModule.tasks ||
          PanelModule.tray =>
            null,
        };

    // `whereType<Widget>()`, not a null-aware element: a module that has no
    // reading to show returns null and is dropped, and this is the spelling the
    // rest of the tree uses for exactly that.
    List<Widget> emit(List<PanelModule> modules) =>
        modules.map(build).whereType<Widget>().toList();

    final children = <Widget>[
      const SizedBox(width: 6),
      if (authored != null)
        ...emit(authored.modules)
      else ...[
        ...emit(const [PanelModule.activities, PanelModule.pager]),
        const Spacer(),
        // The distro's name, centred. Only on the fallback bar: a waybar's
        // middle is the focused window's title, and an authored panel that
        // wanted a label there would need a module for it rather than getting
        // one it never asked for.
        Text(
          theme.spec.name,
          style: TextStyle(
            fontFamily: mono,
            fontSize: 11.5,
            color: onDark.withValues(alpha: 0.6),
          ),
        ),
        const Spacer(),
        ...emit(const [
          PanelModule.network,
          PanelModule.memory,
          PanelModule.storage,
          PanelModule.clock,
        ]),
      ],
      const SizedBox(width: 10),
    ];

    return Material(
      color: theme.palette.bar.withValues(alpha: 0.92 * theme.barOpacity),
      child: SizedBox(
        // The distro's height when it authored one, else the 30 this bar has
        // always been. Same resolution `panelHeight` gets on Plasma.
        height: authored?.height ?? 30,
        child: Row(children: children),
      ),
    );
  }
}

/// One numbered workspace square.
///
/// Lifted out of the bar's build so the pager module is one widget rather than
/// a loop spliced into a children list, which is what let the modules become
/// data at all.
class _Workspace extends StatelessWidget {
  const _Workspace({
    required this.index,
    required this.active,
    required this.accent,
    required this.onDark,
    required this.mono,
    required this.onTap,
  });

  final int index;
  final int active;
  final Color accent;
  final Color onDark;
  final String? mono;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final on = index == active;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 1),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: on ? accent.withValues(alpha: 0.9) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '${index + 1}',
          style: TextStyle(
            fontFamily: mono,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: on ? onDark : onDark.withValues(alpha: 0.7),
          ),
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