import 'package:flutter_test/flutter_test.dart';
import 'package:g_launcher/features/desklets/conky/conky_template.dart';

final _now = DateTime(2026, 10, 29, 14, 5, 9); // a Thursday

ConkyReadings _r({
  Map<String, String?> text = const {},
  Map<String, double?> bars = const {},
}) =>
    ConkyReadings(now: _now, text: text, bars: bars);

void main() {
  group('variables', () {
    test('known values substitute, both syntaxes', () {
      final lines = ConkyTemplate.render(
        r'up ${uptime_short} on $nodename',
        _r(text: {'uptime_short': '3d 4h', 'nodename': 'pixel'}),
      );
      expect(lines.single.plain, 'up 3d 4h on pixel');
    });

    test('a known variable with no reading drops its whole line', () {
      final lines = ConkyTemplate.render(
        'cpu \${cpu}%\nram \${mem}',
        _r(text: {'cpu': null, 'mem': '5.1G'}),
      );
      expect([for (final l in lines) l.plain], ['ram 5.1G']);
    });

    test('an unknown variable is printed as typed', () {
      final lines = ConkyTemplate.render(r'${top name 1}', _r());
      expect(lines.single.plain, r'${top name 1}');
    });
  });

  group('layout', () {
    test('alignr splits the line', () {
      final l = ConkyTemplate.render(
        r'ram${alignr}${mem}',
        _r(text: {'mem': '5.1G'}),
      ).single;
      expect(l.left, [const ConkyText('ram', ConkyInk.normal)]);
      expect(l.right, [const ConkyText('5.1G', ConkyInk.normal)]);
    });

    test('hr is a rule, blank lines are kept, control-only lines are not', () {
      final lines = ConkyTemplate.render('\${hr}\n\n\${color1}', _r());
      expect(lines.length, 2);
      expect(lines.first.rule, isTrue);
      expect(lines.last.isEmpty, isTrue);
    });

    test('colours carry until reset', () {
      final l = ConkyTemplate.render(
        r'${color1}a${color2}b${color}c',
        _r(),
      ).single;
      expect(l.left, const [
        ConkyText('a', ConkyInk.accent),
        ConkyText('b', ConkyInk.muted),
        ConkyText('c', ConkyInk.normal),
      ]);
    });

    test('bars clamp and drop like text', () {
      expect(
        ConkyTemplate.render(r'${membar}', _r(bars: {'membar': 1.4}))
            .single
            .left
            .single,
        const ConkyBar(1.0, ConkyInk.accent),
      );
      expect(ConkyTemplate.render(r'${cpubar}', _r()), isEmpty);
    });

    test('long configs are bounded', () {
      final rc = List.filled(100, 'x').join('\n');
      expect(ConkyTemplate.render(rc, _r()).length, ConkyTemplate.maxLines);
    });
  });

  group('time', () {
    test('strftime subset', () {
      expect(ConkyTemplate.strftime('%a %d %b %Y', _now), 'Thu 29 Oct 2026');
      expect(ConkyTemplate.strftime('%H:%M:%S', _now), '14:05:09');
      expect(ConkyTemplate.strftime('%I %p %e', _now), '02 PM 29');
      expect(ConkyTemplate.strftime('%q 100%%', _now), '%q 100%');
    });

    test('time defaults to HH:MM, and seconds are detected', () {
      expect(ConkyTemplate.render(r'${time}', _r()).single.plain, '14:05');
      expect(ConkyTemplate.needsSeconds(r'${time %H:%M:%S}'), isTrue);
      expect(ConkyTemplate.needsSeconds(r'${time %T}'), isTrue);
      expect(ConkyTemplate.needsSeconds(r'${time %H:%M}'), isFalse);
    });
  });

  test('the default rc renders with full readings', () {
    final lines = ConkyTemplate.render(
      ConkyTemplate.defaultRc,
      _r(
        text: {
          for (final v in ConkyTemplate.textVariables) v: 'v',
        },
        bars: {
          for (final v in ConkyTemplate.barVariables) v: 0.5,
        },
      ),
    );
    expect(lines.length, ConkyTemplate.defaultRc.split('\n').length);
    expect(lines.first.left.first, const ConkyText('v', ConkyInk.accent));
  });
}
