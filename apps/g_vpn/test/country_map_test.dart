import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g_vpn/design/country_map.dart';
import 'package:g_vpn/design/country_shapes.dart';
import 'package:g_vpn/design/world_map.dart' show LatLon;

void main() {
  test('Mercator round trips', () {
    for (final lat in [-60.0, -1.29, 0.0, 35.69, 70.0]) {
      expect(mercLat(mercY(lat)), closeTo(lat, 1e-9));
    }
  });

  test('exposed framing keeps Nairobi inside the frame', () {
    const frame = Rect.fromLTRB(24, 200, 366, 420);
    final box = framingFor(country: 'KE', point: const LatLon(-1.29, 36.82), minSpan: 14);
    final camera = MapCamera.fit(box, frame);
    final p = camera.project(36.82, -1.29, frame.center);
    expect(frame.contains(p), isTrue);
    expect(box.width, greaterThanOrEqualTo(14));
  });

  test('protected framing shows a region, not just the country', () {
    final box = framingFor(country: 'JP', point: const LatLon(35.69, 139.69), minSpan: 34);
    expect(box.width, greaterThanOrEqualTo(34));
    expect(box.contains(126.98, 37.57), isTrue, reason: 'Seoul should be in view');
  });

  test('a pin outside its mainland stays in view', () {
    final box = framingFor(country: 'US', point: const LatLon(61.22, -149.9), minSpan: 14);
    expect(box.contains(-149.9, 61.22), isTrue);
  });

  test('unknown country falls back to the pin, then the world', () {
    final pinned = framingFor(country: 'ZZ', point: const LatLon(10, 10), minSpan: 14);
    expect(pinned.contains(10, 10), isTrue);
    final world = framingFor(minSpan: 14);
    expect(world.width, greaterThan(300));
  });

  test('zoom is clamped', () {
    const frame = Rect.fromLTWH(0, 0, 400, 300);
    final tiny = MapCamera.fit(const GeoBounds(103.6, 1.2, 104.1, 1.5), frame);
    expect(tiny.k, MapCamera.maxK);
  });
}
