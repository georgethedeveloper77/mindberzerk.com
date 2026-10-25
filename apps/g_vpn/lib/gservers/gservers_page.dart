import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/appear.dart';
import '../design/countries.dart';
import '../design/flag.dart';
import '../design/list_ui.dart';
import '../design/meridian.dart';
import '../i18n/strings.g.dart';
import '../pro/billing.dart';
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

/// The Pro tab when G Servers are on: the least busy server, all servers,
/// and this plan's phones.
class GServersPage extends ConsumerWidget {
  const GServersPage({super.key, required this.info});

  final GServersInfo info;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.mer;
    final best = info.best;
    final owned = ref.watch(billingProvider).owned;
    return Scaffold(
      backgroundColor: m.bg,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(gServersProvider.future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(t.pro.title, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -.5, color: m.text)),
                  ),
                  if (owned) Tag(t.gs.active, color: m.good),
                ],
              ),
              const SizedBox(height: 16),
              if (best != null) Appear(index: 0, child: _BestCard(server: best)),
              SectionTitle(t.gs.servers),
              Appear(
                index: 1,
                child: ListGroup(children: [
                  for (final s in info.servers)
                    ListItem(
                      leading: CountryFlag(s.country, width: 30),
                      title: '${countryName(s.country, s.country)} · ${s.city}',
                      subtitle: s.online ? t.gs.busy(n: s.busy ?? 0) : t.gs.offline,
                      trailing: _BusyBar(busy: s.online ? s.busy : null),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => GServerScreen(server: s))),
                    ),
                ]),
              ),
              const SizedBox(height: 14),
              Appear(
                index: 2,
                child: ListGroup(children: [
                  ListItem(
                    leading: Icon(Icons.smartphone_rounded, color: m.brand),
                    title: t.gs.devices,
                    subtitle: t.gs.devicesSub(n: info.limit),
                    trailing: Icon(Icons.chevron_right_rounded, color: m.muted),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => GDevicesScreen(info: info))),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              Text(t.gs.footnote, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, height: 1.5, color: m.muted)),
            ],
          ),
        ),
      ),
    );
  }
}

class _BestCard extends ConsumerWidget {
  const _BestCard({required this.server});

  final GServer server;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.mer;
    final connected = _isConnected(ref, server);
    final busy = ref.watch(vpnProvider).phase == VpnPhase.connecting;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: m.brand, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.gs.leastBusy, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .8, color: Color(0xFFDCE6FF))),
          const SizedBox(height: 12),
          Row(
            children: [
              CountryFlag(server.country, width: 44),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(server.city, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                    Text(t.gs.busyNoLogs(n: server.busy ?? 0), style: m.monoStyle(size: 13, color: const Color(0xFFDCE6FF))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              child: connected
                  ? OutlinedButton(
                      key: const ValueKey('off'),
                      onPressed: () => ref.read(vpnProvider.notifier).disconnect(),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white, width: 1.5),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(t.servers.disconnect, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    )
                  : FilledButton(
                      key: const ValueKey('on'),
                      onPressed: busy ? null : () => connectGServer(context, ref, server),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF1E3FB0),
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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

class _BusyBar extends StatelessWidget {
  const _BusyBar({required this.busy});

  final int? busy;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final value = (busy ?? 0) / 100;
    final color = busy == null ? m.muted : busy! >= 85 ? m.bad : busy! >= 60 ? m.warn : m.good;
    return SizedBox(
      width: 64,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          builder: (_, v, __) => LinearProgressIndicator(value: v, minHeight: 6, backgroundColor: m.line, color: color),
        ),
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
              Expanded(child: _Tile(t.gs.busyLabel, server.busy == null ? '·' : '${server.busy}%')),
              const SizedBox(width: 10),
              Expanded(child: _Tile(t.gs.status, server.online ? t.gs.online : t.gs.offline)),
            ],
          ),
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
