import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'meridian.dart';
import 'world_dots.dart';

@immutable
class LatLon {
  const LatLon(this.lat, this.lon);

  final double lat;
  final double lon;

  @override
  bool operator ==(Object other) => other is LatLon && other.lat == lat && other.lon == lon;

  @override
  int get hashCode => Object.hash(lat, lon);
}

/// The full-page Meridian map: a flat dotted world behind the whole home
/// screen, pinned so that the USER'S location sits exactly under the
/// connect button. The button is "you"; the waves come out of you.
///
/// While connecting, the map scrolls sideways like a spinning globe. Once
/// protected it TRAVELS: the view flies to the server's country, so the
/// button now sits where your traffic comes out, with a dashed arc back to
/// your real location. Disconnecting flies home.
///
/// COST: ~3,700 dots in one drawRawPoints call per frame, only while
/// something moves; tickers mute offstage, in the background, and under
/// "remove animations".
class MeridianWorldMap extends StatefulWidget {
  const MeridianWorldMap({
    super.key,
    required this.anchor,
    required this.scrolling,
    this.user,
    this.server,
    this.userColor,
  });

  /// Where the user's location is drawn, in this widget's coordinates.
  final Offset anchor;
  final bool scrolling;
  final LatLon? user;
  final LatLon? server;
  final Color? userColor;

  /// Pixels per degree at rest: the whole region around you.
  static const scale = 4.0;

  /// Pixels per degree once protected: zoomed in on the server's country.
  static const zoomedScale = 9.0;

  @override
  State<MeridianWorldMap> createState() => _MeridianWorldMapState();
}

class _MeridianWorldMapState extends State<MeridianWorldMap> with TickerProviderStateMixin {
  late final AnimationController _scroll =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));
  late final AnimationController _settle =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));

  /// Longitude and latitude currently under the anchor.
  double _lon = 20;
  double _lat = 5;
  double _scrollFrom = 20;
  double _from = 20;
  double _to = 20;
  double _fromLat = 5;
  double _toLat = 5;
  double _k = MeridianWorldMap.scale;
  double _fromK = MeridianWorldMap.scale;
  double _toK = MeridianWorldMap.scale;

  static final Float32List _dots = Float32List.fromList([for (final v in worldDots) v / 10]);

  /// Where the view should rest: the server once protected, else home.
  LatLon get _focus => widget.server ?? widget.user ?? const LatLon(5, 20);

  /// Zoomed in on the server while protected, out again at home.
  double get _focusK => widget.server != null ? MeridianWorldMap.zoomedScale : MeridianWorldMap.scale;

  @override
  void initState() {
    super.initState();
    _lon = _from = _to = _focus.lon;
    _lat = _fromLat = _toLat = _focus.lat;
    _k = _fromK = _toK = _focusK;
    _scroll.addListener(_tick);
    _settle.addListener(_tick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(MeridianWorldMap old) {
    super.didUpdateWidget(old);
    final moved = old.user != widget.user || old.server != widget.server;
    if (!widget.scrolling && old.scrolling) {
      _scroll.stop();
      _goTo(_focus);
    } else if (!widget.scrolling && moved) {
      _goTo(_focus);
    }
    _sync();
  }

  void _sync() {
    final still = MediaQuery.disableAnimationsOf(context);
    final pinned = widget.user != null || widget.server != null;
    if (!still && pinned && !_pulse.isAnimating) _pulse.repeat();
    if ((still || !pinned) && _pulse.isAnimating) _pulse.stop();
    if (!still && widget.scrolling && !_scroll.isAnimating) {
      _scrollFrom = _lon;
      _scroll.repeat();
    }
    if (still && _scroll.isAnimating) _scroll.stop();
  }

  /// Shortest way round the world to [target], latitude included.
  void _goTo(LatLon target) {
    _from = _lon;
    var delta = (target.lon - _lon) % 360;
    if (delta > 180) delta -= 360;
    _to = _lon + delta;
    _fromLat = _lat;
    _toLat = target.lat;
    _fromK = _k;
    _toK = _focusK;
    if (MediaQuery.disableAnimationsOf(context)) {
      _lon = _to;
      _lat = _toLat;
      _k = _toK;
      setState(() {});
      return;
    }
    _settle.forward(from: 0);
  }

  void _tick() {
    if (_scroll.isAnimating) {
      // One full trip round the world per cycle, travelling east.
      _lon = _scrollFrom + _scroll.value * 360;
      return;
    }
    // A flight, not a jump: ease in and out so departure and arrival both read.
    final t = Curves.easeInOutCubic.transform(_settle.value);
    _lon = ui.lerpDouble(_from, _to, t)!;
    _lat = ui.lerpDouble(_fromLat, _toLat, t)!;
    _k = ui.lerpDouble(_fromK, _toK, t)!;
  }

  @override
  void dispose() {
    _scroll.dispose();
    _settle.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_scroll, _settle, _pulse]),
        builder: (context, child) => CustomPaint(
          size: Size.infinite,
          painter: _MapPainter(
            dots: _dots,
            lon: _lon,
            anchor: widget.anchor,
            anchorLat: _lat,
            k: _k,
            m: m,
            user: widget.scrolling ? null : widget.user,
            server: widget.scrolling ? null : widget.server,
            userColor: widget.userColor ?? m.bad,
            pulse: _pulse.value,
          ),
        ),
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  _MapPainter({
    required this.dots,
    required this.lon,
    required this.anchor,
    required this.anchorLat,
    required this.m,
    required this.user,
    required this.server,
    required this.userColor,
    required this.pulse,
    required this.k,
  });

  final Float32List dots;
  final double lon;
  final Offset anchor;
  final double anchorLat;
  final Meridian m;
  final LatLon? user;
  final LatLon? server;
  final Color userColor;
  final double pulse;

  /// Pixels per degree for this frame (animates during the zoom).
  final double k;

  double get worldWidth => 360 * k;

  /// Equirectangular, wrapped so the world tiles sideways while scrolling.
  Offset _at(double lat, double lng) {
    var x = anchor.dx + (lng - lon) * k;
    x = ((x % worldWidth) + worldWidth) % worldWidth;
    if (x > anchor.dx + worldWidth / 2) x -= worldWidth;
    return Offset(x, anchor.dy - (lat - anchorLat) * k);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final pts = Float32List(dots.length * 2);
    var n = 0;
    for (var i = 0; i < dots.length; i += 2) {
      final p = _at(dots[i], dots[i + 1]);
      // Each dot can appear twice when the wrap seam is on screen.
      for (final dx in [0.0, -worldWidth, worldWidth]) {
        final x = p.dx + dx;
        if (x < -4 || x > size.width + 4 || p.dy < -4 || p.dy > size.height + 4) continue;
        if (n + 2 > pts.length) break;
        pts[n++] = x;
        pts[n++] = p.dy;
      }
    }
    canvas.drawRawPoints(
      ui.PointMode.points,
      Float32List.sublistView(pts, 0, n),
      Paint()
        ..strokeCap = StrokeCap.round
        // Dots grow with the zoom so the country reads as land, not dust.
        ..strokeWidth = 3.2 * (k / MeridianWorldMap.scale).clamp(1.0, 2.2)
        ..color = m.dot.withValues(alpha: .55),
    );

    final u = user, s = server;
    if (u != null && s != null) _arc(canvas, _at(u.lat, u.lon), _at(s.lat, s.lon));
    if (s != null) _pin(canvas, _at(s.lat, s.lon), m.good);
    if (u != null) _pin(canvas, _at(u.lat, u.lon), userColor);
  }

  void _pin(Canvas canvas, Offset at, Color color) {
    canvas.drawCircle(at, 6 * (1 + 2 * pulse), Paint()..color = color.withValues(alpha: (1 - pulse) * .5));
    canvas.drawCircle(at, 8, Paint()..color = m.bg);
    canvas.drawCircle(at, 6, Paint()..color = color);
  }

  /// A gentle bow between the two pins, dashed, with the dashes travelling
  /// from the user to the server.
  void _arc(Canvas canvas, Offset a, Offset b) {
    final mid = Offset.lerp(a, b, .5)!;
    final normal = Offset(-(b.dy - a.dy), b.dx - a.dx);
    final len = normal.distance;
    if (len < 1) return;
    final control = mid + normal / len * math.min(80, len * .25);
    final path = Path()
      ..moveTo(a.dx, a.dy)
      ..quadraticBezierTo(control.dx, control.dy, b.dx, b.dy);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = m.good;
    const dash = 5.0, gap = 6.0;
    for (final metric in path.computeMetrics()) {
      var d = pulse * (dash + gap) * 3 - (dash + gap) * 3;
      while (d < metric.length) {
        if (d + dash > 0) canvas.drawPath(metric.extractPath(math.max(0, d), d + dash), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_MapPainter old) =>
      old.lon != lon ||
      old.k != k ||
      old.anchorLat != anchorLat ||
      old.pulse != pulse ||
      old.anchor != anchor ||
      old.user != user ||
      old.server != server ||
      old.m != m;
}
