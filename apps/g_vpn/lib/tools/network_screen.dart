import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g_network/g_network.dart';

import '../design/meridian.dart';
import '../design/meridian_widgets.dart';
import '../design/wifi_name_prompt.dart';
import '../home/home_scan.dart';
import '../vpn/vpn_controller.dart';
import 'tool_widgets.dart';
import 'tools_providers.dart';

/// Re-reads the network on every change, so this screen never describes
/// the network you just left.
final liveSnapshotProvider = FutureProvider.autoDispose<NetworkSnapshot>((ref) {
  ref.watch(networkChangesProvider);
  ref.watch(vpnProvider.select((s) => s.phase));
  return ref.watch(networkProbeProvider).snapshot();
});

/// Everything about the current network: safety verdict, public identity,
/// signal, gateway and DNS.
class NetworkScreen extends StatelessWidget {
  const NetworkScreen({super.key});

  @override
  Widget build(BuildContext context) => const ToolPage(title: 'This network', children: [_NetworkCard()]);
}

class _NetworkCard extends ConsumerWidget {
  const _NetworkCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.mer;
    final snap = ref.watch(liveSnapshotProvider);
    final id = ref.watch(identityProvider);

    return MerCard(
      child: switch (snap) {
        AsyncData(:final value) => _networkBody(context, ref, m, value, id),
        AsyncError(:final error) => Text('Could not read the network: $error', style: TextStyle(color: m.bad)),
        _ => const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator(minHeight: 2)),
      },
    );
  }

  Widget _networkBody(BuildContext context, WidgetRef ref, Meridian m, NetworkSnapshot s, AsyncValue<PublicIdentity> id) {
    final wifi = s.transport == Transport.wifi;
    final name = switch (s.transport) {
      Transport.wifi => s.ssid ?? 'Wi-Fi',
      Transport.cellular => s.carrierName ?? 'Mobile data',
      Transport.ethernet => 'Ethernet',
      _ => 'Offline',
    };
    final verdict = assessWifi(s);
    final (bannerBg, bannerFg, headline) = switch (verdict.level) {
      SafetyLevel.risk => (m.badSoft, m.bad, 'Risky network. Connect the VPN here.'),
      SafetyLevel.caution => (m.warnSoft, m.warn, 'Worth a look before you trust it.'),
      SafetyLevel.safe => (m.surface2, m.good, s.vpnActive ? 'Covered by the VPN.' : 'This network looks safe.'),
      SafetyLevel.notApplicable => (m.surface2, m.text, s.transport == Transport.cellular ? 'Mobile data.' : 'Not connected.'),
    };
    final band = switch (s.frequencyMhz) {
      null => null,
      final f when f >= 5900 => '6 GHz',
      final f when f >= 4900 => '5 GHz',
      _ => '2.4 GHz',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MerCardTitle(
          name,
          trailing: wifi && s.ssid == null ? MerAction('Show name', onPressed: () => askForWifiNames(context, ref)) : null,
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: bannerBg, borderRadius: BorderRadius.circular(Meridian.rChip)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(headline, style: TextStyle(color: bannerFg, fontSize: 14, fontWeight: FontWeight.w800)),
              for (final r in verdict.reasons) ...[
                const SizedBox(height: 4),
                Text(r, style: TextStyle(color: m.muted, fontSize: 12, height: 1.4)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 6),
        switch (id) {
          AsyncData(:final value) => Column(
              children: [
                MerRow('Sites see', value.ip, mono: true, color: s.vpnActive ? m.good : m.bad),
                if (value.org != null) MerRow('Provider', value.org!),
                if (value.city != null || value.country != null)
                  MerRow('Location', [value.city, value.country].whereType<String>().join(', ')),
              ],
            ),
          AsyncError() => MerRow('Sites see', 'Could not check', color: m.warn),
          _ => const MerRow('Sites see', 'Checking'),
        },
        if (s.rssi != null) MerRow('Signal', '${s.rssi} dBm${band == null ? '' : ' · $band'}'),
        if (s.linkSpeedMbps != null) MerRow('Link speed', '${s.linkSpeedMbps} Mbps'),
        MerRow('Gateway', s.gateway ?? 'None', mono: true),
        MerRow('DNS', s.dnsServers.isEmpty ? 'None' : s.dnsServers.join('\n'), mono: true),
        MerRow(
          'Private DNS',
          s.privateDnsActive ? (s.privateDnsServer ?? 'Automatic') : 'Off',
          color: s.privateDnsActive ? m.good : m.text,
        ),
        MerRow('Metered', s.metered ? 'Yes' : 'No'),
      ],
    );
  }
}
