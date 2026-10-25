import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../../../../i18n/strings.g.dart';
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
final knownPorts = [
  KnownPort(21, 'FTP', PortRisk.risky, note: t.ports.ftpNote),
  KnownPort(22, 'SSH', PortRisk.review, note: t.ports.sshNote),
  KnownPort(23, 'Telnet', PortRisk.risky, note: t.ports.telnetNote),
  const KnownPort(25, 'SMTP', PortRisk.review),
  KnownPort(53, 'DNS', PortRisk.normal, note: t.ports.dnsNote),
  KnownPort(80, t.ports.web, PortRisk.normal, note: t.ports.webNote),
  const KnownPort(139, 'NetBIOS', PortRisk.review),
  KnownPort(443, t.ports.webTls, PortRisk.normal),
  KnownPort(445, t.ports.smb, PortRisk.risky, note: t.ports.smbNote),
  KnownPort(554, t.ports.rtsp, PortRisk.review, note: t.ports.rtspNote),
  KnownPort(1900, 'UPnP', PortRisk.review, note: t.ports.upnpNote),
  KnownPort(3389, t.ports.rdp, PortRisk.risky, note: t.ports.rdpNote),
  const KnownPort(5000, 'UPnP / NAS', PortRisk.review),
  KnownPort(5900, 'VNC', PortRisk.risky, note: t.ports.vncNote),
  KnownPort(7547, 'TR-069', PortRisk.review, note: t.ports.tr069Note),
  KnownPort(8080, t.ports.webAlt, PortRisk.review),
  KnownPort(8443, t.ports.webAltTls, PortRisk.review),
  KnownPort(8888, t.ports.webAlt, PortRisk.review),
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
      title: t.ports.title,
      info: t.ports.info(n: knownPorts.length),
      action: FilledButton(
        onPressed: scan.running ? null : () => ref.read(portScanProvider.notifier).scan(_host.text.trim()),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        child: Text(scan.running ? t.ports.checking(n: knownPorts.length) : t.ports.check),
      ),
      children: [
        TextField(
          controller: _host,
          keyboardType: TextInputType.url,
          style: m.monoStyle(size: 15),
          decoration: InputDecoration(
            labelText: t.ports.address,
            helperText: gateway == null ? null : t.ports.yourRouter(ip: gateway),
            filled: true,
            fillColor: m.surface2,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(Meridian.rChip), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 16),
        if (scan.running) const LinearProgressIndicator(minHeight: 2),
        if (scan.done && scan.open.isEmpty)
          ToolCard(
            child: Text(t.ports.noneOpen(host: scan.host ?? ''), style: TextStyle(fontSize: 15, color: m.text)),
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
      PortRisk.risky => (t.ports.risky, m.bad),
      PortRisk.review => (t.ports.review, m.warn),
      PortRisk.normal => (t.ports.normal, m.good),
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
