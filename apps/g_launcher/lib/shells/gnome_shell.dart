import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g_launcher/i18n/i18n.dart';

import '../data/prefs/hidden_apps.dart';
import '../data/prefs/home_layout.dart';
import '../data/prefs/prefs_repository.dart';
import '../data/repositories/app_repository.dart';
import '../data/repositories/shell_apps.dart';
import '../data/usage/usage_repository.dart';
import '../design/branded_message.dart';
import '../design/components/components.dart';
import '../engine/effective_theme.dart';
// TopBarSide only. An unrestricted import of theme_spec into a file that also
// sees dock_metrics is an ambiguous-import error on DockSide, which is declared
// in both; desklet_editor documents the same trap.
import '../engine/theme_spec.dart' show TopBarSide, WorkspaceAxis;
import '../features/dock/dock_metrics.dart';
import '../features/drawer/app_icon.dart';
import '../features/desklets/desklet_edit.dart';
import '../features/desklets/desklet_edit_bar.dart';
import '../features/desklets/desklet_surface.dart';
import '../features/drawer/drawer_state.dart';
import '../features/drawer/shell_drawer.dart';
import '../features/gestures/gesture_layer.dart';
import '../features/home/gnome/desktop_menu.dart';
import '../features/home/gnome/gnome_dock.dart';
import '../features/home/gnome/gnome_top_bar.dart';
import '../features/home/workspaces/workspace_controller.dart';
import '../features/home/workspaces/workspace_dots.dart';
import '../platform/launcher_api.g.dart';

/// The Ubuntu 24.04 / any-GNOME desktop. Authentic reading: no app icons on the
/// desktop — wallpaper, conky, workspace dots, dock. That's the screen.
///
/// **Workspaces scroll VERTICALLY now.** The mockup was saying this all along:
/// the workspace dots are a vertical strip on the right edge, and vertical dots
/// mean vertical movement (it's also how GNOME itself stacks workspaces). Swipe
/// up/down moves between workspaces; the gesture layer no longer touches
/// vertical drags at all, so there is no arena fight. The drawer moved to swipe
/// right.
///
/// **The dock is real now.** Contents come from `HomeLayout.dockKeys`: the
/// user's pins (`prefs.favourites`) if they've pinned anything, otherwise their
/// most-used apps (frecency) capped at `DockMetrics.defaultCount`, otherwise —
/// very first run, no usage yet — the alphabetical head (also capped) so the
/// dock is never empty. Capacity for PINS is computed from the dock's actual
/// run via `DockMetrics.capacityFor`; the default set is deliberately just four.
///
/// **Long-press the empty desktop** opens the wallpaper / widget / settings
/// menu (`showDesktopMenu`) — GNOME's right-click, mobile shaped.
class GnomeShell extends ConsumerStatefulWidget {
  const GnomeShell({super.key, required this.theme});

  final EffectiveTheme theme;

  @override
  ConsumerState<GnomeShell> createState() => _GnomeShellState();
}

class _GnomeShellState extends ConsumerState<GnomeShell> {
  late final PageController _pages =
      PageController(initialPage: ref.read(activeWorkspaceProvider));

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _openActivities() =>
      ref.read(activitiesOpenProvider.notifier).state = true;

  Future<void> _launch(AppEntry app) async {
    await ref.read(appListProvider.notifier).launch(app);
    // Every launch feeds frequency — it's what the default dock is made of.
    await ref.read(usageProvider.notifier).record(app.componentKey);
  }

  /// A dock slot was dragged onto another one.
  ///
  /// ─── WHY THE SHELL DOES THIS AND NOT THE DOCK ───────────────────────────
  ///
  /// `GnomeDock` holds no `ref` on purpose, which is what lets its golden tests
  /// render without a live LauncherApps. It reports the gesture; this decides
  /// what the gesture means. Same split as `onTap` and `onLongPress` above it.
  ///
  /// ─── AND WHY THE REFUSAL IS SILENT HERE ─────────────────────────────────
  ///
  /// [HomeLayout.reorderDockKeys] returns the prefs unchanged when either key
  /// is not pinned, which is every slot in a dock that is still auto-filling
  /// from frequent apps. That is the right answer and it needs no message: the
  /// dock never offered an arrangement to change, so nothing was refused that
  /// the user asked for. A sentence explaining it would be the launcher
  /// answering a question nobody put.
  ///
  /// The dock only ARMS the drag when this callback is non-null, and it is only
  /// non-null when there are pins, so the silent branch is nearly unreachable
  /// in practice. It stays reachable for the case where the last pin is removed
  /// mid-drag.
  void _dockReorder(String movedKey, String targetKey, bool after) {
    ref.read(prefsProvider(widget.theme.spec.id).notifier).edit(
          (p) => HomeLayout.reorderDockKeys(
            p,
            movedKey,
            targetKey,
            after: after,
          ),
        );
  }

  void _dockLongPress(
    AppEntry app,
    bool isPinned,
    int capacity,
    Rect? anchor,
  ) {
    final theme = widget.theme;
    final notifier = ref.read(prefsProvider(theme.spec.id).notifier);
    final apps = ref.read(appListProvider.notifier);
    final host = context;

    // Built from the theme rather than read from a scope, the same reason
    // `drawer_actions` and `desklet_menu` build their own: the desktop is not
    // guaranteed to sit under a ChromeScope and this route is not a descendant
    // of one.
    final chrome = ChromeData.fromPalette(
      theme.palette,
      typography: theme.typography,
      textScale: theme.textScale,
      family: theme.chromeFamily,
      opacity: theme.surfaceOpacity,
      panelBlur: theme.panelBlur,
      panelTint: theme.panelTint,
      panelRadius: theme.panelRadius,
    );

    // ── THE MIDDLE SLOT CHANGES WITH THE MODE, AND HAS TO ────────────────
    //
    // Unpinned, the dock is filling itself and the useful verb is "stop putting
    // this here", which is the exclusion. Pinned, unpinning ALREADY removes it,
    // so a Remove button beside Unpin would be two glyphs doing one thing. The
    // slot goes to Hide instead, which is the verb the drawer's own menu uses
    // and the only other way an app leaves this shell.
    AnchoredMenu.show(
      context: context,
      chrome: chrome,
      anchor: anchor,
      width: 244,
      title: app.label,
      onInfo: () => apps.openInfo(app),
      actions: [
        if (isPinned)
          MenuAction(
            icon: Icons.push_pin_outlined,
            label: host.t('shell.unpinFromDock'),
            onTap: () => notifier.edit(
              (p) => HomeLayout.unpinFromDock(p, app.componentKey),
            ),
          )
        else
          MenuAction(
            icon: Icons.push_pin,
            label: host.t('shell.pinToDock'),
            onTap: () => notifier.edit(
              (p) => HomeLayout.pinToDock(
                p,
                app.componentKey,
                capacity: capacity,
              ),
            ),
          ),
        if (isPinned)
          MenuAction(
            icon: Icons.visibility_off_outlined,
            label: host.t('drawer.hideApp'),
            onTap: () {
              notifier.edit((p) => HiddenApps.hide(p, app.componentKey));
              if (host.mounted) {
                host.showMessage(
                  host.t('drawer.appHidden', {'name': app.label}),
                );
              }
            },
          )
        else
          MenuAction(
            icon: Icons.remove_circle_outline,
            label: 'Remove from dock',
            onTap: () => notifier.edit(
              (p) => HomeLayout.excludeFromDock(p, app.componentKey),
            ),
          ),
        // A system app cannot be uninstalled, so the third slot takes App info
        // rather than leaving a hole: two glyphs in a three-column row look
        // like one failed to draw.
        if (!app.isSystem && !app.isWorkProfile)
          MenuAction(
            icon: Icons.delete_outline,
            label: host.t('drawer.uninstall'),
            danger: true,
            onTap: () => apps.uninstall(app),
          )
        else
          MenuAction(
            icon: Icons.info_outline,
            label: host.t('shell.appInfo'),
            onTap: () => apps.openInfo(app),
          ),
      ],
      rows: (menu) => const [],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final count = ref.watch(workspaceCountProvider);
    final active = ref.watch(activeWorkspaceProvider);
    final activitiesOpen = ref.watch(activitiesOpenProvider);

    final dockRevealed = ref.watch(dockRevealedProvider);
    final editing = ref.watch(deskletEditProvider).active;

    final side = DockSide.parse(theme.prefs.dockSide);
    final gridButton = GridButtonPosition.parse(theme.prefs.dockGridButton);

    // Source of truth is the controller; the PageController follows. A HOME
    // press, a dot tap, or a gesture can change the workspace — not just a
    // swipe — and the PageView has to track all of them.
    ref.listen<int>(activeWorkspaceProvider, (_, next) {
      if (!_pages.hasClients) return;
      if ((_pages.page ?? 0).round() == next) return;
      _pages.animateToPage(
        next,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });

    // ─── COLUMN OR ROW, BY WHICH EDGE THE BAR OWNS ────────────────────────
    //
    // A vertical bar is not a rotated horizontal one, it is the same three
    // children laid out along the other axis. Building the list once and
    // choosing the flex widget keeps the bar, the workspace and the ordering
    // in one place; writing the vertical case out separately is how the two
    // stop matching after the next change to either.
    //
    // The dock needs no special handling. It is Positioned inside the
    // WORKSPACE's own LayoutBuilder rather than this Stack, so shrinking the
    // workspace by the bar's thickness moves the dock inboard for free, which
    // is also how a real polybar and a dock share an edge.
    // ─── PANELS, NESTED BY AXIS ───────────────────────────────────────────
    //
    // Column for the horizontal edges, wrapping a Row for the vertical ones:
    //
    //   Column[ top..., Expanded(Row[ left..., Expanded(workspace), right... ]),
    //           bottom... ]
    //
    // That shape handles every combination, including the one this shell could
    // not express at all until now: Xfce's top bar AND bottom dock, which is
    // what Kali ships. The single-bar version was an if-chain that could only
    // ever place one.
    //
    // The dock still needs no special handling. It is Positioned inside the
    // WORKSPACE's LayoutBuilder, so every panel that takes space shrinks the
    // box the dock is positioned within, and they cannot overlap.
    List<Widget> panelsOn(TopBarSide side) => [
          for (final p in theme.panels)
            if (p.side == side)
              Opacity(
                // Opacity rather than a conditional, unchanged reasoning: see
                // the note below. Dropping a panel would let the workspace grow
                // into the freed space for one frame, and that reflow is
                // visible through the Activities wash.
                opacity: activitiesOpen ? 0 : 1,
                child: GnomeTopBar(
                  palette: theme.palette,
                  onActivities: _openActivities,
                  displayFontFamily: theme.typography.display,
                  panel: p,
                ),
              ),
        ];

    final workspace = <Widget>[
            // ── WHY THIS IS AN OPACITY AND NOT AN `if` ──────────────────
            //
            // The drawer paints a 0.92 wash, so anything still mounted BELOW
            // it bleeds through at 8%. On a real device that put the word
            // "Activities" across the first row of app labels and ghosted the
            // dock's icons down the left edge: not translucency, just dirt.
            //
            // The wash itself is correct and stays. GNOME's overview is
            // meant to show the wallpaper through it, and the wallpaper is
            // drawn by WindowManager BENEATH Flutter, so it comes through
            // whatever we do here. The bug was never the alpha; it was that
            // the shell's own chrome was sitting between the two.
            //
            // Opacity rather than a conditional because this is a Column
            // child: dropping it would let the workspace canvas grow into the
            // freed height for one frame, and that reflow is visible through
            // the very wash we are fixing. The dock and the dots below are
            // Positioned, so they can simply not be built.
            // ─── THE BAR CAN SIT AT EITHER END ────────────────────────
            //
            // It was always the first child of this Column, which is GNOME's
            // answer and a fine default. It is not everyone's: a waybar or a
            // polybar is as often along the bottom, and a distro that puts it
            // there is a distro this shell could not express.
            //
            // Built once and placed by position rather than duplicated, so the
            // Opacity trick below keeps working identically at both ends. See
            // the note there for why it is opacity and not a conditional.
            // No Expanded here any more: this list is the children of a Stack
            // that an outer Expanded already sizes, and an Expanded inside a
            // Stack is an error. The old code put the bar and the workspace in
            // one Column, so the workspace had to claim the leftover height
            // itself; panels take their space in the enclosing Column now.
            Positioned.fill(
              child: GestureLayer(
                theme: theme,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final insets = MediaQuery.viewPaddingOf(context);

                    // 'off' renders where Ubuntu keeps it — the left — so it is
                    // vertical for sizing too, even though the pref isn't 'left'.
                    // Sizing against the wrong axis makes a revealed off-dock
                    // shrink as if it were the short bottom run.
                    final renderVertical =
                        side.isVertical || side == DockSide.off;

                    // Capacity from the dock's REAL run, insets subtracted — a
                    // left dock that runs under the gesture pill silently loses
                    // its last app. Bottom docks are additionally hard-capped.
                    final available = renderVertical
                        ? constraints.maxHeight - insets.bottom
                        : constraints.maxWidth - 18; // 9px margin each side

                    final capacity = DockMetrics.capacityFor(
                      available: available,
                      hasGridButton: gridButton != GridButtonPosition.off,
                      isBottom: !renderVertical,
                    );

                    final apps = ref.watch(shellAppsProvider(theme));
                    final frequent = ref.watch(frequentAppsProvider);

                    // Pins (up to capacity) → most-used (capped at four) →
                    // (first run, no usage yet) alphabetical head, also four.
                    // The dock must never be empty: it is the only app surface
                    // on the home screen. "Four bigger apps" is the out-of-box
                    // look; pinning grows it up to `capacity`.
                    var keys = HomeLayout.dockKeys(
                      theme.prefs,
                      frequent: frequent,
                      capacity: capacity,
                      defaultLimit: DockMetrics.defaultCount,
                    );
                    if (keys.isEmpty) {
                      keys = [
                        for (final a in apps.take(DockMetrics.defaultCount))
                          a.componentKey,
                      ];
                    }

                    final byKey = {for (final a in apps) a.componentKey: a};
                    final pinned = theme.prefs.favourites.toSet();

                    // Resolve to keys that actually have an installed app, so the
                    // slot size is computed from what really renders — not from
                    // dead keys that would size the dock for icons never drawn.
                    final dockKeys = [
                      for (final key in keys)
                        if (byKey[key] != null) key,
                    ];

                    // Fit-to-run sizing: large for a few apps, shrinking as the
                    // dock fills (and never overflowing). The glyph tracks the
                    // slot; both feed the dock below.
                    final slot = DockMetrics.slotFor(
                      count: dockKeys.length,
                      available: available,
                      hasGridButton: gridButton != GridButtonPosition.off,
                    );
                    final glyph = DockMetrics.appGlyphFor(slot);

                    final entries = <DockEntry>[
                      for (final key in dockKeys)
                        DockEntry(
                          id: key,
                          label: byKey[key]!.label,
                          isPinned: pinned.contains(key),
                          icon: AppIcon(entry: byKey[key]!, size: glyph),
                          onTap: () => _launch(byKey[key]!),
                          onLongPress: (anchor) => _dockLongPress(
                            byKey[key]!,
                            pinned.contains(key),
                            capacity,
                            anchor,
                          ),
                        ),
                    ];

                    // `&& !activitiesOpen`: the dock is the loudest thing
                    // that was ghosting through the drawer. Positioned, so
                    // not building it reflows nothing.
                    final showDock =
                        (side != DockSide.off || dockRevealed) &&
                            !activitiesOpen;

                    return Stack(
                      children: [
                        // ── Workspaces: VERTICAL, and empty on purpose ──────
                        // Their content is the wallpaper, which WindowManager
                        // draws behind Flutter. Vertical drags fall through the
                        // gesture layer straight to this PageView — it owns
                        // them exclusively.
                        //
                        // The long-press wrapper claims NO axis: it is
                        // translucent and handles long-press only. A held press
                        // with no movement resolves to the desktop menu; any
                        // drag resolves to a workspace change. No arena fight —
                        // the thing the handoff warns about is claiming an axis
                        // a scrollable owns, which this does not do.
                        _DesktopHold(
                          // ── NOT BUILT AT ALL WHILE EDITING ─────────────
                          //
                          // This was gated inside the callback, which is not a
                          // gate. A LongPressGestureRecognizer that returns
                          // early has still WON the arena: it took the pointer
                          // from the tile underneath, which then never received
                          // the hold it was waiting for. So holding a widget in
                          // edit mode did nothing at all, and holding one at
                          // rest opened the desktop menu instead of picking the
                          // widget up. Both are the same bug, and the only cure
                          // is for this recognizer not to exist right now.
                          //
                          // At rest it is still exactly GNOME's right-click:
                          // hold the EMPTY desktop for the wallpaper, themes,
                          // widgets and settings bar. A hold that lands on a
                          // tile is claimed by the tile, because the tile is
                          // deeper in the tree and wins the arena on its own.
                          enabled: !editing,
                          onHold: () {
                            HapticFeedback.mediumImpact();
                            showDesktopMenu(context, ref, theme);
                          },
                          child: PageView.builder(
                            controller: _pages,
                            // The DISTRO's axis, not this shell's. GNOME
                            // pages vertically and always did; macOS Spaces run
                            // horizontally, and a phone imitating macOS that
                            // swipes down to change space is wrong in a way
                            // anyone who has used one notices at once.
                            scrollDirection:
                                theme.workspaceAxis == WorkspaceAxis.horizontal
                                    ? Axis.horizontal
                                    : Axis.vertical,
                            // Frozen while editing. A tile being dragged up the
                            // screen and a vertical pager are the same gesture,
                            // and the arena would hand it to whichever claimed
                            // first — which is to say, to whichever one you were
                            // not testing that day. Ceding the axis outright is
                            // why DeskletEditBar has a visible Done: a mode that
                            // silently disables the desktop's main gesture needs
                            // to say so and offer the way out.
                            physics: editing
                                ? const NeverScrollableScrollPhysics()
                                : null,
                            itemCount: count,
                            onPageChanged: (page) => ref
                                .read(activeWorkspaceProvider.notifier)
                                .goTo(page),
                            // ── THE ONE LINE PHASE D TURNED ON ──────────
                            //
                            // These pages returned SizedBox.expand() because
                            // the desktop was empty BY DESIGN. That is still
                            // the authentic default; it is just no longer the
                            // only option. DeskletSurfaceView renders an empty
                            // page as nothing at all unless edit mode is on, so
                            // a desktop with no desklets looks exactly as it
                            // did before this line changed.
                            itemBuilder: (_, page) =>
                                DeskletSurfaceView(theme: theme, page: page),
                          ),
                        ),

                        // Vertical parallax — without it, swiping between
                        // identical empty pages produces no visual change and
                        // the gesture feels broken.
                        Positioned.fill(
                          child: _WallpaperParallax(
                            controller: _pages,
                            pageCount: count,
                            base: theme.palette.bgBottom,
                          ),
                        ),

                        // Dots ghost through the drawer too, and a column of
                        // faint pips down the right edge of an app grid reads
                        // as a rendering fault rather than as chrome.
                        if (!activitiesOpen)
                        Positioned(
                          // ── THE DOTS GET OUT OF THE DOCK'S WAY ──────────
                          //
                          // Hardcoded `right: 9` while the dock only ever sat
                          // on the left, which made the two edges a fixed pair
                          // rather than a decision. A right dock lands the dots
                          // and the dock on the same 9px strip, overlapping,
                          // and the dots lose because they are drawn first.
                          //
                          // The rule is OPPOSITE THE DOCK, not "always right":
                          // the pair is what reads as a workspace strip on one
                          // side and apps on the other, and a bottom or absent
                          // dock leaves them where Ubuntu keeps them.
                          left: side == DockSide.right ? 9 : null,
                          right: side == DockSide.right ? null : 9,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: WorkspaceDots(
                              count: count,
                              active: active,
                              accent: theme.palette.accent,
                              // Was Ubuntu.dotIdle. An inactive workspace dot
                              // has to read against THIS distro's wallpaper.
                              idle:
                                  theme.palette.onDark.withValues(alpha: 0.35),
                              onSelect: (i) => ref
                                  .read(activeWorkspaceProvider.notifier)
                                  .goTo(i),
                            ),
                          ),
                        ),

                        if (showDock)
                          side.isVertical || side == DockSide.off
                              // Off + revealed by gesture shows it where Ubuntu
                              // keeps it: the left.
                              ? Positioned(
                                  // `off` still reveals on the left, which is
                                  // where Ubuntu keeps it; only an explicit
                                  // `right` moves the strip across.
                                  left: side == DockSide.right ? null : 9,
                                  right: side == DockSide.right ? 9 : null,
                                  top: 0,
                                  bottom: 0,
                                  child: Center(
                                    child: GnomeDock(
                                      entries: entries,
                                      // Passed through rather than pinned to
                                      // left: the dock draws its running bars
                                      // against whichever edge it is on, and
                                      // hardcoding the side here is what used
                                      // to make that decision unreachable.
                                      side: side == DockSide.right
                                          ? DockSide.right
                                          : DockSide.left,
                                      gridButton: gridButton,
                                      slotSize: slot,
                                      palette: theme.palette,
                                      opacity: theme.dockOpacity,
                                      onActivities: _openActivities,
                                      // NULL UNLESS THERE ARE PINS.
                                      //
                                      // A dock in frequent-apps mode has no
                                      // arrangement to change: it is whatever
                                      // the user opens most, recomputed. Arming
                                      // the drag there would offer a gesture
                                      // that can only ever be refused, and the
                                      // slot's own fallback branch keeps the
                                      // plain long-press when this is null.
                                      onReorder: pinned.isEmpty
                                          ? null
                                          : _dockReorder,
                                    ),
                                  ),
                                )
                              : Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: insets.bottom + 9,
                                  child: Center(
                                    child: GnomeDock(
                                      entries: entries,
                                      side: DockSide.bottom,
                                      gridButton: gridButton,
                                      slotSize: slot,
                                      palette: theme.palette,
                                      opacity: theme.dockOpacity,
                                      onActivities: _openActivities,
                                      // NULL UNLESS THERE ARE PINS.
                                      //
                                      // A dock in frequent-apps mode has no
                                      // arrangement to change: it is whatever
                                      // the user opens most, recomputed. Arming
                                      // the drag there would offer a gesture
                                      // that can only ever be refused, and the
                                      // slot's own fallback branch keeps the
                                      // plain long-press when this is null.
                                      onReorder: pinned.isEmpty
                                          ? null
                                          : _dockReorder,
                                    ),
                                  ),
                                ),
                      ],
                    );
                  },
                ),
              ),
            ),
    ];

    final body = Stack(
      children: [
        Column(
          children: [
            ...panelsOn(TopBarSide.top),
            Expanded(
              child: Row(
                children: [
                  ...panelsOn(TopBarSide.left),
                  Expanded(child: Stack(children: workspace)),
                  ...panelsOn(TopBarSide.right),
                ],
              ),
            ),
            ...panelsOn(TopBarSide.bottom),
          ],
        ),
        if (activitiesOpen) Positioned.fill(child: _Activities(theme: theme)),

        // Positioned internally, and renders nothing unless edit mode is on.
        DeskletEditBar(theme: theme),
      ],
    );

    // ── BACK IS NOT THIS SHELL'S TO OWN ─────────────────────────────────
    //
    // This file used to hold the priority chain, on the grounds that the shell
    // is the thing that can see what is open. That was right about the problem
    // and wrong about the place: home_screen wraps EVERY shell, this wraps one,
    // and the other four had no edit-mode handler at all. The chain lives there
    // now, and having it in both was itself the double-fire the old comment
    // here warned about.
    return body;
  }
}

/// The Activities overlay.
///
/// Deliberately just a back contract plus [ShellDrawer]: no background, no app
/// bar, no back arrow. The DRAWER owns its presentation — for GNOME that is a
/// translucent wash over the wallpaper, and an opaque box here would paint over
/// exactly the thing that makes it read as Activities rather than as an app
/// list. Same reason there is no arrow: GNOME closes Activities with the Super
/// key, and Android's back gesture is the honest local equivalent, which
/// home_screen's single PopScope provides for every shell.
class _Activities extends ConsumerWidget {
  const _Activities({required this.theme});

  final EffectiveTheme theme;

  /// NO PopScope here, and none in the shell above either any more. home_screen
  /// owns back for the whole tree in priority order, because it is the only
  /// widget that wraps all five shells, and any second scope in the same route
  /// fires on the same press.
  @override
  Widget build(BuildContext context, WidgetRef ref) => ShellDrawer(theme: theme);
}

/// The desktop's own long press, which can be switched off entirely.
///
/// A widget rather than a conditional at the call site purely so the PageView
/// below it is written once. [enabled] false returns the child untouched, so no
/// recognizer is registered and nothing competes for the pointer; see the note
/// at the call site for why returning early from the handler is not the same
/// thing.
class _DesktopHold extends StatelessWidget {
  const _DesktopHold({
    required this.enabled,
    required this.onHold,
    required this.child,
  });

  final bool enabled;
  final VoidCallback onHold;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // A NULL callback, not an early return of the child. Returning the child
    // would change the shape of the tree, and this wraps the workspace
    // PageView: the shape change unmounts it, a remounted PageView carries a
    // brand new PageController, and the desktop would jump back to workspace
    // one every time edit mode toggled. GestureDetector builds a recognizer
    // only for a non-null callback, so this registers nothing while editing and
    // the tree keeps its shape.
    //
    // The wrapper claims NO axis: it is translucent and handles long press
    // only. A held press with no movement resolves to the desktop menu; any
    // drag resolves to a workspace change. No arena fight, because the thing
    // the handoff warns about is claiming an axis a scrollable owns, which this
    // does not do.
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPress: enabled ? onHold : null,
      child: child,
    );
  }
}

/// Vertical parallax. The wallpaper is drawn by WindowManager underneath
/// Flutter, so we can't move it — we move a cheap tint layer over it instead.
/// When the wallpaper is eventually Flutter-drawn, swap the gradient for the
/// image at over-scaled height translated by `-page * overscan`.
class _WallpaperParallax extends StatelessWidget {
  const _WallpaperParallax({
    required this.controller,
    required this.pageCount,
    required this.base,
  });

  final PageController controller;
  final int pageCount;

  /// The distro's darkest base. The drift tint used to be flat black, which
  /// greys every wallpaper the same way; tinting toward the theme's own base
  /// makes the parallax read as this desktop dimming rather than as a shadow
  /// sliding over it.
  final Color base;

  @override
  Widget build(BuildContext context) {
    if (pageCount <= 1) return const SizedBox.shrink();

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final page = controller.hasClients && controller.page != null
              ? controller.page!
              : controller.initialPage.toDouble();
          final t = page / (pageCount - 1);

          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                // Vertical drift to match the vertical scroll.
                begin: Alignment(-1, -1 + t * 0.6),
                end: Alignment(1, 1 + t * 0.6),
                colors: [
                  base.withValues(alpha: 0),
                  base.withValues(alpha: 0.14),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
