import 'package:flutter_test/flutter_test.dart';
import 'package:flatplan/src/logic/basket_insight.dart';
import 'package:flatplan/src/models/models.dart';

const _stats = BasketStats(
  snackShare: 0.30,
  tripSpacingDays: 2,
  usualBasket: 600,
  periodsUsed: 3,
);

FactExpense _fact(double amount) =>
    FactExpense(id: 'f$amount', amount: amount, timestamp: DateTime(2026, 1, 1));

Period _period({
  required String id,
  required DateTime startDate,
  required List<double> amounts,
}) =>
    Period(
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
          bigPurchaseThreshold: 500,
          factExpenses: amounts.map(_fact).toList(),
        ),
      ],
    );

void main() {
  test('reserves the snack share against the limit, then splits the rest', () {
    final advice = basketAdviceFrom(
      stats: _stats,
      limit: 10000,
      remaining: 8000,
      smallSpentThisPeriod: 500,
      daysLeft: 20,
    );

    // 0.30 * 10000 - 500 already spent on small items
    expect(advice!.snackReserve, 2500);
    expect(advice.basketBudget, 5500);
    expect(advice.tripsLeft, 10);
    expect(advice.safeBasket, 550);
  });

  test('floors the reserve at zero once small spending exhausts its share', () {
    final advice = basketAdviceFrom(
      stats: _stats,
      limit: 10000,
      remaining: 5000,
      smallSpentThisPeriod: 4000, // beyond the 3000 expected
      daysLeft: 20,
    );

    expect(advice!.snackReserve, 0);
    // the whole remainder is available, nothing is handed back
    expect(advice.basketBudget, 5000);
    expect(advice.safeBasket, 500);
  });

  test('returns null when nothing is left for baskets', () {
    expect(
      basketAdviceFrom(
        stats: _stats,
        limit: 10000,
        remaining: 2000, // below the 3000 reserve
        smallSpentThisPeriod: 0,
        daysLeft: 20,
      ),
      isNull,
    );
  });

  test('returns null once the period has ended', () {
    expect(
      basketAdviceFrom(
        stats: _stats,
        limit: 10000,
        remaining: 8000,
        smallSpentThisPeriod: 500,
        daysLeft: 0,
      ),
      isNull,
    );
  });

  test('never advises more than the budget that is actually left', () {
    final advice = basketAdviceFrom(
      stats: _stats,
      limit: 10000,
      remaining: 4000,
      smallSpentThisPeriod: 3000, // reserve already exhausted -> 0
      daysLeft: 1, // half a trip at a 2-day cadence
    );

    expect(advice!.tripsLeft, 1);
    expect(advice.safeBasket, 4000);
    expect(advice.safeBasket, lessThanOrEqualTo(advice.basketBudget));
  });

  test('isDailyAllowance guard: returns null when false and history sufficient', () {
    // Create two prior periods with basket-sized and small purchases
    final sliceA = _period(
      id: 'a',
      startDate: DateTime(2026, 1, 1),
      amounts: [100, 100, 1000, 1000],
    );
    final sliceB = _period(
      id: 'b',
      startDate: DateTime(2026, 1, 11),
      amounts: [100, 200, 300, 600, 1400],
    );

    // Current period with isDailyAllowance: false
    final current = Period(
      id: 'current',
      name: 'current',
      startDate: DateTime(2026, 1, 23),
      baseCurrency: 'EUR',
      lastModified: DateTime(2026, 1, 23),
      categories: [
        Category(
          id: 'cat-current',
          name: 'Groceries',
          limit: 10000,
          isDailyAllowance: false, // This is the guard being tested
          bigPurchaseThreshold: 500,
        ),
      ],
    );

    final all = [sliceA, sliceB, current];

    // Should return null because isDailyAllowance is false
    final adviceFalse = basketAdviceFor(
      category: current.categories.first,
      period: current,
      endDate: DateTime(2026, 2, 1),
      allPeriods: all,
      now: DateTime(2026, 1, 25),
    );

    expect(adviceFalse, isNull);

    // Verify that the same fixture with isDailyAllowance: true yields non-null
    // (proving the test exercises the guard, not just a missing history issue)
    final currentWithAllowance = current.categories.first.copyWith(
      isDailyAllowance: true,
    );

    final adviceTrue = basketAdviceFor(
      category: currentWithAllowance,
      period: current,
      endDate: DateTime(2026, 2, 1),
      allPeriods: all,
      now: DateTime(2026, 1, 25),
    );

    expect(adviceTrue, isNotNull);
  });
}
