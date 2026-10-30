// Guards the pack-update reseed: a new starter replaces a desktop only while
// the user has not touched what the old one placed.
import 'package:flutter_test/flutter_test.dart';
import 'package:g_launcher/data/prefs/launcher_prefs.dart';
import 'package:g_launcher/data/prefs/starter_desktop.dart';

void main() {
  const placed = [
    Desklet(id: 'a', kind: 'clock', page: 0, col: 0, row: 0, spanX: 4),
  ];
  final mark = StarterDesktop.seedMark('old', placed);

  test('a changed starter reseeds an untouched desktop', () {
    expect(StarterDesktop.shouldReseed(mark, 'new', placed), isTrue);
  });

  test('an unchanged starter never reseeds', () {
    expect(StarterDesktop.shouldReseed(mark, 'old', placed), isFalse);
  });

  test('a desktop the user changed is never replaced', () {
    const moved = [
      Desklet(id: 'a', kind: 'clock', page: 0, col: 2, row: 0, spanX: 4),
    ];
    expect(StarterDesktop.shouldReseed(mark, 'new', moved), isFalse);
  });

  test('no mark (seeded before this build) never reseeds', () {
    expect(StarterDesktop.shouldReseed(null, 'new', placed), isFalse);
  });
}
