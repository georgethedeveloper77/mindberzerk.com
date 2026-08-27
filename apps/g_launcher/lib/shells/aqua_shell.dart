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
// TopBarSide: the menu bar now asks whether this distro has a top panel at all.
import '../engine/theme_spec.dart';
import '../features/dock/aqua_dock_metrics.dart';
import '../features/drawer/app_icon.dart';
import '../features/drawer/drawer_state.dart';
import '../features/drawer/shell_drawer.dart';
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

  /// Show the apps, however THIS distro shows them.
  ///
  /// Was `activitiesOpenProvider = true`, which is only one of the two answers
  /// now: a Deepin-style distro puts its app list on a page and has no overlay
  /// to open. See [openApps].
  void _openLaunchpad() => openApps(ref);

  Future<void> _launch(AppEntry app) async {
    await ref.read(appListProvider.notifier).launch(app);
    // Every launch feeds frequency — it is what the default dock is made of.
    await ref.read(usageProvider.notifier).record(app.componentKey);
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
            label: 'Remove from Dock',
            onTap: () => notifier.edit(
              (p) => HomeLayout.unpinFromDock(p, app.componentKey),
            ),
          )
        else
          MenuAction(
            icon: Icons.push_pin,
            label: 'Keep in Dock',
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
            label: 'Hide from Launchpad',
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
            label: 'Take out of the Dock',
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
            label: 'Uninstall',
            danger: true,
            onTap: () => apps.uninstall(app),
          )
        else
          MenuAction(
            icon: Icons.info_outline,
            label: 'App info',
            onTap: () => apps.openInfo(app),
          ),
      ],
      rows: (menu) => const [],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;

    // Looked up ONCE, from `widget.theme` rather than from a provider: the
    // theme is already in hand, and reading it twice from two sources is how
    // two answers to one question start disagreeing.
    //
    // It answers two, a few lines apart: whether there is a bar at all, and
    // what is on it.
    PanelSpec? topPanel;
    for (final p in theme.panels) {
      if (p.side == TopBarSide.top) {
        topPanel = p;
        break;
      }
    }
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
          onLongPress: (anchor) => _dockLongPress(
            byKey[key]!,
            pinned.contains(key),
            capacity,
            anchor,
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
            // ─── ONLY IF THE DISTRO HAS A TOP BAR AT ALL ────────────────
            //
            // Unconditional until now, which put a MENU BAR on Deepin: an
            // apple-shaped logo slot and a Spotlight glyph on a desktop that
            // has never had a bar across the top. The class doc above says as
            // much without noticing it applies to only one of the two aqua
            // distros: "The macOS desktop. Menu bar across the top." That is
            // Pantheon. DDE is fashion mode, and fashion mode is a dock on a
            // wallpaper and nothing else.
            //
            // The test is the same one `gnome_shell.panelsOn` uses, and it
            // covers both spellings for free: `ThemeSpec._panels` SYNTHESISES a
            // top panel for any theme with the legacy `topBar: true`, and
            // returns `const []` for `topBar: false`. So elementary keeps its
            // wingpanel without authoring anything, and Deepin loses the bar by
            // saying `topBar: false`, which is simply true of it.
            if (topPanel != null)
              Opacity(
                opacity: activitiesOpen ? 0 : 1,
                child: AquaMenuBar(
                  modules: topPanel.modules,
                  palette: theme.palette,
                  opacity: theme.barOpacity,
                  title: theme.spec.name,
                  // RESOLVED here, so an installed Aqua pack's bare
                  // filename becomes a file rather than a bundle miss. The bar is
                  // frosted chrome, hence the dark-surface variant.
                  logo: theme.spec.logoAsset(onDarkSurface: true),
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
                  child: WorkspaceCanvas(
                    theme: theme,
                    controller: _pages,
                    count: count,
                  ),
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
            // FLAT MEETS THE EDGE. Plank sits on the bottom of the screen;
            // a fashion dock floats above it. The 8dp gap was the only
            // arrangement this shell knew, which is why both aqua distros drew
            // a dock hovering over the wallpaper.
            //
            // `insets.bottom` stays in both: on a gesture-navigation phone that
            // is the home indicator, and a dock underneath it is a dock you
            // cannot tap.
            bottom:
                theme.dockStyle == 'flat' ? insets.bottom : insets.bottom + 8,
            child: AquaDock(
              entries: entries,
              palette: theme.palette,
              style: AquaDockStyle.parse(theme.dockStyle),
              opacity: theme.dockOpacity,
              onLaunchpad: _openLaunchpad,
            ),
          ),

        // ShellDrawer directly; `_Launchpad` was a back contract and nothing
        // else. The interim note about real Launchpad being paged rather than
        // scrolling lives in shell_drawer.dart, which is where the decision
        // actually is.
        if (activitiesOpen) Positioned.fill(child: ShellDrawer(theme: theme)),
      ],
    );
  }
}
