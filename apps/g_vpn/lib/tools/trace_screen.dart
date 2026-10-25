import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/meridian.dart';
import '../i18n/strings.g.dart';
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
    final steps = _Step.fromHops(trace.hops);
    final total = trace.hops.lastWhere((h) => h.rttMs != null, orElse: () => TraceHop(ttl: 0, reached: false)).rttMs;
    final slowest = _Step.slowestJump(steps);

    return ToolPage(
      title: t.trace.title,
      info: t.trace.info,
      action: trace.running
          ? OutlinedButton(
              onPressed: () => ref.read(traceProvider.notifier).stop(),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              child: Text(t.trace.stop),
            )
          : FilledButton(
              onPressed: () {
                FocusScope.of(context).unfocus();
                ref.read(traceProvider.notifier).run(_host.text.trim());
              },
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              child: Text(trace.hops.isEmpty ? t.trace.trace : t.trace.again),
            ),
      children: [
        TextField(
          controller: _host,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.go,
          onSubmitted: (v) => ref.read(traceProvider.notifier).run(v.trim()),
          style: m.monoStyle(size: 15),
          decoration: InputDecoration(
            labelText: t.trace.destination,
            filled: true,
            fillColor: m.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: m.line)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: m.line)),
          ),
        ),
        if (trace.hops.isNotEmpty) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _Stat(label: t.trace.hops, value: '${trace.hops.length}')),
              const SizedBox(width: 8),
              Expanded(child: _Stat(label: t.trace.answered, value: '${trace.hops.where((h) => h.address != null).length}')),
              const SizedBox(width: 8),
              Expanded(child: _Stat(label: t.trace.total, value: total == null ? '--' : t.trace.ms(n: total.round()))),
            ],
          ),
          const SizedBox(height: 14),
          ToolCard(
            child: Column(
              children: [
                _Node(kind: _NodeKind.start, title: t.trace.thisPhone, last: false),
                for (final (i, s) in steps.indexed)
                  _Node(
                    kind: s.silent > 0
                        ? _NodeKind.silent
                        : s.hop!.reached
                            ? _NodeKind.end
                            : identical(s, slowest)
                                ? _NodeKind.slow
                                : _NodeKind.hop,
                    title: s.silent > 0
                        ? (s.silent == 1 ? t.trace.silentOne : t.trace.silentMany(n: s.silent))
                        : s.hop!.reached
                            ? _host.text.trim()
                            : s.hop!.address == gateway
                                ? t.trace.yourRouter
                                : t.trace.hop(n: s.hop!.ttl),
                    address: s.hop?.address,
                    ms: s.hop?.rttMs,
                    jump: identical(s, slowest) ? s.jump : null,
                    last: i == steps.length - 1,
                  ),
              ],
            ),
          ),
          if (trace.running) const Padding(padding: EdgeInsets.only(top: 10), child: LinearProgressIndicator(minHeight: 2)),
          if (slowest != null && !trace.running && slowest.jump! >= 30) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: m.warnSoft, borderRadius: BorderRadius.circular(16)),
              child: Text(
                t.trace.slowest(ms: slowest.jump!.round(), hop: slowest.hop!.ttl),
                style: TextStyle(fontSize: 14, height: 1.45, fontWeight: FontWeight.w600, color: m.warn),
              ),
            ),
          ],
        ],
        if (trace.error != null) ...[
          const SizedBox(height: 10),
          Text(trace.error!, style: TextStyle(color: m.bad)),
        ],
      ],
    );
  }
}

/// A hop that answered, or a run of silent hops folded into one line.
class _Step {
  _Step.hop(this.hop, this.jump) : silent = 0;
  _Step.silent(this.silent)
      : hop = null,
        jump = null;

  final TraceHop? hop;
  final int silent;

  /// Delay added since the previous answering hop.
  final double? jump;

  static List<_Step> fromHops(List<TraceHop> hops) {
    final out = <_Step>[];
    double? prev;
    var silent = 0;
    for (final h in hops) {
      if (h.address == null) {
        silent++;
        continue;
      }
      if (silent > 0) out.add(_Step.silent(silent));
      silent = 0;
      final ms = h.rttMs;
      out.add(_Step.hop(h, ms != null && prev != null ? ms - prev : null));
      if (ms != null) prev = ms;
    }
    if (silent > 0) out.add(_Step.silent(silent));
    return out;
  }

  static _Step? slowestJump(List<_Step> steps) {
    _Step? best;
    for (final s in steps) {
      if (s.jump != null && (best == null || s.jump! > best.jump!)) best = s;
    }
    return best;
  }
}

enum _NodeKind { start, hop, slow, silent, end }

class _Node extends StatelessWidget {
  const _Node({required this.kind, required this.title, this.address, this.ms, this.jump, required this.last});

  final _NodeKind kind;
  final String title;
  final String? address;
  final double? ms;
  final double? jump;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final color = switch (kind) {
      _NodeKind.slow => m.warn,
      _NodeKind.end => m.good,
      _NodeKind.silent => m.muted,
      _ => m.brand,
    };
    final dot = switch (kind) {
      _NodeKind.start => Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(color: m.brand, shape: BoxShape.circle),
          child: Icon(Icons.smartphone_rounded, size: 13, color: m.onBrand),
        ),
      _NodeKind.end => Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(color: m.good, shape: BoxShape.circle),
          child: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
        ),
      _ => Container(
          width: 14,
          height: 14,
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: m.surface,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: kind == _NodeKind.silent ? 2 : 3),
          ),
        ),
    };
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 22,
            child: Column(
              children: [
                dot,
                if (!last) Expanded(child: Container(width: 2, color: m.brandSoft)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 14, top: 1),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: kind == _NodeKind.end ? FontWeight.w800 : FontWeight.w700,
                            color: kind == _NodeKind.silent ? m.muted : kind == _NodeKind.end ? m.good : m.text,
                          ),
                        ),
                        if (address != null && kind != _NodeKind.silent)
                          Text(address!, style: m.monoStyle(size: 12, color: m.muted)),
                      ],
                    ),
                  ),
                  if (jump != null)
                    Text('+${jump!.round()} ms', style: m.monoStyle(size: 13, color: m.warn))
                  else if (ms != null)
                    Text('${ms!.round()} ms', style: m.monoStyle(size: 13, color: m.text)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    return ToolCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: .5, color: m.muted)),
          Text(value, style: m.monoStyle(size: 17)),
        ],
      ),
    );
  }
}
