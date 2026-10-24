import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'meridian.dart';

enum WaveMood { exposed, securing, secure }

/// One side of the hero. The LEFT side is the user's raw traffic and is
/// always [WaveMood.exposed]; the RIGHT side is what leaves the tunnel and
/// changes mood with the connection. Both flow left to right, through the
/// button, which is the whole metaphor.
class MeridianWaves extends StatefulWidget {
  const MeridianWaves({super.key, required this.mood, required this.fadeFromLeft, this.height = 72});

  final WaveMood mood;

  /// Which outer edge fades out: the screen edge, never the button side.
  final bool fadeFromLeft;
  final double height;

  @override
  State<MeridianWaves> createState() => _MeridianWavesState();
}

class _MeridianWavesState extends State<MeridianWaves> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 4));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) => LinearGradient(
        begin: widget.fadeFromLeft ? Alignment.centerLeft : Alignment.centerRight,
        end: widget.fadeFromLeft ? Alignment.centerRight : Alignment.centerLeft,
        colors: const [Colors.transparent, Colors.black],
        stops: const [0, .55],
      ).createShader(rect),
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, child) => CustomPaint(
            size: Size(double.infinity, widget.height),
            painter: _WavePainter(mood: widget.mood, t: _c.value, m: m),
          ),
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({required this.mood, required this.t, required this.m});

  final WaveMood mood;
  final double t;
  final Meridian m;

  /// A fixed restless pattern, 4 points per 40 px, so a 40 px shift loops.
  /// Speeds are WHOLE loops per 4 s controller cycle: a fraction would jump
  /// every time the controller wraps.
  static const _jag = [-.9, .55, -.35, 0.0];
  static const _jag2 = [.6, -.8, .3, 0.0];

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height / 2;
    switch (mood) {
      case WaveMood.exposed:
        // Unencrypted traffic: jagged and red.
        _zigzag(canvas, size, mid, size.height * .36, _jag, m.bad, 1.8, .85, speed: 6);
        _zigzag(canvas, size, mid, size.height * .24, _jag2, m.bad, 1.1, .4, speed: 4);
      case WaveMood.securing:
        _sine(canvas, size, mid, size.height * .26, m.warn, 2.2, 1, speed: 10);
      case WaveMood.secure:
        _sine(canvas, size, mid, size.height * .34, m.goodWave, 2.4, 1, speed: 4);
        _sine(canvas, size, mid, size.height * .2, m.goodWave, 1.5, .5, speed: 3);
        _sine(canvas, size, mid, size.height * .46, m.brand, 1.1, .35, speed: 2);
    }
  }

  void _zigzag(Canvas canvas, Size size, double mid, double amp, List<double> ys, Color color, double width,
      double alpha, {required int speed}) {
    final shift = (t * speed * 40) % 40;
    final path = Path()..moveTo(-40 + shift, mid);
    for (var x = -40.0; x < size.width + 40; x += 40) {
      for (var i = 0; i < 4; i++) {
        path.lineTo(x + (i + 1) * 10 + shift, mid + ys[i] * amp);
      }
    }
    _stroke(canvas, path, color, width, alpha);
  }

  void _sine(Canvas canvas, Size size, double mid, double amp, Color color, double width, double alpha,
      {required int speed}) {
    final shift = (t * speed * 40) % 40;
    final path = Path();
    for (var x = -40.0; x <= size.width + 40; x += 2) {
      final y = mid + math.sin((x - shift) / 40 * 2 * math.pi) * amp;
      if (x == -40) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    _stroke(canvas, path, color, width, alpha);
  }

  void _stroke(Canvas canvas, Path path, Color color, double width, double alpha) => canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = color.withValues(alpha: alpha),
      );

  @override
  bool shouldRepaint(_WavePainter old) => old.t != t || old.mood != mood || old.m != m;
}
