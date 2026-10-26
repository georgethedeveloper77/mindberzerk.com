import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../design/countries.dart';
import '../design/meridian.dart';
import '../design/meridian_widgets.dart';
import '../design/sheet.dart';
import '../home/home_scan.dart';
import '../i18n/strings.g.dart';
import '../providers/provider_api.dart';
import '../tools/tool_widgets.dart';
import '../vpn/tunnel_store.dart';
import '../vpn/vpn_controller.dart';
import 'blocked_check.dart';

/// The tool's own colour: orange, so "blocked" can stay red.
const blockedTone = Color(0xFFF97316);

String kindName(SiteKind k) => switch (k) {
      SiteKind.social => t.blocked.kinds.social,
      SiteKind.messaging => t.blocked.kinds.messaging,
      SiteKind.news => t.blocked.kinds.news,
      SiteKind.video => t.blocked.kinds.video,
      SiteKind.privacy => t.blocked.kinds.privacy,
    };

(String, Color) blockLook(Block b, Meridian m) => switch (b) {
      Block.dns => (t.blocked.how.dns, m.violet),
      Block.reset => (t.blocked.how.reset, m.bad),
      Block.timeout => (t.blocked.how.timeout, m.warn),
      Block.page => (t.blocked.how.page, blockedTone),
      _ => (t.blocked.how.open, m.good),
    };

String failureText(ProbeStep s) => switch (s.failure) {
      Failure.noAnswer => t.blocked.fail.noAnswer,
      Failure.refused => t.blocked.fail.refused,
      Failure.cutOff => t.blocked.fail.cutOff(s: (s.after ?? 0).toStringAsFixed(1)),
      Failure.wrongCertificate => t.blocked.fail.wrongCert,
      null => s.detail,
    };

/// A site's letter on a steady colour of its own.
class SiteBadge extends StatelessWidget {
  const SiteBadge({super.key, required this.host, this.size = 38});

  final String host;
  final double size;

  @override
  Widget build(BuildContext context) {
    const palette = [Color(0xFF3A76F0), Color(0xFFE4572E), Color(0xFF2A9D8F), Color(0xFF7B2CBF), Color(0xFFE76F51), Color(0xFF264653), Color(0xFFBB1919)];
    final c = palette[host.codeUnits.fold(0, (h, u) => (h * 31 + u) & 0x7fffffff) % palette.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(size * .3)),
      child: Text(host[0].toUpperCase(), style: TextStyle(fontSize: size * .42, fontWeight: FontWeight.w800, color: Colors.white)),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: .15), borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
      );
}

/// Tools › What's blocked.
class BlockedScreen extends ConsumerStatefulWidget {
  const BlockedScreen({super.key});

  @override
  ConsumerState<BlockedScreen> createState() => _BlockedScreenState();
}

class _BlockedScreenState extends ConsumerState<BlockedScreen> {
  bool _country = false;

  /// The network being tested, by the name people know it by.
  String _networkName() {
    final p = ref.read(myProviderProvider).value;
    if (p != null && !p.cached) return p.profile.name;
    return ref.read(networkScanProvider).value?.name ?? t.blocked.thisNetwork;
  }

  /// First test only: what the test does, and that it can be noticed.
  Future<bool> _consent() async {
    final prefs = await SharedPreferences.getInstance();
    const key = 'gvpn.blocked.consented.v1';
    if (prefs.getBool(key) ?? false) return true;
    if (!mounted) return false;
    var ok = false;
    await showInfoSheet(
      context,
      icon: Icons.block_rounded,
      color: blockedTone,
      title: t.blocked.consent.title,
      subtitle: t.blocked.consent.body,
      sections: [SheetSection(Icons.visibility_outlined, t.blocked.consent.noticeTitle, t.blocked.consent.notice, tone: blockedTone)],
      button: t.blocked.consent.ok,
      onButton: () => ok = true,
    );
    if (ok) await prefs.setBool(key, true);
    return ok;
  }

  Future<void> _start() async {
    if (!await _consent()) return;
    await ref.read(blockedProvider.notifier).start(network: _networkName());
  }

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final s = ref.watch(blockedProvider);
    final vpnOn = ref.watch(vpnProvider.select((v) => v.phase)) == VpnPhase.on;
    final cc = ref.watch(myProviderProvider).value?.country;

    final Widget? action = _country
        ? null
        : switch (s.phase) {
            TestPhase.running => OutlinedButton(
                onPressed: ref.read(blockedProvider.notifier).stop,
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52), foregroundColor: m.text, side: BorderSide(color: m.line)),
                child: Text(t.blocked.stop),
              ),
            TestPhase.idle when vpnOn => FilledButton.icon(
                onPressed: () => ref.read(vpnProvider.notifier).disconnect(),
                icon: const Icon(Icons.power_settings_new_rounded),
                label: Text(t.blocked.turnOff),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
              ),
            TestPhase.idle => FilledButton.icon(
                onPressed: s.kinds.isEmpty ? null : _start,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(t.blocked.test),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
              ),
            TestPhase.done => _DoneActions(vpnOn: vpnOn),
          };

    return ToolPage(
      title: t.blocked.title,
      icon: Icons.block_rounded,
      color: blockedTone,
      info: t.blocked.info,
      action: action,
      children: [
        // This network | the country.
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: m.surface, borderRadius: BorderRadius.circular(15), border: Border.all(color: m.line)),
          child: Row(children: [
            for (final (country, label) in [(false, t.blocked.thisNetwork), (true, cc == null ? t.blocked.country : countryName(cc, cc))])
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => _country = country),
                  child: Container(
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: _country == country ? m.surface2 : null, borderRadius: BorderRadius.circular(12)),
                    child: Text(label,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _country == country ? m.text : m.muted)),
                  ),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 14),
        if (_country)
          const _CountryView()
        else
          switch (s.phase) {
            TestPhase.idle => _Start(network: _networkName(), vpnOn: vpnOn),
            TestPhase.running => _Running(state: s),
            TestPhase.done => _Results(state: s),
          },
      ],
    );
  }
}

// ── Start ───────────────────────────────────────────────────────────────

class _Start extends ConsumerWidget {
  const _Start({required this.network, required this.vpnOn});

  final String network;
  final bool vpnOn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.mer;
    final s = ref.watch(blockedProvider);
    final count = [for (final k in s.kinds) ...testSites[k]!].length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Center(
        child: SizedBox(
          width: 150,
          height: 120,
          child: CustomPaint(painter: _RingPainter(m: m)),
        ),
      ),
      const SizedBox(height: 6),
      Text(t.blocked.question, textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: m.text)),
      const SizedBox(height: 14),
      _NetworkCard(network: network, vpnOn: vpnOn),
      ToolHeading(t.blocked.sitesToTest(n: count)),
      MerCard(
        padding: EdgeInsets.zero,
        child: Column(children: [
          for (final (i, k) in SiteKind.values.indexed) ...[
            if (i > 0) Divider(height: 1, color: m.line),
            CheckboxListTile(
              value: s.kinds.contains(k),
              onChanged: (v) {
                final next = {...s.kinds};
                v == true ? next.add(k) : next.remove(k);
                ref.read(blockedProvider.notifier).setKinds(next);
              },
              activeColor: blockedTone,
              title: Text(kindName(k), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: m.text)),
              subtitle: Text(testSites[k]!.take(3).join(', '), style: TextStyle(fontSize: 12, color: m.muted)),
              secondary: Text('${testSites[k]!.length}', style: m.monoStyle(size: 12, color: m.muted)),
            ),
          ],
        ]),
      ),
    ]);
  }
}

class _NetworkCard extends StatelessWidget {
  const _NetworkCard({required this.network, required this.vpnOn});

  final String network;
  final bool vpnOn;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    return MerCard(
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: m.brand.withValues(alpha: .14), borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.wifi_rounded, size: 20, color: m.brand),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.blocked.testingOn, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .8, color: m.muted)),
            Text(network, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: m.text)),
          ]),
        ),
        if (vpnOn) _Chip(t.blocked.vpnOn, m.warn),
      ]),
    );
  }
}

/// Sites on a ring around a blocked sign; two of them red.
class _RingPainter extends CustomPainter {
  _RingPainter({required this.m});

  final Meridian m;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    canvas.drawCircle(c, 50, Paint()..color = blockedTone.withValues(alpha: .08));
    canvas.drawCircle(
      c,
      50,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = blockedTone.withValues(alpha: .3),
    );
    const angles = [-1.2, -.2, .9, 2.1, 3.1, 4.2];
    for (final (i, a) in angles.indexed) {
      canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * 50, 6, Paint()..color = i == 1 || i == 4 ? m.bad : m.good);
    }
    canvas.drawCircle(c, 24, Paint()..color = blockedTone.withValues(alpha: .18));
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = blockedTone;
    canvas.drawCircle(c, 12, ring);
    canvas.drawLine(c + const Offset(-8.5, -8.5), c + const Offset(8.5, 8.5), ring);
  }

  @override
  bool shouldRepaint(_RingPainter old) => false;
}

// ── Running ─────────────────────────────────────────────────────────────

class _Running extends StatelessWidget {
  const _Running({required this.state});

  final BlockedState state;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final done = state.results.length;
    final blocked = state.blocked.length;
    final recent = state.results.values.toList().reversed.take(8).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Center(
        child: SizedBox(
          width: 170,
          height: 170,
          child: Stack(alignment: Alignment.center, children: [
            SizedBox.expand(
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: state.total == 0 ? 0 : done / state.total),
                duration: const Duration(milliseconds: 300),
                builder: (_, v, __) => CircularProgressIndicator(
                  value: v,
                  strokeWidth: 12,
                  strokeCap: StrokeCap.round,
                  color: blockedTone,
                  backgroundColor: m.surface2,
                ),
              ),
            ),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Text('$done', style: m.monoStyle(size: 34, color: m.text)),
              Text(t.blocked.ofSites(n: state.total), style: TextStyle(fontSize: 13, color: m.muted)),
            ]),
          ]),
        ),
      ),
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _Chip(t.blocked.blockedCount(n: blocked), m.bad),
        const SizedBox(width: 8),
        _Chip(t.blocked.openCount(n: done - blocked), m.good),
      ]),
      const SizedBox(height: 14),
      MerCard(
        padding: EdgeInsets.zero,
        child: Column(children: [
          for (final (i, r) in recent.indexed) ...[
            if (i > 0) Divider(height: 1, color: m.line),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(children: [
                SiteBadge(host: r.host, size: 32),
                const SizedBox(width: 12),
                Expanded(child: Text(r.host, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: m.text))),
                if (r.block.blocked)
                  _Chip(blockLook(r.block, m).$1, blockLook(r.block, m).$2)
                else if (r.block == Block.open)
                  Icon(Icons.check_rounded, color: m.good, size: 20)
                else
                  Text('?', style: TextStyle(color: m.muted)),
              ]),
            ),
          ],
        ]),
      ),
    ]);
  }
}

// ── Results ─────────────────────────────────────────────────────────────

class _Results extends ConsumerWidget {
  const _Results({required this.state});

  final BlockedState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.mer;
    final blocked = state.blocked;
    final tested = state.results.values.where((r) => r.block != Block.unknown).length;
    final viaVpn = state.throughVpn;
    final allWork = viaVpn.isNotEmpty && viaVpn.values.every((v) => v);
    final network = state.network ?? t.blocked.thisNetwork;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: (blocked.isEmpty ? m.good : m.bad).withValues(alpha: .08),
          borderRadius: BorderRadius.circular(Meridian.rCard),
          border: Border.all(color: (blocked.isEmpty ? m.good : m.bad).withValues(alpha: .35)),
        ),
        child: Row(children: [
          SizedBox(
            width: 88,
            height: 88,
            child: Stack(alignment: Alignment.center, children: [
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: tested == 0 ? 0 : blocked.length / tested,
                  strokeWidth: 10,
                  color: m.bad,
                  backgroundColor: m.good.withValues(alpha: .35),
                ),
              ),
              Text('${blocked.length}', style: m.monoStyle(size: 24, color: m.text)),
            ]),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                blocked.isEmpty ? t.blocked.noneBlocked(network: network) : t.blocked.someBlocked(n: blocked.length, network: network),
                style: TextStyle(fontSize: 19, height: 1.2, fontWeight: FontWeight.w800, color: m.text),
              ),
              const SizedBox(height: 4),
              Text(t.blocked.openOf(open: tested - blocked.length, total: tested), style: TextStyle(fontSize: 13, color: m.muted)),
              if (allWork) ...[const SizedBox(height: 8), _Chip(t.blocked.allWork, m.good)],
            ]),
          ),
        ]),
      ),
      if (blocked.isNotEmpty) ...[
        const SizedBox(height: 10),
        Row(children: [
          for (final (i, b) in [Block.dns, Block.reset, Block.timeout, Block.page].indexed) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: m.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: m.line)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${blocked.where((r) => r.block == b).length}', style: m.monoStyle(size: 20, color: blockLook(b, m).$2)),
                  Text(blockLook(b, m).$1, maxLines: 2, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: m.muted)),
                ]),
              ),
            ),
          ],
        ]),
        ToolHeading(t.blocked.blockedHeading),
        MerCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            for (final (i, r) in blocked.indexed) ...[
              if (i > 0) Divider(height: 1, color: m.line),
              InkWell(
                onTap: () => showSiteSheet(context, r, viaVpn[r.host]),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                  child: Row(children: [
                    SiteBadge(host: r.host),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(r.host, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: m.text)),
                        const SizedBox(height: 3),
                        Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                          _Chip(blockLook(r.block, m).$1, blockLook(r.block, m).$2),
                          if (viaVpn[r.host] == true)
                            Text(t.blocked.worksVpn, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: m.good)),
                          if (viaVpn[r.host] == false)
                            Text(t.blocked.failsVpn, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: m.muted)),
                        ]),
                      ]),
                    ),
                    Icon(Icons.chevron_right_rounded, color: m.muted),
                  ]),
                ),
              ),
            ],
          ]),
        ),
      ],
      ToolHeading(t.blocked.byKind),
      MerCard(
        child: Column(children: [
          for (final k in SiteKind.values)
            if (state.results.values.any((r) => kindOf(r.host) == k))
              Builder(builder: (_) {
                final all = state.results.values.where((r) => kindOf(r.host) == k && r.block != Block.unknown).toList();
                final bad = all.where((r) => r.block.blocked).length;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    SizedBox(width: 108, child: Text(kindName(k), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: m.text))),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: all.isEmpty ? 0 : bad / all.length,
                          minHeight: 8,
                          color: m.bad,
                          backgroundColor: m.good.withValues(alpha: .35),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 48,
                      child: Text('$bad/${all.length}', textAlign: TextAlign.end, style: m.monoStyle(size: 12, color: bad > 0 ? m.bad : m.muted)),
                    ),
                  ]),
                );
              }),
        ]),
      ),
    ]);
  }
}

/// Test again, and the way through: connect, then prove it.
class _DoneActions extends ConsumerWidget {
  const _DoneActions({required this.vpnOn});

  final bool vpnOn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.mer;
    final s = ref.watch(blockedProvider);
    final choice = ref.watch(tunnelsProvider).value?.choice;
    final Widget second;
    if (s.blocked.isEmpty) {
      second = const SizedBox.shrink();
    } else if (vpnOn) {
      second = FilledButton.icon(
        onPressed: s.checkingVpn ? null : ref.read(blockedProvider.notifier).checkThroughVpn,
        icon: s.checkingVpn
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.verified_user_outlined),
        label: Text(t.blocked.checkVpn),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54), backgroundColor: m.good, foregroundColor: m.bg),
      );
    } else {
      second = FilledButton.icon(
        onPressed: choice == null ? null : () => ref.read(vpnProvider.notifier).connect(choice),
        icon: const Icon(Icons.shield_outlined),
        label: Text(t.blocked.connect),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54), backgroundColor: m.brand, foregroundColor: m.onBrand),
      );
    }
    return Row(children: [
      Expanded(
        child: OutlinedButton(
          onPressed: ref.read(blockedProvider.notifier).reset,
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(54), foregroundColor: m.text, side: BorderSide(color: m.line)),
          child: Text(t.blocked.again),
        ),
      ),
      if (s.blocked.isNotEmpty) ...[const SizedBox(width: 8), Expanded(flex: 2, child: second)],
    ]);
  }
}

// ── One site ────────────────────────────────────────────────────────────

Future<void> showSiteSheet(BuildContext context, SiteResult r, bool? viaVpn) {
  final m = context.mer;
  final (how, tone) = blockLook(r.block, m);
  final steps = [
    (t.blocked.steps.lookup, r.lookup),
    (t.blocked.steps.connect, r.connect),
    (t.blocked.steps.handshake, r.handshake),
  ];
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: m.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (c) => SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.paddingOf(c).bottom),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          SiteBadge(host: r.host, size: 52),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.host, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: m.text)),
              const SizedBox(height: 4),
              Wrap(spacing: 6, children: [_Chip(kindName(kindOf(r.host)), m.muted), _Chip(how, tone)]),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          for (final (i, (label, value, color)) in [
            (t.blocked.withoutVpn, how, tone),
            (
              t.blocked.throughVpn,
              viaVpn == null ? t.blocked.notChecked : viaVpn ? t.blocked.opens : t.blocked.stillBlocked,
              viaVpn == true ? m.good : m.muted,
            ),
          ].indexed) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withValues(alpha: .35)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .6, color: m.muted)),
                  Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
                ]),
              ),
            ),
          ],
        ]),
        const SizedBox(height: 14),
        Text(t.blocked.whatHappened, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: .8, color: m.muted)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(color: m.surface2, borderRadius: BorderRadius.circular(16)),
          child: Column(children: [
            for (final (i, (label, step)) in steps.indexed) ...[
              if (i > 0) Divider(height: 1, color: m.line),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: step.ok == true
                          ? m.good.withValues(alpha: .16)
                          : step.ok == false
                              ? m.bad.withValues(alpha: .16)
                              : m.surface,
                    ),
                    child: step.ok == null
                        ? null
                        : Icon(step.ok! ? Icons.check_rounded : Icons.close_rounded, size: 14, color: step.ok! ? m.good : m.bad),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: step.ok == null ? m.muted : m.text)),
                      if (step.ok != null) Text(step.ok! ? step.detail : failureText(step), style: m.monoStyle(size: 12, color: m.muted)),
                    ]),
                  ),
                ]),
              ),
            ],
          ]),
        ),
      ]),
    ),
  );
}

// ── The country ─────────────────────────────────────────────────────────

class _CountryView extends ConsumerWidget {
  const _CountryView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.mer;
    final report = ref.watch(countryBlocksProvider);
    return switch (report) {
      AsyncData(value: final r?) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          MerCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                Text('${r.sites.where((s) => s.certain).length}', style: m.monoStyle(size: 30, color: m.text)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(t.blocked.countryBlocked(country: countryName(r.country, r.country)),
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: m.text)),
                ),
              ]),
              Text(t.blocked.countrySub, style: TextStyle(fontSize: 12, color: m.muted)),
            ]),
          ),
          const SizedBox(height: 12),
          if (r.sites.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(t.blocked.countryNone, textAlign: TextAlign.center, style: TextStyle(color: m.muted)),
            )
          else
            MerCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                for (final (i, s) in r.sites.take(40).indexed) ...[
                  if (i > 0) Divider(height: 1, color: m.line),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    child: Row(children: [
                      SiteBadge(host: s.domain),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(s.domain, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: m.text)),
                          Text(t.blocked.tests(n: s.tests), style: TextStyle(fontSize: 12, color: m.muted)),
                        ]),
                      ),
                      _Chip(s.certain ? t.blocked.confirmed : t.blocked.oftenFails, s.certain ? m.bad : m.warn),
                    ]),
                  ),
                ],
              ]),
            ),
        ]),
      AsyncData() || AsyncError() => Padding(
          padding: const EdgeInsets.all(20),
          child: Text(t.blocked.countryUnavailable, textAlign: TextAlign.center, style: TextStyle(color: m.muted)),
        ),
      _ => const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
    };
  }
}
