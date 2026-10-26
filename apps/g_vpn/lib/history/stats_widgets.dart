import 'package:flutter/material.dart';

import '../design/meridian.dart';
import '../i18n/strings.g.dart';
import 'usage.dart';

/// "9 h 40 m", or "25 m" under an hour.
String formatDuration(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  return h > 0 ? t.stats.hm(h: h, m: m) : t.stats.m(m: m);
}

/// The last [count] local days, oldest first, ending today.
List<DateTime> lastDays(int count) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return [for (var i = count - 1; i >= 0; i--) DateTime(today.year, today.month, today.day - i)];
}

/// The days of a period, and their totals and per-server shares.
class Period {
  Period(this.days, Map<String, UsageDay> usage)
      : entries = [for (final d in days) usage[dayKey(d)] ?? const UsageDay()];

  final List<DateTime> days;
  final List<UsageDay> entries;

  int get seconds => entries.fold(0, (sum, e) => sum + e.seconds);
  int get bytes => entries.fold(0, (sum, e) => sum + e.bytes);

  /// Servers by time (or data), biggest first.
  List<ServerUsage> servers({required bool byData}) {
    final merged = <String, ServerUsage>{};
    for (final e in entries) {
      for (final s in e.servers.entries) {
        final current = merged[s.key];
        merged[s.key] = current == null ? s.value : current.add(s.value.seconds, s.value.bytes);
      }
    }
    return merged.values.toList()
      ..sort((a, b) => byData ? b.bytes.compareTo(a.bytes) : b.seconds.compareTo(a.seconds));
  }
}

/// A simple bar chart: one bar per value, the last (today) in the brand
/// colour, labels underneath. Empty days keep a sliver so the week reads.
class UsageBars extends StatelessWidget {
  const UsageBars({super.key, required this.values, required this.labels, this.height = 110, this.gap = 8});

  final List<double> values;
  final List<String> labels;
  final double height;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final max = values.fold<double>(0, (a, b) => b > a ? b : a);
    final last = values.length - 1;
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++) ...[
            if (i > 0) SizedBox(width: gap),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    height: max <= 0 ? 4 : 4 + (height - 26) * (values[i] / max),
                    decoration: BoxDecoration(
                      color: i == last ? m.brand : m.brand.withValues(alpha: .28),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 14,
                    child: Text(
                      labels[i],
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: i == last ? m.text : m.muted),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A two-option switch, as used across Meridian cards.
class MiniSegment extends StatelessWidget {
  const MiniSegment({super.key, required this.labels, required this.index, required this.onChanged});

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: m.bg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < labels.length; i++)
            Semantics(
              selected: i == index,
              button: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(9),
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  constraints: const BoxConstraints(minHeight: 36),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == index ? m.surface2 : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: i == index ? m.text : m.muted),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
