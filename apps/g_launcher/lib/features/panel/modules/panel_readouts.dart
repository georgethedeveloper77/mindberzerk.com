/// Network, memory and storage, as text on a panel.
///
/// ─── LIFTED OUT OF gnome_top_bar ───────────────────────────────────────────
///
/// This drew only on a GNOME bar, and every other panel in the app answered
/// these three modules with `SizedBox.shrink()`. The comment in `plasma_shell`
/// said so outright and called the lift a refactor with its own decisions,
/// which is what this is: a distro authoring `memory` on a Breeze panel got a
/// gap, and the gap was indistinguishable from the module being broken.
///
/// ─── ONE WIDGET FOR THREE MODULES, ON PURPOSE ──────────────────────────────
///
/// All three read a single stats snapshot, and splitting them would mean three
/// subscriptions to the same stream. So the caller draws this at the FIRST of
/// the three in the theme's order and skips it at the others, which keeps the
/// theme in charge of WHERE in the run they appear while costing one listen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../engine/theme_spec.dart' show PanelModule, ThemePalette;
import '../../../system/system_stats.dart';

/// The three modules this widget answers, in the order it falls back to.
const List<PanelModule> statModules = [
  PanelModule.network,
  PanelModule.memory,
  PanelModule.storage,
];

bool isStatModule(PanelModule m) => statModules.contains(m);

class PanelReadouts extends ConsumerWidget {
  const PanelReadouts({
    super.key,
    required this.palette,
    required this.fontFamily,
    this.stacked = false,
    this.show = const [],
  });

  /// One module per line, for a vertical bar.
  final bool stacked;

  /// Which readouts this panel asked for, in the theme's order. Empty means the
  /// caller filtered nothing out, which only happens from a legacy path.
  final List<PanelModule> show;

  final ThemePalette palette;
  final String? fontFamily;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(systemStatsProvider);
    final s = async.hasValue ? async.requireValue : null;
    if (s == null) return const SizedBox.shrink();

    // The theme's order, not this file's. A distro that lists storage before
    // network gets storage before network.
    final wanted = show.isEmpty ? statModules : show;

    String? render(PanelModule m) => switch (m) {
          PanelModule.network when s.hasNet =>
            '\u2193 ${SystemStats.rate(s.netDownBytesPerSec)}'
                '${stacked ? '\n' : '  '}'
                '\u2191 ${SystemStats.rate(s.netUpBytesPerSec)}',
          PanelModule.memory when s.hasMemory => s.memLabel,
          PanelModule.storage when s.hasStorage =>
            SystemStats.bytes(s.storageTotalBytes! - s.storageUsedBytes!),
          // A stat this device will not report REMOVES its module rather than
          // printing a placeholder, which is the rule every stat surface in
          // this app follows.
          _ => null,
        };

    final parts = <String>[
      for (final m in wanted)
        if (render(m) case final t?) t,
    ];

    if (parts.isEmpty) return const SizedBox.shrink();

    final style = TextStyle(
      fontFamily: fontFamily,
      // A vertical bar is 40dp wide, so the readouts drop a point to fit
      // "4.6/7G" without ellipsising the number that matters.
      fontSize: stacked ? 9 : 11,
      color: palette.onDark.withValues(alpha: 0.75),
    );

    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final p in parts)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                p,
                textAlign: TextAlign.center,
                // TWO lines, because the network module is a down and an up
                // reading and a 40dp column cannot hold both side by side. The
                // horizontal bar keeps them on one line where there is room.
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
            ),
        ],
      );
    }

    return Text(
      parts.join('   '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }
}
