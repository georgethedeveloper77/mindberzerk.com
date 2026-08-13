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

class BatteryCard extends ConsumerWidget {
  const BatteryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;
    final ProbeCapabilities? caps = ref.watch(deviceCapabilitiesProvider).value;
    final ProbeTick? tick = ref.watch(deviceTickProvider).value;
    final BatterySnapshot? battery = tick?.current.battery;

    if (caps != null && !caps.battery) {
      return UnavailableNote(
        title: context.s('Battery'),
        reason:
            'This device reports no battery. That is expected on an '
            'emulator and on mains powered hardware.',
      );
    }
    if (battery == null) {
      return PendingNote(title: context.s('Reading battery'));
    }

    final int? percent = battery.percent;
    final bool charging = battery.charging ?? false;

    // Rows are built as a list and the nulls are filtered out, so a device that
    // serves half of these renders a short card rather than a long one full of
    // blanks.
    // TWO GROUPS, not one list of eight.
    //
    // Wear and current state answer different questions and were interleaved:
    // cycle count sat between voltage and chemistry, which is where a number
    // goes to be ignored. Health first, because it is the reason to open this
    // page.
    final List<(String, String)> wear = _present(<(String, String?)>[
      (
        'Capacity now',
        DeviceFormat.microAmpHours(battery.chargeCounterMicroAh),
      ),
      ('When new', DeviceFormat.microAmpHours(battery.designCapacityMicroAh)),
      ('Charge cycles', battery.cycleCount?.toString()),
      ('Reported state', DeviceFormat.humanise(battery.health)),
    ]);

    final List<(String, String)> nowRows = _present(<(String, String?)>[
      ('Status', DeviceFormat.humanise(battery.status)),
      ('Temperature', DeviceFormat.celsiusFromDeci(battery.tempDeciC)),
      ('Voltage', DeviceFormat.volts(battery.voltageMilliV)),
      ('Current', DeviceFormat.milliAmps(battery.currentMicroA)),
      ('Chemistry', battery.technology),
    ]);

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
            ],
          ),
        ),

        if (wear.isNotEmpty) ...<Widget>[
          const SizedBox(height: GSpace.lg),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              context.s('HEALTH'),
              style: GType.overline.copyWith(color: t.dim),
            ),
          ),
          const SizedBox(height: GSpace.sm + 1),
          GCard(child: _Rows(rows: wear)),
        ],

        if (nowRows.isNotEmpty) ...<Widget>[
          const SizedBox(height: GSpace.lg),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              context.s('RIGHT NOW'),
              style: GType.overline.copyWith(color: t.dim),
            ),
          ),
          const SizedBox(height: GSpace.sm + 1),
          GCard(child: _Rows(rows: nowRows)),
        ],
      ],
    );
  }

  /// Drops the rows this device will not answer.
  static List<(String, String)> _present(List<(String, String?)> rows) =>
      <(String, String)>[
        for (final (String label, String? value) in rows)
          if (value != null) (label, value),
      ];
}

class _Rows extends StatelessWidget {
  const _Rows({required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    return Column(
      children: <Widget>[
        for (int i = 0; i < rows.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(vertical: GSpace.sm + 1),
            decoration: BoxDecoration(
              border: i == rows.length - 1
                  ? null
                  : Border(bottom: BorderSide(color: t.line)),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    rows[i].$1,
                    style: GType.bodySmall.copyWith(color: t.text),
                  ),
                ),
                Text(
                  rows[i].$2,
                  style: GType.monoSmall.copyWith(color: t.muted),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
