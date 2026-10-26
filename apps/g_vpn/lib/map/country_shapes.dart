import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'country_shapes_data.dart';

/// A latitude/longitude box in degrees.
@immutable
class GeoBounds {
  const GeoBounds(this.west, this.south, this.east, this.north);

  final double west;
  final double south;
  final double east;
  final double north;

  double get width => east - west;
  double get height => north - south;
  double get centerLon => (west + east) / 2;
  double get centerLat => (south + north) / 2;

  bool contains(double lon, double lat) =>
      lon >= west && lon <= east && lat >= south && lat <= north;

  bool overlaps(GeoBounds other) =>
      west <= other.east && east >= other.west && south <= other.north && north >= other.south;

  /// Grows the box by [degrees] on every side.
  GeoBounds inflate(double degrees) =>
      GeoBounds(west - degrees, south - degrees, east + degrees, north + degrees);

  @override
  bool operator ==(Object other) =>
      other is GeoBounds &&
      other.west == west &&
      other.south == south &&
      other.east == east &&
      other.north == north;

  @override
  int get hashCode => Object.hash(west, south, east, north);

  @override
  String toString() => 'GeoBounds($west, $south, $east, $north)';
}

/// One country's outline: exterior rings only, as flat lon/lat pairs.
class CountryShape {
  CountryShape._(this.code, this.rings, this.bounds, this.focus);

  /// ISO 3166-1 alpha-2, upper case (the code Cloudflare reports).
  final String code;

  /// Each ring is `[lon0, lat0, lon1, lat1, ...]` in degrees.
  final List<Float32List> rings;

  /// Box around every ring, overseas territories included.
  final GeoBounds bounds;

  /// Box around the largest ring: the mainland, which is what the camera
  /// should frame (France without Guiana, the US without Alaska).
  final GeoBounds focus;

  /// The outline as a GeoJSON MultiPolygon geometry, for map layers.
  Map<String, dynamic> toGeoJson() => {
        'type': 'MultiPolygon',
        'coordinates': [
          for (final ring in rings)
            [
              [
                for (var i = 0; i < ring.length; i += 2) [ring[i], ring[i + 1]],
                // GeoJSON rings close on their first point.
                [ring[0], ring[1]],
              ],
            ],
        ],
      };
}

/// Bundled Natural Earth outlines, decoded once on first use.
class CountryShapes {
  CountryShapes._(this._byCode);

  static CountryShapes? _instance;

  /// The shared, lazily decoded set.
  static CountryShapes get instance => _instance ??= CountryShapes.decode(countryShapesData);

  final Map<String, CountryShape> _byCode;

  /// Every country, in code order.
  Iterable<CountryShape> get all => _byCode.values;

  /// The country for an ISO alpha-2 [code], or null when unknown.
  CountryShape? operator [](String? code) =>
      code == null ? null : _byCode[code.toUpperCase()];

  /// Countries whose outline box touches [view], for painting only what shows.
  Iterable<CountryShape> within(GeoBounds view) => all.where((c) => c.bounds.overlaps(view));

  /// Decodes the base64 varint stream written by `tool/build_country_shapes.py`.
  @visibleForTesting
  static CountryShapes decode(String data) {
    final bytes = base64Decode(data);
    final reader = _VarintReader(bytes);
    final byCode = <String, CountryShape>{};

    while (!reader.isDone) {
      final code = String.fromCharCodes([reader.byte(), reader.byte()]);
      final ringCount = reader.unsigned();
      final rings = <Float32List>[];
      var west = 180.0, south = 90.0, east = -180.0, north = -90.0;
      GeoBounds? focus;
      var focusArea = -1.0;

      for (var r = 0; r < ringCount; r++) {
        final count = reader.unsigned();
        final ring = Float32List(count * 2);
        var x = 0, y = 0;
        var rw = 180.0, rs = 90.0, re = -180.0, rn = -90.0;
        for (var i = 0; i < count; i++) {
          x += reader.signed();
          y += reader.signed();
          final lon = x / 100.0;
          final lat = y / 100.0;
          ring[i * 2] = lon;
          ring[i * 2 + 1] = lat;
          if (lon < rw) rw = lon;
          if (lon > re) re = lon;
          if (lat < rs) rs = lat;
          if (lat > rn) rn = lat;
        }
        rings.add(ring);

        // The mainland is the ring with the largest box.
        final area = (re - rw) * (rn - rs);
        if (area > focusArea) {
          focusArea = area;
          focus = GeoBounds(rw, rs, re, rn);
        }
        if (rw < west) west = rw;
        if (re > east) east = re;
        if (rs < south) south = rs;
        if (rn > north) north = rn;
      }

      if (rings.isNotEmpty) {
        byCode[code] = CountryShape._(code, rings, GeoBounds(west, south, east, north), focus!);
      }
    }
    return CountryShapes._(byCode);
  }
}

/// Reads LEB128 varints, with zigzag for signed values.
class _VarintReader {
  _VarintReader(this._bytes);

  final Uint8List _bytes;
  int _offset = 0;

  bool get isDone => _offset >= _bytes.length;

  int byte() => _bytes[_offset++];

  int unsigned() {
    var result = 0;
    var shift = 0;
    while (true) {
      final b = _bytes[_offset++];
      result |= (b & 0x7F) << shift;
      if (b & 0x80 == 0) return result;
      shift += 7;
    }
  }

  int signed() {
    final n = unsigned();
    return (n >> 1) ^ -(n & 1);
  }
}
