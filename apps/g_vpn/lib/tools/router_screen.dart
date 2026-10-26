import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/meridian.dart';
import '../i18n/strings.g.dart';
import '../vpn/vpn_controller.dart';
import 'tool_widgets.dart';
import 'upnp.dart';

final upnpProvider = FutureProvider.autoDispose<UpnpReport>((ref) => checkUpnp());

class RouterScreen extends ConsumerStatefulWidget {
  const RouterScreen({super.key});

  @override
  ConsumerState<RouterScreen> createState() => _RouterScreenState();
}

class _RouterScreenState extends ConsumerState<RouterScreen> {
  bool _started = false;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final vpnOn = ref.watch(vpnProvider.select((s) => s.phase)) == VpnPhase.on;
    final report = _started ? ref.watch(upnpProvider) : null;

    return ToolPage(
      title: t.router.title,
      icon: Icons.router_outlined,
      color: m.warn,
      info: t.router.info,
      action: FilledButton(
        onPressed: report?.isLoading == true
            ? null
            : () {
                if (_started) ref.invalidate(upnpProvider);
                setState(() => _started = true);
              },
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        child: Text(report?.isLoading == true ? t.router.asking : (_started ? t.router.again : t.router.check)),
      ),
      children: [
        LanVpnNotice(vpnOn: vpnOn),
        switch (report) {
          null => const SizedBox.shrink(),
          AsyncData(:final value) => _Report(report: value),
          AsyncError(:final error) => Text('$error', style: TextStyle(color: m.bad)),
          _ => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
        },
      ],
    );
  }
}

class _Report extends StatelessWidget {
  const _Report({required this.report});

  final UpnpReport report;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final (headline, detail, color) = !report.enabled
        ? (t.router.off, t.router.offBody, m.good)
        : report.mappings.isEmpty
            ? (t.router.upnpOn, t.router.onBody, m.warn)
            : (t.router.opened(n: report.mappings.length), t.router.checkEach, m.bad);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Center(
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: .5), width: 2),
            ),
            child: Icon(Icons.router_outlined, size: 44, color: color),
          ),
        ),
        const SizedBox(height: 12),
        Text(headline, textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 4),
        Text(detail, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, height: 1.4, color: m.muted)),
        if (report.routerName != null || report.externalIp != null) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              if (report.routerName != null)
                Expanded(child: MetricTile(label: t.router.routerLabel, value: report.routerName!)),
              if (report.routerName != null && report.externalIp != null) const SizedBox(width: 8),
              if (report.externalIp != null)
                Expanded(child: MetricTile(label: t.router.internetAddress, value: report.externalIp!)),
            ],
          ),
        ],
        if (report.behindCarrierNat) ...[
          const SizedBox(height: 10),
          Text(t.router.cgnat, style: TextStyle(fontSize: 12, color: m.good)),
        ],
        if (report.mappings.isNotEmpty) ...[
          ToolHeading(t.router.openedBy),
          ToolCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final (i, p) in report.mappings.indexed) ...[
                  if (i > 0) Divider(height: 1, color: m.line),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        _PortChip(port: p.externalPort, color: p.description.isEmpty ? m.warn : m.brand),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.description.isEmpty ? t.router.noDescription : p.description,
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: p.description.isEmpty ? m.warn : m.text),
                              ),
                              Text(t.router.mapping(proto: p.protocol, host: '${p.internalClient}:${p.internalPort}'),
                                  style: m.monoStyle(size: 12, color: m.muted)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// A port number in a tinted box.
class _PortChip extends StatelessWidget {
  const _PortChip({required this.port, required this.color});

  final int port;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minWidth: 58),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color.withValues(alpha: .16), borderRadius: BorderRadius.circular(9)),
        child: Text('$port', style: context.mer.monoStyle(size: 13, weight: FontWeight.w600, color: color)),
      );
}
