import 'package:flutter_test/flutter_test.dart';
import 'package:flatplan/src/logic/basket_insight.dart';
import 'package:flatplan/src/models/models.dart';

FactExpense _fact(double amount) => FactExpense(
  id: 'f$amount',
  amount: amount,
  timestamp: DateTime(2026, 1, 1),
);

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
      basketStatsFor(category: noThreshold, period: current, allPeriods: all),
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

  test('returns null when the measured cadence falls below a day', () {
    // 13 rows at or above the threshold inside a 12-day period
    // (2026-01-11 .. 2026-01-22): 12 / 13 = 0.92 days between "trips".
    // The count is receipt lines, not shopping trips, so a sub-daily
    // spacing means the threshold is too low to separate the two — the
    // advice would degenerate into a per-shop figure below a day's
    // allowance, which is what the insight exists to avoid.
    final dense = _period(
      id: 'c',
      startDate: DateTime(2026, 1, 11),
      amounts: [100, ...List<double>.filled(13, 600)],
    );

    expect(
      basketStatsFor(
        category: current.categories.first,
        period: current,
        allPeriods: [sliceA, dense, current],
      ),
      isNull,
    );
  });

  test('draws on no more than basketHistoryPeriods complete periods', () {
    // Four complete prior periods, each 10 days with two baskets. Only the
    // most recent three may feed the statistics.
    final older = [
      for (var i = 0; i < 4; i++)
        _period(
          id: 'w$i',
          startDate: DateTime(2026, 1, 1).add(Duration(days: i * 10)),
          amounts: const [100, 1000, 1000],
        ),
    ];
    final latest = Period(
      id: 'window-current',
      name: 'window-current',
      startDate: DateTime(2026, 2, 10),
      baseCurrency: 'EUR',
      lastModified: DateTime(2026, 2, 10),
      categories: [
        const Category(
          id: 'cat-window-current',
          name: 'Groceries',
          limit: 10000,
          isDailyAllowance: true,
          bigPurchaseThreshold: 500,
        ),
      ],
    );

    final stats = basketStatsFor(
      category: latest.categories.first,
      period: latest,
      allPeriods: [...older, latest],
    );

    expect(basketHistoryPeriods, 3);
    expect(stats!.periodsUsed, 3);
  });

  test('still passes over a period with nothing spent on the category', () {
    // Nothing was booked to Groceries in the period just gone. It carries
    // no share and no cadence, so the window reaches past it rather than
    // counting a period the user never lived as history.
    final idle = _period(
      id: 'idle',
      startDate: DateTime(2026, 1, 23),
      amounts: const [],
    );
    final later = Period(
      id: 'later',
      name: 'later',
      startDate: DateTime(2026, 2, 1),
      baseCurrency: 'EUR',
      lastModified: DateTime(2026, 2, 1),
      categories: [
        const Category(
          id: 'cat-later',
          name: 'Groceries',
          limit: 10000,
          isDailyAllowance: true,
          bigPurchaseThreshold: 500,
        ),
      ],
    );

    final stats = basketStatsFor(
      category: later.categories.first,
      period: later,
      allPeriods: [sliceA, sliceB, idle, later],
    );

    expect(stats!.periodsUsed, 2);
    expect(stats.snackShare, closeTo(600 / 2600, 0.0001));
    expect(stats.tripSpacingDays, 5);
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
