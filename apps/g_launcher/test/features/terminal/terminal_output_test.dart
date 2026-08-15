// The output functions decide whether a number on screen is honest, which is
// why they take a snapshot rather than a WidgetRef and why most of what follows
// is about what happens when a stat is NOT available.
import 'package:flutter_test/flutter_test.dart';
import 'package:g_launcher/features/terminal/ansi.dart';
import 'package:g_launcher/features/terminal/terminal_output.dart';
import 'package:g_launcher/system/system_stats.dart';

/// Run the produced lines through the parser, which is the path the screen
/// takes, and read them back without styling. Asserting on the raw strings
/// would test the escape sequences rather than what a person sees.
String rendered(List<String> lines) {
  final p = AnsiParser()..feed('${lines.join('\n')}\n');
  return p.committed.map((l) => l.text).join('\n');
}

void main() {
  group('free', () {
    test('prints the shape real free prints', () {
      final out = rendered(outputForKind(
        'free',
        const TerminalFacts(
          stats: SystemStats(memUsedGb: 3.1, memTotalGb: 8),
        ),
      ));

      expect(out, contains('total'));
      expect(out, contains('Mem:'));
      expect(out, contains('3.1Gi'));
      expect(out, contains('8.0Gi'));
      // total minus used, computed rather than reported.
      expect(out, contains('4.9Gi'));
    });

    test('says why rather than printing nothing', () {
      // A command that prints nothing is indistinguishable from one that never
      // ran, and on a shell that is the one failure you cannot debug.
      final out = rendered(outputForKind('free', const TerminalFacts()));
      expect(out, 'free: cannot read memory info');
    });

    test('a half-reported stat is still a failure, not a partial row', () {
      final out = rendered(outputForKind(
        'free',
        const TerminalFacts(stats: SystemStats(memUsedGb: 3.1)),
      ));
      expect(out, contains('cannot read'));
    });
  });

  group('df', () {
    test('prints a filesystem row', () {
      final out = rendered(outputForKind(
        'df',
        const TerminalFacts(
          stats: SystemStats(
            storageUsedBytes: 60 * 1024 * 1024 * 1024,
            storageTotalBytes: 120 * 1024 * 1024 * 1024,
          ),
        ),
      ));

      expect(out, contains('Filesystem'));
      expect(out, contains('/data'));
      expect(out, contains('50%'));
    });

    test('storage and df are the same command with two names', () {
      const facts = TerminalFacts(
        stats: SystemStats(
          storageUsedBytes: 1024,
          storageTotalBytes: 2048,
        ),
      );
      expect(
        rendered(outputForKind('df', facts)),
        rendered(outputForKind('storage', facts)),
      );
    });

    test('a nearly full disk is coloured, and only that', () {
      // The one place a number is coloured by its value. A full disk is the
      // only storage fact worth interrupting someone for.
      final full = outputForKind(
        'df',
        const TerminalFacts(
          stats: SystemStats(
            storageUsedBytes: 99,
            storageTotalBytes: 100,
          ),
        ),
      ).join();
      final roomy = outputForKind(
        'df',
        const TerminalFacts(
          stats: SystemStats(
            storageUsedBytes: 10,
            storageTotalBytes: 100,
          ),
        ),
      ).join();

      expect(full, contains('\x1b[31m'));
      expect(roomy, isNot(contains('\x1b[31m')));
    });
  });

  group('battery', () {
    test('reports direction from the charging flag, never from the sign', () {
      // The platform's current sign is not portable: most OEMs report negative
      // while discharging, several report positive.
      final out = rendered(outputForKind(
        'battery',
        const TerminalFacts(
          stats: SystemStats(
            batteryPercent: 82,
            batteryCharging: false,
            batteryCurrentMa: 450,
          ),
        ),
      ));

      expect(out, contains('Discharging'));
      expect(out, contains('82%'));
      expect(out, contains('450 mA'));
      expect(out, isNot(contains('-450')));
    });

    test('unknown charging state says Unknown rather than guessing', () {
      final out = rendered(outputForKind(
        'battery',
        const TerminalFacts(stats: SystemStats(batteryPercent: 50)),
      ));
      expect(out, contains('Unknown'));
    });

    test('no battery information is an error line', () {
      final out = rendered(outputForKind('battery', const TerminalFacts()));
      expect(out, contains('acpi:'));
    });
  });

  group('network', () {
    test('reports transport and throughput', () {
      final out = rendered(outputForKind(
        'network',
        const TerminalFacts(
          stats: SystemStats(
            transport: 'wifi',
            netDownBytesPerSec: 4.2 * 1024 * 1024,
            netUpBytesPerSec: 800 * 1024,
          ),
        ),
      ));

      expect(out, contains('wifi'));
      expect(out, contains('4.2M/s'));
    });

    test('never prints an SSID', () {
      // Reading the network name needs location permission on Android 10 and
      // above, and this launcher does not ask for location to print a
      // throughput figure. Asserted so nobody adds it back later.
      final out = rendered(outputForKind(
        'network',
        const TerminalFacts(stats: SystemStats(transport: 'wifi')),
      ));
      expect(out.toLowerCase(), isNot(contains('ssid')));
    });
  });

  group('uptime', () {
    test('needs the stats channel', () {
      final out = rendered(outputForKind('uptime', const TerminalFacts()));
      expect(out, contains('no stats channel'));
    });

    test('prints the elapsed time', () {
      final out = rendered(outputForKind(
        'uptime',
        TerminalFacts(
          stats: const SystemStats(uptime: Duration(hours: 3, minutes: 12)),
          now: DateTime(2026, 8, 14, 9, 41),
        ),
      ));
      expect(out, contains('up'));
      expect(out, contains('3h'));
    });
  });

  group('date', () {
    test('prints the shape date prints, not a locale format', () {
      final out = rendered(outputForKind(
        'clock',
        TerminalFacts(now: DateTime(2026, 8, 14, 9, 41, 7)),
      ));
      // Friday 14 August 2026.
      expect(out, 'Fri Aug 14 09:41:07 2026');
    });
  });

  group('ls', () {
    test('says so when the app list has not loaded', () {
      final out = rendered(outputForKind('ls', const TerminalFacts()));
      expect(out, contains('ls:'));
    });
  });

  group('unknown kinds', () {
    test('name the kind rather than printing nothing', () {
      // A gap in the table is a one-line fix only if the output says which
      // kind is missing.
      final out = rendered(outputForKind('teleport', const TerminalFacts()));
      expect(out, contains('teleport'));
    });
  });

  group('help', () {
    test('groups by category and marks the locked rows', () {
      final out = rendered(helpOutput([
        (
          category: 'Launcher',
          name: 'open',
          description: 'Launch an app',
          locked: false,
        ),
        (
          category: 'Remote',
          name: 'sftp',
          description: 'Transfer files',
          locked: true,
        ),
      ]));

      expect(out, contains('LAUNCHER'));
      expect(out, contains('REMOTE'));
      expect(out, contains('[pro]'));
      // The free row carries no marker.
      final openLine =
          out.split('\n').firstWhere((l) => l.contains('open'));
      expect(openLine, isNot(contains('pro')));
    });

    test('an empty set prints nothing rather than a bare heading', () {
      expect(helpOutput(const []), isEmpty);
    });
  });

  group('escape sequences survive the round trip', () {
    test('colour is applied by the parser, not baked into the text', () {
      // Local output takes the same path a remote session will, so a colour
      // bug can only exist in one place.
      final lines = outputForKind(
        'free',
        const TerminalFacts(stats: SystemStats(memUsedGb: 1, memTotalGb: 4)),
      );
      expect(lines.join(), contains('\x1b['));

      final p = AnsiParser()..feed('${lines.join('\n')}\n');
      expect(p.committed.first.text, isNot(contains('\x1b')));
    });
  });
}
