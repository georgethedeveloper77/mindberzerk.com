/// Display formatting.
///
/// Byte sizes use base 1000, not 1024, because that is what Android Settings
/// shows. A user comparing our number against Settings must see the same
/// number, and that matters more than matching a textbook.
///
/// Every *OrNull variant returns null for absent data so the caller can drop
/// the row entirely. Never render a placeholder string for a missing stat.
class GFormat {
  const GFormat._();

  static const List<String> _units = <String>['kB', 'MB', 'GB', 'TB', 'PB'];

  static String bytes(int value, {int decimals = 1}) {
    if (value <= 0) return '0 B';
    if (value < 1000) return '$value B';

    double scaled = value / 1000;
    int unit = 0;
    while (scaled >= 1000 && unit < _units.length - 1) {
      scaled /= 1000;
      unit++;
    }
    final String text = scaled >= 100
        ? scaled.toStringAsFixed(0)
        : scaled.toStringAsFixed(decimals);
    return '$text ${_units[unit]}';
  }

  static String? bytesOrNull(int? value, {int decimals = 1}) =>
      value == null ? null : bytes(value, decimals: decimals);

  /// 1204 becomes 1,204.
  static String count(int value) {
    final String digits = value.abs().toString();
    final StringBuffer out = StringBuffer(value < 0 ? '-' : '');
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
      out.write(digits[i]);
    }
    return out.toString();
  }

  static String? countOrNull(int? value) => value == null ? null : count(value);

  static String percent(double fraction, {int decimals = 0}) {
    final double clamped = fraction.isNaN ? 0 : fraction.clamp(0.0, 1.0);
    return '${(clamped * 100).toStringAsFixed(decimals)}%';
  }

  static String? percentOrNull(double? fraction, {int decimals = 0}) =>
      fraction == null ? null : percent(fraction, decimals: decimals);

  static String duration(Duration value) {
    final int total = value.inSeconds;
    final int hours = total ~/ 3600;
    final int minutes = (total % 3600) ~/ 60;
    final int seconds = total % 60;
    final String mm = minutes.toString().padLeft(hours > 0 ? 2 : 1, '0');
    final String ss = seconds.toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss';
  }

  /// Deliberately not localised yet. Phase 4 routes this through assets/i18n.
  static String relativeDay(DateTime when, DateTime now) {
    final DateTime then = DateTime(when.year, when.month, when.day);
    final DateTime today = DateTime(now.year, now.month, now.day);
    final int days = today.difference(then).inDays;
    if (days <= 0) return 'Today';
    if (days == 1) return 'Yesterday';
    if (days < 7) return '$days days ago';
    if (days < 30) {
      final int weeks = days ~/ 7;
      return weeks == 1 ? '1 week ago' : '$weeks weeks ago';
    }
    return '${then.day}/${then.month}/${then.year}';
  }
}
