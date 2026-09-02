/// Zorin's menu: a category rail beside the apps, on a sheet.
///
/// ─── WHAT THIS REPLACED, AND WHY THE ARGUMENT CHANGED ───────────────────────
///
/// This used to be a 232dp corner menu: a pinned grid stacked over an all-apps
/// list, growing from the Start button. The reasoning was that stacking says
/// something a column pair cannot, and that a third tier of categories would be
/// Cinnamon lying down. Both halves were right about SHAPE and wrong about the
/// two things that decide a phone menu.
///
/// The first is reach. At 232dp the tiers cost 7.5pt pin labels, 10.5pt list
/// labels, 18dp icons and rows around 28dp tall. Every one of those is under
/// the platform minimum, and the audience for this pack is holding a 360dp
/// screen. A menu nobody can hit is not a menu.
///
/// The second is that Zorin's menu IS the rail. Categories down the left and
/// apps on the right is the single thing a Zorin user would name if asked what
/// their menu looks like, and dropping it left this drawer looking like a Start
/// menu with a Zorin palette. `drawerGrouping: "library"` was in the theme.json
/// the whole time, authored and signed and then discarded here.
///
/// So the tiers are gone and the rail is back. There is no third tier: the
/// pinned apps are a rail SLOT rather than a grid above the list, which is
/// where Zorin puts its own favourites anyway.
///
/// ─── THE RAIL IS THE FOLDER SURFACE, NOT A SECOND ONE ───────────────────────
///
/// Every entry after Favourites is a [FolderDrawerItem] straight from
/// `drawerItemsProvider`, so it carries the whole existing folder model with
/// it: the generated `cat:` buckets, the user's own folders, and the
/// materialise-on-first-edit path in [DrawerFolderStore]. Long-pressing a rail
/// entry opens `folder_overlay`, which already does rename, add, remove,
/// reorder and dissolve. Nothing here stores a category and nothing here
/// duplicates an editor.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/components/anchored_menu.dart';
import '../../engine/effective_theme.dart';
import '../../platform/launcher_api.g.dart';
import '../home/workspaces/workspace_controller.dart';
import '../search/search_page.dart';
import 'app_icon.dart';
import 'drawer_actions.dart';
import 'drawer_items.dart';
import 'folder_glyphs.dart';
import 'package:g_launcher/i18n/i18n.dart';

/// One rail slot: a name and the apps behind it.
///
/// [folder] is null for the two synthetic slots (Favourites and All), which is
/// what the long-press handler tests: those two are not folders and must not
/// open a folder editor.
class _Bucket {
  const _Bucket({
    required this.id,
    required this.name,
    required this.apps,
    required this.icon,
    this.folder,
  });

  final String id;
  final String name;
  final List<AppEntry> apps;

  /// Drawn when [folder] is null, or when a folder has no artwork of its own.
  final IconData icon;

  final FolderDrawerItem? folder;
}

class ZorinDrawer extends ConsumerStatefulWidget {
  const ZorinDrawer({super.key, required this.theme});

  final EffectiveTheme theme;

  @override
  ConsumerState<ZorinDrawer> createState() => _ZorinDrawerState();
}

class _ZorinDrawerState extends ConsumerState<ZorinDrawer> {
  /// The selected slot's id, NOT its index.
  ///
  /// An index survives nothing: installing an app can add a category folder
  /// ahead of the selected one and silently move the selection to a different
  /// bucket. An id that no longer exists falls back to the first slot, which is
  /// the only honest answer when the thing you were looking at is gone.
  String? _selected;

  /// The sheet's share of the screen.
  ///
  /// Tall enough that the rail's last entry is reachable and the app list shows
  /// seven rows, short enough that the wallpaper is still visible above it. A
  /// sheet that filled the screen would be a page, and the whole point of a
  /// menu is that the desktop is still there behind it.
  static const _sheetFraction = 0.75;
  static const _minSheet = 460.0;

  static const _railWidth = 56.0;
  static const _railItem = 48.0;
  static const _rowHeight = 56.0;
  static const _footHeight = 56.0;
  static const _searchHeight = 48.0;

  List<_Bucket> _buckets(List<DrawerItem> items) {
    final theme = widget.theme;

    final apps = <AppEntry>[
      for (final i in items)
        if (i is AppDrawerItem) i.entry,
    ];

    // Folders carry their members already resolved, so an app filed into a
    // category does NOT appear in `items` as a loose AppDrawerItem. Collecting
    // both is what makes the All slot actually mean all.
    final folders = <FolderDrawerItem>[
      for (final i in items)
        if (i is FolderDrawerItem) i,
    ];

    final all = <AppEntry>[
      ...apps,
      for (final f in folders) ...f.members,
    ];
    final seen = <String>{};
    final deduped = <AppEntry>[
      for (final a in all)
        if (seen.add(a.componentKey)) a,
    ]..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));

    final byKey = {for (final a in deduped) a.componentKey: a};
    // DEDUPED. `favourites` is a plain list and nothing on the write side
    // guarantees a key appears once, so a double pin renders the same app twice
    // in this bucket. Cheap to guard here and invisible to debug from a
    // screenshot, because two identical rows read as a rendering fault rather
    // than as a list with a repeat in it.
    final seenPins = <String>{};
    final pinned = <AppEntry>[
      for (final k in theme.prefs.favourites)
        if (byKey[k] != null && seenPins.add(k)) byKey[k]!,
    ];

    return [
      if (pinned.isNotEmpty)
        _Bucket(
          id: 'fav',
          name: context.t('drawer.pinned'),
          apps: pinned,
          icon: Icons.star_outline,
        ),
      _Bucket(
        id: 'all',
        name: context.t('drawer.allApps'),
        apps: deduped,
        icon: Icons.apps_outlined,
      ),
      for (final f in folders)
        _Bucket(
          id: f.folder.id,
          name: f.folder.name,
          apps: f.members,
          // The folder's own glyph, else the fallback. The distro's authored
          // category icon is already baked into `folder.glyph` upstream in
          // `drawer_items`, so the chain is resolved once rather than here and
          // in every other surface that draws a folder.
          icon: resolveFolderGlyph(folderGlyph: f.folder.glyph),
          folder: f,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final items = ref.watch(drawerItemsProvider(theme));
    final buckets = _buckets(items);
    if (buckets.isEmpty) return const SizedBox.shrink();

    final selected = buckets.firstWhere(
      (b) => b.id == _selected,
      orElse: () => buckets.first,
    );

    final media = MediaQuery.of(context);
    final navInset = media.padding.bottom;
    final sheetHeight = (media.size.height * _sheetFraction)
        .clamp(_minSheet, media.size.height - 24)
        .toDouble();

    final palette = theme.palette;
    final line = palette.onDark.withValues(alpha: 0.10);

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => closeApps(ref),
            child: ColoredBox(
              // The desktop stays visible through it. A menu that blacks out
              // what it is covering reads as a page.
              color: palette.bgBottom.withValues(alpha: 0.62),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: sheetHeight,
          child: Material(
            // theme-exempt: Material needs a transparent backdrop so the
            // Container below paints the palette itself.
            color: Colors.transparent,
            child: Container(
              padding: EdgeInsets.only(bottom: navInset),
              decoration: BoxDecoration(
                color: palette.bgBottom
                    .withValues(alpha: 0.985 * theme.drawerOpacity),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(
                  top: BorderSide(
                      color: palette.onDark.withValues(alpha: 0.16)),
                ),
              ),
              child: Column(
                children: [
                  _Handle(theme: theme),
                  _Search(theme: theme, height: _searchHeight),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: _railWidth,
                          child: _Rail(
                            theme: theme,
                            buckets: buckets,
                            selectedId: selected.id,
                            itemSize: _railItem,
                            onSelect: (id) => setState(() => _selected = id),
                          ),
                        ),
                        VerticalDivider(width: 1, thickness: 1, color: line),
                        Expanded(
                          child: _Apps(
                            theme: theme,
                            bucket: selected,
                            rowHeight: _rowHeight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, thickness: 1, color: line),
                  _Foot(theme: theme, height: _footHeight),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The drag affordance at the top of the sheet.
///
/// Drawn, not wired. Dismissal is the scrim and the back gesture, both of which
/// already work; a handle that does nothing when dragged would be worse than
/// none, so this is deliberately paired with the sheet being dismissible by the
/// gestures a sheet is normally dismissed by.
class _Handle extends StatelessWidget {
  const _Handle({required this.theme});

  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: theme.palette.onDark.withValues(alpha: 0.24),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

/// The category rail.
///
/// Icon only at rest, which is what keeps it 56dp wide on a 360dp screen and
/// still leaves the app list a readable 304. The selected slot's NAME is the
/// heading above the list, so nothing is unlabelled: the rail says which, the
/// heading says what.
class _Rail extends ConsumerWidget {
  const _Rail({
    required this.theme,
    required this.buckets,
    required this.selectedId,
    required this.itemSize,
    required this.onSelect,
  });

  final EffectiveTheme theme;
  final List<_Bucket> buckets;
  final String selectedId;
  final double itemSize;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = theme.palette;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: buckets.length,
      itemBuilder: (context, i) {
        final b = buckets[i];
        final on = b.id == selectedId;

        return Center(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.selectionClick();
              onSelect(b.id);
            },
            // The whole folder editor, from the rail, with no intermediate
            // screen. `folder_overlay` already owns rename, add, remove,
            // reorder and dissolve, so this is a route and not a feature.
            onLongPress: b.folder == null
                ? null
                : () {
                    HapticFeedback.mediumImpact();
                    openDrawerFolder(context, ref, theme, b.folder!);
                  },
            child: Container(
              width: itemSize,
              height: itemSize,
              margin: const EdgeInsets.symmetric(vertical: 1),
              decoration: BoxDecoration(
                color: on ? palette.accent : null,
                borderRadius: BorderRadius.circular(14),
              ),
              // ─── AN ICON, NEVER `FolderGlyph` ───────────────────────────
              //
              // The first cut drew the folder artwork here with its members
              // tucked in, which is the right picture on a home-screen tile
              // and wrong twice over in a 48dp rail. At that size three
              // overlapping app icons are noise rather than information, and
              // `assets/svg/folder.svg` renders as nothing when it is missing
              // from pubspec's asset list, which `flutter_svg` reports by
              // logging and drawing empty. On device that left the rail as a
              // column of squashed icon strips with no folder behind them.
              //
              // A glyph cannot fail that way: it is a code point in a font
              // Flutter already ships, and the resolution chain ends at
              // [kFolderGlyphFallback] rather than at nothing.
              child: Icon(
                b.icon,
                size: 22,
                color: on
                    ? palette.bgBottom
                    : palette.onDark.withValues(alpha: 0.72),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The selected bucket's apps, one per row.
class _Apps extends ConsumerWidget {
  const _Apps({
    required this.theme,
    required this.bucket,
    required this.rowHeight,
  });

  final EffectiveTheme theme;
  final _Bucket bucket;
  final double rowHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = theme.palette;

    if (bucket.apps.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            context.t('drawer.noApps'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: theme.typography.display,
              fontSize: 13 * theme.textScale,
              color: palette.onDark.withValues(alpha: 0.45),
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 8),
      // One extra for the heading, which SCROLLS rather than pinning. Pinning
      // it would cost a row of the list on a short phone to restate something
      // the highlighted rail slot already says.
      itemCount: bucket.apps.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
            child: Text(
              bucket.name.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: theme.typography.display,
                fontSize: 11 * theme.textScale,
                letterSpacing: 0.9,
                fontWeight: FontWeight.w600,
                color: palette.accent,
              ),
            ),
          );
        }

        final a = bucket.apps[i - 1];
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.lightImpact();
            launchDrawerApp(ref, a);
          },
          onLongPress: () => showDrawerAppMenu(
            context,
            ref,
            theme,
            a,
            anchor: AnchoredMenu.anchorOf(context),
          ),
          child: SizedBox(
            height: rowHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  AppIcon(entry: a, size: 40),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      a.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: theme.typography.display,
                        fontSize: 14 * theme.textScale,
                        color: palette.onDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The launcher's own two, across the foot.
///
/// Unchanged in content from the corner menu, and for the reason its comment
/// gave: a phone launcher has no session to lock, leave or shut down, so the
/// foot carries the two things it genuinely has. Only the targets grew to 40dp.
class _Foot extends ConsumerWidget {
  const _Foot({required this.theme, required this.height});

  final EffectiveTheme theme;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget button(IconData icon, String label, VoidCallback onTap) => Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.lightImpact();
              onTap();
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: theme.palette.onDark.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: theme.typography.display,
                      fontSize: 13 * theme.textScale,
                      color: theme.palette.onDark.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

    return SizedBox(
      height: height,
      child: Row(
        children: [
          button(
            Icons.tune,
            context.t('drawer.gLauncher'),
            () => openLauncherSettings(context, theme),
          ),
          button(
            Icons.settings,
            context.t('drawer.deviceSettings'),
            () => activateDrawerItem(
              context,
              ref,
              theme,
              const DeviceSettingsItem(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Search, above the rail and the list.
///
/// Above BOTH, for the reason the corner menu's own search gave: a field beside
/// the list would read as searching only the selected category, and the one
/// thing this menu has to make obvious is that search goes past the rail
/// entirely.
class _Search extends StatelessWidget {
  const _Search({required this.theme, required this.height});

  final EffectiveTheme theme;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SearchPage(theme: theme),
          ),
        ),
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: theme.palette.onDark.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: theme.palette.onDark.withValues(alpha: 0.12),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.search,
                size: 20,
                color: theme.palette.accent,
              ),
              const SizedBox(width: 10),
              Text(
                context.t('drawer.searchApps'),
                style: TextStyle(
                  fontFamily: theme.typography.display,
                  fontSize: 14 * theme.textScale,
                  color: theme.palette.onDark.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
