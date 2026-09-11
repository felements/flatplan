import 'package:flutter_test/flutter_test.dart';
import 'package:flatplan/src/logic/period_stats.dart';
import 'package:flatplan/src/models/models.dart';

FactExpense _fact(double amount) =>
    FactExpense(id: 'f$amount', amount: amount, timestamp: DateTime(2026, 1, 1));

Period _prior({
  required String id,
  required DateTime startDate,
  required List<double> amounts,
}) => Period(
  id: id,
  name: id,
  startDate: startDate,
  baseCurrency: 'EUR',
  lastModified: startDate,
  categories: [
    Category(
      id: 'cat-$id',
      name: 'Groceries',
      limit: 10000,
      isDailyAllowance: true,
      bigPurchaseThreshold: 500,
      factExpenses: amounts.map(_fact).toList(),
    ),
  ],
);

void main() {
  final a = _prior(
    id: 'a',
    startDate: DateTime(2026, 1, 1),
    amounts: [100, 100, 1000, 1000],
  );
  final b = _prior(
    id: 'b',
    startDate: DateTime(2026, 1, 11),
    amounts: [100, 200, 300, 600, 1400],
  );
  final current = _prior(
    id: 'current',
    startDate: DateTime(2026, 1, 23),
    amounts: [200],
  );
  final all = [a, b, current];

  test('carries both insights onto CategoryStats', () {
    final stats = categoryStatsFor(
      category: current.categories.first,
      period: current,
      endDate: DateTime(2026, 2, 22),
      allPeriods: all,
      now: DateTime(2026, 1, 25),
    );

    expect(stats.trend, isNotNull);
    expect(stats.basket, isNotNull);
    expect(stats.basket!.stats.periodsUsed, 2);
  });
  test('a category without a threshold gets typical, not basket', () {
    final noThreshold = current.categories.first.copyWith(
      bigPurchaseThreshold: null,
    );

    final stats = categoryStatsFor(
      category: noThreshold,
      period: current,
      endDate: DateTime(2026, 2, 22),
      allPeriods: all,
      now: DateTime(2026, 1, 25),
    );

    expect(stats.typical, isNotNull);
    expect(stats.basket, isNull);
  });

  test('a category with a threshold gets basket, not typical', () {
    final stats = categoryStatsFor(
      category: current.categories.first,
      period: current,
      endDate: DateTime(2026, 2, 22),
      allPeriods: all,
      now: DateTime(2026, 1, 25),
    );

    expect(stats.basket, isNotNull);
    expect(stats.typical, isNull);
  });
}
