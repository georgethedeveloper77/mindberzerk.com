import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/i18n/g_strings.dart';

/// A sampled series, drawn as a line over a fade.
///
/// The only shape that answers "is this getting worse", which is the question a
/// person opens a diagnostics screen to ask. A number alone answers "what is it
/// now", which they can get from the notification shade.
///
/// ─── NO ANIMATION, DELIBERATELY ──────────────────────────────────────────────
///
/// Everywhere else in this app a chart grows into place on first paint. Not
/// here. This one is fed by a sampler at 2 Hz, so it already moves, and an
/// entrance tween on top of live data makes the first second of every visit a
/// lie about what the phone was doing.
///
/// ─── DRAWS WHAT IT HAS ───────────────────────────────────────────────────────
///
/// A chart opened cold has one point and grows leftward over the first minute.
/// It does not stretch a single reading across the full width, because a flat
/// line back to the edge is invented history.
class GLineChart extends StatelessWidget {
  const GLineChart({
    required this.values,
    required this.colour,
    super.key,
    this.height = 72,
    this.minY,
    this.maxY,
  });

  final List<double> values;
  final Color colour;
  final double height;

  /// Fixed bounds where the scale means something absolute, such as a
  /// percentage. Left null the chart fits its own range, which is right for
  /// free memory and wrong for battery.
  final double? minY;
  final double? maxY;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    if (values.length < 2) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            // Says why rather than showing an empty box. The sampler runs only
            // while this tab is open, so a fresh visit genuinely has nothing yet.
            context.s('Collecting'),
            style: GType.monoSmall.copyWith(color: t.dim),
          ),
        ),
      );
    }

    double low = values.first;
    double high = values.first;
    for (final double value in values) {
      if (value < low) low = value;
      if (value > high) high = value;
    }
    // A flat series would otherwise give a zero height range and fl_chart draws
    // nothing at all rather than a straight line.
    if (high - low < 0.0001) high = low + 1;

    final double bottom = minY ?? low - (high - low) * 0.15;
    final double top = maxY ?? high + (high - low) * 0.15;

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minY: bottom,
          maxY: top,
          minX: 0,
          maxX: (values.length - 1).toDouble(),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: const FlTitlesData(show: false),
          // Off. This is a summary behind a heading, not an instrument, and a
          // tooltip is something people trigger by accident while scrolling.
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: <LineChartBarData>[
            LineChartBarData(
              spots: <FlSpot>[
                for (int i = 0; i < values.length; i++)
                  FlSpot(i.toDouble(), values[i]),
              ],
              isCurved: true,
              // Gentle. Above about 0.3 a curve overshoots on a spike and draws
              // a value the phone never reported.
              curveSmoothness: 0.22,
              preventCurveOverShooting: true,
              color: colour,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    colour.withValues(alpha: 0.42),
                    colour.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
