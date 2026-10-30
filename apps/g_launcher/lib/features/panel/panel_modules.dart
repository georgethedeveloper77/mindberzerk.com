/// The one switch: a [PanelItem] to the widget that draws it.
///
/// ─── WHY THIS IS ONE FUNCTION AND NOT FOUR SWITCHES ────────────────────────
///
/// There were four. `plasma_shell`, `gnome_top_bar`, `aqua_bar_modules` and
/// `tiling_shell` each mapped the same enum to widgets, and each had a
/// different set of holes: Plasma drew nothing for the three readouts, Aqua
/// dropped battery, wifi and app, GNOME had a second tray widget that did not
/// work. None of those holes was a decision anybody made twice; they were what
/// happens when a vocabulary is answered in four places.
///
/// A shell still decides what it DECLINES, which is a real difference: a GNOME
/// bar refuses a kickoff button because a start menu is not GNOME. That
/// decision belongs in the shell. Which widget a module maps to when it is
/// drawn does not, and that is what lives here.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/effective_theme.dart';
import '../../engine/theme_spec.dart' show PanelItem, PanelModule;
import '../home/workspaces/workspace_controller.dart';
import 'applets/panel_battery.dart';
import 'applets/panel_network.dart';
import 'applets/panel_tray_button.dart';
import 'applets/panel_volume.dart';
import 'modules/panel_clock_module.dart';
import 'modules/panel_cosmic_modules.dart';
import 'modules/panel_launchers.dart';
import 'modules/panel_pager.dart';
import 'modules/panel_readouts.dart';
import 'modules/panel_tasks.dart';
import 'modules/panel_title_module.dart';

/// Everything the switch needs that is not on the item itself.
///
/// A record rather than five parameters: the switch is called once per slot in
/// a build, and five positional arguments at that call site is where an
/// orientation flag gets passed as an editing flag.
class PanelHost {
  const PanelHost({
    required this.theme,
    required this.vertical,
    required this.items,
  });

  final EffectiveTheme theme;

  /// True on a left or right panel. Almost every module changes shape for it,
  /// which is why it is here rather than read from the side at each arm.
  final bool vertical;

  /// The whole panel, needed by exactly one arm: the three readouts share a
  /// widget, so the run has to be known to draw it at the first of them.
  final List<PanelItem> items;

  /// The stat modules on this panel, in the theme's order.
  List<PanelModule> get statRun => [
        for (final i in items)
          if (isStatModule(i.kind)) i.kind,
      ];
}

/// Below this width the panel is on an upright phone. See [panelItemsShown].
const double narrowPanelWidth = 600;

/// Whether the panel in [context] has a phone's upright width.
bool panelIsNarrow(BuildContext context) =>
    MediaQuery.sizeOf(context).width < narrowPanelWidth;

/// What leaves an upright phone's panel for quick settings: the three
/// readouts and the pager. Each is useful and none is a thing you tap ten
/// times a day, which is what a 360dp bar has room for.
const Set<PanelModule> wideOnlyModules = {
  PanelModule.network,
  PanelModule.memory,
  PanelModule.storage,
  PanelModule.pager,
};

/// The status modules: what Android's own status bar already prints.
const Set<PanelModule> statusModules = {
  PanelModule.wifi,
  PanelModule.volume,
  PanelModule.battery,
  PanelModule.clock,
};

/// The panel as drawn, given whether Android's status bar is on screen.
///
/// ─── ONE SWITCH DECIDES WHO OWNS THE STATUS ROW ─────────────────────────────
///
/// Wi-Fi, sound, battery and the clock belong in exactly one place. While
/// Android's status bar is showing, that place is Android's, and a panel that
/// draws them as well is a second status bar a few dp away. So they are left
/// out, and whatever stood for the tray (`tray` itself, or the three it expands
/// into off the top edge) collapses back to ONE quick-settings button, which is
/// the part Android cannot offer.
///
/// The user turns them on with "Status icons on the panel", which hides
/// Android's bar in the same write: the panel takes the row over rather than
/// repeating it. The stored module list is never touched, so turning the
/// switch back on restores the panel exactly as it was authored or arranged.
///
/// ─── AND A PHONE HELD UPRIGHT IS NOT A DESKTOP ─────────────────────────────
///
/// A distro authors its panel for a desktop, and a 1920px bar has room for
/// everything. A 360dp one has room for about eight 44dp targets. So when
/// [narrow], the [wideOnlyModules] are left out too (the readouts reappear in
/// quick settings), and the panel draws the menu, the apps and the quick
/// settings button. Turn the phone sideways, or open it on a tablet, and the
/// same stored panel draws in full.
List<PanelItem> panelItemsShown(
  List<PanelItem> items, {
  required bool systemStatusBar,
  bool narrow = false,
}) {
  final fitting = narrow
      ? [
          for (final item in items)
            if (!wideOnlyModules.contains(item.kind)) item,
        ]
      : items;
  if (!systemStatusBar) return fitting;
  final out = <PanelItem>[];
  var tray = false;
  for (final item in fitting) {
    final standsForTray =
        item.kind == PanelModule.tray || PanelItem.trayExpansion.contains(item);
    if (standsForTray) {
      if (!tray) out.add(const PanelItem(PanelModule.tray));
      tray = true;
      continue;
    }
    if (statusModules.contains(item.kind)) continue;
    out.add(item);
  }
  return out;
}

Widget panelModuleWidget(WidgetRef ref, PanelItem item, PanelHost host) {
  final theme = host.theme;

  return switch (item.kind) {
    // ─── THE TAPPABLE READOUTS ─────────────────────────────────────────────
    //
    // A status-bar icon cannot be tapped from the launcher. These open the
    // figure, the state, and a route into the settings screen for it, which is
    // the whole argument for repeating something Android already shows.
    PanelModule.battery => const PanelBatteryModule(),
    PanelModule.wifi => const PanelNetworkModule(),
    PanelModule.volume => const PanelVolumeModule(),

    // The package is why the caller walks items rather than kinds. A null one
    // cannot happen: `PanelItem.parse` drops `app:` with nothing after it.
    PanelModule.app => PanelAppButton(
        theme: theme,
        package: item.package ?? '',
      ),
    PanelModule.kickoff => PanelKickoffButton(
        theme: theme,
        onTap: () => openApps(ref),
      ),

    // BARE, no Expanded. `PanelBar` applies the flex, because an Expanded must
    // be a direct child of that Flex and this function is called from inside a
    // collection literal.
    PanelModule.tasks => PanelTaskStrip(
        theme: theme,
        vertical: host.vertical,
      ),
    PanelModule.pager => PanelPager(theme: theme),
    PanelModule.title =>
      PanelTitleModule(theme: theme, vertical: host.vertical),
    // Words do not fit a 40dp vertical strip; the toggle is a glyph and does.
    PanelModule.workspacesButton => host.vertical
        ? const SizedBox.shrink()
        : PanelWorkspacesButton(theme: theme),
    PanelModule.appsButton =>
      host.vertical ? const SizedBox.shrink() : PanelAppsButton(theme: theme),
    PanelModule.tiling => PanelTilingToggle(theme: theme),

    // ─── ONLY A TOP PANEL STILL HAS ONE ────────────────────────────────────
    //
    // `PanelItem.parseAll` replaces `tray` with wifi, volume and battery on
    // every other edge, so a bottom panel never reaches this arm.
    PanelModule.tray => PanelTrayButton(
        palette: theme.palette,
        stacked: host.vertical,
        // One button while Android's bar is up, on every edge: the three
        // glyphs are the status row, and the status row is Android's until the
        // user hands it to the panel. See [panelItemsShown].
        compact: theme.statusBar,
      ),
    PanelModule.clock => PanelClockModule(
        onDark: theme.palette.onDark,
        narrow: host.vertical,
      ),
    PanelModule.spacer => const Spacer(),

    // ─── ONE WIDGET, ONE SUBSCRIPTION, DRAWN AT THE FIRST OF THE THREE ─────
    //
    // Lifted out of `gnome_top_bar`, where it was the reason every other panel
    // in the app answered these three with nothing. The run is read off the
    // host so the theme keeps deciding where in the panel they appear.
    PanelModule.network ||
    PanelModule.memory ||
    PanelModule.storage =>
      item.kind == host.statRun.first
          ? PanelReadouts(
              palette: theme.palette,
              fontFamily: theme.typography.display,
              stacked: host.vertical,
              show: host.statRun,
            )
          : const SizedBox.shrink(),

    // ─── THE ONE MODULE STILL OWNED BY A SHELL ─────────────────────────────
    //
    // Activities is GNOME's word and GNOME's widget: an icon and the LABEL
    // "Activities", which is the single most recognisable thing about that
    // shell. It draws in `gnome_top_bar` and nowhere else, and a Breeze panel
    // authoring it gets nothing rather than a GNOME tell on a KDE desktop.
    PanelModule.activities => const SizedBox.shrink(),
  };
}
