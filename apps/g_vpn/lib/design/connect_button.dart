import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../../../../i18n/strings.g.dart';
import '../vpn/vpn_controller.dart';
import 'meridian.dart';

/// The round button at the centre of the globe. Ringed red while exposed,
/// a spinning amber arc while connecting, solid green with a slow halo once
/// protected.
class ConnectButton extends StatefulWidget {
  const ConnectButton({super.key, required this.phase, required this.onTap, this.size = 120});

  final VpnPhase phase;
  final VoidCallback? onTap;
  final double size;

  @override
  State<ConnectButton> createState() => _ConnectButtonState();
}

class _ConnectButtonState extends State<ConnectButton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));

  bool get _moving => widget.phase != VpnPhase.off;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(ConnectButton old) {
    super.didUpdateWidget(old);
    _sync();
  }

  /// Idle while exposed: nothing animates on a screen the user is not
  /// interacting with, apart from the waves.
  void _sync() {
    final run = _moving && !MediaQuery.disableAnimationsOf(context);
    if (run && !_c.isAnimating) _c.repeat();
    if (!run && _c.isAnimating) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final on = widget.phase == VpnPhase.on;
    final busy = widget.phase == VpnPhase.connecting || widget.phase == VpnPhase.disconnecting;
    final fg = on ? m.onButtonOn : busy ? m.warn : m.brand;
    final label = switch (widget.phase) {
      VpnPhase.on => t.button.stop,
      VpnPhase.connecting => t.button.connecting,
      VpnPhase.disconnecting => t.button.stopping,
      VpnPhase.off => t.button.connect,
    };

    return Semantics(
      button: true,
      label: on ? t.button.disconnect : t.button.connect,
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, child) => CustomPaint(
            painter: _RingPainter(phase: widget.phase, t: _c.value, m: m),
            child: child,
          ),
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              width: widget.size * .84,
              height: widget.size * .84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: on ? m.buttonOn : m.buttonOff,
                boxShadow: [BoxShadow(color: m.shadow, blurRadius: 30, offset: const Offset(0, 14), spreadRadius: -12)],
              ),
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: widget.onTap,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.power_settings_new_rounded, size: widget.size * .3, color: fg),
                      const SizedBox(height: 2),
                      Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.phase, required this.t, required this.m});

  final VpnPhase phase;
  final double t;
  final Meridian m;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 2;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    switch (phase) {
      case VpnPhase.off:
        canvas.drawCircle(c, r, ring..color = m.bad);
      case VpnPhase.connecting || VpnPhase.disconnecting:
        canvas.drawCircle(c, r, ring..color = m.line);
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: r),
          t * 2 * math.pi * 3,
          math.pi / 2.5,
          false,
          ring
            ..color = m.warn
            ..strokeCap = StrokeCap.round,
        );
      case VpnPhase.on:
        // Two halos, half a cycle apart.
        for (final offset in [0.0, .5]) {
          final k = (t + offset) % 1;
          canvas.drawCircle(c, r * (.9 + .5 * k), Paint()..color = m.good.withValues(alpha: .35 * (1 - k)));
        }
        canvas.drawCircle(c, r, ring..color = m.good);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.t != t || old.phase != phase || old.m != m;
}
