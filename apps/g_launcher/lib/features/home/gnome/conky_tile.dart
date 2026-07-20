import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/ubuntu_tokens.dart';
import '../../../system/system_stats.dart';

/// The conky. Top-right, right-aligned, Ubuntu Mono, orange accents.
///
/// Mockup:
///
///     Thursday, 18 June          12px, white .78
///     19:42                      30px, bold, tight tracking
///     ─────────────────────      1px rule, white .18
///     cpu 18%   mem 3.1/8G       11px, white .7, "18%" in orange
///     net ↓ 4.2M  ↑ 0.8M         11px, no rule above
///
/// With the authentic decision, this and the dock are the ONLY things on the
/// desktop. That raises the stakes on it considerably: it is no longer a widget
/// on a home screen, it *is* the home screen. So it degrades one line at a time
/// rather than all at once — a clock-and-date conky still looks intentional,
/// which is what you get today until the native stats channel lands.
///
/// Never renders `cpu --%`. A missing stat removes its row.
class ConkyTile extends ConsumerWidget {
  const ConkyTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider).asData?.value ?? DateTime.now();
    final stats = ref.watch(systemStatsProvider).asData?.value;

    final hasCpu = stats?.cpuPercent != null;
    final hasMem = stats?.hasMemory ?? false;
    final hasNet = stats?.hasNet ?? false;

    return IgnorePointer(
      // The conky is decoration. Taps go through it to the desktop — an
      // unresponsive rectangle in the corner of the home screen feels broken,
      // and a real conky isn't clickable either.
      child: DefaultTextStyle(
        style: const TextStyle(
          fontFamily: Ubuntu.mono,
          color: Ubuntu.conkyPrimary,
          height: 1.55,
          shadows: Ubuntu.desktopTextShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                formatDateLong(now),
                style: const TextStyle(fontSize: 12, color: Ubuntu.conkyDate),
              ),
            ),
            Text(
              formatTime(now),
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            if (hasCpu || hasMem)
              _StatLine(
                topRule: true,
                child: _CpuMem(stats: stats!, hasCpu: hasCpu, hasMem: hasMem),
              ),
            if (hasNet)
              _StatLine(
                // The mockup gives the net line no rule — it belongs to the same
                // block as cpu/mem. But if cpu/mem is absent, this becomes the
                // first stat line and needs the rule to separate it from the
                // clock.
                topRule: !(hasCpu || hasMem),
                child: Text(
                  'net ↓ ${SystemStats.rate(stats!.netDownBytesPerSec)}'
                  '\u00A0\u00A0↑ ${SystemStats.rate(stats.netUpBytesPerSec)}',
                  style: const TextStyle(fontSize: 11, color: Ubuntu.conkyStat),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CpuMem extends StatelessWidget {
  const _CpuMem({
    required this.stats,
    required this.hasCpu,
    required this.hasMem,
  });

  final SystemStats stats;
  final bool hasCpu;
  final bool hasMem;

  @override
  Widget build(BuildContext context) {
    const base = TextStyle(
      fontFamily: Ubuntu.mono,
      fontSize: 11,
      color: Ubuntu.conkyStat,
      height: 1.55,
      shadows: Ubuntu.desktopTextShadow,
    );

    return Text.rich(
      TextSpan(
        style: base,
        children: [
          if (hasCpu) ...[
            const TextSpan(text: 'cpu '),
            TextSpan(
              text: '${stats.cpuPercent}%',
              style: const TextStyle(color: Ubuntu.orange),
            ),
          ],
          if (hasCpu && hasMem) const TextSpan(text: '\u00A0\u00A0\u00A0'),
          if (hasMem) TextSpan(text: 'mem ${stats.memLabel}'),
        ],
      ),
    );
  }
}

class _StatLine extends StatelessWidget {
  const _StatLine({required this.child, required this.topRule});

  final Widget child;
  final bool topRule;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: topRule ? 7 : 3),
      padding: EdgeInsets.only(top: topRule ? 7 : 0),
      decoration: topRule
          ? const BoxDecoration(
              border: Border(top: BorderSide(color: Ubuntu.conkyRule)),
            )
          : null,
      child: child,
    );
  }
}
