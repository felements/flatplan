import 'package:flutter_test/flutter_test.dart';
import 'package:flatplan/src/logic/spending_trend.dart';
import 'package:flatplan/src/models/models.dart';

FactExpense _fact(double amount) => FactExpense(
  id: 'f$amount',
  amount: amount,
  timestamp: DateTime.utc(2026, 1, 1),
);

Period _period({
  required String id,
  required DateTime startDate,
  required List<Category> categories,
}) => Period(
  id: id,
  name: id,
  startDate: startDate,
  baseCurrency: 'EUR',
  lastModified: startDate,
  categories: categories,
);

Category _groceries(
  String id,
  List<double> amounts, {
  double limit = 1000,
  bool isDailyAllowance = true,
}) => Category(
  id: id,
  name: 'Groceries',
  limit: limit,
  isDailyAllowance: isDailyAllowance,
  factExpenses: amounts.map(_fact).toList(),
);

void main() {
  // Previous period: 3,000 spent across 30 days -> 100 / day.
  final previous = _period(
    id: 'previous',
    startDate: DateTime.utc(2026, 2, 1),
    categories: [
      _groceries('c1', [1000, 1000, 1000]),
    ],
  );
  // Current period runs 2026-03-03 .. 2026-03-25 (previous ends the day
  // before it starts). UTC throughout: the fixture spans the US
  // spring-forward on 2026-03-08, and local-time arithmetic over that
  // window is an hour short in a US zone.
  final current = _period(
    id: 'current',
    startDate: DateTime.utc(2026, 3, 3),
    categories: [
      _groceries('c2', [200]),
    ],
  );
  final all = [previous, current];
  final endDate = DateTime.utc(2026, 3, 25);

  test('projects the period total from the previous period rate', () {
    final trend = spendingTrendFor(
      category: current.categories.first,
      period: current,
      endDate: endDate,
      allPeriods: all,
      now: DateTime.utc(2026, 3, 5),
    );

    // previous: 3000 / 30 days = 100 / day
    expect(trend!.recentDailyRate, 100);
    // 20 days remain; 200 already spent -> 200 + 20 * 100
    expect(trend.projectedTotal, 2200);
    // limit is 1000
    expect(trend.overshoot, 1200);
    expect(trend.isOverProjected, isTrue);
  });

  test('reports no overshoot when the projection lands inside the limit', () {
    final roomy = _period(
      id: 'current',
      startDate: DateTime.utc(2026, 3, 3),
      categories: [
        _groceries('c2', [200], limit: 5000),
      ],
    );

    final trend = spendingTrendFor(
      category: roomy.categories.first,
      period: roomy,
      endDate: endDate,
      allPeriods: [previous, roomy],
      now: DateTime.utc(2026, 3, 5),
    );

    expect(trend!.projectedTotal, 2200);
    expect(trend.overshoot, 0);
    expect(trend.isOverProjected, isFalse);
  });

  test('reads the immediately preceding period even when it is empty', () {
    // Groceries went untouched last period. That is a rate of zero, which
    // is real data — not a reason to reach back a further period and label
    // it "last period" in the UI.
    final idle = _period(
      id: 'idle',
      startDate: DateTime.utc(2026, 3, 3),
      categories: [_groceries('c-idle', const [])],
    );
    final latest = _period(
      id: 'latest',
      startDate: DateTime.utc(2026, 4, 1),
      categories: [
        _groceries('c-latest', [200]),
      ],
    );

    final trend = spendingTrendFor(
      category: latest.categories.first,
      period: latest,
      endDate: DateTime.utc(2026, 4, 21),
      allPeriods: [previous, idle, latest],
      now: DateTime.utc(2026, 4, 1),
    );

    // Zero, not `previous`'s 100 / day from two periods back.
    expect(trend!.recentDailyRate, 0);
    // 200 already spent plus 20 days at nothing a day.
    expect(trend.projectedTotal, 200);
    expect(trend.overshoot, 0);
    expect(trend.isOverProjected, isFalse);
  });

  test('returns null for a category without a daily allowance', () {
    final plain = _period(
      id: 'current',
      startDate: DateTime.utc(2026, 3, 3),
      categories: [
        _groceries('c2', [200], isDailyAllowance: false),
      ],
    );

    expect(
      spendingTrendFor(
        category: plain.categories.first,
        period: plain,
        endDate: endDate,
        allPeriods: [previous, plain],
        now: DateTime.utc(2026, 3, 5),
      ),
      isNull,
    );
  });

  test('returns null once the period has ended', () {
    expect(
      spendingTrendFor(
        category: current.categories.first,
        period: current,
        endDate: endDate,
        allPeriods: all,
        now: DateTime.utc(2026, 4, 15),
      ),
      isNull,
    );
  });

  test('returns null when there is no complete prior period', () {
    expect(
      spendingTrendFor(
        category: previous.categories.first,
        period: previous,
        endDate: DateTime.utc(2026, 3, 2),
        allPeriods: all,
        now: DateTime.utc(2026, 2, 10),
      ),
      isNull,
    );
  });
}
