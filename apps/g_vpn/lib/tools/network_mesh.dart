import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/meridian.dart';
import '../home/home_scan.dart' show identityProvider;
import '../i18n/strings.g.dart';
import '../vpn/vpn_controller.dart';
import 'device_memory.dart';
import 'devices_screen.dart';
import 'discovery.dart';
import 'lan.dart';

/// One node on the mesh, placed.
class _Node {
  _Node(this.device, this.kind, this.at, {required this.online, required this.lastSeen});

  final LanDevice device;
  final DeviceKind kind;
  final Offset at;
  final bool online;
  final DateTime? lastSeen;
}

/// The network as a living mesh: the router in the middle, the provider
/// above it, every device on a link around it. Links of online devices
/// carry moving pulses; devices that left hang on faded dashed links.
/// Closer to the router means it answers faster. Tap a node to open it.
class NetworkMesh extends ConsumerStatefulWidget {
  const NetworkMesh({super.key, required this.devices, required this.offline, required this.fresh, required this.network});

  final List<LanDevice> devices;
  final List<KnownDevice> offline;
  final Set<String> fresh;
  final String? network;

  @override
  ConsumerState<NetworkMesh> createState() => _NetworkMeshState();
}

class _NetworkMeshState extends ConsumerState<NetworkMesh> with SingleTickerProviderStateMixin {
  late final AnimationController _flow = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _flow.stop();
    } else if (!_flow.isAnimating) {
      _flow.repeat();
    }
  }

  @override
  void dispose() {
    _flow.dispose();
    super.dispose();
  }

  List<_Node> _layout(Size size, DeviceMemory? mem) {
    final centre = Offset(size.width / 2, size.height * .56);
    final reach = math.min(size.width / 2, size.height * .44) - 34;
    final around = [
      for (final d in widget.devices)
        if (!d.isRouter) (d, true, null as DateTime?),
      for (final k in widget.offline) (k.asLan, false, k.lastSeen),
    ];
    final nodes = <_Node>[];
    for (final (i, (d, online, seen)) in around.indexed) {
      // Spread over the circle, leaving the top free for the provider link.
      final angle = math.pi * (-.5 + (40 + 280 * (around.length == 1 ? .5 : i / (around.length - 1))) / 180);
      final speed = online ? (math.log(d.rttMs.clamp(1, 300)) / math.log(300)) : 1.0;
      final dist = reach * (online ? .48 + .44 * speed : .98);
      nodes.add(_Node(d, kindOf(d, mem, widget.network), centre + Offset(math.cos(angle), math.sin(angle)) * dist,
          online: online, lastSeen: seen));
    }
    return nodes;
  }

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final mem = ref.watch(deviceMemoryProvider).value;
    final names = ref.watch(deviceNamesProvider).value ?? const <String, String>{};
    final vpnOn = ref.watch(vpnProvider.select((s) => s.phase)) == VpnPhase.on;
    final provider = vpnOn ? t.devices.throughVpn : ref.watch(identityProvider).value?.org;
    final router = widget.devices.where((d) => d.isRouter).firstOrNull;

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: m.surface,
            borderRadius: BorderRadius.circular(Meridian.rCard),
            border: Border.all(color: m.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: AspectRatio(
            aspectRatio: .8,
            child: LayoutBuilder(builder: (context, box) {
              final size = box.biggest;
              final nodes = _layout(size, mem);
              return GestureDetector(
                onTapUp: (tap) {
                  _Node? hit;
                  var best = 32.0;
                  for (final n in nodes) {
                    final d = (n.at - tap.localPosition).distance;
                    if (d < best) {
                      best = d;
                      hit = n;
                    }
                  }
                  final target = hit?.device ??
                      (router != null && (Offset(size.width / 2, size.height * .56) - tap.localPosition).distance < 34
                          ? router
                          : null);
                  if (target == null) return;
                  Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => DeviceScreen(
                      device: target,
                      isNew: widget.fresh.contains(target.ip),
                      network: widget.network,
                      lastSeen: hit?.lastSeen,
                    ),
                  ));
                },
                child: Semantics(
                  label: t.devices.onlineCount(n: widget.devices.length),
                  child: AnimatedBuilder(
                    animation: _flow,
                    builder: (_, __) => CustomPaint(
                      size: size,
                      painter: _MeshPainter(
                        nodes: nodes,
                        m: m,
                        flow: _flow.value,
                        provider: provider,
                        fresh: widget.fresh,
                        labels: nodes.length <= 12,
                        names: {
                          for (final n in nodes) n.device.ip: deviceTitle(n.device, names[deviceKey(widget.network, n.device.ip)]),
                        },
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          runSpacing: 6,
          children: [
            _Legend(color: m.good, dashed: false, label: t.devices.online),
            _Legend(color: m.muted, dashed: true, label: t.devices.offlineHeading),
            Text(t.devices.closer, style: TextStyle(fontSize: 12, color: m.muted)),
          ],
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.dashed, required this.label});

  final Color color;
  final bool dashed;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 18,
            height: 2,
            child: dashed
                ? Row(children: [for (var i = 0; i < 3; i++) Expanded(child: Container(margin: const EdgeInsets.only(right: 2), color: color))])
                : Container(color: color),
          ),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, color: context.mer.muted)),
        ],
      );
}

class _MeshPainter extends CustomPainter {
  _MeshPainter({
    required this.nodes,
    required this.m,
    required this.flow,
    required this.provider,
    required this.fresh,
    required this.labels,
    required this.names,
  });

  final List<_Node> nodes;
  final Meridian m;
  final double flow;
  final String? provider;
  final Set<String> fresh;
  final bool labels;
  final Map<String, String> names;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height * .56);

    // The internet: the provider above the router.
    final top = Offset(size.width / 2, 40);
    final up = Path()
      ..moveTo(centre.dx, centre.dy - 30)
      ..lineTo(top.dx, top.dy + 18);
    canvas.drawPath(up, _line(m.good, 2.2));
    _pulses(canvas, up, m.text, reverse: true);
    final label = provider;
    if (label != null) {
      final tp = _text(label, 12, m.text, bold: true, maxWidth: size.width - 80);
      final box = Rect.fromCenter(center: top, width: tp.width + 32, height: 36);
      canvas.drawRRect(RRect.fromRectAndRadius(box, const Radius.circular(12)), Paint()..color = m.surface2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(box, const Radius.circular(12)),
        Paint()
          ..style = PaintingStyle.stroke
          ..color = m.line,
      );
      tp.paint(canvas, top - Offset(tp.width / 2, tp.height / 2));
    }

    // Links first, so nodes sit on top of them.
    for (final n in nodes) {
      final color = n.online ? deviceColor(n.kind, m) : m.muted;
      final bend = Offset(-(n.at.dy - centre.dy), n.at.dx - centre.dx) * .12;
      final mid = Offset.lerp(centre, n.at, .5)! + bend;
      final path = Path()
        ..moveTo(centre.dx, centre.dy)
        ..quadraticBezierTo(mid.dx, mid.dy, n.at.dx, n.at.dy);
      if (n.online) {
        canvas.drawPath(path, _line(color.withValues(alpha: .5), 2));
        _pulses(canvas, path, color);
      } else {
        _dashed(canvas, path, _line(m.muted.withValues(alpha: .5), 1.4));
      }
    }

    // The router.
    canvas.drawCircle(centre, 30 + 6 * (1 - (flow * 2 % 1)), Paint()..color = m.good.withValues(alpha: .12));
    canvas.drawCircle(centre, 30, Paint()..color = m.good);
    _icon(canvas, Icons.router_outlined, centre, 26, m.bg);

    for (final n in nodes) {
      final color = n.online ? deviceColor(n.kind, m) : m.muted;
      final glow = n.online && (fresh.contains(n.device.ip) || n.device.isSelf);
      if (glow) {
        final p = flow;
        canvas.drawCircle(n.at, 22 + 14 * p, Paint()..color = color.withValues(alpha: .35 * (1 - p)));
      }
      canvas.drawCircle(n.at, 21, Paint()..color = m.bg);
      canvas.drawCircle(n.at, 19, Paint()..color = color.withValues(alpha: n.online ? .2 : .1));
      canvas.drawCircle(
        n.at,
        21,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color.withValues(alpha: n.online ? 1 : .4),
      );
      _icon(canvas, deviceIcon(n.kind), n.at, 18, color.withValues(alpha: n.online ? 1 : .5));
      if (labels || glow) {
        final tp = _text(names[n.device.ip] ?? n.device.ip, 11, n.online ? m.text : m.muted, bold: true, maxWidth: 96);
        tp.paint(canvas, n.at + Offset(-tp.width / 2, 25));
      }
    }
  }

  Paint _line(Color c, double w) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..color = c;

  /// Dots travelling along [path]: traffic, drawn as a feeling not a figure.
  void _pulses(Canvas canvas, Path path, Color color, {bool reverse = false}) {
    for (final metric in path.computeMetrics()) {
      for (var k = 0; k < 2; k++) {
        var f = (flow + k * .5) % 1;
        if (reverse) f = 1 - f;
        final at = metric.getTangentForOffset(metric.length * f)?.position;
        if (at != null) canvas.drawCircle(at, 2.6, Paint()..color = color);
      }
    }
  }

  void _dashed(Canvas canvas, Path path, Paint paint) {
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 9) {
        canvas.drawPath(metric.extractPath(d, math.min(d + 4, metric.length)), paint);
      }
    }
  }

  void _icon(Canvas canvas, IconData icon, Offset at, double size, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(fontSize: size, fontFamily: icon.fontFamily, package: icon.fontPackage, color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
  }

  TextPainter _text(String s, double size, Color color, {bool bold = false, double maxWidth = 120}) => TextPainter(
        text: TextSpan(
          text: s,
          style: TextStyle(fontSize: size, fontWeight: bold ? FontWeight.w800 : FontWeight.w500, color: color, fontFamily: Meridian.sans),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        textAlign: TextAlign.center,
      )..layout(maxWidth: maxWidth);

  @override
  bool shouldRepaint(_MeshPainter old) => true;
}
