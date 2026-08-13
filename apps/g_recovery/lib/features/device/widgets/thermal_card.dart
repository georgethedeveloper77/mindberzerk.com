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
import '../../../core/i18n/g_strings.dart';

class ThermalCard extends ConsumerWidget {
  const ThermalCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;
    final ProbeCapabilities? caps = ref.watch(deviceCapabilitiesProvider).value;
    final ProbeTick? tick = ref.watch(deviceTickProvider).value;
    final ThermalSample? thermal = tick?.current.thermal;

    final String? status = DeviceFormat.thermalStatus(thermal?.status);
    final List<ThermalZone> zones = thermal?.zones ?? const <ThermalZone>[];
    final int band = DeviceFormat.thermalBand(thermal?.status);

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
                        context.s('Thermal state'),
                        style: GType.heading.copyWith(color: t.text),
                      ),
                      Text(
                        // The framework level is the throttling decision the
                        // system has actually made, which is more useful than
                        // any single zone reading.
                        context.s(
                          'What Android itself thinks, from the system thermal '
                          'service',
                        ),
                        style: GType.micro.copyWith(color: t.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: GSpace.md),
                // Motion means "look at this", so only the hot band moves. A
                // pulsing dot for a phone sitting at a perfectly ordinary
                // temperature would spend the user's attention on a non-event,
                // and a device utility that cries wolf gets uninstalled.
                if (band == 2) ...<Widget>[
                  const _ThermalPulse(),
                  const SizedBox(width: GSpace.sm),
                ],
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
                        context.s('Zones'),
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
            title: context.s('Zones'),
            reason:
                'This ROM does not let apps read the thermal sensors '
                'directly. The state above is the only thermal signal it will '
                'give up, and it is the one Android acts on.',
          )
        else
          PendingNote(title: context.s('Reading thermal zones')),
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
    switch (DeviceFormat.thermalBand(status)) {
      case 0:
        return t.success;
      case 1:
        return t.warning;
      default:
        return t.danger;
    }
  }
}

/// The one moving thing in the thermal card, built only while the device is
/// actually hot.
///
/// Separate widget rather than a flag on the card, so in the two states a user
/// sees almost always there is no controller in existence at all. A ticker that
/// is merely stopped still costs a subscription on a tab that already reads
/// sysfs at 2 Hz.
class _ThermalPulse extends StatefulWidget {
  const _ThermalPulse();

  @override
  State<_ThermalPulse> createState() => _ThermalPulseState();
}

class _ThermalPulseState extends State<_ThermalPulse>
    with SingleTickerProviderStateMixin {
  // Constructed here, never as a late final with an initialiser. The lazy form
  // can run its initialiser from inside dispose, where createTicker reads
  // TickerMode off a deactivated element.
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    if (MediaQuery.disableAnimationsOf(context)) {
      return _dot(t.danger);
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        // A slow breath between full and half, not a blink. Blinking reads as a
        // fault indicator on a piece of hardware.
        final double alpha = 0.45 + 0.55 * _controller.value;
        return _dot(t.danger.withValues(alpha: alpha));
      },
    );
  }

  Widget _dot(Color colour) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
  );
}
