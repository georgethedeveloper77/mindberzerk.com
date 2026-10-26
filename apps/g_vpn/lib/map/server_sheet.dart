import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/flag.dart';
import '../design/meridian.dart';
import '../i18n/strings.g.dart';
import '../vpn/tunnel_store.dart';
import '../vpn/vpn_controller.dart';
import 'map_data.dart';

/// Grade label and colour, as the Worker decides them.
(String, Color) gradeOf(String grade, Meridian m) => switch (grade) {
      'fast' => (t.map.grade.fast, m.good),
      'slow' => (t.map.grade.slow, m.warn),
      _ => (t.map.grade.good, m.brand),
    };

String _speed(double mbps) => mbps >= 10 ? mbps.round().toString() : mbps.toStringAsFixed(1);

/// What a marker tap opens: every server in that country, G Servers
/// first, each with Connect, Switch or Disconnect. [onConnected] runs once
/// a connection starts, so the caller can show Home.
Future<void> showServerSheet(BuildContext context, {required CountryServers country, VoidCallback? onConnected}) {
  final m = context.mer;
  // Captured now: the screen that opened the sheet may close on connect.
  final messenger = ScaffoldMessenger.maybeOf(context);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: m.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => _ServerSheet(country: country, messenger: messenger, onConnected: onConnected),
  );
}

class _ServerSheet extends ConsumerWidget {
  const _ServerSheet({required this.country, required this.messenger, required this.onConnected});

  final CountryServers country;
  final ScaffoldMessengerState? messenger;
  final VoidCallback? onConnected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.mer;
    final vpn = ref.watch(vpnProvider);
    final on = vpn.phase == VpnPhase.on;
    final busy = vpn.phase == VpnPhase.connecting || vpn.phase == VpnPhase.disconnecting;
    final current = on ? vpn.tunnelId : null;
    final counts = [
      if (country.gservers.isNotEmpty) t.map.gServers(n: country.gservers.length),
      if (country.servers.isNotEmpty) t.map.freeServers(n: country.servers.length),
    ].join(' · ');

    /// Closes the sheet, starts [connect], and hands over to the caller.
    void go(Future<void> Function() connect) {
      final started = connect();
      Navigator.of(context).pop();
      onConnected?.call();
      unawaited(started);
    }

    void disconnect() {
      unawaited(ref.read(vpnProvider.notifier).disconnect());
      Navigator.of(context).pop();
    }

    _Action actionFor(String id) => current == id
        ? _Action.disconnect
        : on
            ? _Action.switchTo
            : _Action.connect;

    final rows = <Widget>[
      for (final g in country.gservers)
        _Row(
          leading: _Badge(text: 'G', color: m.good),
          title: g.city.isEmpty ? g.name : g.city,
          detail: [
            'G Server',
            'WireGuard',
            if (g.busy != null) t.gs.busy(n: g.busy!),
          ].join(' · '),
          action: actionFor('$gserverPrefix${g.id}'),
          enabled: !busy,
          onConnect: () => go(() => connectGServerFromMap(ref, g, messenger)),
          onDisconnect: disconnect,
        ),
      for (final (i, s) in country.servers.indexed)
        _Row(
          leading: _Badge(text: '${i + 1}', color: m.muted),
          title: t.map.freeServer(n: i + 1),
          detail: [
            if (s.speedMbps > 0) '${_speed(s.speedMbps)} Mbps',
            s.sstpHost != null ? 'SSTP' : 'OpenVPN ${s.proto.toUpperCase()}',
            if (s.pingMs > 0) '${s.pingMs} ms',
          ].join(' · '),
          grade: gradeOf(s.grade, m),
          best: i == 0 && country.gservers.isEmpty,
          action: actionFor('$communityPrefix${s.id}'),
          enabled: !busy,
          onConnect: () => go(() => connectCommunity(ref, s)),
          onDisconnect: disconnect,
        ),
    ];

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .78),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
            child: Row(
              children: [
                CountryFlag(country.code, width: 40),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        country.name,
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -.4, color: m.text),
                      ),
                      Text(counts, style: TextStyle(fontSize: 13, color: m.muted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.paddingOf(context).bottom),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => rows[i],
            ),
          ),
        ],
      ),
    );
  }
}

enum _Action { connect, switchTo, disconnect }

/// One server: what it is, how it performs, and the one action that fits.
class _Row extends StatelessWidget {
  const _Row({
    required this.leading,
    required this.title,
    required this.detail,
    required this.action,
    required this.enabled,
    required this.onConnect,
    required this.onDisconnect,
    this.grade,
    this.best = false,
  });

  final Widget leading;
  final String title;
  final String detail;
  final _Action action;
  final bool enabled;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;
  final (String, Color)? grade;
  final bool best;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final current = action == _Action.disconnect;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
      decoration: BoxDecoration(
        color: current ? m.good.withValues(alpha: .10) : m.surface2,
        borderRadius: BorderRadius.circular(Meridian.rTile),
        border: Border.all(color: current ? m.good.withValues(alpha: .45) : m.surface2),
      ),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: m.text)),
                    if (best) _Pill(text: t.map.best, color: m.brand),
                    if (current) _Pill(text: t.common.connected, color: m.good),
                    if (grade != null && !current) _Pill(text: grade!.$1, color: grade!.$2),
                  ],
                ),
                const SizedBox(height: 3),
                Text(detail, style: m.monoStyle(size: 12, color: m.muted)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 44,
            child: switch (action) {
              _Action.disconnect => OutlinedButton(
                  onPressed: enabled ? onDisconnect : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: m.bad,
                    side: BorderSide(color: m.bad.withValues(alpha: .55), width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(fontFamily: Meridian.sans, fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                  child: Text(t.servers.disconnect),
                ),
              _ => FilledButton(
                  onPressed: enabled ? onConnect : null,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(96, 44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(fontFamily: Meridian.sans, fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                  child: Text(action == _Action.switchTo ? t.map.switchTo : t.common.connect),
                ),
            },
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color.withValues(alpha: .14), borderRadius: BorderRadius.circular(11)),
        child: Text(text, style: context.mer.monoStyle(size: 13, weight: FontWeight.w600, color: color)),
      );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: .14), borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
      );
}
