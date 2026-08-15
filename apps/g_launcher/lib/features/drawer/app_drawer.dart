import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/prefs/drawer_layout.dart';
import '../../data/prefs/drawer_slots.dart';
import '../../data/prefs/launcher_prefs.dart';
import '../../data/prefs/prefs_repository.dart';
import '../../data/repositories/shell_apps.dart';
import '../../design/branded_message.dart';
import '../../design/components/components.dart';
import '../../design/components/press_pop.dart';
import '../../design/grid_metrics.dart';
import '../../engine/effective_theme.dart';
import '../../platform/launcher_api.g.dart';
import '../search/search_page.dart';
import 'drawer_actions.dart';
import 'drawer_pager.dart';
import 'drawer_state.dart';
import 'package:g_launcher/i18n/i18n.dart';
import 'app_icon.dart';
import 'drawer_drag.dart';
import 'drawer_items.dart';
import 'folder_overlay.dart';

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
class AppDrawer extends ConsumerStatefulWidget {
  const AppDrawer({super.key, required this.theme});

  final EffectiveTheme theme;

  @override
  ConsumerState<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends ConsumerState<AppDrawer> {
  /// The row count the paged layout ACTUALLY rendered, reported by
  /// [DrawerPager.onRows]. Seeding Custom freezes this rather than an
  /// estimate, so entering Custom changes nothing on screen. Null until the
  /// pager's first layout (or forever on the vertical list, which then seeds
  /// from the shared formula).
  int? _pagedRows;

  /// The locate target this drawer has already acted on.
  ///
  /// Guards the folder push below against firing every rebuild, which on a
  /// drawer that rebuilds constantly would be a folder overlay pushed on top of
  /// itself several times a second.
  String? _locateHandled;

  /// If Locate is pointing at an app inside a folder, open that folder.
  ///
  /// ─── WHY THIS MOVED OUT OF locateApp ────────────────────────────────────
  ///
  /// `locateApp` pops the search page and then, in its first version, pushed
  /// the folder overlay from that same popped context. Dead context, no
  /// overlay. It also assumed the drawer was already mounted, which is false
  /// when search was opened over the desktop.
  ///
  /// Here both problems cannot happen. This runs from a State that is mounted
  /// by definition and holds a context that is alive by construction, and it
  /// runs on whichever frame the drawer actually has, whether that is the one
  /// after the aim or the first frame of a drawer that has just appeared.
  ///
  /// Post-frame because this is reached from `build`, and pushing a route
  /// during a build is not allowed.
  void _openFolderForLocate(List<DrawerItem> items) {
    final target = ref.read(locateTargetProvider);
    if (target == null || target == _locateHandled) return;

    for (final i in items) {
      if (i is! FolderDrawerItem) continue;
      if (!i.folder.members.contains(target)) continue;

      // Marked BEFORE the push, not after. The push is asynchronous and the
      // drawer will rebuild several times before it lands.
      _locateHandled = target;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showFolderOverlay(context, ref, widget.theme, i);
      });
      return;
    }

    // Loose in the drawer. Nothing to open; the page jump and the ring do the
    // rest. Still marked, so this scan runs once per target rather than once
    // per rebuild.
    _locateHandled = target;
  }

  /// Which page holds the app Locate is pointing at, or null when nothing is
  /// being pointed at, the target is not in this list, or the row count has not
  /// been reported yet.
  ///
  /// Returns a PAGE rather than an index because that is all the pager can act
  /// on, and it deliberately returns null rather than 0 for "no target": zero
  /// is a real page, and a null-means-first-page reading would send the drawer
  /// home every time the ring cleared.
  /// Wrap [child] so the next deliberate touch anywhere clears the Locate ring.
  ///
  /// ─── A Listener, NOT A GestureDetector ──────────────────────────────────
  ///
  /// This must not consume anything. A GestureDetector here would enter the
  /// arena against every tap, drag and long press in the drawer and would win
  /// some of them, which is a far worse bug than a ring that overstays.
  /// `Listener` observes raw pointer events and competes for nothing.
  ///
  /// Clearing on POINTER DOWN rather than on a completed tap is deliberate: the
  /// question was "where is it", the user has seen the answer the moment they
  /// reach for the screen, and waiting for a gesture to resolve would leave the
  /// ring up through a whole scroll.
  ///
  /// `clear()` is guarded inside the notifier, so the overwhelmingly common
  /// case where nothing is aimed writes no state and rebuilds nothing.
  Widget _clearLocateOnTouch({required Widget child}) => Listener(
        onPointerDown: (_) => ref.read(locateTargetProvider.notifier).clear(),
        child: child,
      );

  int? _locatePage(List<DrawerItem> items, int columns) {
    final target = ref.watch(locateTargetProvider);
    if (target == null) return null;

    final rows = _pagedRows;
    if (rows == null || rows < 1) return null;

    final index = items.indexWhere(
      (i) => i is AppDrawerItem && i.entry.componentKey == target,
    );
    if (index < 0) return null;

    final perPage = rows * columns;
    if (perPage < 1) return null;
    return index ~/ perPage;
  }


  /// One auto-seed attempt per drawer lifetime. Reset only when a scheduled
  /// attempt finds the app list empty, so the next rebuild (the one the
  /// arriving app list causes) can try again.
  bool _seedScheduled = false;

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
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

    // Acts at most once per target. See the method's note for why the drawer
    // owns this rather than `locateApp`.
    _openFolderForLocate(items);

    return _clearLocateOnTouch(
      child: LayoutBuilder(
      builder: (context, constraints) {
        // The user's explicit choice wins; otherwise the screen decides. A fixed
        // theme constant loses to responsiveness here on purpose — a 5-column
        // grid that's right on a tablet is cramped on a 392dp phone, and no
        // theme author can know which one they're on.
        // Custom renders the FROZEN grid; every other mode stays responsive.
        final mode = theme.prefs.drawerSortMode ?? 'custom';
        final columns = mode == 'custom'
            ? (theme.prefs.drawerSlotCols ?? 4)
            : theme.prefs.drawerCols ??
                GridMetrics.drawerColumns(constraints.maxWidth);

        // The RESOLVED value, off EffectiveTheme, per the rule everything else
        // follows. This line used to re-derive it as
        // `prefs.labelLines ?? GridMetrics.defaultLabelLines`, which is how
        // the drawer briefly disagreed with the home grid about row height:
        // GridMetrics said 1 while LayoutResolver said 2, and this was the
        // only surface reading the wrong constant.
        final labelLines = theme.labelLines;

        // ─── THE CELL IS SIZED TO ITS CONTENTS ─────────────────────────
        //
        // This was `labelLines > 1 ? 0.70 : 0.78`, a constant that knew nothing
        // about the icon size, the label's font size, or the system font scale.
        // It clipped the second line of a long name on some phones and left a
        // band of dead space under every short name on others, which is the
        // uneven row spacing.
        //
        // `textScalerOf` is the piece that was missing entirely: Flutter
        // applies the user's Android font-size setting on top of the theme's
        // own textScale, so any measurement that leaves it out is wrong by
        // exactly however far they have turned their font up.
        final labelFontSize = _tileFontSize * theme.textScale;
        final ambientScale = MediaQuery.textScalerOf(context).scale(1);

        final cellW = GridMetrics.cellWidthFor(constraints.maxWidth, columns);
        final aspect = GridMetrics.aspectFor(
          cellWidth: cellW,
          iconSize: theme.iconSizeDp,
          labelLines: labelLines,
          fontSize: labelFontSize,
          textScaler: ambientScale,
        );

        // How the drawer moves. Vertical is the default and the one nobody
        // notices; paged and cube are the personalization payoff.
        // PAGES IS THE DEFAULT, and this fallback is what changes it for
        // everyone rather than only for new installs: the pref is nullable,
        // and null means "the resolver decides".
        //
        // Applying it to existing users was a deliberate call. The alternative
        // is writing 'vertical' into every existing profile on upgrade, which
        // freezes them on the layout they never chose and makes the default a
        // lie for the rest of the app's life.
        //
        // RESOLVED, no local fallback: since distros can author their own
        // drawer default, `prefs ?? 'pages'` here would be only half the
        // chain. LayoutResolver owns user-then-theme-then-engine; this widget
        // just renders the answer.
        final style = theme.drawerScrollStyle;

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
        final tileH = cellW / aspect;
        final topGap = searchAtBottom ? tileH * 0.5 : 0.0;

        Widget tileAt(int i) => _tileFor(
              items[i],
              theme: theme,
              labelLines: labelLines,
              onFolderCreated: onFolderCreated,
            );

        // Grouping only applies to the alphabetical list; letter headers over
        // a usage ranking or a custom arrangement would label an order that
        // is not alphabetical. See LauncherPrefs.drawerGrouping.
        final groupAz = mode == 'az' && theme.drawerGrouping == 'az';

        // ── OVERFLOW MENU, SORT SHEET, AND THE HANDLERS BEHIND THEM ─────
        //
        // Defined here rather than on the State because they capture layout
        // facts (columns, tile height, constraints) that only exist inside
        // this LayoutBuilder, and seeding Custom must freeze exactly what is
        // on screen.

        // ─── ONE ROW COUNT, SHARED ──────────────────────────────────────
        //
        // The rows the pager ACTUALLY rendered, falling back to an estimate on
        // the very first frame. The estimate subtracts a nominal 66 for the
        // search bar and is only ever an estimate; the pager measures the box
        // it is really given.
        //
        // Hoisted above the handlers because `addPage` reads the same grid the
        // body renders, and the grid provider is keyed on this number. Two
        // derivations would mean the button counted pages against one shape
        // while the screen drew another.
        final rowsNow = _pagedRows ??
            DrawerPager.rowsFor(
              // The page-dots strip is subtracted for the same reason the
              // search bar is: neither is part of the height the pages get.
              // Leaving it out made this estimate one row too generous, so the
              // grid provider seeded and keyed itself on a shape the pager
              // could not draw, and the first frame reflowed. Shared constant,
              // not a copied number: two derivations of this drift.
              maxHeight: constraints.maxHeight -
                  (showSearch ? 66 : 0) -
                  DrawerPager.dotsStripFor(withAdd: mode == 'custom'),
              tileHeight: tileH,
              topPadding: topGap,
            );

        final gridKey = (theme: theme, cols: columns, rows: rowsNow);

        void enterCustom() {
          final live = ref.read(prefsProvider(theme.spec.id)).asData?.value ??
              theme.prefs;
          final notifier = ref.read(prefsProvider(theme.spec.id).notifier);

          // Returning to Custom restores the old arrangement; only a first
          // visit seeds.
          if (live.drawerSlots.isNotEmpty) {
            notifier.edit((p) => p.copyWith(drawerSortMode: 'custom'));
            return;
          }

          final apps = ref.read(shellAppsProvider(theme));
          final foldedNow = DrawerLayout.foldedKeys(live);
          final folderIds = [
            for (final f in DrawerLayout.orderedFolders(live)) f.id,
          ];
          final appKeys = [
            for (final a in apps)
              if (!foldedNow.contains(a.componentKey)) a.componentKey,
          ];

          notifier.edit(
            (p) => DrawerSlots.seed(
              p,
              folderIds: folderIds,
              appKeys: appKeys,
              cols: columns,
              rows: rowsNow,
            ),
          );
        }

        // ── AUTO-SEED ───────────────────────────────────────────────────
        //
        // Custom is the DEFAULT now, so a fresh profile arrives here with
        // nothing stored. The grid provider displays the dense append order
        // regardless, but drags against unstored entries degrade to append
        // fallbacks; seeding makes the first drag behave. Post-frame because
        // a provider cannot be written during build. Checked against LIVE
        // prefs inside the callback, since the frame that scheduled it may be
        // stale by the time it runs; an empty app list resets the guard so
        // the rebuild the arriving list causes can try again.
        if (mode == 'custom' &&
            theme.prefs.drawerSlots.isEmpty &&
            !_seedScheduled) {
          _seedScheduled = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (ref.read(shellAppsProvider(theme)).isEmpty) {
              _seedScheduled = false;
              return;
            }
            final live =
                ref.read(prefsProvider(theme.spec.id)).asData?.value;
            if (live == null || live.drawerSlots.isNotEmpty) return;
            enterCustom();
          });
        }

        void openSortSheet() {
          _showSortSheet(
            context,
            ref,
            theme,
            currentMode: mode,
            onCustom: enterCustom,
          );
        }

        void cleanUpPages() {
          final live = ref.read(prefsProvider(theme.spec.id)).asData?.value ??
              theme.prefs;
          final apps = ref.read(shellAppsProvider(theme));
          final foldedNow = DrawerLayout.foldedKeys(live);
          ref.read(prefsProvider(theme.spec.id).notifier).edit(
                (p) => DrawerSlots.cleanUp(
                  p,
                  liveAppKeys: {
                    for (final a in apps)
                      if (!foldedNow.contains(a.componentKey)) a.componentKey,
                  },
                  liveFolderIds: {for (final f in live.drawerFolders) f.id},
                ),
              );
          context.showMessage(context.t('drawer.pagesCleanedUp'));
        }

        void addPage() {
          final live = ref.read(prefsProvider(theme.spec.id)).asData?.value ??
              theme.prefs;
          final grid = ref.read(drawerCustomGridProvider(gridKey));
          // Against the CURRENT page count rather than the stored one, so the
          // first tap on an auto-sized drawer grows it by one rather than
          // jumping to 1 and appearing to do nothing.
          final next = grid.pageCount + 1;
          if ((live.drawerPageCount ?? 0) >= next) return;
          ref
              .read(prefsProvider(theme.spec.id).notifier)
              .edit((p) => p.copyWith(drawerPageCount: next));
        }

        void showOverflow(Offset at) {
          _showDrawerOverflowMenu(
            context,
            theme,
            at: at,
            showCleanUp: mode == 'custom',
            onSort: openSortSheet,
            onCleanUp: cleanUpPages,
            onSettings: () => openLauncherSettings(context, theme),
          );
        }

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

        if (mode == 'custom') {
          // ── THE GRID FOLLOWS THE SCREEN, LIKE EVERY OTHER MODE ────────
          //
          // The row count came from `drawerSlotRows`, frozen when Custom was
          // first entered, and was handed to the pager as `rowsOverride`. Two
          // things went wrong with that and the second was mine.
          //
          // Custom rendered a different number of rows from alphabetical, so
          // switching sort mode reshuffled the whole page. And once cells were
          // sized to their contents the frozen count stopped fitting, at which
          // point the pager's squeeze shrank the cells to make it fit, and
          // shrinking a content-sized cell clips exactly one thing: the label
          // on the last row.
          //
          // So the count is derived here with the SAME arithmetic the ordinary
          // paged branch uses, and a stored arrangement whose shape no longer
          // matches is re-packed onto the new one below.
          final grid = ref.watch(drawerCustomGridProvider(gridKey));

          // Persist the new shape once, post-frame, so the stored slots agree
          // with what is on screen. Order survives; see DrawerSlots.reflow.
          // Post-frame because a provider cannot be written during build, and
          // guarded on a real difference so it settles after one pass.
          if (theme.prefs.drawerSlotCols != columns ||
              theme.prefs.drawerSlotRows != rowsNow) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              ref.read(prefsProvider(theme.spec.id).notifier).edit(
                    (p) => DrawerSlots.reflow(
                      p,
                      cols: columns,
                      rows: rowsNow,
                      liveAppKeys: {
                        for (final i in items)
                          if (i is AppDrawerItem) i.entry.componentKey,
                      },
                      liveFolderIds: {
                        for (final i in items)
                          if (i is FolderDrawerItem) i.folder.id,
                      },
                    ),
                  );
            });
          }

          // ── RESERVED SLOT MIGRATION ──────────────────────────────────
          //
          // The reserved block grew from two cells to three when the Terminal
          // entry landed, so anything stored at flat 2 is now inside it and
          // would be skipped by the renderer: still in storage, gone from the
          // screen. Nothing fails, an app just disappears.
          //
          // Guarded on the data rather than on a version flag, so it runs once
          // and then never again on its own; see
          // DrawerSlots.needsReservedMigration. Separate from the reflow above
          // because it has to run even when the grid shape has not changed.
          if (DrawerSlots.needsReservedMigration(theme.prefs)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              ref.read(prefsProvider(theme.spec.id).notifier).edit(
                    (p) => DrawerSlots.migrateReserved(
                      p,
                      liveAppKeys: {
                        for (final i in items)
                          if (i is AppDrawerItem) i.entry.componentKey,
                      },
                      liveFolderIds: {
                        for (final i in items)
                          if (i is FolderDrawerItem) i.folder.id,
                      },
                    ),
                  );
            });
          }

          final per = grid.cols * grid.rows;
          body = Expanded(
            child: DrawerPager(
              itemCount: grid.cells.length,
              columns: grid.cols,
              aspectRatio: aspect,
              cube: style == 'cube',
              dragPaging: true,
              // Reported after layout, so the grid provider and the pager agree
              // on the row count from the second frame onward.
              onRows: (r) {
                if (_pagedRows != r && mounted) {
                  setState(() => _pagedRows = r);
                }
              },
              topPadding: topGap,
              initialPage: ref.read(drawerPageProvider),
              onPage: (p) =>
                  ref.read(drawerPageProvider.notifier).setPage(p),
              onAddPage: addPage,
              itemBuilder: (context, i) {
                final page = i ~/ per;
                final index = i % per;
                final item = grid.cells[i];
                if (item == null) {
                  return _EmptySlot(
                    key: ValueKey('empty-$page-$index'),
                    theme: theme,
                    page: page,
                    index: index,
                  );
                }
                return _tileFor(
                  item,
                  theme: theme,
                  labelLines: labelLines,
                  onFolderCreated: onFolderCreated,
                  // The reserved cells are chrome: not draggable, not
                  // reorder targets, exactly as in every other mode.
                  slot: i < DrawerSlots.reservedSlots
                      ? null
                      : (page: page, index: index),
                );
              },
            ),
          );
        } else if (style == 'pages' || style == 'cube') {
          body = Expanded(
            child: DrawerPager(
              itemCount: items.length,
              columns: columns,
              aspectRatio: aspect,
              cube: style == 'cube',
              topPadding: topGap,
              // Assigned without setState: the ordinary paged branch does not
              // rebuild on it, it is only read when Custom is entered to seed
              // the frozen count. The custom branch above DOES need a rebuild,
              // which is why it has its own handler.
              // ─── setState WHEN SOMETHING IS WAITING ON THIS ───────────
              //
              // The bare assignment here was correct while nothing read the row
              // count during build, and it silently broke Locate. `_pagedRows`
              // is null on a drawer's FIRST build, so `_locatePage` returns
              // null and no jump is requested; the real count then arrives here
              // post-layout, and without a rebuild `jumpToPage` is never
              // recomputed. A drawer that was closed when you hit Locate would
              // therefore open on the wrong page, forever.
              //
              // Rebuilding only when a target is pending keeps the original
              // reason for the bare assignment intact: the ordinary paged
              // drawer still does not rebuild on a row report.
              onRows: (r) {
                if (_pagedRows == r) return;
                _pagedRows = r;
                if (mounted && ref.read(locateTargetProvider) != null) {
                  setState(() {});
                }
              },
              initialPage: ref.read(drawerPageProvider),
              onPage: (p) =>
                  ref.read(drawerPageProvider.notifier).setPage(p),

              // ─── ONLY THE DRAWER CAN WORK THIS OUT ────────────────────
              //
              // Locate knows the app; the pager knows the geometry; neither
              // knows both. The page an item falls on is `index ~/ (rows *
              // columns)`, and `rows` is DERIVED at layout from the available
              // height, which is why it arrives here through `onRows` rather
              // than being something anyone can compute in advance.
              //
              // Null until `_pagedRows` has been reported at least once, which
              // is the first frame only. A jump on that frame would race the
              // layout that produces the number it depends on.
              jumpToPage: _locatePage(items, columns),
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

        final searchBar =
            _DrawerSearchBar(theme: theme, onOverflow: showOverflow);

        // The drawer paints its OWN backdrop. GNOME's Activities is a
        // translucent wash over the wallpaper, not an opaque page — you can see
        // your desktop behind it, which is most of why it reads as GNOME rather
        // than as "an app list". The shell should mount this full-bleed and add
        // no chrome of its own (no back arrow: GNOME closes Activities with the
        // Super key or a swipe, and Android's back gesture already does that
        // here via the shell's PopScope).
        return ColoredBox(
          // The drawer's own setting, scaling the authored 0.92. This wash is
          // what everything else on the shell is hidden behind while the
          // drawer is open, which is exactly why it earns a separate slider.
          color: theme.palette.bgBottom
              .withValues(alpha: 0.92 * theme.drawerOpacity),
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
    ),
    );
  }
}

/// Activate a tapped tile. Real apps launch natively and record usage;
/// launcher-owned entries route in-app or hand off to the OS. Kept in one place
/// so the tiles can't drift apart.
class _DrawerSearchBar extends StatelessWidget {
  const _DrawerSearchBar({required this.theme, required this.onOverflow});

  final EffectiveTheme theme;

  /// Opens the drawer's overflow menu, anchored at the tap. The dots get
  /// their own hit target so the rest of the pill keeps opening the search
  /// page untouched.
  final void Function(Offset globalPosition) onOverflow;

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
                  Expanded(
                    child: Text(
                      'Search',
                      style: TextStyle(
                        color: onDark.withValues(alpha: 0.6),
                        fontFamily: theme.typography.display,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (d) => onOverflow(d.globalPosition),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 12,
                      ),
                      child: Icon(
                        Icons.more_vert,
                        size: 20,
                        color: onDark.withValues(alpha: 0.7),
                      ),
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

/// The drawer label's base size, before the theme's textScale and before
/// Android's own font scaling. Named because [GridMetrics.cellHeightFor] has to
/// be handed the same number the label is drawn at.
const double _tileFontSize = 12;

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
    final fontSize = _tileFontSize * theme.textScale;

    // ─── A BOX OF EXACTLY THE HEIGHT THE CELL WAS SIZED FOR ──────────────
    //
    // The cell height is computed from `GridMetrics.labelBlockFor`, and until
    // now nothing made the label that tall: the two agreed only while the
    // font's own metrics happened to match the multiplier. They do not. Ubuntu
    // is not Inter, and a fallback face for a script Ubuntu lacks is neither.
    //
    // The overflow lands on the LAST ROW every time, which is what makes it
    // look like a last-row bug rather than a per-tile one: every row above has
    // another row beneath it to push into, and the bottom one has the edge of
    // the page.
    //
    // Boxed, the arithmetic and the widget are the same number by construction.
    // A taller face ellipsises inside its own box instead of pushing the grid
    // past its bottom edge.
    return SizedBox(
      height: GridMetrics.labelBlockFor(
        labelLines: labelLines,
        fontSize: fontSize,
        textScaler: MediaQuery.textScalerOf(context).scale(1),
      ),
      child: Text(
        text,
        maxLines: labelLines,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: fontSize,
          // Explicit, and it has to match labelBlockFor's multiplier exactly.
          height: GridMetrics.labelLineHeight,
          color: theme.palette.onDark,
          fontFamily: theme.typography.display,
        ),
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
    this.slot,
  });

  final AppEntry entry;
  final EffectiveTheme theme;
  final int labelLines;

  /// This tile's (page, index) in the CUSTOM slot grid, or null everywhere
  /// else. Non-null is what arms the zone split: drops on the middle of the
  /// tile merge exactly as always, drops on the left or right quarter insert
  /// the dragged entry before or after this one.
  final ({int page, int index})? slot;

  /// Called with the new folder's id when a drop on this tile created one. The
  /// DRAWER handles it, because this tile is about to unmount (see _mergeWith).
  final void Function(String folderId) onFolderCreated;

  @override
  ConsumerState<_AppTile> createState() => _AppTileState();
}

class _AppTileState extends ConsumerState<_AppTile> {
  /// Where the tile was when the drag began, so release can measure travel.
  /// Where the finger went down, for the hold-versus-drag test. Captured from
  /// a Listener rather than onDragStarted, because the draggable reports no
  /// position and the tile's own corner is not a usable stand-in under the
  /// pointer anchor.
  Offset? _downAt;

  /// Which zone the hovering drag is over, custom mode only. Tracked in
  /// onMove because onAcceptWithDetails reports where the drag was RELEASED
  /// relative to the feedback widget, which is not where the finger is.
  _DropZone? _zone;

  /// Below this, a "drag" is really a hold with a shaky thumb. 24dp is the same
  /// slop Flutter uses to distinguish a tap from a pan.
  static const _slop = 24.0;

  /// Is this tile's menu open?
  ///
  /// Owned HERE rather than by the menu, because this State is the only thing
  /// that knows the difference between a hold and the start of a drag. The
  /// split-on-release test below is what decides it, and it decides it after
  /// the press has already ended.
  bool _held = false;

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final entry = widget.entry;

    // ─── HELD, OR BEING POINTED AT ──────────────────────────────────────
    //
    // The same widget answers both, because they are the same statement: THIS
    // one. A separate highlight for Locate would mean two visual languages for
    // "the launcher means this app", and the user would have to learn which is
    // which for no gain.
    final located = ref.watch(locateTargetProvider) == entry.componentKey;

    // Only the ICON wears the press state, not the whole cell. Scaling the
    // label with it would push a two-line name into its neighbour's row, and
    // the ring would draw a box around text rather than an outline of an app.
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PressPop(
          held: _held || located,
          radius: theme.iconSizeDp * 0.24,
          ringColor: theme.palette.onDark,
          child: AppIcon(entry: entry, size: theme.iconSizeDp),
        ),
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
      onMove: (details) {
        if (widget.slot == null) return;
        final box = context.findRenderObject() as RenderBox?;
        if (box == null || !box.hasSize) return;
        // details.offset IS the pointer, exactly, because the draggables below
        // use pointerDragAnchorStrategy.
        //
        // They did not, and that was the whole reposition bug. Under the
        // default childDragAnchorStrategy this offset is the feedback's
        // top-left, which sits wherever inside the tile the thumb happened to
        // grab. Guessing the finger by adding half a tile is only right if the
        // grab was dead centre; a thumb landing 30dp off pushed every read a
        // third of a tile sideways. The merge band, being the middle AND the
        // null fallback, swallowed nearly every drop, which is precisely the
        // reported symptom: merging worked, repositioning never did.
        final w = box.size.width;
        final dx = box.globalToLocal(details.offset).dx.clamp(0.0, w);
        final z = dx < w * _edgeFraction
            ? _DropZone.before
            : dx > w * (1 - _edgeFraction)
                ? _DropZone.after
                : _DropZone.merge;
        if (z != _zone) setState(() => _zone = z);
      },
      onLeave: (_) {
        if (_zone != null) setState(() => _zone = null);
      },
      onAcceptWithDetails: (d) {
        final z = widget.slot == null ? _DropZone.merge : _zone ?? _DropZone.merge;
        _zone = null;
        switch (z) {
          case _DropZone.merge:
            _accept(d.data);
          case _DropZone.before:
            _insert(d.data, after: false);
          case _DropZone.after:
            _insert(d.data, after: true);
        }
      },
      builder: (context, candidate, __) {
        final hovering = candidate.isNotEmpty;

        return LongPressDraggable<DrawerDrag>(
          data: AppDrag(entry.componentKey),
          // See _AppTileState.onMove: this is what makes details.offset the
          // pointer rather than the feedback's corner.
          dragAnchorStrategy: pointerDragAnchorStrategy,
          // ─── THE DIP LANDS HERE, NOT ON RELEASE ─────────────────────
          //
          // `_held` was set in `onDraggableCanceled`, which fires when the
          // finger LIFTS. So nothing happened under the thumb while the
          // long-press timer ran, and the tile then squashed at the same
          // instant the menu appeared, which reads as decoration on the menu
          // rather than as a response to the press. The whole argument for
          // squash-and-pop over a plain scale was that the motion is a
          // CONSEQUENCE of pressing, and setting it on release threw that away.
          //
          // `onDragStarted` IS the timer completing: it is the moment the
          // draggable takes the long press, and it is where the haptic already
          // fires. Same frame, same event, so the dip and the buzz are one
          // thing rather than two near each other.
          //
          // It stays true through a real drag as well, which costs nothing:
          // `childWhenDragging` replaces this tile for the whole drag, so
          // nothing popped is on screen to see.
          onDragStarted: () {
            HapticFeedback.mediumImpact();
            if (mounted) setState(() => _held = true);
          },
          onDraggableCanceled: (_, offset) {
            // Nothing accepted it. If it never moved, the user was holding, not
            // dragging, and that is the menu.
            //
            // Compared against the POINTER-DOWN position, not the tile corner.
            // Under the pointer anchor the release offset is the finger, and a
            // finger is always most of a tile away from that corner, so the
            // old comparison could never fall under the slop and the long-press
            // menu would have stopped opening entirely.
            final from = _downAt;
            if (from == null || (offset - from).distance < _slop) {
              // Already popped, since `onDragStarted` fired when the timer
              // completed. This only has to KEEP it popped until the panel
              // closes, so the grid keeps saying which app the panel is about.
              showDrawerAppMenu(
                context,
                ref,
                widget.theme,
                widget.entry,
                // The TILE's rectangle, not the finger. A menu about an app
                // should sit under the app, and on a grid the finger can be
                // most of a tile away from the icon it landed on.
                anchor: AnchoredMenu.anchorOf(context),
              ).whenComplete(() {
                // `whenComplete` and not `then`: the route can be dismissed by
                // the barrier, by back, or by an action popping it, and a tile
                // left scaled up because the user tapped outside would be a
                // permanent lie about which app is selected.
                if (mounted) setState(() => _held = false);
              });
            } else if (mounted) {
              // It travelled, so it was a drag that nothing accepted. No menu
              // is coming, so nothing else will clear the pop.
              setState(() => _held = false);
            }
          },
          // Centred on the finger. The pointer anchor puts the feedback's
          // top-left under the pointer, which reads as the icon hanging off
          // the thumb; the fractional shift is half its own size, so it needs
          // no pixel measurement.
          feedback: FractionalTranslation(
            translation: const Offset(-0.5, -0.5),
            child: Transform.scale(
              scale: 1.15,
              child: Material(color: Colors.transparent, child: content),
            ),
          ),
          childWhenDragging: _SourceOutline(theme: theme, child: content),
          child: Listener(
            onPointerDown: (e) => _downAt = e.position,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _launch(context, ref),
              child: _DropFeedback(
                theme: theme,
                hovering: hovering,
                zone: widget.slot == null ? null : _zone,
                child: content,
              ),
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
        // is that folder with one more app in it. In Custom, the slot-aware
        // wrapper additionally frees this app's slot; the folder keeps its
        // own.
        HapticFeedback.mediumImpact();
        ref.read(prefsProvider(widget.theme.spec.id).notifier).edit(
              (p) => widget.slot == null
                  ? DrawerLayout.absorbApp(
                      p,
                      folderId,
                      widget.entry.componentKey,
                    )
                  : DrawerSlots.addToFolderAt(
                      p,
                      folderId,
                      widget.entry.componentKey,
                    ),
            );
    }
  }

  /// An edge drop in Custom: the dragged entry is inserted before or after
  /// THIS tile's slot, contents shifting along the occupied slots so the gaps
  /// the user carved stay put. See DrawerSlots.insertNear.
  void _insert(DrawerDrag drag, {required bool after}) {
    final slot = widget.slot;
    if (slot == null) return;
    HapticFeedback.mediumImpact();

    final (String? key, String? folderId) = switch (drag) {
      AppDrag(:final componentKey) => (componentKey, null),
      FolderDrag(:final folderId) => (null, folderId),
    };

    ref.read(prefsProvider(widget.theme.spec.id).notifier).edit(
          (p) => DrawerSlots.insertNear(
            p,
            componentKey: key,
            folderId: folderId,
            targetPage: slot.page,
            targetIndex: slot.index,
            after: after,
          ),
        );
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

    // The slot-aware wrapper delegates to the same DrawerLayout rules, then
    // hands the new folder the TARGET's slot; outside Custom it is the plain
    // merge unchanged. One function reference, so the refusal check and the
    // edit below cannot run different logic.
    LauncherPrefs merge(LauncherPrefs p) => widget.slot == null
        ? DrawerLayout.mergeApps(
            p,
            sourceKey,
            widget.entry.componentKey,
            newFolderId: () => id,
            newFolderName: defaultFolderName,
          )
        : DrawerSlots.mergeAppsAt(
            p,
            sourceKey,
            widget.entry.componentKey,
            newFolderId: () => id,
            newFolderName: defaultFolderName,
          );

    // The LIVE prefs, not the family-key snapshot: in Custom the merge needs
    // the slot storage, and the snapshot can trail a drag that landed one
    // frame ago.
    final before =
        ref.read(prefsProvider(theme.spec.id)).asData?.value ?? theme.prefs;
    final after = merge(before);

    // Refused (already filed, or same app). Say so rather than absorbing the
    // gesture silently.
    if (identical(before, after)) {
      if (mounted) {
        context.showMessage(context.t('drawer.takeThatAppOut'));
      }
      return;
    }

    // The drop already fired a haptic when the drag began; a second one here
    // reads as a stutter, not as confirmation.
    notifier.edit(merge);

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
    this.slot,
  });

  final FolderDrawerItem item;
  final EffectiveTheme theme;
  final int labelLines;

  /// Same contract as [_AppTile.slot]: non-null in the Custom grid, arming
  /// the centre-merges-edges-insert split.
  final ({int page, int index})? slot;

  @override
  ConsumerState<_FolderTile> createState() => _FolderTileState();
}

class _FolderTileState extends ConsumerState<_FolderTile> {
  /// See [_AppTileState._downAt].
  Offset? _downAt;

  /// See [_AppTileState._zone].
  _DropZone? _zone;

  /// Same 24dp as [_AppTileState]. Named separately rather than shared because
  /// they are the same NUMBER, not the same decision — if one tile ever wants a
  /// different slop, a shared constant would make that look like a bug.
  static const _slop = 24.0;

  /// See [_AppTileState._held]. A folder is held the same way an app is, so it
  /// answers the same way; a grid where apps respond to a hold and folders sit
  /// still would read as folders being broken.
  bool _held = false;

  /// Something was dropped on this folder.
  void _accept(DrawerDrag drag) {
    final theme = widget.theme;
    final notifier = ref.read(prefsProvider(theme.spec.id).notifier);
    HapticFeedback.mediumImpact();

    switch (drag) {
      case AppDrag(:final componentKey):
        // In Custom the slot-aware wrapper also frees the joining app's slot;
        // this folder keeps its own either way.
        notifier.edit(
          (p) => widget.slot == null
              ? DrawerLayout.addToFolder(
                  p,
                  widget.item.folder.id,
                  componentKey,
                )
              : DrawerSlots.addToFolderAt(
                  p,
                  widget.item.folder.id,
                  componentKey,
                ),
        );
      case FolderDrag(:final folderId):
        // THIS folder is the target, so THIS folder's name survives and the
        // dragged one disappears. See DrawerLayout.mergeFolders for why the
        // target wins: the thing that stayed put is the thing that absorbed.
        // In Custom the wrapper also frees the dragged folder's slot.
        LauncherPrefs merge(LauncherPrefs p) => widget.slot == null
            ? DrawerLayout.mergeFolders(p, folderId, widget.item.folder.id)
            : DrawerSlots.mergeFoldersAt(p, folderId, widget.item.folder.id);

        // Live prefs for the same reason as _AppTileState._mergeWith.
        final before =
            ref.read(prefsProvider(theme.spec.id)).asData?.value ??
                theme.prefs;
        final after = merge(before);
        if (identical(before, after)) return;

        notifier.edit(merge);
        if (mounted) {
          context.showMessage(
            context.t(
              'drawer.mergedInto',
              {'name': widget.item.folder.name},
            ),
          );
        }
    }
  }

  /// See [_AppTileState._insert]; identical semantics, this folder as target.
  void _insert(DrawerDrag drag, {required bool after}) {
    final slot = widget.slot;
    if (slot == null) return;
    HapticFeedback.mediumImpact();

    final (String? key, String? folderId) = switch (drag) {
      AppDrag(:final componentKey) => (componentKey, null),
      FolderDrag(:final folderId) => (null, folderId),
    };

    ref.read(prefsProvider(widget.theme.spec.id).notifier).edit(
          (p) => DrawerSlots.insertNear(
            p,
            componentKey: key,
            folderId: folderId,
            targetPage: slot.page,
            targetIndex: slot.index,
            after: after,
          ),
        );
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
      onMove: (details) {
        if (widget.slot == null) return;
        final box = context.findRenderObject() as RenderBox?;
        if (box == null || !box.hasSize) return;
        // details.offset IS the pointer, exactly, because the draggables below
        // use pointerDragAnchorStrategy.
        //
        // They did not, and that was the whole reposition bug. Under the
        // default childDragAnchorStrategy this offset is the feedback's
        // top-left, which sits wherever inside the tile the thumb happened to
        // grab. Guessing the finger by adding half a tile is only right if the
        // grab was dead centre; a thumb landing 30dp off pushed every read a
        // third of a tile sideways. The merge band, being the middle AND the
        // null fallback, swallowed nearly every drop, which is precisely the
        // reported symptom: merging worked, repositioning never did.
        final w = box.size.width;
        final dx = box.globalToLocal(details.offset).dx.clamp(0.0, w);
        final z = dx < w * _edgeFraction
            ? _DropZone.before
            : dx > w * (1 - _edgeFraction)
                ? _DropZone.after
                : _DropZone.merge;
        if (z != _zone) setState(() => _zone = z);
      },
      onLeave: (_) {
        if (_zone != null) setState(() => _zone = null);
      },
      onAcceptWithDetails: (d) {
        final z = widget.slot == null ? _DropZone.merge : _zone ?? _DropZone.merge;
        _zone = null;
        switch (z) {
          case _DropZone.merge:
            _accept(d.data);
          case _DropZone.before:
            _insert(d.data, after: false);
          case _DropZone.after:
            _insert(d.data, after: true);
        }
      },
      builder: (context, candidate, __) {
        final hovering = candidate.isNotEmpty;

        final content = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PressPop(
              held: _held,
              // The FOLDER's radius, not an icon's. A folder glyph is a rounded
              // square of its own and the ring has to follow that shape, or it
              // reads as a box drawn near the folder rather than around it.
              radius: folderCornerRadius(theme, size),
              ringColor: theme.palette.onDark,
              child: Container(
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
          dragAnchorStrategy: pointerDragAnchorStrategy,
          // ─── THE DIP LANDS HERE, NOT ON RELEASE ─────────────────────
          //
          // `_held` was set in `onDraggableCanceled`, which fires when the
          // finger LIFTS. So nothing happened under the thumb while the
          // long-press timer ran, and the tile then squashed at the same
          // instant the menu appeared, which reads as decoration on the menu
          // rather than as a response to the press. The whole argument for
          // squash-and-pop over a plain scale was that the motion is a
          // CONSEQUENCE of pressing, and setting it on release threw that away.
          //
          // `onDragStarted` IS the timer completing: it is the moment the
          // draggable takes the long press, and it is where the haptic already
          // fires. Same frame, same event, so the dip and the buzz are one
          // thing rather than two near each other.
          //
          // It stays true through a real drag as well, which costs nothing:
          // `childWhenDragging` replaces this tile for the whole drag, so
          // nothing popped is on screen to see.
          onDragStarted: () {
            HapticFeedback.mediumImpact();
            if (mounted) setState(() => _held = true);
          },
          onDraggableCanceled: (_, offset) {
            // Nothing accepted the drop. If the finger never really travelled
            // it was a hold, which is the settings sheet, the trigger the
            // draggable took away. See _AppTileState for why this compares
            // against the pointer-down position.
            final from = _downAt;
            if (from == null || (offset - from).distance < _slop) {
              drawerFolderSettings(
                context,
                ref,
                theme,
                item,
                anchor: AnchoredMenu.anchorOf(context),
              ).whenComplete(() {
                if (mounted) setState(() => _held = false);
              });
            } else if (mounted) {
              setState(() => _held = false);
            }
          },
          feedback: FractionalTranslation(
            translation: const Offset(-0.5, -0.5),
            child: Transform.scale(
              scale: 1.15,
              child: Material(color: Colors.transparent, child: content),
            ),
          ),
          childWhenDragging: _SourceOutline(theme: theme, child: content),
          child: Listener(
            onPointerDown: (e) => _downAt = e.position,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => openDrawerFolder(context, ref, theme, item),
              // The folder tile paints its own hover wash on the icon well
              // above, so this only adds the insertion caret.
              child: _DropFeedback(
                theme: theme,
                hovering: false,
                zone: widget.slot == null ? null : _zone,
                child: content,
              ),
            ),
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
  ({int page, int index})? slot,
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
                  slot: slot,
                ),
              FolderDrawerItem() => _FolderTile(
                  key: ValueKey(item.folder.id),
                  item: item,
                  theme: theme,
                  labelLines: labelLines,
                  slot: slot,
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
              TerminalDrawerItem() => _ActionTile(
                  key: const ValueKey('terminal'),
                  item: item,
                  theme: theme,
                  labelLines: labelLines,
                  // A tool, not a branded surface. The same reasoning that
                  // gives Device Settings a plain gear rather than a logo.
                  icon: SizedBox(
                    width: theme.iconSizeDp,
                    height: theme.iconSizeDp,
                    child: Center(
                      child: Icon(
                        Icons.terminal,
                        size: theme.iconSizeDp * 0.82,
                        color: theme.palette.onDark,
                      ),
                    ),
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
      crossAxisSpacing: GridMetrics.columnGap,
      mainAxisSpacing: GridMetrics.rowGap,
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
        crossAxisSpacing: GridMetrics.columnGap,
        mainAxisSpacing: GridMetrics.rowGap,
      ),
      itemCount: items.length,
      // addRepaintBoundaries is on by default and we want it: each icon is an
      // Image.memory, and without a boundary one icon resolving repaints the
      // entire visible grid.
      itemBuilder: (context, i) => tileAt(i),
    ),
  );
}

// ── CUSTOM MODE: DROP ZONES, EMPTY SLOTS, OVERFLOW MENU, SORT SHEET ─────────

/// Where on a tile a drag is hovering. The center merges (folder rules,
/// unchanged from every other mode); the left and right quarters insert before
/// or after, shifting along the occupied slots so user-carved gaps survive.
enum _DropZone { before, merge, after }

/// A vacant cell in the Custom grid. It exists to be dropped on: releasing a
/// drag here parks the entry at exactly this (page, index), which is how gaps
/// are made on purpose rather than survived by accident.
class _EmptySlot extends ConsumerWidget {
  const _EmptySlot({
    super.key,
    required this.theme,
    required this.page,
    required this.index,
  });

  final EffectiveTheme theme;
  final int page;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onDark = theme.palette.onDark;

    return DragTarget<DrawerDrag>(
      onAcceptWithDetails: (d) {
        HapticFeedback.selectionClick();
        final drag = d.data;
        // moveToFree refuses reserved and occupied slots against the LIVE
        // prefs, so a race with another surface degrades to a no-op, never a
        // double-filled cell.
        ref.read(prefsProvider(theme.spec.id).notifier).edit(
              (p) => switch (drag) {
                AppDrag(:final componentKey) => DrawerSlots.moveToFree(
                    p,
                    componentKey: componentKey,
                    toPage: page,
                    toIndex: index,
                  ),
                FolderDrag(:final folderId) => DrawerSlots.moveToFree(
                    p,
                    folderId: folderId,
                    toPage: page,
                    toIndex: index,
                  ),
              },
            );
      },
      builder: (context, candidate, _) {
        final hovering = candidate.isNotEmpty;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: hovering
                ? onDark.withValues(alpha: 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hovering
                  ? onDark.withValues(alpha: 0.35)
                  : Colors.transparent,
            ),
          ),
        );
      },
    );
  }
}

/// The three-dot menu on the drawer search bar, One UI style: a small card
/// anchored at the tap, not a full-width sheet. Adapted from the folder member
/// menu; prefers ABOVE the tap because the search bar lives at the bottom of
/// the screen, so below is usually off-screen.
void _showDrawerOverflowMenu(
  BuildContext context,
  EffectiveTheme theme, {
  required Offset at,
  required bool showCleanUp,
  required VoidCallback onSort,
  required VoidCallback onCleanUp,
  required VoidCallback onSettings,
}) {
  HapticFeedback.selectionClick();

  // Built from the theme, not looked up: the drawer body is not guaranteed to
  // sit under a ChromeScope, and the menu's route is not a descendant of this
  // screen anyway.
  final chrome = ChromeData.fromPalette(
    theme.palette,
    typography: theme.typography,
    textScale: theme.textScale,
    family: theme.chromeFamily,
    opacity: theme.surfaceOpacity,
    // Same reason as the desklet menu: this route builds its own chrome rather
    // than inheriting one, so it is a place the panel material can be
    // forgotten and the menu would quietly keep the old hardcoded look.
    panelBlur: theme.panelBlur,
    panelTint: theme.panelTint,
    panelRadius: theme.panelRadius,
  );

  // ─── PREFERS ABOVE, AND THAT IS THE WHOLE REASON IT TAKES A SIDE ──────
  //
  // The three-dot button lives on the search bar, which sits at the BOTTOM of
  // the drawer, so a menu that opens downward opens off the screen every time.
  // Every other menu in the app prefers below. That difference is why
  // AnchoredMenu takes the side as an argument rather than picking one: it is a
  // real disagreement between surfaces, not an inconsistency to be normalised
  // away.
  //
  // The row count and the height arithmetic that used to live here are gone.
  // AnchoredMenu measures the panel it is positioning, so adding a row is now
  // just adding a row.
  AnchoredMenu.show(
    context: context,
    chrome: chrome,
    anchor: Rect.fromCenter(center: at, width: 1, height: 1),
    width: 220,
    below: AnchoredMenu.preferAbove,
    barrierLabel: context.t('drawer.dismiss'),
    rows: (ctx) {
      Widget row(IconData icon, String title, VoidCallback go) {
        return ThemedListRow(
          icon: icon,
          title: title,
          onTap: () {
            Navigator.pop(ctx);
            go();
          },
        );
      }

      return [
        row(Icons.sort, ctx.t('drawer.sort'), onSort),
        if (showCleanUp)
          row(
            Icons.cleaning_services_outlined,
            ctx.t('drawer.cleanUpPages'),
            onCleanUp,
          ),
        row(
          Icons.settings_outlined,
          ctx.t('drawer.gLauncherSettings'),
          onSettings,
        ),
      ];
    },
  );
}

/// The sort mode picker. Radio-style rows; the current mode is marked. Picking
/// Custom routes through [onCustom], which restores a previous arrangement or
/// seeds a fresh one; the other modes are a plain pref write.
void _showSortSheet(
  BuildContext context,
  WidgetRef ref,
  EffectiveTheme theme, {
  required String currentMode,
  required VoidCallback onCustom,
}) {
  final prefs = ref.read(prefsProvider(theme.spec.id).notifier);

  ThemedSheet.show<void>(
    context,
    title: context.t('drawer.sortBy'),
    builder: (sheet) {
      Widget row(String mode, String title) {
        final selected = currentMode == mode;
        return ThemedListRow(
          icon: selected
              ? Icons.radio_button_checked
              : Icons.radio_button_unchecked,
          title: title,
          onTap: () {
            Navigator.pop(sheet);
            if (selected) return;
            if (mode == 'custom') {
              onCustom();
            } else {
              prefs.edit((p) => p.copyWith(drawerSortMode: mode));
            }
          },
        );
      }

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          row('custom', context.t('drawer.sortCustom')),
          row('az', context.t('drawer.sortAlphabetical')),
          row('mostUsed', context.t('drawer.sortMostUsed')),
          row('recent', context.t('drawer.sortRecent')),
        ],
      );
    },
  );
}

/// How much of a tile's width, each side, means "insert here" rather than
/// "merge". A third each way leaves a third in the middle for merging, which
/// on a four-column phone is roughly 30dp per band: hittable with a thumb once
/// the zone is read from the actual pointer, and visibly signposted by
/// [_DropFeedback] so the geometry is learnable rather than guessed at.
const double _edgeFraction = 1 / 3;

/// What a hovering drag looks like: a wash and ring for a merge, a caret for an
/// insert.
///
/// The zones existed before this widget and were invisible, which made
/// repositioning undiscoverable even where it worked: nothing on screen told
/// you the tile had three different meanings across its width, so a drop that
/// landed on the wrong third read as the feature being broken rather than as a
/// near miss.
class _DropFeedback extends StatelessWidget {
  const _DropFeedback({
    required this.theme,
    required this.hovering,
    required this.zone,
    required this.child,
  });

  final EffectiveTheme theme;

  /// Paint the merge wash. Off for tiles that already wash themselves.
  final bool hovering;

  /// Null outside Custom, where there is nothing to insert into.
  final _DropZone? zone;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final z = zone;
    final merging = z == _DropZone.merge || (hovering && z == null);
    final accent = theme.palette.accent;

    return Stack(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: merging && hovering
                ? theme.palette.onDark.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          // ─── foregroundDecoration, NOT decoration ────────────────────
          //
          // A `Border` in `decoration` is LAYOUT: it insets the child by its
          // width on every side. This one is 2 and it is always 2, transparent
          // when idle, precisely so the tile does not jump when the merge ring
          // appears. Which means every tile in the drawer was quietly losing
          // 4dp of height to a border nobody could see, in every sort mode.
          //
          // The cell has 8dp of breathing room, so four went to this and the
          // last row had four left for whatever the font's metrics wanted.
          // That is the margin the labels were disappearing into.
          //
          // `foregroundDecoration` paints OVER the child and takes no space, so
          // the ring still appears without moving anything, and the tile gets
          // its full cell.
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: merging && z != null
                  ? accent.withValues(alpha: 0.85)
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: child,
        ),
        if (z == _DropZone.before || z == _DropZone.after)
          Positioned(
            left: z == _DropZone.before ? 0 : null,
            right: z == _DropZone.after ? 0 : null,
            top: 4,
            bottom: 4,
            width: 3,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
      ],
    );
  }
}

/// The cell a drag came FROM: an outlined hole, not a faded icon.
///
/// A 25% ghost still reads as an icon, so the grid looked unchanged while
/// something was in flight and there was no visual answer to "where was this
/// before". An empty dashed-looking well matches what the drop targets show and
/// makes the gap the arrangement is about visible while you are making it.
class _SourceOutline extends StatelessWidget {
  const _SourceOutline({required this.theme, required this.child});

  final EffectiveTheme theme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.palette.onDark.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.palette.onDark.withValues(alpha: 0.30),
          width: 1.5,
        ),
      ),
      child: Opacity(opacity: 0.15, child: child),
    );
  }
}
