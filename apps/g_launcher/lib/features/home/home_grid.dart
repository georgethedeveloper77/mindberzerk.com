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
import '../drawer/app_icon.dart';

/// The home workspace: apps, folders, drag-and-drop.
///
/// All the state logic lives in HomeLayout (pure, tested). This file does
/// gestures and paint, nothing more — which is why "I dragged an app into a
/// folder and lost it" is a class of bug we can actually rule out.
class HomeGrid extends ConsumerWidget {
  const HomeGrid({super.key, required this.theme});

  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apps = ref.watch(shellAppsProvider(theme));
    final byKey = {for (final a in apps) a.componentKey: a};
    final prefs = theme.prefs;
    final capacity = theme.rows * theme.cols;

    // First run: nobody has arranged anything, so seed with the first N apps
    // rather than showing an empty desktop and looking broken. The moment the
    // user drags ANYTHING, their layout takes over completely.
    final seeded = prefs.homeItems.isEmpty;

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: theme.cols,
        childAspectRatio: theme.labelLines > 1 ? 0.72 : 0.8,
        mainAxisSpacing: 8,
      ),
      itemCount: capacity,
      itemBuilder: (context, index) {
        if (seeded) {
          if (index >= apps.length) return const SizedBox.shrink();
          return _AppCell(theme: theme, entry: apps[index], slot: null);
        }

        final item = HomeLayout.itemAt(prefs, 0, index);
        return _Slot(theme: theme, index: index, item: item, byKey: byKey);
      },
    );
  }
}

/// An empty or filled slot. Empty slots are still DragTargets — that is what
/// makes "drag an icon into the gap" work.
class _Slot extends ConsumerWidget {
  const _Slot({
    required this.theme,
    required this.index,
    required this.item,
    required this.byKey,
  });

  final EffectiveTheme theme;
  final int index;
  final HomeItem? item;
  final Map<String, AppEntry> byKey;

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
        child: _FolderCell(theme: theme, folder: folder, byKey: byKey),
      );
    }

    final entry = byKey[it.componentKey];
    if (entry == null) return const SizedBox.expand();

    return _Draggable(
      index: index,
      child: _AppCell(theme: theme, entry: entry, slot: index),
    );
  }

  void _onDrop(WidgetRef ref, {required int from}) {
    final notifier = ref.read(prefsProvider(theme.spec.id).notifier);
    final capacity = theme.rows * theme.cols;

    HapticFeedback.mediumImpact();

    notifier.edit((p) {
      final target = HomeLayout.itemAt(p, 0, index);

      if (target == null) {
        return HomeLayout.move(
          p,
          fromPage: 0,
          fromIndex: from,
          toPage: 0,
          toIndex: index,
        );
      }

      return HomeLayout.mergeOrSwap(
        p,
        fromPage: 0,
        fromIndex: from,
        toPage: 0,
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
    required this.slot,
  });

  final EffectiveTheme theme;
  final AppEntry entry;

  /// null when this cell is part of the un-arranged seed layout — there is no
  /// slot to remove it from yet.
  final int? slot;

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
      onLongPress: slot == null ? null : () => _menu(context, ref),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(entry: entry, size: theme.iconSizeDp),
          const SizedBox(height: 4),
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
                  .edit((p) => HomeLayout.removeFromHome(p, 0, slot!));
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
  });

  final EffectiveTheme theme;
  final AppFolder folder;
  final Map<String, AppEntry> byKey;

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
            width: theme.iconSizeDp,
            height: theme.iconSizeDp,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: theme.palette.onDark.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(theme.iconSizeDp * 0.22),
            ),
            child: GridView.count(
              crossAxisCount: 2,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
              children: [
                for (final m in members.take(4))
                  AppIcon(entry: m, size: theme.iconSizeDp / 2 - 5),
              ],
            ),
          ),
          const SizedBox(height: 4),
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
  Widget build(BuildContext context) => Text(
        text,
        maxLines: theme.labelLines,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: theme.palette.onDark,
          fontSize: 11 * theme.textScale,
          fontFamily: theme.typography.display,
          shadows: const [Shadow(blurRadius: 4, color: Colors.black54)],
        ),
      );
}
