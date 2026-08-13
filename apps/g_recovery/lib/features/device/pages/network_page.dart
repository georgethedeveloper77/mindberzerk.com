import 'package:device_probe/device_probe.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../bridge/hardware_api.g.dart';
import '../../../bridge/hardware_bridge.dart';
import '../../../core/format.dart';
import '../../../ui/g_detail_page.dart';
import '../../../ui/g_stat.dart';
import '../device_format.dart';
import '../state/device_providers.dart';

/// WHAT THE RADIO IS DOING.
///
/// ─── THE ONLY LIVE THING ON THE PAGE IS THE CHART ────────────────────────────
///
/// Everything else here is a fact that changes when you join a different
/// network. The throughput line is the reason to open it, so it sits at the top
/// and it is the one element that moves.
class NetworkPage extends ConsumerWidget {
  const NetworkPage({required this.hue, super.key});

  final Color hue;

  static Route<void> route({required Color hue}) => MaterialPageRoute<void>(
    builder: (BuildContext context) => NetworkPage(hue: hue),
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

    final ProbeTick? tick = ref.watch(deviceTickProvider).value;
    final String? sinceBoot = DeviceFormat.uptime(
      tick?.current.elapsedRealtimeMillis,
    );

    return GDetailPage(
      hue: hue,
      icon: Icons.wifi_rounded,
      title: 'Network',
      subtitle: _caption(net, wifi),
      children: <Widget>[
        GChartCard(
          header: Row(
            children: <Widget>[
              _Rate(value: now?.rxBytesPerSecond ?? 0, label: 'down', hue: hue),
              const SizedBox(width: GSpace.lg),
              _Rate(
                value: now?.txBytesPerSecond ?? 0,
                label: 'up',
                hue: t.photo,
              ),
            ],
          ),
          axis: history.length < 2
              ? const <String>[]
              : const <String>['60s ago', 'now'],
          child: SizedBox(
            height: 110,
            child: history.length < 2
                ? Center(
                    child: Text(
                      'Measuring',
                      style: GType.monoSmall.copyWith(color: t.dim),
                    ),
                  )
                : LineChart(
                    _throughput(history, t, hue),
                    // The line grows into place on first paint and eases
                    // between every reading after it, which is what makes a
                    // once a second poll read as a live trace rather than a
                    // chart that jumps.
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                  ),
          ),
        ),

        if (now != null && now.rxBytesTotal + now.txBytesTotal > 0) ...<Widget>[
          const SizedBox(height: GSpace.lg),
          const GOverline('This session'),
          const SizedBox(height: GSpace.sm + 1),
          GSpecCard(
            rows: <(String, String?)>[
              ('Received', GFormat.bytes(now.rxBytesTotal)),
              ('Sent', GFormat.bytes(now.txBytesTotal)),
              ('Since', sinceBoot == null ? null : 'boot, $sinceBoot'),
            ],
          ),
        ],

        if (wifi != null && wifi.connected) ...<Widget>[
          const SizedBox(height: GSpace.lg),
          const GOverline('Link'),
          const SizedBox(height: GSpace.sm + 1),
          GSpecCard(
            rows: <(String, String?)>[
              ('Network', wifi.ssid),
              ('Standard', wifi.standard),
              ('Security', wifi.security),
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
                wifi.frequencyMhz == null ? null : '${wifi.frequencyMhz} MHz',
              ),
              (
                'Signal',
                wifi.signalPercent == null ? null : '${wifi.signalPercent}%',
              ),
              ('MAC address', wifi.macAddress),
            ],
          ),

          // ONE line, only when a permission is actually the reason.
          //
          // Not a general disclaimer: hasLocationPermission distinguishes
          // "Android will not tell us" from "the radio is off", which look
          // identical from a null.
          if (!wifi.hasLocationPermission) ...<Widget>[
            const SizedBox(height: GSpace.sm + 1),
            GMissNote(
              text: 'Network name and MAC need location access',
              onTap: () async {
                await ref.read(hardwareBridgeProvider).requestLocation();
                ref.invalidate(wifiProvider);
              },
            ),
          ],
        ],

        if (net != null) ...<Widget>[
          const SizedBox(height: GSpace.lg),
          const GOverline('Connection'),
          const SizedBox(height: GSpace.sm + 1),
          GSpecCard(
            rows: <(String, String?)>[
              ('Type', _typeName(net.type)),
              ('Internet', net.connected ? 'Reachable' : 'No'),
              ('Metered', net.metered ? 'Yes' : 'No'),
              ('Local IP', net.ipv4),
              ('IPv6', net.ipv6),
            ],
          ),
        ],

        if (wifi != null) ...<Widget>[
          const SizedBox(height: GSpace.lg),
          const GOverline('Bands'),
          const SizedBox(height: GSpace.sm + 1),
          GFlagCard(
            flags: <(String, bool)>[
              ('5 GHz', wifi.supports5Ghz),
              ('6 GHz', wifi.supports6Ghz),
            ],
          ),
        ],
      ],
    );
  }

  /// Type, and the Wi-Fi standard where there is one. Two facts on the line
  /// that a person checks to be sure they are looking at the right radio.
  static String? _caption(NetworkInfo? net, WifiInfo? wifi) {
    if (net == null) return null;
    final String type = _typeName(net.type);
    final String? standard = (wifi != null && wifi.connected)
        ? wifi.standard
        : null;
    return standard == null ? type : '$type  ·  $standard';
  }

  static String _typeName(String type) => switch (type) {
    'wifi' => 'Wi-Fi',
    'cellular' => 'Mobile data',
    'ethernet' => 'Ethernet',
    'vpn' => 'VPN',
    _ => 'Not connected',
  };

  /// Down and up, one minute, on one axis.
  ///
  /// ─── TWO SERIES ON ONE AXIS, NOT TWO CHARTS ────────────────────────────────
  ///
  /// The interesting thing about upload is its size RELATIVE to download, and
  /// two separately scaled charts hide exactly that: a 2 kB/s upload drawn full
  /// height beside a 3 MB/s download says the opposite of the truth.
  LineChartData _throughput(
    List<ThroughputSample> history,
    GTokens t,
    Color down,
  ) {
    final List<FlSpot> rx = <FlSpot>[
      for (int i = 0; i < history.length; i++)
        FlSpot(i.toDouble(), history[i].rxBytesPerSecond / 1024),
    ];
    final List<FlSpot> tx = <FlSpot>[
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

    LineChartBarData bar(List<FlSpot> spots, Color colour, {required bool fill}) =>
        LineChartBarData(
          spots: spots,
          isCurved: true,
          curveSmoothness: 0.24,
          color: colour,
          barWidth: 2,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: fill,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                colour.withValues(alpha: 0.32),
                colour.withValues(alpha: 0),
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
        bar(rx, down, fill: true),
        bar(tx, t.photo, fill: false),
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
