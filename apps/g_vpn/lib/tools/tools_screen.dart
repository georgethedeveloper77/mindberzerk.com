import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g_network/g_network.dart';

import '../../../../../../../../i18n/strings.g.dart';
import '../design/meridian.dart';
import 'devices_screen.dart';
import 'network_screen.dart';
import 'ping_screen.dart';
import 'ports_screen.dart';
import 'router_screen.dart';
import 'speed_screen.dart';
import 'status_screen.dart';
import 'tool_widgets.dart';
import 'trace_screen.dart';
import 'wifi_screen.dart';
import 'wol_screen.dart';

/// The tools index: sections of plain rows, each opening its own screen.
/// Colour carries meaning only: blue for connectivity, green for security,
/// grey for utilities.
class ToolsScreen extends ConsumerWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.mer;
    final snap = ref.watch(liveSnapshotProvider).value;
    final networkName = switch (snap?.transport) {
      Transport.wifi => snap?.ssid ?? t.tools.wifi,
      Transport.cellular => snap?.carrierName ?? t.tools.mobile,
      Transport.ethernet => t.tools.ethernet,
      null => t.tools.checking,
      _ => t.tools.offline,
    };
    void open(Widget screen) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
    const utility = Color(0xFF6B7280);

    return Scaffold(
      appBar: AppBar(title: Text(t.tools.title), centerTitle: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
        children: [
          ToolRow(
            icon: Icons.wifi_rounded,
            color: m.brand,
            title: networkName,
            description: t.tools.networkDesc,
            onTap: () => open(const NetworkScreen()),
          ),
          ToolSection(t.tools.internet),
          ToolRow(
            icon: Icons.speed_rounded,
            color: m.brand,
            title: t.tools.speed,
            description: t.tools.speedDesc,
            onTap: () => open(const SpeedScreen()),
          ),
          ToolRow(
            icon: Icons.show_chart_rounded,
            color: m.brand,
            title: t.tools.ping,
            description: t.tools.pingDesc,
            onTap: () => open(const PingScreen()),
          ),
          ToolRow(
            icon: Icons.fact_check_outlined,
            color: m.brand,
            title: t.tools.status,
            description: t.tools.statusDesc,
            onTap: () => open(const StatusScreen()),
          ),
          ToolRow(
            icon: Icons.route_rounded,
            color: m.brand,
            title: t.tools.trace,
            description: t.tools.traceDesc,
            onTap: () => open(const TraceScreen()),
          ),
          ToolSection(t.tools.security),
          ToolRow(
            icon: Icons.devices_other_rounded,
            color: m.good,
            title: t.tools.devices,
            description: t.tools.devicesDesc,
            onTap: () => open(const DevicesScreen()),
          ),
          ToolRow(
            icon: Icons.router_outlined,
            color: m.good,
            title: t.tools.router,
            description: t.tools.routerDesc,
            onTap: () => open(const RouterScreen()),
          ),
          ToolRow(
            icon: Icons.lock_outline_rounded,
            color: m.good,
            title: t.tools.ports,
            description: t.tools.portsDesc,
            onTap: () => open(const PortsScreen()),
          ),
          ToolSection(t.tools.utilities),
          ToolRow(
            icon: Icons.wifi_find_rounded,
            color: utility,
            title: t.tools.wifiScanner,
            description: t.tools.wifiDesc,
            onTap: () => open(const WifiScreen()),
          ),
          ToolRow(
            icon: Icons.power_settings_new_rounded,
            color: utility,
            title: t.tools.wol,
            description: t.tools.wolDesc,
            onTap: () => open(const WolScreen()),
          ),
        ],
      ),
    );
  }
}
