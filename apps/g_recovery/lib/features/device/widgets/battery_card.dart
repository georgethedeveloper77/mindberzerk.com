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

class BatteryCard extends ConsumerWidget {
  const BatteryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;
    final ProbeCapabilities? caps =
        ref.watch(deviceCapabilitiesProvider).value;
    final ProbeTick? tick = ref.watch(deviceTickProvider).value;
    final BatterySnapshot? battery = tick?.current.battery;

    if (caps != null && !caps.battery) {
      return UnavailableNote(
        title: 'Battery',
        reason: 'This device reports no battery. That is expected on an '
            'emulator and on mains powered hardware.',
      );
    }
    if (battery == null) {
      return PendingNote(title: 'Reading battery');
    }

    final int? percent = battery.percent;
    final bool charging = battery.charging ?? false;

    // Rows are built as a list and the nulls are filtered out, so a device that
    // serves half of these renders a short card rather than a long one full of
    // blanks.
    final List<(String, String?)> rows = <(String, String?)>[
      ('Status', DeviceFormat.humanise(battery.status)),
      ('Temperature', DeviceFormat.celsiusFromDeci(battery.tempDeciC)),
      ('Current', DeviceFormat.milliAmps(battery.currentMicroA)),
      ('Voltage', DeviceFormat.volts(battery.voltageMilliV)),
      ('Charge', DeviceFormat.microAmpHours(battery.chargeCounterMicroAh)),
      ('Cycles', battery.cycleCount?.toString()),
      ('Health', DeviceFormat.humanise(battery.health)),
      ('Chemistry', battery.technology),
    ];
    final List<(String, String)> present = <(String, String)>[
      for (final (String label, String? value) in rows)
        if (value != null) (label, value),
    ];

    return Column(
      children: <Widget>[
        GCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    percent == null ? 'Battery' : '$percent',
                    style: GType.monoDisplay.copyWith(color: t.text),
                  ),
                  if (percent != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5, left: 2),
                      child: Text(
                        '%',
                        style: GType.monoNumber.copyWith(color: t.muted),
                      ),
                    ),
                  const Spacer(),
                  if (charging) GBadge.full('Charging'),
                ],
              ),
              const SizedBox(height: GSpace.md),
              GBar(
                fraction: percent == null ? null : percent / 100,
                colour: charging ? t.success : t.accent,
                height: 8,
              ),
              if (present.isNotEmpty) const GCardDivider(),
              for (final (String label, String value) in present)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          label,
                          style: GType.bodySmall.copyWith(color: t.muted),
                        ),
                      ),
                      Text(
                        value,
                        style: GType.monoNumber.copyWith(color: t.text),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (battery.currentMicroA != null) ...<Widget>[
          const SizedBox(height: GSpace.md - 2),
          GCard(
            child: Text(
              // Worth one line on screen because a user who knows their phone
              // is discharging and sees a positive number assumes the app is
              // broken.
              'Current is shown as a magnitude. Direction comes from the '
              'charging state, because OEMs disagree on the sign.',
              style: GType.micro.copyWith(color: t.dim),
            ),
          ),
        ],
      ],
    );
  }
}
