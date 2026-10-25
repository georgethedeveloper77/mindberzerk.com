import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../../../../i18n/strings.g.dart';
import '../design/meridian.dart';
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ToolCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(headline, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
              const SizedBox(height: 4),
              Text(detail, style: TextStyle(fontSize: 13, height: 1.4, color: m.muted)),
              if (report.routerName != null) ...[
                const SizedBox(height: 10),
                Text(t.router.routerName(name: report.routerName ?? ''), style: TextStyle(fontSize: 13, color: m.text)),
              ],
              if (report.externalIp != null)
                Text(t.router.externalIp(ip: report.externalIp ?? ''), style: m.monoStyle(size: 12, color: m.muted)),
              if (report.behindCarrierNat) ...[
                const SizedBox(height: 6),
                Text(t.router.cgnat, style: TextStyle(fontSize: 12, color: m.good)),
              ],
            ],
          ),
        ),
        if (report.mappings.isNotEmpty) ...[
          const SizedBox(height: 12),
          ToolCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Column(
              children: [
                for (final (i, p) in report.mappings.indexed) ...[
                  if (i > 0) Divider(height: 1, color: m.line),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 70,
                          child: Text('${p.externalPort}', style: m.monoStyle(size: 15, weight: FontWeight.w600)),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.description.isEmpty ? t.router.noDescription : p.description,
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: m.text)),
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
