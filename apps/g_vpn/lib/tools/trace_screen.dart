import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/meridian.dart';
import '../vpn/vpn_api.g.dart';
import '../vpn/vpn_controller.dart' show vpnApiProvider;
import 'network_screen.dart';
import 'tool_widgets.dart';

class TraceState {
  const TraceState({this.hops = const [], this.running = false, this.reached = false, this.error});

  final List<TraceHop> hops;
  final bool running;
  final bool reached;
  final String? error;
}

final traceProvider = NotifierProvider.autoDispose<TraceController, TraceState>(TraceController.new);

class TraceController extends Notifier<TraceState> {
  static const _maxHops = 30;
  bool _stop = false;

  @override
  TraceState build() {
    ref.onDispose(() => _stop = true);
    return const TraceState();
  }

  Future<void> run(String host) async {
    if (state.running || host.isEmpty) return;
    _stop = false;
    state = const TraceState(running: true);
    final api = ref.read(vpnApiProvider);
    var silentRun = 0;
    for (var ttl = 1; ttl <= _maxHops && !_stop; ttl++) {
      final TraceHop hop;
      try {
        hop = await api.traceHop(host, ttl);
      } on PlatformException catch (e) {
        if (ref.mounted) state = TraceState(hops: state.hops, error: e.message);
        return;
      }
      if (!ref.mounted || _stop) return;
      state = TraceState(hops: [...state.hops, hop], running: true);
      if (hop.reached) {
        state = TraceState(hops: state.hops, reached: true);
        return;
      }
      // Eight silent hops in a row: the rest of the path is not answering.
      silentRun = hop.address == null ? silentRun + 1 : 0;
      if (silentRun >= 8) break;
    }
    if (ref.mounted) state = TraceState(hops: state.hops);
  }

  void stop() {
    _stop = true;
    state = TraceState(hops: state.hops);
  }
}

class TraceScreen extends ConsumerStatefulWidget {
  const TraceScreen({super.key});

  @override
  ConsumerState<TraceScreen> createState() => _TraceScreenState();
}

class _TraceScreenState extends ConsumerState<TraceScreen> {
  final _host = TextEditingController(text: 'google.com');

  @override
  void dispose() {
    _host.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final trace = ref.watch(traceProvider);
    final gateway = ref.watch(liveSnapshotProvider).value?.gateway;

    return ToolPage(
      title: 'Traceroute',
      info: 'Each line is one router your traffic passes through. It uses Android\'s own ping tool with a hop limit, '
          'since apps cannot send these packets directly. With the VPN on, the path starts inside the tunnel, '
          'so your own network and provider are hidden.',
      action: trace.running
          ? OutlinedButton(
              onPressed: () => ref.read(traceProvider.notifier).stop(),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              child: const Text('Stop'),
            )
          : FilledButton(
              onPressed: () => ref.read(traceProvider.notifier).run(_host.text.trim()),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              child: Text(trace.hops.isEmpty ? 'Trace' : 'Trace again'),
            ),
      children: [
        TextField(
          controller: _host,
          keyboardType: TextInputType.url,
          style: m.monoStyle(size: 15),
          decoration: InputDecoration(
            labelText: 'Destination',
            filled: true,
            fillColor: m.surface2,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(Meridian.rChip), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 14),
        if (trace.error != null) Text(trace.error!, style: TextStyle(color: m.bad)),
        if (trace.hops.isNotEmpty)
          ToolCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Column(
              children: [
                for (final (i, hop) in trace.hops.indexed) ...[
                  if (i > 0) Divider(height: 1, color: m.line),
                  _HopRow(hop: hop, isRouter: hop.address != null && hop.address == gateway),
                ],
              ],
            ),
          ),
        if (trace.running) const Padding(padding: EdgeInsets.only(top: 10), child: LinearProgressIndicator(minHeight: 2)),
        if (trace.reached)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text('Reached in ${trace.hops.length} hops.', style: TextStyle(fontWeight: FontWeight.w700, color: m.good)),
          ),
      ],
    );
  }
}

class _HopRow extends StatelessWidget {
  const _HopRow({required this.hop, required this.isRouter});

  final TraceHop hop;
  final bool isRouter;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final label = hop.reached
        ? 'Destination'
        : isRouter
            ? 'Your router'
            : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SizedBox(width: 32, child: Text('${hop.ttl}', style: m.monoStyle(size: 13, color: m.muted))),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(hop.address ?? 'No reply', style: m.monoStyle(size: 14, color: hop.address == null ? m.muted : m.text)),
                if (label != null) Text(label, style: TextStyle(fontSize: 12, color: hop.reached ? m.good : m.brand)),
              ],
            ),
          ),
          Text(hop.rttMs == null ? '' : '${hop.rttMs!.round()} ms', style: m.monoStyle(size: 13, color: m.muted)),
        ],
      ),
    );
  }
}
