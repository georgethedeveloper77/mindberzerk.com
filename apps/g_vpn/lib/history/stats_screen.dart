import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../alerts/report_screen.dart';
import '../design/flag.dart';
import '../design/meridian.dart';
import '../design/meridian_widgets.dart';
import '../home/connect_card.dart' show formatBytes;
import '../i18n/strings.g.dart';
import 'stats_widgets.dart';
import 'usage.dart';

/// Short weekday letters for [days], in the phone's language.
List<String> _weekdayLabels(BuildContext context, List<DateTime> days) {
  final narrow = MaterialLocalizations.of(context).narrowWeekdays;
  return [for (final d in days) narrow[d.weekday % 7]];
}

/// Home's "This week": protected time or data for the last seven days.
class StatsCard extends ConsumerStatefulWidget {
  const StatsCard({super.key});

  @override
  ConsumerState<StatsCard> createState() => _StatsCardState();
}

class _StatsCardState extends ConsumerState<StatsCard> {
  bool _data = false;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final usage = ref.watch(usageProvider).value ?? const <String, UsageDay>{};
    final week = Period(lastDays(7), usage);
    final values = [for (final e in week.entries) (_data ? e.bytes : e.seconds).toDouble()];

    return MerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(t.stats.thisWeek, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: m.text)),
              ),
              MiniSegment(
                labels: [t.stats.time, t.stats.data],
                index: _data ? 1 : 0,
                onChanged: (i) => setState(() => _data = i == 1),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _data ? formatBytes(week.bytes) : formatDuration(week.seconds),
                style: m.monoStyle(size: 28, color: m.text),
              ),
              const SizedBox(width: 8),
              Text(_data ? t.stats.throughVpn : t.stats.protected, style: TextStyle(fontSize: 13, color: m.muted)),
            ],
          ),
          const SizedBox(height: 14),
          UsageBars(values: values, labels: _weekdayLabels(context, week.days)),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: MerAction(
              t.stats.seeDetails,
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const StatsScreen())),
            ),
          ),
        ],
      ),
    );
  }
}

/// Week or Month, time or data, and which servers it went through.
class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  bool _month = false;
  bool _data = false;

  Future<void> _reset() async {
    final m = context.mer;
    final sure = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: m.surface,
        title: Text(t.stats.resetTitle),
        content: Text(t.stats.resetBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t.common.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            style: TextButton.styleFrom(foregroundColor: m.bad),
            child: Text(t.stats.reset),
          ),
        ],
      ),
    );
    if (sure == true) await ref.read(usageProvider.notifier).reset();
  }

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final usage = ref.watch(usageProvider).value ?? const <String, UsageDay>{};
    final period = Period(lastDays(_month ? 30 : 7), usage);
    final values = [for (final e in period.entries) (_data ? e.bytes : e.seconds).toDouble()];
    final labels = _month
        ? [for (final (i, d) in period.days.indexed) i % 7 == 0 || i == period.days.length - 1 ? '${d.day}' : '']
        : _weekdayLabels(context, period.days);
    final servers = period.servers(byData: _data).take(5).toList();

    Widget total({required bool data}) {
      final selected = data == _data;
      return Expanded(
        child: Material(
          color: m.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Meridian.rTile),
            side: BorderSide(color: selected ? m.brand : m.line, width: selected ? 1.5 : 1),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(Meridian.rTile),
            onTap: () => setState(() => _data = data),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data ? t.stats.dataUsed : t.stats.protectedLabel,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .6, color: m.muted),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    data ? formatBytes(period.bytes) : formatDuration(period.seconds),
                    style: m.monoStyle(size: 22, color: m.text),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: m.bg,
      appBar: AppBar(
        title: Text(t.stats.title),
        actions: [
          IconButton(
            tooltip: t.report.title,
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ReportScreen())),
            icon: Icon(Icons.insert_chart_outlined_rounded, color: m.text),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: MiniSegment(
                labels: [t.stats.week, t.stats.month],
                index: _month ? 1 : 0,
                onChanged: (i) => setState(() => _month = i == 1),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(children: [total(data: false), const SizedBox(width: 10), total(data: true)]),
          const SizedBox(height: 12),
          MerCard(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
            child: UsageBars(values: values, labels: labels, height: 170, gap: _month ? 3 : 10),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              t.stats.byServer,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: .8, color: m.muted),
            ),
          ),
          const SizedBox(height: 8),
          MerCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: servers.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(t.stats.empty, style: TextStyle(fontSize: 14, color: m.muted)),
                  )
                : Column(
                    children: [
                      for (final s in servers)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          child: Row(
                            children: [
                              if (s.country != null) ...[CountryFlag(s.country!, width: 26), const SizedBox(width: 12)],
                              Expanded(
                                child: Text(s.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: m.text)),
                              ),
                              Text(
                                _data ? formatBytes(s.bytes) : formatDuration(s.seconds),
                                style: m.monoStyle(size: 13, color: m.muted),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Icon(Icons.smartphone_rounded, size: 16, color: m.muted),
              const SizedBox(width: 8),
              Expanded(child: Text(t.stats.onPhone, style: TextStyle(fontSize: 13, color: m.muted))),
              TextButton(
                onPressed: _reset,
                style: TextButton.styleFrom(foregroundColor: m.bad, minimumSize: const Size(48, 44)),
                child: Text(t.stats.reset),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
