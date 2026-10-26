import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g_network/g_network.dart';

import '../analytics/events.dart';
import '../blocked/blocked_screen.dart';
import '../breaches/breaches_screen.dart';
import '../checks/checks_screen.dart';
import '../design/meridian.dart';
import '../design/meridian_widgets.dart';
import '../i18n/strings.g.dart';
import 'devices_screen.dart';
import 'network_screen.dart' show liveSnapshotProvider;
import 'ping_screen.dart';
import 'ports_screen.dart';
import 'router_screen.dart';
import 'speed_screen.dart';
import 'status_screen.dart';
import 'tool_settings.dart';
import 'trace_screen.dart';
import 'wifi_screen.dart';
import 'wol_screen.dart';

/// One tool in the index.
typedef _Tool = ({IconData icon, Color color, String title, String sub, String event, Widget Function() screen});

/// The tools index: the current network on top, then the tools in groups,
/// each with a solid colour of its own and one short line.
class ToolsScreen extends ConsumerWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.mer;

    // Named explicitly: class names are not stable across release builds.
    void open(String event, Widget Function() screen) {
      Events.tool(event);
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen()));
    }

    final groups = <(String, List<_Tool>)>[
      (t.tools.internet, [
        (icon: Icons.speed_rounded, color: m.brand, title: t.tools.speed, sub: t.tools.speedDesc, event: 'speed', screen: () => const SpeedScreen()),
        (icon: Icons.show_chart_rounded, color: m.teal, title: t.tools.ping, sub: t.tools.pingDesc, event: 'ping', screen: () => const PingScreen()),
        (icon: Icons.fact_check_outlined, color: m.violet, title: t.tools.status, sub: t.tools.statusDesc, event: 'status', screen: () => const StatusScreen()),
        (icon: Icons.block_rounded, color: blockedTone, title: t.tools.blocked, sub: t.tools.blockedDesc, event: 'blocked', screen: () => const BlockedScreen()),
        (icon: Icons.route_rounded, color: m.pink, title: t.tools.trace, sub: t.tools.traceDesc, event: 'traceroute', screen: () => const TraceScreen()),
      ]),
      (t.tools.security, [
        (icon: Icons.devices_other_rounded, color: m.good, title: t.tools.devices, sub: t.tools.devicesDesc, event: 'devices', screen: () => const DevicesScreen()),
        (icon: Icons.router_outlined, color: m.warn, title: t.tools.router, sub: t.tools.routerDesc, event: 'router', screen: () => const RouterScreen()),
        (icon: Icons.lock_outline_rounded, color: m.bad, title: t.tools.ports, sub: t.tools.portsDesc, event: 'ports', screen: () => const PortsScreen()),
      ]),
      (t.checks.title, [
        (icon: Icons.password_rounded, color: m.pink, title: t.tools.passwordCheck, sub: t.tools.passwordCheckDesc, event: 'password_check', screen: () => const ChecksScreen()),
        (icon: Icons.link_rounded, color: m.bad, title: t.tools.linkCheck, sub: t.tools.linkCheckDesc, event: 'link_check', screen: () => const ChecksScreen(initial: CheckKind.link)),
        (icon: Icons.key_rounded, color: m.violet, title: t.tools.breaches, sub: t.tools.breachesDesc, event: 'breaches', screen: () => const BreachesScreen()),
      ]),
      (t.tools.utilities, [
        (icon: Icons.wifi_find_rounded, color: m.brand, title: t.tools.wifiScanner, sub: t.tools.wifiDesc, event: 'wifi', screen: () => const WifiScreen()),
        (icon: Icons.power_settings_new_rounded, color: m.teal, title: t.tools.wol, sub: t.tools.wolDesc, event: 'wake_on_lan', screen: () => const WolScreen()),
      ]),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(t.tools.title),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: t.toolSettings.title,
            onPressed: () => ToolSettingsScreen.open(context),
            icon: Icon(Icons.settings_outlined, color: m.text),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          _NetworkCard(onTap: () => open('network_hub', () => const DevicesScreen())),
          for (final (title, tools) in groups) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 22, 4, 8),
              child: Text(
                title.toUpperCase(),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: .8, color: m.muted),
              ),
            ),
            MerCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final (i, tool) in tools.indexed) ...[
                    if (i > 0) Divider(height: 1, indent: 68, color: m.line),
                    _ToolTile(tool: tool, onTap: () => open(tool.event, tool.screen)),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The network the phone is on: name, security, band, devices, verdict.
class _NetworkCard extends ConsumerWidget {
  const _NetworkCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.mer;
    final snap = ref.watch(liveSnapshotProvider).value;
    final scan = ref.watch(deviceScanProvider);

    final wifi = snap?.transport == Transport.wifi;
    final (security, tone) = switch (snap?.wifiSecurity) {
      _ when !wifi => (
          null,
          snap?.transport == Transport.cellular || snap?.transport == Transport.ethernet ? m.good : m.muted,
        ),
      WifiSecurity.open => (t.scan.open, m.bad),
      WifiSecurity.wep => (t.scan.wep, m.bad),
      WifiSecurity.owe => (t.scan.owe, m.warn),
      WifiSecurity.wpa2 => ('WPA2', m.good),
      WifiSecurity.wpa3 => ('WPA3', m.good),
      WifiSecurity.enterprise => (t.scan.enterprise, m.good),
      _ => (t.scan.unknown, m.warn),
    };
    final name = switch (snap?.transport) {
      Transport.wifi => snap?.ssid ?? t.tools.wifi,
      Transport.cellular => snap?.carrierName ?? t.tools.mobile,
      Transport.ethernet => t.tools.ethernet,
      null => t.tools.checking,
      _ => t.tools.offline,
    };
    final mhz = snap?.frequencyMhz;
    final band = !wifi || mhz == null
        ? null
        : mhz >= 5925
            ? '6 GHz'
            : mhz >= 4900
                ? '5 GHz'
                : '2.4 GHz';
    final devices = scan.finished ? scan.devices.length : null;
    final facts = [
      if (security != null) security,
      if (band != null) band,
      if (devices != null) t.toolSettings.devices(n: devices),
    ];
    final verdict = tone == m.good ? t.toolSettings.safe : tone == m.bad ? t.toolSettings.unsafe : null;

    return MerCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: tone.withValues(alpha: .16), borderRadius: BorderRadius.circular(14)),
                child: Icon(
                  snap?.transport == Transport.cellular ? Icons.signal_cellular_alt_rounded : Icons.wifi_rounded,
                  color: tone,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: m.text)),
                    if (facts.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(facts.join(' · '), style: TextStyle(fontSize: 13, color: m.muted)),
                    ],
                  ],
                ),
              ),
              if (verdict != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: tone.withValues(alpha: .14), borderRadius: BorderRadius.circular(999)),
                  child: Text(verdict, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: tone)),
                ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: m.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// One tool: a solid colour square, the name, one short line.
class _ToolTile extends StatelessWidget {
  const _ToolTile({required this.tool, required this.onTap});

  final _Tool tool;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 11, 8, 11),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: tool.color, borderRadius: BorderRadius.circular(13)),
              child: Icon(tool.icon, color: m.bg, size: 21),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tool.title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: m.text)),
                  const SizedBox(height: 1),
                  Text(tool.sub, style: TextStyle(fontSize: 12, color: m.muted)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: m.muted),
          ],
        ),
      ),
    );
  }
}
