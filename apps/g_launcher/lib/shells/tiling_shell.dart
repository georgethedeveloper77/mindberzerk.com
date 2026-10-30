import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/window_chrome.dart';
import '../engine/effective_theme.dart';
// PanelSpec, PanelModule and TopBarSide: the bar is built from the distro's
// authored panel now, not from a list in this file.
import '../engine/theme_spec.dart';
import '../features/drawer/drawer_state.dart';
import '../features/drawer/shell_drawer.dart';
import '../features/gestures/gesture_layer.dart';
import '../features/home/desktop_hold.dart';
import '../features/home/workspaces/workspace_canvas.dart';
import '../features/home/workspaces/workspace_controller.dart';
import '../features/panel/applets/panel_tray_button.dart';
import '../features/panel/modules/panel_title_module.dart';
import '../features/panel/panel_modules.dart'
    show panelIsNarrow, wideOnlyModules;
import '../system/system_stats.dart';
import 'safe_page.dart';

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
            if (!_barAtBottom(theme))
              SafeArea(bottom: false, child: _Waybar(theme: theme))
            else
              // The status bar's inset still has to be cleared at the top
              // when the bar has moved to the bottom.
              SizedBox(height: MediaQuery.viewPaddingOf(context).top),
            Expanded(
              // removeTop, because the SafeArea above has already consumed the
              // status-bar inset for the bar. The desklet surface reads the
              // window's view padding directly, so without this it adds a
              // second status-bar gutter below a bar that is already clear of
              // it, and every top-row tile sits a status bar too low.
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                // The bottom bar has cleared the gesture inset already.
                removeBottom: _barAtBottom(theme),
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
            // ─── i3bar SITS AT THE BOTTOM ───────────────────────────────
            //
            // i3's default, and where a thumb is. An authored bottom panel
            // puts the bar here; the gesture inset is painted in the bar's
            // colour by the bar itself, so it reads as one strip.
            if (_barAtBottom(theme)) _Waybar(theme: theme, atBottom: true),
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

/// Whether this distro authored its tiling bar on the bottom edge.
bool _barAtBottom(EffectiveTheme theme) =>
    !theme.panels.any((p) => p.side == TopBarSide.top) &&
    theme.panels.any((p) => p.side == TopBarSide.bottom);

class _Waybar extends ConsumerWidget {
  const _Waybar({required this.theme, this.atBottom = false});

  final EffectiveTheme theme;

  /// Drawn along the bottom edge, i3bar's default.
  final bool atBottom;

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
    final edge = atBottom ? TopBarSide.bottom : TopBarSide.top;
    for (final p in theme.panels) {
      if (p.side == edge) {
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
              // A thumb's target, not a mouse's: the glyph at 20dp inside the
              // bar's full height and 44dp of width.
              child: SizedBox(
                width: 44,
                child: Center(
                  child: Icon(Icons.terminal, size: 20, color: accent),
                ),
              ),
            ),
          PanelModule.pager => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < count; i++)
                  _Workspace(
                    index: i,
                    active: active,
                    square: theme.barEdge,
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
          // ─── EACH MODULE NOW SHOWS WHAT ITS NAME SAYS ─────────────────
          //
          // `network` printed CPU and `storage` printed a BATTERY percentage
          // here, and nowhere else. Four shells meant one thing by those two
          // words and this shell meant another, with no error and nothing on
          // screen to say so.
          //
          // The cost was not cosmetic. EndeavourOS authored `storage` on its
          // bar, so it drew a battery number beside Android's own battery
          // icon, and neither the CDN audit nor the Settings switches could
          // see it: both look for a module called `battery`. A vocabulary that
          // means something different on one shell is a trap for the next
          // person who authors a waybar, and the audit that cannot read it is
          // the proof.
          //
          // CPU KEEPS A HOME. `cpu` is genuinely the readout a waybar leads
          // with, and there is no module for it, so it rides on `activities`
          // below rather than being deleted. A module for it is a Pigeon-free
          // spec change and belongs in its own pass.
          // `↓ 4.2M ↑ 0.8M`, the same two figures and the same formatter the
          // conky and the GNOME readouts use, so one reading cannot be
          // rendered two ways on two shells.
          PanelModule.network => stats?.hasNet == true
              ? _Module(
                  'net',
                  '↓${SystemStats.rate(stats!.netDownBytesPerSec)} '
                      '↑${SystemStats.rate(stats.netUpBytesPerSec)}',
                  onDark,
                  mono,
                )
              : null,
          PanelModule.memory => (stats != null && stats.hasMemory)
              ? _Module('mem', stats.memLabel, onDark, mono)
              : null,
          PanelModule.storage => stats?.hasStorage == true
              ? _Module(
                  'disk',
                  SystemStats.bytes(
                    stats!.storageTotalBytes! - stats.storageUsedBytes!,
                  ),
                  onDark,
                  mono,
                )
              : null,
          PanelModule.battery => stats?.batteryPercent == null
              ? null
              : _Module('bat', '${stats!.batteryPercent}%', onDark, mono),
          PanelModule.clock => _Module(null, formatTime(now), onDark, mono),
          // The one door into quick settings on a desktop with no tray. A
          // waybar's right end is where its own tray and notifications sit.
          PanelModule.tray => PanelTrayButton(
              palette: theme.palette,
              stacked: false,
              compact: true,
            ),
          // The focused window's title is the middle of every waybar; on a
          // phone it names where you are.
          // Flexible, so a long name shortens instead of pushing the bar's
          // right end off the screen.
          PanelModule.title => Flexible(
              child: PanelTitleModule(theme: theme, vertical: false),
            ),
          // A waybar has no application menu, no window-button strip and no
          // system tray, and inventing one would put a Plasma affordance on a
          // desktop that has never had it. Authored, they are dropped rather
          // than fatal, the same contract PanelModule.parse keeps.
          PanelModule.kickoff ||
          PanelModule.tasks ||
          // `battery` draws now, as text in the readout run, which is what a
          // waybar does with it. `wifi` and `volume` stay dropped: those are
          // tappable Plasma chips, and an app button on a tiling bar is one
          // too, because this desktop launches from a keybind.
          PanelModule.wifi ||
          PanelModule.volume ||
          PanelModule.workspacesButton ||
          PanelModule.appsButton ||
          // A tiling WM is always tiled; a toggle here would offer to stop.
          PanelModule.tiling ||
          PanelModule.app =>
            null,
        };

    // `whereType<Widget>()`, not a null-aware element: a module that has no
    // reading to show returns null and is dropped, and this is the spelling the
    // rest of the tree uses for exactly that.
    //
    // ─── THE STATUS RULE, HERE TOO ────────────────────────────────────────
    //
    // The clock and the battery leave the bar while Android's status bar is
    // showing, as on every other shell: the same row twice is not a rice.
    // "Status icons on the panel" brings them back and hides Android's.
    //
    // ─── AND THE UPRIGHT RULE ─────────────────────────────────────────────
    //
    // The same rule every other panel follows (`panelItemsShown`): on a phone
    // held upright the readouts and the workspace pills leave the bar, and
    // quick settings carries them instead. Sideways or on a tablet the bar
    // draws everything the distro authored.
    final narrow = panelIsNarrow(context);
    bool shown(PanelModule m) =>
        !(narrow && wideOnlyModules.contains(m)) &&
        (!theme.statusBar ||
            (m != PanelModule.clock && m != PanelModule.battery));
    //
    // ─── ONE TRAY, WHATEVER THE EDGE ─────────────────────────────────────
    //
    // Off the top edge `PanelItem.parseAll` expands `tray` into wifi, volume
    // and battery, which a waybar declines as chips. On a bottom i3bar that
    // left no way into quick settings at all. The first of wifi or volume is
    // therefore the tray button and the other is dropped; battery stays a
    // readout under the status rule.
    List<Widget> emit(List<PanelModule> modules) {
      var trayDone = false;
      final out = <Widget>[];
      for (final m in modules.where(shown)) {
        if (m == PanelModule.wifi || m == PanelModule.volume) {
          if (trayDone) continue;
          trayDone = true;
          final w = build(PanelModule.tray);
          if (w != null) out.add(w);
          continue;
        }
        if (m == PanelModule.tray) trayDone = true;
        final w = build(m);
        if (w != null) out.add(w);
      }
      return out;
    }

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

    // ─── A WAYBAR FLOATS ──────────────────────────────────────────────────
    //
    // Today's waybar sits inset from the screen's edges with rounded ends,
    // the same gap the tiled windows below it keep, so the bar reads as one
    // more window rather than as a strip glued to the status bar. Every tiling
    // distro gets it: an edge-to-edge bar is how these desktops looked years
    // ago, and the people who buy them screenshot what they run now.
    final color =
        theme.palette.bar.withValues(alpha: 0.92 * theme.barOpacity);
    final height = authored?.height ?? 34;

    // ─── OR RUNS EDGE TO EDGE, AS i3bar DOES ──────────────────────────────
    //
    // `barStyle: "edge"`: square, full width, no inset. At the bottom it
    // also fills the gesture inset beneath it in its own colour, so the bar
    // and the strip under it read as one, the way a real i3bar meets the
    // bottom of the screen.
    if (theme.barEdge) {
      return ColoredBox(
        color: color,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: atBottom ? MediaQuery.viewPaddingOf(context).bottom : 0,
          ),
          child: SizedBox(height: height, child: Row(children: children)),
        ),
      );
    }

    final radius = theme.spec.surfaces?.radius ?? 10;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        windowGap,
        windowGap / 2,
        windowGap,
        windowGap / 2 +
            (atBottom ? MediaQuery.viewPaddingOf(context).bottom : 0),
      ),
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          // The distro's height when it authored one, else 34: tall enough
          // for a workspace pill a thumb can hit.
          height: height,
          child: Row(children: children),
        ),
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
    this.square = false,
  });

  /// i3's square, bordered workspace button instead of Hyprland's pill.
  final bool square;

  final int index;
  final int active;
  final Color accent;
  final Color onDark;
  final String? mono;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final on = index == active;

    // A Hyprland-style pill: the active workspace is wider and filled, the
    // rest are bare numbers. The tap target is the bar's full height.
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
        width: square ? 30 : (on ? 34 : 24),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? accent.withValues(alpha: 0.95) : Colors.transparent,
          borderRadius: BorderRadius.circular(square ? 0 : 8),
          border: square
              ? Border.all(
                  color: on ? accent : onDark.withValues(alpha: 0.25),
                )
              : null,
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
