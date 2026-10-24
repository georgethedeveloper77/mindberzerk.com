import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/meridian.dart';
import '../vpn/vpn_controller.dart';
import 'probe.dart';
import 'tool_widgets.dart';

/// A service and the host that answers for it.
class Service {
  const Service(this.name, this.host, this.icon);

  final String name;
  final String host;
  final IconData icon;
}

/// Chosen for what people check when "the internet is down" or a service
/// is blocked: messaging first, then the big platforms.
const services = [
  Service('WhatsApp', 'g.whatsapp.net', Icons.chat_rounded),
  Service('Telegram', 'api.telegram.org', Icons.send_rounded),
  Service('Instagram', 'www.instagram.com', Icons.photo_camera_outlined),
  Service('YouTube', 'www.youtube.com', Icons.smart_display_outlined),
  Service('Google', 'www.google.com', Icons.search_rounded),
  Service('Gmail', 'mail.google.com', Icons.mail_outline_rounded),
  Service('X', 'x.com', Icons.alternate_email_rounded),
  Service('TikTok', 'www.tiktok.com', Icons.music_note_rounded),
  Service('Netflix', 'www.netflix.com', Icons.movie_outlined),
  Service('Cloudflare', '1.1.1.1', Icons.cloud_outlined),
];

class ServiceResult {
  const ServiceResult(this.service, this.samples);

  final Service service;
  final List<double?> samples;

  double? get best {
    final ok = samples.whereType<double>();
    return ok.isEmpty ? null : ok.reduce((a, b) => a < b ? a : b);
  }
}

/// Three handshakes per service, all services in parallel. Re-run by
/// invalidating; re-runs on its own when the VPN state changes, so the
/// before/after comparison is one tap away.
final serviceStatusProvider = FutureProvider.autoDispose<List<ServiceResult>>((ref) async {
  ref.watch(vpnProvider.select((s) => s.phase == VpnPhase.on));
  return pooled(services, 5, (s) async {
    final samples = <double?>[];
    for (var i = 0; i < 3; i++) {
      samples.add(await tcpPing(s.host, 443, timeout: const Duration(seconds: 4), refusedCounts: false));
    }
    return ServiceResult(s, samples);
  });
});

class StatusScreen extends ConsumerWidget {
  const StatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.mer;
    final results = ref.watch(serviceStatusProvider);
    final viaVpn = ref.watch(vpnProvider.select((s) => s.phase)) == VpnPhase.on;

    return ToolPage(
      title: 'Service status',
      info: 'Connects to each service three times and shows the fastest answer. If a service is unreachable '
          'without the VPN but works with it, your network or country is blocking it. It checks again '
          'whenever the VPN turns on or off.',
      action: FilledButton(
        onPressed: results.isLoading ? null : () => ref.invalidate(serviceStatusProvider),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        child: Text(results.isLoading ? 'Checking' : 'Check again'),
      ),
      children: [
        Text(viaVpn ? 'Through the VPN' : 'Direct', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: viaVpn ? m.good : m.muted)),
        const SizedBox(height: 8),
        switch (results) {
          AsyncData(:final value) => ToolCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Column(
                children: [
                  for (final (i, r) in value.indexed) ...[
                    if (i > 0) Divider(height: 1, color: m.line),
                    _ServiceRow(result: r),
                  ],
                ],
              ),
            ),
          AsyncError(:final error) => Text('$error', style: TextStyle(color: m.bad)),
          _ => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
        },
      ],
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({required this.result});

  final ServiceResult result;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final best = result.best;
    final (label, color) = switch (best) {
      null => ('Unreachable', m.bad),
      final v when v > 400 => ('${v.round()} ms, slow', m.warn),
      final v => ('${v.round()} ms', m.good),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(result.service.icon, color: m.muted, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Text(result.service.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: m.text)),
          ),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(label, style: m.monoStyle(size: 13, color: color)),
        ],
      ),
    );
  }
}
