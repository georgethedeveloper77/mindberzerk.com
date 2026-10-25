import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/appear.dart';
import '../design/countries.dart';
import '../design/flag.dart';
import '../design/list_ui.dart';
import '../design/meridian.dart';
import '../design/sheet.dart';
import '../i18n/strings.g.dart';
import '../ui/add_server_sheet.dart';
import '../vpn/community_server.dart';
import '../vpn/tunnel_store.dart';
import '../vpn/vpn_controller.dart';
import 'server_details.dart';
import 'community.dart';

/// G Servers (Pro) appear as their own first tab once any are running.
/// Until then the tab is not shown at all: an empty "coming soon" tab is a
/// dead end on the screen people open to connect.
const _proServersLive = false;

enum _Filter { all, fastest, stable, popular }

class ServersScreen extends ConsumerStatefulWidget {
  const ServersScreen({super.key, required this.openHome, required this.openPro});

  /// Tapping a server connects to it and shows the result on Home.
  final VoidCallback openHome;
  final VoidCallback openPro;

  @override
  ConsumerState<ServersScreen> createState() => _ServersScreenState();
}

class _ServersScreenState extends ConsumerState<ServersScreen> {
  // The first tab is the one with servers in it: Free today, Pro later.
  int _tab = 0;
  _Filter _filter = _Filter.all;

  /// Tab ids; labels come from the translations.
  List<String> get _tabs => [if (_proServersLive) 'pro', 'free', 'yours'];

  static String _label(String id) => switch (id) {
        'pro' => t.servers.tabs.pro,
        'free' => t.servers.tabs.free,
        _ => t.servers.tabs.yours,
      };

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

  void _about() => showInfoSheet(
        context,
        icon: Icons.public_rounded,
        title: t.servers.sheet.title,
        subtitle: t.servers.sheet.subtitle,
        sections: [
          SheetSection(Icons.check_rounded, t.servers.tabs.free, t.servers.sheet.free, tone: context.mer.good),
          SheetSection(Icons.bolt_rounded, t.servers.tabs.pro, t.servers.sheet.pro),
          SheetSection(Icons.dns_outlined, t.servers.tabs.yours, t.servers.sheet.yours, tone: context.mer.muted),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final tunnels = ref.watch(tunnelsProvider).value;
    final community = ref.watch(communityProvider);
    final tabs = _tabs;
    final current = tabs[_tab.clamp(0, tabs.length - 1)];
    final counts = {
      'free': community.value?.servers.length,
      'yours': tunnels?.tunnels.length,
    };

    return Scaffold(
      backgroundColor: m.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(t.servers.title, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -.5, color: m.text)),
                  ),
                  IconButton.outlined(
                    tooltip: t.servers.aboutServers,
                    onPressed: _about,
                    icon: const Icon(Icons.info_outline_rounded, size: 20),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _Segmented(
                labels: [for (final id in tabs) _label(id)],
                counts: [for (final id in tabs) counts[id]],
                index: _tab.clamp(0, tabs.length - 1),
                onChanged: (i) => setState(() => _tab = i),
              ),
            ),
            Expanded(
              child: switch (current) {
                'free' => _FreeTab(filter: _filter, onFilter: (f) => setState(() => _filter = f), pick: _pick),
                'yours' => _YoursTab(pick: _pick),
                _ => const SizedBox.shrink(),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({required this.labels, required this.counts, required this.index, required this.onChanged});

  final List<String> labels;
  final List<int?> counts;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: m.surface2, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Semantics(
                selected: i == index,
                button: true,
                child: GestureDetector(
                  onTap: () => onChanged(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == index ? m.surface : Colors.transparent,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Text.rich(
                      TextSpan(
                        text: labels[i],
                        style: TextStyle(fontSize: 14, fontWeight: i == index ? FontWeight.w800 : FontWeight.w700, color: i == index ? m.text : m.muted),
                        children: [
                          if (counts[i] != null)
                            TextSpan(text: '  ${counts[i]}', style: TextStyle(fontWeight: FontWeight.w600, color: m.muted)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

typedef _Pick = Future<void> Function(ServerChoice choice, Future<void> Function() select);

// ── Free ──────────────────────────────────────────────────────────────────

class _FreeTab extends ConsumerWidget {
  const _FreeTab({required this.filter, required this.onFilter, required this.pick});

  final _Filter filter;
  final ValueChanged<_Filter> onFilter;
  final _Pick pick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.mer;
    final community = ref.watch(communityProvider);
    final selectedId = ref.watch(tunnelsProvider).value?.choice?.id;
    final phase = ref.watch(vpnProvider.select((s) => s.phase));
    final busy = phase == VpnPhase.connecting || phase == VpnPhase.disconnecting;

    return RefreshIndicator(
      onRefresh: () => ref.refresh(communityProvider.future),
      child: switch (community) {
        AsyncData(:final value) when value.servers.isNotEmpty => Builder(builder: (context) {
            final servers = value.servers;
            // Badges from what VPN Gate reports live: sessions right now,
            // days without a restart, and measured throughput.
            CommunityServer top(num Function(CommunityServer) by) => servers.reduce((a, b) => by(b) > by(a) ? b : a);
            final badges = <String, (String, Color)>{};
            badges.putIfAbsent(top((s) => s.sessions).id, () => (t.servers.badges.mostUsed, m.brand));
            badges.putIfAbsent(top((s) => s.uptimeDays).id, () => (t.servers.badges.mostStable, m.good));
            badges.putIfAbsent(top((s) => s.speedMbps).id, () => (t.servers.badges.fastest, m.warn));

            final sorted = [...servers];
            switch (filter) {
              case _Filter.fastest:
                sorted.sort((a, b) => b.speedMbps.compareTo(a.speedMbps));
              case _Filter.stable:
                sorted.sort((a, b) => b.uptimeDays.compareTo(a.uptimeDays));
              case _Filter.popular:
                sorted.sort((a, b) => b.sessions.compareTo(a.sessions));
              case _Filter.all:
                break; // the Worker's ranking
            }
            final best = servers.first;
            void connect(CommunityServer s) =>
                pick(CommunityChoice(s), () => ref.read(tunnelsProvider.notifier).selectCommunity(s));

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                Appear(index: 0, child: _BestCard(server: best, onConnect: busy ? null : () => connect(best))),
                const SizedBox(height: 14),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final (f, label) in [
                        (_Filter.all, t.servers.filters.all),
                        (_Filter.fastest, t.servers.filters.fastest),
                        (_Filter.stable, t.servers.filters.stable),
                        (_Filter.popular, t.servers.filters.popular),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(label),
                            selected: filter == f,
                            onSelected: (_) => onFilter(f),
                            showCheckmark: false,
                            selectedColor: m.text,
                            labelStyle: TextStyle(fontWeight: FontWeight.w700, color: filter == f ? m.bg : m.text),
                            shape: StadiumBorder(side: BorderSide(color: filter == f ? m.text : m.line)),
                            backgroundColor: m.surface,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Keyed by filter: changing it replays the arrival.
                KeyedSubtree(
                  key: ValueKey(filter),
                  child: _Group(children: [
                    for (final (i, s) in sorted.indexed)
                      Appear(
                        index: i + 1,
                        child: _ServerRow(
                          server: s,
                          badge: badges[s.id],
                          selected: '$communityPrefix${s.id}' == selectedId,
                          onTap: busy ? null : () => connect(s),
                        ),
                      ),
                  ]),
                ),
              ],
            );
          }),
        AsyncData() || AsyncError() => ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _Group(children: [
                ListTile(
                  title: Text(community.hasError ? t.servers.loadFailed : t.servers.noServers, style: TextStyle(fontWeight: FontWeight.w700, color: m.text)),
                  trailing: TextButton(onPressed: () => ref.invalidate(communityProvider), child: Text(t.common.retry)),
                ),
              ]),
            ],
          ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _BestCard extends StatelessWidget {
  const _BestCard({required this.server, required this.onConnect});

  final CommunityServer server;
  final VoidCallback? onConnect;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    // A dark card in both themes: it is the one thing to look at first.
    const ink = Color(0xFF0E1220);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.circular(Meridian.rCard)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(t.servers.best,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .8, color: Color(0xFF9DB4FF))),
              ),
              if (server.pingMs > 0)
                Text('${server.pingMs} ms', style: m.monoStyle(size: 12, color: const Color(0xFFB7BDCC))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CountryFlag(server.countryCode, width: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(countryName(server.countryCode, server.country),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                    Text(t.servers.topRanked, style: const TextStyle(fontSize: 13, color: Color(0xFFB7BDCC))),
                  ],
                ),
              ),
              FilledButton(
                onPressed: onConnect,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(t.common.connect),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    return Material(
      color: m.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Meridian.rCard), side: BorderSide(color: m.line)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final (i, c) in children.indexed) ...[
            if (i > 0) Divider(height: 1, indent: 14, endIndent: 14, color: m.line),
            c,
          ],
        ],
      ),
    );
  }
}

class _ServerRow extends StatelessWidget {
  const _ServerRow({required this.server, required this.badge, required this.selected, required this.onTap});

  final CommunityServer server;
  final (String, Color)? badge;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final bars = switch (server.grade) { 'fast' => 4, 'good' => 3, _ => 2 };
    final barColor = server.grade == 'slow' ? m.warn : m.good;
    final speed = server.speedMbps <= 0
        ? null
        : server.speedMbps >= 10
            ? server.speedMbps.round().toString()
            : server.speedMbps.toStringAsFixed(1);
    final detail = [
      if (speed != null) '$speed Mbps',
      server.proto.toUpperCase(),
      if (server.pingMs > 0) '${server.pingMs} ms',
    ].join(' · ');

    return InkWell(
      onTap: onTap,
      child: Container(
        color: selected ? m.brandSoft : null,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            CountryFlag(server.countryCode, width: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(countryName(server.countryCode, server.country),
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: m.text)),
                      if (badge != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(color: badge!.$2.withValues(alpha: .13), borderRadius: BorderRadius.circular(999)),
                          child: Text(badge!.$1,
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .4, color: badge!.$2)),
                        ),
                    ],
                  ),
                  Text(detail, style: m.monoStyle(size: 12, color: m.muted)),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_rounded, color: m.brand)
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < 4; i++)
                    Container(
                      width: 4,
                      height: 6.0 + i * 3.4,
                      margin: const EdgeInsets.only(left: 2),
                      decoration: BoxDecoration(color: i < bars ? barColor : m.line, borderRadius: BorderRadius.circular(1)),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ── Yours ─────────────────────────────────────────────────────────────────

class _YoursTab extends ConsumerWidget {
  const _YoursTab({required this.pick});

  final _Pick pick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.mer;
    final tunnels = ref.watch(tunnelsProvider).value;
    final selectedId = tunnels?.choice?.id;
    final phase = ref.watch(vpnProvider.select((s) => s.phase));
    final busy = phase == VpnPhase.connecting || phase == VpnPhase.disconnecting;
    final list = tunnels?.tunnels ?? const <SavedTunnel>[];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        for (final (i, tunnel) in list.indexed) ...[
          Appear(
            key: ValueKey(tunnel.id),
            index: i,
            child: _OwnCard(
              tunnel: tunnel,
              selected: tunnel.id == selectedId,
              connected: phase == VpnPhase.on && tunnel.id == selectedId,
              onConnect: busy ? null : () => pick(OwnServer(tunnel), () => ref.read(tunnelsProvider.notifier).select(tunnel.id)),
              onRemove: () => ref.read(tunnelsProvider.notifier).remove(tunnel.id),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 0, 10),
          child: Text(t.servers.addHeading, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: .6, color: m.muted)),
        ),
        Row(
          children: [
            Expanded(child: _AddButton(icon: Icons.qr_code_scanner_rounded, label: t.servers.scanQr, onTap: () => _scanChoice(context, ref))),
            const SizedBox(width: 10),
            Expanded(child: _AddButton(icon: Icons.file_open_outlined, label: t.servers.importFile, onTap: () => _importFile(context, ref))),
            const SizedBox(width: 10),
            Expanded(child: _AddButton(icon: Icons.content_paste_rounded, label: t.servers.paste, onTap: () => AddServerSheet.show(context))),
          ],
        ),
        const SizedBox(height: 12),
        Material(
          color: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: m.line, width: 1.5)),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => showInfoSheet(
              context,
              icon: Icons.terminal_rounded,
              title: t.servers.own.title,
              subtitle: t.servers.own.subtitle,
              sections: [
                SheetSection(Icons.router_outlined, t.servers.own.router, t.servers.own.routerBody),
                SheetSection(Icons.cloud_outlined, t.servers.own.vps, t.servers.own.vpsBody),
                SheetSection(Icons.home_outlined, t.servers.own.home, t.servers.own.homeBody),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.terminal_rounded, color: m.text),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(list.isEmpty ? t.servers.own.noneYet : t.servers.own.addAnother, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: m.text)),
                        Text(t.servers.own.hint, style: TextStyle(fontSize: 13, color: m.muted)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: m.muted),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OwnCard extends ConsumerWidget {
  const _OwnCard({
    required this.tunnel,
    required this.selected,
    required this.connected,
    required this.onConnect,
    required this.onRemove,
  });

  final SavedTunnel tunnel;
  final bool selected;
  final bool connected;
  final VoidCallback? onConnect;
  final VoidCallback onRemove;

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final name = await _RenameSheet.show(context, tunnel.name);
    if (name != null) await ref.read(tunnelsProvider.notifier).rename(tunnel.id, name);
  }

  void _openDetails(BuildContext context, WidgetRef ref) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ServerDetailsScreen(
            tunnelId: tunnel.id,
            onConnect: () => onConnect?.call(),
            onRename: () => _rename(context, ref),
            onRemove: () async {
              if (!await confirmRemoveServer(context)) return false;
              onRemove();
              return true;
            },
          ),
        ),
      );

  Future<void> _actions(BuildContext context, WidgetRef ref, String endpoint) async {
    final choice = await _ServerActionsSheet.show(context, tunnel.name, endpoint, canRemove: !connected);
    if (!context.mounted) return;
    switch (choice) {
      case _ServerAction.rename:
        await _rename(context, ref);
      case _ServerAction.remove:
        onRemove();
      case null:
        break;
    }
  }

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.mer;
    final vpn = ref.watch(vpnProvider);
    final busy = vpn.phase == VpnPhase.connecting || vpn.phase == VpnPhase.disconnecting;
    String endpoint;
    try {
      endpoint = tunnel.summary.endpoint;
    } on Exception {
      endpoint = t.servers.configBroken;
    }
    final detail = connected
        ? '↓ ${_bytes(vpn.rxBytes)}  ↑ ${_bytes(vpn.txBytes)}'
        : tunnel.lastUsed == null
            ? t.servers.neverUsed
            : t.servers.lastUsed(when: _ago(tunnel.lastUsed!));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.fromLTRB(16, 12, 6, 16),
      decoration: BoxDecoration(
        color: connected ? Color.alphaBlend(m.brand.withValues(alpha: .06), m.surface) : m.surface,
        borderRadius: BorderRadius.circular(Meridian.rCard),
        border: Border.all(color: selected ? m.brand : m.line, width: selected ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: connected ? m.good.withValues(alpha: .16) : m.brandSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.dns_outlined, color: connected ? m.good : m.brand),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _openDetails(context, ref),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: Text(
                          tunnel.name,
                          key: ValueKey(tunnel.name),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: m.text),
                        ),
                      ),
                      Text(endpoint, maxLines: 1, overflow: TextOverflow.ellipsis, style: m.monoStyle(size: 12, color: m.muted)),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: Text(
                          detail,
                          key: ValueKey(connected),
                          style: m.monoStyle(size: 12, color: connected ? m.good : m.muted),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: t.servers.more,
                onPressed: () => _actions(context, ref, endpoint),
                icon: Icon(Icons.more_vert_rounded, color: m.muted),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              // Connect and Disconnect cross-fade and settle into place.
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                switchInCurve: Curves.easeOutCubic,
                transitionBuilder: (child, a) => FadeTransition(
                  opacity: a,
                  child: ScaleTransition(scale: Tween(begin: .96, end: 1.0).animate(a), child: child),
                ),
                child: connected
                    ? OutlinedButton.icon(
                        key: const ValueKey('disconnect'),
                        onPressed: busy ? null : () => ref.read(vpnProvider.notifier).disconnect(),
                        icon: Icon(Icons.power_settings_new_rounded, color: m.bad),
                        label: Text(t.servers.disconnect, style: TextStyle(color: m.bad, fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          side: BorderSide(color: m.bad.withValues(alpha: .5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      )
                    : FilledButton(
                        key: const ValueKey('connect'),
                        onPressed: onConnect,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(t.common.connect),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _ServerAction { rename, remove }

/// Bottom sheet: what can be done with one of the user's servers. Removing
/// asks once more, inside the same sheet.
class _ServerActionsSheet extends StatefulWidget {
  const _ServerActionsSheet({required this.name, required this.endpoint, required this.canRemove});

  final String name;
  final String endpoint;
  final bool canRemove;

  static Future<_ServerAction?> show(BuildContext context, String name, String endpoint, {required bool canRemove}) =>
      showModalBottomSheet<_ServerAction>(
        context: context,
        showDragHandle: true,
        useSafeArea: true,
        backgroundColor: context.mer.surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        builder: (_) => _ServerActionsSheet(name: name, endpoint: endpoint, canRemove: canRemove),
      );

  @override
  State<_ServerActionsSheet> createState() => _ServerActionsSheetState();
}

class _ServerActionsSheetState extends State<_ServerActionsSheet> {
  bool _confirming = false;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.name, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: m.text)),
            Text(widget.endpoint, style: m.monoStyle(size: 12, color: m.muted)),
            const SizedBox(height: 16),
            if (!_confirming)
              ListGroup(children: [
                ListItem(
                  leading: Icon(Icons.edit_outlined, color: m.brand),
                  title: t.servers.rename,
                  onTap: () => Navigator.pop(context, _ServerAction.rename),
                ),
                ListItem(
                  leading: Icon(Icons.delete_outline_rounded, color: widget.canRemove ? m.bad : m.muted),
                  title: t.common.remove,
                  subtitle: widget.canRemove ? null : t.servers.disconnectFirst,
                  onTap: widget.canRemove ? () => setState(() => _confirming = true) : null,
                ),
              ])
            else ...[
              Text(t.servers.removeConfirm, style: TextStyle(fontSize: 15, height: 1.4, color: m.text)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _confirming = false),
                      child: Text(t.common.cancel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: m.bad),
                      onPressed: () => Navigator.pop(context, _ServerAction.remove),
                      child: Text(t.common.remove),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet with a name field. Owns its text controller, so nothing is
/// disposed while the sheet is still animating closed.
class _RenameSheet extends StatefulWidget {
  const _RenameSheet({required this.initial});

  final String initial;

  static Future<String?> show(BuildContext context, String initial) => showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        useSafeArea: true,
        backgroundColor: context.mer.surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        builder: (_) => _RenameSheet(initial: initial),
      );

  @override
  State<_RenameSheet> createState() => _RenameSheetState();
}

class _RenameSheetState extends State<_RenameSheet> {
  late final TextEditingController _name = TextEditingController(text: widget.initial)
    ..selection = TextSelection(baseOffset: 0, extentOffset: widget.initial.length);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final v = _name.text.trim();
    if (v.isNotEmpty) Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    return Padding(
      // Rises with the keyboard.
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t.servers.renameTitle, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: m.text)),
          const SizedBox(height: 14),
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(hintText: t.servers.nameHint),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              child: Text(t.servers.save, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    return Material(
      color: m.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: m.line)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: SizedBox(
          height: 104,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 26, color: m.brand),
              const SizedBox(height: 8),
              Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: m.text)),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _scan(BuildContext context, WidgetRef ref) async {
  try {
    final text = await ref.read(vpnApiProvider).scanQr();
    if (text == null || !context.mounted) return;
    await AddServerSheet.show(context, name: suggestServerName(text) ?? t.servers.scannedServer, config: text);
  } on PlatformException catch (e) {
    if (context.mounted) await _problem(context, t.servers.scanFailedTitle, e.message ?? t.servers.scanFailedBody);
  }
}

Future<void> _importFile(BuildContext context, WidgetRef ref) async {
  try {
    final picked = await ref.read(vpnApiProvider).pickConfigFile();
    if (picked == null || !context.mounted) return;
    final backup = parseBackup(picked.text);
    if (backup != null) {
      final store = ref.read(tunnelsProvider.notifier);
      final have = {for (final s in (await ref.read(tunnelsProvider.future)).tunnels) s.configText.trim()};
      var added = 0;
      for (final s in backup) {
        if (have.contains(s.config.trim())) continue;
        if (await store.add(name: s.name, configText: s.config) == null) added++;
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(added == 0 ? t.backup.nothingNew : t.backup.restored(n: added))),
        );
      }
      return;
    }
    await AddServerSheet.show(context, name: suggestServerName(picked.text) ?? picked.name, config: picked.text);
  } on PlatformException catch (e) {
    if (context.mounted) await _problem(context, t.servers.importFailedTitle, e.message ?? t.servers.importFailedBody);
  }
}

Future<void> _problem(BuildContext context, String title, String message) => showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: Text(t.common.ok))],
      ),
    );


/// Scan QR: with the camera, or from an image already on the phone.
Future<void> _scanChoice(BuildContext context, WidgetRef ref) async {
  final m = context.mer;
  final fromImage = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    backgroundColor: m.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (c) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t.add.title, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: m.text)),
          const SizedBox(height: 4),
          Text(t.add.subtitle, style: TextStyle(fontSize: 14, height: 1.45, color: m.muted)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ChoiceTile(
                  icon: Icons.qr_code_scanner_rounded,
                  title: t.add.camera,
                  subtitle: t.add.cameraSub,
                  primary: true,
                  onTap: () => Navigator.pop(c, false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ChoiceTile(
                  icon: Icons.image_outlined,
                  title: t.add.image,
                  subtitle: t.add.imageSub,
                  onTap: () => Navigator.pop(c, true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: m.brandSoft, borderRadius: BorderRadius.circular(14)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 20, color: m.brand),
                const SizedBox(width: 10),
                Expanded(child: Text(t.add.tip, style: TextStyle(fontSize: 13, height: 1.45, color: m.text))),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  if (fromImage == null || !context.mounted) return;
  if (!fromImage) return _scan(context, ref);
  try {
    final text = await ref.read(vpnApiProvider).scanQrFromImage();
    if (text == null || !context.mounted) return;
    await AddServerSheet.show(context, name: suggestServerName(text) ?? t.servers.scannedServer, config: text);
  } on PlatformException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.code == 'no_qr' ? t.add.noQr : (e.message ?? t.add.noQr))),
      );
    }
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final fg = primary ? Colors.white : m.text;
    return Material(
      color: primary ? m.brand : m.brandSoft,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 112),
          padding: const EdgeInsets.all(16),
          decoration: primary
              ? null
              : BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: m.brand, width: 2)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 28, color: primary ? Colors.white : m.brand),
              const SizedBox(height: 18),
              Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: fg)),
              Text(subtitle, style: TextStyle(fontSize: 12, color: primary ? Colors.white.withValues(alpha: .85) : m.muted)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Asks once before a server's settings are deleted from this phone.
Future<bool> confirmRemoveServer(BuildContext context) async {
  final m = context.mer;
  final yes = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    backgroundColor: m.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (c) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t.servers.removeConfirm, style: TextStyle(fontSize: 15, height: 1.45, color: m.text)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(c, false), child: Text(t.common.cancel))),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: m.bad),
                  onPressed: () => Navigator.pop(c, true),
                  child: Text(t.common.remove),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  return yes ?? false;
}
