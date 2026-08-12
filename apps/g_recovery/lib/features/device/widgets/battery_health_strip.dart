import 'package:device_probe/device_probe.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/format.dart';

/// HOW WORN THE BATTERY IS.
///
/// The one figure on this tab a person cannot find anywhere else on their
/// phone, Settings included. It sat in the empty half of the battery card,
/// which was 86 pixels of gradient under a line that barely moves.
///
/// ─── ABSENT, NEVER ESTIMATED ─────────────────────────────────────────────────
///
/// State of health is API 35 and null on most devices even above it: the
/// property exists in the framework and the OEM has to fill it in. When it is
/// missing the strip does not render, with nothing in its place and no sentence
/// explaining the gap.
///
/// A worn battery reported as healthy because the app guessed from cycle count
/// is worse than no answer, and the guess would be the reason someone kept a
/// phone that needed a new cell.
class BatteryHealthStrip extends StatelessWidget {
  const BatteryHealthStrip({required this.battery, super.key});

  final BatterySnapshot? battery;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    final BatterySnapshot? b = battery;
    if (b == null) return const SizedBox.shrink();

    // Same rule as the rows below: build the list, drop the nulls, render what
    // is left. A phone that reports one of the three gets one cell.
    final List<(String, String)> cells = <(String, String)>[
      if (b.stateOfHealthPercent != null)
        ('${b.stateOfHealthPercent}%', 'HEALTH'),
      if (b.cycleCount != null) (GFormat.count(b.cycleCount!), 'CYCLES'),
      if (b.chargeCounterMicroAh != null)
        (_mah(b.chargeCounterMicroAh!), 'MAH NOW'),
    ];

    if (cells.isEmpty) return const SizedBox.shrink();

    final bool dark = t.brightness == Brightness.dark;
    final Color hue = _hueFor(b.stateOfHealthPercent, t);

    return Padding(
      padding: const EdgeInsets.only(top: GSpace.sm + 1),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: hue.withValues(alpha: dark ? 0.11 : 0.08),
          border: Border.all(color: hue.withValues(alpha: dark ? 0.34 : 0.26)),
          borderRadius: GRadius.all(GRadius.card),
        ),
        child: Row(
          children: <Widget>[
            for (int i = 0; i < cells.length; i++)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: GSpace.md - 2,
                    vertical: GSpace.md - 3,
                  ),
                  decoration: BoxDecoration(
                    border: i == cells.length - 1
                        ? null
                        : Border(
                            right: BorderSide(
                              color: hue.withValues(alpha: 0.2),
                            ),
                          ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        cells[i].$1,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GType.monoNumber.copyWith(
                          color: t.text,
                          fontSize: 17,
                        ),
                      ),
                      Text(
                        cells[i].$2,
                        style: GType.overline.copyWith(
                          color: t.muted,
                          fontSize: 9.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Amber below 80, which is where a replacement starts being worth it.
  ///
  /// Not a verdict and not a grade. The number is the statement; the colour only
  /// saves a person reading three digits to find out whether to care.
  static Color _hueFor(int? health, GTokens t) {
    if (health == null) return t.success;
    if (health < 70) return t.danger;
    if (health < 80) return t.warning;
    return t.success;
  }

  static String _mah(int microAmpHours) => GFormat.count(microAmpHours ~/ 1000);
}
