import 'package:flutter_test/flutter_test.dart';
import 'package:flatplan/src/logic/basket_insight.dart';
import 'package:flatplan/src/models/models.dart';

const _stats = BasketStats(
  snackShare: 0.30,
  tripSpacingDays: 2,
  usualBasket: 600,
  periodsUsed: 3,
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

  test('returns null when isDailyAllowance is false', () {
    final category = Category(
      id: 'test-id',
      name: 'test-category',
      type: CategoryType.optionalExpense,
      isDailyAllowance: false, // explicitly false
      bigPurchaseThreshold: 500,
      limit: 10000,
    );

    final period = Period(
      id: 'period-id',
      name: 'Test Period',
      startDate: DateTime(2025, 1, 1),
      baseCurrency: 'EUR',
      lastModified: DateTime(2025, 1, 1),
    );

    final advice = basketAdviceFor(
      category: category,
      period: period,
      endDate: DateTime(2025, 1, 31),
      allPeriods: [period],
      now: DateTime(2025, 1, 15),
    );

    expect(advice, isNull);
  });
}
