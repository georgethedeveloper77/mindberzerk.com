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
      // The dock menu is the third panel carrying this strip, so it answers
      // the setting too. A menu that keeps its words while the other two drop
      // theirs reads as the setting having missed one.
      showActionLabels: theme.menuActionLabels,
      actions: [
        if (isPinned)
          MenuAction(
            icon: Icons.push_pin_outlined,
            label: host.t('shell.removeFromDock'),
            onTap: () => notifier.edit(
              (p) => HomeLayout.unpinFromDock(p, app.componentKey),
            ),
          )
        else
          MenuAction(
            icon: Icons.push_pin,
            label: host.t('shell.keepInDock'),
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
            label: host.t('shell.hideFromLaunchpad'),
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
            label: host.t('shell.takeOutOfDock'),
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

  /// An app dropped on the dock from the desktop or the drawer.
  ///
  /// Pins it and takes it off the home screen: the two surfaces hold ONE
  /// arrangement between them, and a drag that left a copy behind reads as the
  /// drag having failed.
  ///
  /// [capacity] comes from the build, because it is a function of the screen
  /// width and this dock is always horizontal. A pin past capacity is refused
  /// inside `pinToDock`, and the app then stays where it was rather than being
  /// lost between two surfaces.
  void _dockPin(String componentKey, int capacity) {
    ref.read(prefsProvider(widget.theme.spec.id).notifier).edit((p) {
      final pinned =
          HomeLayout.pinToDock(p, componentKey, capacity: capacity);
      final at = HomeLayout.slotOf(pinned, componentKey);
      return at == null
          ? pinned
          : HomeLayout.removeFromHome(pinned, at.page, at.index);
    });
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

    // ─── IS THE APP LIST ON SCREEN, ON EITHER KIND OF DISTRO ────────────
    //
    // `appsShowing` in `workspace_controller` answers exactly this and answers
    // it with `ref.read`, which is right for the one-shot question a PopScope
    // asks and wrong here: this decides what to BUILD, so it has to rebuild
    // when the page changes. Watched rather than read, and spelled out rather
    // than hidden behind a helper that would silently not rebuild.
    final appsPage = ref.watch(appsPageProvider);

    // ─── WHETHER THE DOCK LEAVES, AND WHO DECIDES ───────────────────────
    //
    // This was a `dockHidden` bool consumed by an `if`, and the dock blinked
    // out of existence rather than leaving. The decision did not change; where
    // it lands did. `activitiesOpen` is still a hard cut below, because
    // Launchpad is an overlay with no gesture to track, and the `desktop` case
    // is handed to `_DockSlide` as a page index so it can follow the swipe.
    //
    // Per distro, because the two workspace-surface distros want opposite
    // answers from the identical arrangement. Deepin's app list is a page you
    // swipe to and the dock staying put is one of its exclusive rows; Pocket's
    // is a page you swipe to and the dock must leave. Nothing but the theme can
    // tell those apart, which is what `dockReveal: "desktop"` says.
    //
    // 'apps' is deliberately NOT handled here. It is the GNOME dash, it belongs
    // to a shell that has one, and `gnome_shell` already computes `dockRevealed`
    // for it. Implementing it here would read as complete while being untested
    // on a shell no distro authors it for.
    //
    // ─── AND `appsUp` IS GONE WITH IT ──────────────────────────────────
    //
    // It computed whether the app list was on screen, from `appsPage` and
    // `activeWorkspace`, and the only thing that ever read it was `dockHidden`.
    // The slide needs the page INDEX rather than a boolean about it, because a
    // boolean is the answer after the swipe has finished and the whole point is
    // to move during it. `activeWorkspace` went too, for the same reason: the
    // PageController's live position is what `_DockSlide` reads, and the
    // settled page number cannot describe a drag in progress.

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
        // ─── IT SLIDES WITH THE THUMB, IT DOES NOT BLINK OUT ──────────────
        //
        // `if (!dockHidden)` removed the widget outright, so the dock vanished
        // between two frames while the library was still sliding in. On a flick
        // that reads as a glitch; on a slow drag it is worse, because the page
        // is halfway across and the dock has already gone.
        //
        // ─── TRACKED, NOT TIMED ────────────────────────────────────────────
        //
        // A 200ms curve fired when the page settles is the easy version and it
        // is wrong for this distro. Pocket's whole claim is that "nothing opens
        // or closes": the library is a place you swipe to, so the dock leaving
        // has to be part of the same gesture rather than a separate animation
        // that happens afterwards. Driven off the PageController, it is exactly
        // as far out as you have swiped, and swiping back brings it back.
        //
        // ─── AND IT STAYS MOUNTED ──────────────────────────────────────────
        //
        // Off-screen rather than absent. Unmounting mid-slide would drop the
        // dock's own state and, on a magnified dock, restart the hover
        // calculation from nothing the moment it returned.
        //
        // `activitiesOpen` is still a hard cut: Launchpad is an overlay that
        // appears over everything, not a page you drag toward, so there is no
        // gesture for the dock to track and a slide would just be a delay.
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
            child: _DockSlide(
              pages: _pages,
              // The page the dock must be gone by. Null when this distro keeps
              // its dock everywhere, and then the slide never runs at all.
              hideAtPage: theme.dockReveal == 'desktop' ? appsPage : null,
              child: AquaDock(
              entries: entries,
              palette: theme.palette,
              style: AquaDockStyle.parse(theme.dockStyle),
              hover: theme.dockHover,
              press: theme.dockPress,
              opacity: theme.dockOpacity,
              onLaunchpad: _openLaunchpad,
              // ─── ALWAYS ARMED ────────────────────────────────────────
              //
              // Unlike a reorder, a drop here has something to do on any dock:
              // pinning is how an auto-filled dock stops being automatic, so
              // refusing it on the docks with no pins would refuse the gesture
              // that makes pinning possible.
              onDropApp: (key) => _dockPin(key, capacity),
              ),
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

/// Slides [child] off the bottom edge as the pager approaches [hideAtPage].
///
/// ─── AN AnimatedBuilder ON THE CONTROLLER, NOT A STATE FLAG ────────────────
///
/// `PageController` is a `Listenable` that ticks on every pixel of a drag, so
/// listening to it gives the dock the gesture itself rather than a summary of
/// it delivered once the page has settled. That is the whole difference between
/// the dock stepping aside and the dock disappearing.
///
/// Only this subtree rebuilds. The shell's own build stays out of it, which
/// matters because it is rebuilding a dock, a workspace pager and a desklet
/// surface, and doing that sixty times a second during a swipe is exactly the
/// kind of thing the jank script would find.
class _DockSlide extends StatelessWidget {
  const _DockSlide({
    required this.pages,
    required this.hideAtPage,
    required this.child,
  });

  final PageController pages;

  /// The page index at which the dock should be fully gone, or null to never
  /// hide. Null is every distro but Pocket.
  final int? hideAtPage;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final target = hideAtPage;
    if (target == null) return child;

    return AnimatedBuilder(
      animation: pages,
      builder: (context, dock) {
        // ─── BEFORE THE FIRST LAYOUT THERE IS NO PAGE ────────────────────
        //
        // `hasClients` is false on the first frame and `page` throws rather
        // than returning null. Falling back to the controller's initial page
        // means the dock is drawn in the right place immediately rather than
        // sliding in from nowhere on launch.
        final live = pages.hasClients && pages.page != null
            ? pages.page!
            : pages.initialPage.toDouble();

        // 1.0 at the page before the library, 0.0 at the library itself, and
        // clamped so the dock neither over-travels on a bounce nor creeps back
        // up when the pager overscrolls past the last page.
        final t = (target - live).clamp(0.0, 1.0);

        // ─── DOWN BY ITS OWN HEIGHT PLUS A MARGIN ────────────────────────
        //
        // A fraction of the child's own height, so this needs no measurement
        // and stays correct whatever the dock's style and slot size work out
        // to. 1.4 rather than 1.0 because the dock sits `insets.bottom + 8`
        // above the edge and a plain 1.0 would leave its last few pixels
        // showing on a gesture-navigation phone.
        //
        // Opacity rides along on the same fraction. Sliding alone is enough on
        // a dark wallpaper and not enough on a bright one, where the plate
        // stays visible against the shelves until the last moment.
        return Opacity(
          opacity: t,
          child: FractionalTranslation(
            translation: Offset(0, (1 - t) * 1.4),
            child: dock,
          ),
        );
      },
      child: child,
    );
  }
}
