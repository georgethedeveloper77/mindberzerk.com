/// The driver half of the transition benchmark.
///
/// ─── WHY THERE IS A DRIVER AT ALL ───────────────────────────────────────────
///
/// `integration_test` can run on device with `flutter test`, and that is enough
/// for a pass/fail test. It is not enough here: `watchPerformance` collects a
/// timeline on the device and has nowhere to put it, so the summaries only
/// reach the host when a driver is listening for them. Running the benchmark
/// with `flutter test` produces a green tick and no numbers, which is the most
/// annoying possible outcome.
///
///   flutter drive \
///     --driver=test_driver/integration_test.dart \
///     --target=integration_test/drawer_transition_bench_test.dart \
///     --profile
///
/// ─── IT PRINTS A TABLE RATHER THAN LEAVING JSON ABOUT ───────────────────────
///
/// The summaries are written to `build/` as well, because they carry far more
/// than the four numbers below and are worth keeping across a change. But a
/// benchmark whose output is six JSON files is a benchmark nobody reads twice.
/// The table is the thing that answers the question in the moment.
library;

import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

/// Report keys the harness produces, so a new style needs no change here.
const _prefix = 'transition_';

Future<void> main() {
  return integrationDriver(
    // ─── ONLY THE CALLBACK. THERE IS NO `writeResponseData` PARAMETER ──────
    //
    // `writeResponseData` is the name of the package's DEFAULT callback, a
    // top-level function that dumps the response to
    // `build/integration_response_data.json`. Passing it as a named argument
    // reads plausibly and does not compile.
    //
    // Supplying `responseDataCallback` replaces that default, which is the
    // point: the summaries are wanted per style with a table printed, not as
    // one undifferentiated blob.
    responseDataCallback: (data) async {
      if (data == null) {
        stderr.writeln('No timeline data came back. Was this run in --profile?');
        return;
      }

      final rows = <_Row>[];

      for (final entry in data.entries) {
        if (!entry.key.startsWith(_prefix)) continue;

        final summary = entry.value;
        if (summary is! Map) continue;
        final map = summary.cast<String, dynamic>();

        // Written for keeping, not for reading. A summary carries per-frame
        // histograms and percentiles that the table below leaves out, and they
        // are what you want when a number moves and nobody knows why.
        final name = entry.key.substring(_prefix.length);
        final file = File('build/transition_$name.timeline_summary.json');
        await file.parent.create(recursive: true);
        await file.writeAsString(
          const JsonEncoder.withIndent('  ').convert(map),
        );

        rows.add(
          _Row(
            name: name,
            build: _num(map, 'average_frame_build_time_millis'),
            worstBuild: _num(map, 'worst_frame_build_time_millis'),
            raster: _num(map, 'average_frame_rasterizer_time_millis'),
            worstRaster: _num(map, 'worst_frame_rasterizer_time_millis'),
            missed: _num(map, 'missed_frame_build_budget_count'),
          ),
        );
      }

      if (rows.isEmpty) {
        stderr.writeln('No keys starting with "$_prefix" in the response.');
        return;
      }

      // The floor first, then the paged styles in the order they were added, so
      // a new arm appends rather than reshuffling a table someone is comparing
      // against yesterday's run.
      // vertical first as the floor, slide next as the transform baseline, then
      // whatever else ran. Stable order matters more than clever order: the
      // table is read against yesterday's run.
      const order = ['vertical', 'slide', 'cube', 'cylinder', 'sphere',
          'depth', 'stack'];
      int rank(String n) {
        final i = order.indexOf(n);
        return i < 0 ? order.length : i;
      }
      rows.sort((a, b) => rank(a.name).compareTo(rank(b.name)));

      final baseline = rows
          .firstWhere((r) => r.name == 'cube', orElse: () => rows.last)
          .raster;

      stdout.writeln('');
      stdout.writeln('  Drawer transitions, milliseconds per frame');
      stdout.writeln('  ${'-' * 74}');
      stdout.writeln(
        '  ${'style'.padRight(12)}'
        '${'build'.padLeft(8)}'
        '${'worst'.padLeft(8)}'
        '${'raster'.padLeft(9)}'
        '${'worst'.padLeft(8)}'
        '${'missed'.padLeft(8)}'
        '${'vs cube'.padLeft(10)}',
      );
      stdout.writeln('  ${'-' * 74}');

      for (final r in rows) {
        final ratio = baseline > 0 ? r.raster / baseline : 0.0;
        stdout.writeln(
          '  ${r.name.padRight(12)}'
          '${r.build.toStringAsFixed(2).padLeft(8)}'
          '${r.worstBuild.toStringAsFixed(2).padLeft(8)}'
          '${r.raster.toStringAsFixed(2).padLeft(9)}'
          '${r.worstRaster.toStringAsFixed(2).padLeft(8)}'
          '${r.missed.toStringAsFixed(0).padLeft(8)}'
          '${'${ratio.toStringAsFixed(2)}x'.padLeft(10)}',
        );
      }

      stdout.writeln('  ${'-' * 74}');
      stdout.writeln(
        '  Read the RATIO, not the absolute. A 120Hz phone has 8.3ms a frame,\n'
        '  so a style at 1.5ms has the headroom to survive a phone a third as\n'
        '  fast, and one at 5ms passes here and stutters on a budget device.\n'
        '  "worst" matters more than "build": jank is a tail problem.',
      );
      stdout.writeln('');
    },
  );
}

double _num(Map<String, dynamic> map, String key) {
  final v = map[key];
  if (v is num) return v.toDouble();
  return 0;
}

class _Row {
  const _Row({
    required this.name,
    required this.build,
    required this.worstBuild,
    required this.raster,
    required this.worstRaster,
    required this.missed,
  });

  final String name;
  final double build;
  final double worstBuild;
  final double raster;
  final double worstRaster;
  final double missed;
}
