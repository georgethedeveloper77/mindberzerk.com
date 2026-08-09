import 'package:device_probe/device_probe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../ui/g_badge.dart';
import '../../../ui/g_card.dart';
import '../state/device_providers.dart';
import 'unavailable_note.dart';

class SensorsCard extends ConsumerWidget {
  const SensorsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;
    final AsyncValue<List<SensorInfo>> async = ref.watch(sensorListProvider);

    if (!async.hasValue) {
      return PendingNote(title: 'Enumerating sensors');
    }
    final List<SensorInfo> sensors = async.value ?? const <SensorInfo>[];
    if (sensors.isEmpty) {
      return UnavailableNote(
        title: 'Sensors',
        reason: 'This device reported no sensors at all, which normally means '
            'an emulator rather than a limitation.',
      );
    }

    const List<String> order = <String>[
      'motion',
      'position',
      'environment',
      'body',
      'other',
    ];
    final Map<String, List<SensorInfo>> grouped = <String, List<SensorInfo>>{};
    for (final SensorInfo sensor in sensors) {
      grouped.putIfAbsent(sensor.category, () => <SensorInfo>[]).add(sensor);
    }

    return Column(
      children: <Widget>[
        GCard(
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${sensors.length} sensors',
                  style: GType.heading.copyWith(color: t.text),
                ),
              ),
              GBadge(label: 'Live values in Phase 3'),
            ],
          ),
        ),
        for (final String category in order)
          if (grouped[category] != null) ...<Widget>[
            const SizedBox(height: GSpace.md - 2),
            _CategoryCard(category: category, sensors: grouped[category]!),
          ],
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category, required this.sensors});

  final String category;
  final List<SensorInfo> sensors;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    return GCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _title(category),
            style: GType.overline.copyWith(color: _tone(t, category)),
          ),
          const SizedBox(height: GSpace.sm + 2),
          for (int i = 0; i < sensors.length; i++) ...<Widget>[
            if (i > 0) const GCardDivider(),
            _SensorRow(sensor: sensors[i]),
          ],
        ],
      ),
    );
  }

  String _title(String category) {
    switch (category) {
      case 'motion':
        return 'MOTION';
      case 'position':
        return 'POSITION';
      case 'environment':
        return 'ENVIRONMENT';
      case 'body':
        return 'BODY';
      default:
        return 'OTHER';
    }
  }

  Color _tone(GTokens t, String category) {
    switch (category) {
      case 'motion':
        return t.video;
      case 'position':
        return t.photo;
      case 'environment':
        return t.docs;
      case 'body':
        return t.apps;
      default:
        return t.dim;
    }
  }
}

class _SensorRow extends StatelessWidget {
  const _SensorRow({required this.sensor});

  final SensorInfo sensor;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    final List<String> facts = <String>[
      if (sensor.vendor != null) sensor.vendor!,
      if (sensor.powerMilliAmp != null)
        '${sensor.powerMilliAmp!.toStringAsFixed(2)} mA',
      if (sensor.maxRange != null)
        'range ${sensor.maxRange!.toStringAsFixed(1)}',
      if (sensor.minDelayMicros != null)
        'up to ${(1000000 / sensor.minDelayMicros!).round()} Hz',
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  sensor.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GType.body.copyWith(
                    color: sensor.readable ? t.text : t.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (facts.isNotEmpty)
                  Text(
                    facts.join(' / '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GType.monoSmall.copyWith(color: t.dim),
                  ),
              ],
            ),
          ),
          const SizedBox(width: GSpace.sm),
          // Present but blocked is shown rather than filtered. Someone hunting
          // for their heart rate sensor needs to see that it exists and that
          // the system is refusing, not an unexplained absence.
          if (!sensor.readable)
            GBadge(label: 'Blocked')
          else if (sensor.wakeUp)
            GBadge.partial('Wake'),
        ],
      ),
    );
  }
}
