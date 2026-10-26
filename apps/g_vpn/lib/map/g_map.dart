import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../design/meridian.dart';
import 'lat_lon.dart';
import 'country_shapes.dart';

/// What the map is telling the user.
enum MapMood {
  /// The user's country outlined in red, their estimated spot pinned.
  exposed,

  /// Zoomed out to the world, turning while the tunnel comes up.
  connecting,

  /// Flown to the server's country, outlined in green.
  protected,
}

/// A place with free servers: one marker per country.
@immutable
class MapMarker {
  const MapMarker({required this.id, required this.at, required this.code, required this.count});

  /// Stable id, the ISO country code for free servers.
  final String id;
  final LatLon at;
  final String code;
  final int count;

  @override
  bool operator ==(Object other) =>
      other is MapMarker && other.id == id && other.at == at && other.count == count && other.code == code;

  @override
  int get hashCode => Object.hash(id, at, code, count);
}

/// Everything the map shows, as plain data.
@immutable
class MapScene {
  const MapScene({
    required this.mood,
    this.you,
    this.youCountry,
    this.server,
    this.serverCountry,
    this.markers = const [],
    this.selected,
  });

  final MapMood mood;

  /// The user's estimated real location and country (ISO alpha-2).
  final LatLon? you;
  final String? youCountry;

  /// Where traffic comes out while protected, and that country.
  final LatLon? server;
  final String? serverCountry;

  final List<MapMarker> markers;

  /// The marker whose card is open.
  final String? selected;

  /// The same scene with server markers and a selection.
  MapScene withMarkers(List<MapMarker> markers, {String? selected}) => MapScene(
        mood: mood,
        you: you,
        youCountry: youCountry,
        server: server,
        serverCountry: serverCountry,
        markers: markers,
        selected: selected,
      );

  bool sameAs(MapScene o) =>
      mood == o.mood &&
      you == o.you &&
      youCountry == o.youCountry &&
      server == o.server &&
      serverCountry == o.serverCountry &&
      selected == o.selected &&
      listEquals(markers, o.markers);
}

/// One camera move in the story.
class _Shot {
  const _Shot(this.update, {this.after = Duration.zero, this.duration});

  final CameraUpdate update;

  /// Wait before this shot starts.
  final Duration after;

  /// Null jumps; otherwise a flight of this length.
  final Duration? duration;
}

/// The Meridian map: MapLibre drawing OpenFreeMap's vector tiles in quiet
/// Meridian colours, with G VPN's story on top: the user's country
/// outlined in red with their estimated spot, the server's country in
/// green, a route between them, and free-server markers.
///
/// With [choreograph], the camera tells it like a film. On arrival: the
/// continent, then the user's country, then their spot. Connecting: out to
/// the whole world, turning. Protected: a flight into the server's country.
/// Disconnecting: back to the user's country, then their spot. Under
/// "remove animations" every move is a jump.
class GMap extends StatefulWidget {
  const GMap({
    super.key,
    required this.scene,
    this.interactive = false,
    this.choreograph = false,
    this.onMarkerTap,
    this.padding = EdgeInsets.zero,
    this.zoom,
  });

  final MapScene scene;

  /// Pan and zoom by touch, and marker taps.
  final bool interactive;

  /// Run the arrival, connect and disconnect story.
  final bool choreograph;

  /// A marker id, or null when the user taps empty map.
  final ValueChanged<String?>? onMarkerTap;

  /// Where overlays cover the map; subjects are framed inside the rest.
  final EdgeInsets padding;

  /// A fixed zoom on the subject point, overriding the story's.
  final double? zoom;

  /// The user's spot: the neighbourhood around the IP's estimate.
  static const spotZoom = 10.5;

  /// The continent, as the story opens.
  static const continentZoom = 2.4;

  /// The whole world, turning while connecting.
  static const worldZoom = 1.1;

  /// Interactive maps open on a region.
  static const regionZoom = 3.6;

  /// How far the estimate may be from the user, drawn as a circle.
  static const estimateMetres = 4000.0;

  @override
  State<GMap> createState() => GMapState();
}

class GMapState extends State<GMap> {
  static bool _surfaceChosen = false;

  MapLibreMapController? _map;
  bool _ready = false;
  int _story = 0;
  Timer? _spin;
  Timer? _pulse;
  double _spinLon = 0;
  int _pulseTick = 0;

  /// Whether the arrival story has played for the current location.
  LatLon? _introducedAt;

  static const _srcCountries = 'gv-countries';
  static const _srcEstimate = 'gv-estimate';
  static const _srcRoute = 'gv-route';
  static const _srcPin = 'gv-pin';
  static const _srcPulse = 'gv-pulse';
  static const _srcServers = 'gv-servers';
  static const _layerServers = 'gv-servers-dot';

  bool get _still => MediaQuery.disableAnimationsOf(context);

  @override
  void initState() {
    super.initState();
    // Composited with Flutter, so the map can be clipped and have cards
    // painted over it. Chosen once, before the first map is created.
    if (!_surfaceChosen) {
      MapLibreMap.useHybridComposition = true;
      _surfaceChosen = true;
    }
  }

  @override
  void didUpdateWidget(GMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_ready) return;
    final a = oldWidget.scene, b = widget.scene;
    if (a.sameAs(b)) return;
    unawaited(_syncData());
    final moved = a.mood != b.mood || a.server != b.server || a.you != b.you || a.serverCountry != b.serverCountry;
    if (widget.choreograph && moved) _direct(from: a.mood);
    _syncPulse();
  }

  @override
  void dispose() {
    _story++;
    _spin?.cancel();
    _pulse?.cancel();
    super.dispose();
  }

  // ── Camera ──────────────────────────────────────────────────────────

  /// Frames [code]'s mainland inside the padding; null when unknown.
  CameraUpdate? _country(String? code) {
    final shape = CountryShapes.instance[code];
    if (shape == null) return null;
    final b = shape.focus;
    final p = widget.padding;
    return CameraUpdate.newLatLngBounds(
      LatLngBounds(southwest: LatLng(b.south, b.west), northeast: LatLng(b.north, b.east)),
      left: p.left + 24,
      top: p.top + 24,
      right: p.right + 24,
      bottom: p.bottom + 24,
    );
  }

  /// Centres [p] in the area the padding leaves free.
  CameraUpdate _point(LatLon p, double zoom) => CameraUpdate.newLatLngZoom(_shift(p, zoom), zoom);

  /// Moves [p] so it sits in the middle of the uncovered area, not the
  /// middle of the widget.
  LatLng _shift(LatLon p, double zoom) {
    final offset = (widget.padding.top - widget.padding.bottom) / 2;
    final world = 512 * math.pow(2, zoom).toDouble();
    double y(double lat) {
      final s = math.sin(lat.clamp(-85.0, 85.0) * math.pi / 180);
      return (.5 - math.log((1 + s) / (1 - s)) / (4 * math.pi)) * world;
    }

    double lat(double py) {
      final n = math.pi - 2 * math.pi * py / world;
      return 180 / math.pi * math.atan(.5 * (math.exp(n) - math.exp(-n)));
    }

    return LatLng(lat(y(p.lat) - offset), p.lon);
  }

  /// The opening frame before the style is ready.
  CameraPosition get _initialCamera {
    final s = widget.scene;
    final at = s.mood == MapMood.protected ? s.server : s.you;
    if (at == null) return const CameraPosition(target: LatLng(10, 20), zoom: GMap.worldZoom + .8);
    final zoom = widget.zoom ?? (widget.choreograph ? GMap.continentZoom : GMap.regionZoom);
    return CameraPosition(target: _shift(at, zoom), zoom: zoom);
  }

  /// Plays [shots] in order; a newer story cancels this one.
  Future<void> _play(List<_Shot> shots) async {
    final id = ++_story;
    for (final shot in shots) {
      if (shot.after > Duration.zero && !_still) await Future<void>.delayed(shot.after);
      final map = _map;
      if (id != _story || !mounted || map == null) return;
      final d = shot.duration;
      if (d == null || _still) {
        unawaited(map.moveCamera(shot.update));
      } else {
        unawaited(map.animateCamera(shot.update, duration: d));
      }
    }
  }

  /// Arrival: continent, then country, then the user's spot.
  List<_Shot> _arrival() {
    final s = widget.scene;
    final you = s.you;
    if (you == null) return const [];
    _introducedAt = you;
    final country = _country(s.youCountry);
    return [
      _Shot(_point(you, GMap.continentZoom)),
      if (country != null) _Shot(country, after: const Duration(milliseconds: 700), duration: const Duration(milliseconds: 1800)),
      _Shot(
        _point(you, GMap.spotZoom),
        after: Duration(milliseconds: country == null ? 700 : 2300),
        duration: const Duration(milliseconds: 2000),
      ),
    ];
  }

  /// Decides the next scene's camera from the last mood.
  void _direct({required MapMood from}) {
    final s = widget.scene;
    switch (s.mood) {
      case MapMood.connecting:
        _startSpin();
      case MapMood.protected:
        _stopSpin();
        final target = _country(s.serverCountry) ?? (s.server == null ? null : _point(s.server!, 5));
        if (target != null) unawaited(_play([_Shot(target, duration: const Duration(milliseconds: 2800))]));
      case MapMood.exposed:
        _stopSpin();
        final you = s.you;
        if (you == null) return;
        if (from == MapMood.exposed && _introducedAt == null) {
          unawaited(_play(_arrival()));
          return;
        }
        // Home again: the user's country first, then their spot.
        _introducedAt = you;
        final country = _country(s.youCountry);
        unawaited(_play([
          if (country != null) _Shot(country, duration: const Duration(milliseconds: 2400)),
          _Shot(
            _point(you, GMap.spotZoom),
            after: Duration(milliseconds: country == null ? 0 : 2700),
            duration: const Duration(milliseconds: 1800),
          ),
        ]));
    }
  }

  /// Out to the whole world, then a steady turn east until the tunnel is
  /// up: the globe spinning while G VPN finds a way out.
  void _startSpin() {
    if (_spin != null) return;
    _story++;
    _spinLon = widget.scene.you?.lon ?? 20;
    final map = _map;
    if (map == null) return;
    final update = CameraUpdate.newLatLngZoom(LatLng(15, _spinLon), GMap.worldZoom);
    if (_still) {
      unawaited(map.moveCamera(update));
      return;
    }
    unawaited(map.animateCamera(update, duration: const Duration(milliseconds: 1200)));
    // Each leg starts just before the last ends, so the turn never pauses.
    _spin = Timer.periodic(const Duration(milliseconds: 1300), (_) {
      _spinLon += 60;
      if (_spinLon > 180) _spinLon -= 360;
      unawaited(_map?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(15, _spinLon), GMap.worldZoom),
        duration: const Duration(milliseconds: 1400),
      ));
    });
  }

  void _stopSpin() {
    _spin?.cancel();
    _spin = null;
  }

  /// Back to where the scene rests; for "my location" buttons.
  void recenter() {
    final s = widget.scene;
    final protected = s.mood == MapMood.protected;
    final at = protected ? s.server : s.you;
    final update = _country(protected ? s.serverCountry : s.youCountry) ??
        (at == null ? null : _point(at, widget.zoom ?? GMap.regionZoom));
    if (update != null) unawaited(_play([_Shot(update, duration: const Duration(milliseconds: 1200))]));
  }

  /// Frames a marker's country, for search results.
  void focusOn(String code, LatLon at) {
    final update = _country(code) ?? _point(at, GMap.regionZoom + 1);
    unawaited(_play([_Shot(update, duration: const Duration(milliseconds: 1200))]));
  }

  // ── Layers ──────────────────────────────────────────────────────────

  Future<void> _onStyle() async {
    final map = _map;
    if (map == null || !mounted) return;
    _ready = false;
    _sent.clear();
    final m = context.mer;
    final empty = <String, dynamic>{'type': 'FeatureCollection', 'features': <Object>[]};
    for (final id in [_srcCountries, _srcEstimate, _srcRoute, _srcPin, _srcPulse, _srcServers]) {
      await map.addGeoJsonSource(id, empty);
    }

    // Country outlines: a soft wash, a blurred glow, then a crisp edge.
    await map.addFillLayer(_srcCountries, 'gv-country-fill',
        const FillLayerProperties(fillColor: ['get', 'color'], fillOpacity: .10),
        enableInteraction: false);
    await map.addLineLayer(_srcCountries, 'gv-country-glow',
        const LineLayerProperties(lineColor: ['get', 'color'], lineWidth: 7, lineBlur: 5, lineOpacity: .45, lineJoin: 'round'),
        enableInteraction: false);
    await map.addLineLayer(_srcCountries, 'gv-country-edge',
        const LineLayerProperties(lineColor: ['get', 'color'], lineWidth: 1.8, lineOpacity: .95, lineJoin: 'round'),
        enableInteraction: false);

    await map.addFillLayer(_srcEstimate, 'gv-estimate-fill',
        const FillLayerProperties(fillColor: ['get', 'color'], fillOpacity: .12),
        enableInteraction: false);
    await map.addLineLayer(_srcEstimate, 'gv-estimate-edge',
        const LineLayerProperties(lineColor: ['get', 'color'], lineOpacity: .7, lineWidth: 1.4, lineDasharray: [3, 3]),
        enableInteraction: false);
    await map.addLineLayer(_srcRoute, 'gv-route',
        const LineLayerProperties(lineColor: ['get', 'color'], lineWidth: 2.2, lineOpacity: .85, lineDasharray: [2, 2]),
        enableInteraction: false);

    await map.addCircleLayer(_srcServers, _layerServers, CircleLayerProperties(
      circleRadius: 15,
      circleColor: ['case', ['get', 'selected'], _hex(m.brand), _hex(m.surface)],
      circleStrokeColor: ['case', ['get', 'selected'], _hex(m.brand), _hex(m.line)],
      circleStrokeWidth: 1.5,
    ));
    await map.addSymbolLayer(_srcServers, 'gv-servers-count', SymbolLayerProperties(
      textField: ['get', 'count'],
      textFont: const ['Noto Sans Bold'],
      textSize: 12,
      textColor: ['case', ['get', 'selected'], _hex(m.onBrand), _hex(m.text)],
      textAllowOverlap: true,
      textIgnorePlacement: true,
    ), enableInteraction: false);
    await map.addSymbolLayer(_srcServers, 'gv-servers-code', SymbolLayerProperties(
      textField: ['get', 'code'],
      textFont: const ['Noto Sans Bold'],
      textSize: 11,
      textOffset: const [0, 2.1],
      textColor: _hex(m.text),
      textHaloColor: _hex(m.bg),
      textHaloWidth: 1.4,
      textAllowOverlap: true,
    ), enableInteraction: false);

    await map.addCircleLayer(_srcPulse, 'gv-pulse', const CircleLayerProperties(
      circleRadius: ['get', 'r'],
      circleColor: ['get', 'color'],
      circleOpacity: 0,
      circleStrokeColor: ['get', 'color'],
      circleStrokeWidth: 1.6,
      circleStrokeOpacity: ['get', 'o'],
    ), enableInteraction: false);
    await map.addCircleLayer(_srcPin, 'gv-pin-ring', const CircleLayerProperties(
      circleRadius: ['get', 'ring'],
      circleColor: ['get', 'color'],
      circleOpacity: .16,
      circleStrokeColor: ['get', 'color'],
      circleStrokeWidth: 1.6,
    ), enableInteraction: false);
    await map.addCircleLayer(_srcPin, 'gv-pin-core', CircleLayerProperties(
      circleRadius: ['get', 'core'],
      circleColor: ['get', 'color'],
      circleStrokeColor: _hex(m.bg),
      circleStrokeWidth: 2,
    ), enableInteraction: false);

    _ready = true;
    await _syncData();
    _syncPulse();
    _opening();
  }

  /// The first camera once layers exist: the arrival story on Home, or a
  /// framed rest elsewhere.
  void _opening() {
    final s = widget.scene;
    if (widget.choreograph) {
      switch (s.mood) {
        case MapMood.exposed:
          if (s.you != null && _introducedAt == null) unawaited(_play(_arrival()));
        case MapMood.connecting:
          _startSpin();
        case MapMood.protected:
          final target = _country(s.serverCountry);
          if (target != null) unawaited(_play([_Shot(target)]));
      }
    } else if (widget.zoom == null) {
      recenter();
    }
  }

  /// What each source last received, so a change to one part of the
  /// scene (a selected marker) does not resend the others (country
  /// outlines run to thousands of points).
  final Map<String, Object> _sent = {};

  /// Sends [build] to [source] only when [key] differs from last time.
  Future<void> _push(String source, Object key, Map<String, dynamic> Function() build) async {
    final map = _map;
    if (map == null || _sent[source] == key) return;
    _sent[source] = key;
    await map.setGeoJsonSource(source, build());
  }

  /// Pushes the scene into the map's sources.
  Future<void> _syncData() async {
    if (_map == null || !_ready || !mounted) return;
    final m = context.mer;
    final s = widget.scene;
    final protected = s.mood == MapMood.protected && s.server != null;
    final pinAt = protected ? s.server : s.you;
    final pinColor = _hex(_tone(m));
    final youShape = CountryShapes.instance[s.youCountry];
    final serverShape = protected ? CountryShapes.instance[s.serverCountry] : null;
    final bad = _hex(m.bad), good = _hex(m.good), muted = _hex(m.muted);

    await _push(_srcCountries, (youShape?.code, serverShape?.code, bad, good), () => _collection([
          // While protected the user's country stays, so the route has
          // somewhere to start.
          if (youShape != null && youShape.code != serverShape?.code) _feature(youShape.toGeoJson(), {'color': bad}),
          if (serverShape != null) _feature(serverShape.toGeoJson(), {'color': good}),
        ]));
    await _push(_srcEstimate, (protected, s.you, bad), () => _collection([
          if (!protected && s.you != null)
            _feature({'type': 'Polygon', 'coordinates': [_circle(s.you!, GMap.estimateMetres)]}, {'color': bad}),
        ]));
    await _push(_srcRoute, (protected, s.you, s.server, good), () => _collection([
          if (protected && s.you != null)
            _feature({'type': 'LineString', 'coordinates': _route(s.you!, s.server!)}, {'color': good}),
        ]));
    await _push(_srcPin, (protected, s.you, pinAt, pinColor, muted), () => _collection([
          if (protected && s.you != null) _feature(_pointJson(s.you!), {'color': muted, 'ring': 0, 'core': 4.5}),
          if (pinAt != null) _feature(_pointJson(pinAt), {'color': pinColor, 'ring': 15, 'core': 5.5}),
        ]));
    await _push(_srcServers, (Object.hashAll(s.markers), s.selected), () => _collection([
          for (final k in s.markers)
            _feature(_pointJson(k.at), {'id': k.id, 'code': k.code, 'count': '${k.count}', 'selected': k.id == s.selected}),
        ]));
    await _pushPulse();
  }

  Color _tone(Meridian m) => switch (widget.scene.mood) {
        MapMood.exposed => m.bad,
        MapMood.connecting => m.warn,
        MapMood.protected => widget.scene.server != null ? m.good : m.bad,
      };

  // ── Pulse ───────────────────────────────────────────────────────────

  void _syncPulse() {
    final want = !_still && _ready && (widget.scene.you != null || widget.scene.server != null);
    if (want && _pulse == null) {
      // About 12 frames a second: smooth for a soft ring, light on the
      // platform bridge, so taps and sheets are never queued behind it.
      _pulse = Timer.periodic(const Duration(milliseconds: 80), (_) {
        _pulseTick = (_pulseTick + 1) % 33;
        unawaited(_pushPulse());
      });
    } else if (!want && _pulse != null) {
      _pulse!.cancel();
      _pulse = null;
      unawaited(_pushPulse());
    }
  }

  Future<void> _pushPulse() async {
    final map = _map;
    if (map == null || !_ready || !mounted) return;
    final s = widget.scene;
    final protected = s.mood == MapMood.protected && s.server != null;
    final at = protected ? s.server : s.you;
    final t = _pulseTick / 33;
    await map.setGeoJsonSource(_srcPulse, _collection([
      if (at != null && _pulse != null)
        _feature(_pointJson(at), {'color': _hex(_tone(context.mer)), 'r': 14 + 30 * t, 'o': .85 * (1 - t)}),
    ]));
  }

  // ── Taps ────────────────────────────────────────────────────────────

  /// The marker under a point in the map's own pixels, with a finger's
  /// worth of slack so small markers are easy to hit.
  Future<String?> _markerAtPixel(Offset pixel) async {
    final map = _map;
    if (map == null || !_ready) return null;
    final slack = 22 * MediaQuery.devicePixelRatioOf(context);
    final hits = await map.queryRenderedFeaturesInRect(
      Rect.fromCenter(center: pixel, width: slack * 2, height: slack * 2),
      [_layerServers],
      null,
    );
    for (final hit in hits) {
      final props = hit is Map ? hit['properties'] : null;
      if (props is Map && props['id'] is String) return props['id'] as String;
    }
    return null;
  }

  /// The marker under a screen position, for maps that take taps through
  /// an overlay rather than directly (Home).
  Future<String?> markerAt(Offset globalPosition) async {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    final local = box.globalToLocal(globalPosition);
    return _markerAtPixel(local * MediaQuery.devicePixelRatioOf(context));
  }

  Offset? _downAt;
  DateTime? _downTime;

  /// The marker within a finger's reach of [local], from the tracked
  /// camera: instant, no platform round trip. Null when none is near.
  String? _hitTest(Offset local) {
    final camera = _map?.cameraPosition;
    final box = context.findRenderObject();
    if (camera == null || box is! RenderBox || !box.hasSize) return null;
    final world = 512 * math.pow(2, camera.zoom).toDouble();
    Offset project(double lat, double lon) {
      final sin = math.sin(lat.clamp(-85.0, 85.0) * math.pi / 180);
      return Offset((lon + 180) / 360 * world, (.5 - math.log((1 + sin) / (1 - sin)) / (4 * math.pi)) * world);
    }

    final centre = project(camera.target.latitude, camera.target.longitude);
    final half = box.size.center(Offset.zero);
    String? best;
    var bestDistance = 26.0;
    for (final marker in widget.scene.markers) {
      var p = project(marker.at.lat, marker.at.lon) - centre;
      // The nearest copy of the marker across the date line.
      if (p.dx > world / 2) p -= Offset(world, 0);
      if (p.dx < -world / 2) p += Offset(world, 0);
      final d = (p + half - local).distance;
      if (d < bestDistance) {
        bestDistance = d;
        best = marker.id;
      }
    }
    return best;
  }

  void _pointerDown(PointerDownEvent e) {
    _downAt = e.localPosition;
    _downTime = DateTime.now();
  }

  /// A short press that did not move is a tap; drags and pinches are not.
  void _pointerUp(PointerUpEvent e) {
    final at = _downAt, time = _downTime;
    _downAt = null;
    if (at == null || time == null) return;
    final quick = DateTime.now().difference(time) < const Duration(milliseconds: 350);
    if (!quick || (e.localPosition - at).distance > 12) return;
    widget.onMarkerTap?.call(_hitTest(e.localPosition));
  }

  // ── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final interactive = widget.interactive;
    final map = MapLibreMap(
      styleString: dark ? 'assets/map/meridian_dark.json' : 'assets/map/meridian_light.json',
      initialCameraPosition: _initialCamera,
      onMapCreated: (c) => _map = c,
      onStyleLoadedCallback: () => unawaited(_onStyle()),
      // Interactive maps hit-test markers in Dart from the camera.
      trackCameraPosition: interactive,
      scrollGesturesEnabled: interactive,
      zoomGesturesEnabled: interactive,
      dragEnabled: interactive,
      doubleClickZoomEnabled: interactive,
      rotateGesturesEnabled: false,
      tiltGesturesEnabled: false,
      compassEnabled: false,
      attributionButtonPosition: AttributionButtonPosition.bottomLeft,
      // G VPN draws its own layers; the plugin's annotation layers would
      // only add work (and a text-font warning on every style load).
      annotationOrder: const [],
      foregroundLoadColor: m.bg,
    );
    if (!interactive || widget.onMarkerTap == null) return map;
    // Watches taps without taking them from the map's own pan and zoom.
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _pointerDown,
      onPointerUp: _pointerUp,
      child: map,
    );
  }
}

// ── GeoJSON helpers ─────────────────────────────────────────────────────

String _hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

Map<String, dynamic> _collection(List<Map<String, dynamic>> features) =>
    {'type': 'FeatureCollection', 'features': features};

Map<String, dynamic> _feature(Map<String, dynamic> geometry, Map<String, Object> props) =>
    {'type': 'Feature', 'geometry': geometry, 'properties': props};

Map<String, dynamic> _pointJson(LatLon p) => {
      'type': 'Point',
      'coordinates': [p.lon, p.lat],
    };

/// A closed ring of [metres] radius around [c], on the sphere.
List<List<double>> _circle(LatLon c, double metres) {
  const earth = 6371000.0;
  final d = metres / earth;
  final lat1 = c.lat * math.pi / 180, lon1 = c.lon * math.pi / 180;
  return [
    for (var i = 0; i <= 64; i++)
      () {
        final b = 2 * math.pi * i / 64;
        final lat2 = math.asin(math.sin(lat1) * math.cos(d) + math.cos(lat1) * math.sin(d) * math.cos(b));
        final lon2 = lon1 + math.atan2(math.sin(b) * math.sin(d) * math.cos(lat1), math.cos(d) - math.sin(lat1) * math.sin(lat2));
        return [lon2 * 180 / math.pi, lat2 * 180 / math.pi];
      }(),
  ];
}

/// A gently bowed line from [a] to [b], taking the short way round.
List<List<double>> _route(LatLon a, LatLon b) {
  var dLon = b.lon - a.lon;
  if (dLon > 180) dLon -= 360;
  if (dLon < -180) dLon += 360;
  final bow = math.min(12.0, math.sqrt(dLon * dLon + math.pow(b.lat - a.lat, 2)) * .15);
  return [
    for (var i = 0; i <= 32; i++)
      () {
        final t = i / 32;
        return [a.lon + dLon * t, a.lat + (b.lat - a.lat) * t + bow * math.sin(math.pi * t)];
      }(),
  ];
}
