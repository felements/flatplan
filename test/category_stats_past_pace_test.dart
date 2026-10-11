import 'package:flutter_test/flutter_test.dart';
import 'package:flatplan/src/logic/period_stats.dart';
import 'package:flatplan/src/models/models.dart';

FactExpense _fact(String id, double amount, int day) =>
    FactExpense(id: id, amount: amount, timestamp: DateTime(2026, 3, day, 12));

/// March 1st to March 30th inclusive: 30 days.
final _start = DateTime(2026, 3, 1);
final _end = DateTime(2026, 3, 30);

Category _groceries({double limit = 1200, bool isDailyAllowance = true}) =>
    Category(
      id: 'groceries',
      name: 'Groceries',
      type: CategoryType.optionalExpense,
      limit: limit,
      isDailyAllowance: isDailyAllowance,
      factExpenses: [_fact('f1', 600, 5), _fact('f2', 450, 20)],
    );

CategoryStats _statsAt(DateTime now, {Category? category}) {
  final cat = category ?? _groceries();
  final period = Period(
    id: 'march',
    name: 'March',
    startDate: _start,
    baseCurrency: 'EUR',
    lastModified: _start,
    categories: [cat],
  );
  return categoryStatsFor(
    category: cat,
    period: period,
    endDate: _end,
    allPeriods: [period],
    now: now,
  );
}

void main() {
  test('a finished period reports how it was spent per day', () {
    final stats = _statsAt(DateTime(2026, 3, 31, 9));

    // 1,050 over 30 days, against 1,200 over 30 days.
    expect(stats.averageDailySpent, 35);
    expect(stats.plannedDailyPace, 40);
    // Nothing is left to spend per day once the period is over.
    expect(stats.dailyAllowanceAmount, isNull);
  });

  test('a finished period spent faster than planned is over pace', () {
    // 1,050 over 30 days is 35 a day, against 900's 30.
    final over = _statsAt(
      DateTime(2026, 4, 2),
      category: _groceries(limit: 900),
    );
    final under = _statsAt(DateTime(2026, 4, 2));

    expect(over.isOverPace, isTrue);
    expect(under.isOverPace, isFalse);
  });

  test('without a plan there is no pace to be over', () {
    final stats = _statsAt(
      DateTime(2026, 4, 2),
      category: _groceries(limit: 0),
    );

    expect(stats.isOverPace, isFalse);
  });

  test('the last day of a period still counts as live', () {
    final stats = _statsAt(DateTime(2026, 3, 30, 18));

    expect(stats.dailyAllowanceAmount, 150);
    expect(stats.averageDailySpent, isNull);
    expect(stats.plannedDailyPace, isNull);
  });

  test('a live period keeps the daily allowance and no past pace', () {
    final stats = _statsAt(DateTime(2026, 3, 25, 9));

    // 150 left over the 5 days wholeDaysBetween counts to March 30th.
    expect(stats.dailyAllowanceAmount, 30);
    expect(stats.averageDailySpent, isNull);
    expect(stats.plannedDailyPace, isNull);
  });

  test('a finished category without a daily allowance gets no pace', () {
    final stats = _statsAt(
      DateTime(2026, 4, 2),
      category: _groceries(isDailyAllowance: false),
    );

    expect(stats.averageDailySpent, isNull);
    expect(stats.plannedDailyPace, isNull);
  });

  test('a finished category with no budget has an average but no plan', () {
    final stats = _statsAt(
      DateTime(2026, 4, 2),
      category: _groceries(limit: 0),
    );

    expect(stats.averageDailySpent, 35);
    expect(stats.plannedDailyPace, isNull);
  });
}
