/// The panel clock, and the calendar it opens.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../system/system_stats.dart';
import '../applets/panel_calendar.dart';

class PanelClockModule extends ConsumerWidget {
  const PanelClockModule({
    super.key,
    required this.onDark,
    required this.narrow,
  });

  final Color onDark;

  /// True on a vertical panel, where the strip is about 40dp wide. The time
  /// drops a point to fit and the DATE goes entirely: "Thu 20 Aug" cannot be
  /// set in 40dp without either ellipsising or being turned on its side, and a
  /// clock nobody can read is worse than a clock with no date on it.
  final bool narrow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider).asData?.value ?? DateTime.now();

    // ── THE TAP, WHICH THIS MODULE DID NOT HAVE ─────────────────────────────
    //
    // Every other module on the panel answers a tap. This one drew the time and
    // swallowed the gesture, which on a responsive panel reads as a fault
    // rather than as a clock that is merely finished.
    return GestureDetector(
      onTap: () => showCalendarMenu(context, ref),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            formatTime(now),
            style: TextStyle(
              color: onDark,
              fontSize: narrow ? 11 : 14,
              fontWeight: FontWeight.w600,
              height: 1.0,
            ),
          ),
          if (!narrow)
            Text(
              formatDateShort(now),
              style: TextStyle(
                color: onDark.withValues(alpha: 0.7),
                fontSize: 9.5,
                height: 1.3,
              ),
            ),
        ],
      ),
    );
  }
}
