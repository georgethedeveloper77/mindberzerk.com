import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/appear.dart';
import '../design/countries.dart';
import '../design/flag.dart';
import '../design/list_ui.dart';
import '../design/meridian.dart';
import '../i18n/strings.g.dart';
import '../pro/billing.dart';
import '../tools/probe.dart';
import '../vpn/tunnel_store.dart';
import '../vpn/vpn_controller.dart';
import 'gservers.dart';

/// Connects to a G Server: registers this phone's key (or confirms it is
/// still there), selects it and connects. Problems become a sheet or a bar.
Future<void> connectGServer(BuildContext context, WidgetRef ref, GServer server) async {
  try {
    final tunnel = await registerGServer(
      ref.read(vpnApiProvider),
      server,
      purchaseToken: ref.read(billingProvider).purchaseToken,
    );
    await ref.read(tunnelsProvider.notifier).selectGServer(tunnel);
    await ref.read(vpnProvider.notifier).connect(OwnServer(tunnel));
  } on GServerException catch (e) {
    if (!context.mounted) return;
    if (e.code == 'limit') {
      final freed = await _LimitSheet.show(context, e.limit ?? e.devices.length, e.devices);
      if (freed && context.mounted) await connectGServer(context, ref, server);
      return;
    }
    final message = switch (e.code) {
      'pro_required' => t.gs.proRequired,
      'busy' => t.gs.busyNow,
      'full' => t.gs.serverFull,
      'off' => t.gs.off,
      _ => t.gs.network,
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Whether this G Server is the selected one and passing traffic.
bool _isConnected(WidgetRef ref, GServer s) {
  final selected = ref.watch(tunnelsProvider).value?.selectedId;
  return selected == '$gserverPrefix${s.id}' && ref.watch(vpnProvider).phase == VpnPhase.on;
}

/// Time to reach a G Server from this phone, in ms; null when it cannot be
/// timed. One handshake each, measured when the Pro tab opens.
final gServerPingProvider = FutureProvider.autoDispose.family<double?, String>((ref, id) async {
  final info = await ref.watch(gServersProvider.future);
  final s = info.servers.where((s) => s.id == id).firstOrNull;
  final host = s?.host;
  if (s == null || host == null || !s.online) return null;
  return tcpPing(host, s.pingPort ?? 443, timeout: const Duration(seconds: 3));
});

Color _busyColor(Meridian m, int? busy) =>
    busy == null ? m.muted : busy >= 85 ? m.bad : busy >= 60 ? m.warn : m.good;

/// The Pro tab when G Servers are on: the best server for this phone right
/// now, every server with its load and ping, what Pro includes, and this
/// plan's phones.
class GServersPage extends ConsumerWidget {
  const GServersPage({super.key, required this.info});

  final GServersInfo info;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.mer;
    final best = info.best;
    final owned = ref.watch(billingProvider).owned;
    final devices = ref.watch(gDevicesProvider).value;
    final used = devices?.devices.length ?? 0;
    final limit = devices?.limit ?? info.limit;

    return Scaffold(
      backgroundColor: m.bg,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(gServersProvider.future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Row(children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: m.warn.withValues(alpha: .16), borderRadius: BorderRadius.circular(11)),
                  child: Icon(Icons.workspace_premium_rounded, size: 20, color: m.warn),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(t.pro.title, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -.5, color: m.text)),
                ),
                if (owned) Tag(t.gs.active, color: m.good),
              ]),
              const SizedBox(height: 16),
              if (best != null) Appear(index: 0, child: _BestCard(server: best)),
              _Heading(t.gs.servers),
              Appear(
                index: 1,
                child: _Card(children: [for (final s in byLoad(info.servers)) GServerRow(server: s)]),
              ),
              _Heading(t.gs.included),
              Appear(
                index: 2,
                child: _Card(children: [
                  _Perk(icon: Icons.bolt_rounded, color: m.brand, title: t.gs.perkServers, sub: t.gs.perkServersSub),
                  _Perk(icon: Icons.link_rounded, color: m.bad, title: t.gs.perkLinks, sub: t.gs.perkLinksSub),
                ]),
              ),
              const SizedBox(height: 12),
              Appear(
                index: 3,
                child: Material(
                  color: m.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Meridian.rCard), side: BorderSide(color: m.line)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(Meridian.rCard),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => GDevicesScreen(info: info))),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(children: [
                        // One slot per phone the plan allows, filled for each in use.
                        for (var i = 0; i < limit.clamp(1, 5); i++) ...[
                          if (i > 0) const SizedBox(width: 6),
                          Container(
                            width: 26,
                            height: 40,
                            decoration: BoxDecoration(
                              color: i < used ? m.brand.withValues(alpha: .14) : null,
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(color: i < used ? m.brand : m.line, width: 2),
                            ),
                            child: i < used ? Icon(Icons.smartphone_rounded, size: 14, color: m.brand) : null,
                          ),
                        ],
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(t.gs.devicesOf(used: used, limit: limit),
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: m.text)),
                            Text(t.gs.eachKey, style: TextStyle(fontSize: 12, color: m.muted)),
                          ]),
                        ),
                        Icon(Icons.chevron_right_rounded, color: m.muted),
                      ]),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
        child: Text(text.toUpperCase(),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: .8, color: context.mer.muted)),
      );
}

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    return Container(
      decoration: BoxDecoration(color: m.surface, borderRadius: BorderRadius.circular(Meridian.rCard), border: Border.all(color: m.line)),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        for (final (i, c) in children.indexed) ...[
          if (i > 0) Divider(height: 1, color: m.line),
          c,
        ],
      ]),
    );
  }
}

class _Perk extends StatelessWidget {
  const _Perk({required this.icon, required this.color, required this.title, required this.sub});

  final IconData icon;
  final Color color;
  final String title;
  final String sub;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: color.withValues(alpha: .16), borderRadius: BorderRadius.circular(11)),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: m.text)),
            Text(sub, style: TextStyle(fontSize: 12, color: m.muted)),
          ]),
        ),
        Icon(Icons.check_rounded, color: m.good),
      ]),
    );
  }
}

/// How busy a server is, as a ring with the figure inside.
class _BusyRing extends StatelessWidget {
  const _BusyRing({required this.busy});

  static const _size = 44.0;

  final int? busy;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final color = _busyColor(m, busy);
    return SizedBox(
      width: _size,
      height: _size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: (busy ?? 0) / 100),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (_, v, __) => Stack(alignment: Alignment.center, children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: busy == null ? 0 : v.clamp(0.02, 1.0),
              strokeWidth: 5,
              strokeCap: StrokeCap.round,
              color: color,
              backgroundColor: m.surface2,
            ),
          ),
          Text(busy == null ? '--' : '$busy%', style: m.monoStyle(size: 11, color: m.text)),
        ]),
      ),
    );
  }
}

/// Servers that are up first, least busy first: the fastest to use now.
List<GServer> byLoad(List<GServer> servers) => [...servers]
  ..sort((a, b) {
    if (a.online != b.online) return a.online ? -1 : 1;
    return (a.busy ?? 100).compareTo(b.busy ?? 100);
  });

/// One G Server: load ring, ping from this phone, and Connect.
class GServerRow extends ConsumerWidget {
  const GServerRow({super.key, required this.server});

  final GServer server;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.mer;
    final s = server;
    final ping = ref.watch(gServerPingProvider(s.id)).value;
    final connected = _isConnected(ref, s);
    final connecting = ref.watch(vpnProvider).phase == VpnPhase.connecting;
    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => GServerScreen(server: s))),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Row(children: [
          _BusyRing(busy: s.online ? s.busy : null),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                CountryFlag(s.country, width: 20),
                const SizedBox(width: 8),
                Flexible(child: Text(s.city, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: m.text))),
              ]),
              const SizedBox(height: 2),
              Text(
                s.online ? [if (ping != null) '${ping.round()} ms', countryName(s.country, s.country)].join(' · ') : t.gs.offline,
                style: m.monoStyle(size: 12, color: s.online ? m.muted : m.bad),
              ),
            ]),
          ),
          if (connected)
            Tag(t.gs.connected, color: m.good)
          else if (s.online)
            OutlinedButton(
              onPressed: connecting ? null : () => connectGServer(context, ref, s),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                foregroundColor: m.brand,
                side: BorderSide(color: m.brand.withValues(alpha: .5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(t.common.connect, style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
        ]),
      ),
    );
  }
}

/// The best server for this phone now: a gradient card with its load and
/// ping, and one big button.
class _BestCard extends ConsumerWidget {
  const _BestCard({required this.server});

  final GServer server;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.mer;
    final connected = _isConnected(ref, server);
    final busy = ref.watch(vpnProvider).phase == VpnPhase.connecting;
    final ping = ref.watch(gServerPingProvider(server.id)).value;
    const soft = Color(0xFFDCE6FF);
    Widget tile(String label, String value) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: .12), borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              Text(value, style: m.monoStyle(size: 15, color: Colors.white)),
              Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .6, color: soft)),
            ]),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2E57E6), Color(0xFF172A73)],
        ),
        boxShadow: [BoxShadow(color: const Color(0xFF2E57E6).withValues(alpha: .35), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.gs.bestNow, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: soft)),
          const SizedBox(height: 12),
          Row(children: [
            CountryFlag(server.country, width: 48),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(server.city, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
                Text(countryName(server.country, server.country), style: const TextStyle(fontSize: 13, color: soft)),
              ]),
            ),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            tile(t.gs.busyLabel, server.busy == null ? '--' : '${server.busy}%'),
            const SizedBox(width: 6),
            tile(t.gs.ping, ping == null ? '--' : '${ping.round()} ms'),
            const SizedBox(width: 6),
            tile(t.gs.logsShort, t.gs.noneKept),
          ]),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              child: connected
                  ? OutlinedButton(
                      key: const ValueKey('off'),
                      onPressed: () => ref.read(vpnProvider.notifier).disconnect(),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white, width: 1.5),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(t.servers.disconnect, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    )
                  : FilledButton(
                      key: const ValueKey('on'),
                      onPressed: busy ? null : () => connectGServer(context, ref, server),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF1E3FB0),
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(t.common.connect, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One G Server: how busy it is, Connect, and what it knows about this phone.
class GServerScreen extends ConsumerWidget {
  const GServerScreen({super.key, required this.server});

  final GServer server;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.mer;
    final connected = _isConnected(ref, server);
    final busy = ref.watch(vpnProvider).phase == VpnPhase.connecting;
    final mine = ref.watch(tunnelsProvider).value?.gserver;
    final onThis = mine != null && mine.id == '$gserverPrefix${server.id}';
    String? field(String name) =>
        RegExp('^\\s*$name\\s*=\\s*(.+)\$', multiLine: true, caseSensitive: false).firstMatch(mine?.configText ?? '')?.group(1);

    return Scaffold(
      backgroundColor: m.bg,
      appBar: AppBar(backgroundColor: m.bg, surfaceTintColor: Colors.transparent),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          Row(
            children: [
              CountryFlag(server.country, width: 60),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(server.city, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -.4, color: m.text)),
                    Text(t.gs.subtitle(country: countryName(server.country, server.country)), style: TextStyle(fontSize: 14, color: m.muted)),
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
                      onPressed: () => ref.read(vpnProvider.notifier).disconnect(),
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
                      onPressed: busy || !server.online ? null : () => connectGServer(context, ref, server),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(server.online ? t.common.connect : t.gs.offline,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _Tile(
                  t.gs.ping,
                  switch (ref.watch(gPingProvider(server.id))) {
                    AsyncData(:final value) => value == null ? '·' : '$value ms',
                    _ => '…',
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: _Tile(t.gs.busyLabel, server.busy == null ? '·' : '${server.busy}%')),
              const SizedBox(width: 10),
              Expanded(child: _Tile(t.gs.status, server.online ? t.gs.online : t.gs.offline)),
            ],
          ),
          SectionTitle(t.gs.last24),
          _LoadChart(history: server.history),
          SectionTitle(t.gs.onThisServer),
          ListGroup(children: [
            ListItem(title: t.gs.thisPhone, trailing: _Value(onThis ? t.gs.added : t.gs.notAdded)),
            if (onThis && field('Address') != null) ListItem(title: t.details.address, trailing: _Value(field('Address')!, mono: true)),
            if (onThis && field('DNS') != null) ListItem(title: t.details.dns, trailing: _Value(field('DNS')!, mono: true)),
            ListItem(title: t.gs.logs, trailing: _Value(t.gs.noneKept, color: m.good)),
          ]),
          const SizedBox(height: 14),
          Text(t.gs.privacy, style: TextStyle(fontSize: 13, height: 1.5, color: m.muted)),
        ],
      ),
    );
  }
}

/// This plan's phones, with Remove, and how to add one or reinstall.
class GDevicesScreen extends ConsumerWidget {
  const GDevicesScreen({super.key, required this.info});

  final GServersInfo info;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.mer;
    final data = ref.watch(gDevicesProvider);
    final steps = info.proOnly ? [t.gs.stepPro1, t.gs.stepPro2, t.gs.step3] : [t.gs.stepFree1, t.gs.stepFree2, t.gs.step3];
    return Scaffold(
      backgroundColor: m.bg,
      appBar: AppBar(backgroundColor: m.bg, surfaceTintColor: Colors.transparent),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(gDevicesProvider.future),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          children: [
            Text(t.gs.devices, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -.4, color: m.text)),
            const SizedBox(height: 6),
            Text(info.proOnly ? t.gs.devicesIntroPro : t.gs.devicesIntroFree, style: TextStyle(fontSize: 14, height: 1.5, color: m.muted)),
            const SizedBox(height: 16),
            switch (data) {
              AsyncData(:final value) when value != null && value.devices.isNotEmpty => ListGroup(children: [
                  for (final d in value.devices)
                    ListItem(
                      leading: Icon(Icons.smartphone_rounded, color: d.you ? m.good : m.muted),
                      title: d.you ? t.gs.thisPhone : (d.name ?? t.gs.otherPhone),
                      subtitle: d.you ? d.name : t.gs.lastConnected(when: _ago(d.lastSeen)),
                      trailing: d.you
                          ? null
                          : TextButton(
                              onPressed: () async {
                                if (await removeGDevice(d.key)) ref.invalidate(gDevicesProvider);
                              },
                              child: Text(t.common.remove, style: TextStyle(color: m.bad)),
                            ),
                    ),
                ]),
              AsyncLoading() => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
              _ => Text(t.gs.noDevices, style: TextStyle(fontSize: 14, color: m.muted)),
            },
            SectionTitle(t.gs.addTitle),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: m.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: m.line)),
              child: Column(
                children: [
                  for (final (i, step) in steps.indexed)
                    Padding(
                      padding: EdgeInsets.only(bottom: i == steps.length - 1 ? 0 : 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 13,
                            backgroundColor: m.brand,
                            child: Text('${i + 1}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Text(step, style: TextStyle(fontSize: 14, height: 1.5, color: m.text))),
                        ],
                      ),
                    ),
                ],
              ),
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
                  Expanded(child: Text(t.gs.idle(n: info.idleDays), style: TextStyle(fontSize: 13, height: 1.5, color: m.text))),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(t.gs.limitNote(n: info.limit), style: TextStyle(fontSize: 13, color: m.muted)),
          ],
        ),
      ),
    );
  }
}

/// Shown when the plan is full: remove a phone here, then connect again.
class _LimitSheet extends ConsumerStatefulWidget {
  const _LimitSheet({required this.limit, required this.devices});

  final int limit;
  final List<GDevice> devices;

  static Future<bool> show(BuildContext context, int limit, List<GDevice> devices) async =>
      await showModalBottomSheet<bool>(
        context: context,
        showDragHandle: true,
        useSafeArea: true,
        backgroundColor: context.mer.surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        builder: (_) => _LimitSheet(limit: limit, devices: devices),
      ) ??
      false;

  @override
  ConsumerState<_LimitSheet> createState() => _LimitSheetState();
}

class _LimitSheetState extends ConsumerState<_LimitSheet> {
  String? _removing;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t.gs.fullTitle(n: widget.limit), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: m.text)),
          const SizedBox(height: 4),
          Text(t.gs.fullBody, style: TextStyle(fontSize: 14, height: 1.45, color: m.muted)),
          const SizedBox(height: 14),
          ListGroup(children: [
            for (final d in widget.devices)
              ListItem(
                leading: Icon(Icons.smartphone_rounded, color: m.muted),
                title: d.name ?? t.gs.otherPhone,
                subtitle: t.gs.lastConnected(when: _ago(d.lastSeen)),
                trailing: _removing == d.key
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : TextButton(
                        onPressed: () async {
                          setState(() => _removing = d.key);
                          final ok = await removeGDevice(d.key);
                          if (context.mounted) Navigator.pop(context, ok);
                        },
                        child: Text(t.common.remove, style: TextStyle(color: m.bad)),
                      ),
              ),
          ]),
        ],
      ),
    );
  }
}

String _ago(DateTime at) {
  final d = DateTime.now().difference(at);
  if (d.inMinutes < 1) return t.servers.justNow;
  if (d.inHours < 1) return t.servers.minutesAgo(n: d.inMinutes);
  if (d.inDays < 1) return t.servers.hoursAgo(n: d.inHours);
  return t.servers.daysAgo(n: d.inDays);
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
      decoration: BoxDecoration(color: m.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: m.line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .8, color: m.muted)),
          const SizedBox(height: 6),
          Text(value, style: m.monoStyle(size: 20, color: m.text)),
        ],
      ),
    );
  }
}

class _Value extends StatelessWidget {
  const _Value(this.text, {this.mono = false, this.color});

  final String text;
  final bool mono;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 180),
      child: Text(
        text,
        textAlign: TextAlign.end,
        overflow: TextOverflow.ellipsis,
        style: mono
            ? m.monoStyle(size: 13, color: color ?? m.text)
            : TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color ?? m.text),
      ),
    );
  }
}

/// Busy over the last 24 hours, one bar per 15 minutes; the newest in the
/// brand colour. Bars rise in when the page opens.
class _LoadChart extends StatelessWidget {
  const _LoadChart({required this.history});

  final List<int> history;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    return Container(
      height: 110,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(color: m.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: m.line)),
      child: history.isEmpty
          ? Center(child: Text(t.gs.noHistory, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: m.muted)))
          : Column(
              children: [
                Expanded(
                  child: Semantics(
                    label: t.gs.chartLabel(max: history.reduce((a, b) => a > b ? a : b)),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOutCubic,
                      builder: (_, grow, __) => Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (final (i, v) in history.indexed)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: .8),
                                child: FractionallySizedBox(
                                  heightFactor: ((v.clamp(2, 100)) / 100) * grow,
                                  alignment: Alignment.bottomCenter,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: i == history.length - 1 ? m.brand : m.brand.withValues(alpha: .35),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(t.gs.hoursAgo, style: TextStyle(fontSize: 11, color: m.muted)),
                    Text(t.gs.now, style: TextStyle(fontSize: 11, color: m.muted)),
                  ],
                ),
              ],
            ),
    );
  }
}
