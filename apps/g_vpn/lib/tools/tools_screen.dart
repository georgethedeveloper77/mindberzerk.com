import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g_network/g_network.dart';

import '../design/meridian.dart';
import 'devices_screen.dart';
import 'network_screen.dart';
import 'ping_screen.dart';
import 'ports_screen.dart';
import 'router_screen.dart';
import 'speed_screen.dart';
import 'status_screen.dart';
import 'trace_screen.dart';
import 'tool_widgets.dart';
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
      Transport.wifi => snap?.ssid ?? 'Wi-Fi',
      Transport.cellular => snap?.carrierName ?? 'Mobile data',
      Transport.ethernet => 'Ethernet',
      null => 'Checking',
      _ => 'Offline',
    };
    void open(Widget screen) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
    const utility = Color(0xFF6B7280);

    return Scaffold(
      appBar: AppBar(title: const Text('Tools'), centerTitle: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
        children: [
          ToolRow(
            icon: Icons.wifi_rounded,
            color: m.brand,
            title: networkName,
            description: 'Safety check, what sites see, signal, router and DNS.',
            onTap: () => open(const NetworkScreen()),
          ),
          const ToolSection('Internet connectivity'),
          ToolRow(
            icon: Icons.speed_rounded,
            color: m.brand,
            title: 'Speed test',
            description: 'Download and upload speed, and the video quality it supports.',
            onTap: () => open(const SpeedScreen()),
          ),
          ToolRow(
            icon: Icons.show_chart_rounded,
            color: m.brand,
            title: 'Ping',
            description: 'Live response time and jitter to any server or your router.',
            onTap: () => open(const PingScreen()),
          ),
          ToolRow(
            icon: Icons.fact_check_outlined,
            color: m.brand,
            title: 'Service status',
            description: 'Is WhatsApp, YouTube or Google reachable from here, or blocked?',
            onTap: () => open(const StatusScreen()),
          ),
          ToolRow(
            icon: Icons.route_rounded,
            color: m.brand,
            title: 'Traceroute',
            description: 'Every router between you and a site, and how long each takes.',
            onTap: () => open(const TraceScreen()),
          ),
          const ToolSection('Network security'),
          ToolRow(
            icon: Icons.devices_other_rounded,
            color: m.good,
            title: 'Devices on this network',
            description: 'Who else is on your Wi-Fi: phones, TVs, cameras and computers.',
            onTap: () => open(const DevicesScreen()),
          ),
          ToolRow(
            icon: Icons.router_outlined,
            color: m.good,
            title: 'Router check',
            description: 'Whether devices can open ports on your router by themselves (UPnP).',
            onTap: () => open(const RouterScreen()),
          ),
          ToolRow(
            icon: Icons.lock_outline_rounded,
            color: m.good,
            title: 'Open ports',
            description: 'Check your router or a server for risky open ports.',
            onTap: () => open(const PortsScreen()),
          ),
          const ToolSection('Utilities'),
          ToolRow(
            icon: Icons.wifi_find_rounded,
            color: utility,
            title: 'Wi-Fi scanner',
            description: 'Nearby networks, their security, and the least crowded channel.',
            onTap: () => open(const WifiScreen()),
          ),
          ToolRow(
            icon: Icons.power_settings_new_rounded,
            color: utility,
            title: 'Wake on LAN',
            description: 'Turn on a computer or NAS on this network.',
            onTap: () => open(const WolScreen()),
          ),
        ],
      ),
    );
  }
}
