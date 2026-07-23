import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/prefs/drawer_layout.dart';
import '../../data/prefs/prefs_repository.dart';
import '../../design/branded_message.dart';
import '../../design/grid_metrics.dart';
import '../../engine/effective_theme.dart';
import '../../platform/launcher_api.g.dart';
import '../search/search_page.dart';
import 'drawer_actions.dart';
import 'drawer_pager.dart';
import 'app_icon.dart';
import 'drawer_drag.dart';
import 'drawer_items.dart';

/// The Activities drawer.
///
/// Painted from EffectiveTheme, not Material — columns, icon size, label lines
/// and text scale are all user-settable, and this is where they show up.
///
/// Search lives on its OWN page now (the One UI-style [SearchPage]): the drawer
/// shows the full app grid, and a search bar — positioned top or bottom per the
/// per-theme `drawerSearchPosition` pref — opens that page. This replaces the old
/// inline filter; typing, suggestions, and recent searches all belong to the
/// page, so the drawer stays a clean browsing grid.
///
/// ## Performance rules, non-negotiable
///
/// This list is 150+ apps with a bitmap each, and it is the surface people judge
/// the whole launcher on: a drawer that stutters on a fling reads as "this app
/// is slow", however fast everything else is.
///
///  - **Lazy build only.** Never build the full list eagerly. Off-screen tiles
///    must cost nothing.
///  - **Never decode an icon on the main isolate.** Icons arrive as PNG bytes
///    from the NATIVE disk cache (IconCache.kt), which renders on its own two IO
///    threads and hands back bytes. Decoding one adaptive icon is 2-5ms; on a
///    40-tile screen that is several dropped frames.
///  - **Never render an icon in Dart at all.** The recipe engine is native by
///    design. A Dart path here would duplicate it and lose both cache tiers.
///
/// (Absorbed from the retired `features/drawer/README.md`.)
class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key, required this.theme});

  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(drawerItemsProvider(theme));

    // Where the search bar sits. null = the theme decides, resolved to bottom
    // (thumb-reachable, matching the One UI search page); a theme may pin 'top'
    // for an authentic GNOME feel.
    // THREE positions now, not two. 'off' hides the bar entirely, for people
    // who reach search by gesture or by the desktop search desklet.
    final searchPosition = theme.prefs.drawerSearchPosition ?? 'bottom';
    final showSearch = searchPosition != 'off';

    // 'off' counts as "not at the top", so the empty first row survives when
    // the bar is hidden. The gap exists to clear the status bar, and that is
    // just as true with no search bar as with one at the bottom.
    final searchAtBottom = searchPosition != 'top';

    // Naming a folder happens HERE, at the drawer, not on the tile that handled
    // the drop — that tile folds itself away and unmounts. `context` is the
    // drawer's own, and the drawer only rebuilds (its Element persists), so it
    // is still valid a frame later.
    //
    // Post-framed so the grid settles into its new shape before the sheet slides
    // over it, and re-checked with `context.mounted` in case the whole drawer
    // was dismissed in that frame.
    void onFolderCreated(String folderId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        renameDrawerFolder(
          context,
          ref,
          theme,
          folderId: folderId,
          currentName: defaultFolderName,
        );
      });
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // The user's explicit choice wins; otherwise the screen decides. A fixed
        // theme constant loses to responsiveness here on purpose — a 5-column
        // grid that's right on a tablet is cramped on a 392dp phone, and no
        // theme author can know which one they're on.
        final columns = theme.prefs.drawerCols ??
            GridMetrics.drawerColumns(constraints.maxWidth);

        final labelLines =
            theme.prefs.labelLines ?? GridMetrics.defaultLabelLines;

        final aspect = labelLines > 1 ? 0.70 : 0.78;

        // How the drawer moves. Vertical is the default and the one nobody
        // notices; paged and cube are the personalization payoff.
        // PAGES IS THE DEFAULT, and this fallback is what changes it for
        // everyone rather than only for new installs: the pref is nullable,
        // and null has always meant "whatever this line says".
        //
        // Applying it to existing users was a deliberate call. The alternative
        // is writing 'vertical' into every existing profile on upgrade, which
        // freezes them on the layout they never chose and makes the default a
        // lie for the rest of the app's life.
        final style = theme.prefs.drawerScrollStyle ?? 'pages';

        // ── THE EMPTY FIRST ROW ─────────────────────────────────────────
        //
        // One row of clearance above the grid. Not a reserved SLOT: padding.
        //
        // That distinction is the whole design. As a reserved slot it would
        // have to be skipped by the item indexer, would cost four apps on
        // every page of a paged drawer, and would need a rule about whether
        // page two also gets one. As padding it is free, it applies to every
        // page automatically, and the pager's row count absorbs it because
        // rows are already derived from the height actually available.
        //
        // It exists because the drawer had twelve pixels of top padding, so
        // on a real device the first row of icons sat jammed under the status
        // bar with the shell's "Activities" label landing across the labels.
        // Every drawer worth copying leaves this gap.
        //
        // ONLY when the search bar is at the bottom. With search at the top
        // that row is already occupied by something, and a gap under it would
        // be a hole rather than breathing room.
        // HALF a row, not a whole one.
        //
        // A full tile height was the literal reading of "an empty first row"
        // and it is too much on a phone: it reads as the grid having failed to
        // start rather than as breathing room, and on a paged drawer it cost a
        // whole row of apps on every page. Measured against the drawer this is
        // modelled on, the gap there is a little under half a row.
        //
        // Still derived from the tile rather than a fixed dp, so it stays
        // proportional across a 320dp Tecno and a tablet.
        final tileH =
            GridMetrics.cellWidthFor(constraints.maxWidth, columns) / aspect;
        final topGap = searchAtBottom ? tileH * 0.5 : 0.0;

        Widget tileAt(int i) => _tileFor(
              items[i],
              theme: theme,
              labelLines: labelLines,
              onFolderCreated: onFolderCreated,
            );

        // Grouping only applies to the list; see LauncherPrefs.drawerGrouping.
        final groupAz = (theme.prefs.drawerGrouping ?? 'none') == 'az';

        // ── WHY THE PAGED BRANCH NO LONGER RETURNS EARLY ────────────────
        //
        // It used to `return Expanded(DrawerPager(...))` from here, which
        // skipped everything below: the search bar, the SafeArea and the
        // drawer's own backdrop. So choosing pages or cube silently lost the
        // search bar, which is the bug that reads as "there is no search on
        // pages". It also returned a bare Expanded from a LayoutBuilder, with
        // no Flex above it to give it a flex factor.
        //
        // Now every layout produces a `body` and falls through to the one
        // scaffold at the bottom. A layout can change how the grid MOVES; it
        // has no business deciding whether the drawer has a search bar.
        final Widget body;

        if (style == 'pages' || style == 'cube') {
          body = Expanded(
            child: DrawerPager(
              itemCount: items.length,
              columns: columns,
              aspectRatio: aspect,
              cube: style == 'cube',
              topPadding: topGap,
              itemBuilder: (context, i) => tileAt(i),
            ),
          );
        } else if (groupAz) {
          body = Expanded(
            child: _AzList(
              items: items,
              theme: theme,
              columns: columns,
              aspect: aspect,
              topGap: topGap,
              tileBuilder: (item) => _tileFor(
                item,
                theme: theme,
                labelLines: labelLines,
                onFolderCreated: onFolderCreated,
              ),
            ),
          );
        } else {
          body = _plainGrid(
            items: items,
            columns: columns,
            aspect: aspect,
            topGap: topGap,
            tileAt: tileAt,
          );
        }

        final searchBar = _DrawerSearchBar(theme: theme);

        // The drawer paints its OWN backdrop. GNOME's Activities is a
        // translucent wash over the wallpaper, not an opaque page — you can see
        // your desktop behind it, which is most of why it reads as GNOME rather
        // than as "an app list". The shell should mount this full-bleed and add
        // no chrome of its own (no back arrow: GNOME closes Activities with the
        // Super key or a swipe, and Android's back gesture already does that
        // here via the shell's PopScope).
        return ColoredBox(
          color: theme.palette.bgBottom.withValues(alpha: 0.92),
          child: SafeArea(
            child: Column(
              children: [
                if (showSearch && !searchAtBottom) searchBar,
                body,
                if (showSearch && searchAtBottom) searchBar,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Activate a tapped tile. Real apps launch natively and record usage;
/// launcher-owned entries route in-app or hand off to the OS. Kept in one place
/// so the tiles can't drift apart.
class _DrawerSearchBar extends StatelessWidget {
  const _DrawerSearchBar({required this.theme});

  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context) {
    final onDark = theme.palette.onDark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Center(
        child: ConstrainedBox(
          // Adwaita's search entry is a centred pill that does not run the full
          // width of the screen. On a phone that ceiling rarely binds, but it is
          // what keeps the drawer looking like GNOME on a tablet.
          constraints: const BoxConstraints(maxWidth: 520),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => SearchPage(theme: theme)),
            ),
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: onDark.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: onDark.withValues(alpha: 0.10)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.search,
                    size: 20,
                    color: onDark.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Search',
                    style: TextStyle(
                      color: onDark.withValues(alpha: 0.6),
                      fontFamily: theme.typography.display,
                      fontSize: 14,
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

/// The shared label under any drawer tile. Extracted so the launcher entries are
/// pixel-for-pixel peers of the app tiles, not lookalikes that drift.
class _TileLabel extends StatelessWidget {
  const _TileLabel({
    required this.text,
    required this.theme,
    required this.labelLines,
  });

  final String text;
  final EffectiveTheme theme;
  final int labelLines;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: labelLines,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 12 * theme.textScale,
        color: theme.palette.onDark,
        fontFamily: theme.typography.display,
      ),
    );
  }
}

/// Generates a drawer folder id. Prefixed `df` so it is obvious at a glance in
/// a prefs dump that this is a DRAWER folder, not a home-screen one.
/// An app tile. Tap launches, hold opens the menu, and dragging it onto another
/// app or a folder files it away.
///
/// **Why the gesture is split on release.** [LongPressDraggable] consumes the
/// long press, so a naive `onLongPress` menu would never fire once the tile
/// became draggable. Rather than demote the menu to a worse trigger, intent is
/// read on release: if nothing accepted the drop AND the finger never really
/// travelled, it was a hold, so the menu opens. Move it and it is a drag. This
/// is what every launcher does; it just usually does it in native code.
class _AppTile extends ConsumerStatefulWidget {
  const _AppTile({
    super.key,
    required this.entry,
    required this.theme,
    required this.labelLines,
    required this.onFolderCreated,
  });

  final AppEntry entry;
  final EffectiveTheme theme;
  final int labelLines;

  /// Called with the new folder's id when a drop on this tile created one. The
  /// DRAWER handles it, because this tile is about to unmount (see _mergeWith).
  final void Function(String folderId) onFolderCreated;

  @override
  ConsumerState<_AppTile> createState() => _AppTileState();
}

class _AppTileState extends ConsumerState<_AppTile> {
  /// Where the tile was when the drag began, so release can measure travel.
  Offset? _origin;

  /// Below this, a "drag" is really a hold with a shaky thumb. 24dp is the same
  /// slop Flutter uses to distinguish a tap from a pan.
  static const _slop = 24.0;

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final entry = widget.entry;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppIcon(entry: entry, size: theme.iconSizeDp),
        const SizedBox(height: 6),
        _TileLabel(
          text: entry.label,
          theme: theme,
          labelLines: widget.labelLines,
        ),
      ],
    );

    return DragTarget<DrawerDrag>(
      onWillAcceptWithDetails: (d) => switch (d.data) {
        // Cannot fold an app into itself.
        AppDrag(:final componentKey) => componentKey != entry.componentKey,
        // A folder dropped on a loose app always has somewhere to go.
        FolderDrag() => true,
      },
      onAcceptWithDetails: (d) => _accept(d.data),
      builder: (context, candidate, __) {
        final hovering = candidate.isNotEmpty;

        return LongPressDraggable<DrawerDrag>(
          data: AppDrag(entry.componentKey),
          onDragStarted: () {
            HapticFeedback.mediumImpact();
            final box = context.findRenderObject() as RenderBox?;
            _origin = (box != null && box.hasSize)
                ? box.localToGlobal(Offset.zero)
                : null;
          },
          onDraggableCanceled: (_, offset) {
            // Nothing accepted it. If it never moved, the user was holding, not
            // dragging — that is the menu.
            final from = _origin;
            if (from == null || (offset - from).distance < _slop) {
              showDrawerAppMenu(context, ref, widget.theme, widget.entry);
            }
          },
          // The dragged icon must FOLLOW the finger, not sit under it.
          feedback: Transform.scale(
            scale: 1.15,
            child: Material(color: Colors.transparent, child: content),
          ),
          childWhenDragging: Opacity(opacity: 0.25, child: content),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _launch(context, ref),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              decoration: BoxDecoration(
                // The only affordance telling you a drop will land here.
                color: hovering
                    ? theme.palette.onDark.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: content,
            ),
          ),
        );
      },
    );
  }

  /// Something was dropped on this app. What that means depends on what it was.
  ///
  /// The switch is exhaustive over [DrawerDrag], which is the whole reason the
  /// payload stopped being a String: when folders became draggable this file
  /// stopped compiling until the folder case was answered, instead of silently
  /// treating a folder id as a component key and filing a folder into itself.
  void _accept(DrawerDrag drag) {
    switch (drag) {
      case AppDrag(:final componentKey):
        _mergeWith(componentKey);
      case FolderDrag(:final folderId):
        // A folder dragged onto a loose app: the app joins the folder. The
        // mirror of dropping the app on the folder, and it must resolve the
        // same way — whichever direction the user drags, a folder plus an app
        // is that folder with one more app in it.
        HapticFeedback.mediumImpact();
        ref.read(prefsProvider(widget.theme.spec.id).notifier).edit(
              (p) => DrawerLayout.absorbApp(
                p,
                folderId,
                widget.entry.componentKey,
              ),
            );
    }
  }

  /// Another app was dropped on this one → a new folder holding both, and the
  /// rename sheet opens straight away.
  ///
  /// Naming happens HERE, at the moment of intent. A folder called "Folder" is a
  /// folder nobody ever renames: the user has just told us these two apps belong
  /// together, and that is the only moment they know what to call the group.
  /// Dismissing the sheet is fine — the folder keeps the default name and can be
  /// renamed later from its long-press menu.
  void _mergeWith(String sourceKey) {
    final theme = widget.theme;
    final notifier = ref.read(prefsProvider(theme.spec.id).notifier);

    // One id, generated once and reused: the edit closure needs it, and so does
    // the rename sheet that follows. Generating inside the closure would leave
    // us with no handle on the folder we just made.
    final id = newDrawerFolderId();

    final before = theme.prefs;
    final after = DrawerLayout.mergeApps(
      before,
      sourceKey,
      widget.entry.componentKey,
      newFolderId: () => id,
      newFolderName: defaultFolderName,
    );

    // Refused (already filed, or same app). Say so rather than absorbing the
    // gesture silently.
    if (identical(before, after)) {
      if (mounted) context.showMessage('Take that app out of its folder first');
      return;
    }

    // The drop already fired a haptic when the drag began; a second one here
    // reads as a stutter, not as confirmation.
    notifier.edit(
      (p) => DrawerLayout.mergeApps(
        p,
        sourceKey,
        widget.entry.componentKey,
        newFolderId: () => id,
        newFolderName: defaultFolderName,
      ),
    );

    // Hand the new folder UP to the drawer rather than opening the sheet here.
    //
    // This tile cannot do it: merging folds BOTH apps away, so the tile that
    // handled the drop is removed from the list and unmounts on the very next
    // build. Anything scheduled against its State (a post-frame callback, a
    // mounted check) is dead by the time it runs — which is exactly why the
    // rename sheet never appeared. The drawer survives the rebuild, so it owns
    // the prompt.
    widget.onFolderCreated(id);
  }

  /// Passes the icon's on-screen rect to Android so the app-open animation
  /// expands FROM the icon. Nobody notices it until it is missing, and then
  /// every launch feels cheap.
  void _launch(BuildContext context, WidgetRef ref) {
    final box = context.findRenderObject() as RenderBox?;
    Rect? bounds;
    if (box != null && box.hasSize) {
      bounds = box.localToGlobal(Offset.zero) & box.size;
    }
    activateDrawerItem(
      context,
      ref,
      widget.theme,
      AppDrawerItem(widget.entry),
      iconBounds: bounds,
    );
  }

}

/// A drawer folder: a 2x2 preview of its first four members, its name beneath.
///
/// Tap opens it. Drop a loose app on it to file that app away. Hold it for
/// folder settings (rename / ungroup).
///
/// ─── FOLDERS ARE NOW DRAGGABLE, AND THE OLD NOTE HERE WAS WRONG ─────────────
///
/// This carried a comment explaining that a folder deliberately could not be
/// dragged, for two reasons: nested folders are a mess, and an alphabetical
/// list gives you nowhere to drag one TO.
///
/// The first reason is real and still holds — dropping a folder on a folder
/// MERGES them, it does not nest them, and there is no code path that puts a
/// folder inside a folder. The second was a non-sequitur: dragging a folder
/// onto another folder is not about position, so the list being alphabetical
/// never had anything to do with it. Combining two folders you made by hand is
/// the obvious next thing to want after making them, and the gesture is already
/// in the user's fingers from merging two apps.
///
/// Dragging brings the release-intent problem with it. [LongPressDraggable]
/// consumes the long press, so the settings sheet had to move off `onLongPress`
/// and onto the same read-intent-on-release trick [_AppTile] uses: nothing
/// accepted the drop AND the finger never really moved, so it was a hold.
class _FolderTile extends ConsumerStatefulWidget {
  const _FolderTile({
    super.key,
    required this.item,
    required this.theme,
    required this.labelLines,
  });

  final FolderDrawerItem item;
  final EffectiveTheme theme;
  final int labelLines;

  @override
  ConsumerState<_FolderTile> createState() => _FolderTileState();
}

class _FolderTileState extends ConsumerState<_FolderTile> {
  Offset? _origin;

  /// Same 24dp as [_AppTileState]. Named separately rather than shared because
  /// they are the same NUMBER, not the same decision — if one tile ever wants a
  /// different slop, a shared constant would make that look like a bug.
  static const _slop = 24.0;

  /// Something was dropped on this folder.
  void _accept(DrawerDrag drag) {
    final theme = widget.theme;
    final notifier = ref.read(prefsProvider(theme.spec.id).notifier);
    HapticFeedback.mediumImpact();

    switch (drag) {
      case AppDrag(:final componentKey):
        notifier.edit(
          (p) => DrawerLayout.addToFolder(p, widget.item.folder.id, componentKey),
        );
      case FolderDrag(:final folderId):
        // THIS folder is the target, so THIS folder's name survives and the
        // dragged one disappears. See DrawerLayout.mergeFolders for why the
        // target wins: the thing that stayed put is the thing that absorbed.
        final before = theme.prefs;
        final after = DrawerLayout.mergeFolders(
          before,
          folderId,
          widget.item.folder.id,
        );
        if (identical(before, after)) return;

        notifier.edit(
          (p) => DrawerLayout.mergeFolders(p, folderId, widget.item.folder.id),
        );
        if (mounted) {
          context.showMessage('Merged into ${widget.item.folder.name}');
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final item = widget.item;
    final size = theme.iconSizeDp;

    return DragTarget<DrawerDrag>(
      onWillAcceptWithDetails: (d) => switch (d.data) {
        // Already in here: nothing to do, and highlighting would promise
        // something that will not happen.
        AppDrag(:final componentKey) =>
          !item.folder.members.contains(componentKey),
        // Cannot merge a folder into itself.
        FolderDrag(:final folderId) => folderId != item.folder.id,
      },
      onAcceptWithDetails: (d) => _accept(d.data),
      builder: (context, candidate, __) {
        final hovering = candidate.isNotEmpty;

        final content = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
              Container(
                width: size,
                height: size,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: theme.palette.onDark
                      .withValues(alpha: hovering ? 0.30 : 0.15),
                  borderRadius: BorderRadius.circular(
                    folderCornerRadius(theme, size),
                  ),
                ),
                // A 2x2 preview of the first four. The convention everyone
                // already knows — do not invent a new folder glyph.
                child: GridView.count(
                  crossAxisCount: 2,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 2,
                  crossAxisSpacing: 2,
                  children: [
                    for (final m in item.members.take(4))
                      AppIcon(entry: m, size: size / 2 - 5),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            _TileLabel(
              text: item.folder.name,
              theme: theme,
              labelLines: widget.labelLines,
            ),
          ],
        );

        return LongPressDraggable<DrawerDrag>(
          data: FolderDrag(item.folder.id),
          onDragStarted: () {
            HapticFeedback.mediumImpact();
            final box = context.findRenderObject() as RenderBox?;
            _origin = (box != null && box.hasSize)
                ? box.localToGlobal(Offset.zero)
                : null;
          },
          onDraggableCanceled: (_, offset) {
            // Nothing accepted the drop. If the finger never really travelled
            // it was a hold, which is the settings sheet — the trigger the
            // draggable took away.
            final from = _origin;
            if (from == null || (offset - from).distance < _slop) {
              drawerFolderSettings(context, ref, theme, item);
            }
          },
          feedback: Transform.scale(
            scale: 1.15,
            child: Material(color: Colors.transparent, child: content),
          ),
          childWhenDragging: Opacity(opacity: 0.25, child: content),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => openDrawerFolder(context, ref, theme, item),
            child: content,
          ),
        );
      },
    );
  }
}

/// A launcher-owned drawer entry (Settings, Device Settings) styled as a peer of
/// the app tiles. Tap-to-activate, no long-press sheet: none of pin / App-info /
/// uninstall applies to a non-app entry, and an empty sheet is worse than none.
///
/// The icon is passed in rather than derived here so each variant keeps its own
/// treatment (brand mark vs. system glyph) at the call site, where the variant
/// is already in hand.
class _ActionTile extends ConsumerWidget {
  const _ActionTile({
    super.key,
    required this.item,
    required this.theme,
    required this.labelLines,
    required this.icon,
  });

  final DrawerItem item;
  final EffectiveTheme theme;
  final int labelLines;
  final Widget icon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => activateDrawerItem(context, ref, theme, item),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(height: 6),
          _TileLabel(text: item.label, theme: theme, labelLines: labelLines),
        ],
      ),
    );
  }
}


/// One drawer tile.
///
/// Factored out of the grid's itemBuilder so the PAGED and CUBE layouts build
/// identical tiles from the same code. Two copies of this switch would mean a
/// new DrawerItem variant compiling in one layout and throwing in another.
Widget _tileFor(
  DrawerItem drawerItem, {
  required EffectiveTheme theme,
  required int labelLines,
  required void Function(String folderId) onFolderCreated,
}) {
            final item = drawerItem;
            // Sealed: adding a DrawerItem variant breaks this until it's
            // handled, which is the safety we want.
            return switch (item) {
              AppDrawerItem(:final entry) => _AppTile(
                  onFolderCreated: onFolderCreated,
                  // Stable identity so a prefs change (a folder created, an
                  // app pinned) REUSES this element instead of building a new
                  // one. Without it the whole grid is rebuilt from scratch,
                  // every AppIcon is recreated, and each one re-requests its
                  // bitmap from native — which is the flash on merge.
                  key: ValueKey(entry.componentKey),
                  entry: entry,
                  theme: theme,
                  labelLines: labelLines,
                ),
              FolderDrawerItem() => _FolderTile(
                  key: ValueKey(item.folder.id),
                  item: item,
                  theme: theme,
                  labelLines: labelLines,
                ),
              LauncherSettingsItem() => _ActionTile(
                  key: const ValueKey('launcher-settings'),
                  item: item,
                  theme: theme,
                  labelLines: labelLines,
                  // The launcher's own settings wear the theme's brand mark
                  // (Ubuntu → the Ubuntu logo, others → the Mindhunter mark).
                  icon: LauncherBrandIcon(
                    theme: theme,
                    size: theme.iconSizeDp,
                  ),
                ),
              DeviceSettingsItem() => _ActionTile(
                  key: const ValueKey('device-settings'),
                  item: item,
                  theme: theme,
                  labelLines: labelLines,
                  // A system handoff, not a branded app: a plain themed gear
                  // reads as "this leaves the launcher" the way a logo wouldn't.
                  icon: SizedBox(
                    width: theme.iconSizeDp,
                    height: theme.iconSizeDp,
                    child: Center(
                      child: Icon(
                        Icons.settings,
                        size: theme.iconSizeDp * 0.82,
                        color: theme.palette.onDark,
                      ),
                    ),
                  ),
                ),
            };
}


/// The drawer's app list, cut into letter sections.
///
/// ─── THE PINNED BLOCK KEEPS NO HEADER ───────────────────────────────────────
///
/// `drawerItemsProvider` returns folders, then the launcher's own entries, then
/// the apps A to Z, and both of the first two blocks are pinned for reasons
/// written out at length in that file. Sorting them under letters would undo
/// all of it: "Games" would land under G, sixty rows down, and G Launcher
/// Settings would be back under G where nobody found it the first time.
///
/// So everything that is not an app stays in one unheaded block at the top,
/// and only the apps are sectioned. The absence of a header is what marks that
/// block as chrome rather than as content, which is the same signal the folder
/// block already relies on.
///
/// ─── AND WHY A CUSTOMSCROLLVIEW ─────────────────────────────────────────────
///
/// A single GridView cannot carry full-width headers between its rows, and a
/// Column of GridViews would build every section eagerly, which on 261 apps is
/// the one thing the drawer's performance rules forbid. Slivers give lazy
/// building AND mixed row shapes, which is exactly the pair this needs.
class _AzList extends StatelessWidget {
  const _AzList({
    required this.items,
    required this.theme,
    required this.columns,
    required this.aspect,
    required this.topGap,
    required this.tileBuilder,
  });

  final List<DrawerItem> items;
  final EffectiveTheme theme;
  final int columns;
  final double aspect;
  final double topGap;
  final Widget Function(DrawerItem) tileBuilder;

  /// The section a label belongs to.
  ///
  /// Anything that does not start with A to Z lands in '#', which is where a
  /// music library puts them and where nobody is surprised to find "6amMart"
  /// or an app whose name starts with an emoji. Case-folded, so "iFixit" and
  /// "Instagram" share a section rather than sorting into two.
  static String _sectionOf(String label) {
    final t = label.trim();
    if (t.isEmpty) return '#';
    final c = t[0].toUpperCase();
    return (c.codeUnitAt(0) >= 65 && c.codeUnitAt(0) <= 90) ? c : '#';
  }

  @override
  Widget build(BuildContext context) {
    final pinned = [
      for (final i in items)
        if (i is! AppDrawerItem) i,
    ];
    final apps = [
      for (final i in items)
        if (i is AppDrawerItem) i,
    ];

    // Insertion-ordered, and `apps` arrives already sorted A to Z, so the
    // sections come out in order without a second sort. '#' therefore lands
    // wherever its first member does, which is the top, matching how a
    // case-insensitive sort already treats digits and symbols.
    final sections = <String, List<DrawerItem>>{};
    for (final a in apps) {
      sections.putIfAbsent(_sectionOf(a.label), () => <DrawerItem>[]).add(a);
    }

    final delegate = SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: columns,
      childAspectRatio: aspect,
      crossAxisSpacing: 8,
      mainAxisSpacing: 16,
    );

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // The empty first row, as padding, exactly as the unsectioned grid
        // does it. Applied once at the top rather than per section.
        SliverToBoxAdapter(child: SizedBox(height: 12 + topGap)),

        if (pinned.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: delegate,
              delegate: SliverChildBuilderDelegate(
                (context, i) => tileBuilder(pinned[i]),
                childCount: pinned.length,
              ),
            ),
          ),

        for (final e in sections.entries) ...[
          SliverToBoxAdapter(
            child: _SectionHeader(letter: e.key, theme: theme),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: delegate,
              delegate: SliverChildBuilderDelegate(
                (context, i) => tileBuilder(e.value[i]),
                childCount: e.value.length,
              ),
            ),
          ),
        ],

        const SliverToBoxAdapter(child: SizedBox(height: 12)),
      ],
    );
  }
}

/// One letter, with a hairline running off to the right.
///
/// Reads the palette and the theme's display family, never a constant, so the
/// header is Ubuntu's under Ubuntu and Breeze's under KDE. `no_constants.sh`
/// would fail it otherwise, and rightly: a section header is chrome, and chrome
/// that ignores the distro is the one place the whole app forgets what it is.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.letter, required this.theme});

  final String letter;
  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context) {
    final ink = theme.palette.onDark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Row(
        children: [
          Text(
            letter,
            style: TextStyle(
              fontFamily: theme.typography.display,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: theme.palette.accent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 1,
              color: ink.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}


/// The unsectioned, unpaged grid: one long scroll.
///
/// Pulled out of `build` when the layout branch was rewritten. It used to be
/// built inline as `final grid = ...` and the paged branch returned BEFORE
/// reaching it, which is how pages and cube lost the search bar. Three
/// sibling functions returning a body, and one scaffold consuming it, makes
/// that class of mistake structural rather than a matter of remembering.
Widget _plainGrid({
  required List<DrawerItem> items,
  required int columns,
  required double aspect,
  required double topGap,
  required Widget Function(int) tileAt,
}) {
  return Expanded(
    child: GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      // fromLTRB, not symmetric: the empty first row is above the grid only.
      // A matching gap at the bottom would push the last row off the search
      // bar and read as the list having stopped short.
      padding: EdgeInsets.fromLTRB(16, 12 + topGap, 16, 12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        childAspectRatio: aspect,
        crossAxisSpacing: 8,
        mainAxisSpacing: 16,
      ),
      itemCount: items.length,
      // addRepaintBoundaries is on by default and we want it: each icon is an
      // Image.memory, and without a boundary one icon resolving repaints the
      // entire visible grid.
      itemBuilder: (context, i) => tileAt(i),
    ),
  );
}
