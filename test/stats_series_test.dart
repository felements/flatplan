import 'package:flutter_test/flutter_test.dart';
import 'package:flatplan/src/logic/stats_series.dart';
import 'package:flatplan/src/models/models.dart';

import 'support/stats_fixtures.dart';

void main() {
  final today = DateTime(2026, 11, 10);

  List<Period> sepOctNovDec() => [
    period('oct', DateTime(2026, 10, 5), []),
    period('sep', DateTime(2026, 9, 5), []),
    period('nov', DateTime(2026, 11, 5), []),
    period('dec', DateTime(2026, 11, 11), []),
  ];

  group('chartPeriods', () {
    test('sorts by start date and drops periods starting after today', () {
      expect(chartPeriods(sepOctNovDec(), today: today).map((p) => p.id), [
        'sep',
        'oct',
        'nov',
      ]);
      expect(
        chartPeriods([
          period('t', DateTime(2026, 11, 10), []),
        ], today: today).map((p) => p.id),
        ['t'],
      );
    });

    test('compares calendar days, not the time of day', () {
      final late = period('late', DateTime(2026, 11, 10, 23, 59), []);
      final noon = DateTime(2026, 11, 10, 12);
      expect(chartPeriods([late], today: noon).map((p) => p.id), ['late']);
    });

    test('keeps periods whose start month is in the range, both ends '
        'included', () {
      final ps = sepOctNovDec();
      expect(
        chartPeriods(
          ps,
          today: today,
          range: MonthRange(DateTime(2026, 10), DateTime(2026, 11)),
        ).map((p) => p.id),
        ['oct', 'nov'],
      );
      expect(
        chartPeriods(
          ps,
          today: today,
          range: MonthRange(DateTime(2026, 12), DateTime(2026, 12)),
        ),
        isEmpty,
      );
    });

    test('a month range is stored as the first instant of each month', () {
      final range = MonthRange(
        DateTime(2026, 10, 17, 9),
        DateTime(2026, 11, 3),
      );
      expect(range.from, DateTime(2026, 10));
      expect(range.to, DateTime(2026, 11));
    });
  });

  test('availableMonths lists each start month once, oldest first, without '
      'future periods', () {
    final ps = [
      period('oct', DateTime(2026, 10, 5), []),
      period('sep2', DateTime(2026, 9, 25), []),
      period('sep', DateTime(2026, 9, 5), []),
      period('dec', DateTime(2026, 12, 1), []),
    ];
    expect(availableMonths(ps, today: today), [
      DateTime(2026, 9),
      DateTime(2026, 10),
    ]);
  });

  test('a category subject is keyed by trimmed lower-case name within its '
      'kind', () {
    expect(
      StatsSubject.category(' Groceries ', income: false),
      StatsSubject.category('groceries', income: false),
    );
    expect(
      StatsSubject.category(' Groceries ', income: false).hashCode,
      StatsSubject.category('groceries', income: false).hashCode,
    );
    expect(
      StatsSubject.category('Other', income: false),
      isNot(StatsSubject.category('Other', income: true)),
    );
    expect(
      StatsSubject.category(' Groceries ', income: false).label,
      'Groceries',
    );
  });

  test('only the category subjects have a limit', () {
    expect(StatsSubject.all.hasLimit, isFalse);
    expect(StatsSubject.tag('renovation').hasLimit, isFalse);
    expect(StatsSubject.category('Home', income: false).hasLimit, isTrue);
    expect(StatsSubject.category('Salary', income: true).hasLimit, isTrue);
  });

  test('All and a tag are keyed as the brief says', () {
    expect(StatsSubject.all.label, 'All');
    expect(StatsSubject.all.key, '');
    final tag = StatsSubject.tag('renovation');
    expect(tag.kind, StatsSubjectKind.tag);
    expect(tag.key, 'renovation');
    expect(tag.label, 'renovation');
  });

  test('subjectCatalog groups subjects, names them as in the latest period '
      'and sorts them', () {
    final ps = [
      period('nov', DateTime(2026, 11, 5), [
        category('Groceries'),
        category('home'),
        category('Other'),
        category('Other', type: CategoryType.income),
      ]),
      period('oct', DateTime(2026, 10, 5), [
        category('groceries'),
        category(
          'home',
          type: CategoryType.mandatoryExpense,
          facts: [(900, 'tiles #Renovation')],
        ),
        category(
          'Salary',
          type: CategoryType.income,
          facts: [(5200, '#bonus')],
        ),
      ]),
    ];
    final c = subjectCatalog(ps);
    expect(c.expenses.map((s) => s.label), ['Groceries', 'home', 'Other']);
    expect(c.income.map((s) => s.label), ['Other', 'Salary']);
    expect(c.tags.map((s) => s.label), ['renovation']);
    expect(c.expenses.map((s) => s.kind).toSet(), {
      StatsSubjectKind.expenseCategory,
    });
    expect(c.income.map((s) => s.kind).toSet(), {
      StatsSubjectKind.incomeCategory,
    });
    expect(c.tags.map((s) => s.kind).toSet(), {StatsSubjectKind.tag});
  });

  test('subjectCatalog names a subject as in the newest period, whatever the '
      'list order', () {
    final older = period('oct', DateTime(2026, 10, 5), [category('groceries')]);
    final newer = period('nov', DateTime(2026, 11, 5), [category('Groceries')]);
    expect(subjectCatalog([older, newer]).expenses.single.label, 'Groceries');
    expect(subjectCatalog([newer, older]).expenses.single.label, 'Groceries');
  });

  test('subjectCatalog of no periods is empty', () {
    final c = subjectCatalog(const []);
    expect(c.expenses, isEmpty);
    expect(c.income, isEmpty);
    expect(c.tags, isEmpty);
  });

  test('toggleSubject keeps All exclusive and never leaves nothing ticked', () {
    final g = StatsSubject.category('Groceries', income: false);
    final t = StatsSubject.tag('renovation');
    expect(toggleSubject([StatsSubject.all], g), [g]);
    expect(toggleSubject([g], t), [g, t]);
    expect(toggleSubject([g, t], g), [t]);
    expect(toggleSubject([t], t), [StatsSubject.all]);
    expect(toggleSubject([g, t], StatsSubject.all), [StatsSubject.all]);
    expect(toggleSubject([StatsSubject.all], StatsSubject.all), [
      StatsSubject.all,
    ]);
  });
}
