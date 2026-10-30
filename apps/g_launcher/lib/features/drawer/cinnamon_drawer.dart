import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../design/components/anchored_menu.dart';
import '../../engine/effective_theme.dart';
import '../../platform/launcher_api.g.dart';
import '../command/command_rows.dart';
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

/// Which category's flyout is open in cascade mode, by row key: [_allKey] for
/// All applications, null for none.
///
/// Separate from [_categoryProvider] and `autoDispose`, because the two menus
/// remember differently. Cinnamon reopens on the category you left; Plasma's
/// Application Menu reopens closed, with no flyout, every time.
final _flyoutProvider = StateProvider.autoDispose<String?>((ref) => null);

/// Row key for All applications. Category names are never empty, so the empty
/// string cannot collide with one.
const _allKey = '';

/// A row key no category can carry, for "no row selected". Category names are
/// labels from a theme, and a NUL is not something a label contains.
const _noneKey = '\u0000';

class CinnamonDrawer extends ConsumerWidget {
  const CinnamonDrawer({super.key, required this.theme, this.cascade = false});

  final EffectiveTheme theme;

  /// Plasma's Application Menu (`appDrawer: "kicker"`) rather than Cinnamon.
  ///
  /// The same favourites and categories, with two differences that are the
  /// whole look of the thing. The apps are not a third column: they open as a
  /// flyout beside the menu when a category is tapped, the way the desktop
  /// menu cascades. And the settings buttons sit at the foot of the favourites
  /// strip, where Plasma puts leave and power, so search has the foot alone.
  final bool cascade;

  /// Width of the category column in cascade mode. Wider than Cinnamon's,
  /// because each row also carries a chevron.
  static const _cascadeCategoryWidth = 168.0;

  /// The foot strip's fixed height, so the flyout can stand exactly on it.
  static const footHeight = 48.0;

  /// The gap left around the menu.
  ///
  /// ─── IT USED TO BE 246dp WIDE ──────────────────────────────────────────
  ///
  /// The argument was that leaving the wallpaper visible down one side is what
  /// keeps a menu a menu rather than a sheet. True on a desktop, where 246dp is
  /// a quarter of the screen. On a 360dp phone it is two thirds, and what it
  /// actually bought was an 80dp category column that could not fit the words
  /// "Sound and Video", a 17dp app icon, and 10.5pt labels that truncated
  /// halfway through "ALL Currency Converter".
  ///
  /// Three columns need the width. The menu still reads as a menu because it is
  /// anchored to the button, has a border and a shadow, and stops well short of
  /// the top of the screen.
  static const _inset = 6.0;

  /// How tall the three columns are, above the foot.
  ///
  /// Fixed rather than shrink-wrapped, for `WhiskerDrawer`'s reason: the app
  /// column changes length when you pick a category, and a menu that grew and
  /// shrank would move the search field you were reaching for.
  ///
  /// A SHARE of the screen rather than 250dp flat. The rows are 48dp now, so
  /// 250 showed five apps; the same fraction shows a useful list on a small
  /// phone and a longer one on a tall device, which is what the space is for.
  static double _colsHeight(BuildContext context) =>
      (MediaQuery.of(context).size.height * 0.46).clamp(260.0, 460.0);

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

    if (cascade) {
      return _cascadeMenu(context, ref, apps, buckets, named);
    }

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
          // the left end of the bottom panel since 2011. It now runs to the
          // right edge as well, because three columns of readable text do not
          // fit in two thirds of a phone.
          left: _inset,
          right: _inset,
          bottom: _inset,
          child: _Menu(
            theme: theme,
            favourites: favourites,
            categories: named,
            active: active,
            apps: listed,
            height: _colsHeight(context),
            onCategory: (n) => ref.read(_categoryProvider.notifier).state = n,
          ),
        ),
      ],
    );
  }

  /// The Application Menu: a narrow menu on the corner, and a flyout beside it.
  Widget _cascadeMenu(
    BuildContext context,
    WidgetRef ref,
    List<AppEntry> apps,
    Map<String, List<AppEntry>> buckets,
    List<String> named,
  ) {
    final rawOpen = ref.watch(_flyoutProvider);
    final open =
        (rawOpen == null || rawOpen == _allKey || named.contains(rawOpen))
            ? rawOpen
            : null;

    // Typing opens the flyout on the results, whatever is selected, and
    // searches everything, for the reason Cinnamon mode does.
    final query = ref.watch(_queryProvider).trim();
    final List<AppEntry>? flyApps = query.isNotEmpty
        ? [for (final r in ref.watch(paletteResultsProvider(theme))) r.item]
        : open == null
            ? null
            : open == _allKey
                ? apps
                : (buckets[open] ?? const <AppEntry>[]);

    final byKey = {for (final a in apps) a.componentKey: a};
    final favourites = <AppEntry>[
      for (final k in theme.prefs.favourites)
        if (byKey[k] != null) byKey[k]!,
    ];

    final size = MediaQuery.sizeOf(context);
    final colsHeight = _colsHeight(context);
    const menuWidth = _Favourites._width + _cascadeCategoryWidth;

    // ─── THE FLYOUT OVERLAPS THE MENU ON A PHONE, ON PURPOSE ─────────────
    //
    // On a desktop the flyout sits wholly to the right of the menu. A 360dp
    // phone has about 170dp left over, which cuts every app name. So the
    // flyout takes a readable width and slides left over the category column
    // when it must, leaving the favourites strip and the start of each
    // category in view: still a cascade, and still a list you can read.
    final flyWidth = (size.width * 0.58).clamp(200.0, 320.0);
    final maxLeft = size.width - _inset - flyWidth;
    const wantLeft = _inset + menuWidth - 6;
    final flyLeft = maxLeft < _inset
        ? _inset
        : (wantLeft < maxLeft ? wantLeft : maxLeft);

    void toggle(String key) {
      HapticFeedback.selectionClick();
      final n = ref.read(_flyoutProvider.notifier);
      n.state = n.state == key ? null : key;
    }

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
          left: _inset,
          bottom: _inset,
          width: menuWidth,
          child: _Menu(
            theme: theme,
            favourites: favourites,
            categories: named,
            active: open,
            apps: const [],
            height: colsHeight,
            cascade: true,
            onCategory: (key) => toggle(key ?? _allKey),
          ),
        ),
        if (flyApps != null)
          Positioned(
            left: flyLeft,
            width: flyWidth,
            bottom: _inset + footHeight + 1,
            height: colsHeight,
            child: _Flyout(theme: theme, apps: flyApps),
          ),
      ],
    );
  }
}

/// The apps of one category, standing beside the Application Menu.
class _Flyout extends StatelessWidget {
  const _Flyout({required this.theme, required this.apps});

  final EffectiveTheme theme;
  final List<AppEntry> apps;

  @override
  Widget build(BuildContext context) {
    final palette = theme.palette;
    return Material(
      color: Colors.transparent,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color:
              palette.bgBottom.withValues(alpha: 0.985 * theme.drawerOpacity),
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
        child: _Apps(theme: theme, apps: apps),
      ),
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
    this.cascade = false,
  });

  final EffectiveTheme theme;
  final List<AppEntry> favourites;
  final List<String> categories;

  /// The selected row. In Cinnamon mode null is All applications; in cascade
  /// mode null is no row and [_allKey] is All applications.
  final String? active;
  final List<AppEntry> apps;
  final double height;
  final ValueChanged<String?> onCategory;

  /// Application Menu presentation. See [CinnamonDrawer.cascade].
  final bool cascade;

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
                  _Favourites(
                    theme: theme,
                    apps: favourites,
                    line: line,
                    sessionButtons: cascade,
                  ),
                  if (cascade)
                    Expanded(
                      child: _Categories(
                        theme: theme,
                        categories: categories,
                        // Back to Cinnamon's convention, where null is All.
                        // Nothing open maps to a key no row carries.
                        active:
                            active == _allKey ? null : (active ?? _noneKey),
                        line: null,
                        chevrons: true,
                        onCategory: onCategory,
                      ),
                    )
                  else ...[
                    _Categories(
                      theme: theme,
                      categories: categories,
                      active: active,
                      line: line,
                      onCategory: onCategory,
                    ),
                    Expanded(child: _Apps(theme: theme, apps: apps)),
                  ],
                ],
              ),
            ),
            Divider(height: 1, thickness: 1, color: line),
            SizedBox(
              height: CinnamonDrawer.footHeight,
              child: _Foot(theme: theme, buttons: !cascade),
            ),
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
    this.sessionButtons = false,
  });

  final EffectiveTheme theme;
  final List<AppEntry> apps;
  final Color line;

  /// The settings buttons at the foot of the strip, where Plasma's menu keeps
  /// leave, restart and power. Cascade mode only; Cinnamon keeps them beside
  /// its search field.
  final bool sessionButtons;

  /// 36 held a 22dp icon with 7dp either side, which is a 36dp target on a
  /// surface where everything else is now 48. The icon grows with it: these are
  /// the apps somebody pinned, so they are the ones most often reached for.
  static const _width = 52.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: _width,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: line)),
      ),
      child: sessionButtons
          ? Column(
              children: [
                Expanded(child: _list()),
                _sessionButtons(context, ref),
              ],
            )
          : _list(),
    );
  }

  Widget _sessionButtons(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
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

  Widget _list() {
    return Consumer(
      builder: (context, ref, _) => ListView(
        padding: const EdgeInsets.symmetric(vertical: 5),
        children: [
          for (final a in apps)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
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
                  child: AppIcon(entry: a, size: 30),
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
    this.chevrons = false,
  });

  final EffectiveTheme theme;
  final List<String> categories;
  final String? active;

  /// The column's right rule. Null in cascade mode, where the column is the
  /// menu's last and the menu's own border closes it.
  final Color? line;
  final ValueChanged<String?> onCategory;

  /// A chevron on every row, saying the row opens something rather than
  /// filtering in place. Cascade mode only.
  final bool chevrons;

  /// Sized to hold the longest category WHOLE.
  ///
  /// 80 truncated "Sound and Video" to "Sound and ...", which is the one thing
  /// a category column must never do: the label is the only way to tell what is
  /// in it. 124 fits it at 13pt with room for the padding, and anything longer
  /// in another language wraps to a second line rather than being cut.
  static const _width = 124.0;

  @override
  Widget build(BuildContext context) {
    final palette = theme.palette;

    Widget withChevron(bool on, Widget text) {
      if (!chevrons) return text;
      return Row(
        children: [
          Expanded(child: text),
          Icon(
            Icons.chevron_right,
            size: 18,
            color: on ? palette.bar : palette.onDark.withValues(alpha: 0.45),
          ),
        ],
      );
    }

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
          // 48dp, the floor for anything a thumb aims at. The old row was 22.
          constraints: const BoxConstraints(minHeight: 48),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          // A full-width FILL, not a left bar. Cinnamon selects its category by
          // painting the whole row, and Kickoff's rail uses the bar; keeping
          // them apart is most of what stops the two menus reading alike in a
          // thumbnail.
          color: on ? palette.accent : Colors.transparent,
          child: withChevron(
            on,
            Text(
              label,
              // TWO lines before anything is cut. A category name that does not
              // fit is a category you cannot identify, and German and Portuguese
              // both have one that will not fit on one line at any width this
              // column can afford.
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: theme.typography.display,
                fontSize: 13 * theme.textScale,
                fontWeight: on ? FontWeight.w600 : FontWeight.w400,
                // The BAR colour on the accent. Mint's green is bright enough
                // that white on it is unreadable.
                color: on ? palette.bar : palette.onDark.withValues(alpha: 0.66),
              ),
            ),
          ),
        ),
      );
    }

    final rule = line;
    return Container(
      width: chevrons ? null : _width,
      decoration: BoxDecoration(
        border: rule == null ? null : Border(right: BorderSide(color: rule)),
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
    final query = ref.watch(_queryProvider).trim();
    final palette = theme.palette;

    // While searching, the column leads with the command answers (sums,
    // units, bangs) and, with no app matching, the web and Play rows.
    if (query.isNotEmpty) {
      final block = PaletteCommandBlock(
        query: query,
        hasApps: apps.isNotEmpty,
        style: CommandRowStyle(
          text: palette.onDark,
          muted: palette.onDark.withValues(alpha: 0.55),
          accent: palette.accent,
          fontFamily: theme.typography.display,
          monoFamily: theme.typography.mono,
          scale: theme.textScale,
        ),
        onClose: () => closeApps(ref),
        fillQuery: (v) {
          ref.read(_queryProvider.notifier).state = v;
          ref.read(paletteQueryProvider.notifier).state = v;
        },
      );
      if (apps.isEmpty) return SingleChildScrollView(child: block);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [block, Expanded(child: _list(context, ref))],
      );
    }

    if (apps.isEmpty) {
      return Center(
        child: Text(
          context.t('drawer.noApps'),
          style: TextStyle(
            fontFamily: theme.typography.display,
            fontSize: 13 * theme.textScale,
            color: theme.palette.onDark.withValues(alpha: 0.4),
          ),
        ),
      );
    }

    return _list(context, ref);
  }

  Widget _list(BuildContext context, WidgetRef ref) {
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
          child: Container(
            // 52dp, so a 30dp icon and a two-line label both fit and the row
            // clears the 48dp target floor with a little to spare.
            constraints: const BoxConstraints(minHeight: 52),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                AppIcon(entry: a, size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    a.label,
                    // ─── TWO LINES, BECAUSE ONE CUT THE NAME ────────────
                    //
                    // At 246dp wide this column had about 130dp for a label and
                    // showed "ALL Currency C...", which names nothing. Wrapping
                    // costs a row its second line only when the name needs it,
                    // and almost every app name fits two lines at this width.
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: theme.typography.display,
                      fontSize: 13 * theme.textScale,
                      height: 1.2,
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
  const _Foot({required this.theme, this.buttons = true});

  final EffectiveTheme theme;

  /// The settings buttons beside the field. Off in cascade mode, where they
  /// stand at the foot of the favourites strip instead.
  final bool buttons;

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
            // The foot is a 48dp strip now, matching the rows above it.
            padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
            child: Row(
              children: [
                Icon(
                  Icons.search,
                  size: 20,
                  color: palette.onDark.withValues(alpha: 0.45),
                ),
                const SizedBox(width: 9),
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
                    onSubmitted: (v) => submitPaletteQuery(
                      context,
                      ref,
                      query: v,
                      hasApps:
                          ref.read(paletteResultsProvider(theme)).isNotEmpty,
                      fillQuery: (q) {
                        ref.read(_queryProvider.notifier).state = q;
                        ref.read(paletteQueryProvider.notifier).state = q;
                      },
                      onClose: () => closeApps(ref),
                      launchTopApp: () => launchTopMatch(ref, theme),
                    ),
                    style: TextStyle(
                      fontFamily: theme.typography.display,
                      fontSize: 14 * theme.textScale,
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
                        fontSize: 14 * theme.textScale,
                        color: palette.onDark.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (buttons) ...[
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
          // 48dp square. These sit beside the search field at the foot, which
          // is the densest strip in the menu and the easiest place to hit the
          // wrong thing.
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Icon(
            icon,
            size: 20,
            color: theme.palette.onDark.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}
