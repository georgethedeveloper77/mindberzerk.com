import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/countries.dart';
import '../design/flag.dart';
import '../design/meridian.dart';
import '../design/meridian_widgets.dart';
import '../design/sheet.dart';
import '../i18n/strings.g.dart';
import '../rules/rules_store.dart';
import '../servers/community.dart';
import '../vpn/tunnel_store.dart';
import '../vpn/vpn_controller.dart';
import 'home_scan.dart';

/// How many distinct countries the "picked from" row looks across.
const _pickedFromDepth = 12;

/// The one connect action Home offers, from the card and the IP sheet:
/// resume a pause, else connect the selected server, else the free server
/// the Worker ranks best right now. With nothing to connect to, it opens
/// Servers.
Future<void> connectFromHome(WidgetRef ref, {required VoidCallback openServers}) async {
  final vpn = ref.read(vpnProvider);
  final controller = ref.read(vpnProvider.notifier);
  if (vpn.pausedUntil != null) return controller.resume();
  if (vpn.phase != VpnPhase.off) return;

  final choice = ref.read(tunnelsProvider).value?.choice;
  if (choice != null) return controller.connect(choice);

  final best = ref.read(communityProvider).value?.servers.firstOrNull;
  if (best == null) {
    openServers();
    return;
  }
  await ref.read(tunnelsProvider.notifier).selectCommunity(best);
  await controller.connect(CommunityChoice(best));
}

/// Protocol label for a choice, shared by both card states.
String protocolOf(ServerChoice choice) => switch (choice) {
      OwnServer() => t.home.card.wireguard,
      CommunityChoice(:final server) =>
        server.sstpHost != null ? 'SSTP' : t.home.card.openvpn(proto: server.proto.toUpperCase()),
    };

/// Home's main card. Ready: what Connect will do. Protected: where the
/// traffic comes out, with Disconnect and Change.
class HomeConnectCard extends ConsumerWidget {
  const HomeConnectCard({super.key, required this.openServers});

  final VoidCallback openServers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vpn = ref.watch(vpnProvider);
    final choice = ref.watch(tunnelsProvider).value?.choice;
    if (vpn.phase == VpnPhase.on && choice != null) {
      return _ProtectedCard(choice: choice, vpn: vpn, openServers: openServers);
    }
    return _ReadyCard(choice: choice, phase: vpn.phase, openServers: openServers);
  }
}

class _ReadyCard extends ConsumerWidget {
  const _ReadyCard({required this.choice, required this.phase, required this.openServers});

  final ServerChoice? choice;
  final VpnPhase phase;
  final VoidCallback openServers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.mer;
    final c = choice;
    final community = ref.watch(communityProvider);
    final busy = phase == VpnPhase.connecting || phase == VpnPhase.disconnecting;
    final fastest = c == null;
    final failed = fastest && community.hasError && !community.hasValue;
    final waiting = fastest && !community.hasValue && !failed;

    final VoidCallback? onPressed = busy || waiting
        ? null
        : failed
            ? () => ref.invalidate(communityProvider)
            : () => connectFromHome(ref, openServers: openServers);

    return MerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _Badge(
                child: c == null
                    ? Icon(Icons.bolt_rounded, color: m.brand)
                    : c.countryCode != null
                        ? CountryFlag(c.countryCode!, width: 26)
                        : Icon(Icons.dns_outlined, color: m.brand),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!fastest) _Label(t.home.card.selected),
                    Text(
                      c == null ? t.home.fastest.title : c.name,
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: m.text),
                    ),
                    const SizedBox(height: 3),
                    if (c == null)
                      _PickedFrom(community: community, failed: failed)
                    else
                      Text(protocolOf(c), style: TextStyle(fontSize: 13, color: m.muted)),
                  ],
                ),
              ),
              if (fastest)
                IconButton(
                  tooltip: t.home.fastest.how,
                  icon: Icon(Icons.info_outline_rounded, color: m.muted),
                  onPressed: () => showInfoSheet(
                    context,
                    icon: Icons.bolt_rounded,
                    title: t.home.fastest.title,
                    sections: [SheetSection.text(t.home.fastest.how, t.home.fastest.sheetBody)],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 56,
            child: FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                textStyle: const TextStyle(fontFamily: Meridian.sans, fontSize: 17, fontWeight: FontWeight.w800),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (busy || waiting)
                    SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: m.muted))
                  else
                    Icon(failed ? Icons.refresh_rounded : Icons.power_settings_new_rounded, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    busy
                        ? (phase == VpnPhase.connecting ? t.home.status.connecting : t.home.status.stopping)
                        : waiting
                            ? t.home.fastest.finding
                            : failed
                                ? t.common.retry
                                : t.common.connect,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Align(alignment: Alignment.centerRight, child: MerAction(t.home.pickServer, onPressed: openServers)),
        ],
      ),
    );
  }
}

/// "Picked from" and the flags of the best-ranked countries.
class _PickedFrom extends StatelessWidget {
  const _PickedFrom({required this.community, required this.failed});

  final AsyncValue<CommunityList> community;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    if (failed) return Text(t.home.fastest.failed, style: TextStyle(fontSize: 13, color: m.bad));
    final servers = community.value?.servers ?? const [];
    final codes = <String>{for (final s in servers.take(_pickedFromDepth * 4)) s.countryCode.toUpperCase()}
        .take(_pickedFromDepth)
        .toList();
    if (codes.isEmpty) return Text(t.home.fastest.finding, style: TextStyle(fontSize: 13, color: m.muted));
    final shown = codes.take(3).toList();
    return Row(
      children: [
        Text(t.home.fastest.pickedFrom, style: TextStyle(fontSize: 13, color: m.muted)),
        for (final code in shown) ...[const SizedBox(width: 6), CountryFlag(code, width: 18)],
        if (codes.length > shown.length) ...[
          const SizedBox(width: 6),
          Text(t.home.fastest.more(n: codes.length - shown.length),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: m.muted)),
        ],
      ],
    );
  }
}

class _ProtectedCard extends ConsumerWidget {
  const _ProtectedCard({required this.choice, required this.vpn, required this.openServers});

  final ServerChoice choice;
  final VpnState vpn;
  final VoidCallback openServers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.mer;
    final shield = ref.watch(rulesProvider.select((r) => r.value?.shield ?? true));
    final id = ref.watch(identityProvider).value;
    final code = choice.countryCode ?? (id?.country?.length == 2 ? id!.country : null);
    final country = code == null ? null : countryName(code, code);
    final place = [id?.city, country].whereType<String>().where((s) => s.isNotEmpty).join(', ');

    return MerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _Badge(
                color: m.good.withValues(alpha: .12),
                child: code != null ? CountryFlag(code, width: 26) : Icon(Icons.dns_outlined, color: m.good),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Label(t.home.card.browsingFrom),
                    Text(
                      place.isEmpty ? choice.name : place,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: m.text),
                    ),
                    const SizedBox(height: 2),
                    Text('${choice.name} · ${protocolOf(choice)}', style: m.monoStyle(size: 12, color: m.muted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: vpn.phase == VpnPhase.on ? () => ref.read(vpnProvider.notifier).disconnect() : null,
                    icon: const Icon(Icons.power_settings_new_rounded, size: 18),
                    label: Text(t.home.card.disconnect),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: m.bad,
                      side: BorderSide(color: m.bad.withValues(alpha: .55), width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      textStyle: const TextStyle(fontFamily: Meridian.sans, fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: openServers,
                    icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                    label: Text(t.home.card.change),
                    style: FilledButton.styleFrom(
                      backgroundColor: m.surface2,
                      foregroundColor: m.text,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      textStyle: const TextStyle(fontFamily: Meridian.sans, fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _Stat(label: t.home.card.downloaded, value: formatBytes(vpn.rxBytes), mono: true)),
              const SizedBox(width: 8),
              Expanded(child: _Stat(label: t.home.card.uploaded, value: formatBytes(vpn.txBytes), mono: true)),
              const SizedBox(width: 8),
              Expanded(
                child: _Stat(
                  label: t.home.card.shield,
                  value: shield ? t.home.card.enabled : t.common.off,
                  color: shield ? m.good : m.muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Bytes as KB, MB or GB.
String formatBytes(int b) {
  if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
  if (b < 1024 * 1024 * 1024) return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
  return '${(b / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

class _Badge extends StatelessWidget {
  const _Badge({required this.child, this.color});

  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
        width: 46,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color ?? context.mer.brandSoft,
          borderRadius: BorderRadius.circular(14),
        ),
        child: child,
      );
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Text(
          text,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: .6, color: context.mer.muted),
        ),
      );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.mono = false, this.color});

  final String label;
  final String value;
  final bool mono;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final fg = color ?? m.text;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(color: m.surface2, borderRadius: BorderRadius.circular(Meridian.rChip)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: .4, color: m.muted)),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              softWrap: false,
              style: mono
                  ? m.monoStyle(size: 14, color: fg)
                  : TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: fg),
            ),
          ),
        ],
      ),
    );
  }
}
