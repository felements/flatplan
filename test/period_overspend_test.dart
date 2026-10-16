import 'package:flutter_test/flutter_test.dart';
import 'package:flatplan/src/logic/period_stats.dart';
import 'package:flatplan/src/models/models.dart';

FactExpense _fact(String id, double amount) =>
    FactExpense(id: id, amount: amount, timestamp: DateTime(2026, 3, 5));

Period _period(List<Category> categories) => Period(
  id: 'march',
  name: 'March',
  startDate: DateTime(2026, 3, 1),
  baseCurrency: 'EUR',
  lastModified: DateTime(2026, 3, 1),
  categories: categories,
);

PeriodStats _statsFor(List<Category> categories) {
  final period = _period(categories);
  return periodStatsFor(
    period: period,
    allPeriods: [period],
    now: DateTime(2026, 3, 10),
  );
}

void main() {
  test('sums only the excess of each expense category over its limit', () {
    final stats = _statsFor([
      // 50 over.
      Category(
        id: 'fun',
        name: 'Fun',
        type: CategoryType.optionalExpense,
        limit: 100,
        factExpenses: [_fact('f1', 150)],
      ),
      // 150 under: must not offset the overshoot elsewhere.
      Category(
        id: 'groceries',
        name: 'Groceries',
        type: CategoryType.optionalExpense,
        limit: 200,
        factExpenses: [_fact('g1', 50)],
      ),
      // 20 over.
      Category(
        id: 'rent',
        name: 'Rent',
        type: CategoryType.mandatoryExpense,
        limit: 300,
        factExpenses: [_fact('r1', 320)],
      ),
      // Income above plan is not overspending.
      Category(
        id: 'salary',
        name: 'Salary',
        type: CategoryType.income,
        limit: 1000,
        factExpenses: [_fact('s1', 1200)],
      ),
    ]);

    expect(stats.totalOverspent, 70);
    expect(stats.overBudgetCount, 2);
  });

  test('is zero when every category stays within its limit', () {
    final stats = _statsFor([
      Category(
        id: 'fun',
        name: 'Fun',
        type: CategoryType.optionalExpense,
        limit: 100,
        factExpenses: [_fact('f1', 100)],
      ),
      Category(
        id: 'rent',
        name: 'Rent',
        type: CategoryType.mandatoryExpense,
        limit: 300,
        factExpenses: [_fact('r1', 120)],
      ),
    ]);

    expect(stats.totalOverspent, 0);
    expect(stats.overBudgetCount, 0);
  });
}
