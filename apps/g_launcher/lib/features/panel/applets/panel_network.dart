/// The network transport, as a panel chip.
///
/// ─── TRANSPORT, NEVER THE NAME ─────────────────────────────────────────────
///
/// `system_stats.dart` says it outright: reading the SSID needs a location
/// permission. A launcher asking for location to put a network name on a panel
/// is a trade nobody would take, so this shows WHAT KIND of connection there is
/// and leaves the name to the settings screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g_launcher/i18n/i18n.dart';

import '../../../design/components/components.dart';
import '../../../engine/effective_theme.dart';
import '../../../system/system_stats.dart';
import '../../settings/device_pages.dart';
import 'panel_applet_menu.dart';

/// One switch, read twice: the chip and the popover must not disagree about
/// what the phone is connected to, and two copies of this drift the first time
/// a transport is added.
IconData transportGlyph(String? transport) => switch (transport) {
      'wifi' => Icons.wifi,
      'cellular' => Icons.signal_cellular_alt,
      'ethernet' => Icons.settings_ethernet,
      // Null is NOT SAMPLED YET and 'none' is offline. Drawn the same, because
      // a panel that flickers between two icons on every poll is worse than one
      // that is briefly wrong about a phone with no connection.
      _ => Icons.wifi_off,
    };

String transportKey(String? transport) => switch (transport) {
      'wifi' => 'shell.onWifi',
      'cellular' => 'shell.onMobileData',
      'ethernet' => 'shell.onEthernet',
      _ => 'shell.noConnection',
    };

void showNetworkMenu(BuildContext context, WidgetRef ref) {
  final transport = ref.read(systemStatsProvider).value?.transport;

  showAppletMenu(
    context: context,
    title: context.t('shell.moduleWifi'),
    rows: (menu) => [
      ThemedListRow(
        icon: transportGlyph(transport),
        title: menu.t(transportKey(transport)),
      ),
      // The missing SSID is explained on the Network page, under the chart that
      // gives the explanation somewhere to sit. A 224dp popover repeating it
      // was three lines of apology above a one-line readout.
      devicePageRow(
        menuContext: menu,
        host: context,
        title: menu.t('settings.network'),
        page: const NetworkPage(),
      ),
    ],
  );
}

class PanelNetworkModule extends ConsumerWidget {
  const PanelNetworkModule({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(effectiveThemeProvider).value;
    if (theme == null) return const SizedBox.shrink();

    final transport = ref.watch(systemStatsProvider).value?.transport;
    return GestureDetector(
      onTap: () => showNetworkMenu(context, ref),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7),
        child: Icon(
          transportGlyph(transport),
          size: 13,
          color: theme.palette.onDark,
        ),
      ),
    );
  }
}
