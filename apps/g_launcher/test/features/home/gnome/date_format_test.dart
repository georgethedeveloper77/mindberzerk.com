import 'package:flutter_test/flutter_test.dart';
import 'package:g_launcher/system/system_stats.dart';

void main() {
  final thu18Jun = DateTime(2026, 6, 18, 19, 42);

  test('top bar clock matches the mockup', () {
    expect(formatTime(thu18Jun), '19:42');
    expect(formatDateShort(thu18Jun), 'Thu 18 Jun');
  });

  test('conky date matches the mockup', () {
    expect(formatDateLong(thu18Jun), 'Thursday, 18 June');
  });

  test('midnight is 00:00, not 24:00 or 0:00', () {
    expect(formatTime(DateTime(2026, 1, 1, 0, 0)), '00:00');
  });

  test('net rates render like the mockup', () {
    expect(SystemStats.rate(4.2 * 1024 * 1024), '4.2M');
    expect(SystemStats.rate(0.8 * 1024 * 1024), '0.8M');
    expect(SystemStats.rate(900), '1K');
    expect(SystemStats.rate(null), '—');
  });

  test('memory label matches the mockup', () {
    const s = SystemStats(memUsedGb: 3.1, memTotalGb: 8);
    expect(s.memLabel, '3.1/8G');
  });

  test('stats absent → nothing to render, and no placeholder text', () {
    const s = SystemStats();
    expect(s.hasMemory, isFalse);
    expect(s.hasNet, isFalse);
    expect(s.memLabel, isEmpty);
  });
}
