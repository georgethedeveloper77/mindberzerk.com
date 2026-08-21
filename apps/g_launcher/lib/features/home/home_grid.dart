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
import '../drawer/app_icon.dart';

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

    return _Draggable(
      index: index,
      child: _AppCell(
        theme: theme,
        entry: entry,
        page: page,
        slot: index,
        iconSize: iconSize,
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

class _AppCell extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        final box = context.findRenderObject() as RenderBox?;
        final bounds = (box != null && box.hasSize)
            ? box.localToGlobal(Offset.zero) & box.size
            : null;
        HapticFeedback.lightImpact();
        ref.read(appListProvider.notifier).launch(entry, iconBounds: bounds);
      },
      onLongPress: () => _menu(context, ref),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(entry: entry, size: iconSize),
          const SizedBox(height: GridMetrics.labelGap),
          _Label(theme: theme, text: entry.label),
        ],
      ),
    );
  }

  void _menu(BuildContext context, WidgetRef ref) {
    ThemedSheet.show<void>(
      context,
      builder: (sheet) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ThemedListRow(
            icon: Icons.remove_circle_outline,
            title: 'Remove from home',
            subtitle: 'The app stays installed',
            onTap: () {
              Navigator.pop(sheet);
              ref
                  .read(prefsProvider(theme.spec.id).notifier)
                  .edit((p) => HomeLayout.removeFromHome(p, page, slot));
            },
          ),
          ThemedListRow(
            icon: Icons.info_outline,
            title: 'App info',
            onTap: () {
              Navigator.pop(sheet);
              ref.read(appListProvider.notifier).openInfo(entry);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
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
