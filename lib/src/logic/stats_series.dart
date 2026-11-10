import '../models/models.dart';
import 'payment_tags.dart';

/// What a chart line is about.
enum StatsSubjectKind { all, expenseCategory, incomeCategory, tag }

/// The key a category is matched by across periods: the trimmed, lower-case
/// name. Ids cannot link a category across periods because rollover
/// regenerates them.
String categoryKey(String name) => name.trim().toLowerCase();

/// One thing the Stats page can graph: everything, a category or a tag.
///
/// Two subjects are the same when their [kind] and [key] match; the [label]
/// only decides what the user reads, so a renamed capitalisation does not
/// split a category in two.
class StatsSubject {
  const StatsSubject._({
    required this.kind,
    required this.key,
    required this.label,
  });

  /// The whole period: everything spent and everything earned.
  static const all = StatsSubject._(
    kind: StatsSubjectKind.all,
    key: '',
    label: 'All',
  );

  /// The category called [name], matched ignoring case and surrounding
  /// spaces. Income and expense categories sharing a name are different
  /// subjects.
  factory StatsSubject.category(String name, {required bool income}) =>
      StatsSubject._(
        kind: income
            ? StatsSubjectKind.incomeCategory
            : StatsSubjectKind.expenseCategory,
        key: categoryKey(name),
        label: name.trim(),
      );

  /// The lowercased [tag] as [splitTags] produces it.
  factory StatsSubject.tag(String tag) =>
      StatsSubject._(kind: StatsSubjectKind.tag, key: tag, label: tag);

  final StatsSubjectKind kind;

  /// What identifies the subject within its [kind].
  final String key;

  /// The name to show, spelled as the newest period spells it.
  final String label;

  /// Whether the subject has a budget limit to draw: true for categories.
  bool get hasLimit =>
      kind == StatsSubjectKind.expenseCategory ||
      kind == StatsSubjectKind.incomeCategory;

  @override
  bool operator ==(Object other) =>
      other is StatsSubject && other.kind == kind && other.key == key;

  @override
  int get hashCode => Object.hash(kind, key);
}

/// Every subject the user can pick, by group, each sorted by label.
class SubjectCatalog {
  const SubjectCatalog({
    required this.expenses,
    required this.income,
    required this.tags,
  });

  final List<StatsSubject> expenses;
  final List<StatsSubject> income;
  final List<StatsSubject> tags;
}

/// The subjects found in [periods].
///
/// Periods are walked newest first, so a category is named as in the latest
/// period that has it. Tags come from expense categories only, as in
/// [spendingByTag].
SubjectCatalog subjectCatalog(List<Period> periods) {
  final newestFirst = [...periods]
    ..sort((a, b) => b.startDate.compareTo(a.startDate));

  final expenses = <StatsSubject>{};
  final income = <StatsSubject>{};
  final tags = <StatsSubject>{};
  for (final period in newestFirst) {
    for (final category in period.categories) {
      final isIncome = category.type == CategoryType.income;
      // A set keeps the first element added, so the newest spelling wins.
      (isIncome ? income : expenses).add(
        StatsSubject.category(category.name, income: isIncome),
      );
    }
    for (final tag in spendingByTag(period).keys) {
      tags.add(StatsSubject.tag(tag));
    }
  }

  List<StatsSubject> sorted(Set<StatsSubject> subjects) => subjects.toList()
    ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
  return SubjectCatalog(
    expenses: sorted(expenses),
    income: sorted(income),
    tags: sorted(tags),
  );
}

/// A span of calendar months, both ends included.
class MonthRange {
  /// Keeps only the year and month of [from] and [to].
  MonthRange(DateTime from, DateTime to)
    : from = DateTime(from.year, from.month),
      to = DateTime(to.year, to.month);

  final DateTime from;
  final DateTime to;
}

/// The periods to chart, oldest first.
///
/// Periods starting after [today] (compared by calendar day) are dropped:
/// they hold nothing yet. With a [range], only periods whose start month lies
/// in it are kept.
List<Period> chartPeriods(
  List<Period> periods, {
  required DateTime today,
  MonthRange? range,
}) {
  final day = DateTime(today.year, today.month, today.day);
  final kept = [
    for (final period in periods)
      if (!_startDay(period).isAfter(day) &&
          (range == null || _inRange(_startMonth(period), range)))
        period,
  ]..sort((a, b) => a.startDate.compareTo(b.startDate));
  return kept;
}

/// The months in which a charted period starts, each once, oldest first.
List<DateTime> availableMonths(
  List<Period> periods, {
  required DateTime today,
}) {
  final months = <DateTime>[];
  for (final period in chartPeriods(periods, today: today)) {
    final month = _startMonth(period);
    if (months.isEmpty || months.last != month) months.add(month);
  }
  return months;
}

/// The selection after the user ticks or unticks [subject] in [selected].
///
/// [StatsSubject.all] excludes every other subject: picking it clears the
/// rest, and picking anything else clears it. Unticking the last subject
/// falls back to All, so something is always shown.
List<StatsSubject> toggleSubject(
  List<StatsSubject> selected,
  StatsSubject subject,
) {
  if (subject == StatsSubject.all) return const [StatsSubject.all];
  if (selected.contains(subject)) {
    final rest = [
      for (final s in selected)
        if (s != subject) s,
    ];
    return rest.isEmpty ? const [StatsSubject.all] : rest;
  }
  return [
    for (final s in selected)
      if (s != StatsSubject.all) s,
    subject,
  ];
}

DateTime _startDay(Period period) {
  final start = period.startDate;
  return DateTime(start.year, start.month, start.day);
}

DateTime _startMonth(Period period) =>
    DateTime(period.startDate.year, period.startDate.month);

bool _inRange(DateTime month, MonthRange range) =>
    !month.isBefore(range.from) && !month.isAfter(range.to);
