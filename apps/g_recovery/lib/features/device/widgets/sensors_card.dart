import 'package:device_probe/device_probe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../bridge/hardware_api.g.dart';
import '../../../bridge/hardware_bridge.dart';
import '../../../ui/g_badge.dart';
import '../../../ui/g_card.dart';
import '../state/device_providers.dart';
import 'unavailable_note.dart';
import '../../../core/i18n/g_strings.dart';

class SensorsCard extends ConsumerWidget {
  const SensorsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;
    final AsyncValue<List<SensorInfo>> async = ref.watch(sensorListProvider);

    if (!async.hasValue) {
      return PendingNote(title: context.s('Enumerating sensors'));
    }
    final List<SensorInfo> sensors = async.value ?? const <SensorInfo>[];
    if (sensors.isEmpty) {
      return UnavailableNote(
        title: context.s('Sensors'),
        reason:
            'This device reported no sensors at all, which normally means '
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
        // LIVE, not a badge promising live.
        //
        // The card said "Live values in Phase 3", which was a placeholder that
        // outlived the phase. The readings are real now, and the ones that mean
        // something without context sit at the top where the promise was.
        const _LiveSensors(),
        const SizedBox(height: GSpace.md - 2),
        GCard(
          child: Text(
            '${sensors.length} sensors on this phone',
            style: GType.heading.copyWith(color: t.text),
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
            GBadge(label: context.s('Blocked'))
          else if (sensor.wakeUp)
            GBadge.partial('Wake'),
        ],
      ),
    );
  }
}

/// The sensors a person can make move.
///
/// ─── ONLY THE ONES THAT MEAN SOMETHING UNAIDED ───────────────────────────────
///
/// A phone reports thirty one sensors and most are fused virtual ones whose
/// numbers are meaningless without a frame of reference. These read as a test:
/// tilt the phone and the bars move, cover the top and the light drops.
class _LiveSensors extends ConsumerWidget {
  const _LiveSensors();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;
    final List<SensorReading> live =
        ref.watch(sensorValuesProvider).value ?? const <SensorReading>[];

    if (live.isEmpty) {
      return GCard(
        child: Text(
          context.s('Waiting for a reading'),
          style: GType.monoSmall.copyWith(color: t.dim),
        ),
      );
    }

    return Column(
      children: <Widget>[
        for (int i = 0; i < live.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: GSpace.sm),
          _LiveRow(reading: live[i]),
        ],
      ],
    );
  }
}

class _LiveRow extends StatelessWidget {
  const _LiveRow({required this.reading});

  final SensorReading reading;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    final List<Color> axisHues = <Color>[t.photo, t.docs, t.chat];

    return GCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  _label(reading.type),
                  style: GType.body.copyWith(color: t.text),
                ),
              ),
              Text(reading.unit, style: GType.micro.copyWith(color: t.dim)),
            ],
          ),
          const SizedBox(height: GSpace.sm),
          Row(
            children: <Widget>[
              for (int i = 0; i < reading.values.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: GSpace.md),
                Expanded(
                  child: _Axis(
                    value: reading.values[i],
                    // Three values are x, y and z. One value has no axis and
                    // gets no letter, because calling a light reading "x" is
                    // worse than calling it nothing.
                    label: reading.values.length > 1
                        ? <String>['x', 'y', 'z'][i]
                        : null,
                    hue: axisHues[i % axisHues.length],
                    range: reading.maxRange,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  static String _label(String type) => switch (type) {
    'accelerometer' => 'Accelerometer',
    'gyroscope' => 'Gyroscope',
    'magnetometer' => 'Magnetometer',
    'light' => 'Light',
    'proximity' => 'Proximity',
    'pressure' => 'Pressure',
    _ => type,
  };
}

class _Axis extends StatelessWidget {
  const _Axis({
    required this.value,
    required this.label,
    required this.hue,
    required this.range,
  });

  final double value;
  final String? label;
  final Color hue;
  final double? range;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    // Signed sensors fill from the middle, unsigned from the left.
    //
    // An accelerometer at rest reads about -9.8 on one axis, and drawing that
    // as a bar from zero would make gravity look like a fault. A centre origin
    // shows direction, which is the whole reason the number has a sign.
    final bool signed = range != null && range! > 0 && value < 0;
    final double span = (range == null || range! <= 0) ? 100 : range!;
    final double fraction = (value.abs() / span).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            if (label != null) ...<Widget>[
              Text(label!, style: GType.micro.copyWith(color: t.dim)),
              const SizedBox(width: GSpace.xs + 1),
            ],
            Expanded(
              child: Text(
                value.toStringAsFixed(2),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GType.monoNumber.copyWith(color: hue, fontSize: 14),
              ),
            ),
          ],
        ),
        const SizedBox(height: GSpace.xs + 1),
        ClipRRect(
          borderRadius: GRadius.all(3),
          child: SizedBox(
            height: 5,
            child: Stack(
              children: <Widget>[
                Positioned.fill(child: ColoredBox(color: t.panelAlt)),
                // No implicit animation on the width: at five readings a second
                // a tween would still be catching up when the next value lands,
                // which reads as lag rather than smoothness.
                Align(
                  alignment: signed
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: fraction,
                    heightFactor: 1,
                    child: ColoredBox(color: hue),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
