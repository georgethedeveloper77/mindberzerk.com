/// The calendar the panel clock opens.
///
/// ─── THE ONE MODULE THAT DID NOTHING AT ALL ────────────────────────────────
///
/// Battery, network and volume each report something and each open a screen.
/// The clock reported the time and swallowed every tap, which on a panel that
/// otherwise responds is read as the panel being broken rather than as the
/// clock being finished.
///
/// A month grid is also the most recognisable thing a desktop panel clock does.
/// Cinnamon, Plasma, Xfce and the Windows taskbar all open one from the same
/// corner, and it is the single affordance a person who has used any of them
/// will try first.
///
/// ─── AND WHY IT IS A MONTH AND NOT AN AGENDA ───────────────────────────────
///
/// An agenda needs the calendar provider, which is a runtime permission, a new
/// Pigeon surface and a Play Store data-safety disclosure for the sake of a
/// popover. A month grid needs the date, which the launcher already has. It
/// answers what a panel calendar is actually asked ("what day is the 14th")
/// without asking the user for anything.
///
/// ─── LOCALISATION COMES FROM FLUTTER, NOT FROM `i18n` ──────────────────────
///
/// Weekday letters, the month name and WHICH DAY THE WEEK STARTS ON are all in
/// `MaterialLocalizations` for every locale this app ships. Restating them in
/// `translations.dart` would be re-authoring a table Flutter already has, and
/// the first-day index in particular is the kind of thing that is quietly wrong
/// for months: a grid that starts on Monday for a user whose week starts on
/// Sunday puts every date under the wrong column.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g_launcher/i18n/i18n.dart';

import '../../../data/repositories/app_repository.dart';
import '../../../design/components/components.dart';
import '../../../system/system_stats.dart';
import 'panel_applet_menu.dart';

const _dateSettings = 'android.settings.DATE_SETTINGS';

void showCalendarMenu(BuildContext context, WidgetRef ref) {
  final now = ref.read(clockProvider).asData?.value ?? DateTime.now();

  showAppletMenu(
    context: context,
    // The month, not the word "Calendar". The header is the one line of the
    // popover that is always read, so it carries the thing being looked at.
    title: MaterialLocalizations.of(context).formatMonthYear(now),
    rows: (menu) => [
      _MonthGrid(month: now),
      // Android's own, because there is no date page in this app and no reason
      // to build one: the launcher does not set the clock.
      androidSettingsRow(
        menuContext: menu,
        title: menu.t('shell.dateAndTimeSettings'),
        action: _dateSettings,
        open: ref.read(launcherHostApiProvider).openAndroidSettings,
      ),
    ],
  );
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.month});

  final DateTime month;

  /// Seven columns is not negotiable, so the cell is whatever a seventh of the
  /// popover is. Fixed at 28dp the grid overflowed the 224dp panel by a
  /// hairline on the widest locales.
  static const _rowHeight = 30.0;

  @override
  Widget build(BuildContext context) {
    final chrome = ChromeScope.of(context);
    final l10n = MaterialLocalizations.of(context);

    final first = DateTime(month.year, month.month);
    // Day zero of the NEXT month is the last day of this one, which is the
    // only leap-year-safe way to count these without a table.
    final days = DateTime(month.year, month.month + 1, 0).day;

    // `DateTime.weekday` is 1 for Monday through 7 for Sunday;
    // `firstDayOfWeekIndex` is 0 for Sunday. The modulo maps the first onto the
    // second before they are compared.
    final startColumn = (first.weekday % 7 - l10n.firstDayOfWeekIndex + 7) % 7;

    final labels = [
      for (var i = 0; i < 7; i++)
        l10n.narrowWeekdays[(l10n.firstDayOfWeekIndex + i) % 7],
    ];

    Widget cell(Widget child) => SizedBox(height: _rowHeight, child: child);

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 2, 10, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              for (final label in labels)
                Expanded(
                  child: SizedBox(
                    height: 18,
                    child: Center(
                      child: Text(
                        label,
                        style: chrome.text.caption.copyWith(
                          color: chrome.colors.textFaint,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          for (var row = 0; row * 7 < startColumn + days; row++)
            Row(
              children: [
                for (var column = 0; column < 7; column++)
                  Expanded(
                    child: cell(
                      _cellFor(
                        chrome: chrome,
                        day: row * 7 + column - startColumn + 1,
                        days: days,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  /// A day outside the month is BLANK rather than the greyed neighbour a
  /// desktop calendar shows. At 30dp a dimmed 31 beside a live 1 is two numbers
  /// competing for the same glance, and the month being looked at is the point.
  Widget _cellFor({
    required ChromeData chrome,
    required int day,
    required int days,
  }) {
    if (day < 1 || day > days) return const SizedBox.shrink();

    final today = day == month.day;
    return Center(
      child: Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: today
            ? BoxDecoration(
                color: chrome.colors.accent,
                borderRadius: BorderRadius.circular(6),
              )
            : null,
        child: Text(
          '$day',
          style: chrome.text.body.copyWith(
            fontSize: 12,
            color: today ? chrome.colors.onAccent : chrome.colors.text,
            fontWeight: today ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
