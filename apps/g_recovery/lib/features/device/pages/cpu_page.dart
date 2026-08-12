import 'package:device_probe/device_probe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../ui/g_badge.dart';
import '../../../ui/g_stat.dart';
import '../device_format.dart';
import '../state/device_history.dart';
import '../state/device_providers.dart';
import '../widgets/g_line_chart.dart';
import '../widgets/unavailable_note.dart';
import 'device_chrome.dart';

/// THE PROCESSOR.
///
/// ─── WAS A CARD HOSTED IN A GENERIC PAGE ─────────────────────────────────────
///
/// Every reading on it was real and every one of them was crammed into a single
/// panel, because a card has to be self contained and a page does not. Split
/// into sections, the same data reads as four answers instead of one dense
/// block: how hard is it working, what is each core doing, what is the silicon,
/// and what will this kernel not tell us.
class CpuPage extends ConsumerWidget {
  const CpuPage({required this.hue, super.key});

  final Color hue;

  static Route<void> route({required Color hue}) => MaterialPageRoute<void>(
    builder: (BuildContext context) => CpuPage(hue: hue),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;
    final ProbeCapabilities? caps = ref.watch(deviceCapabilitiesProvider).value;
    final CpuInfo? info = ref.watch(cpuInfoProvider).value;
    final ProbeTick? tick = ref.watch(deviceTickProvider).value;

    final List<VitalSample> history = ref.watch(vitalHistoryProvider);
    final List<double> busySeries = vitalSeries(
      history,
      (VitalSample s) => s.busy == null ? null : s.busy! * 100,
    );
    final double? busy = tick == null ? null : CpuLoad.busyFraction(tick);

    return DeviceDetailPage(
      hue: hue,
      icon: Icons.memory_rounded,
      title: info?.socModel ?? info?.hardware ?? 'Processor',
      subtitle: info == null ? null : _subtitle(info),
      trailing: (caps?.coreFrequencies ?? false)
          ? const GBadge.live('2 Hz')
          : null,
      children: <Widget>[
        if (info == null)
          const PendingNote(title: 'Reading CPU topology')
        else ...<Widget>[
          if (caps?.cpuJiffies ?? false)
            GChartCard(
              caption: 'Load, last minute',
              axis: <String>[
                '0%',
                if (busy != null) '${(busy * 100).round()}% now',
                '100%',
              ],
              child: GLineChart(
                values: busySeries,
                colour: hue,
                height: 88,
                // Fixed to the full scale. A percentage that rescales to its
                // own range makes a quiet phone look as busy as a hot one.
                minY: 0,
                maxY: 100,
              ),
            )
          else
            const UnavailableNote(
              title: 'System load',
              reason:
                  'Android stopped letting apps read system wide CPU time on '
                  'this device. Any app showing a live CPU percentage here is '
                  'showing its own process or a number it invented. The per '
                  'core frequencies below are real.',
            ),

          const SizedBox(height: GSpace.lg),
          const GOverline('Cores'),
          const SizedBox(height: GSpace.sm + 1),
          _Cores(info: info, tick: tick, readable: caps?.coreFrequencies),

          if (info.clusters.isNotEmpty) ...<Widget>[
            const SizedBox(height: GSpace.lg),
            const GOverline('Clusters'),
            const SizedBox(height: GSpace.sm + 1),
            GSpecCard(
              rows: <(String, String?)>[
                for (final CpuCluster cluster in info.clusters)
                  (_clusterName(cluster), _range(cluster)),
                ('Governor', _governor(info)),
              ],
            ),
            if (!(caps?.cpuClusters ?? true)) ...<Widget>[
              const SizedBox(height: GSpace.sm),
              Text(
                // The distinction matters to anyone comparing against a spec
                // sheet, and pretending to certainty we do not have is the
                // thing this app is built not to do.
                'Clusters inferred from maximum frequencies. This kernel does '
                'not publish its frequency domains.',
                style: GType.micro.copyWith(color: t.dim),
              ),
            ],
          ],

          const SizedBox(height: GSpace.lg),
          const GOverline('Chip'),
          const SizedBox(height: GSpace.sm + 1),
          GSpecCard(
            rows: <(String, String?)>[
              ('Model', info.socModel),
              ('Hardware', info.hardware),
              ('Architecture', info.abi),
              ('Cores', '${info.coreCount}'),
              (
                'Clusters',
                info.clusters.isEmpty ? null : '${info.clusters.length}',
              ),
            ],
          ),
        ],
      ],
    );
  }

  static String _subtitle(CpuInfo info) {
    final List<String> parts = <String>[
      '${info.coreCount} cores',
      if (info.clusters.length > 1) '${info.clusters.length} clusters',
      if (info.abi != null) info.abi!,
    ];
    return parts.join('  ·  ');
  }

  /// "Prime, 1 core" rather than "Prime". The count is what makes a cluster
  /// name mean something to a person who has not read a die shot.
  static String _clusterName(CpuCluster cluster) {
    final int count = cluster.coreIds.length;
    return '${cluster.label}, $count ${count == 1 ? 'core' : 'cores'}';
  }

  /// The frequency window, or just the ceiling where no floor was published.
  static String? _range(CpuCluster cluster) {
    final String? low = DeviceFormat.frequency(cluster.minKhz);
    final String? high = DeviceFormat.frequency(cluster.maxKhz);
    if (low != null && high != null) return '$low to $high';
    if (high != null) return 'up to $high';
    return null;
  }

  /// The first cluster that named one. Kernels that run different governors per
  /// domain exist and are rare enough that a single row is the honest summary;
  /// the alternative is four identical rows on every normal phone.
  static String? _governor(CpuInfo info) {
    for (final CpuCluster cluster in info.clusters) {
      if (cluster.governor != null) return cluster.governor;
    }
    return null;
  }
}

/// One bar per core, in core order.
///
/// ─── ORDERED BY CORE NUMBER, COLOURED BY CLUSTER ─────────────────────────────
///
/// [CpuInfo.clusters] arrives fastest first, which is the right order for a
/// list of clusters and the wrong order for a list of cores: nobody looking at
/// core 7 expects to find it at the top. The rows run 0 upward and the colour
/// carries the grouping instead.
class _Cores extends StatelessWidget {
  const _Cores({required this.info, required this.tick, required this.readable});

  final CpuInfo info;
  final ProbeTick? tick;
  final bool? readable;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    final List<int?>? coreKhz = tick?.current.cpu?.coreKhz;
    final List<bool?>? coreOnline = tick?.current.cpu?.coreOnline;

    if (readable == false) {
      return const UnavailableNote(
        title: 'Per core frequency',
        reason:
            'This ROM does not let apps read the current frequency of each '
            'core. The policy is set per build by the manufacturer, which is '
            'why the same Android version answers on one phone and refuses on '
            'another. Nothing the app can do changes it.',
      );
    }
    if (coreKhz == null) {
      return const PendingNote(title: 'Sampling cores');
    }

    // Cluster index per core, so a bar can be coloured by the domain it belongs
    // to without searching the cluster list once per row.
    final Map<int, int> clusterOf = <int, int>{};
    for (int c = 0; c < info.clusters.length; c++) {
      for (final int id in info.clusters[c].coreIds) {
        clusterOf[id] = c;
      }
    }

    // The ceiling each bar is a fraction of. Per cluster where the kernel
    // published one, and the fastest reading seen otherwise, because a bar with
    // no ceiling has no length.
    int fallbackMax = 0;
    for (final int? khz in coreKhz) {
      if (khz != null && khz > fallbackMax) fallbackMax = khz;
    }

    final List<GCoreBar> bars = <GCoreBar>[];
    for (int core = 0; core < coreKhz.length; core++) {
      final int? khz = coreKhz[core];
      final bool online = (coreOnline != null && core < coreOnline.length)
          ? coreOnline[core] ?? true
          : true;
      final int? cluster = clusterOf[core];
      final int? ceiling = cluster == null
          ? null
          : info.clusters[cluster].maxKhz;

      bars.add(
        GCoreBar(
          label: '$core',
          colour: online
              ? _clusterHue(t, cluster ?? 0)
              : t.dim,
          fraction: online
              ? DeviceFormat.frequencyFraction(
                  khz,
                  ceiling ?? (fallbackMax > 0 ? fallbackMax : null),
                )
              : null,
          value: online ? DeviceFormat.frequency(khz) : 'offline',
        ),
      );
    }

    if (bars.isEmpty) return const SizedBox.shrink();

    return GChartCard(child: GCoreBars(cores: bars));
  }

  /// Loudest for the fastest cluster, which is index 0.
  ///
  /// Category hues rather than a gradient, because the point is that these
  /// cores are different silicon, not that they are ranked.
  static Color _clusterHue(GTokens t, int index) {
    final List<Color> palette = <Color>[
      t.audio,
      t.video,
      t.photo,
      t.docs,
      t.chat,
      t.apps,
    ];
    return palette[index % palette.length];
  }
}
