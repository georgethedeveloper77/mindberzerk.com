import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g_network/g_network.dart';

import '../design/meridian.dart';
import '../i18n/strings.g.dart';
import '../vpn/vpn_controller.dart';
import 'network_screen.dart' show liveSnapshotProvider;
import 'tool_settings.dart';
import 'tool_widgets.dart';
import 'tools_providers.dart';

class SpeedScreen extends ConsumerWidget {
  const SpeedScreen({super.key});

  /// Starts a test, first asking on mobile data when the setting says so:
  /// a test can use well over 100 MB on a fast connection.
  Future<void> _start(BuildContext context, WidgetRef ref) async {
    final ask = (await ref.read(toolSettingsProvider.future)).askOnMobile;
    final mobile = ref.read(liveSnapshotProvider).value?.transport == Transport.cellular;
    if (ask && mobile && context.mounted) {
      final go = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(t.toolSettings.mobileTitle),
          content: Text(t.toolSettings.mobileBody),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t.common.cancel)),
            TextButton(onPressed: () => Navigator.pop(c, true), child: Text(t.toolSettings.mobileGo)),
          ],
        ),
      );
      if (go != true) return;
    }
    ref.read(speedTestProvider.notifier).start();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.mer;
    final test = ref.watch(speedTestProvider);
    final p = test.progress;
    final viaVpn = ref.watch(vpnProvider.select((s) => s.phase)) == VpnPhase.on;
    final down = p?.downloadMbps;
    final up = p?.uploadMbps;
    final direct = ref.watch(directSpeedProvider).value;
    final history = ref.watch(speedHistoryProvider).value ?? const <SpeedResult>[];
    // The ISP is only meaningful for a direct test; through the VPN the
    // "provider" is the VPN server's host.
    final isp = viaVpn ? null : ref.watch(publicIdentityProvider).value?.org;
    final comparison = viaVpn ? null : ref.watch(ispComparisonProvider).value;
    final sharing = ref.watch(shareResultsProvider).value ?? true;

    // A finished test is saved, and a direct one becomes the VPN baseline.
    ref.listen(speedTestProvider, (prev, next) {
      final done = next.progress?.phase == SpeedPhase.done && prev?.progress?.phase != SpeedPhase.done;
      final r = next.progress;
      if (!done || r?.downloadMbps == null) return;
      if (!viaVpn) {
        ref.read(directSpeedProvider.notifier).record(r!.downloadMbps!);
        if (ref.read(shareResultsProvider).value ?? true) {
          shareResult(down: r.downloadMbps!, up: r.uploadMbps ?? 0, ping: r.minRttMs ?? 0)
              .then((_) => ref.invalidate(ispComparisonProvider));
        }
      }
      ref.read(speedHistoryProvider.notifier).add(SpeedResult(
            at: DateTime.now(),
            down: r!.downloadMbps!,
            up: r.uploadMbps ?? 0,
            pingMs: r.minRttMs,
            viaVpn: viaVpn,
            isp: isp,
          ));
    });

    final phase = p?.phase;
    final (value, caption, color) = switch (phase) {
      SpeedPhase.download => (p!.mbps, t.speed.download, m.brand),
      SpeedPhase.upload => (p!.mbps, t.speed.upload, m.good),
      SpeedPhase.done => (down ?? 0.0, t.speed.download, m.brand),
      SpeedPhase.locating => (0.0, t.speed.finding, m.muted),
      null => (0.0, viaVpn ? t.speed.throughVpn : t.speed.directNoVpn, m.muted),
    };
    // The preview follows the download as it is measured, then settles.
    final previewMbps = phase == SpeedPhase.download ? p!.mbps : down;
    final where = p?.server == null ? null : [p!.server!.city, p.server!.country].whereType<String>().join(', ');

    return ToolPage(
      title: t.speed.title,
      icon: Icons.speed_rounded,
      color: m.brand,
      action: test.running
          ? OutlinedButton(
              onPressed: () => ref.read(speedTestProvider.notifier).cancel(),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              child: Text(t.speed.stop),
            )
          : FilledButton(
              onPressed: () => _start(context, ref),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              child: Text(p == null ? t.speed.start : t.speed.again),
            ),
      children: [
        ToolCard(
          child: Column(
            children: [
              Row(
                children: [
                  _Chip(text: viaVpn ? t.speed.viaVpn : t.speed.direct, color: viaVpn ? m.good : m.muted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isp ?? where ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: m.text),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _Phases(phase: phase),
              const SizedBox(height: 4),
              SizedBox(
                width: 270,
                height: 220,
                child: CustomPaint(
                  painter: _Dial(value: value, color: color, m: m),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(value.toStringAsFixed(value >= 100 ? 0 : 1), style: m.monoStyle(size: 46, weight: FontWeight.w600)),
                        Text(t.speed.mbps, style: TextStyle(fontSize: 15, color: m.muted)),
                        const SizedBox(height: 2),
                        Text(caption, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
                      ],
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  for (final (i, (label, figure, tone)) in [
                    (t.speed.download, down == null ? t.speed.none : down.toStringAsFixed(down >= 100 ? 0 : 1), null),
                    (t.speed.upload, up == null ? t.speed.none : up.toStringAsFixed(up >= 100 ? 0 : 1), null),
                    (t.speed.ping, p?.minRttMs == null ? t.speed.none : t.speed.ms(n: p!.minRttMs!.round()), null),
                    if (viaVpn && down != null && direct != null && direct > 0)
                      (t.speed.vsDirect, '${(down / direct * 100).round()}%', m.good),
                  ].indexed) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(child: MetricTile(label: label, value: figure, color: tone)),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _PhaseChart(
                label: t.speed.download,
                samples: test.downSamples,
                value: phase == SpeedPhase.download ? p!.mbps : down,
                color: m.brand,
                active: phase == SpeedPhase.download,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _PhaseChart(
                label: t.speed.upload,
                samples: test.upSamples,
                value: phase == SpeedPhase.upload ? p!.mbps : up,
                color: m.good,
                active: phase == SpeedPhase.upload,
              ),
            ),
          ],
        ),
        if (test.error != null) ...[
          const SizedBox(height: 10),
          Text(test.error!, style: TextStyle(color: m.bad, fontSize: 13)),
        ],
        if (phase == SpeedPhase.done && down != null) ...[
          const SizedBox(height: 12),
          _GradeCard(down: down, up: up ?? 0, pingMs: p?.minRttMs, isp: isp, viaVpn: viaVpn),
        ],
        if (phase == SpeedPhase.done && down != null && viaVpn && direct != null && direct > 0) ...[
          const SizedBox(height: 12),
          _VpnCost(vpn: down, direct: direct),
        ],
        const SizedBox(height: 12),
        _VideoPreview(mbps: previewMbps, live: phase == SpeedPhase.download),
        if (comparison != null && comparison.providers.length >= 2) ...[
          const SizedBox(height: 12),
          _Comparison(data: comparison),
        ],
        if (history.isNotEmpty) ...[
          const SizedBox(height: 20),
          _History(results: history, onClear: () => ref.read(speedHistoryProvider.notifier).clear()),
        ],
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: sharing,
          onChanged: (v) => ref.read(shareResultsProvider.notifier).set(v),
          title: Text(t.speed.compare, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: m.text)),
          subtitle: Text(t.speed.compareSub, style: TextStyle(fontSize: 13, color: m.muted)),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: color.withValues(alpha: .13), borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
      );
}

/// One phase's own graph: its live samples, its figure, lit while running.
class _PhaseChart extends StatelessWidget {
  const _PhaseChart({required this.label, required this.samples, required this.value, required this.color, required this.active});

  final String label;
  final List<double?> samples;
  final double? value;
  final Color color;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 8),
      decoration: BoxDecoration(
        color: m.surface,
        borderRadius: BorderRadius.circular(Meridian.rCard),
        border: Border.all(color: active ? color : m.line, width: active ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(label == t.speed.download ? Icons.south_rounded : Icons.north_rounded, size: 16, color: color),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: m.text)),
            ],
          ),
          Text(
            value == null ? t.speed.none : t.speed.mbpsValue(v: value!.toStringAsFixed(value! >= 100 ? 0 : 1)),
            style: m.monoStyle(size: 17, weight: FontWeight.w600, color: value == null ? m.muted : m.text),
          ),
          const SizedBox(height: 6),
          LineChartView(series: [(samples, color)], height: 80),
        ],
      ),
    );
  }
}

/// The same picture at the resolution this speed can stream. Decoding the
/// photo at a small width and scaling it up with no smoothing gives the
/// honest blockiness of a low-resolution stream; no video is fetched.
class _VideoPreview extends StatelessWidget {
  const _VideoPreview({required this.mbps, required this.live});

  final double? mbps;
  final bool live;

  // (minimum Mbps, label, decode width, who it suits)
  static final _tiers = [
    (25.0, '4K', 1280, t.speed.tierTv),
    (15.0, '1440p', 640, t.speed.tierLaptopLarge),
    (8.0, '1080p', 400, t.speed.tierTablet),
    (5.0, '720p', 220, t.speed.tierPhone),
    (2.5, '480p', 130, t.speed.tierSmallPhone),
    (1.0, '360p', 84, t.speed.tierCalls),
    (0.0, '240p', 52, t.speed.messagingOnly),
  ];

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final tier = mbps == null ? null : _tiers.firstWhere((x) => mbps! >= x.$1);
    final width = tier?.$3 ?? 40;
    return ToolCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(t.speed.videoQuality, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: m.text)),
              const Spacer(),
              if (live) Text('measuring', style: TextStyle(fontSize: 12, color: m.muted)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/preview/city.jpg',
                    cacheWidth: width,
                    filterQuality: FilterQuality.none,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  ),
                  Positioned(
                    left: 10,
                    top: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: .55), borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        tier == null ? t.speed.preview : t.speed.previewTier(tier: tier.$2),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .5, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final tr in _tiers.reversed)
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: tier != null && mbps! >= tr.$1 ? m.good.withValues(alpha: .14) : m.surface2,
                      borderRadius: BorderRadius.circular(8),
                      border: tier == tr ? Border.all(color: m.good, width: 1.5) : null,
                    ),
                    child: Text(
                      tr.$2,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: tier != null && mbps! >= tr.$1 ? m.good : m.muted,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (tier != null && !live) ...[
            const SizedBox(height: 8),
            Text(t.speed.streamsUpTo(tier: tier.$2, who: tier.$4), style: TextStyle(fontSize: 13, color: m.muted)),
          ],
        ],
      ),
    );
  }
}

class _History extends StatelessWidget {
  const _History({required this.results, required this.onClear});

  final List<SpeedResult> results;
  final VoidCallback onClear;

  String _when(BuildContext context, DateTime at) {
    final now = DateTime.now();
    final time = TimeOfDay.fromDateTime(at).format(context);
    if (now.year == at.year && now.month == at.month && now.day == at.day) return t.speed.today(time: time);
    return '${at.day}/${at.month}, $time';
  }

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(t.speed.history, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: m.text)),
            const Spacer(),
            TextButton(onPressed: onClear, child: Text(t.speed.clear)),
          ],
        ),
        ToolCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Oldest on the left, like any timeline.
              LineChartView(
                series: [
                  ([for (final r in results.reversed) r.down], m.brand),
                  ([for (final r in results.reversed) r.up], m.good),
                ],
                height: 120,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _Legend(color: m.brand, text: t.speed.download),
                  const SizedBox(width: 14),
                  _Legend(color: m.good, text: t.speed.upload),
                  const Spacer(),
                  Text(t.speed.tests(n: results.length), style: TextStyle(fontSize: 11, color: m.muted)),
                ],
              ),
              for (final r in results.take(5)) ...[
                Divider(height: 20, color: m.line),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_when(context, r.at), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: m.text)),
                          Text(
                            r.viaVpn ? t.speed.viaVpnLower : (r.isp ?? t.speed.directLower),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: m.muted),
                          ),
                        ],
                      ),
                    ),
                    _GradeBadge(letter: speedGrade(r.down, r.up, r.pingMs).$1, small: true),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('↓ ${r.down.toStringAsFixed(1)}', style: m.monoStyle(size: 13, color: m.text)),
                        Text('↑ ${r.up.toStringAsFixed(1)}', style: m.monoStyle(size: 13, color: m.muted)),
                      ],
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// The headline verdict: one letter and one word, plus what it means.
class _GradeCard extends StatelessWidget {
  const _GradeCard({required this.down, required this.up, required this.pingMs, required this.isp, required this.viaVpn});

  final double down;
  final double up;
  final double? pingMs;
  final String? isp;
  final bool viaVpn;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final (letter, label) = speedGrade(down, up, pingMs);
    final good = letter.startsWith('A') || letter == 'B';
    final meaning = switch (letter) {
      'A+' || 'A' => t.speed.gradeA,
      'B' => t.speed.gradeB,
      'C' => t.speed.gradeC,
      'D' => t.speed.gradeD,
      _ => t.speed.messagingOnly,
    };
    return ToolCard(
      child: Row(
        children: [
          _GradeBadge(letter: letter),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  viaVpn ? t.speed.gradeVpn(label: label) : (isp == null ? label : t.speed.gradeIsp(label: label, isp: isp!)),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: good ? m.text : m.warn),
                ),
                const SizedBox(height: 2),
                Text(meaning, style: TextStyle(fontSize: 13, height: 1.4, color: m.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GradeBadge extends StatelessWidget {
  const _GradeBadge({required this.letter, this.small = false});

  final String letter;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final color = switch (letter) {
      'A+' || 'A' => m.good,
      'B' => m.brand,
      'C' => m.warn,
      _ => m.bad,
    };
    final size = small ? 34.0 : 56.0;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color.withValues(alpha: .14), borderRadius: BorderRadius.circular(small ? 10 : 16)),
      child: Text(letter, style: TextStyle(fontSize: small ? 14 : 22, fontWeight: FontWeight.w800, color: color)),
    );
  }
}

/// "Safaricom in Nairobi: 2nd of 5 providers", and the ranking itself.
class _Comparison extends StatelessWidget {
  const _Comparison({required this.data});

  final IspComparison data;

  static String _ordinal(int n) {
    final s = (n % 100 >= 11 && n % 100 <= 13) ? 'th' : const {1: 'st', 2: 'nd', 3: 'rd'}[n % 10] ?? 'th';
    return '$n$s';
  }

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final where = data.scope == 'city' && (data.city?.isNotEmpty ?? false) ? data.city! : (data.country ?? t.speed.yourCountry);
    final top = data.providers.map((p) => p.down).fold<double>(1, math.max);
    final headline = data.rank == null
        ? t.speed.notEnough(isp: data.isp ?? t.speed.yourProvider)
        : t.speed.rankLine(isp: data.isp ?? '', where: where, rank: _ordinal(data.rank!), of: data.of);
    return ToolCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(headline, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: m.text)),
          Text(t.speed.median, style: TextStyle(fontSize: 12, color: m.muted)),
          const SizedBox(height: 12),
          for (final p in data.providers.take(6)) ...[
            Row(
              children: [
                SizedBox(
                  width: 110,
                  child: Text(
                    p.isp,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: p.isp == data.isp ? FontWeight.w800 : FontWeight.w600,
                      color: p.isp == data.isp ? m.brand : m.text,
                    ),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: p.down / top,
                      minHeight: 10,
                      backgroundColor: m.surface2,
                      color: p.isp == data.isp ? m.brand : m.muted.withValues(alpha: .5),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 56,
                  child: Text(p.down.toStringAsFixed(p.down >= 100 ? 0 : 1),
                      textAlign: TextAlign.right, style: m.monoStyle(size: 13, color: m.text)),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Text(t.speed.fromUsers, style: TextStyle(fontSize: 11, color: m.muted)),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(width: 9, height: 9, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 5),
          Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.mer.muted)),
        ],
      );
}

/// What the VPN costs, against the last direct test.
class _VpnCost extends StatelessWidget {
  const _VpnCost({required this.vpn, required this.direct});

  final double vpn;
  final double direct;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final pct = (vpn / direct * 100).clamp(0, 999).round();
    final (color, note) = pct >= 70
        ? (m.good, t.speed.costLittle)
        : pct >= 40
            ? (m.warn, t.speed.costNoticeable)
            : (m.bad, t.speed.costMuch);
    return ToolCard(
      child: Row(
        children: [
          Text('$pct%', style: m.monoStyle(size: 28, weight: FontWeight.w600, color: color)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.speed.ofDirect, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: m.text)),
                Text(t.speed.costLine(note: note, mbps: direct.toStringAsFixed(1)), style: TextStyle(fontSize: 12, color: m.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Dial extends CustomPainter {
  _Dial({required this.value, required this.color, required this.m});

  final double value;
  final Color color;
  final Meridian m;

  @override
  void paint(Canvas canvas, Size size) {
    final max = const [50.0, 100.0, 250.0, 500.0, 1000.0].firstWhere((s) => value <= s, orElse: () => 1000);
    final centre = Offset(size.width / 2, size.height / 2 + 6);
    final radius = size.width / 2 - 18;
    final rect = Rect.fromCircle(center: centre, radius: radius);
    const start = math.pi * .75, sweep = math.pi * 1.5;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, start, sweep, false, stroke..color = m.surface2);

    // Scale marks: 0, a fifth, ... the top of the scale.
    for (var i = 0; i <= 5; i++) {
      final a = start + sweep * i / 5;
      final at = centre + Offset(math.cos(a), math.sin(a)) * (radius - 26);
      final label = (max * i / 5).round().toString();
      final tp = TextPainter(
        text: TextSpan(text: label, style: TextStyle(fontSize: 10, fontFamily: Meridian.mono, color: m.muted)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
    }

    final f = (value / max).clamp(0.0, 1.0);
    if (f <= 0) return;
    final fill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: start,
        endAngle: start + sweep,
        colors: [m.teal, color],
        transform: const GradientRotation(0),
      ).createShader(rect);
    canvas.drawArc(rect, start, sweep * f, false, fill);
    final end = start + sweep * f;
    final knob = centre + Offset(math.cos(end), math.sin(end)) * radius;
    canvas.drawCircle(knob, 9, Paint()..color = m.bg);
    canvas.drawCircle(
      knob,
      9,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_Dial old) => old.value != value || old.color != color || old.m != m;
}

/// Ping, Download, Upload: the step running now is lit and breathing.
class _Phases extends StatefulWidget {
  const _Phases({required this.phase});

  final SpeedPhase? phase;

  @override
  State<_Phases> createState() => _PhasesState();
}

class _PhasesState extends State<_Phases> with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _breath.stop();
    } else if (!_breath.isAnimating) {
      _breath.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final phase = widget.phase;
    final done = phase == SpeedPhase.done;
    final steps = [
      (t.speed.ping, m.good, phase == SpeedPhase.locating, done || phase == SpeedPhase.download || phase == SpeedPhase.upload),
      (t.speed.download, m.brand, phase == SpeedPhase.download, done || phase == SpeedPhase.upload),
      (t.speed.upload, m.good, phase == SpeedPhase.upload, done),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final (i, (label, tone, now, past)) in steps.indexed) ...[
          if (i > 0) const SizedBox(width: 18),
          AnimatedBuilder(
            animation: _breath,
            builder: (_, __) => Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: now ? tone.withValues(alpha: .4 + .6 * _breath.value) : past ? tone : m.line,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: now || past ? tone : m.muted)),
        ],
      ],
    );
  }
}
