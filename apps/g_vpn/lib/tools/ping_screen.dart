import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/meridian.dart';
import '../i18n/strings.g.dart';
import 'network_screen.dart';
import 'probe.dart';
import 'tool_widgets.dart';

class PingState {
  const PingState({this.samples = const [], this.running = false});

  /// Milliseconds per probe; null is a lost probe.
  final List<double?> samples;
  final bool running;

  List<double> get ok => samples.whereType<double>().toList();
  double? get avg => ok.isEmpty ? null : ok.reduce((a, b) => a + b) / ok.length;
  double? get min => ok.isEmpty ? null : ok.reduce((a, b) => a < b ? a : b);
  double? get max => ok.isEmpty ? null : ok.reduce((a, b) => a > b ? a : b);
  double get loss => samples.isEmpty ? 0 : (samples.length - ok.length) * 100 / samples.length;

  /// Mean change between consecutive answers: what a call feels as jitter.
  double? get jitter {
    final v = ok;
    if (v.length < 2) return null;
    var sum = 0.0;
    for (var i = 1; i < v.length; i++) {
      sum += (v[i] - v[i - 1]).abs();
    }
    return sum / (v.length - 1);
  }
}

final pingProvider = NotifierProvider.autoDispose<PingController, PingState>(PingController.new);

/// One probe a second, keeping the last minute. Stops with the screen.
class PingController extends Notifier<PingState> {
  static const _keep = 60;
  Timer? _timer;
  bool _inFlight = false;

  @override
  PingState build() {
    ref.onDispose(() => _timer?.cancel());
    return const PingState();
  }

  void start(String host, int port) {
    _timer?.cancel();
    state = const PingState(running: true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (_inFlight) return;
      _inFlight = true;
      final ms = await tcpPing(host, port);
      _inFlight = false;
      if (!state.running) return;
      final next = [...state.samples, ms];
      state = PingState(samples: next.length > _keep ? next.sublist(next.length - _keep) : next, running: true);
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    state = PingState(samples: state.samples);
  }
}

class PingScreen extends ConsumerStatefulWidget {
  const PingScreen({super.key});

  @override
  ConsumerState<PingScreen> createState() => _PingScreenState();
}

class _PingScreenState extends ConsumerState<PingScreen> {
  String _target = 'google.com';
  String? _custom;

  @override
  void initState() {
    super.initState();
    // Starts measuring the moment the page opens: the page IS the answer.
    WidgetsBinding.instance.addPostFrameCallback((_) => _run(_target));
  }

  void _run(String host) {
    setState(() => _target = host);
    ref.read(pingProvider.notifier).start(host, 443);
  }

  Future<void> _askHost() async {
    final controller = TextEditingController(text: _custom ?? '');
    final host = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t.ping.askTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(hintText: t.ping.askHint),
          onSubmitted: (v) => Navigator.pop(c, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(t.ping.cancel)),
          FilledButton(onPressed: () => Navigator.pop(c, controller.text.trim()), child: Text(t.ping.title)),
        ],
      ),
    );
    controller.dispose();
    if (host == null || host.isEmpty) return;
    _custom = host;
    _run(host);
  }

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final ping = ref.watch(pingProvider);
    final gateway = ref.watch(liveSnapshotProvider).value?.gateway;
    final last = ping.samples.isEmpty ? null : ping.samples.last;
    final targets = [
      ('Google', 'google.com'),
      if (gateway != null) (t.ping.router, gateway),
      ('Cloudflare', '1.1.1.1'),
      if (_custom != null) (_custom!, _custom!),
    ];

    return ToolPage(
      title: t.ping.title,
      info: t.ping.info,
      action: ping.running
          ? OutlinedButton(
              onPressed: () => ref.read(pingProvider.notifier).stop(),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              child: Text(t.ping.pause),
            )
          : FilledButton(
              onPressed: () => _run(_target),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              child: Text(t.ping.start),
            ),
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final (label, host) in targets)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: _target == host,
                    onSelected: (_) => _run(host),
                    showCheckmark: false,
                    selectedColor: m.text,
                    backgroundColor: m.surface,
                    labelStyle: TextStyle(fontWeight: FontWeight.w700, color: _target == host ? m.bg : m.text),
                    shape: StadiumBorder(side: BorderSide(color: _target == host ? m.text : m.line)),
                  ),
                ),
              ActionChip(
                avatar: Icon(Icons.add_rounded, size: 18, color: m.text),
                label: Text(t.ping.host),
                onPressed: _askHost,
                backgroundColor: m.surface,
                labelStyle: TextStyle(fontWeight: FontWeight.w700, color: m.text),
                shape: StadiumBorder(side: BorderSide(color: m.line)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ToolCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    last == null ? (ping.samples.isEmpty ? '--' : t.ping.lost) : last.round().toString(),
                    style: m.monoStyle(size: 52, weight: FontWeight.w600, color: last == null && ping.samples.isNotEmpty ? m.bad : m.text),
                  ),
                  const SizedBox(width: 6),
                  if (last != null) Text('ms', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: m.muted)),
                  const Spacer(),
                  if (ping.running)
                    Row(
                      children: [
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: m.good, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Text(t.ping.live, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: m.good)),
                      ],
                    ),
                ],
              ),
              Text(_target, style: m.monoStyle(size: 12, color: m.muted)),
              const SizedBox(height: 10),
              LineChartView(series: [(ping.samples, m.brand)], height: 130, unit: ''),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(t.ping.ago, style: TextStyle(fontSize: 11, color: m.muted)),
                  Text(t.ping.now, style: TextStyle(fontSize: 11, color: m.muted)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (final (i, (label, value)) in [
              (t.ping.min, ping.min),
              (t.ping.avg, ping.avg),
              (t.ping.jitter, ping.jitter),
              (t.ping.loss, ping.samples.isEmpty ? null : ping.loss),
            ].indexed) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: ToolCard(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: .5, color: m.muted)),
                      Text(
                        value == null ? '--' : label == t.ping.loss ? '${value.round()}%' : value.toStringAsFixed(label == t.ping.jitter ? 1 : 0),
                        style: m.monoStyle(size: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        if (ping.samples.length >= 5) ...[
          const SizedBox(height: 20),
          Text(t.ping.goodFor, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: m.text)),
          const SizedBox(height: 10),
          ToolCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                for (final (i, (icon, use, verdict)) in _verdicts(ping).indexed) ...[
                  if (i > 0) Divider(height: 1, color: m.line),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      children: [
                        Icon(icon, color: m.text),
                        const SizedBox(width: 12),
                        Expanded(child: Text(use, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: m.text))),
                        _Verdict(verdict),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Thresholds from what each use tolerates: games need low, steady
  /// latency; calls tolerate more delay but not jitter; streaming buffers
  /// and mostly cares about loss.
  static List<(IconData, String, int)> _verdicts(PingState p) {
    final avg = p.avg ?? 999, jitter = p.jitter ?? 99, loss = p.loss;
    int grade(bool great, bool ok) => great ? 2 : ok ? 1 : 0;
    return [
      (Icons.videocam_outlined, t.ping.calls, grade(avg < 100 && jitter < 15 && loss < 1, avg < 200 && jitter < 40 && loss < 3)),
      (Icons.sports_esports_outlined, t.ping.games, grade(avg < 50 && jitter < 8 && loss == 0, avg < 100 && jitter < 20 && loss < 2)),
      (Icons.live_tv_rounded, t.ping.streaming, grade(loss < 1 && avg < 300, loss < 5)),
    ];
  }
}

class _Verdict extends StatelessWidget {
  const _Verdict(this.level);

  final int level;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final (text, color) = switch (level) {
      2 => (t.ping.great, m.good),
      1 => (t.ping.okay, m.warn),
      _ => (t.ping.poor, m.bad),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: .13), borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
    );
  }
}
