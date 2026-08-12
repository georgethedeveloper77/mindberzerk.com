/// One day's worth of findings.
///
/// The header carries a count and a total, not just a date. Samsung's gallery
/// shows only the date, which looks tidy and tells you nothing: the reason to
/// scroll a grouped list is to find the day worth acting on, and that is a
/// question about size.
class DateGroup<T> {
  const DateGroup({
    required this.label,
    required this.items,
    required this.bytes,
    required this.dated,
  });

  final String label;
  final List<T> items;
  final int bytes;

  /// False for the catch-all group. Callers style it differently and it always
  /// sorts last, whatever its size.
  final bool dated;

  int get count => items.length;
}

/// Groups by the day a thing was deleted, newest first.
///
/// ─── WHY NOT FALL BACK TO dateAddedMillis ────────────────────────────────────
///
/// Because it answers a different question. A thumbnail cache entry and most
/// files sitting in an app's trash folder have no recorded deletion date, only
/// the moment the file was written. Filing a photo taken in March under "deleted
/// in March" would be a quiet lie in a screen whose entire job is being straight
/// about what is knowable. Undated items get their own group, pinned last, and
/// the header says so once instead of stamping it on all three hundred.
///
/// [prefix] lets recovery read "Deleted today" while storage reads "Today" from
/// the same function.
/// GENERIC over the item, and it has to be.
///
/// Recovery groups by the day a file was deleted. Storage has no deletion date
/// at all and groups by the day a file was last written. Same shape, same
/// headers, two different questions, so the caller supplies both accessors and
/// this stays the one place the grouping rules live.
List<DateGroup<T>> groupByDate<T>(
  List<T> items, {
  required int? Function(T) dateOf,
  required int Function(T) sizeOf,
  String prefix = '',
  DateTime? now,
}) {
  final DateTime today = _midnight(now ?? DateTime.now());
  final Map<int, List<T>> dated = <int, List<T>>{};
  final List<T> undated = <T>[];

  for (final T item in items) {
    final int? millis = dateOf(item);
    if (millis == null || millis <= 0) {
      undated.add(item);
      continue;
    }
    final DateTime day = _midnight(DateTime.fromMillisecondsSinceEpoch(millis));
    dated.putIfAbsent(day.millisecondsSinceEpoch, () => <T>[]).add(item);
  }

  final List<int> days = dated.keys.toList()..sort((int a, int b) => b - a);

  final List<DateGroup<T>> groups = <DateGroup<T>>[
    for (final int day in days)
      DateGroup<T>(
        label: _label(DateTime.fromMillisecondsSinceEpoch(day), today, prefix),
        items: dated[day]!
          ..sort((T a, T b) => (dateOf(b) ?? 0).compareTo(dateOf(a) ?? 0)),
        bytes: _sum(dated[day]!, sizeOf),
        dated: true,
      ),
  ];

  if (undated.isNotEmpty) {
    groups.add(
      DateGroup<T>(
        label: 'Date unknown',
        items: undated,
        bytes: _sum(undated, sizeOf),
        dated: false,
      ),
    );
  }

  return groups;
}

int _sum<T>(List<T> items, int Function(T) sizeOf) =>
    items.fold<int>(0, (int total, T item) => total + sizeOf(item));

DateTime _midnight(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// Today and Yesterday by name, everything else by date.
///
/// Written by hand rather than through intl. The app carries no localisation
/// yet, adding a package for two words would be premature, and when the i18n
/// sweep comes this is one function to replace rather than a formatter threaded
/// through every call site.
String _label(DateTime day, DateTime today, String prefix) {
  final int distance = today.difference(day).inDays;
  final String core;
  if (distance == 0) {
    core = 'today';
  } else if (distance == 1) {
    core = 'yesterday';
  } else if (day.year == today.year) {
    core = '${day.day} ${_months[day.month - 1]}';
  } else {
    core = '${day.day} ${_months[day.month - 1]} ${day.year}';
  }

  if (prefix.isEmpty) {
    return core[0].toUpperCase() + core.substring(1);
  }
  return '$prefix $core';
}

const List<String> _months = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// Reorders day groups by the largest thing in each.
///
/// Used when the sort is by size. The groups keep their day labels, so a header
/// still says what it says, but the day holding the biggest file is at the top
/// rather than the most recent one.
///
/// The undated group stays last regardless, for the same reason it always does:
/// "Date unknown" is a footnote, not a finding.
List<DateGroup<T>> rankGroupsBySize<T>(
  List<DateGroup<T>> groups, {
  bool smallestFirst = false,
}) {
  final List<DateGroup<T>> dated =
      groups.where((DateGroup<T> g) => g.dated).toList()..sort(
        (DateGroup<T> a, DateGroup<T> b) => smallestFirst
            ? a.bytes.compareTo(b.bytes)
            : b.bytes.compareTo(a.bytes),
      );

  return <DateGroup<T>>[
    ...dated,
    ...groups.where((DateGroup<T> g) => !g.dated),
  ];
}
