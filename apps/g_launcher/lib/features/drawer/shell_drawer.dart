import 'package:flutter/widgets.dart';

import '../../engine/effective_theme.dart';
import '../../engine/theme_spec.dart';
import 'app_drawer.dart';
import 'kickoff_drawer.dart';
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
  Widget build(BuildContext context) => switch (theme.shell) {
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
