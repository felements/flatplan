import '../models/models.dart';
import 'payment_tags.dart';
import 'period_extensions.dart';

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

/// What a [StatsLine] measures.
enum StatsLineRole {
  /// Everything spent: the expense half of the All subject.
  spent,

  /// Everything earned: the income half of the All subject.
  earned,

  /// The subject's own figure: a category's facts or a tag's spending.
  value,
}

/// One line on the chart: a figure per chart period.
class StatsLine {
  const StatsLine({
    required this.subject,
    required this.role,
    required this.values,
    this.limits,
  });

  final StatsSubject subject;
  final StatsLineRole role;

  /// One entry per chart period; `null` is a gap, a period without the
  /// subject.
  final List<double?> values;

  /// The budget limit per chart period, drawn beside the line. Only category
  /// lines have it; an entry is `null` where the period has no limit.
  final List<double?>? limits;

  /// What the legend and the tooltip call the line.
  String get label => switch (role) {
    StatsLineRole.spent => 'Spent',
    StatsLineRole.earned => 'Earned',
    StatsLineRole.value => subject.label,
  };
}

/// Everything the Stats chart draws.
class StatsChart {
  const StatsChart({
    required this.periods,
    required this.lines,
    this.inProgressIndex,
  });

  /// The periods along the x axis, oldest first.
  final List<Period> periods;
  final List<StatsLine> lines;

  /// The index in [periods] of the one that covers today, if any.
  final int? inProgressIndex;

  /// True when no line has anything to draw: every value is a gap or zero.
  bool get isEmpty => lines.every(
    (line) => line.values.every((value) => value == null || value == 0),
  );
}

/// One line's figures at a single chart period, as the tooltip lists them.
class StatsTooltipRow {
  const StatsTooltipRow({required this.line, required this.value, this.limit});

  final StatsLine line;
  final double value;
  final double? limit;
}

/// The chart for [subjects] over the periods of [allPeriods] that
/// [chartPeriods] keeps for [today] and [range].
///
/// [StatsSubject.all] becomes two lines, spent then earned; every other
/// subject is one line, and lines follow the order of [subjects]. A period
/// ends where the next one in [allPeriods] begins, charted or not, so a
/// [range] cannot change which period is in progress.
StatsChart buildStatsChart({
  required List<Period> allPeriods,
  required List<StatsSubject> subjects,
  required DateTime today,
  MonthRange? range,
}) {
  final periods = chartPeriods(allPeriods, today: today, range: range);
  return StatsChart(
    periods: periods,
    lines: [for (final subject in subjects) ..._linesFor(subject, periods)],
    inProgressIndex: _inProgressIndex(periods, allPeriods, today),
  );
}

/// What the tooltip shows at [index]: a row for each line of [chart] that
/// has a value there, in line order.
List<StatsTooltipRow> tooltipRows(StatsChart chart, int index) => [
  for (final line in chart.lines)
    if (line.values[index] case final value?)
      StatsTooltipRow(line: line, value: value, limit: line.limits?[index]),
];

List<StatsLine> _linesFor(StatsSubject subject, List<Period> periods) {
  switch (subject.kind) {
    case StatsSubjectKind.all:
      return [
        StatsLine(
          subject: subject,
          role: StatsLineRole.spent,
          values: [for (final p in periods) _factsTotal(p, income: false)],
        ),
        StatsLine(
          subject: subject,
          role: StatsLineRole.earned,
          values: [for (final p in periods) _factsTotal(p, income: true)],
        ),
      ];
    case StatsSubjectKind.expenseCategory:
    case StatsSubjectKind.incomeCategory:
      return [_categoryLine(subject, periods)];
    case StatsSubjectKind.tag:
      return [
        StatsLine(
          subject: subject,
          role: StatsLineRole.value,
          values: [for (final p in periods) spendingByTag(p)[subject.key] ?? 0],
        ),
      ];
  }
}

StatsLine _categoryLine(StatsSubject subject, List<Period> periods) {
  final income = subject.kind == StatsSubjectKind.incomeCategory;
  final values = <double?>[];
  final limits = <double?>[];
  for (final period in periods) {
    final matching = [
      for (final category in period.categories)
        if ((category.type == CategoryType.income) == income &&
            categoryKey(category.name) == subject.key)
          category,
    ];
    if (matching.isEmpty) {
      values.add(null);
      limits.add(null);
      continue;
    }
    values.add(matching.fold<double>(0, (sum, c) => sum + _facts(c)));
    final limit = matching.fold<double>(0, (sum, c) => sum + c.effectiveLimit);
    limits.add(limit == 0 ? null : limit);
  }
  return StatsLine(
    subject: subject,
    role: StatsLineRole.value,
    values: values,
    limits: limits,
  );
}

/// Facts recorded in [period]'s income categories, or in its expense ones.
double _factsTotal(Period period, {required bool income}) => period.categories
    .where((c) => (c.type == CategoryType.income) == income)
    .fold<double>(0, (sum, c) => sum + _facts(c));

double _facts(Category category) =>
    category.factExpenses.fold<double>(0, (sum, f) => sum + f.amount);

/// The index in [periods] of the period whose days include [today].
int? _inProgressIndex(
  List<Period> periods,
  List<Period> allPeriods,
  DateTime today,
) {
  final day = DateTime(today.year, today.month, today.day);
  for (var i = 0; i < periods.length; i++) {
    final end = effectiveEndDate(periods[i], allPeriods);
    if (!_startDay(periods[i]).isAfter(day) &&
        !day.isAfter(DateTime(end.year, end.month, end.day))) {
      return i;
    }
  }
  return null;
}

DateTime _startDay(Period period) {
  final start = period.startDate;
  return DateTime(start.year, start.month, start.day);
}

DateTime _startMonth(Period period) =>
    DateTime(period.startDate.year, period.startDate.month);

bool _inRange(DateTime month, MonthRange range) =>
    !month.isBefore(range.from) && !month.isAfter(range.to);
