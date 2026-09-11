import 'package:flutter_test/flutter_test.dart';
import 'package:flatplan/src/logic/basket_insight.dart';
import 'package:flatplan/src/models/models.dart';

FactExpense _fact(double amount) =>
    FactExpense(id: 'f$amount', amount: amount, timestamp: DateTime(2026, 1, 1));

Period _period({
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
      isDailyAllowance: true,
      factExpenses: amounts.map(_fact).toList(),
    ),
  ],
);

void main() {
  // sliceA: 10 days, small [100,100]=200 of 2200 -> 9.1%; 2 baskets -> every 5d
  final sliceA = _period(
    id: 'a',
    startDate: DateTime(2026, 1, 1),
    amounts: [100, 100, 1000, 1000],
  );
  // sliceB: 12 days, small [100,200,300]=600 of 2600 -> 23.1%; 2 baskets -> every 6d
  final sliceB = _period(
    id: 'b',
    startDate: DateTime(2026, 1, 11),
    amounts: [100, 200, 300, 600, 1400],
  );
  final current = Period(
    id: 'current',
    name: 'current',
    startDate: DateTime(2026, 1, 23),
    baseCurrency: 'EUR',
    lastModified: DateTime(2026, 1, 23),
    categories: [
      const Category(
        id: 'cat-current',
        name: 'Groceries',
        limit: 10000,
        isDailyAllowance: true,
        bigPurchaseThreshold: 500,
      ),
    ],
  );
  final all = [sliceA, sliceB, current];

  test('takes the worst of each statistic across the window', () {
    final stats = basketStatsFor(
      category: current.categories.first,
      period: current,
      allPeriods: all,
    );

    // worst (highest) snack share is sliceB's 600/2600
    expect(stats!.snackShare, closeTo(600 / 2600, 0.0001));
    // tightest (lowest) spacing is sliceA's 10 days / 2 baskets
    expect(stats.tripSpacingDays, 5);
    // median of each slice's median basket: both are 1000
    expect(stats.usualBasket, 1000);
    expect(stats.periodsUsed, 2);
  });

  test('returns null without a threshold set', () {
    final noThreshold = current.categories.first.copyWith(
      bigPurchaseThreshold: null,
    );

    expect(
      basketStatsFor(
        category: noThreshold,
        period: current,
        allPeriods: all,
      ),
      isNull,
    );
  });

  test('returns null below the minimum number of prior periods', () {
    expect(
      basketStatsFor(
        category: current.categories.first,
        period: current,
        allPeriods: [sliceA, current],
      ),
      isNull,
    );
  });

  test('returns null when a period in the window holds no basket', () {
    final snacksOnly = _period(
      id: 'c',
      startDate: DateTime(2026, 1, 11),
      amounts: [100, 200, 300],
    );

    expect(
      basketStatsFor(
        category: current.categories.first,
        period: current,
        allPeriods: [sliceA, snacksOnly, current],
      ),
      isNull,
    );
  });

  test('treats an amount exactly at the threshold as a basket', () {
    final atThreshold = _period(
      id: 'c',
      startDate: DateTime(2026, 1, 11),
      amounts: [100, 500],
    );

    final stats = basketStatsFor(
      category: current.categories.first,
      period: current,
      allPeriods: [sliceA, atThreshold, current],
    );

    // 500 counted as the sole basket, so only the 100 is small.
    expect(stats!.snackShare, closeTo(100 / 600, 0.0001));
  });

  test('suggests the mean amount rounded to the nearest 50', () {
    // sliceA + sliceB: [100,100,1000,1000,100,200,300,600,1400]
    // sum 4800 over 9 amounts = 533.33 -> 550
    expect(
      suggestedBigPurchaseThreshold(
        category: current.categories.first,
        period: current,
        allPeriods: all,
      ),
      550,
    );
  });

  test('suggests nothing without history', () {
    expect(
      suggestedBigPurchaseThreshold(
        category: current.categories.first,
        period: current,
        allPeriods: [current],
      ),
      isNull,
    );
  });
}
