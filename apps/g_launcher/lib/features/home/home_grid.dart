import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/prefs/home_layout.dart';
import '../../data/prefs/launcher_prefs.dart';
import '../../data/prefs/prefs_repository.dart';
import '../../data/repositories/app_repository.dart';
import '../../engine/effective_theme.dart';
import '../../data/repositories/shell_apps.dart';
import '../../platform/launcher_api.g.dart';
import '../../design/components/components.dart';
import '../../design/grid_metrics.dart';
import '../../design/icon_sizing.dart';
import '../../design/components/press_pop.dart';
import '../drawer/app_icon.dart';
import '../drawer/drawer_actions.dart';

/// The home workspace: apps, folders, drag-and-drop.
///
/// All the state logic lives in HomeLayout (pure, tested). This file does
/// gestures and paint, nothing more — which is why "I dragged an app into a
/// folder and lost it" is a class of bug we can actually rule out.
class HomeGrid extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
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

        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(pad),
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
              iconSize: iconSize,
            );
          },
        );
      },
    );
  }
}

/// The label's point size. One place, because the cell arithmetic and the
/// TextStyle have to be the same number or the measurement is fiction.
double _labelFontSize(EffectiveTheme theme) => 11 * theme.textScale;

/// An empty or filled slot. Empty slots are still DragTargets — that is what
/// makes "drag an icon into the gap" work.
class _Slot extends ConsumerWidget {
  const _Slot({
    required this.theme,
    required this.page,
    required this.index,
    required this.item,
    required this.byKey,
    required this.iconSize,
  });

  final EffectiveTheme theme;

  /// The workspace this slot belongs to. A drop writes here, not to page zero.
  final int page;
  final int index;
  final HomeItem? item;
  final Map<String, AppEntry> byKey;

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
          child: _content(context, ref),
        );
      },
    );
  }

  Widget _content(BuildContext context, WidgetRef ref) {
    final it = item;
    if (it == null) return const SizedBox.expand();

    if (it.isFolder) {
      final folder = HomeLayout.folder(theme.prefs, it.folderId!);
      if (folder == null) return const SizedBox.expand();
      return _Draggable(
        index: index,
        child: _FolderCell(
          theme: theme,
          folder: folder,
          byKey: byKey,
          iconSize: iconSize,
        ),
      );
    }

    final entry = byKey[it.componentKey];
    if (entry == null) return const SizedBox.expand();

    // NOT wrapped in [_Draggable], unlike the folder above. See [_AppCell]:
    // it owns its own draggable because the hold-versus-drag split has to
    // happen inside the widget that knows what a hold MEANS.
    return _AppCell(
      theme: theme,
      entry: entry,
      page: page,
      slot: index,
      iconSize: iconSize,
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
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => _FolderView(theme: theme, folder: folder),
      ),
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

class _FolderView extends ConsumerStatefulWidget {
  const _FolderView({required this.theme, required this.folder});
  final EffectiveTheme theme;
  final AppFolder folder;

  @override
  ConsumerState<_FolderView> createState() => _FolderViewState();
}

class _FolderViewState extends ConsumerState<_FolderView> {
  late final TextEditingController _name =
      TextEditingController(text: widget.folder.name);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final apps = ref.watch(shellAppsProvider(theme));
    final byKey = {for (final a in apps) a.componentKey: a};

    // Read the folder LIVE from prefs. Using widget.folder would show stale
    // members after a removal, and the dialog would lie until you closed it.
    final folder = HomeLayout.folder(theme.prefs, widget.folder.id);
    if (folder == null) return const SizedBox.shrink();

    final members =
        folder.members.map((k) => byKey[k]).whereType<AppEntry>().toList();

    return Dialog(
      backgroundColor: theme.palette.bar,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              style: TextStyle(color: theme.palette.onDark, fontSize: 18),
              decoration: const InputDecoration(border: InputBorder.none),
              onSubmitted: (v) => ref
                  .read(prefsProvider(theme.spec.id).notifier)
                  .edit((p) => HomeLayout.renameFolder(p, folder.id, v)),
            ),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 4,
              mainAxisSpacing: 12,
              children: [
                for (final m in members)
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      ref.read(appListProvider.notifier).launch(m);
                    },
                    onLongPress: () => ref
                        .read(prefsProvider(theme.spec.id).notifier)
                        .edit(
                          (p) => HomeLayout.removeFromFolder(
                            p,
                            folder.id,
                            m.componentKey,
                            capacity: theme.rows * theme.cols,
                          ),
                        ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppIcon(entry: m, size: theme.iconSizeDp),
                        const SizedBox(height: 4),
                        _Label(theme: theme, text: m.label),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
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
