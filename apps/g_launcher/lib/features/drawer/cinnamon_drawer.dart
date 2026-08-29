import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../design/components/anchored_menu.dart';
import '../../engine/effective_theme.dart';
import '../../platform/launcher_api.g.dart';
import '../home/workspaces/workspace_controller.dart';
import '../palette/palette_controller.dart';
import 'app_icon.dart';
import 'drawer_actions.dart';
import 'drawer_items.dart';
import 'package:g_launcher/i18n/i18n.dart';

/// Cinnamon's menu: favourites, categories and apps, side by side.
///
/// ─── THREE COLUMNS, AND THAT IS THE WHOLE ARGUMENT ──────────────────────────
///
/// Kickoff is a rail beside a list, which is two. Whisker is a list with a
/// category strip under it, which is one plus a footer. This is genuinely
/// three, all visible at once, and it is the oldest continuously shipped menu
/// in Linux precisely because its users will not have it changed.
///
/// Drawing it as Kickoff with different labels was the available shortcut and
/// it is the substitution this catalogue keeps having to undo: Mint on the
/// shared Kickoff is one field from KDE, and no palette closes that.
///
/// ─── WHY THE FAVOURITES COLUMN IS ICONS ONLY ────────────────────────────────
///
/// Real Cinnamon gives it about 40px and no labels. On a 246dp popup, three
/// labelled columns would be three ellipses; the strip carries the six apps you
/// launch by shape rather than by name, which is what a favourites column is
/// for. Their names are still reachable: a long press names the app in the
/// menu's own header.
///
/// ─── AND THE SEARCH IS AT THE FOOT ──────────────────────────────────────────
///
/// Every other drawer here puts search at the top, and `drawerSearchPosition`
/// lets a user move it. Cinnamon's is at the bottom beside the session buttons,
/// fixed, which is why Mint greys that row: the field is part of the foot
/// rather than a bar above the content.
final _categoryProvider = StateProvider<String?>((ref) => null);

/// What is typed in the foot.
///
/// Local and `autoDispose`, for Kickoff's reason: a field inside a menu that
/// stays open must not leave a word in the provider rofi and the TUI share.
final _queryProvider = StateProvider.autoDispose<String>((ref) => '');

class CinnamonDrawer extends ConsumerWidget {
  const CinnamonDrawer({super.key, required this.theme});

  final EffectiveTheme theme;

  /// Wide, for a corner menu.
  ///
  /// `WhiskerDrawer` takes 208 for a single column. Three need more, and this
  /// is the widest of the compact drawers without becoming a sheet: on a 360dp
  /// phone it still leaves the wallpaper visible down one side, which is what
  /// keeps it a menu.
  static const _width = 246.0;

  /// How tall the three columns are, above the foot.
  ///
  /// Fixed rather than shrink-wrapped, for `WhiskerDrawer`'s reason: the app
  /// column changes length when you pick a category, and a menu that grew and
  /// shrank would move the search field you were reaching for.
  static const _colsHeight = 250.0;

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

    final named = [
      for (final n in cats.order)
        if (buckets[n] != null) n,
    ];

    final open = ref.watch(_categoryProvider);
    // Null is ALL, which is Cinnamon's first entry and its default. Not the
    // favourites: those have their own column and are visible whatever the
    // category column has selected.
    final active = (open != null && named.contains(open)) ? open : null;

    // ─── TYPING NARROWS THE THIRD COLUMN, NOTHING ELSE MOVES ──────────────
    //
    // The favourites strip and the category column stay where they are. That is
    // the whole reason Cinnamon searches in place rather than on a page: the
    // menu is three columns and only one of them is a result list.
    //
    // A query searches EVERYTHING rather than the selected category, for
    // Kickoff's reason: filtering within Office and being told a name you can
    // see under All does not exist reads as the search being broken.
    final query = ref.watch(_queryProvider).trim();
    final listed = query.isNotEmpty
        ? [for (final r in ref.watch(paletteResultsProvider(theme))) r.item]
        : active == null
            ? apps
            : (buckets[active] ?? const <AppEntry>[]);

    final byKey = {for (final a in apps) a.componentKey: a};
    final favourites = <AppEntry>[
      for (final k in theme.prefs.favourites)
        if (byKey[k] != null) byKey[k]!,
    ];

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
          // Bottom left, against the menu button, which on Cinnamon has been at
          // the left end of the bottom panel since 2011.
          left: 3,
          bottom: 3,
          width: _width,
          child: _Menu(
            theme: theme,
            favourites: favourites,
            categories: named,
            active: active,
            apps: listed,
            height: _colsHeight,
            onCategory: (n) =>
                ref.read(_categoryProvider.notifier).state = n,
          ),
        ),
      ],
    );
  }
}

class _Menu extends ConsumerWidget {
  const _Menu({
    required this.theme,
    required this.favourites,
    required this.categories,
    required this.active,
    required this.apps,
    required this.height,
    required this.onCategory,
  });

  final EffectiveTheme theme;
  final List<AppEntry> favourites;
  final List<String> categories;
  final String? active;
  final List<AppEntry> apps;
  final double height;
  final ValueChanged<String?> onCategory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = theme.palette;
    final line = palette.onDark.withValues(alpha: 0.10);

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color:
              palette.bgBottom.withValues(alpha: 0.985 * theme.drawerOpacity),
          // Near-square. Mint authors a 0.14 corner radius and its whole visual
          // argument is that nothing has changed since 2011.
          borderRadius: BorderRadius.circular(theme.icons.cornerRadius * 8),
          border: Border.all(color: palette.onDark.withValues(alpha: 0.16)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: height,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Favourites(theme: theme, apps: favourites, line: line),
                  _Categories(
                    theme: theme,
                    categories: categories,
                    active: active,
                    line: line,
                    onCategory: onCategory,
                  ),
                  Expanded(child: _Apps(theme: theme, apps: apps)),
                ],
              ),
            ),
            Divider(height: 1, thickness: 1, color: line),
            _Foot(theme: theme),
          ],
        ),
      ),
    );
  }
}

/// The narrow strip: pinned apps, icons only.
class _Favourites extends ConsumerWidget {
  const _Favourites({
    required this.theme,
    required this.apps,
    required this.line,
  });

  final EffectiveTheme theme;
  final List<AppEntry> apps;
  final Color line;

  static const _width = 36.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: _width,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: line)),
      ),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 5),
        children: [
          for (final a in apps)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3.5),
              child: Center(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    launchDrawerApp(ref, a);
                  },
                  // The only place these apps are NAMED. The strip is icons
                  // only by design, so the menu's own header is what tells you
                  // which one you are holding.
                  onLongPress: () => showDrawerAppMenu(
                    context,
                    ref,
                    theme,
                    a,
                    anchor: AnchoredMenu.anchorOf(context),
                  ),
                  child: AppIcon(entry: a, size: 22),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The middle column: category names, one selected.
class _Categories extends StatelessWidget {
  const _Categories({
    required this.theme,
    required this.categories,
    required this.active,
    required this.line,
    required this.onCategory,
  });

  final EffectiveTheme theme;
  final List<String> categories;
  final String? active;
  final Color line;
  final ValueChanged<String?> onCategory;

  static const _width = 80.0;

  @override
  Widget build(BuildContext context) {
    final palette = theme.palette;

    Widget row(String? name, String label) {
      final on = name == active;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onCategory(name);
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
          // A full-width FILL, not a left bar. Cinnamon selects its category by
          // painting the whole row, and Kickoff's rail uses the bar; keeping
          // them apart is most of what stops the two menus reading alike in a
          // thumbnail.
          color: on ? palette.accent : Colors.transparent,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: theme.typography.display,
              fontSize: 9.5 * theme.textScale,
              fontWeight: on ? FontWeight.w600 : FontWeight.w400,
              // The BAR colour on the accent. Mint's green is bright enough
              // that white on it is unreadable at 9.5pt.
              color: on ? palette.bar : palette.onDark.withValues(alpha: 0.66),
            ),
          ),
        ),
      );
    }

    return Container(
      width: _width,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: line)),
      ),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 3),
        children: [
          row(null, context.t('drawer.allApps')),
          for (final c in categories) row(c, c),
        ],
      ),
    );
  }
}

/// The right column: the selected category's apps.
class _Apps extends ConsumerWidget {
  const _Apps({required this.theme, required this.apps});

  final EffectiveTheme theme;
  final List<AppEntry> apps;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (apps.isEmpty) {
      return Center(
        child: Text(
          context.t('drawer.noApps'),
          style: TextStyle(
            fontFamily: theme.typography.display,
            fontSize: 10 * theme.textScale,
            color: theme.palette.onDark.withValues(alpha: 0.4),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 3),
      itemCount: apps.length,
      itemBuilder: (context, i) {
        final a = apps[i];
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
            child: Row(
              children: [
                AppIcon(entry: a, size: 17),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    a.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: theme.typography.display,
                      fontSize: 10.5 * theme.textScale,
                      color: theme.palette.onDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Search and the session buttons, across the foot.
///
/// ─── THE SESSION BUTTONS ARE THE TWO THAT DO SOMETHING ──────────────────────
///
/// Cinnamon's foot carries lock, log out and shut down. A phone launcher can do
/// none of those: locking is the power button, there is no session to leave,
/// and shutting down is a system menu Android owns. Three glyphs that all
/// refuse would be worse than none.
///
/// So the foot carries the two the launcher genuinely has, which is what every
/// other drawer here already puts at its bottom edge: its own settings and the
/// device's. The shape is Cinnamon's; the contents are honest.
class _Foot extends ConsumerWidget {
  const _Foot({required this.theme});

  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = theme.palette;

    return Row(
      children: [
        // ── THE FIELD, IN PLACE ──────────────────────────────────────
        //
        // This opened the shared page, which navigated away from a
        // three-column menu to show a one-column list. `capabilities.dart`
        // already greys Mint's search-position row because Cinnamon's field
        // cannot move; this makes the field behave like the setting describes.
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(9, 4, 6, 4),
            child: Row(
              children: [
                Icon(
                  Icons.search,
                  size: 14,
                  color: palette.onDark.withValues(alpha: 0.45),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: TextField(
                    autocorrect: false,
                    enableSuggestions: false,
                    onChanged: (v) {
                      ref.read(_queryProvider.notifier).state = v;
                      // AND the shared one, which is what
                      // `paletteResultsProvider` reads. The local copy is what
                      // this menu forgets on close.
                      ref.read(paletteQueryProvider.notifier).state = v;
                    },
                    style: TextStyle(
                      fontFamily: theme.typography.display,
                      fontSize: 10.5 * theme.textScale,
                      color: palette.onDark,
                    ),
                    cursorColor: palette.accent,
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      hintText: context.t('drawer.searchApps'),
                      hintStyle: TextStyle(
                        fontFamily: theme.typography.display,
                        fontSize: 10.5 * theme.textScale,
                        color: palette.onDark.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        _FootButton(
          theme: theme,
          icon: Icons.tune,
          label: context.t('drawer.gLauncher'),
          onTap: () => openLauncherSettings(context, theme),
        ),
        _FootButton(
          theme: theme,
          icon: Icons.settings,
          label: context.t('drawer.deviceSettings'),
          onTap: () => activateDrawerItem(
            context,
            ref,
            theme,
            const DeviceSettingsItem(),
          ),
        ),
      ],
    );
  }
}

class _FootButton extends StatelessWidget {
  const _FootButton({
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
    return Semantics(
      button: true,
      // Glyph only, so the foot stays one line beside the search field. The
      // label lives here rather than under the icon, which is the trade the
      // tool menu's footer makes the other way because it has the width.
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
          child: Icon(
            icon,
            size: 15,
            color: theme.palette.onDark.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}
