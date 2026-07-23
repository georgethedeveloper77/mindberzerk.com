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
import '../features/dock/aqua_dock_metrics.dart';
import '../features/drawer/shell_drawer.dart';
import '../features/drawer/app_icon.dart';
import '../features/drawer/drawer_state.dart';
import '../features/gestures/gesture_layer.dart';
import '../features/home/aqua/aqua_dock.dart';
import '../features/home/aqua/aqua_menu_bar.dart';
import '../features/home/gnome/desktop_menu.dart';
import '../features/home/gnome/gnome_dock.dart' show DockEntry;
import '../features/home/workspaces/workspace_canvas.dart';
import '../features/home/workspaces/workspace_controller.dart';
import '../platform/launcher_api.g.dart';

/// The macOS desktop. Menu bar across the top, magnifying dock floating at the
/// bottom, and nothing else — no icons on the desktop, same authentic-reading
/// rule the GNOME shell follows.
///
/// Structurally this is [GnomeShell] with three deliberate differences:
///
///  1. **The dock lives OUTSIDE [GestureLayer].** In the GNOME shell the dock is
///     a child of the gesture layer, which is fine because that dock only takes
///     taps. Aqua's dock tracks a finger dragging ALONG it, and a horizontal
///     scrub inside the gesture layer would be contested by the shell's swipe
///     handlers. Hoisting the dock out of that subtree removes the conflict at
///     the tree level rather than fighting it in the arena.
///
///  2. **Dock sizing is [AquaDockMetrics], not [DockMetrics].** The GNOME dock
///     is fit-to-run: every slot the same size, shrinking as it fills. Aqua's
///     slots are all different sizes at once and change every frame.
///
///  3. **The dock side is not user-configurable.** Ubuntu genuinely ships a
///     left dock and KDE a bottom panel, so `prefs.dockSide` means something
///     there. A vertical magnifying dock is not a Mac; it is a different
///     desktop wearing Aqua's paint. The pref is ignored here on purpose, and
///     the grid-button position with it, because Launchpad's slot has one home.
class AquaShell extends ConsumerStatefulWidget {
  const AquaShell({super.key, required this.theme});

  final EffectiveTheme theme;

  @override
  ConsumerState<AquaShell> createState() => _AquaShellState();
}

class _AquaShellState extends ConsumerState<AquaShell> {
  late final PageController _pages =
      PageController(initialPage: ref.read(activeWorkspaceProvider));

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _openLaunchpad() =>
      ref.read(activitiesOpenProvider.notifier).state = true;

  Future<void> _launch(AppEntry app) async {
    await ref.read(appListProvider.notifier).launch(app);
    // Every launch feeds frequency — it is what the default dock is made of.
    await ref.read(usageProvider.notifier).record(app.componentKey);
  }

  void _dockLongPress(AppEntry app, bool isPinned, int capacity) {
    final notifier = ref.read(prefsProvider(widget.theme.spec.id).notifier);

    ThemedSheet.show<void>(
      context,
      builder: (sheet) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isPinned)
            ThemedListRow(
              icon: Icons.push_pin_outlined,
              title: 'Remove from Dock',
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
              title: 'Keep in Dock',
              subtitle: 'The Dock stops changing once you keep something',
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
    final activitiesOpen = ref.watch(activitiesOpenProvider);
    final insets = MediaQuery.viewPaddingOf(context);

    // Source of truth is the controller; the PageController follows, so a HOME
    // press or a menu-bar action moves the page too, not just a swipe.
    ref.listen<int>(activeWorkspaceProvider, (_, next) {
      if (!_pages.hasClients) return;
      if ((_pages.page ?? 0).round() == next) return;
      _pages.animateToPage(
        next,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });

    final apps = ref.watch(shellAppsProvider(theme));
    final frequent = ref.watch(frequentAppsProvider);

    // Capacity is a plain function of width here, unlike the GNOME dock's
    // inset-aware calculation, because an Aqua dock is always horizontal and
    // always floats clear of the gesture pill.
    final capacity = AquaDockMetrics.capacityFor(
      MediaQuery.sizeOf(context).width * 0.92,
    );

    // Kept apps → most-used → (first run, no usage yet) the alphabetical head.
    // The dock must never be empty: it is the only app surface on the desktop.
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

    // Resolve to keys that actually have an installed app, so the magnification
    // is computed from what really renders rather than from dead keys.
    final dockKeys = [
      for (final key in keys)
        if (byKey[key] != null) key,
    ];

    final entries = <DockEntry>[
      for (final key in dockKeys)
        DockEntry(
          id: key,
          label: byKey[key]!.label,
          isPinned: pinned.contains(key),
          // Built once at the PEAK size and scaled down by the dock's FittedBox.
          // Building at the resting size and scaling UP would blur every icon
          // the moment it magnified, which is the one thing a dock this showy
          // cannot afford.
          icon: AppIcon(entry: byKey[key]!, size: AquaDockMetrics.peakSlot),
          onTap: () => _launch(byKey[key]!),
          onLongPress: () => _dockLongPress(
            byKey[key]!,
            pinned.contains(key),
            capacity,
          ),
        ),
    ];

    return Stack(
      children: [
        Column(
          children: [
            // Hidden while Launchpad is open, for the reason written out at
            // length in gnome_shell: the drawer paints a 0.92 wash, so any
            // chrome still mounted below it bleeds through at 8% and reads as
            // dirt rather than as translucency. Opacity rather than an `if`
            // because this is a Column child and dropping it would reflow the
            // canvas for a frame, visibly, through that same wash.
            Opacity(
              opacity: activitiesOpen ? 0 : 1,
              child: AquaMenuBar(
                palette: theme.palette,
                title: theme.spec.name,
                logo: theme.spec.logo,
                displayFontFamily: theme.typography.display,
                onLaunchpad: _openLaunchpad,
                onSpotlight: _openLaunchpad,
              ),
            ),
            Expanded(
              child: GestureLayer(
                theme: theme,
                child: GestureDetector(
                  // Translucent and long-press only, claiming no axis — the same
                  // arrangement the GNOME shell uses. A held press resolves to
                  // the desktop menu; any drag resolves to a workspace change.
                  behavior: HitTestBehavior.translucent,
                  onLongPress: () {
                    HapticFeedback.mediumImpact();
                    showDesktopMenu(context, ref, theme);
                  },
                  child: WorkspaceCanvas(controller: _pages, count: count),
                ),
              ),
            ),
          ],
        ),

        // OUTSIDE the gesture layer. See the class note: a scrub along the dock
        // must not be contested by the shell's swipe handlers.
        //
        // Not built at all while Launchpad is open. A Positioned, so this
        // reflows nothing, and a magnifying dock ghosting through an app grid
        // is the worst-looking version of this bug: the icons are large and
        // unevenly sized, so they read as a second broken grid.
        if (!activitiesOpen)
        Positioned(
          left: 0,
          right: 0,
          bottom: insets.bottom + 8,
          child: AquaDock(
            entries: entries,
            palette: theme.palette,
            onLaunchpad: _openLaunchpad,
          ),
        ),

        if (activitiesOpen) Positioned.fill(child: _Launchpad(theme: theme)),
      ],
    );
  }
}

/// Launchpad.
///
/// A back contract and nothing else, exactly like GNOME's `_Activities` and
/// KDE's `_Kickoff`: [ShellDrawer] owns the presentation, and wrapping it in an
/// opaque background here would paint over the blurred desktop that makes it
/// read as Launchpad rather than as an app list.
///
/// Today that resolves to the shared Activities grid — see the interim note in
/// shell_drawer.dart. Real Launchpad is paged rather than scrolling, which is
/// its own sitting.
class _Launchpad extends ConsumerWidget {
  const _Launchpad({required this.theme});

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
