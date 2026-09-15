import 'package:flutter/widgets.dart';
import 'package:g_launcher/i18n/i18n.dart';

/// Copy shared by the backup list, the restore screen and the missing apps
/// list.
///
/// Pulled out of `backup_screen.dart` when the restore screen started needing
/// the same dates and counts. Two copies of "1 distro" drift, and the first
/// symptom of that drift is a row and the screen it opens disagreeing about the
/// same file.
///
/// ─── THESE TAKE A CONTEXT NOW ───────────────────────────────────────────────
///
/// They used to build English by hand. Every string in this feature has moved
/// into `assets/i18n/en.json`, and `t` hangs off the context, so a helper that
/// formats a date or a count has to be handed one. The alternative was passing
/// finished strings down from each build method, which spreads the formatting
/// back into the widgets these exist to keep it out of.

/// One or many, without a placeholder in the singular case.
///
/// TWO KEYS rather than one with a count in it. A translator working in a
/// language with different plural rules needs to write both forms separately,
/// and "1 distros" reaching the screen is exactly what the pair prevents.
/// [oneKey] is the whole phrase; [otherKey] carries `{n}`.
String plural(BuildContext c, int n, String oneKey, String otherKey) =>
    n == 1 ? c.t(oneKey) : c.t(otherKey, {'n': '$n'});

String sizeLabel(BuildContext c, int bytes) {
  if (bytes >= 1024 * 1024) {
    return c.t('settings.backup.sizeMegabytes', {
      'n': (bytes / (1024 * 1024)).toStringAsFixed(1),
    });
  }
  if (bytes >= 1024) {
    return c.t('settings.backup.sizeKilobytes', {
      'n': '${(bytes / 1024).round()}',
    });
  }
  return c.t('settings.backup.sizeBytes', {'n': '$bytes'});
}

/// A day someone can recognise. Today and yesterday are named rather than
/// dated, because those are the two a person is most likely to be looking for
/// and a date makes them do arithmetic.
///
/// The month names come from ONE comma-separated key rather than twelve. A
/// translator fills a row of twelve abbreviations into a single field, in
/// order, which is how they think about months anyway; the alternative is
/// twelve keys that have to be found and kept in step individually.
String dayLabel(BuildContext c, DateTime t) {
  final now = DateTime.now();
  final day = DateTime(t.year, t.month, t.day);
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(day).inDays;

  final clock = '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';

  if (diff == 0) return c.t('settings.backup.dayToday', {'clock': clock});
  if (diff == 1) return c.t('settings.backup.dayYesterday', {'clock': clock});

  final months = c.t('settings.backup.monthsShort').split(',');
  // Falls back to the number when a translation has the wrong count, rather
  // than throwing a range error inside a list row. A backup dated "9" is poor;
  // a red box where the date should be is worse.
  final month = months.length == 12 ? months[t.month - 1].trim() : '${t.month}';

  if (t.year == now.year) {
    return c.t('settings.backup.dayThisYear', {
      'day': '${t.day}',
      'month': month,
    });
  }
  return c.t('settings.backup.dayOtherYear', {
    'day': '${t.day}',
    'month': month,
    'year': '${t.year}',
  });
}

/// How long ago, for the one line that answers "am I covered".
String agoLabel(BuildContext c, DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return c.t('settings.backup.agoJustNow');
  if (d.inMinutes < 60) {
    return plural(c, d.inMinutes, 'settings.backup.agoMinuteOne',
        'settings.backup.agoMinuteOther');
  }
  if (d.inHours < 24) {
    return plural(c, d.inHours, 'settings.backup.agoHourOne',
        'settings.backup.agoHourOther');
  }
  if (d.inDays == 1) return c.t('settings.backup.agoYesterday');
  if (d.inDays < 30) {
    return plural(c, d.inDays, 'settings.backup.agoDayOne',
        'settings.backup.agoDayOther');
  }
  return c.t('settings.backup.agoOn', {'day': dayLabel(c, t)});
}
