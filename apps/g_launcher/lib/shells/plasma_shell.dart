import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g_launcher/i18n/i18n.dart';
import 'package:g_launcher/platform/launcher_api.g.dart';
import '../features/home/workspaces/workspace_canvas.dart';

import '../../../data/prefs/home_layout.dart';
import '../../../data/prefs/prefs_repository.dart';
import '../../../data/repositories/app_repository.dart';
import '../../../data/repositories/shell_apps.dart';
import '../../../data/usage/usage_repository.dart';
import '../../../engine/effective_theme.dart';
import '../../../engine/theme_spec.dart'
    show PanelModule, TopBarSide;
import '../../../design/components/components.dart';
import '../../../features/desklets/desklet_edit.dart';
import '../../../features/dock/dock_metrics.dart';
import '../../../features/drawer/shell_drawer.dart';
import '../../../features/dock/aqua_dock_metrics.dart';
import '../../../features/drawer/drawer_actions.dart';
import '../../../features/home/aqua/aqua_dock.dart';
// `DockEntry` is declared in gnome_dock, not aqua_dock: the entry is the shared
// shape and only the SHELL of a dock differs, which is why both docks take it.
import '../../../features/home/gnome/gnome_dock.dart' show DockEntry;
import '../../../features/drawer/app_icon.dart';
import '../../../features/drawer/drawer_state.dart';
import '../../../features/gestures/gesture_layer.dart';
import '../../../features/home/desktop_hold.dart';
import '../../../features/home/workspaces/workspace_controller.dart';
import '../../../system/system_stats.dart';

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
      if (!_pages.hasClients) return;
      if ((_pages.page ?? 0).round() == next) return;
      _pages.animateToPage(
        next,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });

    final insets = MediaQuery.viewPaddingOf(context);

    // Watched, not read: entering and leaving edit mode has to rebuild both the
    // bar above the panel and the badges inside it.
    final editingPanel = ref.watch(deskletEditProvider).editingPanel;
    final side = theme.panelSide;

    // ONE instance, placed in one of four slots below. Built here so the four
    // `if`s stay one line each and cannot drift apart.
    final panel = _PlasmaPanel(theme: theme, insets: insets);

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
        // always horizontal and always directly above the workspace, because it
        // is a toolbar rather than a panel and a vertical strip of buttons 40dp
        // wide could not hold its labels.
        Column(
          children: [
            if (side == TopBarSide.top) panel,
            Expanded(
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
            if (editingPanel) _PanelEditBar(theme: theme),
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
                    ? (theme.panelHeight ?? _plasmaPanelHeight)
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
      opacity: theme.dockOpacity,
      // Kickoff is the launcher on this shell and it opens from the panel, so
      // a second way in from the dock would be a button that duplicates the one
      // three centimetres below it.
      onLaunchpad: () => openApps(ref),
    );
  }
}

/// The Breeze panel.
/// Breeze's panel is 48. These bound what the stepper can reach.
///
/// 36 is about where the task strip's labels stop being readable, and 72 is
/// where the panel starts eating the workspace it is supposed to sit beside.
/// Neither is a hard constraint in the layout; both are the range where the
/// result still looks like a Plasma panel.
const _minPanelHeight = 36.0;
const _maxPanelHeight = 72.0;
const _panelHeightStep = 4.0;

/// The modules the Add sheet offers.
///
/// ─── NOT ALL TEN, AND THE FOUR MISSING ARE MISSING ON PURPOSE ─────────────
///
/// `activities`, `network`, `memory` and `storage` exist in [PanelModule] and
/// this shell draws none of them: they are one widget over one stats
/// subscription living in `gnome_top_bar`, and the panel's own switch returns
/// an empty box for all four with a comment saying so.
///
/// Offering them here would let someone add a module that renders nothing,
/// which is the exact failure the empty-panel bug was. They come back the day
/// that readouts widget is lifted out of a file named after the GNOME bar, and
/// that lift is a refactor with its own decisions rather than a line here.
const _addableModules = [
  PanelModule.kickoff,
  PanelModule.tasks,
  PanelModule.pager,
  PanelModule.tray,
  PanelModule.clock,
  PanelModule.spacer,
];

/// The label for a module in the Add sheet.
///
/// A switch rather than a map, so a new module cannot be added to the enum and
/// silently arrive in this sheet with no name.
String _moduleLabel(BuildContext context, PanelModule m) => switch (m) {
      PanelModule.kickoff => context.t('shell.moduleKickoff'),
      PanelModule.tasks => context.t('shell.moduleTasks'),
      PanelModule.pager => context.t('shell.modulePager'),
      PanelModule.tray => context.t('shell.moduleTray'),
      PanelModule.clock => context.t('shell.moduleClock'),
      PanelModule.spacer => context.t('shell.moduleSpacer'),
      PanelModule.activities => context.t('shell.moduleActivities'),
      PanelModule.network => context.t('shell.moduleNetwork'),
      PanelModule.memory => context.t('shell.moduleMemory'),
      PanelModule.storage => context.t('shell.moduleStorage'),
    };

IconData _moduleIcon(PanelModule m) => switch (m) {
      PanelModule.kickoff => Icons.apps,
      PanelModule.tasks => Icons.view_agenda_outlined,
      PanelModule.pager => Icons.grid_view,
      PanelModule.tray => Icons.expand_less,
      PanelModule.clock => Icons.schedule,
      PanelModule.spacer => Icons.space_bar,
      PanelModule.activities => Icons.dashboard_outlined,
      PanelModule.network => Icons.swap_vert,
      PanelModule.memory => Icons.memory,
      PanelModule.storage => Icons.sd_storage_outlined,
    };

/// Append [add] to the panel.
///
/// APPENDED, never inserted. Ordering by drag is the obvious next want and it
/// is a different interaction with its own hit-testing; appending is the honest
/// version of what this build does, and a module in the wrong place can be
/// removed and re-added until reordering exists.
void _addModule(WidgetRef ref, EffectiveTheme theme,
    List<PanelModule> modules, PanelModule add) {
  HapticFeedback.mediumImpact();
  final next = [for (final m in modules) m.name, add.name];
  ref
      .read(prefsProvider(theme.spec.id).notifier)
      .edit((p) => p.copyWith(panelModules: next));
}

void _setHeight(WidgetRef ref, EffectiveTheme theme, double dp) {
  HapticFeedback.selectionClick();
  ref
      .read(prefsProvider(theme.spec.id).notifier)
      .edit((p) => p.copyWith(panelHeight: dp.clamp(_minPanelHeight, _maxPanelHeight)));
}

/// The four edges, with the current one marked.
///
/// A SHEET rather than four buttons in the bar. Edge is the least-used of the
/// three controls and the most expensive in width, and putting it inline would
/// have pushed Reset and Done off a 360dp phone at any raised font scale.
void _showPanelEdge(BuildContext context, WidgetRef ref, EffectiveTheme theme) {
  const sides = [
    (TopBarSide.bottom, 'shell.edgeBottom', Icons.border_bottom),
    (TopBarSide.top, 'shell.edgeTop', Icons.border_top),
    (TopBarSide.left, 'shell.edgeLeft', Icons.border_left),
    (TopBarSide.right, 'shell.edgeRight', Icons.border_right),
  ];

  ThemedSheet.show<void>(
    context,
    builder: (sheet) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (side, key, icon) in sides)
          ThemedListRow(
            icon: icon,
            title: context.t(key),
            // The current edge says so in its subtitle and stays tappable.
            // Marking it with a trailing widget would have been tidier and
            // `ThemedListRow` may well take one, but I have not read that file
            // and a guessed parameter is a compile error at best. Subtitle is
            // the slot this menu already uses in the Add sheet.
            subtitle:
                side == theme.panelSide ? context.t('shell.currentEdge') : null,
            onTap: () {
              Navigator.pop(sheet);
              HapticFeedback.mediumImpact();
              ref
                  .read(prefsProvider(theme.spec.id).notifier)
                  .edit((p) => p.copyWith(panelSide: side.name));
            },
          ),
      ],
    ),
  );
}

/// The Add sheet. Everything already on the panel is DIMMED rather than absent,
/// so the list never changes shape between openings and nobody has to work out
/// what disappeared.
void _showAddModule(BuildContext context, WidgetRef ref, EffectiveTheme theme) {
  final current = _currentModules(theme);

  ThemedSheet.show<void>(
    context,
    builder: (sheet) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final m in _addableModules)
          ThemedListRow(
            icon: _moduleIcon(m),
            title: _moduleLabel(context, m),
            // A spacer is the one module that can legitimately appear twice, so
            // it never dims: two spacers is how a panel gets a centred module.
            subtitle: (m != PanelModule.spacer && current.contains(m))
                ? context.t('shell.alreadyOnPanel')
                : null,
            onTap: (m != PanelModule.spacer && current.contains(m))
                ? null
                : () {
                    Navigator.pop(sheet);
                    _addModule(ref, theme, current, m);
                  },
          ),
      ],
    ),
  );
}

/// The panel as it stands: the user's if they have built one, the distro's
/// bottom panel if it authored one, else Plasma's default five.
///
/// ONE definition, used by both the Add sheet and the panel itself, because two
/// readings of "what is on the panel right now" would drift the first time a
/// fallback changed.
List<PanelModule> _currentModules(EffectiveTheme theme) {
  for (final p in theme.panels) {
    if (p.side == TopBarSide.bottom) return p.modules;
  }
  return _plasmaDefaultModules;
}

/// A minus or plus for the height stepper. Inert at the bounds rather than
/// hidden, so the control does not change width as you reach the end of it.
class _HeightStep extends StatelessWidget {
  const _HeightStep({
    required this.theme,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final EffectiveTheme theme;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: enabled ? onTap : null,
      visualDensity: VisualDensity.compact,
      icon: Icon(
        icon,
        size: 18,
        color: theme.palette.onDark
            .withValues(alpha: enabled ? 0.75 : 0.28),
      ),
    );
  }
}

/// Write [modules] minus [drop] as the user's own panel.
///
/// The FULL list every time, never a diff. The stored panel replaces the
/// distro's outright, so removing the tray from a five-module panel writes the
/// other four rather than a note about the tray. `LauncherPrefs.panelModules`
/// explains why a diff has no honest semantics once the distro's own panel can
/// change underneath it.
void _removeModule(
  WidgetRef ref,
  EffectiveTheme theme,
  List<PanelModule> modules,
  PanelModule drop,
) {
  HapticFeedback.mediumImpact();
  final kept = [
    for (final m in modules)
      if (m != drop) m.name,
  ];
  ref
      .read(prefsProvider(theme.spec.id).notifier)
      .edit((p) => p.copyWith(panelModules: kept));
}

/// The bar above the panel while it is being edited.
///
/// TWO ACTIONS ONLY, and Reset is one of them. A user who removes the clock,
/// the tray and the pager is looking at a coloured strip with no obvious way
/// back, so the way back ships in the same build as the way in rather than in a
/// later one. It is deliberately next to Done and deliberately not hidden
/// behind a confirm: everything it undoes is one long press away from being
/// redone, which is the test for whether a destructive action needs a gate.
class _PanelEditBar extends ConsumerWidget {
  const _PanelEditBar({required this.theme});

  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = theme.palette;
    final height = theme.panelHeight ?? _plasmaPanelHeight;

    // EITHER pref, not just the modules. Someone who only thickened the panel
    // has something to reset, and a Reset that ignored height would leave them
    // with no way back to the distro's own thickness.
    final edited = theme.prefs.panelModules != null ||
        theme.prefs.panelHeight != null ||
        theme.prefs.panelSide != null;

    return Material(
      color: p.bar.withValues(alpha: 0.96 * theme.barOpacity),
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            // ─── THE LEFT GROUP SCROLLS ──────────────────────────────────
            //
            // Add, Edge and the stepper are about 210dp at the default text
            // size, and Reset plus Done are another 110. That fits a 360dp
            // phone with nothing to spare, and stops fitting the moment the
            // system font scale goes up, which is the setting most likely to be
            // raised by the people who most need the bar to work.
            //
            // Scrolling the group is the version that cannot overflow at any
            // scale. Reset and Done stay pinned, because the two things you
            // must always be able to reach are the undo and the way out.
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => _showAddModule(context, ref, theme),
                      icon: Icon(Icons.add, size: 18, color: p.accent),
                      label: Text(
                        context.t('shell.addModule'),
                        style: TextStyle(color: p.accent, fontSize: 12.5),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _showPanelEdge(context, ref, theme),
                      icon: Icon(
                        Icons.border_outer,
                        size: 18,
                        color: p.onDark.withValues(alpha: 0.75),
                      ),
                      label: Text(
                        context.t('shell.panelEdge'),
                        style: TextStyle(
                          color: p.onDark.withValues(alpha: 0.75),
                          fontSize: 12.5,
                        ),
                      ),
                    ),

            // ─── A STEPPER, NOT A SLIDER ────────────────────────────────
            //
            // Panel height has about ten useful values and a wrong one is
            // instantly visible, so the control that matters is the one you can
            // nudge and read. A slider on a 44dp bar would also sit under the
            // thumb that is trying to see the result.
                    _HeightStep(
                      theme: theme,
                      icon: Icons.remove,
                      enabled: height > _minPanelHeight,
                      onTap: () =>
                          _setHeight(ref, theme, height - _panelHeightStep),
                    ),
                    Text(
                      '${height.round()}',
                      style: TextStyle(
                        color: p.onDark.withValues(alpha: 0.75),
                        fontSize: 12,
                        fontFamily: theme.typography.mono,
                      ),
                    ),
                    _HeightStep(
                      theme: theme,
                      icon: Icons.add,
                      enabled: height < _maxPanelHeight,
                      onTap: () =>
                          _setHeight(ref, theme, height + _panelHeightStep),
                    ),
                  ],
                ),
              ),
            ),
            // Absent until there is something to undo. A Reset that resets
            // nothing is a button that teaches the user it does nothing.
            if (edited)
              TextButton(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  ref
                      .read(prefsProvider(theme.spec.id).notifier)
                      .edit((x) => x.clearing(
                            panelModules: true,
                            panelHeight: true,
                            panelSide: true,
                          ));
                },
                child: Text(
                  context.t('shell.resetPanel'),
                  style: TextStyle(color: p.onDark.withValues(alpha: 0.75)),
                ),
              ),
            TextButton(
              onPressed: () => ref.read(deskletEditProvider.notifier).exit(),
              child: Text(
                context.t('shell.done'),
                style: TextStyle(color: p.accent),
              ),
            ),
            const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }
}

/// One module, plus its remove badge while the panel is being edited.
class _PanelSlot extends StatelessWidget {
  const _PanelSlot({
    required this.theme,
    required this.editing,
    required this.flexible,
    required this.onRemove,
    required this.child,
  });

  final EffectiveTheme theme;
  final bool editing;

  /// True for the task strip, whose child is an [Expanded]. A flex child must
  /// stay a direct child of the Row, so this slot BECOMES the Expanded rather
  /// than wrapping one.
  final bool flexible;

  final VoidCallback onRemove;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // ─── THE Expanded IS APPLIED HERE, NEVER BY THE CALLER ────────────────
    //
    // `Expanded` must be a direct child of the Row, and it may not sit inside
    // the Stack that draws the badge. So the switch above hands over the BARE
    // task strip and this slot decides: Stack first, flex outermost.
    //
    // Getting that order wrong is not a cosmetic bug. An Expanded inside a
    // Stack throws, and an Expanded wrapping another Expanded throws, so both
    // of the obvious shapes here fail at runtime rather than in review.
    final body = editing
        ? Padding(padding: const EdgeInsets.only(top: 6), child: child)
        : child;

    if (!editing) return flexible ? Expanded(child: body) : body;

    final stacked = Stack(
      clipBehavior: Clip.none,
      children: [
        // The strip fills the slot when it is the flexible one, so the badge
        // has something to sit on the corner of either way.
        flexible ? SizedBox.expand(child: body) : body,
        Positioned(
          top: -2,
          left: -2,
          child: GestureDetector(
            onTap: onRemove,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 16,
              height: 16,
              // ACCENT, not a red. There is no `danger` colour in
              // `ThemePalette` and inventing one for a badge would put a token
              // in the engine that exactly one widget reads. The badge already
              // says remove by being a minus on a circle, and a Breeze blue
              // badge is more Breeze than a red one would be.
              decoration: BoxDecoration(
                color: theme.palette.accent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.remove,
                size: 11,
                color: theme.palette.onDark,
              ),
            ),
          ),
        ),
      ],
    );

    return flexible ? Expanded(child: stacked) : stacked;
  }
}

/// Plasma's panel when the theme authors none.
///
/// The exact order the hardcoded Row had, kept as a constant rather than
/// written into the KDE theme.json alone, because EVERY plasma-shell distro
/// falls back here: Manjaro and Garuda both use this shell and neither should
/// need to restate the obvious to get a working panel.
///
/// No spacer. [PanelModule.tasks] is the flexible one, so the fixed modules
/// pack to both ends on their own.
const _plasmaDefaultModules = [
  PanelModule.kickoff,
  PanelModule.tasks,
  PanelModule.pager,
  PanelModule.tray,
  PanelModule.clock,
];

/// Breeze's panel thickness in dp, used when neither the theme nor the user has
/// set one. Was a literal `48` inside the SizedBox.
const _plasmaPanelHeight = 48.0;

class _PlasmaPanel extends ConsumerWidget {
  const _PlasmaPanel({required this.theme, required this.insets});

  final EffectiveTheme theme;

  /// The WHOLE window inset, not just the bottom one. A panel on the left has
  /// to clear a gesture bar at the foot of its own strip and a notch at the
  /// head of it, and a panel that only knew about the bottom would put its
  /// kickoff button under the camera.
  final EdgeInsets insets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apps = ref.watch(shellAppsProvider(theme));
    final frequent = ref.watch(frequentAppsProvider);
    final byKey = {for (final a in apps) a.componentKey: a};

    // Same source of truth as the GNOME dock: pins, else most-used, else the
    // alphabetical head so the task strip is never empty on first run.
    var keys = HomeLayout.dockKeys(
      theme.prefs,
      frequent: frequent,
      capacity: 8,
      defaultLimit: DockMetrics.defaultCount,
    );
    if (keys.isEmpty) {
      keys = [
        for (final a in apps.take(DockMetrics.defaultCount)) a.componentKey,
      ];
    }
    final taskKeys = [
      for (final k in keys)
        if (byKey[k] != null) k,
    ];

    // ─── THE PANEL IS A LIST NOW, NOT A LITERAL ──────────────────────────
    //
    // Every child below used to be written out in source order, which meant
    // the arrangement of the most configurable desktop in Linux was the one
    // thing in this app a theme could not touch. A distro could not ship a
    // different panel without an APK release, and a user could not rearrange
    // one at all, which is the review this work started from.
    //
    // ─── ONE READING OF WHAT IS ON THE PANEL ─────────────────────────────
    //
    // This inlined its own lookup: walk `theme.panels` for the bottom one, fall
    // back to Plasma's five. The Add sheet needs the identical answer, and two
    // copies of it would drift the first time either fallback changed, so it
    // moved out to `_currentModules` and both call that.
    //
    // The bottom-edge match is the part worth keeping in mind. `theme.panels`
    // can contain a SYNTHESISED top bar, built from `topBar` and `topBarSide`
    // for a theme that authored no panels of its own, and handing this bottom
    // panel a top bar's module list would render it completely empty.
    final modules = _currentModules(theme);

    // ─── HEIGHT COMES FROM THE RESOLVER NOW ──────────────────────────────
    //
    // It read `authored?.height` directly, which was fine while the only source
    // was the theme. The user can set it too, so it resolves the way every
    // other scalar does and arrives already merged. Reading the PanelSpec here
    // as well would put the same question in two places, and the two would
    // eventually disagree.
    final height = theme.panelHeight ?? _plasmaPanelHeight;
    final side = theme.panelSide;
    final vertical = side.isVertical;

    final editing = ref.watch(deskletEditProvider).editingPanel;

    return GestureDetector(
      // ─── HOLD THE PANEL TO EDIT IT ──────────────────────────────────────
      //
      // Long press only, claiming no axis, which is the same arrangement
      // `DesktopHold` uses on the workspace and for the same reason: the task
      // strip below scrolls horizontally, and claiming that axis here would
      // fight it for every flick.
      //
      // The callback is NULL rather than the branch returning an unwrapped
      // child, so the tree keeps its shape and no recognizer is registered when
      // there is nothing to enter. Null on a distro without `panelEdit`, and
      // null again once editing, where a second long press has nothing to do.
      behavior: HitTestBehavior.translucent,
      onLongPress: (!theme.panelEdit || editing)
          ? null
          : () {
              HapticFeedback.mediumImpact();
              ref.read(deskletEditProvider.notifier).enterPanel();
            },
      child: Material(
        // The authored 0.96 scaled by the user's bar setting, not replaced: a
        // Breeze panel is very nearly solid on purpose, and this keeps that
        // relationship at every slider position.
        color: theme.palette.bar.withValues(alpha: 0.96 * theme.barOpacity),
        child: Padding(
          // ─── ONLY THE EDGES THIS PANEL DOES NOT OCCUPY ─────────────────
          //
          // A bottom panel clears the gesture bar beneath it and nothing else,
          // which is what the single `bottom` here used to say. A LEFT panel
          // has to clear the notch above it and the gesture bar below it, along
          // the whole length of its strip, and would otherwise put its kickoff
          // button under the camera.
          padding: EdgeInsets.only(
            bottom: side == TopBarSide.top ? 0 : insets.bottom,
            top: side == TopBarSide.bottom ? 0 : insets.top,
            left: side == TopBarSide.right ? insets.left : 0,
            right: side == TopBarSide.left ? insets.right : 0,
          ),
          child: SizedBox(
            // The stepper writes ONE number and it means thickness either way:
            // a vertical panel's height is its width. Two prefs would reset the
            // panel every time it changed orientation, which is the opposite of
            // what someone who just set it expects.
            height: vertical ? null : height,
            width: vertical ? height : null,
            child: Flex(
              direction: vertical ? Axis.vertical : Axis.horizontal,
              children: [
              for (final m in modules)
                _PanelSlot(
                  theme: theme,
                  editing: editing,
                  // The task strip is the flexible module, so its slot has to
                  // be flexible too. Wrapping an Expanded in a plain widget
                  // would drop the flex and pack the panel to the leading edge
                  // the moment edit mode turned on, which reads as the panel
                  // breaking rather than as it becoming editable.
                  flexible: m == PanelModule.tasks,
                  onRemove: () => _removeModule(ref, theme, modules, m),
                  child: switch (m) {
                  PanelModule.kickoff => _KickoffButton(
                      accent: theme.palette.accent,
                      onTap: () => openApps(ref),
                    ),

                  // EXPANDED, and that is why this panel needs no spacer. The
                  // task strip is the only module that wants whatever is left,
                  // exactly as a real taskbar does, so a Plasma panel packs its
                  // fixed modules to both ends without one.
                    // BARE, no Expanded. `_PanelSlot` applies the flex, because
                    // it also has to apply the Stack that carries the badge and
                    // the two have a required order: Stack inside, flex outside.
                    // Scrolls ALONG the panel. Left horizontal, a vertical
                    // strip would have tried to scroll its 40dp width and the
                    // task list would have been unreachable past the first icon.
                    PanelModule.tasks => ListView(
                        scrollDirection:
                            vertical ? Axis.vertical : Axis.horizontal,
                        children: [
                          for (final k in taskKeys)
                            _TaskButton(
                              vertical: vertical,
                              entry: byKey[k]!,
                              onTap: () {
                                ref
                                    .read(appListProvider.notifier)
                                    .launch(byKey[k]!);
                                ref.read(usageProvider.notifier).record(k);
                              },
                            ),
                        ],
                      ),
                    PanelModule.pager => _Pager(theme: theme),
                  PanelModule.tray => _Tray(theme: theme),
                  PanelModule.clock =>
                    _PanelClock(
                      onDark: theme.palette.onDark,
                      narrow: vertical,
                    ),
                  PanelModule.spacer => const Spacer(),

                  // ─── GNOME'S THREE READOUTS, NOT DRAWN HERE ────────────
                  //
                  // Not an oversight and not a TODO. They are one widget over
                  // one stats subscription in `gnome_top_bar`, and lifting that
                  // widget out of a file called gnome_top_bar so a Breeze panel
                  // can borrow it is a refactor with its own decisions. A theme
                  // listing them on a Plasma panel gets nothing until that
                  // happens, which the compiler will keep pointing at because
                  // this switch has no catch-all.
                  PanelModule.activities ||
                  PanelModule.network ||
                  PanelModule.memory ||
                    PanelModule.storage =>
                      const SizedBox.shrink(),
                  },
                ),
              // The trailing gutter turns with the panel: on a vertical strip
              // a 12dp WIDTH would do nothing at all and the clock would sit
              // against the bottom edge.
              SizedBox(
                width: vertical ? 0 : 12,
                height: vertical ? 12 : 0,
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KickoffButton extends StatelessWidget {
  const _KickoffButton({required this.accent, required this.onTap});

  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Center(
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.grid_view_rounded, size: 20, color: accent),
          ),
        ),
      ),
    );
  }
}

class _TaskButton extends StatelessWidget {
  const _TaskButton({
    required this.entry,
    required this.onTap,
    required this.vertical,
  });

  final AppEntry entry;
  final VoidCallback onTap;

  /// Which way the padding runs. The icon itself needs no change, because this
  /// button never carried a label: a Plasma task strip on a phone is icons, and
  /// that is the one thing about it that was already orientation-neutral.
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: vertical
            ? const EdgeInsets.symmetric(vertical: 4)
            : const EdgeInsets.symmetric(horizontal: 4),
        child: Center(child: AppIcon(entry: entry, size: 30)),
      ),
    );
  }
}

/// KDE's virtual-desktop pager applet, in the panel: numbered squares, the
/// active one filled with the accent.
class _Pager extends ConsumerWidget {
  const _Pager({required this.theme});

  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(workspaceCountProvider);
    final active = ref.watch(activeWorkspaceProvider);
    final onDark = theme.palette.onDark;

    // The squares run ALONG the panel, so they stack on a vertical one. A Row
    // here would have laid four 16dp squares across a 40dp strip and shown the
    // first two.
    return Flex(
      direction: theme.panelSide.isVertical ? Axis.vertical : Axis.horizontal,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          GestureDetector(
            onTap: () => ref.read(activeWorkspaceProvider.notifier).goTo(i),
            child: Container(
              width: 16,
              height: 16,
              margin: theme.panelSide.isVertical
                  ? const EdgeInsets.symmetric(vertical: 2)
                  : const EdgeInsets.symmetric(horizontal: 2),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: i == active
                    ? theme.palette.accent.withValues(alpha: 0.9)
                    : Colors.transparent,
                border: Border.all(color: onDark.withValues(alpha: 0.35)),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                '${i + 1}',
                style: TextStyle(
                  fontFamily: theme.typography.mono,
                  fontSize: 9,
                  color: i == active
                      ? onDark
                      : onDark.withValues(alpha: 0.7),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// A small tray: wifi, volume, and battery when it can be read. Nullable stats
/// hide their glyph rather than showing a placeholder.
class _Tray extends ConsumerWidget {
  const _Tray({required this.theme});

  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final battery = ref.watch(systemStatsProvider).asData?.value.batteryPercent;
    final c = theme.palette.onDark.withValues(alpha: 0.75);

    final vertical = theme.panelSide.isVertical;
    // The gap turns with the tray. A `width` between stacked icons is a no-op,
    // and the three would have touched.
    final gap = SizedBox(
      width: vertical ? 0 : 8,
      height: vertical ? 8 : 0,
    );

    return Flex(
      direction: vertical ? Axis.vertical : Axis.horizontal,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.wifi, size: 15, color: c),
        gap,
        Icon(Icons.volume_up_outlined, size: 15, color: c),
        if (battery != null) ...[
          gap,
          Icon(Icons.battery_std, size: 15, color: c),
          SizedBox(width: vertical ? 0 : 2, height: vertical ? 2 : 0),
          Text(
            '$battery%',
            style: TextStyle(
              fontFamily: theme.typography.mono,
              fontSize: 11,
              color: c,
            ),
          ),
        ],
      ],
    );
  }
}

class _PanelClock extends ConsumerWidget {
  const _PanelClock({required this.onDark, required this.narrow});

  final Color onDark;

  /// True on a vertical panel, where the strip is about 40dp wide. The time
  /// drops a point to fit and the DATE goes entirely: "Thu 20 Aug" cannot be
  /// set in 40dp without either ellipsising or being turned on its side, and a
  /// clock nobody can read is worse than a clock with no date on it.
  final bool narrow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider).asData?.value ?? DateTime.now();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          formatTime(now),
          style: TextStyle(
            color: onDark,
            fontSize: narrow ? 11 : 14,
            fontWeight: FontWeight.w600,
            height: 1.0,
          ),
        ),
        if (!narrow)
          Text(
            formatDateShort(now),
            style: TextStyle(
              color: onDark.withValues(alpha: 0.7),
              fontSize: 9.5,
              height: 1.3,
            ),
          ),
      ],
    );
  }
}