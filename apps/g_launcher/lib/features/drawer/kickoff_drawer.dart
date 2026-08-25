import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../design/components/anchored_menu.dart';
import '../../data/usage/usage_repository.dart';
import '../../engine/effective_theme.dart';
import '../search/search_page.dart';
import 'app_icon.dart';
import 'drawer_actions.dart';
import 'drawer_items.dart';

/// Which rail tab Kickoff is showing. Session state, not a preference: Kickoff
/// opens on Favorites every time, exactly like the real thing.
enum KickoffTab { favorites, frequent, all }

/// One entry in the rail: either one of the three tabs, or a generated
/// category.
///
/// A sealed pair rather than a widened enum, because the categories are not
/// known at compile time. Which buckets exist depends on what is installed, so
/// a `KickoffTab.social` arm would be a promise the device cannot always keep.
class _Slot {
  const _Slot.tab(KickoffTab this.tab) : category = null;
  const _Slot.category(String this.category) : tab = null;

  final KickoffTab? tab;
  final String? category;

  /// Stable across rebuilds, which is what the provider stores. Holding a
  /// [_Slot] directly would need value equality; holding the id needs nothing.
  String get id => tab != null ? 'tab:${tab!.name}' : 'cat:$category';

  String get label => switch (tab) {
        KickoffTab.favorites => 'Favorites',
        KickoffTab.frequent => 'Frequent',
        KickoffTab.all => 'All',
        null => category!,
      };

  IconData get icon => switch (tab) {
        KickoffTab.favorites => Icons.star_outline,
        KickoffTab.frequent => Icons.history,
        KickoffTab.all => Icons.apps_outlined,
        null => switch (category!) {
            'Social' => Icons.people_outline,
            'Media' => Icons.play_circle_outline,
            'Productivity' => Icons.work_outline,
            'Games' => Icons.sports_esports_outlined,
            'News' => Icons.article_outlined,
            'Travel' => Icons.flight_outlined,
            'Utilities' => Icons.build_outlined,
            // 'Other', and anything a newer build adds to kCategoryOrder that
            // this switch has not been taught yet. A glyph, never a crash.
            _ => Icons.more_horiz,
          },
      };
}

/// Session state, not a preference: Kickoff opens on Favorites every time,
/// exactly like the real thing. Stored as [_Slot.id] so a category that stops
/// existing (its last app uninstalled) simply fails to match and the rail falls
/// back to Favorites, rather than holding a dangling reference.
final _slotProvider =
    StateProvider.autoDispose<String>((ref) => 'tab:${KickoffTab.favorites.name}');

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
    final slotId = ref.watch(_slotProvider);

    // Apps and folders go in the list; the two launcher-owned entries go in the
    // footer. The switch is exhaustive so a new DrawerItem variant has to
    // declare which side of that line it falls on.
    final listable = [
      for (final i in items)
        if (switch (i) {
          AppDrawerItem() || FolderDrawerItem() => true,
          // THE TERMINAL GOES IN THE LIST, not the footer, and it is the one
          // launcher entry that does. The footer holds the two SETTINGS
          // entries, which are chrome you configure; the terminal is something
          // you open, which is what the list is for. A third footer button
          // would also put three labels where two already fill the width.
          TerminalDrawerItem() => true,
          LauncherSettingsItem() || DeviceSettingsItem() => false,
        })
          i,
    ];

    // Categories only in the categories rail, so a KDE-rail distro does no
    // bucketing work at all and its drawer is byte-identical to before.
    final buckets = theme.kickoffRail == 'categories'
        ? _bucket(listable)
        : const <String, List<DrawerItem>>{};

    final slots = <_Slot>[
      for (final t in KickoffTab.values) _Slot.tab(t),
      for (final name in kCategoryOrder)
        if (buckets[name] != null) _Slot.category(name),
    ];

    // A category can stop existing between builds (its last app uninstalled),
    // so a stored id that no longer matches falls back rather than showing an
    // empty rail with nothing selected.
    final active =
        slots.firstWhere((s) => s.id == slotId, orElse: () => slots.first);

    final shown = _forSlot(ref, active, listable, buckets);

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
      // Kickoff is the plasma shell's drawer, so it takes the DRAWER setting,
      // not the bar one, even though it is painted in the panel colour: what
      // the user is adjusting is the app list, and `palette.bar` is only where
      // the colour comes from. Breeze's Kickoff is near-solid by design, so
      // this scales an opaque base rather than an authored alpha.
      color: theme.palette.bar.withValues(alpha: theme.drawerOpacity),
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
                  _Rail(theme: theme, slots: slots, active: active),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // The categories rail is icon-only, so the label has to
                        // land somewhere or the user cannot tell Travel from
                        // Utilities. Heading the list is where Cinnamon puts it
                        // and it costs no rail width.
                        if (theme.kickoffRail == 'categories')
                          _ListHeading(theme: theme, slot: active),
                        Expanded(
                          child: shown.isEmpty
                        ? _Empty(theme: theme, slot: active)
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
        TerminalDrawerItem() => 'terminal',
      };

  /// Category buckets, built the SAME way the library drawer builds them.
  ///
  /// Deliberately a copy of the shape in `drawer_items.dart` rather than a call
  /// into it: that function returns FOLDERS, and Kickoff wants flat lists of
  /// rows. What must not diverge is the RULE, so both apply
  /// [categoryFolderName], both sweep sub-threshold buckets into Other, and
  /// both walk [kCategoryOrder]. Those three now live in one place and are
  /// imported here.
  ///
  /// Sweeping matters more here than it looks. Without it a lone Social app
  /// would be reachable from no rail slot at all, because the rail only lists
  /// buckets that survived the threshold. It would be in the list, in the
  /// drawer, and findable only through All.
  Map<String, List<DrawerItem>> _bucket(List<DrawerItem> all) {
    final buckets = <String, List<DrawerItem>>{};
    for (final item in all) {
      if (item is! AppDrawerItem) continue;
      final name = categoryFolderName(item.entry);
      if (name == null) continue;
      (buckets[name] ??= []).add(item);
    }

    final strays = <DrawerItem>[];
    buckets.removeWhere((name, v) {
      if (name == 'Other' || v.length >= kMinCategoryMembers) return false;
      strays.addAll(v);
      return true;
    });
    if (strays.isNotEmpty) (buckets['Other'] ??= []).addAll(strays);

    return buckets;
  }

  /// The rail's views over the one list.
  ///
  /// Favorites and Frequent are ORDERED by their source (pin order, frecency
  /// rank) rather than alphabetically, and that ordering is the whole point of
  /// those tabs. All and the categories keep the provider's A-to-Z.
  List<DrawerItem> _forSlot(
    WidgetRef ref,
    _Slot slot,
    List<DrawerItem> all,
    Map<String, List<DrawerItem>> buckets,
  ) {
    if (slot.category != null) return buckets[slot.category] ?? const [];

    final tab = slot.tab!;
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

/// The rail. Active slot takes the accent, KDE-style: a filled left border and
/// a tinted background.
///
/// ─── TWO WIDTHS, AND THAT IS THE WHOLE DIFFERENTIATION ──────────────────────
///
/// Tabs mode is 74dp with a label under every glyph, which is KDE's Kickoff and
/// what every plasma distro drew before this field existed.
///
/// Categories mode is 56dp and icon-only, because three labelled entries fit a
/// phone and eleven do not: "Productivity" does not render at 74dp, and a rail
/// wide enough for it eats the list. Icon-only also means the two rails read as
/// two menus at a glance rather than as one menu with more rows, which is the
/// point of the field. The active label heads the list instead.
///
/// Scrollable in both modes. Eleven slots at 40dp clears a phone, but a short
/// screen with a large text scale is exactly the device this launcher targets,
/// and a rail that clips its last category is a category the user cannot reach.
class _Rail extends ConsumerWidget {
  const _Rail({
    required this.theme,
    required this.slots,
    required this.active,
  });

  final EffectiveTheme theme;
  final List<_Slot> slots;
  final _Slot active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onDark = theme.palette.onDark;
    final compact = theme.kickoffRail == 'categories';

    return Container(
      width: compact ? 56 : 74,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: onDark.withValues(alpha: 0.10)),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 6),
            for (final s in slots)
              _RailItem(
                theme: theme,
                slot: s,
                compact: compact,
                selected: s.id == active.id,
                onTap: () => ref.read(_slotProvider.notifier).state = s.id,
              ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

/// The active category's name, above the list, in the categories rail only.
///
/// Not a section header inside the ListView: it must not scroll away, because
/// it is the only thing naming what an icon-only rail selected.
class _ListHeading extends StatelessWidget {
  const _ListHeading({required this.theme, required this.slot});

  final EffectiveTheme theme;
  final _Slot slot;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
      child: Text(
        slot.label,
        style: TextStyle(
          fontSize: 11.5 * theme.textScale,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
          color: theme.palette.accent,
          fontFamily: theme.typography.display,
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.theme,
    required this.slot,
    required this.compact,
    required this.selected,
    required this.onTap,
  });

  final EffectiveTheme theme;
  final _Slot slot;

  /// Icon-only, 56dp rail. See [_Rail]'s note.
  final bool compact;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = theme.palette.accent;
    final onDark = theme.palette.onDark;
    final ink = selected ? accent : onDark.withValues(alpha: 0.65);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        // Tighter when icon-only: the label is what needed the vertical room,
        // and eleven slots at the labelled spacing would not clear a phone.
        padding: EdgeInsets.symmetric(vertical: compact ? 11 : 10),
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
            // Semantics, not decoration. An icon-only rail is unreadable to a
            // screen reader without it, and this is the one mode where the
            // visible label is gone.
            Semantics(
              label: compact ? slot.label : null,
              child: Icon(slot.icon, size: compact ? 20 : 19, color: ink),
            ),
            if (!compact) ...[
              const SizedBox(height: 3),
              Text(
                slot.label,
                style: TextStyle(
                  fontSize: 11 * theme.textScale,
                  color: ink,
                  fontFamily: theme.typography.display,
                ),
              ),
            ],
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
            showDrawerAppMenu(context, ref, theme, entry,
                anchor: AnchoredMenu.anchorOf(context)),
        final FolderDrawerItem f => () =>
            drawerFolderSettings(context, ref, theme, f,
                anchor: AnchoredMenu.anchorOf(context)),
        // Neither pin nor uninstall nor rename applies to a launcher entry, and
        // an empty sheet is worse than none. The terminal will eventually earn
        // a menu of its own (new session, snippets, hosts); until those exist,
        // showing an empty one would be the same mistake.
        LauncherSettingsItem() ||
        DeviceSettingsItem() ||
        TerminalDrawerItem() =>
          null,
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
                // A plain glyph rather than the brand mark. The brand mark says
                // "this launcher's own settings"; the terminal is a tool, and
                // it reads as one next to the app icons it sits among.
                TerminalDrawerItem() => Icon(
                    Icons.terminal,
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
  const _Empty({required this.theme, required this.slot});

  final EffectiveTheme theme;
  final _Slot slot;

  @override
  Widget build(BuildContext context) {
    final text = switch (slot.tab) {
      KickoffTab.favorites =>
        'Pin an app to the dock and it shows up here.\nHold any app, then Pin to dock.',
      KickoffTab.frequent => 'The apps you use most will collect here.',
      KickoffTab.all => 'No apps.',
      // A category slot only exists because it had members when the rail was
      // built, so this is the frame between an uninstall and the rebuild. It
      // needs words rather than a blank panel, but it never sits there.
      null => 'Nothing in this category.',
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
