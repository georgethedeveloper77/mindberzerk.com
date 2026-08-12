import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';

/// One bar.
class GBarDatum {
  const GBarDatum({
    required this.label,
    required this.value,
    required this.colour,
  });

  /// Short. It sits under a bar about forty pixels wide.
  final String label;

  final double value;
  final Color colour;
}

/// A bar chart that grows into place.
///
/// ─── WHY THE ANIMATION IS OURS AND NOT THE LIBRARY'S ─────────────────────────
///
/// fl_chart animates between two data sets when the data changes, which is the
/// wrong trigger here: on a screen that reads its numbers once, the data never
/// changes, so nothing ever moves. Driving the values through a tween from zero
/// gives the growth on first paint, and the library's own interpolation smooths
/// each step on top of it.
///
/// It also keeps this wrapper down to the two constructor arguments every
/// version of fl_chart has agreed on, rather than the animation parameters that
/// have been renamed between releases.
///
/// ─── BARS GROW FROM THE BASELINE ─────────────────────────────────────────────
///
/// Not fading in, not sliding sideways. A bar is a measurement, and a
/// measurement that draws itself upward reads as one being taken.
class GBarChart extends StatelessWidget {
  const GBarChart({required this.data, super.key, this.height = 148});

  final List<GBarDatum> data;
  final double height;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    if (data.isEmpty) return const SizedBox.shrink();

    final double peak = data
        .map((GBarDatum d) => d.value)
        .reduce((double a, double b) => a > b ? a : b);
    if (peak <= 0) return const SizedBox.shrink();

    final bool still = MediaQuery.disableAnimationsOf(context);

    return SizedBox(
      height: height,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: still ? 1 : 0, end: 1),
        duration: const Duration(milliseconds: 720),
        curve: Curves.easeOutCubic,
        builder: (BuildContext context, double grown, Widget? child) => BarChart(
          BarChartData(
            // Headroom, so the tallest bar does not touch the top edge and read
            // as clipped.
            maxY: peak * 1.12,
            minY: 0,
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            // Touch off. These are a summary sitting behind a heading, not an
            // instrument, and a tooltip on a home screen chart is a thing people
            // trigger by accident while scrolling.
            barTouchData: BarTouchData(enabled: false),
            titlesData: FlTitlesData(
              show: true,
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 26,
                  getTitlesWidget: (double value, TitleMeta meta) {
                    final int index = value.round();
                    if (index < 0 || index >= data.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        data[index].label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GType.micro.copyWith(color: t.dim),
                      ),
                    );
                  },
                ),
              ),
            ),
            barGroups: <BarChartGroupData>[
              for (int i = 0; i < data.length; i++)
                BarChartGroupData(
                  x: i,
                  barRods: <BarChartRodData>[
                    BarChartRodData(
                      // A floor of one percent so a category that exists but is
                      // tiny still shows a mark on the baseline. A missing bar
                      // reads as broken; a stub reads as nearly nothing, which
                      // is the truth.
                      toY:
                          (data[i].value <= 0 ? peak * 0.01 : data[i].value) *
                          grown,
                      color: data[i].colour,
                      width: 20,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(5),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
