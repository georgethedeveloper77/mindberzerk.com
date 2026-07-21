import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/prefs/home_layout.dart';
import '../data/prefs/prefs_repository.dart';
import '../data/repositories/app_repository.dart';
import '../data/repositories/shell_apps.dart';
import '../data/usage/usage_repository.dart';
import '../design/components/components.dart';
import '../engine/effective_theme.dart';
import '../features/dock/dock_metrics.dart';
import '../features/drawer/app_icon.dart';
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

  void _dockLongPress(AppEntry app, bool isPinned, int capacity) {
    final theme = widget.theme;
    final notifier = ref.read(prefsProvider(theme.spec.id).notifier);

    ThemedSheet.show<void>(
      context,
      builder: (sheet) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isPinned)
            ThemedListRow(
              icon: Icons.push_pin_outlined,
              title: 'Unpin from dock',
              onTap: () {
                Navigator.pop(sheet);
                notifier.edit(
                  (p) => HomeLayout.unpinFromDock(p, app.componentKey),
                );
              },
            )
          else
            ThemedListRow(
              icon: Icons.push_pin,
              title: 'Pin to dock',
              subtitle: 'The dock stops changing once you pin something',
              onTap: () {
                Navigator.pop(sheet);
                notifier.edit(
                  (p) => HomeLayout.pinToDock(
                    p,
                    app.componentKey,
                    capacity: capacity,
                  ),
                );
              },
            ),
          ThemedListRow(
            icon: Icons.info_outline,
            title: 'App info',
            onTap: () {
              Navigator.pop(sheet);
              ref.read(appListProvider.notifier).openInfo(app);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final count = ref.watch(workspaceCountProvider);
    final active = ref.watch(activeWorkspaceProvider);
    final activitiesOpen = ref.watch(activitiesOpenProvider);
    final dockRevealed = ref.watch(dockRevealedProvider);

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

    return Stack(
      children: [
        Column(
          children: [
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
            Opacity(
              opacity: activitiesOpen ? 0 : 1,
              child: GnomeTopBar(
                palette: theme.palette,
                onActivities: _openActivities,
                displayFontFamily: theme.typography.display,
              ),
            ),
            Expanded(
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
                          onLongPress: () => _dockLongPress(
                            byKey[key]!,
                            pinned.contains(key),
                            capacity,
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
                        GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onLongPress: () {
                            HapticFeedback.mediumImpact();
                            showDesktopMenu(context, theme);
                          },
                          child: PageView.builder(
                            controller: _pages,
                            scrollDirection: Axis.vertical,
                            itemCount: count,
                            onPageChanged: (page) => ref
                                .read(activeWorkspaceProvider.notifier)
                                .goTo(page),
                            itemBuilder: (_, __) => const SizedBox.expand(),
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
                          right: 9,
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
                                  left: 9,
                                  top: 0,
                                  bottom: 0,
                                  child: Center(
                                    child: GnomeDock(
                                      entries: entries,
                                      side: DockSide.left,
                                      gridButton: gridButton,
                                      slotSize: slot,
                                      palette: theme.palette,
                                      onActivities: _openActivities,
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
                                      onActivities: _openActivities,
                                    ),
                                  ),
                                ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
        if (activitiesOpen) Positioned.fill(child: _Activities(theme: theme)),
      ],
    );
  }
}

/// The Activities overlay.
///
/// Deliberately just a back contract plus [ShellDrawer]: no background, no app
/// bar, no back arrow. The DRAWER owns its presentation — for GNOME that is a
/// translucent wash over the wallpaper, and an opaque box here would paint over
/// exactly the thing that makes it read as Activities rather than as an app
/// list. Same reason there is no arrow: GNOME closes Activities with the Super
/// key, and Android's back gesture is the honest local equivalent, which the
/// PopScope below already provides.
class _Activities extends ConsumerWidget {
  const _Activities({required this.theme});

  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopScope(
      canPop: false,
      // Back closes the drawer, never leaves the launcher — native's
      // onBackPressed is intentionally empty, so this is all that stands
      // between a back press and nothing.
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          ref.read(activitiesOpenProvider.notifier).state = false;
        }
      },
      child: ShellDrawer(theme: theme),
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
