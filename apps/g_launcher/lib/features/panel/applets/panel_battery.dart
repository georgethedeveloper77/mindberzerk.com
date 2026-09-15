/// Charge, as a panel chip that opens the level and the settings screen.
///
/// ─── THE TAP IS THE JUSTIFICATION ──────────────────────────────────────────
///
/// `gnome_top_bar` argues a launcher bar should not repeat what Android's
/// status bar already shows, and that argument stands for a GNOME bar sitting
/// directly under it. A Plasma panel is at the BOTTOM of the screen, and more
/// to the point a status-bar icon cannot be tapped from the launcher. This one
/// opens the figure, the state, and a route into the real settings screen.
///
/// ─── AND WHY IT LEFT plasma_shell ──────────────────────────────────────────
///
/// It was private to that file while `tray` was the module Mint authored, so
/// the shell that had the working battery readout was not the shell Mint used.
/// Now that `PanelItem.parseAll` puts this module on every bottom panel in the
/// app, the widget that draws it cannot live inside one shell.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g_launcher/i18n/i18n.dart';

import '../../../design/components/components.dart';
import '../../../engine/effective_theme.dart';
import '../../../system/system_stats.dart';
import '../../settings/device_pages.dart';
import 'panel_applet_menu.dart';

void showBatteryMenu(BuildContext context, WidgetRef ref) {
  final stats = ref.read(systemStatsProvider).value;
  final pct = stats?.batteryPercent;
  final charging = stats?.batteryCharging ?? false;
  final temp = stats?.batteryTempC;
  final ma = stats?.batteryCurrentMa;

  showAppletMenu(
    context: context,
    title: context.t('shell.moduleBattery'),
    rows: (menu) => [
      ThemedListRow(
        icon:
            charging ? Icons.battery_charging_full : Icons.battery_std_outlined,
        title: pct == null ? menu.t('common.unknown') : '$pct%',
        subtitle: menu.t(charging ? 'shell.charging' : 'shell.discharging'),
      ),
      // Shown only where the device reports them. `StatCapabilities` exists
      // because several OEMs serve neither, and a row reading "null" is worse
      // than a row that is not there.
      if (temp != null)
        ThemedListRow(
          icon: Icons.thermostat,
          title: '${temp.toStringAsFixed(1)} °C',
          subtitle: menu.t('shell.temperature'),
        ),
      if (ma != null)
        ThemedListRow(
          icon: Icons.bolt_outlined,
          title: '$ma mA',
          // MAGNITUDE ONLY. The platform's sign is not portable, which
          // `SystemStats.batteryCurrentMa` documents at length, so the
          // direction comes from the charging flag above and not from here.
          subtitle: menu.t('shell.current'),
        ),
      // Into the app's Power page, which carries the charge ring, the
      // temperature series and its own link on to Android. The panel used to
      // jump the queue straight to Android and skip all of it.
      devicePageRow(
        menuContext: menu,
        host: context,
        title: menu.t('settings.power'),
        page: const PowerPage(),
      ),
    ],
  );
}

class PanelBatteryModule extends ConsumerWidget {
  const PanelBatteryModule({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(effectiveThemeProvider).value;
    final stats = ref.watch(systemStatsProvider).value;
    final pct = stats?.batteryPercent;
    if (theme == null || pct == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => showBatteryMenu(context, ref),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              // Charging is the one state worth a different glyph: it changes
              // what a low number MEANS, and a user glancing at 12% wants to
              // know whether it is falling.
              (stats?.batteryCharging ?? false)
                  ? Icons.battery_charging_full
                  : Icons.battery_std_outlined,
              size: 13,
              color: theme.palette.onDark,
            ),
            const SizedBox(width: 3),
            Text(
              '$pct%',
              style: TextStyle(fontSize: 11, color: theme.palette.onDark),
            ),
          ],
        ),
      ),
    );
  }
}
