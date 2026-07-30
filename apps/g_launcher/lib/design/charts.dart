import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'components/chrome_theme.dart';

/// Charts, dressed as the active distro.
///
/// ─── WHY THESE ARE WRAPPERS AND NOT fl_chart AT THE CALL SITE ───────────────
///
/// Two reasons, and the second is the load-bearing one.
///
/// fl_chart's configuration is verbose enough that three pages configuring it
/// inline would drift: one would show a grid, another would round its corners
/// differently, a third would forget to turn touch off. More importantly, every
/// colour here has to come from [ChromeScope] rather than from a constant. A
/// storage bar in a fixed blue is the one place a settings screen forgets which
/// distro it is wearing, and `no_constants.sh` exists precisely because that
/// keeps happening.
///
/// Touch is OFF on all of them. These are readouts on a settings page, not an
/// analysis tool, and a tooltip that appears when you meant to scroll is worse
/// than no tooltip.

/// The SERIES colours, and the one place in the app that does not take its
/// palette from the distro.
///
/// ─── WHY THESE ARE LITERAL AND WHY THAT IS NOT A no_constants VIOLATION ─────
///
/// A ThemePalette carries six colours, exactly one of which is chromatic: the
/// accent. Charts need CATEGORICAL colour, several hues that are distinguishable
/// from each other at a glance, and deriving four of those from one accent gives
/// four shades of orange that nobody can tell apart in a legend.
///
/// So download is cyan and upload is pink wherever you are, the way every system
/// monitor on every desktop has always done it, and the distro identity stays in
/// the chrome around the chart rather than inside it.
///
/// Chosen bright and mid-saturation so they read on a near-black terminal
/// palette and on a light Yaru surface without a per-mode variant.
///
/// theme-exempt: categorical series colour cannot be derived from a six-colour
/// theme palette, and a legend of four oranges is unreadable.
abstract final class ChartColors {
  const ChartColors._();

  static const down = Color(0xFF22D3EE);
  static const up = Color(0xFFF472B6);
  static const warm = Color(0xFFFBBF24);
  static const good = Color(0xFF4ADE80);
  static const cool = Color(0xFFA78BFA);
}

/// A filled line, for a rate over time.
///
/// Takes plain doubles rather than FlSpots: the caller has a list of samples
/// oldest-first, and the index IS the x axis. Handing it spots would mean every
/// caller doing the same enumerate.
class TrendChart extends StatelessWidget {
  const TrendChart({
    super.key,
    required this.series,
    this.height = 96,
    this.color,
    this.secondSeries,
    this.secondColor,
    this.minY,
    this.maxY,
  });

  /// Oldest first.
  final List<double> series;

  /// A second line on the same axes, for up against down.
  final List<double>? secondSeries;

  final Color? color;
  final Color? secondColor;
  final double height;

  /// Both default to the data's own range. Pass [minY] 0 for anything where the
  /// axis genuinely starts at zero, which is most rates: letting a flat line at
  /// 4.2 MB/s fill the box makes an idle connection look like a busy one.
  final double? minY;
  final double? maxY;

  @override
  Widget build(BuildContext context) {
    final c = ChromeScope.of(context).colors;
    final primary = color ?? c.accent;
    final second = secondColor ?? c.textMuted;

    final all = <double>[...series, ...?secondSeries];
    final top = maxY ?? (all.isEmpty ? 1.0 : all.reduce((a, b) => a > b ? a : b));
    final bottom =
        minY ?? (all.isEmpty ? 0.0 : all.reduce((a, b) => a < b ? a : b));

    // A flat series has zero range, and a zero-range axis makes fl_chart draw
    // the line on the border or not at all. Padding it by a tenth keeps a
    // steady value visible as a steady value.
    final pad = (top - bottom).abs() < 0.0001 ? (top.abs() * 0.1 + 1) : 0.0;

    final count =
        [series.length, secondSeries?.length ?? 0].reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (count - 1).toDouble().clamp(1, double.infinity),
          minY: bottom - pad,
          maxY: top + pad,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: const FlTitlesData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            if (secondSeries != null && secondSeries!.isNotEmpty)
              _line(secondSeries!, second, fill: false),
            if (series.isNotEmpty) _line(series, primary, fill: true),
          ],
        ),
      ),
    );
  }

  LineChartBarData _line(List<double> data, Color colour, {required bool fill}) {
    return LineChartBarData(
      spots: [
        for (var i = 0; i < data.length; i++) FlSpot(i.toDouble(), data[i]),
      ],
      isCurved: true,
      // Curvature is deliberately low. fl_chart's default overshoots on a
      // spiky series, which on a network rate draws dips below zero that the
      // data never contained.
      curveSmoothness: 0.18,
      preventCurveOverShooting: true,
      color: colour,
      barWidth: 2,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: fill,
        color: colour.withValues(alpha: 0.16),
      ),
    );
  }
}

/// A ring, for one quantity against a known total.
///
/// The number lives in the middle rather than in a legend, which is what makes
/// a ring worth using here instead of a bar: the headline and the chart are the
/// same object, so there is nothing to cross-reference.
class RingGauge extends StatelessWidget {
  const RingGauge({
    super.key,
    required this.fraction,
    required this.label,
    this.caption,
    this.color,
    this.size = 132,
  });

  /// 0 to 1. Clamped, because a rate that briefly exceeds its own total is a
  /// rounding artefact and not worth drawing as an overfull ring.
  final double fraction;

  /// The big number in the middle.
  final String label;

  /// The quiet line under it.
  final String? caption;

  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    final c = d.colors;
    final filled = fraction.clamp(0.0, 1.0);
    final colour = color ?? c.accent;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              startDegreeOffset: -90,
              sectionsSpace: 0,
              centerSpaceRadius: size * 0.34,
              sections: [
                PieChartSectionData(
                  value: filled == 0 ? 0.0001 : filled,
                  color: colour,
                  radius: size * 0.14,
                  showTitle: false,
                ),
                PieChartSectionData(
                  value: (1 - filled) == 0 ? 0.0001 : (1 - filled),
                  // The track, not a second quantity. Faint enough to read as
                  // the empty part of one ring rather than as a rival slice.
                  color: c.lineStrong,
                  radius: size * 0.14,
                  showTitle: false,
                ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: d.text.display.copyWith(fontSize: size * 0.19)),
              if (caption != null)
                Text(
                  caption!,
                  style: d.text.caption.copyWith(color: c.textMuted),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The label under a chart, and the legend when there are two lines.
class ChartLegend extends StatelessWidget {
  const ChartLegend({super.key, required this.entries});

  /// Label to colour, in the order the lines are drawn.
  final Map<String, Color> entries;

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);

    return Row(
      children: [
        for (final e in entries.entries) ...[
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(color: e.value, shape: BoxShape.circle),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Text(
              e.key,
              style: d.text.caption.copyWith(color: d.colors.textMuted),
            ),
          ),
        ],
      ],
    );
  }
}


/// Categorical bars, drawn from labelled values.
///
/// ─── WHY A BAR AND NOT A THIRD RING ─────────────────────────────────────────
///
/// A ring answers "how much of the whole", and once every page on a screen
/// answers that same question with the same shape, the screen stops carrying
/// information and starts carrying decoration. A bar answers "how do these
/// compare", which is a different question and the right one for two or three
/// named quantities.
///
/// Labels are drawn HERE rather than through fl_chart's axis titles. The titles
/// API wants a widget builder per tick and a reserved size, which is four more
/// pieces of configuration to keep in step across three pages, for a row of
/// text this can lay out itself and centre exactly under each rod.
class BarsChart extends StatelessWidget {
  const BarsChart({
    super.key,
    required this.bars,
    this.height = 130,
    this.maxY,
  });

  /// Label, value, colour. Order is left to right.
  final List<({String label, double value, Color color})> bars;

  final double height;

  /// Defaults to the tallest bar plus headroom, so a bar never touches the top
  /// edge and read as clipped.
  final double? maxY;

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    if (bars.isEmpty) return const SizedBox.shrink();

    final top = maxY ??
        bars.map((b) => b.value).reduce((a, b) => a > b ? a : b) * 1.15;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: height,
          child: BarChart(
            BarChartData(
              maxY: top <= 0 ? 1 : top,
              minY: 0,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: const FlTitlesData(show: false),
              barTouchData: BarTouchData(enabled: false),
              barGroups: [
                for (var i = 0; i < bars.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: bars[i].value,
                        color: bars[i].color,
                        width: 26,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final b in bars)
              Expanded(
                child: Text(
                  b.label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: d.text.caption.copyWith(color: d.colors.textMuted),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
