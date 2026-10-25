import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../design/meridian.dart';
import '../i18n/strings.g.dart';
import '../vpn/tunnel_store.dart';
import '../vpn/vpn_controller.dart';
import 'probe.dart';
import 'tool_widgets.dart';

/// A service and the host that answers for it.
class Service {
  const Service(this.name, this.host, this.icon, this.color);

  final String name;
  final String host;
  final IconData icon;

  /// Tile colour: close to the service's own, so it is found at a glance.
  final Color color;
}

/// Chosen for what people check when "the internet is down" or a service
/// is blocked: messaging first, then the big platforms.
const services = [
  Service('WhatsApp', 'g.whatsapp.net', Icons.chat_rounded, Color(0xFF1F9D55)),
  Service('Telegram', 'api.telegram.org', Icons.send_rounded, Color(0xFF2A9DD8)),
  Service('Instagram', 'www.instagram.com', Icons.photo_camera_outlined, Color(0xFFE1306C)),
  Service('YouTube', 'www.youtube.com', Icons.smart_display_outlined, Color(0xFFD92B2B)),
  Service('Google', 'www.google.com', Icons.search_rounded, Color(0xFF3B6FE0)),
  Service('Gmail', 'mail.google.com', Icons.mail_outline_rounded, Color(0xFFC5372C)),
  Service('X', 'x.com', Icons.alternate_email_rounded, Color(0xFF1A1A1A)),
  Service('TikTok', 'www.tiktok.com', Icons.music_note_rounded, Color(0xFF111111)),
  Service('Netflix', 'www.netflix.com', Icons.movie_outlined, Color(0xFFB20710)),
  Service('Cloudflare', '1.1.1.1', Icons.cloud_outlined, Color(0xFFE8790C)),
];

class ServiceResult {
  const ServiceResult(this.service, this.samples);

  final Service service;
  final List<double?> samples;

  double? get best {
    final ok = samples.whereType<double>();
    return ok.isEmpty ? null : ok.reduce((a, b) => a < b ? a : b);
  }
}

/// Three handshakes per service, all services in parallel. Re-run by
/// invalidating; re-runs on its own when the VPN state changes, so the
/// before/after comparison is one tap away.
final serviceStatusProvider = FutureProvider.autoDispose<List<ServiceResult>>((ref) async {
  ref.watch(vpnProvider.select((s) => s.phase == VpnPhase.on));
  return pooled(services, 5, (s) async {
    final samples = <double?>[];
    for (var i = 0; i < 3; i++) {
      samples.add(await tcpPing(s.host, 443, timeout: const Duration(seconds: 4), refusedCounts: false));
    }
    return ServiceResult(s, samples);
  });
});


/// Every check this phone ran in the last 24 hours, newest first: the
/// service name and its best handshake (null when unreachable).
class StatusCheck {
  const StatusCheck(this.at, this.viaVpn, this.results);

  final DateTime at;
  final bool viaVpn;
  final Map<String, double?> results;
}

final statusHistoryProvider = AsyncNotifierProvider<StatusHistory, List<StatusCheck>>(StatusHistory.new);

class StatusHistory extends AsyncNotifier<List<StatusCheck>> {
  static const _key = 'gvpn.status_history.v1';
  static const _window = Duration(hours: 24);

  @override
  Future<List<StatusCheck>> build() async {
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    if (raw == null) return const [];
    try {
      final cutoff = DateTime.now().subtract(_window);
      return [
        for (final e in jsonDecode(raw) as List)
          if (e is Map && e['t'] is int)
            StatusCheck(
              DateTime.fromMillisecondsSinceEpoch(e['t'] as int),
              e['v'] == true,
              {for (final r in (e['r'] as Map).entries) r.key as String: (r.value as num?)?.toDouble()},
            ),
      ].where((c) => c.at.isAfter(cutoff)).toList();
    } on Object {
      return const [];
    }
  }

  Future<void> add(List<ServiceResult> results, bool viaVpn) async {
    final check = StatusCheck(DateTime.now(), viaVpn, {for (final r in results) r.service.name: r.best});
    final cutoff = DateTime.now().subtract(_window);
    final next = [check, ...(state.value ?? const <StatusCheck>[])].where((c) => c.at.isAfter(cutoff)).take(200).toList();
    state = AsyncData(next);
    await (await SharedPreferences.getInstance()).setString(
      _key,
      jsonEncode([
        for (final c in next) {'t': c.at.millisecondsSinceEpoch, 'v': c.viaVpn, 'r': c.results},
      ]),
    );
  }
}

/// Up to four services shown as tiles; the rest are listed below.
final favouriteServicesProvider = AsyncNotifierProvider<FavouriteServices, List<String>>(FavouriteServices.new);

class FavouriteServices extends AsyncNotifier<List<String>> {
  static const _key = 'gvpn.status_favourites.v1';
  static const max = 4;

  @override
  Future<List<String>> build() async =>
      (await SharedPreferences.getInstance()).getStringList(_key) ?? const ['WhatsApp', 'YouTube', 'Telegram', 'Gmail'];

  Future<void> toggle(String name) async {
    final current = [...?state.value];
    if (!current.remove(name)) {
      if (current.length >= max) current.removeAt(0);
      current.add(name);
    }
    state = AsyncData(current);
    await (await SharedPreferences.getInstance()).setStringList(_key, current);
  }
}

class StatusScreen extends ConsumerWidget {
  const StatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.mer;
    final results = ref.watch(serviceStatusProvider);
    final viaVpn = ref.watch(vpnProvider.select((s) => s.phase)) == VpnPhase.on;
    final favNames = ref.watch(favouriteServicesProvider).value ?? const <String>[];
    final history = ref.watch(statusHistoryProvider).value ?? const <StatusCheck>[];

    // Every completed check is kept for the 24-hour strips.
    ref.listen(serviceStatusProvider, (prev, next) {
      if (next case AsyncData(:final value) when !identical(prev?.value, value)) {
        ref.read(statusHistoryProvider.notifier).add(value, viaVpn);
      }
    });

    final list = results.value ?? const <ServiceResult>[];
    final byName = {for (final r in list) r.service.name: r};
    final blocked = list.where((r) => r.best == null).toList();
    final favs = [for (final s in services) if (favNames.contains(s.name)) s];

    return ToolPage(
      title: t.status.title,
      info: t.status.info,
      action: FilledButton(
        onPressed: results.isLoading ? null : () => ref.invalidate(serviceStatusProvider),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        child: Text(results.isLoading ? t.status.checking : t.status.again),
      ),
      children: [
        Text(viaVpn ? t.status.viaVpn : t.status.direct,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: viaVpn ? m.good : m.muted)),
        const SizedBox(height: 10),
        if (blocked.isNotEmpty) ...[
          _BlockedBanner(names: [for (final b in blocked) b.service.name], viaVpn: viaVpn),
          const SizedBox(height: 16),
        ],
        Row(
          children: [
            Text(t.status.favourites, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: m.text)),
            const Spacer(),
            TextButton(onPressed: () => _editFavourites(context, ref), child: Text(t.status.edit)),
          ],
        ),
        Row(
          children: [
            for (final (i, s) in favs.indexed) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(child: _FavTile(service: s, result: byName[s.name], loading: results.isLoading)),
            ],
            for (var i = favs.length; i < FavouriteServices.max; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              const Expanded(child: SizedBox()),
            ],
          ],
        ),
        if (favs.isNotEmpty && history.isNotEmpty) ...[
          const SizedBox(height: 20),
          Row(
            children: [
              Text(t.status.last24, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: m.text)),
              const Spacer(),
              Text(t.status.checks(n: history.length), style: TextStyle(fontSize: 12, color: m.muted)),
            ],
          ),
          const SizedBox(height: 10),
          ToolCard(
            child: Column(
              children: [
                for (final (i, s) in favs.indexed) ...[
                  if (i > 0) const SizedBox(height: 14),
                  _Strip(name: s.name, history: history),
                ],
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(t.status.ago, style: TextStyle(fontSize: 11, color: m.muted)),
                    Text(t.status.now, style: TextStyle(fontSize: 11, color: m.muted)),
                  ],
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        Text(t.status.all, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: m.text)),
        const SizedBox(height: 10),
        ToolCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Column(
            children: [
              for (final (i, s) in services.indexed) ...[
                if (i > 0) Divider(height: 1, color: m.line),
                _ServiceLine(service: s, result: byName[s.name], loading: results.isLoading),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _editFavourites(BuildContext context, WidgetRef ref) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        backgroundColor: context.mer.surface,
        builder: (c) => Consumer(
          builder: (c, ref, _) {
            final m = c.mer;
            final favs = ref.watch(favouriteServicesProvider).value ?? const <String>[];
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.status.favourites, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: m.text)),
                    Text(t.status.pickFour, style: TextStyle(fontSize: 15, color: m.muted)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final s in services)
                          FilterChip(
                            avatar: Icon(s.icon, size: 18, color: favs.contains(s.name) ? Colors.white : s.color),
                            label: Text(s.name),
                            selected: favs.contains(s.name),
                            onSelected: (_) => ref.read(favouriteServicesProvider.notifier).toggle(s.name),
                            showCheckmark: false,
                            selectedColor: s.color,
                            labelStyle: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: favs.contains(s.name) ? Colors.white : m.text,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
}

class _BlockedBanner extends ConsumerWidget {
  const _BlockedBanner({required this.names, required this.viaVpn});

  final List<String> names;
  final bool viaVpn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.mer;
    final choice = ref.watch(tunnelsProvider).value?.choice;
    final who = names.length == 1 ? names.first : t.status.andMore(first: names.first, n: names.length - 1);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: m.badSoft, borderRadius: BorderRadius.circular(Meridian.rCard)),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: m.surface, borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.block_rounded, color: m.bad),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.status.notReachable(who: who), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: m.bad)),
                Text(viaVpn ? t.status.outage : t.status.blocked,
                    style: TextStyle(fontSize: 13, color: m.bad)),
              ],
            ),
          ),
          if (!viaVpn && choice != null)
            FilledButton(
              onPressed: () => ref.read(vpnProvider.notifier).connect(choice),
              style: FilledButton.styleFrom(backgroundColor: m.bad, minimumSize: const Size(0, 44)),
              child: Text(t.status.connect),
            ),
        ],
      ),
    );
  }
}

class _FavTile extends StatelessWidget {
  const _FavTile({required this.service, required this.result, required this.loading});

  final Service service;
  final ServiceResult? result;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final best = result?.best;
    final (dot, line) = result == null || loading
        ? (m.line, '...')
        : best == null
            ? (m.bad, t.status.blockedShort)
            : best > 400
                ? (m.warn, '${best.round()} ms')
                : (m.good, '${best.round()} ms');
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        color: m.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: dot == m.bad ? m.bad.withValues(alpha: .45) : m.line, width: dot == m.bad ? 2 : 1),
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: service.color, borderRadius: BorderRadius.circular(12)),
                child: Icon(service.icon, color: Colors.white, size: 22),
              ),
              Positioned(
                right: -3,
                bottom: -3,
                child: Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(color: dot, shape: BoxShape.circle, border: Border.all(color: m.surface, width: 2)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(service.name, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: m.text)),
          Text(line, style: m.monoStyle(size: 11, color: dot == m.line ? m.muted : dot)),
        ],
      ),
    );
  }
}

/// Twelve two-hour slots: green when every check answered, amber when one
/// was slow, red when one failed, empty when nothing was checked.
class _Strip extends StatelessWidget {
  const _Strip({required this.name, required this.history});

  final String name;
  final List<StatusCheck> history;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final now = DateTime.now();
    final slots = List<Color?>.filled(12, null);
    var ok = 0, total = 0;
    for (final c in history) {
      if (!c.results.containsKey(name)) continue;
      final age = now.difference(c.at).inMinutes;
      final slot = 11 - (age ~/ 120);
      if (slot < 0 || slot > 11) continue;
      final ms = c.results[name];
      total++;
      if (ms != null) ok++;
      final colour = ms == null ? m.bad : ms > 400 ? m.warn : m.good;
      final current = slots[slot];
      // The worst result in a slot wins.
      if (current == null || colour == m.bad || (colour == m.warn && current == m.good)) slots[slot] = colour;
    }
    final pct = total == 0 ? null : (ok * 100 / total).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: m.text)),
            const Spacer(),
            if (pct != null)
              Text('$pct%', style: m.monoStyle(size: 13, color: pct == 100 ? m.good : pct >= 80 ? m.warn : m.bad)),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (var i = 0; i < 12; i++) ...[
              if (i > 0) const SizedBox(width: 3),
              Expanded(
                child: Container(
                  height: 18,
                  decoration: BoxDecoration(color: slots[i] ?? m.surface2, borderRadius: BorderRadius.circular(3)),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _ServiceLine extends StatelessWidget {
  const _ServiceLine({required this.service, required this.result, required this.loading});

  final Service service;
  final ServiceResult? result;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final best = result?.best;
    final (text, color) = result == null || loading
        ? ('...', m.muted)
        : best == null
            ? (t.status.unreachable, m.bad)
            : ('${best.round()} ms', best > 400 ? m.warn : m.good);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(service.icon, size: 20, color: service.color),
          const SizedBox(width: 12),
          Expanded(child: Text(service.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: m.text))),
          Text(text, style: m.monoStyle(size: 13, color: color)),
        ],
      ),
    );
  }
}
