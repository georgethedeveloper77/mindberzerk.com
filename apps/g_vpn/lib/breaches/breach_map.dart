import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../map/country_shapes.dart';
import 'breaches.dart';

/// Country endings that are really used worldwide (.io for tech, .tv for
/// video, .me for personal sites): never placed on a country.
const _worldwide = {
  'io',
  'co',
  'ai',
  'me',
  'tv',
  'gg',
  'ly',
  'fm',
  'am',
  'to',
  'cc',
  'ws',
  'sh',
  'ac',
  'la',
  'ag',
  'gl',
  'im',
  'vc',
  'so',
  'st',
  'nu',
  'eu',
  'is',
  'gs',
  'tk',
  'ml',
  'ga',
  'cf',
  'gq',
  'cx',
  'ms',
};

/// The country a breach belongs to, from its web address's ending
/// (shop.example.de is Germany). Null for .com and other worldwide ones.
String? breachCountry(Breach b) {
  final domain = b.domain.toLowerCase().trim();
  final dot = domain.lastIndexOf('.');
  if (dot < 0) return null;
  final tld = domain.substring(dot + 1);
  if (tld.length != 2 || _worldwide.contains(tld)) return null;
  final code =
      switch (tld) { 'uk' => 'GB', 'su' => 'RU', final t => t.toUpperCase() };
  return CountryShapes.instance[code] == null ? null : code;
}

/// Breaches per country, most first.
Map<String, int> breachesByCountry(List<Breach> list) {
  final counts = <String, int>{};
  for (final b in list) {
    final c = breachCountry(b);
    if (c != null) counts[c] = (counts[c] ?? 0) + 1;
  }
  return Map.fromEntries(
      counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));
}

/// Where a country's pin goes: the middle of its mainland, in degrees.
(double, double) countryCentre(String code) {
  final f = CountryShapes.instance[code]?.focus;
  if (f == null) return (0, 0);
  return ((f.west + f.east) / 2, (f.south + f.north) / 2);
}

// ── The Earth's geometry, prepared once ────────────────────────────────

const _rad = math.pi / 180;

/// One outline with each point's sine and cosine of latitude and its
/// longitude in radians, so a frame only needs the longitude's trig.
class _Ring {
  factory _Ring(Float32List lonLat, {int step = 1}) {
    final n = (lonLat.length / 2 / step).ceil();
    final ring = _Ring._(Float32List(n), Float32List(n), Float32List(n));
    for (var j = 0; j < n; j++) {
      final i = j * 2 * step;
      ring.lon[j] = lonLat[i] * _rad;
      final la = lonLat[i + 1] * _rad;
      ring.cosLat[j] = math.cos(la);
      ring.sinLat[j] = math.sin(la);
    }
    return ring;
  }

  _Ring._(this.lon, this.cosLat, this.sinLat);

  final Float32List lon;
  final Float32List cosLat;
  final Float32List sinLat;
}

class _Country {
  _Country(this.code, this.rings, this.coarse, this.raw);

  final String code;
  final List<_Ring> rings;

  /// Every third point, for frames while the Earth moves.
  final List<_Ring> coarse;

  /// The original lon/lat outlines, for tap tests.
  final List<Float32List> raw;
}

List<_Country>? _earth;

List<_Country> _countries() => _earth ??= [
      for (final c in CountryShapes.instance.all)
        if (c.code != 'AQ')
          _Country(
            c.code,
            [for (final r in c.rings) _Ring(r)],
            [
              for (final r in c.rings)
                if (r.length >= 18) _Ring(r, step: 3)
            ],
            c.rings,
          ),
    ];

// ── The camera ─────────────────────────────────────────────────────────

double _wrap(double lon) => ((lon + 180) % 360 + 360) % 360 - 180;

/// What the globe looks at: the centre point and how close.
@immutable
class GlobeView {
  const GlobeView({this.lon = 20, this.lat = 20, this.zoom = 1});

  final double lon;
  final double lat;

  /// 1 fits the whole Earth; up to 8.
  final double zoom;

  GlobeView copyWith({double? lon, double? lat, double? zoom}) => GlobeView(
        lon: _wrap(lon ?? this.lon),
        lat: (lat ?? this.lat).clamp(-80.0, 80.0),
        zoom: (zoom ?? this.zoom).clamp(.9, 8.0),
      );

  static GlobeView lerp(GlobeView a, GlobeView b, double t) {
    // The short way round in longitude.
    var d = b.lon - a.lon;
    if (d > 180) d -= 360;
    if (d < -180) d += 360;
    return GlobeView(
        lon: _wrap(a.lon + d * t),
        lat: a.lat + (b.lat - a.lat) * t,
        zoom: a.zoom + (b.zoom - a.zoom) * t);
  }

  @override
  bool operator ==(Object other) =>
      other is GlobeView &&
      other.lon == lon &&
      other.lat == lat &&
      other.zoom == zoom;

  @override
  int get hashCode => Object.hash(lon, lat, zoom);
}

/// Moves the globe from outside: fly to a country, zoom, back to the world.
class GlobeController extends ChangeNotifier {
  GlobeController([this._view = const GlobeView()]);

  GlobeView _view;
  GlobeView get view => _view;

  /// Where a flight is heading, picked up by the globe.
  GlobeView? _target;

  void flyTo(GlobeView v) {
    _target = v;
    notifyListeners();
  }

  void flyToCountry(String code, {double zoom = 2.6}) {
    final (lon, lat) = countryCentre(code);
    flyTo(_view.copyWith(lon: lon, lat: lat, zoom: zoom));
  }

  void zoomBy(double factor) =>
      flyTo(_view.copyWith(zoom: _view.zoom * factor));

  void reset() => flyTo(_view.copyWith(lat: 20, zoom: 1));
}

/// Screen point to longitude and latitude in degrees, or null off the Earth.
(double, double)? _unproject(Offset p, Offset c, double r, GlobeView v) {
  final x = (p.dx - c.dx) / r;
  final y = -(p.dy - c.dy) / r;
  final rho = math.sqrt(x * x + y * y);
  if (rho > 1) return null;
  if (rho == 0) return (v.lon, v.lat);
  final cc = math.asin(rho);
  final lat0 = v.lat * _rad;
  final lat = math.asin(
      math.cos(cc) * math.sin(lat0) + y * math.sin(cc) * math.cos(lat0) / rho);
  final lon = v.lon * _rad +
      math.atan2(
          x * math.sin(cc),
          rho * math.cos(lat0) * math.cos(cc) -
              y * math.sin(lat0) * math.sin(cc));
  return (_wrap(lon / _rad), lat / _rad);
}

bool _inside(Float32List ring, double x, double y) {
  var inside = false;
  for (var i = 0, j = ring.length - 2; i < ring.length; j = i, i += 2) {
    final xi = ring[i], yi = ring[i + 1], xj = ring[j], yj = ring[j + 1];
    if ((yi > y) != (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi) {
      inside = !inside;
    }
  }
  return inside;
}

String? _countryAt(double lon, double lat) {
  for (final c in _countries()) {
    final b = CountryShapes.instance[c.code]!.bounds;
    if (lon < b.west || lon > b.east || lat < b.south || lat > b.north) {
      continue;
    }
    if (c.raw.any((r) => _inside(r, lon, lat))) return c.code;
  }
  return null;
}

// ── The widget ─────────────────────────────────────────────────────────

/// The Earth in space, countries lit by their breaches.
///
/// With [interactive] it spins on drag (and keeps going a little after),
/// zooms on pinch or double tap, and flies where the controller sends it.
/// Without, it turns slowly on its own and any tap is [onTapAnywhere].
class BreachGlobe extends StatefulWidget {
  const BreachGlobe({
    super.key,
    required this.counts,
    this.selected,
    this.onSelect,
    this.onTapAnywhere,
    this.controller,
    this.interactive = true,
  });

  final Map<String, int> counts;
  final String? selected;
  final ValueChanged<String?>? onSelect;
  final VoidCallback? onTapAnywhere;
  final GlobeController? controller;
  final bool interactive;

  @override
  State<BreachGlobe> createState() => _BreachGlobeState();
}

class _BreachGlobeState extends State<BreachGlobe>
    with TickerProviderStateMixin {
  late final GlobeController _ctl = widget.controller ?? GlobeController();
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2200));
  late final AnimationController _fly = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900));
  late final Ticker _spin = createTicker(_glide);
  GlobeView _from = const GlobeView();
  GlobeView _to = const GlobeView();
  double _startZoom = 1;
  Offset _velocity = Offset.zero;
  Duration _lastTick = Duration.zero;
  bool _moving = false;
  bool _still = false;

  @override
  void initState() {
    super.initState();
    _ctl.addListener(_onController);
    _fly
      ..addListener(() {
        _ctl._view = GlobeView.lerp(
            _from, _to, Curves.easeInOutCubic.transform(_fly.value));
        setState(() {});
      })
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) setState(() => _moving = false);
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.disableAnimationsOf(context);
    if (_still) {
      _pulse.stop();
      _spin.stop();
    } else {
      if (!_pulse.isAnimating) _pulse.repeat();
      // The small globe turns slowly by itself: 8 degrees a second.
      if (!widget.interactive && !_spin.isActive) {
        _velocity = const Offset(-8, 0);
        _lastTick = Duration.zero;
        _spin.start();
      }
    }
  }

  @override
  void dispose() {
    _ctl.removeListener(_onController);
    if (widget.controller == null) _ctl.dispose();
    _spin.dispose();
    _pulse.dispose();
    _fly.dispose();
    super.dispose();
  }

  void _onController() {
    final target = _ctl._target;
    if (target == null) return;
    _ctl._target = null;
    _spin.stop();
    if (_still) {
      _ctl._view = target;
      setState(() {});
      return;
    }
    _from = _ctl.view;
    _to = target;
    _moving = true;
    _fly.forward(from: 0);
  }

  /// Each frame of a fling (slowing down) or of the small globe's turn.
  void _glide(Duration elapsed) {
    final dt = ((elapsed - _lastTick).inMicroseconds / 1e6).clamp(0.0, .05);
    _lastTick = elapsed;
    if (widget.interactive) {
      _velocity *= math.pow(.05, dt).toDouble();
      if (_velocity.distance < 1.5) {
        _spin.stop();
        setState(() => _moving = false);
        return;
      }
    }
    final v = _ctl.view;
    _ctl._view = v.copyWith(
        lon: v.lon + _velocity.dx * dt, lat: v.lat + _velocity.dy * dt);
    setState(() {});
  }

  double _radius(Size s) => math.min(s.width, s.height) * .42 * _ctl.view.zoom;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final size = box.biggest;
      final centre = size.center(Offset.zero);
      final r = _radius(size);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) {
          if (!widget.interactive) {
            widget.onTapAnywhere?.call();
            return;
          }
          final at = _unproject(d.localPosition, centre, r, _ctl.view);
          final code = at == null ? null : _countryAt(at.$1, at.$2);
          widget.onSelect?.call(code);
        },
        onDoubleTap: widget.interactive ? () => _ctl.zoomBy(1.8) : null,
        onScaleStart: widget.interactive
            ? (_) {
                _fly.stop();
                _spin.stop();
                _startZoom = _ctl.view.zoom;
                setState(() => _moving = true);
              }
            : null,
        onScaleUpdate: widget.interactive
            ? (d) {
                final v = _ctl.view;
                // Dragging the Earth's radius turns it about 57 degrees.
                _ctl._view = v.copyWith(
                  lon: v.lon - d.focalPointDelta.dx / r / _rad,
                  lat: v.lat + d.focalPointDelta.dy / r / _rad,
                  zoom: d.pointerCount > 1 ? _startZoom * d.scale : v.zoom,
                );
                setState(() {});
              }
            : null,
        onScaleEnd: widget.interactive
            ? (d) {
                final px = d.velocity.pixelsPerSecond;
                _velocity = Offset(-px.dx / r / _rad, px.dy / r / _rad);
                if (_still || _velocity.distance < 8) {
                  setState(() => _moving = false);
                  return;
                }
                _lastTick = Duration.zero;
                _spin.start();
              }
            : null,
        child: Semantics(
          label: 'Globe of data breaches by country',
          child: Stack(fit: StackFit.expand, children: [
            RepaintBoundary(child: CustomPaint(painter: _StarsPainter())),
            CustomPaint(
              painter: _EarthPainter(
                  view: _ctl.view,
                  radius: r,
                  counts: widget.counts,
                  selected: widget.selected,
                  coarse: _moving),
            ),
            CustomPaint(
              painter: _PulsePainter(
                  view: _ctl.view,
                  radius: r,
                  counts: widget.counts,
                  selected: widget.selected,
                  pulse: _pulse),
            ),
          ]),
        ),
      );
    });
  }
}

const _cyan = Color(0xFF5EEAD4);
const _pink = Color(0xFFF472B6);
const _landColor = Color(0xFF2B3556);
const _landLine = Color(0xFF3E4A72);

/// Orthographic projection for one frame. Points on the far side slide to
/// the Earth's edge, so outlines that cross it close neatly along the rim.
class _Projector {
  _Projector(this.view, this.centre, this.radius)
      : _lon0 = view.lon * _rad,
        _sinLat0 = math.sin(view.lat * _rad),
        _cosLat0 = math.cos(view.lat * _rad);

  final GlobeView view;
  final Offset centre;
  final double radius;
  final double _lon0;
  final double _sinLat0;
  final double _cosLat0;

  /// Whether the last projected point faced the viewer.
  bool front = false;

  Offset call(double lon, double cosLat, double sinLat) {
    final d = lon - _lon0;
    final cosD = math.cos(d);
    final cosC = _sinLat0 * sinLat + _cosLat0 * cosLat * cosD;
    var x = cosLat * math.sin(d);
    var y = _cosLat0 * sinLat - _sinLat0 * cosLat * cosD;
    front = cosC >= 0;
    if (!front) {
      final n = math.sqrt(x * x + y * y);
      if (n > 0) {
        x /= n;
        y /= n;
      }
    }
    return Offset(centre.dx + radius * x, centre.dy - radius * y);
  }

  Offset? degrees(double lon, double lat) {
    final p = call(lon * _rad, math.cos(lat * _rad), math.sin(lat * _rad));
    return front ? p : null;
  }
}

class _EarthPainter extends CustomPainter {
  _EarthPainter(
      {required this.view,
      required this.radius,
      required this.counts,
      required this.selected,
      required this.coarse});

  final GlobeView view;
  final double radius;
  final Map<String, int> counts;
  final String? selected;
  final bool coarse;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = radius;
    final disc = Rect.fromCircle(center: c, radius: r);
    final project = _Projector(view, c, r);

    // Atmosphere, then the ocean.
    canvas.drawCircle(
      c,
      r * 1.12,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x006EA8FF), Color(0x4D6EA8FF), Color(0x006EA8FF)],
          stops: [.86, .93, 1],
        ).createShader(Rect.fromCircle(center: c, radius: r * 1.12)),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.25, -.35),
          radius: 1.1,
          colors: [Color(0xFF1D2B58), Color(0xFF0E1530), Color(0xFF070A18)],
          stops: [0, .7, 1],
        ).createShader(disc),
    );

    canvas.save();
    canvas.clipPath(Path()..addOval(disc));

    // Lines of latitude and longitude, only on the near side.
    final grid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .8
      ..color = const Color(0x1A96B4FF);
    for (var lat = -60; lat <= 60; lat += 30) {
      _line(
          canvas,
          project,
          [
            for (var lon = -180; lon <= 180; lon += 5)
              (lon.toDouble(), lat.toDouble())
          ],
          grid);
    }
    for (var lon = -180; lon < 180; lon += 30) {
      _line(
          canvas,
          project,
          [
            for (var lat = -85; lat <= 85; lat += 5)
              (lon.toDouble(), lat.toDouble())
          ],
          grid);
    }

    // Countries, lit by their breaches.
    final most = counts.values.fold<int>(1, math.max);
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .6;
    Path? picked;
    for (final country in _countries()) {
      final rings =
          coarse && country.coarse.isNotEmpty ? country.coarse : country.rings;
      final path = Path();
      var seen = false;
      for (final ring in rings) {
        for (var i = 0; i < ring.lon.length; i++) {
          final p = project(ring.lon[i], ring.cosLat[i], ring.sinLat[i]);
          seen |= project.front;
          i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
        }
        path.close();
      }
      if (!seen) continue;
      if (country.code == selected) {
        picked = path;
        continue;
      }
      final n = counts[country.code] ?? 0;
      canvas.drawPath(
          path,
          Paint()
            ..color = n == 0
                ? _landColor
                : Color.lerp(_landColor, _pink, .3 + .6 * n / most)!);
      canvas.drawPath(path,
          border..color = n == 0 ? _landLine : _pink.withValues(alpha: .8));
    }
    if (picked != null) {
      canvas.drawPath(picked, Paint()..color = _cyan.withValues(alpha: .35));
      canvas.drawPath(
        picked,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = _cyan,
      );
    }
    canvas.restore();

    // Night falls toward the far edge.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.3, -.4),
          radius: 1.2,
          colors: [Color(0x00000000), Color(0x8C000000)],
          stops: [.55, 1],
        ).createShader(disc),
    );
  }

  void _line(Canvas canvas, _Projector project, List<(double, double)> pts,
      Paint paint) {
    final path = Path();
    var drawing = false;
    for (final (lon, lat) in pts) {
      final p = project.degrees(lon, lat);
      if (p == null) {
        drawing = false;
        continue;
      }
      drawing ? path.lineTo(p.dx, p.dy) : path.moveTo(p.dx, p.dy);
      drawing = true;
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_EarthPainter old) =>
      old.view != view ||
      old.radius != radius ||
      old.selected != selected ||
      old.counts != counts ||
      old.coarse != coarse;
}

/// The pulses, and the picked country's marker.
class _PulsePainter extends CustomPainter {
  _PulsePainter(
      {required this.view,
      required this.radius,
      required this.counts,
      required this.selected,
      required this.pulse})
      : super(repaint: pulse);

  final GlobeView view;
  final double radius;
  final Map<String, int> counts;
  final String? selected;
  final Animation<double> pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final project = _Projector(view, size.center(Offset.zero), radius);
    final t = pulse.value;
    for (final e in counts.entries) {
      if (e.key == selected) continue;
      final (lon, lat) = countryCentre(e.key);
      final p = project.degrees(lon, lat);
      if (p == null) continue;
      final r = 2.4 + math.sqrt(e.value) * 1.5;
      canvas.drawCircle(p, r + 9 * t,
          Paint()..color = _pink.withValues(alpha: .35 * (1 - t)));
      canvas.drawCircle(p, r, Paint()..color = _pink);
    }
    final code = selected;
    if (code != null) {
      final (lon, lat) = countryCentre(code);
      final p = project.degrees(lon, lat);
      if (p != null) {
        canvas.drawCircle(p, 6 + 9 * t,
            Paint()..color = _cyan.withValues(alpha: .3 * (1 - t)));
        canvas.drawCircle(p, 6, Paint()..color = _cyan);
      }
    }
  }

  @override
  bool shouldRepaint(_PulsePainter old) =>
      old.view != view ||
      old.radius != radius ||
      old.selected != selected ||
      old.counts != counts;
}

class _StarsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(7);
    final paint = Paint();
    for (var i = 0; i < 120; i++) {
      paint.color = Colors.white.withValues(alpha: .2 + rnd.nextDouble() * .6);
      canvas.drawCircle(
          Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height),
          rnd.nextDouble() * .9 + .3,
          paint);
    }
  }

  @override
  bool shouldRepaint(_StarsPainter old) => false;
}
