import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/meridian.dart';
import '../design/wifi_name_prompt.dart';
import '../vpn/vpn_api.g.dart';
import '../vpn/vpn_controller.dart';
import 'network_screen.dart';
import 'tool_widgets.dart';

final wifiScanProvider = FutureProvider.autoDispose<List<WifiAccessPoint>>(
  (ref) => ref.read(vpnApiProvider).scanWifi(),
);

final _wifiAllowedProvider = FutureProvider.autoDispose<bool>((ref) => ref.read(vpnApiProvider).wifiNamesAllowed());

class WifiScreen extends ConsumerWidget {
  const WifiScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.mer;
    final allowed = ref.watch(_wifiAllowedProvider).value;
    final current = ref.watch(liveSnapshotProvider).value?.ssid;

    if (allowed == null) return const ToolPage(title: 'Wi-Fi scanner', children: []);
    if (!allowed) {
      return ToolPage(
        title: 'Wi-Fi scanner',
        action: FilledButton(
          onPressed: () async {
            await askForWifiNames(context, ref);
            ref.invalidate(_wifiAllowedProvider);
            ref.invalidate(wifiScanProvider);
          },
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: const Text('Allow Wi-Fi scanning'),
        ),
        info: 'Android only shows nearby Wi-Fi networks to apps with location permission. '
            'G VPN uses it to list networks on this phone and nothing else.',
        children: [
          Text('Needs location permission.', style: TextStyle(fontSize: 14, color: m.muted)),
        ],
      );
    }

    final scan = ref.watch(wifiScanProvider);
    return ToolPage(
      title: 'Wi-Fi scanner',
      info: 'Lists networks from the phone\'s last scan. Android allows only a few scans a minute, so a quick re-scan '
          'may show the same list. The suggested channel is the least crowded of 1, 6 and 11, the three that do not overlap.',
      action: FilledButton(
        onPressed: scan.isLoading ? null : () => ref.invalidate(wifiScanProvider),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        child: Text(scan.isLoading ? 'Scanning' : 'Scan again'),
      ),
      children: [
        switch (scan) {
          AsyncData(:final value) => _Results(networks: value, current: current),
          AsyncError(:final error) => Text(
              error is PlatformException ? (error.message ?? 'Scan failed') : '$error',
              style: TextStyle(color: m.bad),
            ),
          _ => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
        },
      ],
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({required this.networks, required this.current});

  final List<WifiAccessPoint> networks;
  final String? current;

  /// Least crowded of the three 2.4 GHz channels that do not overlap,
  /// weighting strong neighbours more than faint ones.
  static int? bestChannel(List<WifiAccessPoint> nets) {
    final load = {1: 0.0, 6: 0.0, 11: 0.0};
    final twoFour = nets.where((n) => n.frequencyMhz < 3000).toList();
    if (twoFour.isEmpty) return null;
    for (final n in twoFour) {
      final weight = ((n.level + 100) / 50).clamp(0.1, 1.5);
      for (final c in load.keys) {
        // Channels within four of each other overlap.
        if ((n.channel - c).abs() < 5) load[c] = load[c]! + weight;
      }
    }
    return load.entries.reduce((a, b) => a.value <= b.value ? a : b).key;
  }

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    if (networks.isEmpty) {
      return Text('No networks found. Location services may be off.', style: TextStyle(color: m.muted));
    }
    final best = bestChannel(networks);
    final open = networks.where((n) => n.security == 'Open' || n.security == 'WEP').length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${networks.length} networks nearby', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: m.text)),
        Text(
          [
            if (best != null) 'Least crowded 2.4 GHz channel: $best',
            if (open > 0) '$open open or weak',
          ].join(' · '),
          style: TextStyle(fontSize: 13, color: m.muted),
        ),
        const SizedBox(height: 12),
        ToolCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Column(
            children: [
              for (final (i, n) in networks.indexed) ...[
                if (i > 0) Divider(height: 1, color: m.line),
                _NetworkRow(net: n, isCurrent: current != null && n.ssid == current),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _NetworkRow extends StatelessWidget {
  const _NetworkRow({required this.net, required this.isCurrent});

  final WifiAccessPoint net;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final weak = net.security == 'Open' || net.security == 'WEP';
    final band = net.frequencyMhz >= 5925
        ? '6 GHz'
        : net.frequencyMhz >= 4900
            ? '5 GHz'
            : '2.4 GHz';
    final bars = net.level >= -55 ? 4 : net.level >= -67 ? 3 : net.level >= -78 ? 2 : 1;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          _Bars(bars: bars, color: isCurrent ? m.brand : m.text, dim: m.line),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  net.ssid.isEmpty ? 'Hidden network' : net.ssid,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: net.ssid.isEmpty ? m.muted : m.text),
                ),
                Text(
                  '${isCurrent ? 'Connected · ' : ''}$band · ch ${net.channel} · ${net.widthMhz} MHz · ${net.level} dBm',
                  style: m.monoStyle(size: 11, color: isCurrent ? m.brand : m.muted),
                ),
              ],
            ),
          ),
          Text(net.security, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: weak ? m.bad : m.muted)),
        ],
      ),
    );
  }
}

class _Bars extends StatelessWidget {
  const _Bars({required this.bars, required this.color, required this.dim});

  final int bars;
  final Color color;
  final Color dim;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 22,
        height: 18,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < 4; i++)
              Container(
                width: 4,
                height: 5.0 + i * 4,
                decoration: BoxDecoration(color: i < bars ? color : dim, borderRadius: BorderRadius.circular(1)),
              ),
          ],
        ),
      );
}
