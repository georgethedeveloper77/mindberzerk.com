import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'country_shapes.dart';
import 'meridian.dart';
import 'world_map.dart' show LatLon;

/// What the map is telling the user.
enum MapMood {
  /// Spotlight on the user's own country, red pulse on their location.
  exposed,

  /// Same framing, amber pulse while the tunnel comes up.
  connecting,

  /// Framed on the server's region, green pulse on the server, free
  /// servers nearby as dots.
  protected,
}

/// Mercator in degrees: x is longitude, y is the Mercator ordinate scaled
/// to degrees so both axes share one zoom factor.
double mercY(double lat) {
  final phi = lat.clamp(-85.0, 85.0) * math.pi / 180;
  return math.log(math.tan(math.pi / 4 + phi / 2)) * 180 / math.pi;
}

/// Inverse of [mercY].
double mercLat(double y) => (2 * math.atan(math.exp(y * math.pi / 180)) - math.pi / 2) * 180 / math.pi;

/// Where the map looks: the point under [anchor] and the zoom.
@immutable
class MapCamera {
  const MapCamera({required this.lon, required this.y, required this.k});

  /// Longitude and Mercator ordinate under the anchor.
  final double lon;
  final double y;

  /// Pixels per degree.
  final double k;

  static const minK = 1.0;
  static const maxK = 26.0;

  /// Frames [bounds] inside [frame], clamped to a sane zoom.
  factory MapCamera.fit(GeoBounds bounds, Rect frame) {
    final top = mercY(bounds.north), bottom = mercY(bounds.south);
    final k = math.min(frame.width / bounds.width, frame.height / (top - bottom));
    return MapCamera(lon: bounds.centerLon, y: (top + bottom) / 2, k: k.clamp(minK, maxK));
  }

  /// Screen position of [lon], [lat] with this camera centred on [anchor].
  Offset project(double lon, double lat, Offset anchor) =>
      Offset(anchor.dx + (lon - this.lon) * k, anchor.dy - (mercY(lat) - y) * k);

  @override
  bool operator ==(Object other) => other is MapCamera && other.lon == lon && other.y == y && other.k == k;

  @override
  int get hashCode => Object.hash(lon, y, k);
}

/// The box the camera should frame for a country, widened to at least
/// [minSpan] degrees of longitude so small countries keep their neighbours.
@visibleForTesting
GeoBounds framingFor({String? country, LatLon? point, required double minSpan}) {
  final shape = CountryShapes.instance[country];
  var box = shape?.focus ??
      (point == null
          ? const GeoBounds(-170, -50, 180, 72)
          : GeoBounds(point.lon - 6, point.lat - 6, point.lon + 6, point.lat + 6));

  // A pin outside its country's mainland (an island, an exclave) still has
  // to be on screen.
  if (point != null && shape != null && !box.contains(point.lon, point.lat)) {
    box = GeoBounds(
      math.min(box.west, point.lon),
      math.min(box.south, point.lat),
      math.max(box.east, point.lon),
      math.max(box.north, point.lat),
    );
  }

  // Breathing room on every side, then the minimum span.
  box = box.inflate(math.max(1.5, box.width * .18));
  if (box.width < minSpan) {
    final pad = (minSpan - box.width) / 2;
    box = GeoBounds(box.west - pad, box.south - pad * .6, box.east + pad, box.north + pad * .6);
  }
  return box;
}

/// The Meridian home map: real country outlines (Natural Earth) drawn as a
/// halftone over a faint graticule, on the phone with no tiles, keys or
/// network.
///
/// Exposed, the user's country lights up in red dots with a sight-style
/// pin on their location. Protected, the map flies to the server's region,
/// that country lights up green, a dashed route runs back to the user, and
/// nearby free servers show as rings. Flights zoom out mid-way when the
/// distance is long, so departure and arrival both read.
///
/// COST: the visible countries' cached paths, transformed once per frame
/// and filled with a cached halftone tile, only while something moves.
/// Under "remove animations" the camera jumps and nothing pulses.
class CountryMap extends StatelessWidget {
  const CountryMap({
    super.key,
    required this.mood,
    this.you,
    this.youCountry,
    this.server,
    this.serverCountry,
    this.dots = const [],
    this.framePadding = EdgeInsets.zero,
    this.span,
    this.pulse = true,
  });

  final MapMood mood;

  /// The user's real location and country (ISO alpha-2).
  final LatLon? you;
  final String? youCountry;

  /// Where the traffic comes out, once protected.
  final LatLon? server;
  final String? serverCountry;

  /// Free servers to mark while protected.
  final List<LatLon> dots;

  /// Insets where overlays sit; the subject is framed inside the rest.
  final EdgeInsets framePadding;

  /// Minimum framed span in degrees of longitude. Defaults to a country
  /// close-up when exposed and a whole region when protected.
  final double? span;

  final bool pulse;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, box) => _MapView(
          size: box.biggest,
          frame: framePadding.deflateRect(Offset.zero & box.biggest),
          map: this,
        ),
      );
}

class _MapView extends StatefulWidget {
  const _MapView({required this.size, required this.frame, required this.map});

  final Size size;
  final Rect frame;
  final CountryMap map;

  @override
  State<_MapView> createState() => _MapViewState();
}

class _MapViewState extends State<_MapView> with TickerProviderStateMixin {
  late final AnimationController _flight =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..addListener(_tick);
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));

  late MapCamera _camera = _target();
  late MapCamera _from = _camera;
  late MapCamera _to = _camera;

  /// Zoom at the top of a long flight.
  double _peakK = MapCamera.maxK;

  bool get _still => MediaQuery.disableAnimationsOf(context);

  MapCamera _target() {
    final map = widget.map;
    final protected = map.mood == MapMood.protected && map.server != null;
    final bounds = protected
        ? framingFor(country: map.serverCountry, point: map.server, minSpan: map.span ?? 34)
        : framingFor(country: map.youCountry, point: map.you, minSpan: map.span ?? 14);
    return MapCamera.fit(bounds, widget.frame);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPulse();
  }

  @override
  void didUpdateWidget(_MapView old) {
    super.didUpdateWidget(old);
    final next = _target();
    if (next != _to) _flyTo(next);
    _syncPulse();
  }

  void _flyTo(MapCamera target) {
    // Shortest way round the world.
    var delta = (target.lon - _camera.lon) % 360;
    if (delta > 180) delta -= 360;
    _from = _camera;
    _to = MapCamera(lon: _camera.lon + delta, y: target.y, k: target.k);
    if (_still) {
      setState(() => _camera = _to);
      return;
    }
    // Zoom out enough mid-flight to keep both ends in view.
    final travel = delta.abs() + (target.y - _camera.y).abs();
    final fit = widget.frame.width / (travel + 20);
    _peakK = math.min(math.min(_from.k, _to.k), fit).clamp(MapCamera.minK, MapCamera.maxK);
    _flight.forward(from: 0);
  }

  void _tick() {
    final t = Curves.easeInOutCubic.transform(_flight.value);
    double logLerp(double a, double b, double u) => math.exp(ui.lerpDouble(math.log(a), math.log(b), u)!);
    final k = t < .5 ? logLerp(_from.k, _peakK, t * 2) : logLerp(_peakK, _to.k, t * 2 - 1);
    setState(() {
      _camera = MapCamera(
        lon: ui.lerpDouble(_from.lon, _to.lon, t)!,
        y: ui.lerpDouble(_from.y, _to.y, t)!,
        k: k,
      );
    });
  }

  void _syncPulse() {
    final want = widget.map.pulse && !_still;
    if (want && !_pulse.isAnimating) _pulse.repeat();
    if (!want && _pulse.isAnimating) _pulse.stop();
  }

  @override
  void dispose() {
    _flight.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final map = widget.map;
    final m = context.mer;
    final (pinColor, pin, highlight) = switch (map.mood) {
      MapMood.exposed => (m.bad, map.you, map.youCountry),
      MapMood.connecting => (m.warn, map.you, map.youCountry),
      MapMood.protected when map.server != null => (m.good, map.server, map.serverCountry),
      MapMood.protected => (m.bad, map.you, map.youCountry),
    };
    final protected = map.mood == MapMood.protected && map.server != null;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) => CustomPaint(
          size: widget.size,
          painter: _CountryPainter(
            camera: _camera,
            anchor: widget.frame.center,
            m: m,
            dpr: MediaQuery.devicePixelRatioOf(context),
            highlight: highlight?.toUpperCase(),
            highlightColor: pinColor,
            pin: pin,
            pinColor: pinColor,
            origin: protected ? map.you : null,
            dots: protected ? map.dots : const [],
            pulse: map.pulse ? _pulse.value : null,
          ),
        ),
      ),
    );
  }
}

/// The Meridian look: land as a halftone of dots rather than flat fills,
/// a faint graticule of meridians and parallels, the spotlit country in
/// denser coloured dots with a soft glow on its edge, and a reticle pin.
class _CountryPainter extends CustomPainter {
  _CountryPainter({
    required this.camera,
    required this.anchor,
    required this.m,
    required this.dpr,
    required this.highlight,
    required this.highlightColor,
    required this.pin,
    required this.pinColor,
    required this.origin,
    required this.dots,
    required this.pulse,
  });

  final MapCamera camera;
  final Offset anchor;
  final Meridian m;

  /// Device pixel ratio, so halftone tiles are drawn at full resolution.
  final double dpr;

  final String? highlight;
  final Color highlightColor;
  final LatLon? pin;
  final Color pinColor;

  /// The user's real location while protected: the start of the route arc.
  final LatLon? origin;

  final List<LatLon> dots;

  /// 0 to 1 through the pulse cycle; null draws a still pin.
  final double? pulse;

  /// Halftone pitch and dot radii, in logical pixels.
  static const _pitch = 5.0;
  static const _landDot = 1.05;
  static const _spotDot = 1.55;

  /// Graticule spacing in degrees.
  static const _grid = 15.0;

  /// Outlines in (longitude, Mercator degrees), built once per country and
  /// shared by every map on screen.
  static final Map<String, Path> _paths = {};

  /// One halftone tile per colour and dot size.
  static final Map<String, ui.Image> _tiles = {};

  static Path _pathFor(CountryShape c) =>
      _paths.putIfAbsent(c.code, () => c.toPath((lon, lat) => Offset(lon, mercY(lat))));

  /// A repeating tile of one dot, drawn at [dpr] so it stays crisp.
  ui.Image _tile(Color color, double radius) {
    final key = '${color.toARGB32()}:$radius:$dpr';
    return _tiles.putIfAbsent(key, () {
      final side = _pitch * dpr;
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawCircle(Offset(side / 2, side / 2), radius * dpr, Paint()..color = color);
      final picture = recorder.endRecording();
      final image = picture.toImageSync(side.round(), side.round());
      picture.dispose();
      return image;
    });
  }

  /// A fill that paints the halftone, locked to the map so the dots travel
  /// with the land while it pans.
  Paint _halftone(Color color, double radius, Offset shift) {
    final s = 1 / dpr;
    final matrix = Float64List.fromList([
      s, 0, 0, 0, //
      0, s, 0, 0,
      0, 0, 1, 0,
      shift.dx % _pitch, shift.dy % _pitch, 0, 1,
    ]);
    return Paint()
      ..shader = ui.ImageShader(_tile(color, radius), TileMode.repeated, TileMode.repeated, matrix)
      ..filterQuality = FilterQuality.none;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final k = camera.k;
    final west = camera.lon - anchor.dx / k;
    final east = camera.lon + (size.width - anchor.dx) / k;
    final north = mercLat(camera.y + anchor.dy / k);
    final south = mercLat(camera.y - (size.height - anchor.dy) / k);

    _graticule(canvas, size, west, east, south, north);

    // The world's origin on screen, which the halftone is locked to.
    final worldShift = Offset(anchor.dx - camera.lon * k, anchor.dy + camera.y * k);
    final tint = Paint()..color = m.globe.withValues(alpha: .55);
    final dotsPaint = _halftone(m.dot.withValues(alpha: .5), _landDot, worldShift);
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .6
      ..color = m.dot.withValues(alpha: .22);
    final spotDots = _halftone(highlightColor, _spotDot, worldShift);
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
      ..color = highlightColor.withValues(alpha: .55);
    final spotEdge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 1.3
      ..color = highlightColor.withValues(alpha: .9);

    // The world repeats sideways, so a view across the date line draws the
    // neighbouring copy too.
    final spots = <Path>[];
    for (final shift in const [-360.0, 0.0, 360.0]) {
      final view = GeoBounds(west - shift, south, east - shift, north);
      if (view.east < -180 || view.west > 180) continue;
      final toScreen = Float64List.fromList([
        k, 0, 0, 0, //
        0, -k, 0, 0,
        0, 0, 1, 0,
        anchor.dx + (shift - camera.lon) * k, anchor.dy + camera.y * k, 0, 1,
      ]);
      for (final c in CountryShapes.instance.within(view)) {
        final path = _pathFor(c).transform(toScreen);
        if (c.code == highlight) {
          spots.add(path);
          continue;
        }
        canvas.drawPath(path, tint);
        canvas.drawPath(path, dotsPaint);
        canvas.drawPath(path, edge);
      }
    }
    // Drawn last so the glow sits over the neighbours.
    for (final path in spots) {
      canvas.drawPath(path, glow);
      canvas.drawPath(path, Paint()..color = highlightColor.withValues(alpha: .10));
      canvas.drawPath(path, spotDots);
      canvas.drawPath(path, spotEdge);
    }

    final at = pin == null ? null : camera.project(pin!.lon, pin!.lat, anchor);
    final from = origin == null ? null : camera.project(origin!.lon, origin!.lat, anchor);
    if (from != null && at != null && (from - at).distance > 24) _arc(canvas, from, at);

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = m.brand;
    final hole = Paint()..color = m.bg;
    for (final d in dots) {
      final p = camera.project(d.lon, d.lat, anchor);
      if (!(Offset.zero & size).inflate(6).contains(p)) continue;
      if (at != null && (p - at).distance < 14) continue;
      canvas.drawCircle(p, 4, hole);
      canvas.drawCircle(p, 4, ring);
      canvas.drawCircle(p, 1.4, Paint()..color = m.brand);
    }

    if (from != null) _origin(canvas, from);
    if (at != null) _reticle(canvas, at);
  }

  /// Meridians and parallels every [_grid] degrees: the app's namesake,
  /// faint enough to read as texture.
  void _graticule(Canvas canvas, Size size, double west, double east, double south, double north) {
    final line = Paint()
      ..strokeWidth = .7
      ..color = m.line.withValues(alpha: .9);
    for (var lon = (west / _grid).ceil() * _grid; lon <= east; lon += _grid) {
      final x = camera.project(lon, 0, anchor).dx;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    final first = math.max(-75.0, (south / _grid).ceil() * _grid);
    for (var lat = first; lat <= math.min(75.0, north); lat += _grid) {
      final y = camera.project(0, lat, anchor).dy;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
  }

  /// The pin: a solid core, a ring with four ticks like a sight, and a
  /// sonar ring that spreads and fades.
  void _reticle(Canvas canvas, Offset at) {
    final p = pulse;
    if (p != null) {
      canvas.drawCircle(
        at,
        12 + 30 * p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = pinColor.withValues(alpha: .8 * (1 - p)),
      );
    }
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..color = pinColor;
    canvas.drawCircle(at, 15, Paint()..color = pinColor.withValues(alpha: .14));
    canvas.drawCircle(at, 15, stroke);
    for (final dir in const [Offset(0, -1), Offset(1, 0), Offset(0, 1), Offset(-1, 0)]) {
      canvas.drawLine(at + dir * 18, at + dir * 23, stroke);
    }
    canvas.drawCircle(at, 6.5, Paint()..color = m.bg);
    canvas.drawCircle(at, 5, Paint()..color = pinColor);
  }

  /// Where the user really is, while protected: a hollow, quiet marker.
  void _origin(Canvas canvas, Offset at) {
    canvas.drawCircle(at, 5, Paint()..color = m.bg);
    canvas.drawCircle(
      at,
      5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = m.muted,
    );
  }

  /// A bowed, dashed route from the user to the server, its dashes
  /// travelling outward with the pulse.
  void _arc(Canvas canvas, Offset a, Offset b) {
    final mid = Offset.lerp(a, b, .5)!;
    final normal = Offset(-(b.dy - a.dy), b.dx - a.dx);
    final len = normal.distance;
    final control = mid + normal / len * math.min(70, len * .22);
    final path = Path()
      ..moveTo(a.dx, a.dy)
      ..quadraticBezierTo(control.dx, control.dy, b.dx, b.dy);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = pinColor.withValues(alpha: .85);
    const dash = 5.0, gap = 6.0;
    final offset = (pulse ?? 0) * (dash + gap) * 3;
    for (final metric in path.computeMetrics()) {
      var d = offset - (dash + gap) * 3;
      while (d < metric.length) {
        if (d + dash > 0) canvas.drawPath(metric.extractPath(math.max(0, d), d + dash), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_CountryPainter old) =>
      old.camera != camera ||
      old.anchor != anchor ||
      old.pulse != pulse ||
      old.m != m ||
      old.dpr != dpr ||
      old.highlight != highlight ||
      old.highlightColor != highlightColor ||
      old.pin != pin ||
      old.pinColor != pinColor ||
      old.origin != origin ||
      !listEquals(old.dots, dots);
}
