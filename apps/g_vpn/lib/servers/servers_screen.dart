import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/countries.dart';
import '../design/flag.dart';
import '../design/list_ui.dart';
import '../design/meridian.dart';
import '../ui/add_server_sheet.dart';
import '../vpn/community_server.dart';
import '../vpn/tunnel_store.dart';
import '../vpn/vpn_controller.dart';
import 'community.dart';

class ServersScreen extends ConsumerStatefulWidget {
  const ServersScreen({super.key, required this.openHome, required this.openPro});

  /// Tapping a server connects to it and shows the result on Home.
  final VoidCallback openHome;
  final VoidCallback openPro;

  @override
  ConsumerState<ServersScreen> createState() => _ServersScreenState();
}

class _ServersScreenState extends ConsumerState<ServersScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  /// Select, connect (switching if already connected elsewhere), show Home.
  Future<void> _pick(ServerChoice choice, Future<void> Function() select) async {
    await select();
    widget.openHome();
    final vpn = ref.read(vpnProvider.notifier);
    final current = ref.read(vpnProvider);
    if (current.phase == VpnPhase.on) {
      if (current.tunnelId == choice.id) return;
      await vpn.disconnect();
    }
    await vpn.connect(choice);
  }

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final tunnels = ref.watch(tunnelsProvider).value;
    final community = ref.watch(communityProvider);
    final phase = ref.watch(vpnProvider.select((s) => s.phase));
    final busy = phase == VpnPhase.connecting || phase == VpnPhase.disconnecting;
    final selectedId = tunnels?.choice?.id;
    final notice = community.value?.notice ?? '';
    const pad = EdgeInsets.fromLTRB(16, 16, 16, 24);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Servers'),
        centerTitle: false,
        actions: [
          InfoAction(
            title: 'Servers',
            body: 'Pro: G Servers, run by Mindberzerk with no activity logs.\n\n'
                'Free: volunteer servers from the VPN Gate academic project, ranked by speed, load and uptime, '
                'and checked to be reachable. $notice\n\n'
                'Yours: any WireGuard server you run, such as a router, a VPS or a home server.',
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800),
          tabs: const [Tab(text: 'Pro'), Tab(text: 'Free'), Tab(text: 'Yours')],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          // ── Pro ──
          ListView(
            padding: pad,
            children: [
              ListGroup(children: [
                ListItem(
                  leading: Icon(Icons.bolt_rounded, color: m.brand),
                  title: 'G Servers',
                  subtitle: 'Coming soon',
                  trailing: Tag('PRO', color: m.brand),
                  onTap: widget.openPro,
                ),
              ]),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => _tabs.animateTo(1),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                child: const Text('Use free servers'),
              ),
            ],
          ),
          // ── Free ──
          RefreshIndicator(
            onRefresh: () => ref.refresh(communityProvider.future),
            child: ListView(
              padding: pad,
              children: [
                switch (community) {
                  AsyncData(:final value) => ListGroup(children: [
                      for (final s in value.servers)
                        _CommunityItem(
                          server: s,
                          selected: '$communityPrefix${s.id}' == selectedId,
                          onTap: busy
                              ? null
                              : () => _pick(CommunityChoice(s), () => ref.read(tunnelsProvider.notifier).selectCommunity(s)),
                        ),
                    ]),
                  AsyncError() => ListGroup(children: [
                      ListItem(
                        title: 'Could not load the list',
                        trailing: Text('Retry', style: TextStyle(color: m.brand, fontWeight: FontWeight.w700)),
                        onTap: () => ref.invalidate(communityProvider),
                      ),
                    ]),
                  _ => const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator(minHeight: 2)),
                },
              ],
            ),
          ),
          // ── Yours ──
          ListView(
            padding: pad,
            children: [
              if (tunnels?.tunnels.isNotEmpty ?? false) ...[
                ListGroup(children: [
                  for (final t in tunnels!.tunnels)
                    _OwnItem(
                      tunnel: t,
                      selected: t.id == selectedId,
                      onTap: busy ? null : () => _pick(OwnServer(t), () => ref.read(tunnelsProvider.notifier).select(t.id)),
                    ),
                ]),
                const SizedBox(height: 16),
              ],
              ListGroup(children: [
                ListItem(
                  leading: Icon(Icons.qr_code_scanner_rounded, color: m.brand),
                  title: 'Scan QR code',
                  onTap: () => _scan(context, ref),
                ),
                ListItem(
                  leading: Icon(Icons.file_open_outlined, color: m.brand),
                  title: 'Import file',
                  onTap: () => _importFile(context, ref),
                ),
                ListItem(
                  leading: Icon(Icons.content_paste_rounded, color: m.brand),
                  title: 'Paste config',
                  onTap: () => AddServerSheet.show(context),
                ),
              ]),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> _scan(BuildContext context, WidgetRef ref) async {
  try {
    final text = await ref.read(vpnApiProvider).scanQr();
    if (text == null || !context.mounted) return;
    await AddServerSheet.show(context, name: 'Scanned server', config: text);
  } on PlatformException catch (e) {
    if (context.mounted) await _problem(context, 'Could not scan', e.message ?? 'The scanner is not available on this phone.');
  }
}

Future<void> _importFile(BuildContext context, WidgetRef ref) async {
  try {
    final picked = await ref.read(vpnApiProvider).pickConfigFile();
    if (picked == null || !context.mounted) return;
    await AddServerSheet.show(context, name: picked.name, config: picked.text);
  } on PlatformException catch (e) {
    if (context.mounted) await _problem(context, 'Could not import', e.message ?? 'That file could not be read.');
  }
}

Future<void> _problem(BuildContext context, String title, String message) => showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
      ),
    );

class _CommunityItem extends StatelessWidget {
  const _CommunityItem({required this.server, required this.selected, required this.onTap});

  final CommunityServer server;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final color = switch (server.grade) {
      'fast' => m.good,
      'slow' => m.warn,
      _ => m.brand,
    };
    // Partner sources publish no speed; show the protocol alone rather than "0 Mbps".
    final speed = server.speedMbps <= 0
        ? null
        : server.speedMbps >= 10
            ? server.speedMbps.round().toString()
            : server.speedMbps.toStringAsFixed(1);
    return ListItem(
      leading: CountryFlag(server.countryCode),
      title: countryName(server.countryCode, server.country),
      subtitle: speed == null ? server.proto.toUpperCase() : '$speed Mbps · ${server.proto.toUpperCase()}',
      mono: true,
      selected: selected,
      onTap: onTap,
      trailing: selected ? Icon(Icons.check_rounded, color: m.brand) : Tag(server.grade.toUpperCase(), color: color),
    );
  }
}

class _OwnItem extends ConsumerWidget {
  const _OwnItem({required this.tunnel, required this.selected, required this.onTap});

  final SavedTunnel tunnel;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.mer;
    String endpoint;
    try {
      endpoint = tunnel.summary.endpoint;
    } on Exception {
      endpoint = 'Config needs attention';
    }
    return ListItem(
      leading: Container(
        width: 28,
        height: 21,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: m.brandSoft, borderRadius: BorderRadius.circular(4)),
        child: Text('WG', style: m.monoStyle(size: 10, weight: FontWeight.w600, color: m.brand)),
      ),
      title: tunnel.name,
      subtitle: endpoint,
      mono: true,
      selected: selected,
      onTap: onTap,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selected) Icon(Icons.check_rounded, color: m.brand),
          IconButton(
            tooltip: 'Remove',
            onPressed: () => ref.read(tunnelsProvider.notifier).remove(tunnel.id),
            icon: Icon(Icons.delete_outline_rounded, color: m.muted),
          ),
        ],
      ),
    );
  }
}
