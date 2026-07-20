import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../data/usage/usage_repository.dart';
import '../../engine/effective_theme.dart';
import '../search/search_page.dart';
import 'app_icon.dart';
import 'drawer_actions.dart';
import 'drawer_items.dart';

/// Which rail tab Kickoff is showing. Session state, not a preference: Kickoff
/// opens on Favorites every time, exactly like the real thing.
enum KickoffTab { favorites, frequent, all }

final _tabProvider =
    StateProvider.autoDispose<KickoffTab>((ref) => KickoffTab.favorites);

/// KDE Plasma's Kickoff menu.
///
/// The shape that says "KDE" is not a grid — it is a **category rail on the left
/// and a list of icon-and-name rows on the right**, with system actions along
/// the bottom. That list row is the signature: GNOME shows you a wall of icons,
/// Kickoff shows you a menu.
///
/// **Where the categories come from.** Android apps carry no freedesktop
/// categories, so "Games / Office / Development" would have to be invented — a
/// heuristic, or a Play Store lookup, both of which are wrong often enough to be
/// annoying. So the rail uses what the launcher already knows for certain:
///
///  - **Favorites** — the dock pins (`prefs.favourites`). Literally what KDE's
///    Favorites tab is: the apps you chose.
///  - **Frequent** — `frequentAppsProvider`, the same frecency ranking that
///    fills an unpinned dock.
///  - **All** — everything, A-to-Z, folders included.
///
/// Zero new data, zero guessing, and each tab means something the user can
/// predict. Folders appear in All (and in Favorites/Frequent they cannot, since
/// those are keyed by component key).
///
/// Everything comes off the shared [drawerItemsProvider], so hidden apps, drawer
/// folders and the launcher-owned entries all behave exactly as they do in the
/// GNOME drawer — only the presentation differs. The launcher entries are pulled
/// OUT of the list and rendered as the footer, which is where Kickoff puts its
/// system actions.
class KickoffDrawer extends ConsumerWidget {
  const KickoffDrawer({super.key, required this.theme});

  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(drawerItemsProvider(theme));
    final tab = ref.watch(_tabProvider);

    // Apps and folders go in the list; the two launcher-owned entries go in the
    // footer. The switch is exhaustive so a new DrawerItem variant has to
    // declare which side of that line it falls on.
    final listable = [
      for (final i in items)
        if (switch (i) {
          AppDrawerItem() || FolderDrawerItem() => true,
          LauncherSettingsItem() || DeviceSettingsItem() => false,
        })
          i,
    ];

    final shown = _forTab(ref, tab, listable);

    final searchAtBottom =
        (theme.prefs.drawerSearchPosition ?? 'bottom') != 'top';
    final search = _KickoffSearch(theme: theme);

    // Kickoff paints its OWN surface, and deliberately NOT the way GNOME does.
    // Activities is a translucent wash over the wallpaper; Kickoff is a solid
    // menu welded to the panel — you do not see your desktop through it. Same
    // palette, opposite treatment, which is a large part of why the two shells
    // read as different desktops rather than one drawer in two colours.
    //
    // The shell should mount this full-bleed and add nothing: no back arrow
    // (KDE closes Kickoff by pressing the launcher again or clicking away), no
    // second background.
    // Material, not ColoredBox: the rows and the footer buttons are InkWells,
    // and a shell overlay has no Scaffold above it to supply the Material
    // ancestor they require. Same crash the desktop bar hit; fixed here before
    // it can fire, since it only shows on a KDE theme.
    return Material(
      color: theme.palette.bar,
      child: SafeArea(
        // The footer draws its own bottom inset, so the menu meets the panel.
        bottom: false,
        child: Column(
          children: [
            if (!searchAtBottom) search,
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Rail(theme: theme, active: tab),
                  Expanded(
                    child: shown.isEmpty
                        ? _Empty(theme: theme, tab: tab)
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            itemCount: shown.length,
                            itemBuilder: (context, i) => _Row(
                              // Stable identity so switching tabs or creating a
                              // folder reuses rows instead of re-requesting
                              // every icon from native.
                              key: ValueKey(_idOf(shown[i])),
                              theme: theme,
                              item: shown[i],
                            ),
                          ),
                  ),
                ],
              ),
            ),
            if (searchAtBottom) search,
            _Footer(theme: theme),
          ],
        ),
      ),
    );
  }

  /// A stable identity per row, for widget keys.
  static String _idOf(DrawerItem item) => switch (item) {
        AppDrawerItem(:final entry) => entry.componentKey,
        FolderDrawerItem(:final folder) => folder.id,
        LauncherSettingsItem() => 'launcher-settings',
        DeviceSettingsItem() => 'device-settings',
      };

  /// The rail's three views over the one list.
  ///
  /// Favorites and Frequent are ORDERED by their source (pin order, frecency
  /// rank) rather than alphabetically — that ordering is the whole point of
  /// those tabs. All keeps the provider's A-to-Z.
  List<DrawerItem> _forTab(WidgetRef ref, KickoffTab tab, List<DrawerItem> all) {
    if (tab == KickoffTab.all) return all;

    final byKey = <String, DrawerItem>{
      for (final i in all)
        if (i is AppDrawerItem) i.entry.componentKey: i,
    };

    final keys = switch (tab) {
      KickoffTab.favorites => theme.prefs.favourites,
      KickoffTab.frequent => ref.watch(frequentAppsProvider),
      KickoffTab.all => const <String>[],
    };

    final picked = [
      for (final k in keys)
        if (byKey[k] != null) byKey[k]!,
    ];

    // Nothing used yet on a fresh install. Falling back to the alphabetical
    // head keeps the tab from reading as broken — the same fallback the Plasma
    // panel's task strip already uses. Favorites has no fallback on purpose:
    // an empty Favorites is TRUE (you have pinned nothing) and its empty state
    // says how to fill it.
    if (picked.isEmpty && tab == KickoffTab.frequent) {
      return all.take(12).toList();
    }
    return picked;
  }
}

/// The category rail. Active tab takes the accent, KDE-style: a filled left
/// border and a tinted background.
class _Rail extends ConsumerWidget {
  const _Rail({required this.theme, required this.active});

  final EffectiveTheme theme;
  final KickoffTab active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onDark = theme.palette.onDark;

    return Container(
      width: 74,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: onDark.withValues(alpha: 0.10)),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 6),
          for (final t in KickoffTab.values)
            _RailItem(
              theme: theme,
              tab: t,
              selected: t == active,
              onTap: () => ref.read(_tabProvider.notifier).state = t,
            ),
        ],
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.theme,
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final EffectiveTheme theme;
  final KickoffTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = theme.palette.accent;
    final onDark = theme.palette.onDark;
    final ink = selected ? accent : onDark.withValues(alpha: 0.65);

    final (icon, label) = switch (tab) {
      KickoffTab.favorites => (Icons.star_outline, 'Favorites'),
      KickoffTab.frequent => (Icons.history, 'Frequent'),
      KickoffTab.all => (Icons.apps_outlined, 'All'),
    };

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.14) : null,
          border: Border(
            left: BorderSide(
              color: selected ? accent : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 19, color: ink),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11 * theme.textScale,
                color: ink,
                fontFamily: theme.typography.display,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One Kickoff row: icon, then name. The list-not-grid shape is the signature.
class _Row extends ConsumerWidget {
  const _Row({super.key, required this.theme, required this.item});

  final EffectiveTheme theme;
  final DrawerItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onDark = theme.palette.onDark;
    // Rows are denser than grid tiles; a full-size drawer icon overwhelms them.
    final size = theme.iconSizeDp * 0.62;

    return InkWell(
      onTap: () => activateDrawerItem(context, ref, theme, item),
      onLongPress: switch (item) {
        AppDrawerItem(:final entry) => () =>
            showDrawerAppMenu(context, ref, theme, entry),
        final FolderDrawerItem f => () =>
            drawerFolderSettings(context, ref, theme, f),
        // Neither pin nor uninstall nor rename applies to a launcher entry, and
        // an empty sheet is worse than none.
        LauncherSettingsItem() || DeviceSettingsItem() => null,
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: size,
              height: size,
              child: switch (item) {
                AppDrawerItem(:final entry) =>
                  AppIcon(entry: entry, size: size),
                final FolderDrawerItem f => _FolderGlyph(theme: theme, item: f),
                LauncherSettingsItem() =>
                  LauncherBrandIcon(theme: theme, size: size),
                DeviceSettingsItem() => Icon(
                    Icons.settings,
                    size: size * 0.82,
                    color: onDark,
                  ),
              },
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5 * theme.textScale,
                  color: onDark,
                  fontFamily: theme.typography.display,
                ),
              ),
            ),
            // Folders advertise that tapping opens rather than launches.
            if (item is FolderDrawerItem)
              Icon(
                Icons.chevron_right,
                size: 18,
                color: onDark.withValues(alpha: 0.4),
              ),
          ],
        ),
      ),
    );
  }
}

/// A folder's 2x2 preview, sized for a list row.
class _FolderGlyph extends StatelessWidget {
  const _FolderGlyph({required this.theme, required this.item});

  final EffectiveTheme theme;
  final FolderDrawerItem item;

  @override
  Widget build(BuildContext context) {
    final size = theme.iconSizeDp * 0.62;
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: theme.palette.onDark.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(folderCornerRadius(theme, size)),
      ),
      child: GridView.count(
        crossAxisCount: 2,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 1.5,
        crossAxisSpacing: 1.5,
        children: [
          for (final m in item.members.take(4))
            AppIcon(entry: m, size: size / 2 - 4),
        ],
      ),
    );
  }
}

/// Kickoff's search field. Tapping opens the shared search page, same as the
/// GNOME drawer — one search experience, whichever desktop you are wearing.
class _KickoffSearch extends StatelessWidget {
  const _KickoffSearch({required this.theme});

  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context) {
    final onDark = theme.palette.onDark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => SearchPage(theme: theme)),
        ),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: onDark.withValues(alpha: 0.08),
            // Breeze corners are tighter than Adwaita's pills.
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: onDark.withValues(alpha: 0.12)),
          ),
          child: Row(
            children: [
              Icon(Icons.search, size: 18, color: onDark.withValues(alpha: 0.6)),
              const SizedBox(width: 8),
              Text(
                'Search apps',
                style: TextStyle(
                  color: onDark.withValues(alpha: 0.6),
                  fontFamily: theme.typography.display,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The system row along the bottom — where Kickoff keeps leave/settings actions.
/// These are the launcher-owned [DrawerItem]s, pulled out of the list so they
/// sit where a KDE user expects them instead of alphabetically among the apps.
class _Footer extends ConsumerWidget {
  const _Footer({required this.theme});

  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onDark = theme.palette.onDark;

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: onDark.withValues(alpha: 0.10))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: _FooterButton(
                theme: theme,
                icon: Icons.settings_outlined,
                label: 'G Launcher',
                onTap: () => activateDrawerItem(
                  context,
                  ref,
                  theme,
                  const LauncherSettingsItem(),
                ),
              ),
            ),
            Container(width: 1, height: 26, color: onDark.withValues(alpha: 0.10)),
            Expanded(
              child: _FooterButton(
                theme: theme,
                icon: Icons.tune,
                label: 'Device settings',
                onTap: () => activateDrawerItem(
                  context,
                  ref,
                  theme,
                  const DeviceSettingsItem(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FooterButton extends StatelessWidget {
  const _FooterButton({
    required this.theme,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final EffectiveTheme theme;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = theme.palette.onDark.withValues(alpha: 0.7);

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: ink),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12 * theme.textScale,
                  color: ink,
                  fontFamily: theme.typography.display,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// An honest empty tab. Favorites starts empty for everyone, and saying how to
/// fill it beats an unexplained blank panel.
class _Empty extends StatelessWidget {
  const _Empty({required this.theme, required this.tab});

  final EffectiveTheme theme;
  final KickoffTab tab;

  @override
  Widget build(BuildContext context) {
    final text = switch (tab) {
      KickoffTab.favorites =>
        'Pin an app to the dock and it shows up here.\nHold any app, then Pin to dock.',
      KickoffTab.frequent => 'The apps you use most will collect here.',
      KickoffTab.all => 'No apps.',
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5 * theme.textScale,
            height: 1.5,
            color: theme.palette.onDark.withValues(alpha: 0.5),
            fontFamily: theme.typography.display,
          ),
        ),
      ),
    );
  }
}
