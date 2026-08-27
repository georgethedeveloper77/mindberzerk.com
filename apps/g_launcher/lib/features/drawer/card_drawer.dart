import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:g_launcher/i18n/i18n.dart';

import '../../design/components/anchored_menu.dart';
import '../../engine/effective_theme.dart';
import '../../platform/launcher_api.g.dart';
import '../home/workspaces/workspace_controller.dart';
import '../search/search_sheet.dart';
import 'app_icon.dart';
import 'drawer_actions.dart';
import 'drawer_items.dart';

/// Slingshot: a card that drops from the Applications button.
///
/// ─── THE POINT IS WHAT IT DOES NOT DO ───────────────────────────────────────
///
/// Every other drawer in this app takes the screen. The GNOME grid, the tool
/// menu, the App Library, even Kickoff at its height. This one is a CARD: it
/// covers about half the display, the wallpaper and the dock stay visible
/// around it, and it points at the button that opened it.
///
/// That restraint is the product. Pantheon's whole argument is that a desktop
/// should interrupt you as little as possible, and a launcher that blanks the
/// screen to show you eight icons is the opposite of it. It is also the cleanest
/// separation available from the other aqua distro: Deepin's launcher IS the
/// screen, and these two now sit at opposite ends of the same shell.
///
/// ─── TWO VIEWS, BECAUSE THE DISTRO ALREADY ASKED FOR BOTH ───────────────────
///
/// elementary authors `drawerGrouping: "library"`, which under the shared
/// `AppDrawer` routed it to the full-screen category screen. That was the
/// distro asking for categories and getting the iPhone. Here the same field
/// selects which of the card's two views opens first, which is what Slingshot
/// itself does with its Grid and Categories toggle.
///
/// So nothing about elementary's theme.json changes to gain the switch. The
/// field it already had stops meaning "take over the screen" and starts meaning
/// what it says.
final _viewProvider = StateProvider<bool>((ref) => false);

/// Which category is open in the Categories view, or null for the list.
final _categoryProvider = StateProvider<String?>((ref) => null);

class CardDrawer extends ConsumerWidget {
  const CardDrawer({super.key, required this.theme});

  final EffectiveTheme theme;

  /// How wide the card is, as a fraction of the screen.
  ///
  /// Not a fixed dp: on a 360dp phone 0.86 is 310dp and on a tablet it is far
  /// too much, but the alternative is a card that looks generous on one device
  /// and cramped on another. Capped below so it stops growing on a big screen,
  /// which is where a launcher card should stay a card.
  static const _widthFraction = 0.86;
  static const _maxWidth = 340.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(drawerItemsProvider(theme));
    final apps = <AppEntry>[
      for (final i in items)
        if (i is AppDrawerItem) i.entry,
    ];

    // The distro's own default. `library` opens on categories, anything else on
    // the grid; see the class doc for why this field rather than a new one.
    final showCategories =
        ref.watch(_viewProvider) || theme.drawerGrouping == 'library';

    final width = (MediaQuery.sizeOf(context).width * _widthFraction)
        .clamp(0.0, _maxWidth);
    final top = MediaQuery.viewPaddingOf(context).top + 26;

    return Stack(
      children: [
        // ─── NO SCRIM ────────────────────────────────────────────────────
        //
        // A dimmed backdrop would make this a modal, and a modal is a thing
        // that has taken over. The card is opaque enough to read against any
        // wallpaper on its own, and leaving the desktop at full brightness is
        // what keeps it feeling like a menu rather than a screen.
        //
        // Full-screen and opaque to hit testing all the same, because a tap
        // anywhere off the card has to close it.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => closeApps(ref),
            child: const SizedBox.expand(),
          ),
        ),
        Positioned(
          // Under the Applications button, which lives at the left of the
          // wingpanel. Not centred: the beak has to point at the thing that
          // opened this, and a centred card with a left-hand beak would be
          // pointing at nothing.
          left: 8,
          top: top,
          width: width,
          child: _Card(
            theme: theme,
            apps: apps,
            showCategories: showCategories,
            onView: (v) => ref.read(_viewProvider.notifier).state = v,
          ),
        ),
      ],
    );
  }
}

class _Card extends ConsumerWidget {
  const _Card({
    required this.theme,
    required this.apps,
    required this.showCategories,
    required this.onView,
  });

  final EffectiveTheme theme;
  final List<AppEntry> apps;
  final bool showCategories;
  final ValueChanged<bool> onView;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = theme.palette;

    return Material(
      color: Colors.transparent,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              color: palette.bgBottom
                  .withValues(alpha: 0.96 * theme.drawerOpacity),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.onDark.withValues(alpha: 0.12)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.42),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Search(theme: theme),
                Flexible(
                  child: showCategories
                      ? _Categories(theme: theme, apps: apps)
                      : _Pages(theme: theme, apps: apps),
                ),
                _Views(
                  theme: theme,
                  showCategories: showCategories,
                  onView: onView,
                ),
              ],
            ),
          ),
          // The beak, pointing back at the Applications button. Outside the
          // Container so the border draws around the card rather than around
          // the beak, and Clip.none above is what lets it sit off the edge.
          Positioned(
            left: 18,
            top: -5,
            child: Transform.rotate(
              angle: 0.785,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: palette.bgBottom
                      .withValues(alpha: 0.96 * theme.drawerOpacity),
                  border: Border(
                    left: BorderSide(
                        color: palette.onDark.withValues(alpha: 0.12)),
                    top: BorderSide(
                        color: palette.onDark.withValues(alpha: 0.12)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The paged grid. Four across, three down, dots underneath.
class _Pages extends ConsumerStatefulWidget {
  const _Pages({required this.theme, required this.apps});

  final EffectiveTheme theme;
  final List<AppEntry> apps;

  @override
  ConsumerState<_Pages> createState() => _PagesState();
}

class _PagesState extends ConsumerState<_Pages> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Four across and three down.
  ///
  /// FIXED rather than `theme.drawerCols`, and that is the one place this
  /// widget ignores a preference on purpose. The card's width is a fraction of
  /// the screen, so five columns inside 310dp is a 55dp cell, and the pref was
  /// written for a full-screen drawer where five is comfortable. A card that
  /// honoured it would be a card whose icons shrink when you change a setting
  /// about a different drawer.
  static const _cols = 4;
  static const _rows = 3;

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    const perPage = _cols * _rows;
    final pages =
        widget.apps.isEmpty ? 1 : (widget.apps.length / perPage).ceil();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          // Measured from the icon rather than guessed: three rows of icon plus
          // label plus the gaps. A fixed height here and a different one in the
          // cell arithmetic is how a grid ends up clipping its last row.
          height: _rows * (theme.iconSizeDp + 30) + 8,
          child: PageView.builder(
            controller: _controller,
            itemCount: pages,
            onPageChanged: (p) => setState(() => _page = p),
            itemBuilder: (context, p) {
              final start = p * perPage;
              final end = (start + perPage).clamp(0, widget.apps.length);
              final slice = widget.apps.sublist(
                start.clamp(0, widget.apps.length),
                end,
              );
              return GridView.count(
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(8, 2, 8, 4),
                crossAxisCount: _cols,
                childAspectRatio: 0.76,
                children: [
                  for (final a in slice) _Tile(theme: theme, entry: a),
                ],
              );
            },
          ),
        ),
        if (pages > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < pages; i++)
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.palette.onDark
                          .withValues(alpha: i == _page ? 0.85 : 0.25),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The category list, and a category opened.
class _Categories extends ConsumerWidget {
  const _Categories({required this.theme, required this.apps});

  final EffectiveTheme theme;
  final List<AppEntry> apps;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = CategorySet.forTheme(theme);

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

    if (active != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 12, 4),
            child: Row(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () =>
                      ref.read(_categoryProvider.notifier).state = null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Icon(Icons.chevron_left,
                        size: 18, color: theme.palette.accent),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    active,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: theme.typography.display,
                      fontSize: 12.5 * theme.textScale,
                      fontWeight: FontWeight.w600,
                      color: theme.palette.onDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: _Pages(theme: theme, apps: buckets[active] ?? const []),
          ),
        ],
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(6, 2, 6, 6),
      itemCount: shown.length,
      itemBuilder: (context, i) {
        final name = shown[i];
        final members = buckets[name] ?? const <AppEntry>[];
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.selectionClick();
            ref.read(_categoryProvider.notifier).state = name;
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                // A stack of three, not a folder glyph and not a 2x2. The card
                // is narrow, so the preview has to say "several things" in
                // about 40dp, and three overlapping squares do that at a size
                // where a 2x2 would be four unreadable smudges.
                SizedBox(
                  width: 40,
                  height: 22,
                  child: Stack(
                    children: [
                      for (var k = 0; k < members.length && k < 3; k++)
                        Positioned(
                          left: k * 9.0,
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: AppIcon(entry: members[k], size: 22),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: theme.typography.display,
                      fontSize: 12 * theme.textScale,
                      color: theme.palette.onDark,
                    ),
                  ),
                ),
                Text(
                  '${members.length}',
                  style: TextStyle(
                    fontFamily: theme.typography.display,
                    fontSize: 10.5 * theme.textScale,
                    color: theme.palette.onDark.withValues(alpha: 0.4),
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

/// The Grid and Categories switch, across the foot of the card.
class _Views extends ConsumerWidget {
  const _Views({
    required this.theme,
    required this.showCategories,
    required this.onView,
  });

  final EffectiveTheme theme;
  final bool showCategories;
  final ValueChanged<bool> onView;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget tab(String label, bool on, VoidCallback onTap) => Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: on
                  ? theme.palette.accent.withValues(alpha: 0.22)
                  : Colors.transparent,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: theme.typography.display,
                  fontSize: 11 * theme.textScale,
                  fontWeight: on ? FontWeight.w600 : FontWeight.w400,
                  color: on
                      ? theme.palette.onDark
                      : theme.palette.onDark.withValues(alpha: 0.55),
                ),
              ),
            ),
          ),
        );

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.palette.onDark.withValues(alpha: 0.10)),
        ),
      ),
      child: Row(
        children: [
          tab(context.t('drawer.viewGrid'), !showCategories, () {
            // Leaving Categories also forgets which one was open. Coming back
            // to a card still filtered to Travel, minutes later, from a tab
            // that says Categories, would be a state nobody asked for.
            ref.read(_categoryProvider.notifier).state = null;
            onView(false);
          }),
          tab(context.t('drawer.viewCategories'), showCategories,
              () => onView(true)),
        ],
      ),
    );
  }
}

class _Tile extends ConsumerWidget {
  const _Tile({required this.theme, required this.entry});

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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(entry: entry, size: theme.iconSizeDp * 0.82),
          const SizedBox(height: 4),
          Flexible(
            child: Text(
              entry.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: theme.typography.display,
                fontSize: 9.5 * theme.textScale,
                color: theme.palette.onDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The search field, at the top of the card where Slingshot puts it.
class _Search extends StatelessWidget {
  const _Search({required this.theme});

  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => showSearchSheet(context, theme),
        child: Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: theme.palette.onDark.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            children: [
              Icon(Icons.search,
                  size: 14, color: theme.palette.onDark.withValues(alpha: 0.5)),
              const SizedBox(width: 7),
              Text(
                context.t('drawer.searchApps'),
                style: TextStyle(
                  fontFamily: theme.typography.display,
                  fontSize: 11.5 * theme.textScale,
                  color: theme.palette.onDark.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
