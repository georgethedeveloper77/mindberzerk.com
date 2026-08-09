import 'package:device_probe/device_probe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/format.dart';
import '../../../ui/g_bar.dart';
import '../../../ui/g_card.dart';
import '../device_format.dart';
import '../state/device_providers.dart';
import 'unavailable_note.dart';

class MemoryCard extends ConsumerWidget {
  const MemoryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;
    final ProbeTick? tick = ref.watch(deviceTickProvider).value;
    final MemorySnapshot? memory = tick?.current.memory;

    if (memory == null) {
      return PendingNote(title: 'Reading memory');
    }

    final int? total = memory.totalBytes;
    final int? avail = memory.availBytes;
    final int? used = (total != null && avail != null) ? total - avail : null;

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
                    used == null ? 'Memory' : GFormat.bytes(used),
                    style: GType.monoDisplay.copyWith(color: t.text),
                  ),
                  if (total != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6, left: 6),
                      child: Text(
                        'of ${GFormat.bytes(total)} in use',
                        style: GType.monoSmall.copyWith(color: t.muted),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: GSpace.md),
              GBar(
                fraction: (used != null && total != null && total > 0)
                    ? used / total
                    : null,
                colour: (memory.lowMemory ?? false) ? t.danger : t.video,
                height: 8,
              ),
              if (total != null) ...<Widget>[
                const SizedBox(height: GSpace.sm),
                Text(
                  // Android never reports the number on the box, and a user who
                  // bought an 8 GB phone and reads 7.63 assumes something is
                  // wrong or stolen.
                  'Sold as ${GFormat.bytes(DeviceFormat.nominalRamBytes(total))}. '
                  'The kernel and the bootloader reserve the difference before '
                  'userspace sees it.',
                  style: GType.micro.copyWith(color: t.dim),
                ),
              ],
              const GCardDivider(),
              _Row(
                label: 'Available',
                value: GFormat.bytesOrNull(memory.availBytes),
              ),
              _Row(
                label: 'Low memory threshold',
                value: GFormat.bytesOrNull(memory.thresholdBytes),
              ),
              _Row(
                label: 'Swap and zram',
                value: GFormat.bytesOrNull(memory.swapTotalBytes),
              ),
              _Row(
                label: 'Swap free',
                value: GFormat.bytesOrNull(memory.swapFreeBytes),
              ),
            ],
          ),
        ),
        if (memory.lowMemory ?? false) ...<Widget>[
          const SizedBox(height: GSpace.md - 2),
          GCard(
            tint: t.danger,
            child: Text(
              'Android is below its own low memory threshold and is killing '
              'background apps to keep going.',
              style: GType.bodySmall.copyWith(color: t.text),
            ),
          ),
        ],
      ],
    );
  }
}

/// Label and value, and NOTHING when the value is null. Same rule as GStat:
/// absent data is an absent row.
class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    if (value == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(label, style: GType.bodySmall.copyWith(color: t.muted)),
          ),
          Text(value!, style: GType.monoNumber.copyWith(color: t.text)),
        ],
      ),
    );
  }
}
