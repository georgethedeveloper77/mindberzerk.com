import 'package:device_probe/device_probe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/format.dart';
import '../../../ui/g_card.dart';
import '../../../ui/g_detail_page.dart';
import '../../../ui/g_stat.dart';
import '../device_format.dart';
import '../state/device_history.dart';
import '../state/device_providers.dart';
import '../widgets/g_line_chart.dart';
import '../widgets/unavailable_note.dart';
import '../../../core/i18n/g_strings.dart';

/// RAM AND SWAP.
///
/// ─── AVAILABLE IS THE HEADLINE, NOT USED ─────────────────────────────────────
///
/// Android fills memory on purpose: unused RAM is wasted RAM, and a phone that
/// reports 90% used is usually a phone that is working correctly. What a person
/// can act on is how much is left before the system starts killing what they
/// have open, which is why the threshold sits directly under it.
class MemoryPage extends ConsumerWidget {
  const MemoryPage({required this.hue, super.key});

  final Color hue;

  static Route<void> route({required Color hue}) => MaterialPageRoute<void>(
    builder: (BuildContext context) => MemoryPage(hue: hue),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;
    final ProbeTick? tick = ref.watch(deviceTickProvider).value;
    final MemorySnapshot? memory = tick?.current.memory;

    final List<VitalSample> history = ref.watch(vitalHistoryProvider);
    final List<double> freeSeries = vitalSeries(
      history,
      (VitalSample s) => s.freeBytes == null ? null : s.freeBytes! / 1073741824,
    );

    final int? total = memory?.totalBytes;
    final int? avail = memory?.availBytes;
    final int? used = (total != null && avail != null) ? total - avail : null;

    final int? swapTotal = memory?.swapTotalBytes;
    final int? swapFree = memory?.swapFreeBytes;
    final int? swapUsed = (swapTotal != null && swapFree != null)
        ? swapTotal - swapFree
        : null;

    return GDetailPage(
      hue: hue,
      icon: Icons.grid_view_rounded,
      title: context.s('Memory'),
      subtitle: total == null ? null : '${GFormat.bytes(total)} total',
      children: <Widget>[
        if (memory == null)
          PendingNote(title: context.s('Reading memory'))
        else ...<Widget>[
          GCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      avail == null ? 'Memory' : GFormat.bytes(avail),
                      style: GType.monoDisplay.copyWith(color: t.text),
                    ),
                    if (total != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6, left: 6),
                        child: Text(
                          'available of ${GFormat.bytes(total)}',
                          style: GType.monoSmall.copyWith(color: t.muted),
                        ),
                      ),
                  ],
                ),
                if (used != null && avail != null) ...<Widget>[
                  const SizedBox(height: GSpace.md),
                  GStackBar(
                    parts: <GStackPart>[
                      GStackPart(
                        bytes: used,
                        colour: (memory.lowMemory ?? false) ? t.danger : hue,
                      ),
                      GStackPart(bytes: avail, colour: t.panelHigh),
                    ],
                  ),
                  const SizedBox(height: GSpace.sm + 2),
                  GStackKeys(
                    entries: <(String, Color)>[
                      (
                        'Used ${GFormat.bytes(used)}',
                        (memory.lowMemory ?? false) ? t.danger : hue,
                      ),
                      ('Free ${GFormat.bytes(avail)}', t.panelHigh),
                    ],
                  ),
                ],
                if (total != null) ...<Widget>[
                  const SizedBox(height: GSpace.sm + 2),
                  Text(
                    // Android never reports the number on the box, and a user
                    // who bought an 8 GB phone and reads 7.63 assumes something
                    // is wrong or stolen.
                    'Sold as '
                    '${GFormat.bytes(DeviceFormat.nominalRamBytes(total))}. '
                    'The kernel and the bootloader reserve the difference '
                    'before userspace sees it.',
                    style: GType.micro.copyWith(color: t.dim),
                  ),
                ],
              ],
            ),
          ),

          if (freeSeries.isNotEmpty) ...<Widget>[
            const SizedBox(height: GSpace.md - 1),
            GChartCard(
              caption: context.s('Free memory, last minute'),
              axis: const <String>['a minute ago', 'now'],
              child: GLineChart(values: freeSeries, colour: hue, height: 76),
            ),
          ],

          if (memory.lowMemory ?? false) ...<Widget>[
            const SizedBox(height: GSpace.md - 1),
            GCard(
              tint: t.danger,
              child: Text(
                context.s(
                  'Android is below its own low memory threshold and is killing '
                  'background apps to keep going.',
                ),
                style: GType.bodySmall.copyWith(color: t.text),
              ),
            ),
          ],

          if (swapTotal != null && swapTotal > 0) ...<Widget>[
            const SizedBox(height: GSpace.lg),
            const GOverline('Swap and zram'),
            const SizedBox(height: GSpace.sm + 1),
            GCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (swapUsed != null && swapFree != null) ...<Widget>[
                    GStackBar(
                      parts: <GStackPart>[
                        GStackPart(bytes: swapUsed, colour: t.photo),
                        GStackPart(bytes: swapFree, colour: t.panelHigh),
                      ],
                    ),
                    const SizedBox(height: GSpace.sm + 2),
                    GStackKeys(
                      entries: <(String, Color)>[
                        ('Used ${GFormat.bytes(swapUsed)}', t.photo),
                        ('Free ${GFormat.bytes(swapFree)}', t.panelHigh),
                      ],
                    ),
                    const SizedBox(height: GSpace.sm + 2),
                  ],
                  Text(
                    // Worth a sentence, because "swap" on a phone is not the
                    // disk file it is on a desktop and the difference decides
                    // whether the number is alarming.
                    context.s(
                      'Compressed in RAM rather than written to storage, so it '
                      'costs processor time instead of wear.',
                    ),
                    style: GType.micro.copyWith(color: t.dim),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: GSpace.lg),
          const GOverline('Detail'),
          const SizedBox(height: GSpace.sm + 1),
          GSpecCard(
            rows: <(String, String?)>[
              ('Total RAM', GFormat.bytesOrNull(total)),
              ('Available', GFormat.bytesOrNull(avail)),
              ('In use', GFormat.bytesOrNull(used)),
              (
                'Low memory',
                memory.lowMemory == null
                    ? null
                    : (memory.lowMemory! ? 'Yes' : 'No'),
              ),
              ('Kill threshold', GFormat.bytesOrNull(memory.thresholdBytes)),
              ('Swap total', GFormat.bytesOrNull(swapTotal)),
              ('Swap free', GFormat.bytesOrNull(swapFree)),
            ],
          ),
        ],
      ],
    );
  }
}
