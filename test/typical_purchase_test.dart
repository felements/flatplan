import 'package:flutter_test/flutter_test.dart';
import 'package:flatplan/src/logic/typical_purchase.dart';
import 'package:flatplan/src/models/models.dart';

FactExpense _fact(double amount) => FactExpense(
  id: 'f$amount',
  amount: amount,
  timestamp: DateTime.utc(2026, 1, 1),
);

Period _period({
  required String id,
  required DateTime startDate,
  required List<double> amounts,
  double limit = 1000,
  bool isDailyAllowance = true,
  double? threshold,
}) => Period(
  id: id,
  name: id,
  startDate: startDate,
  baseCurrency: 'EUR',
  lastModified: startDate,
  categories: [
    Category(
      id: 'cat-$id',
      name: 'Dining Out',
      limit: limit,
      isDailyAllowance: isDailyAllowance,
      bigPurchaseThreshold: threshold,
      factExpenses: amounts.map(_fact).toList(),
    ),
  ],
);

void main() {
  final a = _period(
    id: 'a',
    startDate: DateTime.utc(2026, 1, 1),
    amounts: [100, 100, 300],
  );
  final b = _period(
    id: 'b',
    startDate: DateTime.utc(2026, 1, 11),
    amounts: [100, 500, 900],
  );
  final current = _period(
    id: 'current',
    startDate: DateTime.utc(2026, 1, 23),
    amounts: const [],
  );
  final all = [a, b, current];
  final endDate = DateTime.utc(2026, 2, 22);
  final now = DateTime.utc(2026, 2, 2);

  test('pairs the median purchase with how often the budget affords one', () {
    final typical = typicalPurchaseFor(
      category: current.categories.first,
      period: current,
      endDate: endDate,
      allPeriods: all,
      now: now,
    );

    // pooled [100,100,100,300,500,900] -> median (100+300)/2
    expect(typical!.amount, 200);
    expect(typical.purchasesUsed, 6);
    // 1000 left buys 5 at 200; 20 days / 5
    expect(typical.everyDays, 4);
  });
  TypicalPurchase? run(
    Period cur, {
    List<Period>? periods,
    DateTime? at,
  }) => typicalPurchaseFor(
    category: cur.categories.first,
    period: cur,
    endDate: endDate,
    allPeriods: periods ?? [a, b, cur],
    now: at ?? now,
  );

  test('stands down for a category that has a big-purchase threshold', () {
    // A threshold means the basket insight owns this category; the two
    // modes must never both produce a figure.
    final withThreshold = _period(
      id: 'current',
      startDate: DateTime.utc(2026, 1, 23),
      amounts: const [],
      threshold: 500,
    );

    expect(run(withThreshold), isNull);
  });

  test('returns null for a category without a daily allowance', () {
    final plain = _period(
      id: 'current',
      startDate: DateTime.utc(2026, 1, 23),
      amounts: const [],
      isDailyAllowance: false,
    );

    expect(run(plain), isNull);
  });

  test('returns null once the period has ended', () {
    expect(run(current, at: DateTime.utc(2026, 3, 15)), isNull);
  });

  test('returns null below three past purchases', () {
    final thin = _period(
      id: 'b',
      startDate: DateTime.utc(2026, 1, 11),
      amounts: [100, 500],
    );

    expect(run(current, periods: [thin, current]), isNull);
  });

  test('returns null when nothing is left to spend', () {
    final spent = _period(
      id: 'current',
      startDate: DateTime.utc(2026, 1, 23),
      amounts: [1000],
    );

    expect(run(spent, periods: [a, b, spent]), isNull);
  });

  test('returns null when the cadence would fall below a day', () {
    // Tiny purchases against a large budget: affordable far exceeds the days
    // remaining, so the cadence rounds to zero — the per-day figure restated.
    final tiny = _period(
      id: 'b',
      startDate: DateTime.utc(2026, 1, 11),
      amounts: [10, 10, 10],
    );

    expect(run(current, periods: [tiny, current]), isNull);
  });

  test('returns null when the cadence is sparser than half the period', () {
    final rare = _period(
      id: 'b',
      startDate: DateTime.utc(2026, 1, 11),
      amounts: [900, 900, 900],
    );

    expect(run(current, periods: [rare, current]), isNull);
  });
}
