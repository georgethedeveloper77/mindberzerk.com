import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g_launcher/i18n/i18n.dart';

import '../data/prefs/hidden_apps.dart';
import '../data/prefs/home_layout.dart';
import '../data/prefs/launcher_prefs.dart';
import '../data/prefs/prefs_repository.dart';
import '../data/repositories/app_repository.dart';
import '../data/repositories/shell_apps.dart';
import '../data/usage/usage_repository.dart';
import '../design/branded_message.dart';
import '../design/components/components.dart';
import '../design/icon_sizing.dart';
import '../design/liquid_glass.dart';
import '../engine/effective_theme.dart';
// TopBarSide: the menu bar now asks whether this distro has a top panel at all.
import '../engine/theme_spec.dart';
import '../features/desklets/desklet_edit.dart';
import '../features/dock/aqua_dock_metrics.dart';
import '../features/dock/dock_extent.dart';
import '../features/drawer/app_icon.dart';
import '../features/drawer/drawer_drag.dart';
import '../features/drawer/drawer_state.dart';
import '../features/drawer/folder_overlay.dart';
import '../features/drawer/library_view.dart' show openSearch;
import '../features/drawer/shell_drawer.dart';
import '../features/gestures/gesture_actions.dart';
import '../features/gestures/gesture_layer.dart';
import '../features/home/aqua/aqua_dock.dart';
import '../features/home/aqua/aqua_menu_bar.dart';
import '../features/home/gnome/desktop_menu.dart';
import '../features/home/gnome/gnome_dock.dart' show DockEntry;
import '../features/home/pocket/pocket_edit_bar.dart';
import '../features/home/workspaces/workspace_canvas.dart';
import '../features/home/workspaces/workspace_controller.dart';
import '../features/panel/applets/panel_battery.dart';
import '../features/panel/applets/panel_tray_button.dart';
import '../features/panel/modules/panel_clock_module.dart';
import '../platform/launcher_api.g.dart';
import 'safe_page.dart';

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

  /// A vertical swipe on the home, fired through the user's Gesture bindings.
  ///
  /// Only on a sideways-paging home, where the pager claims no vertical drag.
  /// Pocket defaults swipe down to search; every binding stays the user's.
  Future<void> _swipe(Gesture gesture) => runGesture(
        ref,
        bindingFor(widget.theme, gesture),
        onActivities: _openLaunchpad,
        onShowDock: () {},
        onSearch: () => openSearch(ref),
      );

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

  /// The dock key a drag carries: the component key for an app, the
  /// `folder:<id>` entry for a folder.
  static String _keyOf(DrawerDrag drag) => switch (drag) {
        AppDrag(:final componentKey) => componentKey,
        FolderDrag(:final folderId) => HomeLayout.dockFolderKey(folderId),
      };

  /// Something let go in a gap on the dock: an arrival, or a move along it.
  ///
  /// [order] and [gap] come from the dock, which knows what it drew; the key
  /// either side of the gap is what the pin is placed against. [visible] is
  /// the whole dock as drawn, so an auto-filled dock first becomes the pins
  /// it was showing (see `HomeLayout.adoptDock`).
  ///
  /// The arrival leaves wherever it was: off the grid (one arrangement between
  /// the two surfaces, never a copy), or out of the folder it was dragged
  /// from. A full dock refuses inside `pinToDockAt`, and then nothing moves.
  void _dockDropAt(
    DrawerDrag drag,
    List<String> order,
    int gap, {
    required List<String> visible,
    required int capacity,
  }) {
    final theme = widget.theme;
    final key = _keyOf(drag);
    final before = gap < order.length ? order[gap] : null;
    final after = gap > 0 && gap - 1 < order.length ? order[gap - 1] : null;
    var refused = false;

    ref.read(prefsProvider(theme.spec.id).notifier).edit((p) {
      var next = HomeLayout.adoptDock(p, visible);
      if (drag is AppDrag && drag.from == DragOrigin.folder) {
        final f = HomeLayout.folderOf(next, key);
        if (f != null) {
          next = HomeLayout.removeFromFolder(
            next,
            f.id,
            key,
            capacity: theme.rows * theme.cols,
          );
        }
      }
      final pinned = HomeLayout.pinToDockAt(
        next,
        key,
        beforeKey: before,
        afterKey: after,
        capacity: capacity,
      );
      if (identical(pinned, next)) {
        refused = true;
        return p;
      }
      return HomeLayout.takeOffHome(pinned, key);
    }).then((_) {
      if (refused) _dockFull();
    });
  }

  /// An app held on a dock icon's centre: into that folder, or a new one.
  void _dockDropOnto(
    DrawerDrag drag,
    String ontoKey, {
    required List<String> visible,
  }) {
    if (drag is! AppDrag) return;
    final theme = widget.theme;
    final key = drag.componentKey;
    ref.read(prefsProvider(theme.spec.id).notifier).edit((p) {
      var next = HomeLayout.adoptDock(p, visible);
      if (drag.from == DragOrigin.folder) {
        final f = HomeLayout.folderOf(next, key);
        if (f != null) {
          next = HomeLayout.removeFromFolder(
            next,
            f.id,
            key,
            capacity: theme.rows * theme.cols,
          );
        }
      }
      final folded = HomeLayout.dockFolder(
        next,
        ontoKey: ontoKey,
        dropKey: key,
        // The same id shape the home grid stamps, so the two kinds of folder
        // are indistinguishable everywhere a folder is looked up by id.
        newFolderId: () =>
            'f${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}',
      );
      return identical(folded, next) ? p : folded;
    });
  }

  /// A `folder:<id>` dock key whose folder still exists.
  bool _isDockFolder(String key) {
    final id = HomeLayout.dockFolderIdOf(key);
    return id != null && HomeLayout.folder(widget.theme.prefs, id) != null;
  }

  /// A dock folder as an entry: Liquid Glass with its first nine apps, tap to
  /// open it where it is, hold for its menu.
  DockEntry _folderEntry(
    String key,
    AppFolder folder,
    Map<String, AppEntry> byKey,
    double size,
  ) {
    return DockEntry(
      id: key,
      folderId: folder.id,
      label: folder.name,
      isPinned: true,
      icon: _DockFolderIcon(
        theme: widget.theme,
        members: [
          for (final m in folder.members)
            if (byKey[m] case final app?) app,
        ],
        // The app icons' size, so a folder never stands out from them.
        size: size,
      ),
      onTap: () => showHomeFolderOverlay(context, ref, widget.theme, folder.id),
      onLongPress: (anchor) => _dockFolderMenu(folder, anchor),
    );
  }

  /// The dock is full: the dock has already shaken, this says why.
  void _dockFull() {
    if (!mounted) return;
    context.showMessage(context.t('shell.dockFull'));
  }

  /// The edit-mode badge on a dock FOLDER. An app's badge opens the same menu
  /// its long press does.
  void _dockFolderMenu(AppFolder folder, Rect? anchor) {
    final theme = widget.theme;
    final notifier = ref.read(prefsProvider(theme.spec.id).notifier);
    final capacity = theme.rows * theme.cols;
    final host = context;
    AnchoredMenu.show(
      context: context,
      chrome: ChromeData.fromPalette(
        theme.palette,
        typography: theme.typography,
        textScale: theme.textScale,
        family: theme.chromeFamily,
        opacity: theme.surfaceOpacity,
        panelBlur: theme.panelBlur,
        panelTint: theme.panelTint,
        panelRadius: theme.panelRadius,
      ),
      anchor: anchor,
      width: 244,
      title: folder.name,
      showActionLabels: theme.menuActionLabels,
      actions: [
        MenuAction(
          icon: Icons.open_in_new,
          label: host.t('shell.moveToHomeScreen'),
          onTap: () => notifier.edit((p) {
            final page = ref.read(activeWorkspaceProvider);
            final slot = HomeLayout.lastFreeSlot(p, page, capacity, theme.cols);
            if (slot == null) return p;
            return HomeLayout.placeFolderAt(
              p,
              folder.id,
              page: page,
              index: slot,
              capacity: capacity,
              cols: theme.cols,
            );
          }),
        ),
        MenuAction(
          icon: Icons.unfold_more,
          label: host.t('drawer.ungroup'),
          onTap: () {
            if (folder.members.length >
                HomeLayout.dissolveRoom(
                  theme.prefs,
                  folder.id,
                  capacity: capacity,
                )) {
              host.showMessage(host.t('drawer.ungroupNoRoom'));
              return;
            }
            notifier.edit(
              (p) => HomeLayout.dissolve(p, folder.id, capacity: capacity),
            );
          },
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
      // `pageOrNull`, not `hasClients` plus `page`: see `safe_page.dart`.
      final at = _pages.pageOrNull;
      if (at == null || at.round() == next) return;
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
    //
    // A distro that authors `dockCapacity` (Pocket: four) gets exactly that,
    // never more than fits.
    final fits = AquaDockMetrics.capacityFor(
      MediaQuery.sizeOf(context).width * 0.92,
    );
    final authored = theme.dockCapacity;
    final capacity =
        authored == null ? fits : (authored < fits ? authored : fits);
    final editing = ref.watch(deskletEditProvider).editingApps;

    // ─── A PHONE DOCK'S ICONS ARE THE HOME ICONS ──────────────────────
    //
    // On a phone home (Pocket) the dock draws exactly the box the home grid
    // draws (`IconSizing.phoneBoxFor`), so the two read as one size whatever
    // icon look is on, and a full dock sits in the grid's columns: the gap
    // between two dock icons is the grid's column pitch less one box.
    double? dockRest;
    double? dockSpacing;
    if (theme.phoneHome) {
      final width = MediaQuery.sizeOf(context).width;
      final cellW = (width - 24 - (theme.cols - 1) * 8) / theme.cols;
      dockRest = IconSizing.phoneBoxFor(width, theme.cols);
      dockSpacing = cellW + 8 - dockRest;
    }
    // Rendered AT that size on a phone dock, which never swells: scaling a
    // peak-size icon up to the box would blur it.
    final dockIconSize = dockRest ?? AquaDockMetrics.peakSlot;

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
        if (byKey[key] != null || _isDockFolder(key)) key,
    ];

    final entries = <DockEntry>[
      for (final key in dockKeys)
        if (HomeLayout.dockFolderIdOf(key) case final id?)
          _folderEntry(
            key,
            HomeLayout.folder(theme.prefs, id)!,
            byKey,
            dockIconSize,
          )
        else
          DockEntry(
            id: key,
            label: byKey[key]!.label,
            isPinned: pinned.contains(key),
            // Built once at the PEAK size and scaled down by the dock's FittedBox.
            // Building at the resting size and scaling UP would blur every icon
            // the moment it magnified, which is the one thing a dock this showy
            // cannot afford.
            icon: AppIcon(entry: byKey[key]!, size: dockIconSize),
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
                  clear: theme.barClear,
                  tray: theme.barClear
                      ? PanelTrayButton(
                          palette: AquaMenuBar.clearPalette(theme.palette),
                          stacked: false,
                          compact: theme.statusBar,
                        )
                      : null,
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
                  onVerticalDragEnd:
                      theme.workspaceAxis == WorkspaceAxis.horizontal
                          ? (d) {
                              final v = d.primaryVelocity ?? 0;
                              if (v < -400) _swipe(Gesture.swipeUp);
                              if (v > 400) _swipe(Gesture.swipeDown);
                            }
                          : null,
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
                onDropAt: (drag, order, gap) => _dockDropAt(
                  drag,
                  order,
                  gap,
                  visible: dockKeys,
                  capacity: capacity,
                ),
                onDropOnto: (drag, onto) =>
                    _dockDropOnto(drag, onto, visible: dockKeys),
                onFull: _dockFull,
                onRemove: (entry, anchor) => entry.onLongPress?.call(anchor),
                capacity: capacity,
                folders: theme.dockFolders,
                editing: editing,
                // ─── THE DOCK'S TRAY, ON A DESKTOP WITH NO TOP BAR ──────
                //
                // Deepin's fashion dock ends with the status a top bar would
                // carry. Under the status rule: battery and time only when
                // the user has handed the status row to the desktop.
                tray: theme.dockTray ? _DockTray(theme: theme) : null,
                glass: theme.glass,
                glassDark: theme.glassDark,
                launcherSlot: theme.dockLauncher,
                restSlot: dockRest,
                restSpacing: dockSpacing,
                trayWidth:
                    theme.dockTray ? _DockTray.widthFor(theme) : 0,
              ),
            ),
          ),

        // ─── THE SEARCH BUTTON ────────────────────────────────────────────
        //
        // Above the dock, riding the same slide: it belongs to the home and
        // leaves with the dock when the library arrives. Positioned from the
        // dock's measured height, so a dock that grows does not cover it.
        // Not while a phone home is being edited: Edit and Done own the
        // screen then, as on a phone.
        if (!activitiesOpen &&
            theme.homeSearchPill &&
            !(editing && theme.phoneHome))
          Positioned(
            left: 0,
            right: 0,
            bottom: insets.bottom +
                8 +
                (ref.watch(dockExtentProvider) ?? AquaDockMetrics.reserve) +
                10,
            child: _DockSlide(
              pages: _pages,
              hideAtPage: theme.dockReveal == 'desktop' ? appsPage : null,
              child: Center(child: _SearchPill(theme: theme)),
            ),
          ),

        // ShellDrawer directly; `_Launchpad` was a back contract and nothing
        // else. The interim note about real Launchpad being paged rather than
        // scrolling lives in shell_drawer.dart, which is where the decision
        // actually is.
        if (activitiesOpen) Positioned.fill(child: ShellDrawer(theme: theme)),

        // A phone home's edit mode: Edit and Done at the top, home undimmed.
        if (editing && theme.phoneHome && !activitiesOpen)
          Positioned.fill(child: PocketEditBar(theme: theme)),
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
/// The home's Search button: a small glass pill that opens search.
class _SearchPill extends ConsumerWidget {
  const _SearchPill({required this.theme});

  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = context.t('drawer.searchApps');
    final ink = theme.palette.onDark;
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          openSearch(ref);
        },
        // 44dp tall for the thumb; the pill drawn inside is 32.
        child: SizedBox(
          height: 44,
          child: Center(
            child: LiquidGlass(
              radius: BorderRadius.circular(16),
              dark: theme.glassDark,
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search, size: 16, color: ink),
                  const SizedBox(width: 6),
                  Text(
                    context.t('home.search'),
                    style: TextStyle(
                      fontFamily: theme.typography.display,
                      fontSize: 13 * theme.textScale,
                      fontWeight: FontWeight.w600,
                      color: ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The tray at the right end of a dock that carries one.
class _DockTray extends StatelessWidget {
  const _DockTray({required this.theme});

  final EffectiveTheme theme;

  /// Divider and margins, the quick-settings button, and the readouts when
  /// the status row is the desktop's.
  static double widthFor(EffectiveTheme theme) =>
      13 + 44 + (theme.statusBar ? 0 : 104);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (!theme.statusBar) ...[
          const Flexible(child: PanelBatteryModule()),
          Flexible(
            child: PanelClockModule(
              onDark: theme.palette.onDark,
              narrow: false,
            ),
          ),
        ],
        SizedBox(
          width: 44,
          child: PanelTrayButton(
            palette: theme.palette,
            stacked: false,
            compact: true,
          ),
        ),
      ],
    );
  }
}

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
        final live = pages.pageOrNull ?? pages.initialPage.toDouble();

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

/// A dock folder's face: the home grid's glass folder, three by three.
class _DockFolderIcon extends StatelessWidget {
  const _DockFolderIcon({
    required this.theme,
    required this.members,
    required this.size,
  });

  final EffectiveTheme theme;
  final List<AppEntry> members;
  final double size;

  /// Between two minis, on both axes. The grid's number.
  static const _gap = 2.0;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * theme.icons.cornerRadius);
    final padding = size * 0.12;
    final inner = size - padding * 2;
    // A hair under the exact share, so rounding never wraps the last mini.
    final mini = (inner - _gap * 2) / 3 - 0.01;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        gradient: LiquidGlass.fill(dark: theme.glassDark),
        borderRadius: radius,
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: LiquidGlass.edge),
        gradient: LiquidGlass.rim(BorderRadius.zero).gradient,
      ),
      child: Wrap(
        spacing: _gap,
        runSpacing: _gap,
        children: [
          for (final m in members.take(9)) AppIcon(entry: m, size: mini),
        ],
      ),
    );
  }
}
