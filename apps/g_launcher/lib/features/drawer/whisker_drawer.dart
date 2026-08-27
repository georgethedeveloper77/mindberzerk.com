import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../design/components/anchored_menu.dart';
import '../../engine/effective_theme.dart';
import '../../platform/launcher_api.g.dart';
import '../home/workspaces/workspace_controller.dart';
import '../search/search_sheet.dart';
import 'app_icon.dart';
import 'drawer_actions.dart';
import 'drawer_items.dart';
import 'package:g_launcher/i18n/i18n.dart';

/// Whisker: Xfce's menu, anchored at the panel.
///
/// ─── THE THIRD COMPACT DRAWER, AND WHY IT IS NOT THE OTHER TWO ──────────────
///
/// Three menus in this app now refuse to take the screen, and they refuse
/// differently, which is the only reason three of them are worth having.
///
///   * [CardDrawer] is Slingshot: a card that drops from a button in the TOP
///     bar, wide, paged, with a view switcher. It is a panel of apps.
///   * [ToolDrawer] is Kali's: a full-height numbered RAIL beside a list, and
///     it fills the screen precisely because thirteen shelves need the height.
///   * This is Whisker: a narrow column standing on the BOTTOM-LEFT corner,
///     search on top, a short run of apps, and a strip of category buttons
///     along its foot. It is a menu in the Windows sense, and its shape comes
///     from the corner it grows out of.
///
/// The corner is the whole tell. Xfce's menu button lives at the left end of
/// the panel, and everything about Whisker follows from opening there: narrow
/// because a wide popup at the left edge would look like a sheet, bottom-anchored
/// because it grows UP from the button, and short because it is a list of the
/// apps you use rather than all of them.
///
/// ─── AND THE CATEGORY STRIP IS ALONG THE BOTTOM, NOT DOWN THE SIDE ──────────
///
/// Real Whisker puts its categories in a row of small buttons under the app
/// list. That is not decoration: a column of categories would make this the
/// tool menu at half width, and the row is what leaves the popup narrow enough
/// to sit in a corner rather than across the screen.
final _categoryProvider = StateProvider<String?>((ref) => null);

class WhiskerDrawer extends ConsumerWidget {
  const WhiskerDrawer({super.key, required this.theme});

  final EffectiveTheme theme;

  /// Narrow, and fixed rather than a fraction.
  ///
  /// `CardDrawer` takes 86 percent of the width because Slingshot is a panel
  /// and wants the room. This is a corner menu, and a corner menu that grew
  /// with the screen would stop being one on a tablet. 208 is wide enough for
  /// an icon, a label and a count, and narrow enough that the wallpaper is
  /// still obviously there beside it.
  static const _width = 208.0;

  /// How many apps stand above the category strip.
  ///
  /// Whisker shows a short run and expects you to search or pick a category for
  /// the rest. Eight rows plus the search field plus the strip is about 60
  /// percent of a phone's height, which is the most a corner menu can take
  /// before it reads as a screen.
  static const _rows = 8;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(drawerItemsProvider(theme));
    final cats = CategorySet.forTheme(theme);

    final apps = <AppEntry>[
      for (final i in items)
        if (i is AppDrawerItem) i.entry,
    ];

    final buckets = <String, List<AppEntry>>{};
    for (final a in apps) {
      final name = cats.nameFor(a);
      if (name == null) continue;
      (buckets[name] ??= []).add(a);
    }
    cats.sweep(buckets);

    final shown = [
      for (final n in cats.order)
        if (buckets[n] != null) n,
    ];

    final open = ref.watch(_categoryProvider);
    final active = (open != null && shown.contains(open)) ? open : null;

    // Null category means the FAVOURITES run, not everything. Whisker opens on
    // what you use; a fresh install with nothing pinned falls through to the
    // first category so the menu is never empty on first open.
    final listed = active != null
        ? (buckets[active] ?? const <AppEntry>[])
        : _favourites(apps, shown, buckets);

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => closeApps(ref),
            child: const SizedBox.expand(),
          ),
        ),
        Positioned(
          // Bottom LEFT, against the panel it grows from. Not centred and not
          // full width: see the class doc. The 4dp inset is the gap Xfce leaves
          // between the popup and the screen edge.
          left: 4,
          bottom: 4,
          width: _width,
          child: _Popup(
            theme: theme,
            apps: listed,
            categories: shown,
            active: active,
            rows: _rows,
            onCategory: (n) =>
                ref.read(_categoryProvider.notifier).state = n,
          ),
        ),
      ],
    );
  }

  /// The pinned apps, or the first category when nothing is pinned.
  List<AppEntry> _favourites(
    List<AppEntry> apps,
    List<String> order,
    Map<String, List<AppEntry>> buckets,
  ) {
    final byKey = {for (final a in apps) a.componentKey: a};
    final pinned = <AppEntry>[
      for (final k in theme.prefs.favourites)
        if (byKey[k] != null) byKey[k]!,
    ];
    if (pinned.isNotEmpty) return pinned;
    // A menu that opens empty on a fresh install teaches the user it is broken
    // before they have pinned anything, and there is nothing to pin FROM if the
    // menu is the only way to reach an app.
    return order.isEmpty ? apps : (buckets[order.first] ?? apps);
  }
}

class _Popup extends ConsumerWidget {
  const _Popup({
    required this.theme,
    required this.apps,
    required this.categories,
    required this.active,
    required this.rows,
    required this.onCategory,
  });

  final EffectiveTheme theme;
  final List<AppEntry> apps;
  final List<String> categories;
  final String? active;
  final int rows;
  final ValueChanged<String?> onCategory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = theme.palette;
    // Square, or near it. This is the Xfce chrome family, whose whole framing
    // is corners; a rounded popup here would be the one soft thing on the
    // distro.
    final radius = BorderRadius.circular(theme.icons.cornerRadius * 8);

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color:
              palette.bgBottom.withValues(alpha: 0.97 * theme.drawerOpacity),
          borderRadius: radius,
          border: Border.all(color: palette.onDark.withValues(alpha: 0.14)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 26,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Search(theme: theme),
            Divider(
              height: 1,
              thickness: 1,
              color: palette.onDark.withValues(alpha: 0.10),
            ),
            // A FIXED height rather than shrink-wrapping. The list changes
            // length when you pick a category, and a popup that grew and shrank
            // under your finger would move the category strip you are aiming
            // at.
            SizedBox(
              height: rows * 34.0,
              child: apps.isEmpty
                  ? Center(
                      child: Text(
                        context.t('drawer.noApps'),
                        style: TextStyle(
                          fontFamily: theme.typography.display,
                          fontSize: 11 * theme.textScale,
                          color: palette.onDark.withValues(alpha: 0.4),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      itemCount: apps.length,
                      itemBuilder: (context, i) =>
                          _Row(theme: theme, entry: apps[i]),
                    ),
            ),
            Divider(
              height: 1,
              thickness: 1,
              color: palette.onDark.withValues(alpha: 0.10),
            ),
            _Strip(
              theme: theme,
              categories: categories,
              active: active,
              onCategory: onCategory,
            ),
          ],
        ),
      ),
    );
  }
}

/// The category strip along the foot: small buttons, one row, scrolling.
class _Strip extends StatelessWidget {
  const _Strip({
    required this.theme,
    required this.categories,
    required this.active,
    required this.onCategory,
  });

  final EffectiveTheme theme;
  final List<String> categories;
  final String? active;
  final ValueChanged<String?> onCategory;

  @override
  Widget build(BuildContext context) {
    final palette = theme.palette;

    Widget button(String? name, String label) {
      final on = name == active;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onCategory(name);
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: on
                ? palette.accent.withValues(alpha: 0.85)
                : palette.onDark.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(theme.icons.cornerRadius * 8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: theme.typography.display,
              fontSize: 9.5 * theme.textScale,
              fontWeight: on ? FontWeight.w600 : FontWeight.w400,
              // The BAR colour on the accent, not white. The strip is small
              // enough that a white-on-accent chip would read as a badge.
              color: on ? palette.bar : palette.onDark.withValues(alpha: 0.75),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 32,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        children: [
          // Favourites is a category in the strip rather than a tab above it,
          // because in Whisker it IS one: the strip is how you change what the
          // list is showing, and the pinned run is one of the things it can
          // show.
          button(null, context.t('drawer.favourites')),
          for (final c in categories) button(c, c),
        ],
      ),
    );
  }
}

/// One app. A row, not a tile: the popup is 208dp and a grid inside it would be
/// three columns of unreadable labels.
class _Row extends ConsumerWidget {
  const _Row({required this.theme, required this.entry});

  final EffectiveTheme theme;
  final AppEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact();
        launchDrawerApp(ref, entry);
      },
      onLongPress: () => showDrawerAppMenu(
        context,
        ref,
        theme,
        entry,
        anchor: AnchoredMenu.anchorOf(context),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Row(
          children: [
            AppIcon(entry: entry, size: theme.iconSizeDp * 0.5),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                entry.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: theme.typography.display,
                  fontSize: 11.5 * theme.textScale,
                  color: theme.palette.onDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Search, at the top where Whisker puts it.
class _Search extends StatelessWidget {
  const _Search({required this.theme});

  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showSearchSheet(context, theme),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: Row(
          children: [
            Icon(
              Icons.search,
              size: 14,
              color: theme.palette.onDark.withValues(alpha: 0.45),
            ),
            const SizedBox(width: 8),
            Text(
              context.t('drawer.searchApps'),
              style: TextStyle(
                fontFamily: theme.typography.display,
                fontSize: 11.5 * theme.textScale,
                color: theme.palette.onDark.withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
