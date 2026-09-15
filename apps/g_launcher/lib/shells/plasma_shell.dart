import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/prefs/home_layout.dart';
import '../../../data/repositories/shell_apps.dart';
import '../../../data/usage/usage_repository.dart';
import '../../../engine/effective_theme.dart';
import '../../../engine/theme_spec.dart' show TopBarSide;
import '../../../features/dock/aqua_dock_metrics.dart';
import '../../../features/drawer/app_icon.dart';
import '../../../features/drawer/drawer_actions.dart';
import '../../../features/drawer/drawer_state.dart';
import '../../../features/drawer/shell_drawer.dart';
import '../../../features/gestures/gesture_layer.dart';
import '../../../features/home/aqua/aqua_dock.dart';
import '../../../features/home/desktop_hold.dart';
// `DockEntry` is declared in gnome_dock, not aqua_dock: the entry is the shared
// shape and only the SHELL of a dock differs, which is why both docks take it.
import '../../../features/home/gnome/gnome_dock.dart' show DockEntry;
import '../../../features/home/workspaces/workspace_controller.dart';
import '../../../features/panel/panel_bar.dart';
import '../../../features/panel/panel_skin.dart';
import '../features/home/workspaces/workspace_canvas.dart';
import 'safe_page.dart';

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

    final insets = MediaQuery.viewPaddingOf(context);

    final side = theme.panelSide;

    // ONE instance, placed in one of four slots below. Built here so the four
    // `if`s stay one line each and cannot drift apart.
    // ─── KEYED, BECAUSE THE EDGE CONTROL MOVES IT BETWEEN SLOTS ──────────
    //
    // The panel appears in one of four slots and the workspace is always the
    // Column's Expanded. Changing the edge changes the Column's CHILD LIST:
    // [panel, Expanded] on top becomes [Expanded, panel] on bottom, and
    // [Expanded] when the panel moves into the Row. Unkeyed, the child at index
    // 0 changes type, so Flutter unmounts that subtree and builds a new one,
    // and for one frame the old PageView and the new one are both attached to
    // `_pages`. `PageController.page` asserts on exactly that, which is the
    // crash every edge change produced.
    //
    // With keys the elements are MATCHED across the reorder and the workspace
    // subtree, its PageView included, is reused rather than rebuilt.
    final panel = KeyedSubtree(
      key: const ValueKey('plasma.panel'),
      child: PanelBar(theme: theme, insets: insets),
    );

    return Stack(
      children: [
        // ─── THE PANEL IS A SIBLING OF THE WORKSPACE, NOT A LID ON IT ─────
        //
        // This was a `Positioned.fill` canvas with the panel floating over its
        // bottom edge, which was correct for exactly as long as the workspace
        // drew nothing. It draws desklets now, and a desktop that lays a tile
        // out across its full height puts the bottom row underneath an opaque
        // panel: the widget is placed, saved, and invisible.
        //
        // DeskletSurfaceView's own doc already states the contract this now
        // keeps ("panels are siblings of the workspace and take their own
        // space out of it"), and gnome_shell has been built this way since it
        // gained desklets. Plasma was the shell that never got the change,
        // which is why its panel and its desklets disagreed about how tall the
        // desktop is.
        // ─── COLUMN FOR THE HORIZONTAL EDGES, ROW INSIDE IT FOR THE OTHERS ──
        //
        // The same nesting `gnome_shell` uses, and copied rather than invented
        // for exactly that reason: two shells arranging their chrome by two
        // different schemes is how one of them ends up with a panel that
        // overlaps its own workspace on one edge only.
        //
        //   Column[ top, Expanded(Row[ left, Expanded(workspace), right ]),
        //           editBar, bottom ]
        //
        // The panel appears in exactly ONE of those four slots. The edit bar is
        // always horizontal and always against the panel it edits, because it is
        // a toolbar rather than a panel and a vertical strip of buttons 40dp
        // wide could not hold its labels.
        //
        Column(
          children: [
            if (side == TopBarSide.top) panel,
            Expanded(
              key: const ValueKey('plasma.workspace'),
              child: Row(
                children: [
                  if (side == TopBarSide.left) panel,
                  Expanded(
                    child: MediaQuery.removePadding(
                      context: context,
                      // The panel on that edge has already taken the inset out
                      // of its own box, so the workspace must not count it
                      // twice. On the edges where there is no panel the inset
                      // still belongs to the workspace.
                      removeBottom: side == TopBarSide.bottom,
                      removeTop: side == TopBarSide.top,
                      child: GestureLayer(
                        theme: theme,
                        // ─── THE HOLD THAT WAS NEVER HERE ────────────────
                        //
                        // Holding the Plasma desktop did nothing whatsoever.
                        // Every route to wallpaper, themes, widgets and
                        // settings ran through the drawer, so a user reaching
                        // for the gesture every launcher has concluded this
                        // shell could not be customised, and said so in a
                        // review.
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
                  if (side == TopBarSide.right) panel,
                ],
              ),
            ),
            if (side == TopBarSide.bottom) panel,
          ],
        ),
        // ShellDrawer DIRECTLY. `_Kickoff` wrapped it purely to carry a back
        // contract, and its own doc said so: "a back contract and nothing
        // else". home_screen owns back for every shell now, so the wrapper
        // had nothing left to do. Kickoff's presentation was never here
        // anyway; ShellDrawer resolves this shell to it.
        // ─── THE LATTE DOCK ───────────────────────────────────────────
        //
        // This shell drew a panel and NO dock, which is why Garuda's could not
        // exist: Dr460nized's whole look is a floating, magnifying dock over a
        // Plasma panel, and half of that was unreachable.
        //
        // `AquaDock` rather than `GnomeDock`, and that is not a shortcut.
        // Magnification lives in `AquaDockMetrics` and `GnomeDockStyle`
        // deliberately has no `magnified` arm, so teaching the GNOME dock to
        // swell would be a second parabola. Latte was modelled on the Mac dock
        // in the first place, so reusing the widget that owns the swell is the
        // accurate reading rather than the convenient one.
        //
        // Hidden while Kickoff is open, for the reason gnome_shell writes out:
        // the drawer paints a wash and anything still mounted below it bleeds
        // through and reads as dirt.
        // ─── THE RESOLVED VALUE, BY NAME ──────────────────────────────
        //
        // This read `DockSide.parse(theme.prefs.dockSide)`, which is the RAW
        // PREFERENCE. Null on any distro the user has not touched, and `parse`
        // falls back to bottom, so every plasma distro drew a dock and
        // `dock: "off"` in the theme was never consulted. Mint and KDE both
        // author `off` and both had one.
        //
        // `theme.dock` is the resolved answer: prefs first, then the theme,
        // computed once in `LayoutResolver`. It is the only value that should
        // ever be asked.
        //
        // Compared by NAME because two `DockSide` enums exist, one in
        // `theme_spec` and one in `dock_metrics`, and this file imports
        // `theme_spec` with a `show` list that excludes it. Adding it would put
        // two identically named enums in one scope, which is the collision the
        // restricted import exists to prevent. `.name` needs neither.
        // ─── AND OUT OF THE WAY WHILE THE PANEL IS EDITED ─────────────
        //
        // Two bars, both live, and a module dragged a little too far lands in
        // the wrong one. Hidden rather than dimmed: a dimmed dock still takes
        // the drop, and the gesture that misses is the one nobody can explain
        // afterwards.
        //
        // It comes straight back on Done, so nothing is lost and no state is
        // written; this is a visibility condition, not an edit.
        // ─── THE DOCK STAYS UP WHILE THE PANEL IS EDITED ─────────────────
        //
        // It was hidden because the old edit bar sat where the dock does and
        // the two collided. The editor is a sheet now, and hiding the dock
        // while someone edits the panel changes the desktop they are looking
        // at: the panel moves to the bottom edge, the dock is not there to
        // collide with, and it reappears somewhere else the moment they tap
        // Done. Editing should show the result, not a version of it.
        if (theme.dock.name != 'off' && !activitiesOpen)
          Positioned(
            left: 0,
            right: 0,
            // ─── ABOVE THE PANEL, NOT ON TOP OF IT ────────────────────
            //
            // The dock is a `Positioned` in the full-screen Stack and the
            // panel is a Column sibling that takes its own space out of the
            // bottom. So a bottom panel and a dock at `insets.bottom` land in
            // the same place and the dock sits over the clock.
            //
            // Authentic Dr460nized puts its panel on TOP and its Latte dock at
            // the foot, so this arrangement should be rare. It is handled
            // anyway because nothing stops a distro authoring both, and a
            // launcher that overlaps two of its own bars when asked to is worse
            // than one that stacks them.
            bottom: insets.bottom +
                10 +
                (side == TopBarSide.bottom
                    ? (theme.panelHeight ?? defaultPanelHeight)
                    : 0),
            child: _Dock(theme: theme),
          ),
        if (activitiesOpen) Positioned.fill(child: ShellDrawer(theme: theme)),
      ],
    );
  }
}

/// Plasma's dock, for the distros that put one over the panel.
///
/// ─── THE ENTRY BUILD IS SHORT, AND THE MENU IS THE SHARED ONE ───────────────
///
/// `aqua_shell` builds its entries the same way and then hands the long press to
/// a sixty-line private method with hardcoded English in it. That method is not
/// copied here, and not extracted either: this uses `showDrawerAppMenu`, which
/// every drawer in the app already uses, which speaks through `AppMenuWords` and
/// therefore says the right word on a distro whose favourites live in Kickoff
/// rather than on a dock.
///
/// What IS shared is the part that matters: `HomeLayout.dockKeys` decides which
/// apps are here, so a pin made anywhere shows up here and the two shells cannot
/// disagree about what the dock holds.
class _Dock extends ConsumerWidget {
  const _Dock({required this.theme});

  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apps = ref.watch(shellAppsProvider(theme));
    final frequent = ref.watch(frequentAppsProvider);

    final capacity = AquaDockMetrics.capacityFor(
      MediaQuery.sizeOf(context).width * 0.92,
    );

    // Kept apps, then most-used, then the alphabetical head on a fresh install.
    // A dock that can be empty is a dock that looks broken on day one.
    var keys = HomeLayout.dockKeys(
      theme.prefs,
      frequent: frequent,
      capacity: capacity,
      defaultLimit: AquaDockMetrics.minCapacity + 1,
    );
    if (keys.isEmpty) {
      keys = [
        for (final a in apps.take(AquaDockMetrics.minCapacity + 1))
          a.componentKey,
      ];
    }

    final byKey = {for (final a in apps) a.componentKey: a};
    final pinned = theme.prefs.favourites.toSet();

    final entries = <DockEntry>[
      for (final key in keys)
        if (byKey[key] != null)
          DockEntry(
            id: key,
            label: byKey[key]!.label,
            isPinned: pinned.contains(key),
            // Built at the PEAK size and scaled down by the dock's FittedBox.
            // Building at rest and scaling up blurs every icon the moment it
            // magnifies, which is the one thing a dock this showy cannot
            // afford. `aqua_dock` states the same rule.
            icon: AppIcon(entry: byKey[key]!, size: AquaDockMetrics.peakSlot),
            onTap: () => launchDrawerApp(ref, byKey[key]!),
            onLongPress: (anchor) => showDrawerAppMenu(
              context,
              ref,
              theme,
              byKey[key]!,
              anchor: anchor,
            ),
          ),
    ];

    if (entries.isEmpty) return const SizedBox.shrink();

    return AquaDock(
      entries: entries,
      palette: theme.palette,
      style: AquaDockStyle.parse(theme.dockStyle),
      hover: theme.dockHover,
      press: theme.dockPress,
      opacity: theme.dockOpacity,
      // Kickoff is the launcher on this shell and it opens from the panel, so
      // a second way in from the dock would be a button that duplicates the one
      // three centimetres below it.
      onLaunchpad: () => openApps(ref),
    );
  }
}
