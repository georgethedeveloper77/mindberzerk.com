import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../bridge/hardware_api.g.dart';
import '../../../bridge/hardware_bridge.dart';
import '../../../ui/g_card.dart';
import '../../../ui/g_stat.dart';
import 'device_chrome.dart';

/// THE SIMS.
///
/// ─── THE NUMBER IS NOT HERE, AND WILL NOT BE ─────────────────────────────────
///
/// Reading the subscriber's own phone number needs more than phone state on
/// modern Android, and a recovery app asking for it would be the most alarming
/// permission in the product. Carrier, country and network codes answer every
/// question someone opens this page with.
class SimPage extends ConsumerWidget {
  const SimPage({required this.hue, super.key});

  final Color hue;

  static Route<void> route({required Color hue}) => MaterialPageRoute<void>(
    builder: (BuildContext context) => SimPage(hue: hue),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;
    final List<SimInfo> sims =
        ref.watch(simsProvider).value ?? const <SimInfo>[];

    return DeviceDetailPage(
      hue: hue,
      icon: Icons.sim_card_outlined,
      title: 'SIM',
      subtitle: sims.isEmpty
          ? null
          : '${sims.length} ${sims.length == 1 ? 'card' : 'cards'}',
      children: <Widget>[
        if (sims.isEmpty)
          // One state covers both "no permission" and "no SIM", because the
          // system call throws rather than distinguishing them. The button is
          // offered either way: on a phone with no SIM it grants a permission
          // that then shows nothing, which is a smaller cost than a dead end on
          // a phone that has one.
          GMissNote(
            icon: Icons.sim_card_outlined,
            text: 'Android needs phone access to name the carrier',
            onTap: () async {
              await ref.read(hardwareBridgeProvider).requestPhoneState();
              ref.invalidate(simsProvider);
            },
          ),

        for (final SimInfo sim in sims) ...<Widget>[
            Row(
              children: <Widget>[
                Text(
                  'SLOT ${sim.slot + 1}',
                  style: GType.overline.copyWith(color: t.dim),
                ),
                if (sim.dataDefault) ...<Widget>[
                  const SizedBox(width: GSpace.sm),
                  _Tag(label: 'Data', hue: t.success),
                ],
                if (sim.embedded) ...<Widget>[
                  const SizedBox(width: GSpace.sm),
                  _Tag(label: 'eSIM', hue: t.chat),
                ],
                if (sim.roaming) ...<Widget>[
                  const SizedBox(width: GSpace.sm),
                  _Tag(label: 'Roaming', hue: t.warning),
                ],
              ],
            ),
            const SizedBox(height: GSpace.sm + 1),
            GSpecCard(
              rows: <(String, String?)>[
                ('Carrier', sim.carrier),
                ('Country', sim.countryIso),
                ('MCC', sim.mcc),
                ('MNC', sim.mnc),
                ('Type', sim.embedded ? 'Built in' : 'Physical card'),
              ],
            ),
            const SizedBox(height: GSpace.md - 1),
          ],
      ],
    );
  }
}

/// THE BLUETOOTH RADIO.
class BluetoothPage extends ConsumerWidget {
  const BluetoothPage({required this.hue, super.key});

  final Color hue;

  static Route<void> route({required Color hue}) => MaterialPageRoute<void>(
    builder: (BuildContext context) => BluetoothPage(hue: hue),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final BluetoothInfo? bt = ref.watch(bluetoothProvider).value;

    return DeviceDetailPage(
      hue: hue,
      icon: Icons.bluetooth_rounded,
      title: 'Bluetooth',
      subtitle: bt == null
          ? null
          : bt.available
          ? (bt.enabled ? 'On' : 'Off')
          : 'Not fitted',
      children: <Widget>[
        if (bt != null) ...<Widget>[
          GSpecCard(
            rows: <(String, String?)>[
              ('Radio', bt.available ? 'Present' : 'Not fitted'),
              ('State', bt.enabled ? 'On' : 'Off'),
              ('This phone', bt.name),
            ],
          ),

          if (!bt.hasPermission) ...<Widget>[
            const SizedBox(height: GSpace.sm + 1),
            GMissNote(
              // Names what appears, not what is missing. "Grant Bluetooth" says
              // nothing about why anyone would.
              text: 'Paired devices need Bluetooth access',
              onTap: () async {
                await ref.read(hardwareBridgeProvider).requestBluetooth();
                ref.invalidate(bluetoothProvider);
              },
            ),
          ],

          if (bt.paired.isNotEmpty) ...<Widget>[
            const SizedBox(height: GSpace.lg),
            GOverline('${bt.paired.length} paired'),
            const SizedBox(height: GSpace.sm + 1),
            GCard(
              padding: const EdgeInsets.symmetric(horizontal: GSpace.md),
              child: Column(
                children: <Widget>[
                  for (int i = 0; i < bt.paired.length; i++)
                    _PairedRow(
                      device: bt.paired[i],
                      last: i == bt.paired.length - 1,
                    ),
                ],
              ),
            ),
          ],

          const SizedBox(height: GSpace.lg),
          const GOverline('Low energy'),
          const SizedBox(height: GSpace.sm + 1),
          GFlagCard(
            flags: <(String, bool)>[
              ('Bluetooth LE', bt.leSupported),
              ('2M PHY', bt.le2mSupported),
              ('Coded PHY', bt.leCodedSupported),
              ('LE Audio', bt.leAudioSupported),
            ],
          ),
        ],
      ],
    );
  }
}

class _PairedRow extends StatelessWidget {
  const _PairedRow({required this.device, required this.last});

  final PairedDevice device;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: GSpace.md - 3),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: t.line)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: t.chat.withValues(alpha: 0.16),
              borderRadius: GRadius.all(10),
            ),
            child: Icon(_icon(device.type), size: 16, color: t.chat),
          ),
          const SizedBox(width: GSpace.md),
          Expanded(
            child: Text(
              device.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GType.bodySmall.copyWith(color: t.text),
            ),
          ),
          Text(device.address, style: GType.monoSmall.copyWith(color: t.dim)),
        ],
      ),
    );
  }

  static IconData _icon(String type) => switch (type) {
    'audio' => Icons.headphones_rounded,
    'phone' => Icons.smartphone_rounded,
    'computer' => Icons.laptop_rounded,
    'wearable' => Icons.watch_rounded,
    'input' => Icons.keyboard_rounded,
    _ => Icons.bluetooth_rounded,
  };
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.hue});

  final String label;
  final Color hue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: GSpace.sm, vertical: 2),
      decoration: BoxDecoration(
        color: hue.withValues(alpha: 0.18),
        borderRadius: GRadius.all(GRadius.chip),
      ),
      child: Text(
        label,
        style: GType.micro.copyWith(color: hue, fontSize: 9.5),
      ),
    );
  }
}
