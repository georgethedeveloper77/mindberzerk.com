import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/meridian.dart';
import 'network_screen.dart';
import 'probe.dart';
import 'tool_widgets.dart';

/// A port worth checking, and what an open one means for a home user.
class KnownPort {
  const KnownPort(this.port, this.service, this.risk, {this.note});

  final int port;
  final String service;
  final PortRisk risk;
  final String? note;
}

enum PortRisk { normal, review, risky }

/// The ports that matter on home routers and devices, not a full scan:
/// fast, and every result comes with a plain explanation.
const knownPorts = [
  KnownPort(21, 'FTP', PortRisk.risky, note: 'Sends passwords unencrypted.'),
  KnownPort(22, 'SSH', PortRisk.review, note: 'Remote login. Fine if you set it up.'),
  KnownPort(23, 'Telnet', PortRisk.risky, note: 'Unencrypted remote login; a favourite of botnets.'),
  KnownPort(25, 'SMTP', PortRisk.review),
  KnownPort(53, 'DNS', PortRisk.normal, note: 'Normal on a router.'),
  KnownPort(80, 'Web (HTTP)', PortRisk.normal, note: 'Usually the router admin page.'),
  KnownPort(139, 'NetBIOS', PortRisk.review),
  KnownPort(443, 'Web (HTTPS)', PortRisk.normal),
  KnownPort(445, 'Windows file sharing', PortRisk.risky, note: 'Should never face the internet.'),
  KnownPort(554, 'RTSP camera stream', PortRisk.review, note: 'A camera may be streaming here.'),
  KnownPort(1900, 'UPnP', PortRisk.review, note: 'Lets devices open router ports on their own.'),
  KnownPort(3389, 'Remote Desktop', PortRisk.risky, note: 'A common break-in route.'),
  KnownPort(5000, 'UPnP / NAS', PortRisk.review),
  KnownPort(5900, 'VNC', PortRisk.risky, note: 'Screen sharing, often without a password.'),
  KnownPort(7547, 'TR-069', PortRisk.review, note: 'ISP remote management.'),
  KnownPort(8080, 'Web (alt)', PortRisk.review),
  KnownPort(8443, 'Web (alt HTTPS)', PortRisk.review),
  KnownPort(8888, 'Web (alt)', PortRisk.review),
];

class PortScanState {
  const PortScanState({this.host, this.open = const [], this.running = false, this.done = false});

  final String? host;
  final List<KnownPort> open;
  final bool running;
  final bool done;
}

final portScanProvider = NotifierProvider.autoDispose<PortScanController, PortScanState>(PortScanController.new);

class PortScanController extends Notifier<PortScanState> {
  @override
  PortScanState build() => const PortScanState();

  Future<void> scan(String host) async {
    if (state.running || host.isEmpty) return;
    state = PortScanState(host: host, running: true);
    final open = await pooled(knownPorts, 8, (p) async => await isOpen(host, p.port) ? p : null);
    if (!ref.mounted) return;
    state = PortScanState(host: host, open: open.whereType<KnownPort>().toList(), done: true);
  }
}

class PortsScreen extends ConsumerStatefulWidget {
  const PortsScreen({super.key});

  @override
  ConsumerState<PortsScreen> createState() => _PortsScreenState();
}

class _PortsScreenState extends ConsumerState<PortsScreen> {
  final _host = TextEditingController();
  bool _prefilled = false;

  @override
  void dispose() {
    _host.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final scan = ref.watch(portScanProvider);
    final gateway = ref.watch(liveSnapshotProvider).value?.gateway;
    if (!_prefilled && gateway != null) {
      // The router is the device people most need checked.
      _host.text = gateway;
      _prefilled = true;
    }

    return ToolPage(
      title: 'Open ports',
      info: 'Checks the ${knownPorts.length} ports that matter on home routers and devices, and explains each open one. '
          'Only check devices and servers you own or manage.',
      action: FilledButton(
        onPressed: scan.running ? null : () => ref.read(portScanProvider.notifier).scan(_host.text.trim()),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        child: Text(scan.running ? 'Checking ${knownPorts.length} ports' : 'Check ports'),
      ),
      children: [
        TextField(
          controller: _host,
          keyboardType: TextInputType.url,
          style: m.monoStyle(size: 15),
          decoration: InputDecoration(
            labelText: 'Device or server address',
            helperText: gateway == null ? null : 'Your router is $gateway',
            filled: true,
            fillColor: m.surface2,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(Meridian.rChip), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 16),
        if (scan.running) const LinearProgressIndicator(minHeight: 2),
        if (scan.done && scan.open.isEmpty)
          ToolCard(
            child: Text('No common ports open on ${scan.host}.', style: TextStyle(fontSize: 15, color: m.text)),
          ),
        if (scan.done && scan.open.isNotEmpty)
          ToolCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Column(
              children: [
                for (final (i, p) in scan.open.indexed) ...[
                  if (i > 0) Divider(height: 1, color: m.line),
                  _PortRow(port: p),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _PortRow extends StatelessWidget {
  const _PortRow({required this.port});

  final KnownPort port;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final (tag, color) = switch (port.risk) {
      PortRisk.risky => ('RISKY', m.bad),
      PortRisk.review => ('REVIEW', m.warn),
      PortRisk.normal => ('NORMAL', m.good),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 56, child: Text('${port.port}', style: m.monoStyle(size: 15, weight: FontWeight.w600))),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(port.service, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: m.text)),
                if (port.note != null) Text(port.note!, style: TextStyle(fontSize: 12, color: m.muted)),
              ],
            ),
          ),
          Text(tag, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}
