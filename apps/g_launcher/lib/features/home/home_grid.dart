import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/prefs/home_layout.dart';
import '../../data/prefs/launcher_prefs.dart';
import '../../data/prefs/prefs_repository.dart';
import '../../data/repositories/app_repository.dart';
import '../../engine/effective_theme.dart';
import '../dock/dock_insets.dart';
import '../../data/repositories/shell_apps.dart';
import '../../platform/launcher_api.g.dart';
import '../../design/components/components.dart';
import '../../design/grid_metrics.dart';
import '../../design/icon_sizing.dart';
import '../../design/components/press_pop.dart';
import '../drawer/app_icon.dart';
import '../drawer/drawer_actions.dart';
import 'package:g_launcher/i18n/i18n.dart';
import '../drawer/folder_overlay.dart';
// deskletEditProvider and EditMode.apps: the jiggle state lives here rather
// than in a local bool, because the pager, the desktop hold and back all read
// it. See DeskletEditState.
import '../desklets/desklet_edit.dart';

/// The home workspace: apps, folders, drag-and-drop.
///
/// All the state logic lives in HomeLayout (pure, tested). This file does
/// gestures and paint, nothing more — which is why "I dragged an app into a
/// folder and lost it" is a class of bug we can actually rule out.
/// The desktop grid, and the ticker that jiggles it.
///
/// ─── ONE TICKER, NOT ONE PER ICON ───────────────────────────────────────────
///
/// `library_view` learned this first and wrote it down: with a screen full of
/// apps, a controller per tile is a ticker per tile, and on a budget phone that
/// is the difference between a jiggle and a stutter. One animation drives every
/// icon here too, and the phase that stops them moving in lockstep comes from
/// each tile's own INDEX rather than its own clock, so it is stable across
/// rebuilds. A random phase would resettle every icon on every frame that
/// rebuilt the grid.
///
/// Stateful rather than a provider because a ticker needs a vsync and a
/// dispose, neither of which belongs in Riverpod. What IS in a provider is
/// whether edit mode is on, and that is [EditMode.apps] rather than a local
/// bool for the reason its own doc gives: the pager, the desktop hold and back
/// all have to know, and they already read `active`.
class HomeGrid extends ConsumerStatefulWidget {
  const HomeGrid({super.key, required this.theme, required this.page});

  final EffectiveTheme theme;

  /// ─── WHICH WORKSPACE THIS GRID IS ─────────────────────────────────────
  ///
  /// Every read in this file used to be `HomeLayout.itemAt(prefs, 0, index)`,
  /// with the page hardcoded to zero. `HomeLayout` has been page-aware from the
  /// start; the widget simply threw the parameter away, so swiping to workspace
  /// two showed workspace one's icons and dropping anything there wrote it back
  /// to page one. It was invisible only because nothing has mounted this widget
  /// since the desktop grid was removed.
  final int page;

  @override
  ConsumerState<HomeGrid> createState() => _HomeGridState();
}

class _HomeGridState extends ConsumerState<HomeGrid>
    with SingleTickerProviderStateMixin {
  late final AnimationController _jiggle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  );

  @override
  void dispose() {
    _jiggle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final page = widget.page;

    // ─── THE TICKER FOLLOWS THE PROVIDER, NOT THE CALL SITES ─────────────
    //
    // Started and stopped from the watched state rather than from the places
    // that enter and exit, because there are more than two of those: the
    // desktop menu enters, back exits, and anything that ever calls `exit()`
    // would also have to remember to stop this. Following the state means the
    // animation cannot be left running by a path nobody thought of.
    final editing = ref.watch(deskletEditProvider).editingApps;
    if (editing && !_jiggle.isAnimating) {
      _jiggle.repeat(reverse: true);
    } else if (!editing && _jiggle.isAnimating) {
      _jiggle.stop();
      _jiggle.value = 0;
    }

    final apps = ref.watch(shellAppsProvider(theme));
    final byKey = {for (final a in apps) a.componentKey: a};
    final prefs = theme.prefs;
    final capacity = theme.rows * theme.cols;

    // ─── NO SEEDED DESKTOP ────────────────────────────────────────────────
    //
    // This began `final seeded = prefs.homeItems.isEmpty;` and, on a desktop
    // nobody had arranged yet, drew the first N apps so the screen would not
    // look broken. What it actually produced was a screen that looked finished
    // and was inert: those cells were built with `slot: null`, so long press did
    // nothing on any of them, and they were not wrapped in `_Draggable`, so they
    // could not be moved either. A desktop full of icons that refuse every
    // gesture is a worse first impression than an empty one, and it is the
    // literal complaint in the review that started this work.
    //
    // An empty desktop is also the honest one. KDE's Folder View shows the
    // contents of a folder that is empty on a fresh install, so nothing is what
    // Plasma actually does. A distro that wants a populated desktop out of the
    // box can author it, the same way it authors desklets: `StarterDesktop`
    // already applies authored placements once per theme, through the same
    // clamps a user drag goes through.

    // ─── THE CELL IS MEASURED, NOT GUESSED ────────────────────────────────
    //
    // This was `labelLines > 1 ? 0.72 : 0.8`, a number that knew nothing about
    // the icon size, the font size or the SYSTEM font scale. The drawer had the
    // same constant and it was wrong in both directions: too short clipped a
    // second label line, too tall left dead space inside every tile so the row
    // gaps read as uneven. `GridMetrics` replaced it there and the home grid
    // was never brought across, which is how one phone ended up with two grids
    // measuring the same content differently.
    //
    // LayoutBuilder rather than MediaQuery width: the home grid sits inside a
    // workspace that a vertical panel can narrow, and sizing to the screen
    // would overflow by the panel's width on exactly the distros that have one.
    return LayoutBuilder(
      builder: (context, constraints) {
        const pad = 12.0;
        const crossGap = 8.0;
        final cols = theme.cols;
        final cellW =
            (constraints.maxWidth - pad * 2 - (cols - 1) * crossGap) / cols;

        // Through IconSizing, so a distro's `iconScale` reaches the home grid
        // the same way it reaches the drawer and the dock. `theme.iconSizeDp`
        // is the legacy flat number and is deliberately not consulted here.
        final iconSize = IconSizing.inCell(cellW, scale: theme.iconScale);
        final fontSize = _labelFontSize(theme);

        // The AMBIENT scaler, on top of the theme's own textScale. Omitting it
        // makes the measurement wrong by exactly the amount the user has turned
        // their system font up, which is the setting most likely to clip a
        // label in the first place.
        final textScaler = MediaQuery.textScalerOf(context).scale(1.0);

        // ─── TILED IS A GEOMETRY OVER THE SAME SLOTS ──────────────────
        //
        // Every cell below is a [_Slot], which owns the drag target, the
        // merge-into-folder drop, the long-press menu and the (page, index)
        // write. Tiled changes WHERE a slot lands and nothing else, so all of
        // that behaviour is inherited rather than reimplemented. A second
        // surface would have needed its own copy of the lot, and the copy
        // would have drifted the way `_FolderView` did.
        if (theme.homeLayout == 'tiled') {
          final rects = _tile(
            Rect.fromLTWH(0, 0, constraints.maxWidth, constraints.maxHeight),
            capacity,
          );
          return Stack(
            children: [
              for (var i = 0; i < rects.length; i++)
                Positioned.fromRect(
                  rect: rects[i],
                  child: _Slot(
                    theme: theme,
                    page: page,
                    index: i,
                    item: HomeLayout.itemAt(prefs, page, i),
                    byKey: byKey,
                    editing: editing,
                    jiggle: _jiggle,
                    // Sized from the TILE, not from the grid cell computed
                    // above: tiles are all different shapes, and an icon
                    // measured against a 4-wide cell would be identical in
                    // every one of them, which is the look this mode exists to
                    // avoid.
                    iconSize: IconSizing.inCell(
                      rects[i].shortestSide,
                      scale: theme.iconScale,
                    ),
                  ),
                ),
            ],
          );
        }

        final grid = GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          // ─── THE DOCK LIVES IN THIS BOX TOO ─────────────────────────
          //
          // `HomeGrid` fills the workspace and the shell positions its dock
          // inside the same box, so the grid ran underneath it: the whole
          // bottom row on a bottom-dock distro, column zero on the four with a
          // vertical dock. Cells that are drawn, counted in `capacity`, and
          // handed out by `addToHome` while being invisible and untappable.
          //
          // Fourth site of the same missing subtraction, after the desklet
          // surface, the drawer and the search bar. `dockInsets` is where the
          // band is derived now, from the constants the docks themselves use.
          //
          // `desktopDockInsets`, not `dockInsets`: a distro with
          // `dockReveal: "apps"` has no dock on the desktop at all, and
          // reserving a band for one would cost Fedora 89dp of a desktop whose
          // argument is that it is empty.
          padding: const EdgeInsets.all(pad) + desktopDockInsets(theme),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: crossGap,
            childAspectRatio: GridMetrics.aspectFor(
              cellWidth: cellW,
              iconSize: iconSize,
              labelLines: theme.labelLines,
              fontSize: fontSize,
              textScaler: textScaler,
            ),
            mainAxisSpacing: 8,
          ),
          itemCount: capacity,
          itemBuilder: (context, index) {
            final item = HomeLayout.itemAt(prefs, page, index);
            return _Slot(
              theme: theme,
              page: page,
              index: index,
              item: item,
              byKey: byKey,
              editing: editing,
              jiggle: _jiggle,
              iconSize: iconSize,
            );
          },
        );

        if (!editing) return grid;

        // ─── SAY HOW TO LEAVE ────────────────────────────────────────────
        //
        // Tapping bare wallpaper exits, and on a full desktop there is no bare
        // wallpaper to tap. A chip is the only thing between that and a user
        // who is stuck, and it is what the App Library already does.
        //
        // Above the grid in a Stack rather than beside it in a Column, so the
        // cells keep the geometry `GridMetrics` measured for them.
        return Stack(
          children: [
            grid,
            Positioned(
              top: 4,
              right: 10,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => ref.read(deskletEditProvider.notifier).exit(),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: theme.palette.onDark.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    context.t('shell.done'),
                    style: TextStyle(
                      fontFamily: theme.typography.display,
                      fontSize: 13 * theme.textScale,
                      fontWeight: FontWeight.w600,
                      color: theme.palette.accent,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// An X badge over whatever is being arranged.
///
/// ─── DELIBERATELY NOT A COPY OF library_view's ──────────────────────────────
///
/// That one uninstalls, because in the App Library there is nowhere else for an
/// app to go: removing it from the Library means removing it from the phone.
/// Here the badge takes a tile off the DESKTOP, and the app is still in the
/// drawer, so the two carry the same glyph and mean different things. The
/// callback is therefore supplied by the slot rather than assumed by the badge,
/// which is also what lets a folder's X ungroup instead.
///
/// The geometry and the colour reasoning ARE that file's, unchanged: bounded so
/// the target stays comfortable, and themed rather than iOS grey because a
/// badge sitting on top of an icon has to read as a control against whatever
/// the distro's icons look like.
class _Removable extends StatelessWidget {
  const _Removable({
    required this.theme,
    required this.size,
    required this.editing,
    required this.onRemove,
    required this.child,
  });

  final EffectiveTheme theme;
  final double size;
  final bool editing;
  final VoidCallback onRemove;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!editing) return child;

    final badge = (size * 0.34).clamp(16.0, 24.0);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          // Top LEFT, matching the Library. The label sits under the icon and a
          // badge on the right would overlap the neighbouring tile's icon on a
          // four-column grid, where the Library's cells are wider.
          top: -badge * 0.20,
          left: -badge * 0.20,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.selectionClick();
              onRemove();
            },
            child: Container(
              width: badge,
              height: badge,
              decoration: BoxDecoration(
                color: theme.palette.onDark,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.close,
                size: badge * 0.62,
                color: theme.palette.bar,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The label's point size. One place, because the cell arithmetic and the
/// TextStyle have to be the same number or the measurement is fiction.
double _labelFontSize(EffectiveTheme theme) => 11 * theme.textScale;

/// Split [box] into [count] tiles the way a tiling window manager does.
///
/// ─── THE SPIRAL, BECAUSE IT IS WHAT A TILING SCREEN LOOKS LIKE ──────────────
///
/// Each tile takes half of what is left and the remainder recurses into the
/// other half, splitting along whichever axis is currently longer. That is
/// i3 with automatic orientation, and dwm's fibonacci layout, and it is the
/// arrangement anyone who has seen a tiling desktop recognises instantly: one
/// large region, then progressively smaller ones winding into a corner.
///
/// The alternatives are both wrong here. Equal columns is i3's literal default
/// with `splith`, and at six tiles on a phone it is six vertical slivers.
/// Master-and-stack is dwm's default and reads as a phone widget over a list.
/// The spiral is the only one that stays legible from one tile to eight.
///
/// ─── GAPLESS, AND THAT IS THE POINT ─────────────────────────────────────────
///
/// No padding, no gutter, no rounding here. The distro that wants this is the
/// one whose entire visual argument is that nothing is spaced and nothing is
/// rounded, and a gap would make it a grid with delusions. i3-gaps exists and
/// is popular; it is also the configuration Arch's own defaults do not ship.
///
/// ─── AND IT HAS A CEILING THE AUTHOR HAS TO RESPECT ────────────────────────
///
/// Halving compounds. On a 360 by 640 workspace the smallest tile is about 85dp
/// square at six, 42dp at eight, and nothing at all by twenty: the spiral winds
/// into a corner and the last few tiles are slivers no thumb can hit.
///
/// There is no clamp here, deliberately. Dropping slots would lose apps the
/// user placed, and falling back to a grid past some count would make the
/// desktop change shape as it filled. Capacity is `rows * cols` and a tiled
/// distro is expected to author a small grid; Arch uses three by two. A distro
/// that authors five by four and turns this on gets a mosaic, and it will be
/// obvious on the first screenshot.
///
/// Returns exactly [count] rects, in slot order, so index 0 is the largest.
/// A caller asking for zero gets an empty list rather than a division by zero.
List<Rect> _tile(Rect box, int count) {
  if (count <= 0) return const [];

  final out = <Rect>[];
  var left = box;

  for (var i = 0; i < count; i++) {
    // The last one takes everything remaining, which is what keeps the tiles
    // covering the box exactly rather than leaving a sliver of wallpaper down
    // one edge from accumulated halving.
    if (i == count - 1) {
      out.add(left);
      break;
    }

    if (left.width >= left.height) {
      final w = left.width / 2;
      out.add(Rect.fromLTWH(left.left, left.top, w, left.height));
      left = Rect.fromLTWH(left.left + w, left.top, left.width - w, left.height);
    } else {
      final h = left.height / 2;
      out.add(Rect.fromLTWH(left.left, left.top, left.width, h));
      left = Rect.fromLTWH(left.left, left.top + h, left.width, left.height - h);
    }
  }

  return out;
}

/// An empty or filled slot. Empty slots are still DragTargets — that is what
/// makes "drag an icon into the gap" work.
class _Slot extends ConsumerWidget {
  const _Slot({
    required this.theme,
    required this.page,
    required this.index,
    required this.item,
    required this.byKey,
    required this.editing,
    required this.jiggle,
    required this.iconSize,
  });

  final EffectiveTheme theme;

  /// The workspace this slot belongs to. A drop writes here, not to page zero.
  final int page;
  final int index;
  final HomeItem? item;
  final Map<String, AppEntry> byKey;

  /// Is the grid in [EditMode.apps]? Passed down rather than watched here so
  /// the whole page answers from one read, and so an EMPTY slot knows too: in
  /// edit mode a tap on bare wallpaper is how you leave, and a slot that still
  /// offered to add something would swallow it.
  final bool editing;

  /// The shared wobble. See [HomeGrid]: one ticker for the whole grid, with the
  /// phase taken from [index] so it is stable across rebuilds.
  final Animation<double> jiggle;

  /// Measured from the cell by the grid above, so every tile in a row is the
  /// same size by construction rather than by each one recomputing it.
  final double iconSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DragTarget<int>(
      onWillAcceptWithDetails: (d) => d.data != index,
      onAcceptWithDetails: (d) => _onDrop(ref, from: d.data),
      builder: (context, candidate, _) {
        final hovering = candidate.isNotEmpty;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            // The only affordance telling you a drop will land here. Without it
            // drag-and-drop is guesswork.
            color: hovering
                ? theme.palette.onDark.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          // ─── AN EMPTY SLOT IS HOW YOU LEAVE ────────────────────────
          //
          // Tapping bare wallpaper exits, which is what every phone does and
          // what nobody has to be told. `DesktopHold` cannot do it: it is a
          // LONG press, and it already returns early while edit mode is
          // active. So the tap lives on the empty slots, which are the only
          // things in the grid with nothing else to do with one.
          child: (editing && item == null)
              ? GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => ref.read(deskletEditProvider.notifier).exit(),
                  child: _content(context, ref),
                )
              : _content(context, ref),
        );
      },
    );
  }

  /// The wobble, applied once around whatever this slot holds.
  ///
  /// Around the OUTSIDE rather than inside `_AppCell`, so a folder tile
  /// wobbles too. Filing apps into a folder is the other half of arranging a
  /// home screen, and a grid where half the tiles were still would read as
  /// half of it being locked.
  ///
  /// The angle is the same curve `library_view` uses: a triangle rather than a
  /// sine, because a sine spends most of its time near the extremes and turns
  /// a full grid into something unpleasant to look at for more than a second.
  Widget _wobble(Widget child) {
    if (!editing) return child;
    return AnimatedBuilder(
      animation: jiggle,
      builder: (context, c) {
        final t = (jiggle.value + (index.isEven ? 0.0 : 0.5)) % 1.0;
        return Transform.rotate(
          angle: (t < 0.5 ? t * 2 - 0.5 : 1.5 - t * 2) * 0.024,
          child: c,
        );
      },
      child: child,
    );
  }

  Widget _content(BuildContext context, WidgetRef ref) {
    final it = item;
    if (it == null) return const SizedBox.expand();

    if (it.isFolder) {
      final folder = HomeLayout.folder(theme.prefs, it.folderId!);
      if (folder == null) return const SizedBox.expand();
      return _wobble(
        _Removable(
          theme: theme,
          size: iconSize,
          editing: editing,
          // A folder's X UNGROUPS it rather than uninstalling anything. The
          // apps inside are not being deleted, and an X that removed six apps
          // because it sat on the tile holding them would be the worst button
          // in the launcher.
          onRemove: () => ref
              .read(prefsProvider(theme.spec.id).notifier)
              .edit((p) => HomeLayout.dissolve(
                    p,
                    it.folderId!,
                    capacity: theme.rows * theme.cols,
                  )),
          child: _Draggable(
            index: index,
            child: _FolderCell(
              theme: theme,
              folder: folder,
              byKey: byKey,
              iconSize: iconSize,
            ),
          ),
        ),
      );
    }

    final entry = byKey[it.componentKey];
    if (entry == null) return const SizedBox.expand();

    // NOT wrapped in [_Draggable], unlike the folder above. See [_AppCell]:
    // it owns its own draggable because the hold-versus-drag split has to
    // happen inside the widget that knows what a hold MEANS.
    return _wobble(
      _Removable(
        theme: theme,
        size: iconSize,
        editing: editing,
        // TAKES IT OFF THE DESKTOP, and does not uninstall.
        //
        // iOS asks which you meant. This does not, because the two are not
        // equally reachable here: Uninstall is already in the long-press menu
        // with Android's own confirmation behind it, and a badge that could
        // delete an app on one tap with no dialog is a badge nobody should
        // trust. Removing from home is instantly undoable by dragging it back.
        onRemove: () => ref
            .read(prefsProvider(theme.spec.id).notifier)
            .edit((p) => HomeLayout.removeFromHome(p, page, index)),
        child: _AppCell(
          theme: theme,
          entry: entry,
          page: page,
          slot: index,
          iconSize: iconSize,
        ),
      ),
    );
  }

  void _onDrop(WidgetRef ref, {required int from}) {
    final notifier = ref.read(prefsProvider(theme.spec.id).notifier);
    final capacity = theme.rows * theme.cols;

    HapticFeedback.mediumImpact();

    notifier.edit((p) {
      final target = HomeLayout.itemAt(p, page, index);

      // Both ends are THIS page. A drag cannot cross workspaces in one gesture,
      // because the pager does not scroll while a tile is held, so from and to
      // are the same page by construction rather than by assumption.
      if (target == null) {
        return HomeLayout.move(
          p,
          fromPage: page,
          fromIndex: from,
          toPage: page,
          toIndex: index,
        );
      }

      return HomeLayout.mergeOrSwap(
        p,
        fromPage: page,
        fromIndex: from,
        toPage: page,
        toIndex: index,
        newFolderId: () =>
            'f${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}',
      );
    });

    // capacity is unused on this path today, but folder dissolve needs it and
    // keeping the signature honest is cheaper than remembering later.
    assert(capacity > 0);
  }
}

/// The plain draggable, now FOLDERS ONLY.
///
/// Apps moved off it because the hold-versus-drag split has to live in the
/// same State as the menu it decides about; see [_AppCell]. A folder has no
/// menu to contest the hold, so it keeps the simple wrapper: hold to move it,
/// tap to open it.
///
/// The two therefore drag differently on purpose. This one uses the default
/// anchor, so the feedback keeps the grab offset the thumb landed with; the
/// app cell uses the pointer anchor because its release offset has to be
/// measurable against pointer-down. Neither affects where a drop LANDS, since
/// [DragTarget] hit-tests the pointer either way and `_Slot` reads only
/// `d.data`.
class _Draggable extends StatelessWidget {
  const _Draggable({required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LongPressDraggable<int>(
      data: index,
      // The dragged icon must FOLLOW the finger, not sit under it. dragAnchor
      // defaults leave the icon offset from your thumb and it feels wrong.
      feedback: Transform.scale(
        scale: 1.15,
        child: Material(color: Colors.transparent, child: child),
      ),
      childWhenDragging: Opacity(opacity: 0.25, child: child),
      onDragStarted: HapticFeedback.selectionClick,
      child: child,
    );
  }
}

/// One app on the desktop. Tap launches, hold opens the menu, drag files it.
///
/// ─── THE MENU COULD NOT OPEN, AND THAT IS WHY IT WAS NEVER FIXED ────────────
///
/// This was a [ConsumerWidget] carrying `onLongPress: () => _menu(...)`, and
/// every one of these cells was wrapped by [_Draggable], which is a
/// [LongPressDraggable]. The draggable consumes the long press. The inner
/// handler therefore never fired, on any distro, ever: the two-row sheet it
/// pointed at was unreachable, which is the only reason nobody noticed that the
/// desktop menu offered neither Pin to dock nor Uninstall while the drawer's
/// offered both.
///
/// `app_drawer.dart` met this first and solved it, so this is that solution
/// ported rather than a second invention. Intent is read on RELEASE: if nothing
/// accepted the drop and the finger never travelled past [_slop], it was a hold,
/// so the menu opens; if it travelled, it was a drag. Two things that pattern
/// needs and the old code had neither of:
///
///   * [pointerDragAnchorStrategy], so the release offset is the FINGER. Under
///     the default strategy it is the feedback's top-left, which on a grid is
///     most of a tile away from the pointer, so the slop test could never pass
///     and the menu would never open even after the wrapper was removed.
///   * a [Listener] capturing pointer-down, because the draggable reports no
///     start position and the cell's own corner is not a stand-in for it.
///
/// Owning the draggable HERE rather than staying inside [_Draggable] is what
/// makes that possible: the release test needs the drag callbacks and the menu
/// in one State. [_FolderCell] keeps the wrapper, since a folder opens on TAP
/// and has no menu to contest the hold.
class _AppCell extends ConsumerStatefulWidget {
  const _AppCell({
    required this.theme,
    required this.entry,
    required this.page,
    required this.slot,
    required this.iconSize,
  });

  final EffectiveTheme theme;
  final AppEntry entry;
  final double iconSize;

  /// Which workspace this cell is on, so Remove takes it off THIS one. The
  /// call below said page zero, which on workspace two removed whichever icon
  /// happened to share the slot index on workspace one.
  final int page;

  /// NON-NULL now. It was nullable only for the seeded layout, whose cells had
  /// no slot to be removed from, and that layout is gone. Every cell this grid
  /// builds is a real placement, so every cell answers a long press.
  final int slot;

  @override
  ConsumerState<_AppCell> createState() => _AppCellState();
}

class _AppCellState extends ConsumerState<_AppCell> {
  /// Where the finger went down, for the hold-versus-drag test on release.
  Offset? _downAt;

  /// Below this, a "drag" is a hold with a shaky thumb. 24dp, the same slop
  /// Flutter uses to tell a tap from a pan, and the same number
  /// `app_drawer.dart` uses so the two surfaces feel identical.
  static const _slop = 24.0;

  /// Is this cell's menu open? Owned here because this State is the only thing
  /// that knows the difference between a hold and the start of a drag, and it
  /// only finds out after the press has already ended.
  bool _held = false;

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final entry = widget.entry;

    // Only the ICON wears the press state. Scaling the label with it would push
    // a two-line name into the row below, and the ring would outline text
    // rather than an app.
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PressPop(
          held: _held,
          radius: widget.iconSize * 0.24,
          ringColor: theme.palette.onDark,
          child: AppIcon(entry: entry, size: widget.iconSize),
        ),
        const SizedBox(height: GridMetrics.labelGap),
        _Label(theme: theme, text: entry.label),
      ],
    );

    return LongPressDraggable<int>(
      data: widget.slot,
      // See the class doc: this is what makes the release offset the pointer
      // rather than the feedback's corner, and the slop test therefore mean
      // anything at all.
      dragAnchorStrategy: pointerDragAnchorStrategy,
      // The dip lands when the TIMER completes, not when the finger lifts, so
      // the squash and the haptic are one event rather than two near each
      // other. Same reasoning as the drawer tile.
      onDragStarted: () {
        HapticFeedback.selectionClick();
        if (mounted) setState(() => _held = true);
      },
      onDraggableCanceled: (_, offset) {
        // Nothing accepted it. If it never moved, the user was holding.
        final from = _downAt;
        if (from == null || (offset - from).distance < _slop) {
          // Already popped by onDragStarted. This only has to KEEP it popped
          // until the panel closes, so the grid keeps saying which app the
          // panel is about.
          _menu().whenComplete(() {
            // whenComplete and not then: the route can go by the barrier, by
            // back, or by an action popping it, and a cell left scaled up
            // would be a permanent claim that an app is selected.
            if (mounted) setState(() => _held = false);
          });
        } else if (mounted) {
          // It travelled, so it was a drag nothing accepted. No menu is coming,
          // so nothing else will clear the pop.
          setState(() => _held = false);
        }
      },
      // ACCEPTED drops only. onDragEnd fires on both paths and fires AFTER
      // onDraggableCanceled, so clearing unconditionally here would snuff the
      // pop in the same frame the menu opened. On an accepted drop no menu is
      // coming and this State can survive at a new index, so something has to
      // clear it.
      onDragEnd: (details) {
        if (details.wasAccepted && mounted) setState(() => _held = false);
      },
      // Centred on the finger. The pointer anchor puts the feedback's top-left
      // under the pointer, which reads as the icon hanging off the thumb; the
      // fractional shift is half its own size, so it needs no measurement.
      feedback: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: Transform.scale(
          scale: 1.15,
          child: Material(color: Colors.transparent, child: content),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.25, child: content),
      child: Listener(
        onPointerDown: (e) => _downAt = e.position,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            final box = context.findRenderObject() as RenderBox?;
            final bounds = (box != null && box.hasSize)
                ? box.localToGlobal(Offset.zero) & box.size
                : null;
            HapticFeedback.lightImpact();
            ref.read(appListProvider.notifier).launch(entry, iconBounds: bounds);
          },
          child: content,
        ),
      ),
    );
  }

  /// The SAME menu the drawer opens, with one substitution.
  ///
  /// It was a two-row [ThemedSheet] climbing from the bottom edge with Remove
  /// and App info in raw English, while `showDrawerAppMenu` offered Pin to
  /// dock, Hide, Uninstall with its refusal statuses, the app's own icon in the
  /// header, i18n throughout, and an anchor at the tile. Keeping a second copy
  /// was never a decision; it is what happens when the first copy is
  /// unreachable and nobody sees the gap.
  ///
  /// [AnchoredMenu.anchorOf] is measured off THIS context, which is the whole
  /// draggable rather than the icon alone. Close enough on a grid cell, and the
  /// alternative is threading a key down to the [PressPop] for a few dp.
  Future<void> _menu() {
    final theme = widget.theme;
    return showDrawerAppMenu(
      context,
      ref,
      theme,
      widget.entry,
      anchor: AnchoredMenu.anchorOf(context),
      // The verb, not the coordinates. See the parameter's doc: drawer_actions
      // serves five drawers and four of them have no slots.
      onRemoveFromHome: () => ref
          .read(prefsProvider(theme.spec.id).notifier)
          .edit((p) =>
              HomeLayout.removeFromHome(p, widget.page, widget.slot)),
    );
  }
}

class _FolderCell extends ConsumerWidget {
  const _FolderCell({
    required this.theme,
    required this.folder,
    required this.byKey,
    required this.iconSize,
  });

  final EffectiveTheme theme;
  final AppFolder folder;
  final Map<String, AppEntry> byKey;
  final double iconSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members =
        folder.members.map((k) => byKey[k]).whereType<AppEntry>().toList();

    return GestureDetector(
      // ─── THE SAME OVERLAY THE DRAWER OPENS ──────────────────────────
      //
      // This pushed `_FolderView`, a bare `Dialog` holding a `TextField` and a
      // four-column grid, with raw `TextStyle`, raw palette colours, no
      // [ChromeScope], no paging, and a long press that removed a member
      // outright with no menu and no undo. `folder_overlay.dart` has had the
      // full-screen panel, in-place rename, the multi-select add dialog, drag
      // reordering with edge page-flip, and a context menu at the pointer for
      // some time; the desktop simply never got pointed at it.
      //
      // [FolderStore] is what makes one screen serve both without merging two
      // storage models that are correctly separate. See its library doc.
      onTap: () => showHomeFolderOverlay(context, ref, theme, folder.id),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // A 2x2 preview of the first four. The convention everyone already
          // knows — do not invent a new folder glyph.
          Container(
            width: iconSize,
            height: iconSize,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: theme.palette.onDark.withValues(alpha: 0.15),
              // The THEME's corner radius, not a hardcoded 0.22. A distro on
              // circular icons was getting rounded-square folders sitting
              // beside them, which is the one place on the desktop where the
              // icon shape setting visibly did not apply.
              borderRadius:
                  BorderRadius.circular(iconSize * theme.icons.cornerRadius),
            ),
            child: GridView.count(
              crossAxisCount: 2,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
              children: [
                for (final m in members.take(4))
                  AppIcon(entry: m, size: iconSize / 2 - 5),
              ],
            ),
          ),
          const SizedBox(height: GridMetrics.labelGap),
          _Label(theme: theme, text: folder.name),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.theme, required this.text});
  final EffectiveTheme theme;
  final String text;

  @override
  Widget build(BuildContext context) {
    final fontSize = _labelFontSize(theme);

    // ─── THE BOX IS THE MEASUREMENT, ENFORCED ─────────────────────────────
    //
    // `GridMetrics.cellHeightFor` reserves exactly this much for the label, and
    // nothing used to make the label that tall, so the two agreed only while
    // the font's own metrics matched the multiplier. Ubuntu's do not match
    // Inter's, and a fallback face for a script the bundled font lacks matches
    // neither. The difference always lands on the bottom row, where there is no
    // row beneath to lend it space.
    //
    // Sized here, so the arithmetic and the widget are the same number by
    // construction. A taller face ellipsises inside its own box instead of
    // pushing the grid past its cell.
    return SizedBox(
      height: GridMetrics.labelBlockFor(
        labelLines: theme.labelLines,
        fontSize: fontSize,
        textScaler: MediaQuery.textScalerOf(context).scale(1.0),
      ),
      child: Text(
        text,
        maxLines: theme.labelLines,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: theme.palette.onDark,
          fontSize: fontSize,
          // Explicit, because the measurement above assumes it. Left to the
          // font's own default these two disagree by whatever that default
          // happens to be.
          height: GridMetrics.labelLineHeight,
          fontFamily: theme.typography.display,
          shadows: const [Shadow(blurRadius: 4, color: Colors.black54)],
        ),
      ),
    );
  }
}
