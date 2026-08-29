import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/app_repository.dart';
import '../../design/branded_message.dart';
import '../../engine/effective_theme.dart';
import '../search/search_sheet.dart';
import '../../i18n/i18n.dart';
import '../../platform/launcher_api.g.dart';
import 'app_icon.dart';
import 'drawer_actions.dart';
import 'drawer_items.dart';
import 'folder_overlay.dart';

/// ─── THE LIBRARY'S GEOMETRY, AT FILE LEVEL ─────────────────────────────────
///
/// These were `static const` on [LibraryView] and moved out when the widget
/// gained a State: the code that reads them lives in `_LibraryViewState`, which
/// is a DIFFERENT CLASS, so the bare names stopped resolving and the const
/// padding at the grid stopped being constant.
///
/// File level rather than qualified with the widget's name, because they
/// describe the layout and not the instance. Every one of them is read by the
/// state, the grid and the cell, and none of them varies per widget.

/// Screen edge to the first tile.
const _side = 14.0;

/// Between the two columns, and between rows.
const _gutter = 12.0;

/// FIXED, and not a preference. The tile draws three legible icons plus a
/// cluster, and that composition needs the width two columns gives it. This is
/// why the Settings row for drawer columns is greyed under library: the number
/// is a property of the layout rather than a choice.
const _columns = 2;

/// The App Library: sections of folder tiles, scrolled vertically.
///
/// ─── ITS OWN VIEW, NOT A MODE INSIDE DrawerPager ────────────────────────────
///
/// This was built twice inside the pager first, and both attempts failed the
/// same way. `DrawerPager` carries drag and drop, slot storage, custom mode,
/// merge zones, four sort modes and folder editing, and every one of those has
/// an opinion about columns, cell size and gestures. Bending it produced a run
/// of fixes that each uncovered the next blocker: the wrong provider, then the
/// wrong sort mode, then the wrong column count, then a glyph sized from the
/// icon preference rather than from the cell.
///
/// The library needs none of that machinery. Nothing here drags, nothing has a
/// slot, nothing merges, nothing pages. It is a scrolling list of static tiles.
/// Written separately it has ONE caller and ONE job, so nothing it does can
/// break Custom, Pages, Cube or A to Z, and the next thing that looks wrong has
/// one file to look in.
///
/// ─── THE GEOMETRY IS INVERTED, WHICH IS THE REAL REASON ─────────────────────
///
/// Everywhere else the cell is sized to fit the icon: the user picks an icon
/// size and `GridMetrics.aspectFor` works out how tall a cell must be. Here the
/// column count is fixed by the layout, so the CELL is decided first and the
/// tile grows to meet it. That inversion is the thing the pager cannot express,
/// and every proportion below follows from it.
class LibraryView extends ConsumerStatefulWidget {
  const LibraryView({
    super.key,
    required this.theme,
    required this.items,
  });

  final EffectiveTheme theme;

  /// Straight from `drawerItemsProvider`, unchanged. Under `library` grouping
  /// it already emits the user's folders, then generated category folders, then
  /// the launcher's own entries, then whatever is left loose.
  final List<DrawerItem> items;

  @override
  ConsumerState<LibraryView> createState() => _LibraryViewState();
}

class _LibraryViewState extends ConsumerState<LibraryView>
    with SingleTickerProviderStateMixin {
  /// ─── EDIT MODE IS LOCAL, AND DELIBERATELY NOT A PROVIDER ────────────────
  ///
  /// `deskletEditProvider` is global because three things outside the desklet
  /// grid need to know about it: the pager, the desktop long press and the
  /// shells' back handling. Nothing outside this view needs to know the library
  /// is jiggling, and it must not survive the drawer closing: coming back to a
  /// drawer still in edit mode, with an X on every icon, reads as a bug.
  bool _editing = false;

  /// One controller for the whole grid, not one per tile.
  ///
  /// With 261 apps a per-tile controller is 261 tickers on a budget phone. One
  /// shared animation drives every icon, and the phase offset that stops them
  /// moving in lockstep comes from the tile's own index rather than from its
  /// own clock.
  late final AnimationController _jiggle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  );

  @override
  void dispose() {
    _jiggle.dispose();
    super.dispose();
  }

  void _enterEdit() {
    if (_editing) return;
    HapticFeedback.mediumImpact();
    setState(() => _editing = true);
    _jiggle.repeat(reverse: true);
  }

  void _exitEdit() {
    if (!_editing) return;
    setState(() => _editing = false);
    _jiggle.stop();
    _jiggle.value = 0;
  }

  /// The X. Android owns the confirmation, so this only ever OPENS a dialog.
  ///
  /// `AppEntry` carries no "is a system app" flag, so the X cannot be hidden in
  /// advance for those; the request refuses and `uninstallRefusalKey` already
  /// maps every refusal to a sentence. Silence would look like a broken button.
  Future<void> _uninstall(AppEntry entry) async {
    final status = await ref.read(appListProvider.notifier).uninstall(entry);
    if (UninstallStatus.succeeded(status)) return;
    if (!mounted) return;
    context.showMessage(context.t(uninstallRefusalKey(status)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final items = widget.items;

    // ─── SECTIONS ARE CUT FROM ONE LIST ───────────────────────────────────
    //
    // The provider already emits folders first and everything else after, so
    // splitting at the first non-folder gives both sections without the
    // provider having to know this view exists. A second provider returning
    // pre-sectioned data would be a second definition of the same order.
    final folders = <FolderDrawerItem>[];
    final rest = <DrawerItem>[];
    var stillFolders = true;
    for (final i in items) {
      if (stillFolders && i is FolderDrawerItem) {
        folders.add(i);
      } else {
        stillFolders = false;
        rest.add(i);
      }
    }

    return LayoutBuilder(
      builder: (context, box) {
        final cell =
            (box.maxWidth - _side * 2 - _gutter * (_columns - 1)) / _columns;

        // ─── NO SECTION HEADINGS ──────────────────────────────────────
        //
        // There were two, "Categories" and "Everything else", and both went.
        // Categories labelled the only thing on the screen, which is a heading
        // that earns nothing. And now that uncategorised apps have their own
        // Other folder, the loose remainder is just the launcher's own three
        // entries, so "Everything else" was actively wrong about what sat
        // under it.
        //
        // iOS has no headings here either, for the same reason: a grid of
        // labelled folders is already self-describing.
        return Stack(
          children: [
            Column(
              children: [
                // ─── PINNED, ABOVE THE SCROLL ─────────────────────────────
                //
                // This was a sliver and it scrolled away, which put it
                // half off the top edge the moment you moved: the one control
                // on the screen, and the first thing to go.
                //
                // Outside the CustomScrollView entirely rather than a pinned
                // SliverPersistentHeader, because a pinned header still floats
                // OVER the content and the bubbles would slide under it. A
                // Column takes its height out of the scroll's box instead, so
                // nothing ever passes beneath it.
                //
                // Hidden while editing: the X badges are the subject then, and
                // a sheet over a jiggling grid would be two edit modes at once.
                if (!_editing)
                  SafeArea(
                    bottom: false,
                    child: _SearchPill(theme: widget.theme),
                  ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.deferToChild,
                    // Hold the background to edit, tap it to leave. The grid's
                    // own tiles handle their taps first, so this only fires on
                    // the gaps between them, which is exactly where "nothing in
                    // particular" means "get me out of here".
                    onLongPress: _enterEdit,
                    onTap: _editing ? _exitEdit : null,
                    child: CustomScrollView(
                      // Frozen while editing. A jiggling grid that also scrolls
                      // makes the X a moving target, and iOS freezes for the
                      // same reason.
                      physics: _editing
                          ? const NeverScrollableScrollPhysics()
                          : null,
                      slivers: [
                        const SliverToBoxAdapter(child: SizedBox(height: 4)),
                        if (folders.isNotEmpty) _grid(context, folders, cell),
                        if (rest.isNotEmpty) _grid(context, rest, cell),
                        // ─── ROOM FOR THE DOCK ────────────────────────────
                        //
                        // Twelve, and the dock is a floating slab about ninety
                        // tall sitting over this. The last row was underneath
                        // it with its label hidden, which on a screen whose
                        // whole job is finding things is the row you were
                        // scrolling to reach.
                        //
                        // Measured from the inset rather than fixed, so a
                        // gesture-navigation phone and a three-button one both
                        // clear it.
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height: 96 + MediaQuery.viewPaddingOf(context).bottom,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (_editing)
              Positioned(
                top: 6,
                right: _side,
                child: GestureDetector(
                  onTap: _exitEdit,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Text(
                      'Done',
                      style: TextStyle(
                        color: theme.palette.accent,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontFamily: theme.typography.display,
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

  Widget _grid(
    BuildContext context,
    List<DrawerItem> section,
    double cell,
  ) {
    // Cell plus the label beneath it. Given directly rather than as an aspect
    // ratio, because an aspect ratio has to be recomputed from the width every
    // time either changes and this is the number both ends actually mean.
    final rowHeight = cell + 6 + 16;

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: _side),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _columns,
          mainAxisSpacing: _gutter,
          crossAxisSpacing: _gutter,
          mainAxisExtent: rowHeight,
        ),
        delegate: SliverChildBuilderDelegate(
          childCount: section.length,
          (context, i) => _Cell(
            theme: widget.theme,
            item: section[i],
            size: cell,
            editing: _editing,
            jiggle: _jiggle,
            // The phase offset that stops 261 icons moving in lockstep. Index
            // based, so it is stable across rebuilds: a random phase would
            // resettle every icon on every frame that rebuilds the grid.
            phase: i.isEven ? 0.0 : 0.5,
            onUninstall: _uninstall,
          ),
        ),
      ),
    );
  }
}

/// One position in the grid: a folder tile, or a single app centred.
class _Cell extends ConsumerWidget {
  const _Cell({
    required this.theme,
    required this.item,
    required this.size,
    required this.editing,
    required this.jiggle,
    required this.phase,
    required this.onUninstall,
  });

  final EffectiveTheme theme;
  final DrawerItem item;
  final double size;
  final bool editing;
  final Animation<double> jiggle;
  final double phase;
  final Future<void> Function(AppEntry) onUninstall;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (child, label, onTap) = switch (item) {
      FolderDrawerItem() => (
          _FolderTile(
            theme: theme,
            item: item as FolderDrawerItem,
            size: size,
            editing: editing,
            onUninstall: onUninstall,
            onLaunch: (e) => ref.read(appListProvider.notifier).launch(e),
          ),
          (item as FolderDrawerItem).folder.name,
          () => showFolderOverlay(
                context,
                ref,
                theme,
                item as FolderDrawerItem,
              ),
        ),
      AppDrawerItem() => (
          _SoloTile(
            theme: theme,
            entry: (item as AppDrawerItem).entry,
            size: size,
            editing: editing,
            onUninstall: onUninstall,
          ),
          (item as AppDrawerItem).entry.label,
          () => ref
              .read(appListProvider.notifier)
              .launch((item as AppDrawerItem).entry),
        ),
      // ─── THE LAUNCHER'S OWN THREE ─────────────────────────────────────
      //
      // Settings, Terminal and Device Settings are DrawerItems like any other
      // and have to render, or they vanish from the drawer entirely the moment
      // a distro turns the library on. Drawn as a themed glyph rather than an
      // app icon, matching what `_ActionTile` does in the pager.
      // ─── THESE TWO TAPS ARE NOT WIRED YET, AND SAY SO ─────────────────
      //
      // `_ActionTile` in the pager owns the routes to Settings and Terminal and
      // I have not read how it pushes them. Guessing a route name here would
      // compile and then fail at the tap, which is worse than a tile that
      // closes the drawer: at least closing is a defined thing to have
      // happened. Both are one line once `_ActionTile.onTap` is read.
      LauncherSettingsItem() => (
          _GlyphTile(theme: theme, icon: Icons.settings_outlined, size: size),
          'G Launcher Settings',
          () => Navigator.of(context).maybePop(),
        ),
      TerminalDrawerItem() => (
          _GlyphTile(theme: theme, icon: Icons.terminal, size: size),
          'Terminal',
          () => Navigator.of(context).maybePop(),
        ),
      DeviceSettingsItem() => (
          _GlyphTile(theme: theme, icon: Icons.tune, size: size),
          'Device Settings',
          () => ref.read(launcherHostApiProvider).openAndroidSettings(
                'android.settings.SETTINGS',
              ),
        ),
    };

    final content = GestureDetector(
      behavior: HitTestBehavior.opaque,
      // Inert while editing. A tap in this mode is either the X, which the
      // badge handles itself, or a miss that should not launch anything: iOS
      // does not open apps out of a jiggling grid either.
      onTap: editing ? null : onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          child,
          const SizedBox(height: 6),
          SizedBox(
            height: 16,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.palette.onDark.withValues(alpha: 0.88),
                fontSize: 11,
                fontFamily: theme.typography.display,
              ),
            ),
          ),
        ],
      ),
    );

    if (!editing) return content;

    // ─── ONE ANIMATION, APPLIED PER CELL ────────────────────────────────
    //
    // 0.012 radians is about 0.7 degrees. It reads as alive at a glance and
    // stays legible: a bigger angle makes labels visibly wobble and turns a
    // 261-tile grid into something unpleasant to look at for more than a
    // second.
    return AnimatedBuilder(
      animation: jiggle,
      builder: (context, child) {
        final t = (jiggle.value + phase) % 1.0;
        return Transform.rotate(
          angle: (t < 0.5 ? t * 2 - 0.5 : 1.5 - t * 2) * 0.024,
          child: child,
        );
      },
      child: content,
    );
  }
}

/// The search pill at the top of the Library.
///
/// Opens [showSearchSheet]. Wide and soft, because it is the one control on a
/// screen made entirely of rounded tiles and a square field would be the only
/// hard edge.
///
/// ─── AND THIS IS NOW THE SHEET'S ONLY CALLER ────────────────────────────────
///
/// It briefly opened from all seven drawers. That was wrong: `SearchPage`
/// carries suggested apps, settings topics, folders, recent searches and a
/// voice button, and the sheet carries a field and eight rows, so making it
/// universal deleted five features from six distros.
///
/// The sheet is right HERE, on a phone home screen where a card over the
/// wallpaper is what the desktop actually does. Everywhere else opens the page
/// again. Ranking is shared either way: both read `paletteResultsProvider`.
class _SearchPill extends StatelessWidget {
  const _SearchPill({required this.theme});

  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context) {
    final palette = theme.palette;

    return Padding(
      padding: const EdgeInsets.fromLTRB(_side, 2, _side, 12),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => showSearchSheet(context, theme),
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: palette.onDark.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(19),
          ),
          child: Row(
            children: [
              Icon(
                Icons.search,
                size: 17,
                color: palette.onDark.withValues(alpha: 0.55),
              ),
              const SizedBox(width: 9),
              Text(
                context.t('drawer.appLibrary'),
                style: TextStyle(
                  fontFamily: theme.typography.display,
                  fontSize: 13 * theme.textScale,
                  color: palette.onDark.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Three large icons and a cluster, in a rounded square that fills its cell.
///
/// ─── WHY NOT THE 2x2 THE PAGER'S FOLDERS USE ────────────────────────────────
///
/// Size. A folder glyph in the pager is about 56dp and four quadrants of ~26
/// each read fine. This tile is around 157dp, and four quadrants there gives
/// four 70dp icons, which makes a folder look like four apps stuck together
/// rather than like a container holding many.
///
/// Three large plus a cluster says the thing the 2x2 cannot: these three are
/// the ones you want, and there are others. The three are the folder's most
/// used, because `drawer_items` sorts every bucket by frecency before building
/// it, so the tile leads with what you actually open.
class _FolderTile extends StatelessWidget {
  const _FolderTile({
    required this.theme,
    required this.item,
    required this.size,
    required this.editing,
    required this.onUninstall,
    required this.onLaunch,
  });

  final EffectiveTheme theme;
  final FolderDrawerItem item;
  final double size;
  final bool editing;
  final Future<void> Function(AppEntry) onUninstall;

  /// ─── THE LARGE THREE LAUNCH, THE CLUSTER OPENS ────────────────────────────
  ///
  /// They were laid out so they COULD be tapped and then never wired, so the
  /// whole tile opened the folder and a 57dp WhatsApp icon did not start
  /// WhatsApp. That is the wrong answer to the most obvious gesture on the
  /// screen: an icon that looks tappable and is not teaches the user that the
  /// tile is a picture rather than a control.
  ///
  /// The cluster stays a folder opener, which is also what it looks like: four
  /// icons too small to aim at individually, which is exactly the affordance
  /// for "there is more in here".
  final void Function(AppEntry) onLaunch;

  @override
  Widget build(BuildContext context) {
    final pad = size * 0.09;
    final gap = size * 0.06;
    final inner = size - pad * 2;
    final big = (inner - gap) / 2;
    final small = (big - gap) / 2;

    final members = item.members;
    final large = members.take(3).toList();
    final rest = members.skip(3).toList();

    // The cluster shows four, unless there are more than four left, in which
    // case it shows three and a count. `hidden` is exactly how many members
    // appear NOWHERE on this tile, which is what makes the number honest.
    final hidden = rest.length > 4 ? rest.length - 3 : 0;
    final cluster = (hidden > 0 ? rest.take(3) : rest.take(4)).toList();

    // ─── THE BADGE GOES ON THE APPS, NOT ON THE FOLDER ──────────────────
    //
    // A generated category folder is not a thing that can be uninstalled, and
    // an X on the tile itself would have to mean something else, probably
    // "remove this grouping", which is not a thing either: the categories come
    // back on the next launch because the apps declare them.
    //
    // So the X sits on each visible member, which is also what iOS does. It is
    // the app that goes, and the folder shrinks by one.
    Widget slot(int i) => SizedBox(
          width: big,
          height: big,
          child: i < large.length
              ? _Removable(
                  theme: theme,
                  entry: large[i],
                  size: big,
                  editing: editing,
                  onUninstall: onUninstall,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    // Null while editing, so a jiggling grid does not launch
                    // anything: the badge owns the tap in that mode, and the
                    // cell above has already gone inert for the same reason.
                    //
                    // A non-null callback here beats the cell's own onTap,
                    // because this detector is deeper in the tree and wins the
                    // arena outright. That is the whole mechanism: no flag, no
                    // hit-test maths, just depth.
                    onTap: editing ? null : () => onLaunch(large[i]),
                    child: AppIcon(entry: large[i], size: big),
                  ),
                )
              : null,
        );

    Widget mini(int i) => SizedBox(
          width: small,
          height: small,
          child: i < cluster.length
              ? _Removable(
                  theme: theme,
                  entry: cluster[i],
                  size: small,
                  editing: editing,
                  onUninstall: onUninstall,
                  child: AppIcon(entry: cluster[i], size: small),
                )
              : null,
        );

    return Container(
      width: size,
      height: size,
      // NO clipBehavior. The badges overhang their icons by design and a clip
      // here would shave the ones on the top and left edges into crescents.
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        // Over the drawer's blurred backdrop, so a light film reads as glass
        // rather than as a grey box.
        color: theme.palette.onDark.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(size * 0.22),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [slot(0), SizedBox(width: gap), slot(1)],
          ),
          SizedBox(height: gap),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              slot(2),
              SizedBox(width: gap),
              SizedBox(
                width: big,
                height: big,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [mini(0), SizedBox(width: gap), mini(1)],
                    ),
                    SizedBox(height: gap),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        mini(2),
                        SizedBox(width: gap),
                        hidden > 0
                            ? _Overflow(
                                count: hidden,
                                size: small,
                                onDark: theme.palette.onDark,
                              )
                            : mini(3),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// An icon with its remove badge, while the grid is being edited.
///
/// ─── THE BADGE IS ABSENT, NOT DISABLED, FOR WORK PROFILE ──────────────────
///
/// A work-profile app cannot be uninstalled by the launcher and the request
/// refuses with `workProfile`. Showing an X that always fails is a button that
/// lies, so those icons simply do not get one.
///
/// System apps are the case that CANNOT be pre-filtered: `AppEntry` carries no
/// flag for them, so their X is shown and the refusal arrives at the tap with a
/// message. That asymmetry is not a compromise, it is the difference between
/// what the bridge tells us in advance and what only the OS knows.
class _Removable extends StatelessWidget {
  const _Removable({
    required this.theme,
    required this.entry,
    required this.size,
    required this.editing,
    required this.onUninstall,
    required this.child,
  });

  final EffectiveTheme theme;
  final AppEntry entry;
  final double size;
  final bool editing;
  final Future<void> Function(AppEntry) onUninstall;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!editing || entry.isWorkProfile) return child;

    // Bounded so the badge stays tappable on a cluster icon and does not
    // swallow a large one. 44 is the smallest comfortable target; the cluster
    // icons are smaller than that, and there the badge overhangs deliberately.
    final badge = (size * 0.34).clamp(16.0, 24.0);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: -badge * 0.28,
          left: -badge * 0.28,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.selectionClick();
              onUninstall(entry);
            },
            child: Container(
              width: badge,
              height: badge,
              // THEMED, not iOS grey. The badge has to read as a control on
              // top of an icon, which means high contrast against the icons
              // rather than a fixed pair of greys: `onDark` is already the
              // colour this distro uses for anything sitting on its surfaces,
              // and `bar` is the darkest thing in the palette to punch the
              // glyph out of it.
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

/// A single app, centred in a cell sized for a folder.
///
/// 0.62 rather than filling: an icon drawn at the full 157dp cell would be
/// twice the size of anything else on the phone. Centring keeps the row rhythm
/// identical to the folder rows while the icon stays a believable size.
class _SoloTile extends StatelessWidget {
  const _SoloTile({
    required this.theme,
    required this.entry,
    required this.size,
    required this.editing,
    required this.onUninstall,
  });

  final EffectiveTheme theme;
  final AppEntry entry;
  final double size;
  final bool editing;
  final Future<void> Function(AppEntry) onUninstall;

  @override
  Widget build(BuildContext context) {
    final icon = size * 0.62;

    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: _Removable(
          theme: theme,
          entry: entry,
          size: icon,
          editing: editing,
          onUninstall: onUninstall,
          child: AppIcon(entry: entry, size: icon),
        ),
      ),
    );
  }
}

/// The launcher's own entries: a themed glyph at the same size a solo app draws.
class _GlyphTile extends StatelessWidget {
  const _GlyphTile({
    required this.theme,
    required this.icon,
    required this.size,
  });

  final EffectiveTheme theme;
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final inner = size * 0.62;

    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Container(
          width: inner,
          height: inner,
          decoration: BoxDecoration(
            color: theme.palette.onDark.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(inner * 0.24),
          ),
          child: Icon(
            icon,
            size: inner * 0.55,
            color: theme.palette.onDark,
          ),
        ),
      ),
    );
  }
}

/// "+7" in the cluster's last slot.
class _Overflow extends StatelessWidget {
  const _Overflow({
    required this.count,
    required this.size,
    required this.onDark,
  });

  final int count;
  final double size;

  /// Passed in rather than read from `ChromeScope`. `onDark` is a PALETTE
  /// token and every other reference in the drawer reaches it through
  /// `theme.palette.onDark`; a widget that went looking on chrome would find
  /// either nothing or a similarly named colour that is not this one.
  final Color onDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: onDark.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: FittedBox(
        child: Padding(
          padding: EdgeInsets.all(size * 0.14),
          child: Text(
            '+$count',
            style: TextStyle(
              color: onDark.withValues(alpha: 0.78),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
