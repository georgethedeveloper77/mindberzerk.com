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

class ThermalCard extends ConsumerWidget {
  const ThermalCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;
    final ProbeCapabilities? caps =
        ref.watch(deviceCapabilitiesProvider).value;
    final ProbeTick? tick = ref.watch(deviceTickProvider).value;
    final ThermalSample? thermal = tick?.current.thermal;

    final String? status = DeviceFormat.thermalStatus(thermal?.status);
    final List<ThermalZone> zones = thermal?.zones ?? const <ThermalZone>[];

    return Column(
      children: <Widget>[
        if (status != null)
          GCard(
            tint: _statusTone(t, thermal?.status),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Thermal state',
                        style: GType.heading.copyWith(color: t.text),
                      ),
                      Text(
                        // The framework level is the throttling decision the
                        // system has actually made, which is more useful than
                        // any single zone reading.
                        'What Android itself thinks, from the system thermal '
                        'service',
                        style: GType.micro.copyWith(color: t.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: GSpace.md),
                Text(
                  status,
                  style: GType.monoNumber.copyWith(
                    color: _statusTone(t, thermal?.status),
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        if (status != null && zones.isNotEmpty)
          const SizedBox(height: GSpace.md - 2),
        if (zones.isNotEmpty)
          GCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Zones',
                        style: GType.heading.copyWith(color: t.text),
                      ),
                    ),
                    GBadge.live('${zones.length}'),
                  ],
                ),
                const SizedBox(height: GSpace.sm),
                for (final ThermalZone zone in _ordered(zones))
                  GMeterRow(
                    label: zone.label,
                    value: DeviceFormat.celsiusFromMilli(zone.milliCelsius),
                    fraction: DeviceFormat.thermalFraction(zone.milliCelsius),
                    colour: _zoneTone(t, zone.milliCelsius),
                    labelWidth: 96,
                    valueWidth: 56,
                  ),
              ],
            ),
          )
        else if (caps != null && !caps.thermalZones)
          UnavailableNote(
            title: 'Zones',
            reason: 'This ROM does not let apps read the thermal sensors '
                'directly. The state above is the only thermal signal it will '
                'give up, and it is the one Android acts on.',
          )
        else
          PendingNote(title: 'Reading thermal zones'),
      ],
    );
  }

  /// Known categories first and in a fixed order, so the card does not reshuffle
  /// between ticks, then everything else by temperature.
  List<ThermalZone> _ordered(List<ThermalZone> zones) {
    const List<String> priority = <String>[
      'battery',
      'cpu',
      'gpu',
      'skin',
      'modem',
      'ambient',
      'other',
    ];
    final List<ThermalZone> sorted = List<ThermalZone>.of(zones);
    sorted.sort((ThermalZone a, ThermalZone b) {
      final int rankA = priority.indexOf(a.category);
      final int rankB = priority.indexOf(b.category);
      if (rankA != rankB) return rankA.compareTo(rankB);
      return b.milliCelsius.compareTo(a.milliCelsius);
    });
    return sorted;
  }

  Color _zoneTone(GTokens t, int milliCelsius) {
    final double celsius = milliCelsius / 1000;
    if (celsius >= 55) return t.danger;
    if (celsius >= 43) return t.warning;
    return t.success;
  }

  Color _statusTone(GTokens t, int? status) {
    if (status == null || status <= 0) return t.success;
    if (status <= 2) return t.warning;
    return t.danger;
  }
}
