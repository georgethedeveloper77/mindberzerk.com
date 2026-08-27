import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/components/anchored_menu.dart';
import '../../engine/effective_theme.dart';
import '../../platform/launcher_api.g.dart';
import '../home/workspaces/workspace_controller.dart';
import '../search/search_sheet.dart';
import 'app_icon.dart';
import 'drawer_actions.dart';
import 'drawer_items.dart';
import 'package:g_launcher/i18n/i18n.dart';

/// Zorin's menu: pinned apps over everything else.
///
/// ─── STACKED, WHICH IS THE ONE SHAPE NOBODY ELSE USES ───────────────────────
///
/// Five compact drawers now, and the point of a fifth is that it arranges the
/// same material differently rather than colouring it differently:
///
///   * Kickoff  a rail beside a list          two columns
///   * Cinnamon favourites, categories, apps  three columns
///   * Whisker  a list with a strip beneath   one column plus a footer
///   * Slingshot a paged panel with a switch  one region, two views
///   * Zorin    a grid ABOVE a list           two tiers
///
/// Stacking is the Start menu's shape and it says something the columned ones
/// cannot: these eight are different in KIND from the hundred below, not just
/// filed elsewhere. A column of favourites beside a column of apps makes them
/// peers; a grid above a rule makes one of them the answer and the other the
/// fallback, which is what a pinned row is for.
///
/// ─── AND THERE IS NO CATEGORY COLUMN, ON PURPOSE ────────────────────────────
///
/// Zorin's theme.json authored `drawerGrouping: "library"`, which under the
/// shared grid routed it to the full-screen category screen. That field is
/// dropped rather than honoured here: a two-tier menu with a third tier of
/// categories is three tiers, which is Cinnamon lying down. The list is
/// everything, in one run, and search is the way past it.
class ZorinDrawer extends ConsumerWidget {
  const ZorinDrawer({super.key, required this.theme});

  final EffectiveTheme theme;

  /// Wider than Whisker, narrower than a sheet.
  ///
  /// The pinned grid is four across and needs the room; on a 360dp phone this
  /// still leaves the wallpaper down one side, which is what keeps every one of
  /// these a menu rather than a screen.
  static const _width = 232.0;

  /// How many pinned apps the grid shows.
  ///
  /// Two rows of four. A third row would push the all-apps list off a short
  /// phone, and the tier stops meaning "the ones that matter" somewhere around
  /// a dozen anyway.
  static const _pins = 8;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(drawerItemsProvider(theme));

    final apps = <AppEntry>[
      for (final i in items)
        if (i is AppDrawerItem) i.entry,
    ];
    final byKey = {for (final a in apps) a.componentKey: a};

    final pinned = <AppEntry>[
      for (final k in theme.prefs.favourites)
        if (byKey[k] != null) byKey[k]!,
    ].take(_pins).toList();

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
          // Bottom left, against the Start button at the left end of the
          // taskbar. Same corner Whisker and Cinnamon grow from, because it is
          // the same button on all three desktops.
          left: 4,
          bottom: 0,
          width: _width,
          child: _Menu(theme: theme, pinned: pinned, all: apps),
        ),
      ],
    );
  }
}

class _Menu extends ConsumerWidget {
  const _Menu({
    required this.theme,
    required this.pinned,
    required this.all,
  });

  final EffectiveTheme theme;
  final List<AppEntry> pinned;
  final List<AppEntry> all;

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
          // Rounded on TOP only: this menu sits on the taskbar, and rounding
          // the edge it meets would draw a gap that is not there. The same
          // rule `GnomeDockStyle.flat` follows for the same reason.
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          border: Border.all(color: palette.onDark.withValues(alpha: 0.16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Search(theme: theme),
            if (pinned.isNotEmpty) ...[
              _TierHeading(theme: theme, label: context.t('drawer.pinned')),
              _Pins(theme: theme, apps: pinned),
            ],
            // THE RULE IS THE POINT. Without it this is a grid that happens to
            // be above a list; with it, it is two tiers and the eye reads the
            // top one as the answer.
            Divider(height: 1, thickness: 1, color: line),
            _TierHeading(theme: theme, label: context.t('drawer.allApps')),
            Flexible(child: _All(theme: theme, apps: all)),
            Divider(height: 1, thickness: 1, color: line),
            _Foot(theme: theme),
          ],
        ),
      ),
    );
  }
}

/// A tier's name. Small, quiet, uppercase.
class _TierHeading extends StatelessWidget {
  const _TierHeading({required this.theme, required this.label});

  final EffectiveTheme theme;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(11, 6, 11, 5),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            fontFamily: theme.typography.display,
            fontSize: 8 * theme.textScale,
            letterSpacing: 0.9,
            fontWeight: FontWeight.w600,
            color: theme.palette.onDark.withValues(alpha: 0.40),
          ),
        ),
      ),
    );
  }
}

/// The top tier: pinned apps, four across, labelled.
class _Pins extends ConsumerWidget {
  const _Pins({required this.theme, required this.apps});

  final EffectiveTheme theme;
  final List<AppEntry> apps;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(7, 0, 7, 8),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 4,
        mainAxisSpacing: 6,
        childAspectRatio: 0.84,
        children: [
          for (final a in apps)
            GestureDetector(
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIcon(entry: a, size: 30),
                  const SizedBox(height: 3),
                  Flexible(
                    child: Text(
                      a.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: theme.typography.display,
                        fontSize: 7.5 * theme.textScale,
                        color: theme.palette.onDark.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The bottom tier: everything, as a list.
class _All extends ConsumerWidget {
  const _All({required this.theme, required this.apps});

  final EffectiveTheme theme;
  final List<AppEntry> apps;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (apps.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            context.t('drawer.noApps'),
            style: TextStyle(
              fontFamily: theme.typography.display,
              fontSize: 10 * theme.textScale,
              color: theme.palette.onDark.withValues(alpha: 0.4),
            ),
          ),
        ),
      );
    }

    return ConstrainedBox(
      // CAPPED, not shrink-wrapped. With 248 apps a shrink-wrapped list makes
      // the menu taller than the screen, and the foot with search and settings
      // in it would be off the bottom edge where nobody can reach it.
      constraints: const BoxConstraints(maxHeight: 168),
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 4),
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
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
              child: Row(
                children: [
                  AppIcon(entry: a, size: 18),
                  const SizedBox(width: 9),
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
      ),
    );
  }
}

/// The launcher's own two, across the foot.
///
/// Cinnamon's foot argues this at length and the reasoning carries: a phone
/// launcher has no session to lock, leave or shut down, so the foot carries the
/// two things it genuinely has. Zorin's real menu puts its power button here;
/// this puts the settings that exist.
class _Foot extends ConsumerWidget {
  const _Foot({required this.theme});

  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget button(IconData icon, String label, VoidCallback onTap) => Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.lightImpact();
              onTap();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 14,
                    color: theme.palette.onDark.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: theme.typography.display,
                        fontSize: 9.5 * theme.textScale,
                        color: theme.palette.onDark.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

    return Row(
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
    );
  }
}

/// Search, above both tiers.
///
/// Above rather than between, because it searches BOTH: a field sitting under
/// the pinned grid would read as searching only the list beneath it, and the
/// one thing this menu has to make obvious is that the two tiers are one menu.
class _Search extends StatelessWidget {
  const _Search({required this.theme});

  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(9, 9, 9, 2),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => showSearchSheet(context, theme),
        child: Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            color: theme.palette.onDark.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(15),
          ),
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
                  fontSize: 10.5 * theme.textScale,
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
