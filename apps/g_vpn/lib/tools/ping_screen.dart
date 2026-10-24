import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/meridian.dart';
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
  final _host = TextEditingController(text: '1.1.1.1');

  @override
  void dispose() {
    _host.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final ping = ref.watch(pingProvider);
    final gateway = ref.watch(liveSnapshotProvider).value?.gateway;
    String ms(double? v) => v == null ? 'none' : '${v.toStringAsFixed(v < 10 ? 1 : 0)} ms';

    final verdict = switch ((ping.avg, ping.loss, ping.jitter ?? 0)) {
      (null, _, _) => null,
      (_, final loss, _) when loss > 10 => ('Unstable: calls will break up', m.bad),
      (final avg?, _, final jitter) when avg > 150 || jitter > 30 => ('Fair: fine for browsing', m.warn),
      _ => ('Good: calls and games are fine', m.good),
    };

    void preset(String host) {
      _host.text = host;
      ref.read(pingProvider.notifier).start(host, 443);
    }

    return ToolPage(
      title: 'Ping',
      info: 'Times a TCP handshake once a second over the last minute. Android apps cannot send classic ICMP pings; '
          'a handshake is the same single round trip. Jitter is how much each answer differs from the one before, '
          'which is what breaks up calls. With the VPN on, it measures through the tunnel.',
      action: ping.running
          ? OutlinedButton(
              onPressed: () => ref.read(pingProvider.notifier).stop(),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              child: const Text('Stop'),
            )
          : FilledButton(
              onPressed: () => ref.read(pingProvider.notifier).start(_host.text.trim(), 443),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              child: const Text('Start'),
            ),
      children: [
        TextField(
          controller: _host,
          keyboardType: TextInputType.url,
          style: m.monoStyle(size: 15),
          decoration: InputDecoration(
            labelText: 'Host or IP address',
            filled: true,
            fillColor: m.surface2,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(Meridian.rChip), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: [
            ActionChip(label: const Text('Cloudflare'), onPressed: () => preset('1.1.1.1')),
            ActionChip(label: const Text('Google'), onPressed: () => preset('8.8.8.8')),
            if (gateway != null) ActionChip(label: const Text('Your router'), onPressed: () => preset(gateway)),
          ],
        ),
        const SizedBox(height: 18),
        StatStrip(stats: [
          ('Average', ms(ping.avg), null),
          ('Jitter', ms(ping.jitter), null),
          ('Loss', '${ping.loss.toStringAsFixed(0)}%', ping.loss > 0 ? m.warn : null),
        ]),
        const SizedBox(height: 16),
        LineChartView(series: [(ping.samples, m.brand)], height: 180),
        const SizedBox(height: 12),
        if (verdict != null)
          Text(verdict.$1, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: verdict.$2)),
        if (ping.min != null) ...[
          const SizedBox(height: 8),
          Text('Fastest ${ms(ping.min)}, slowest ${ms(ping.max)}, ${ping.samples.length} probes',
              style: m.monoStyle(size: 12, color: m.muted)),
        ],
      ],
    );
  }
}
