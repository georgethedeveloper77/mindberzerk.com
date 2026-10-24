import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g_network/g_network.dart';

import '../design/meridian.dart';
import '../vpn/vpn_controller.dart';
import 'tool_widgets.dart';
import 'tools_providers.dart';

class SpeedScreen extends ConsumerWidget {
  const SpeedScreen({super.key});

  Future<void> _start(BuildContext context, WidgetRef ref) async {
    final consent = ref.read(mlabConsentProvider).value ?? false;
    if (!consent) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Before your first test'),
          content: const Text(
            'Speed tests run on M-Lab, a research platform. M-Lab publishes every result, '
            'including your IP address, as open data. A test uses roughly 50 to 100 MB.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Not now')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Run test')),
          ],
        ),
      );
      if (ok != true) return;
      await ref.read(mlabConsentProvider.notifier).accept();
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
    final direct = ref.watch(directSpeedProvider).value;

    // A finished direct test becomes the baseline for VPN comparisons.
    ref.listen(speedTestProvider, (prev, next) {
      final done = next.progress?.phase == SpeedPhase.done && prev?.progress?.phase != SpeedPhase.done;
      final mbps = next.progress?.downloadMbps;
      if (done && mbps != null && !viaVpn) ref.read(directSpeedProvider.notifier).record(mbps);
    });

    final (value, caption, color) = switch (p?.phase) {
      SpeedPhase.download => (p!.mbps, 'Download', m.brand),
      SpeedPhase.upload => (p!.mbps, 'Upload', m.good),
      SpeedPhase.done => (down ?? 0.0, 'Download', m.brand),
      SpeedPhase.locating => (0.0, 'Finding a server', m.muted),
      null => (0.0, viaVpn ? 'Through the VPN' : 'Direct, no VPN', m.muted),
    };
    final where = p?.server == null ? null : [p!.server!.city, p.server!.country].whereType<String>().join(', ');

    return ToolPage(
      title: 'Speed test',
      info: 'Measured by M-Lab, a research platform that publishes every result, including your IP address, '
          'as open data. A test uses about 50 to 100 MB. With the VPN on, it measures the speed through the tunnel. '
          'Video quality uses the bitrates streaming services publish for each resolution. '
          'Run one test without the VPN first: tests through the VPN are then compared with it.',
      action: test.running
          ? OutlinedButton(
              onPressed: () => ref.read(speedTestProvider.notifier).cancel(),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              child: const Text('Stop'),
            )
          : FilledButton(
              onPressed: () => _start(context, ref),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              child: Text(p == null ? 'Start test' : 'Test again'),
            ),
      children: [
        StatStrip(stats: [
          ('Latency', p?.minRttMs == null ? 'none' : '${p!.minRttMs!.round()} ms', null),
          ('Server', where ?? 'M-Lab', null),
          ('Path', viaVpn ? 'VPN' : 'Direct', viaVpn ? m.good : null),
        ]),
        const SizedBox(height: 24),
        Center(
          child: SizedBox(
            width: 260,
            height: 230,
            child: CustomPaint(
              painter: _Dial(value: value, color: color, m: m),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(value.toStringAsFixed(value >= 100 ? 0 : 1), style: m.monoStyle(size: 48, weight: FontWeight.w600)),
                    Text('Mbps', style: TextStyle(fontSize: 16, color: m.muted)),
                    const SizedBox(height: 4),
                    Text(caption, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        LineChartView(series: [
          (test.downSamples, m.brand),
          (test.upSamples, m.good),
        ], unit: ''),
        const SizedBox(height: 16),
        ToolCard(
          child: StatStrip(stats: [
            ('Download', down?.toStringAsFixed(1) ?? 'none', m.brand),
            ('Upload', p?.uploadMbps?.toStringAsFixed(1) ?? 'none', m.good),
          ]),
        ),
        if (test.error != null) ...[
          const SizedBox(height: 10),
          Text(test.error!, style: TextStyle(color: m.bad, fontSize: 13)),
        ],
        if (p?.phase == SpeedPhase.done && down != null) ...[
          if (viaVpn && direct != null && direct > 0) ...[
            const SizedBox(height: 12),
            _VpnCost(vpn: down, direct: direct),
          ],
          const SizedBox(height: 12),
          _VideoQuality(mbps: down),
        ],
      ],
    );
  }
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
        ? (m.good, 'Little speed lost to the VPN')
        : pct >= 40
            ? (m.warn, 'Noticeably slower than direct')
            : (m.bad, 'Much slower. Try another server');
    return ToolCard(
      child: Row(
        children: [
          Text('$pct%', style: m.monoStyle(size: 28, weight: FontWeight.w600, color: color)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('of your direct speed', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: m.text)),
                Text('$note · direct ${direct.toStringAsFixed(1)} Mbps', style: TextStyle(fontSize: 12, color: m.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// What this download speed can stream, using the bitrates streaming
/// services publish for each resolution.
class _VideoQuality extends StatelessWidget {
  const _VideoQuality({required this.mbps});

  final double mbps;

  static const _tiers = [
    (25.0, '4K', '2160p', 'Large TVs'),
    (15.0, '1440p', 'QHD', 'Large laptops'),
    (8.0, '1080p', 'Full HD', 'Tablets and laptops'),
    (5.0, '720p', 'HD', 'Phones'),
    (2.5, '480p', 'SD', 'Small phones'),
    (1.0, '360p', 'Low', 'Audio and calls'),
  ];

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final tier = _tiers.firstWhere((t) => mbps >= t.$1, orElse: () => (0.0, 'Below 360p', 'Very low', 'Messaging'));
    return ToolCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: m.brandSoft, borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.smart_display_outlined, color: m.brand),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Video up to ${tier.$2}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: m.text)),
                Text('${tier.$3}. Good for ${tier.$4.toLowerCase()}.', style: TextStyle(fontSize: 13, color: m.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A 270-degree dial. The scale steps up (50, 100, 250, 500, 1000) so a slow
/// link still fills a visible arc and a fast one never overflows.
class _Dial extends CustomPainter {
  _Dial({required this.value, required this.color, required this.m});

  final double value;
  final Color color;
  final Meridian m;

  @override
  void paint(Canvas canvas, Size size) {
    final max = const [50.0, 100.0, 250.0, 500.0, 1000.0].firstWhere((s) => value <= s, orElse: () => 1000);
    final rect = Rect.fromCircle(center: Offset(size.width / 2, size.height / 2 + 6), radius: size.width / 2 - 14);
    const start = math.pi * .75, sweep = math.pi * 1.5;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, start, sweep, false, stroke..color = m.surface2);
    final f = (value / max).clamp(0.0, 1.0);
    if (f > 0) canvas.drawArc(rect, start, sweep * f, false, stroke..color = color);
  }

  @override
  bool shouldRepaint(_Dial old) => old.value != value || old.color != color || old.m != m;
}
