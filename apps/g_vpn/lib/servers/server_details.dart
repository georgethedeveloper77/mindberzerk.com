import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../design/list_ui.dart';
import '../design/meridian.dart';
import '../i18n/strings.g.dart';
import '../vpn/tunnel_store.dart';
import '../vpn/vpn_controller.dart';
import 'share_sheet.dart';

/// One of the user's own WireGuard servers: status, traffic, what the
/// settings say, and everything that can be done with it.
class ServerDetailsScreen extends ConsumerStatefulWidget {
  const ServerDetailsScreen({
    super.key,
    required this.tunnelId,
    required this.onConnect,
    required this.onRename,
    required this.onRemove,
  });

  final String tunnelId;
  final VoidCallback onConnect;
  final Future<void> Function() onRename;
  final Future<bool> Function() onRemove;

  @override
  ConsumerState<ServerDetailsScreen> createState() => _ServerDetailsScreenState();
}

class _ServerDetailsScreenState extends ConsumerState<ServerDetailsScreen> {
  // "Connected for" moves on by itself.
  late final Timer _tick = Timer.periodic(const Duration(seconds: 30), (_) {
    if (mounted) setState(() {});
  });

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final tunnels = ref.watch(tunnelsProvider).value;
    final tunnel = tunnels?.tunnels.where((t) => t.id == widget.tunnelId).firstOrNull;
    if (tunnel == null) return Scaffold(backgroundColor: m.bg);
    final vpn = ref.watch(vpnProvider);
    final selected = tunnels!.selectedId == tunnel.id;
    final connected = selected && vpn.phase == VpnPhase.on;
    final busy = vpn.phase == VpnPhase.connecting || vpn.phase == VpnPhase.disconnecting;
    final ini = WgIni.parse(tunnel.configText);

    return Scaffold(
      backgroundColor: m.bg,
      appBar: AppBar(
        backgroundColor: m.bg,
        surfaceTintColor: Colors.transparent,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: OutlinedButton.icon(
              onPressed: () => ShareServerSheet.show(context, tunnel),
              icon: const Icon(Icons.ios_share_rounded, size: 18),
              label: Text(t.details.share),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: connected ? m.good.withValues(alpha: .16) : m.brandSoft,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(Icons.dns_outlined, size: 28, color: connected ? m.good : m.brand),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tunnel.name, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -.4, color: m.text)),
                    Text(ini.endpoint ?? '', style: m.monoStyle(size: 13, color: m.muted)),
                    const SizedBox(height: 8),
                    _StatusPill(connected: connected, since: vpn.connectedAt),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 54,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              child: connected
                  ? OutlinedButton.icon(
                      key: const ValueKey('off'),
                      onPressed: busy ? null : () => ref.read(vpnProvider.notifier).disconnect(),
                      icon: Icon(Icons.power_settings_new_rounded, color: m.bad),
                      label: Text(t.servers.disconnect, style: TextStyle(color: m.bad, fontSize: 16, fontWeight: FontWeight.w800)),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                        side: BorderSide(color: m.bad.withValues(alpha: .55), width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    )
                  : FilledButton(
                      key: const ValueKey('on'),
                      onPressed: busy ? null : widget.onConnect,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(t.common.connect, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: connected
                ? [
                    Expanded(child: _Tile(t.details.downloaded, _bytes(vpn.rxBytes))),
                    const SizedBox(width: 10),
                    Expanded(child: _Tile(t.details.uploaded, _bytes(vpn.txBytes))),
                  ]
                : [
                    Expanded(
                      child: _Tile(
                        t.details.lastUsed,
                        tunnel.lastUsed == null ? t.servers.neverUsed : _ago(tunnel.lastUsed!),
                      ),
                    ),
                  ],
          ),
          SectionTitle(t.details.connection),
          ListGroup(children: [
            ListItem(title: t.details.protocol, trailing: const _Value('WireGuard')),
            if (ini.address != null) ListItem(title: t.details.address, trailing: _Value(ini.address!, mono: true)),
            if (ini.dns != null) ListItem(title: t.details.dns, trailing: _Value(ini.dns!, mono: true)),
            ListItem(
              title: t.details.routes,
              trailing: _Value(ini.allTraffic ? t.details.allTraffic : t.details.someRoutes(n: ini.routeCount)),
            ),
            if (ini.keepalive != null) ListItem(title: t.details.keepalive, trailing: _Value('${ini.keepalive} s', mono: true)),
            if (ini.serverKey != null)
              ListItem(
                title: t.details.serverKey,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Value(_short(ini.serverKey!), mono: true),
                    IconButton(
                      tooltip: t.details.copy,
                      icon: Icon(Icons.copy_rounded, size: 18, color: m.brand),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: ini.serverKey!));
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.details.copied)));
                      },
                    ),
                  ],
                ),
              ),
          ]),
          SectionTitle(t.details.manage),
          ListGroup(children: [
            ListItem(
              leading: Icon(Icons.edit_outlined, color: m.brand),
              title: t.servers.rename,
              onTap: widget.onRename,
            ),
            ListItem(
              leading: Icon(Icons.download_rounded, color: m.brand),
              title: t.details.export,
              subtitle: t.details.exportSub,
              onTap: () => exportBackup(tunnels.tunnels),
            ),
            ListItem(
              leading: Icon(Icons.delete_outline_rounded, color: connected ? m.muted : m.bad),
              title: t.common.remove,
              subtitle: connected ? t.servers.disconnectFirst : null,
              onTap: connected
                  ? null
                  : () async {
                      if (await widget.onRemove() && context.mounted) Navigator.pop(context);
                    },
            ),
          ]),
        ],
      ),
    );
  }

  static String _short(String key) => key.length > 12 ? '${key.substring(0, 4)}…${key.substring(key.length - 4)}' : key;

  static String _bytes(int b) {
    if (b >= 1 << 30) return '${(b / (1 << 30)).toStringAsFixed(1)} GB';
    if (b >= 1 << 20) return '${(b / (1 << 20)).toStringAsFixed(1)} MB';
    return '${(b / 1024).toStringAsFixed(0)} KB';
  }

  static String _ago(DateTime at) {
    final d = DateTime.now().difference(at);
    if (d.inMinutes < 1) return t.servers.justNow;
    if (d.inHours < 1) return t.servers.minutesAgo(n: d.inMinutes);
    if (d.inDays < 1) return t.servers.hoursAgo(n: d.inHours);
    return t.servers.daysAgo(n: d.inDays);
  }
}

/// Every saved server in one file, to restore after a reinstall or move to
/// another phone. Holds private keys, so it goes only where the user sends it.
Future<void> exportBackup(List<SavedTunnel> tunnels) async {
  final json = jsonEncode({
    'gvpnBackup': 1,
    'servers': [for (final s in tunnels) {'name': s.name, 'config': s.configText}],
  });
  await SharePlus.instance.share(ShareParams(
    files: [XFile.fromData(utf8.encode(json), mimeType: 'application/json', name: 'g-vpn-servers.json')],
    fileNameOverrides: ['g-vpn-servers.json'],
  ));
}

/// Servers in a G VPN backup file, or null when the text is not one.
List<({String name, String config})>? parseBackup(String text) {
  try {
    final j = jsonDecode(text);
    if (j is! Map || j['gvpnBackup'] != 1 || j['servers'] is! List) return null;
    return [
      for (final s in j['servers'] as List)
        if (s is Map && s['name'] is String && s['config'] is String) (name: s['name'] as String, config: s['config'] as String),
    ];
  } on FormatException {
    return null;
  }
}

/// The few wg-quick fields the details page shows.
class WgIni {
  WgIni._(this.address, this.dns, this.endpoint, this.serverKey, this.keepalive, this.routes);

  final String? address;
  final String? dns;
  final String? endpoint;
  final String? serverKey;
  final String? keepalive;
  final List<String> routes;

  bool get allTraffic => routes.contains('0.0.0.0/0');
  int get routeCount => routes.length;

  factory WgIni.parse(String text) {
    String? section;
    final interface = <String, String>{}, peer = <String, String>{};
    for (final raw in const LineSplitter().convert(text)) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      if (line.startsWith('[')) {
        section = line.toLowerCase();
        continue;
      }
      final i = line.indexOf('=');
      if (i < 0) continue;
      final key = line.substring(0, i).trim().toLowerCase();
      final value = line.substring(i + 1).trim();
      if (section == '[interface]') interface[key] = value;
      if (section == '[peer]') peer.putIfAbsent(key, () => value);
    }
    return WgIni._(
      interface['address'],
      interface['dns'],
      peer['endpoint'],
      peer['publickey'],
      peer['persistentkeepalive'],
      (peer['allowedips'] ?? '').split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.connected, required this.since});

  final bool connected;
  final DateTime? since;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final minutes = since == null ? 0 : DateTime.now().difference(since!).inMinutes;
    final color = connected ? m.good : m.muted;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: .14), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(
            connected ? t.details.connectedFor(n: minutes) : t.details.notConnected,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: .6, color: color),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: m.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: m.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .8, color: m.muted)),
          const SizedBox(height: 6),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(value, key: ValueKey(value), style: m.monoStyle(size: 20, color: m.text)),
          ),
        ],
      ),
    );
  }
}

class _Value extends StatelessWidget {
  const _Value(this.text, {this.mono = false});

  final String text;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 180),
      child: Text(
        text,
        textAlign: TextAlign.end,
        overflow: TextOverflow.ellipsis,
        style: mono ? m.monoStyle(size: 13, color: m.text) : TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: m.text),
      ),
    );
  }
}
