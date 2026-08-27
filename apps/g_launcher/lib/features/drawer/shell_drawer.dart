import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/effective_theme.dart';
import '../../engine/theme_spec.dart';
import 'app_drawer.dart';
import 'kickoff_drawer.dart';
import 'card_drawer.dart';
import 'cinnamon_drawer.dart';
import 'drawer_items.dart';
import 'library_view.dart';
import 'query_drawer.dart';
import 'tool_drawer.dart';
import 'whisker_drawer.dart';
import 'zorin_drawer.dart';
import 'tiling_launcher.dart';

/// Which drawer a shell gets.
///
/// **The seam for "themes are data, not code" applied to the app list.** Every
/// shell shows the same [drawerItemsProvider] contents — the same apps, the same
/// folders, the same launcher entries, filtered by the same per-theme hidden
/// set — but a GNOME desktop shows them as a full-screen Activities grid and a
/// Plasma desktop shows them as a Kickoff menu. Presentation is per SHELL, not
/// per theme, which is why Ubuntu and Fedora share a drawer and only KDE gets
/// the rail: adding a Breeze-family distro is still a data change.
///
/// Shells call this instead of naming a drawer directly. That way a shell never
/// has to know which drawer belongs to it, and adding one is an edit HERE plus
/// the new widget, rather than a hunt through four shell files.
///
/// The switch is exhaustive with no default arm, deliberately: when [ShellKind]
/// gained `aqua` this stopped compiling until its arm was chosen. That is the
/// same rule [ChromeFamily.defaultForShell] and the `DrawerItem` switches
/// follow, and it did its job — see the aqua arm below, which is an INTERIM
/// answer written down as one rather than a default that hid the gap.
class ShellDrawer extends StatelessWidget {
  const ShellDrawer({super.key, required this.theme});

  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context) {
    // ─── THE DISTRO GETS THE FIRST WORD ──────────────────────────────────
    //
    // Checked BEFORE the shell switch, and that ordering is the whole point of
    // `appDrawer`. The class doc above says presentation is per SHELL and that
    // adding a Breeze-family distro is still a data change, which was true and
    // was also the ceiling: five shells map onto three widgets, so eight of
    // fourteen distros shared one drawer and no theme.json could say otherwise.
    // Kali and Ubuntu were handed the identical grid.
    //
    // The switch below stays exhaustive and stays the default. This is an
    // override a distro opts into, not a replacement for the shell rule, which
    // is why an unknown value parses to 'grid' and lands there rather than
    // failing to open.
    if (theme.appDrawer == 'tools') return ToolDrawer(theme: theme);
    if (theme.appDrawer == 'card') return CardDrawer(theme: theme);
    if (theme.appDrawer == 'whisker') return WhiskerDrawer(theme: theme);
    if (theme.appDrawer == 'cinnamon') return CinnamonDrawer(theme: theme);
    if (theme.appDrawer == 'zorin') return ZorinDrawer(theme: theme);
    if (theme.appDrawer == 'query') return QueryDrawer(theme: theme);
    // ─── THE SAME WIDGET `drawerGrouping: "library"` REACHES ──────────────
    //
    // `LibraryView` already existed and already draws the bubbles; this value
    // exists so a product can reach it WITHOUT a preference. See
    // [ThemeLayout.appDrawer]: grouping has a prefs arm and cannot carry an
    // exclusive row.
    if (theme.appDrawer == 'library') return _Library(theme: theme);

    return switch (theme.shell) {
        // GNOME's Activities: full-screen grid, search bar wherever the user
        // put it. The original drawer, now one presentation among several.
        ShellKind.gnome => AppDrawer(theme: theme),

        // KDE's Kickoff: category rail + icon-and-name list + system footer.
        ShellKind.plasma => KickoffDrawer(theme: theme),

        // A tiling WM launches from a keybind into a centred rofi/wofi prompt
        // over a fuzzy-ranked list — no dock, no grid. Shares `fuzzy.dart` with
        // the terminal palette, because "two letters, top hit, enter" should
        // behave identically in both.
        ShellKind.tiling => TilingLauncher(theme: theme),

        // INTERIM: Aqua borrows GNOME's Activities grid.
        //
        // Launchpad is genuinely close to it — a full-screen paged grid of app
        // icons over a blurred desktop — but it differs in ways that are the
        // whole point of it (paged rather than scrolling, folders opening
        // in-place, search at the top rather than wherever the user put it).
        // Borrowing the grid is honest and looks right today; it is not
        // Launchpad, and this comment is here so nobody mistakes it for done.
        ShellKind.aqua => AppDrawer(theme: theme),

        // The terminal shell IS its own drawer: type two letters, press enter.
        // TuiShell never opens an overlay, so this arm is unreachable in
        // practice — it exists to keep the switch exhaustive, and the grid is a
        // safe answer if some future surface does ask a TUI theme for a drawer.
        ShellKind.tui => AppDrawer(theme: theme),
      };
  }
}

/// `LibraryView` needs the resolved item list, and `ShellDrawer` is a
/// StatelessWidget.
///
/// A four-line Consumer rather than converting the class: every other arm above
/// hands its widget the theme and nothing else, and making the whole router a
/// ConsumerWidget so that ONE of seven can read a provider would rebuild the
/// router whenever the app list changed, for six drawers that do not care.
///
/// `libraryGrouped` is what makes the list arrive folders-first; see
/// [EffectiveTheme.libraryGrouped].
class _Library extends ConsumerWidget {
  const _Library({required this.theme});

  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      LibraryView(theme: theme, items: ref.watch(drawerItemsProvider(theme)));
}
