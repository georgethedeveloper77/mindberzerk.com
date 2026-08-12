import 'package:device_probe/device_probe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../ui/g_badge.dart';
import '../../../ui/g_bar.dart';
import '../../../ui/g_card.dart';
import '../device_format.dart';
import '../state/device_providers.dart';
import 'unavailable_note.dart';

class CpuCard extends ConsumerWidget {
  const CpuCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;
    final ProbeCapabilities? caps = ref.watch(deviceCapabilitiesProvider).value;
    final CpuInfo? info = ref.watch(cpuInfoProvider).value;
    final ProbeTick? tick = ref.watch(deviceTickProvider).value;

    if (info == null) {
      return PendingNote(title: 'Reading CPU topology');
    }

    final double? busy = tick == null ? null : CpuLoad.busyFraction(tick);

    return Column(
      children: <Widget>[
        GCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          info.socModel ?? info.hardware ?? 'Processor',
                          style: GType.heading.copyWith(color: t.text),
                        ),
                        Text(
                          _subtitle(info),
                          style: GType.monoSmall.copyWith(color: t.muted),
                        ),
                      ],
                    ),
                  ),
                  if (caps?.coreFrequencies ?? false)
                    GBadge.live('2 Hz')
                  else
                    GBadge(label: 'Static'),
                ],
              ),
              const GCardDivider(),
              for (final CpuCluster cluster in info.clusters)
                _ClusterRows(cluster: cluster, tick: tick),
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
          ),
        ),
        const SizedBox(height: GSpace.md - 2),
        if (caps?.cpuJiffies ?? false)
          GCard(
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'System load',
                    style: GType.heading.copyWith(color: t.text),
                  ),
                ),
                Text(
                  busy == null
                      ? 'Sampling'
                      : '${(busy * 100).toStringAsFixed(0)}%',
                  style: GType.monoNumber.copyWith(
                    color: busy == null ? t.dim : t.video,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          )
        else
          UnavailableNote(
            title: 'System load',
            reason:
                'Android stopped letting apps read system wide CPU time on this '
                'device. Any app showing a live CPU percentage here is showing '
                'its own process or a number it invented. The per core '
                'frequencies above are real.',
          ),
      ],
    );
  }

  String _subtitle(CpuInfo info) {
    final List<String> parts = <String>[
      '${info.coreCount} cores',
      if (info.clusters.length > 1) '${info.clusters.length} clusters',
      if (info.abi != null) info.abi!,
      if (info.clusters.isNotEmpty && info.clusters.first.governor != null)
        info.clusters.first.governor!,
    ];
    return parts.join(' / ');
  }
}

class _ClusterRows extends StatelessWidget {
  const _ClusterRows({required this.cluster, this.tick});

  final CpuCluster cluster;
  final ProbeTick? tick;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    final List<int?>? coreKhz = tick?.current.cpu?.coreKhz;
    final List<bool?>? coreOnline = tick?.current.cpu?.coreOnline;

    // A single core cluster gets one row named for the cluster. A multi core
    // one gets a row per core, numbered within the cluster rather than by
    // global index, because "Gold 1" is how the silicon is discussed and
    // "cpu5" is not.
    final bool single = cluster.coreIds.length == 1;

    return Column(
      children: <Widget>[
        for (int i = 0; i < cluster.coreIds.length; i++)
          Builder(
            builder: (BuildContext _) {
              final int core = cluster.coreIds[i];
              final int? khz = (coreKhz != null && core < coreKhz.length)
                  ? coreKhz[core]
                  : null;
              final bool online =
                  (coreOnline != null && core < coreOnline.length)
                  ? coreOnline[core] ?? true
                  : true;
              return GMeterRow(
                label: single ? cluster.label : '${cluster.label} ${i + 1}',
                value: online ? DeviceFormat.frequency(khz) : 'offline',
                fraction: online
                    ? DeviceFormat.frequencyFraction(khz, cluster.maxKhz)
                    : null,
                colour: _tone(t, khz, cluster.maxKhz),
                labelWidth: 52,
              );
            },
          ),
      ],
    );
  }

  /// Colour by how hard the core is working, not by cluster. A silver core at
  /// its ceiling is working as hard as a prime core at its ceiling.
  Color _tone(GTokens t, int? khz, int? maxKhz) {
    final double? fraction = DeviceFormat.frequencyFraction(khz, maxKhz);
    if (fraction == null) return t.dim;
    if (fraction > 0.8) return t.danger;
    if (fraction > 0.45) return t.warning;
    return t.video;
  }
}
