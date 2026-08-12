import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../bridge/hardware_api.g.dart';
import '../../../bridge/hardware_bridge.dart';
import '../../../core/format.dart';
import '../../../ui/g_app_bar.dart';
import '../../../ui/g_card.dart';
import 'spec_rows.dart';

/// WHAT THE RADIO IS DOING.
///
/// ─── THE ONLY LIVE THING ON THE PAGE IS THE CHART ────────────────────────────
///
/// Everything else here is a fact that changes when you join a different
/// network. The throughput line is the reason to open it, so it sits at the top
/// and it is the one element that moves.
class NetworkPage extends ConsumerWidget {
  const NetworkPage({super.key});

  static Route<void> route() => MaterialPageRoute<void>(
    builder: (BuildContext context) => const NetworkPage(),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;
    final NetworkInfo? net = ref.watch(networkProvider).value;
    final WifiInfo? wifi = ref.watch(wifiProvider).value;

    // Subscribed here so the poll runs while this page lives and stops with it.
    ref.watch(throughputProvider);
    final List<ThroughputSample> history = ref.watch(throughputHistoryProvider);
    final ThroughputSample? now = history.isEmpty ? null : history.last;

    return Scaffold(
      backgroundColor: t.ink,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            GSpace.gutter,
            0,
            GSpace.gutter,
            GSpace.xl,
          ),
          children: <Widget>[
            GAppBar(
              title: 'Network',
              subtitle: net == null ? null : _typeName(net.type),
              leading: GIconButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => Navigator.of(context).pop(),
              ),
            ),

            _Throughput(history: history, now: now),

            if (now != null) ...<Widget>[
              const SizedBox(height: GSpace.md - 1),
              _SessionSplit(sample: now),
            ],

            if (wifi != null && wifi.connected) ...<Widget>[
              const SizedBox(height: GSpace.lg),
              Text('LINK', style: GType.overline.copyWith(color: t.dim)),
              const SizedBox(height: GSpace.sm + 1),
              GCard(
                child: SpecRows(
                  rows: <(String, String?)>[
                    ('Network', wifi.ssid),
                    ('Standard', wifi.standard),
                    (
                      'Link speed',
                      wifi.linkSpeedMbps == null
                          ? null
                          : '${wifi.linkSpeedMbps} Mbps',
                    ),
                    (
                      'Receiving at',
                      wifi.rxLinkSpeedMbps == null
                          ? null
                          : '${wifi.rxLinkSpeedMbps} Mbps',
                    ),
                    (
                      'Frequency',
                      wifi.frequencyMhz == null
                          ? null
                          : '${wifi.frequencyMhz} MHz',
                    ),
                    (
                      'Signal',
                      wifi.signalPercent == null
                          ? null
                          : '${wifi.signalPercent}%',
                    ),
                    ('MAC address', wifi.macAddress),
                  ],
                ),
              ),

              // ONE line, only when a permission is actually the reason.
              //
              // Not a general disclaimer: hasLocationPermission distinguishes
              // "Android will not tell us" from "the radio is off", which look
              // identical from a null.
              if (!wifi.hasLocationPermission) ...<Widget>[
                const SizedBox(height: GSpace.sm + 1),
                GCard(
                  onTap: () async {
                    await ref.read(hardwareBridgeProvider).requestLocation();
                    ref.invalidate(wifiProvider);
                  },
                  child: Row(
                    children: <Widget>[
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 18,
                        color: t.audio,
                      ),
                      const SizedBox(width: GSpace.md),
                      Expanded(
                        child: Text(
                          'Network name and MAC need location access',
                          style: GType.bodySmall.copyWith(color: t.muted),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, size: 18, color: t.dim),
                    ],
                  ),
                ),
              ],
            ],

            if (net != null) ...<Widget>[
              const SizedBox(height: GSpace.lg),
              Text('CONNECTION', style: GType.overline.copyWith(color: t.dim)),
              const SizedBox(height: GSpace.sm + 1),
              GCard(
                child: SpecRows(
                  rows: <(String, String?)>[
                    ('Type', _typeName(net.type)),
                    ('Internet', net.connected ? 'Reachable' : 'No'),
                    ('Metered', net.metered ? 'Yes' : 'No'),
                    ('Local IP', net.ipv4),
                    ('IPv6', net.ipv6),
                  ],
                ),
              ),
            ],

            if (wifi != null) ...<Widget>[
              const SizedBox(height: GSpace.lg),
              Text('BANDS', style: GType.overline.copyWith(color: t.dim)),
              const SizedBox(height: GSpace.sm + 1),
              GCard(
                child: SpecRows(
                  rows: <(String, String?)>[
                    ('5 GHz', wifi.supports5Ghz ? 'Supported' : 'No'),
                    ('6 GHz', wifi.supports6Ghz ? 'Supported' : 'No'),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _typeName(String type) => switch (type) {
    'wifi' => 'Wi-Fi',
    'cellular' => 'Mobile data',
    'ethernet' => 'Ethernet',
    'vpn' => 'VPN',
    _ => 'Not connected',
  };
}

/// Down and up, one minute, filled.
///
/// ─── TWO SERIES ON ONE AXIS, NOT TWO CHARTS ──────────────────────────────────
///
/// The interesting thing about upload is its size RELATIVE to download, and two
/// separately scaled charts hide exactly that: a 2 kB/s upload drawn full height
/// beside a 3 MB/s download says the opposite of the truth.
class _Throughput extends StatelessWidget {
  const _Throughput({required this.history, required this.now});

  final List<ThroughputSample> history;
  final ThroughputSample? now;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    return GCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              _Rate(
                value: now?.rxBytesPerSecond ?? 0,
                label: 'down',
                hue: t.accent,
              ),
              const SizedBox(width: GSpace.lg),
              _Rate(
                value: now?.txBytesPerSecond ?? 0,
                label: 'up',
                hue: t.photo,
              ),
            ],
          ),
          const SizedBox(height: GSpace.md),
          SizedBox(
            height: 116,
            child: history.length < 2
                ? Center(
                    child: Text(
                      'Measuring',
                      style: GType.monoSmall.copyWith(color: t.dim),
                    ),
                  )
                : LineChart(
                    _data(t),
                    // The line grows into place on first paint and eases
                    // between every reading after it, which is what makes a
                    // once a second poll read as a live trace rather than a
                    // chart that jumps.
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                  ),
          ),
        ],
      ),
    );
  }

  LineChartData _data(GTokens t) {
    final List<FlSpot> down = <FlSpot>[
      for (int i = 0; i < history.length; i++)
        FlSpot(i.toDouble(), history[i].rxBytesPerSecond / 1024),
    ];
    final List<FlSpot> up = <FlSpot>[
      for (int i = 0; i < history.length; i++)
        FlSpot(i.toDouble(), history[i].txBytesPerSecond / 1024),
    ];

    // A floor on the axis, so an idle radio draws a flat line near the bottom
    // rather than noise magnified to full height.
    double peak = 1;
    for (final ThroughputSample s in history) {
      final double kb =
          (s.rxBytesPerSecond > s.txBytesPerSecond
              ? s.rxBytesPerSecond
              : s.txBytesPerSecond) /
          1024;
      if (kb > peak) peak = kb;
    }

    LineChartBarData bar(List<FlSpot> spots, Color hue, bool fill) =>
        LineChartBarData(
          spots: spots,
          isCurved: true,
          curveSmoothness: 0.24,
          color: hue,
          barWidth: 2,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: fill,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                hue.withValues(alpha: 0.32),
                hue.withValues(alpha: 0),
              ],
            ),
          ),
        );

    return LineChartData(
      minY: 0,
      maxY: peak * 1.15,
      minX: 0,
      maxX: (history.length - 1).toDouble(),
      gridData: const FlGridData(show: false),
      titlesData: const FlTitlesData(show: false),
      borderData: FlBorderData(show: false),
      lineTouchData: const LineTouchData(enabled: false),
      lineBarsData: <LineChartBarData>[
        bar(down, t.accent, true),
        bar(up, t.photo, false),
      ],
    );
  }
}

/// Total received against total sent, since boot.
///
/// A pie rather than two numbers, because the ratio is the point: a phone that
/// has uploaded almost as much as it downloaded is doing something worth
/// noticing, and two figures in a row make that comparison work for the reader.
class _SessionSplit extends StatelessWidget {
  const _SessionSplit({required this.sample});

  final ThroughputSample sample;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    final int total = sample.rxBytesTotal + sample.txBytesTotal;
    if (total <= 0) return const SizedBox.shrink();

    return GCard(
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 92,
            height: 92,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 26,
                startDegreeOffset: -90,
                sections: <PieChartSectionData>[
                  PieChartSectionData(
                    value: sample.rxBytesTotal.toDouble(),
                    color: t.accent,
                    radius: 18,
                    showTitle: false,
                  ),
                  PieChartSectionData(
                    value: sample.txBytesTotal.toDouble(),
                    color: t.photo,
                    radius: 18,
                    showTitle: false,
                  ),
                ],
              ),
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutCubic,
            ),
          ),
          const SizedBox(width: GSpace.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _Key(
                  hue: t.accent,
                  label: 'Received',
                  value: GFormat.bytes(sample.rxBytesTotal),
                ),
                const SizedBox(height: GSpace.sm),
                _Key(
                  hue: t.photo,
                  label: 'Sent',
                  value: GFormat.bytes(sample.txBytesTotal),
                ),
                const SizedBox(height: GSpace.sm),
                Text(
                  'since this phone last started',
                  style: GType.micro.copyWith(color: t.dim),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.hue, required this.label, required this.value});

  final Color hue;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    return Row(
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: hue, shape: BoxShape.circle),
        ),
        const SizedBox(width: GSpace.sm),
        Expanded(
          child: Text(label, style: GType.bodySmall.copyWith(color: t.muted)),
        ),
        Text(
          value,
          style: GType.monoNumber.copyWith(color: t.text, fontSize: 13),
        ),
      ],
    );
  }
}

class _Rate extends StatelessWidget {
  const _Rate({required this.value, required this.label, required this.hue});

  final int value;
  final String label;
  final Color hue;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '${GFormat.bytes(value)}/s',
          style: GType.monoNumber.copyWith(color: hue, fontSize: 17),
        ),
        Text(label, style: GType.micro.copyWith(color: t.muted)),
      ],
    );
  }
}
