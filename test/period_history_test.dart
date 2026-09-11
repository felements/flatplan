import 'package:flutter_test/flutter_test.dart';
import 'package:flatplan/src/logic/period_history.dart';
import 'package:flatplan/src/models/models.dart';

FactExpense _fact(double amount) =>
    FactExpense(id: 'f$amount', amount: amount, timestamp: DateTime(2026, 1, 1));

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

Category _groceries(String id, List<double> amounts, {String name = 'Groceries'}) =>
    Category(
      id: id,
      name: name,
      factExpenses: amounts.map(_fact).toList(),
    );

void main() {
  final older = _period(
    id: 'older',
    startDate: DateTime(2026, 1, 1),
    categories: [_groceries('c1', [100, 200])],
  );
  final previous = _period(
    id: 'previous',
    startDate: DateTime(2026, 2, 1),
    categories: [_groceries('c2', [300, 400])],
  );
  final current = _period(
    id: 'current',
    startDate: DateTime(2026, 3, 1),
    categories: [_groceries('c3', [999])],
  );
  final all = [current, previous, older];

  test('returns prior periods newest first, excluding the current one', () {
    final slices = priorCategoryHistory(
      categoryName: 'Groceries',
      currentPeriod: current,
      allPeriods: all,
      limit: 5,
    );

    expect(slices.map((s) => s.amounts), [
      [300, 400],
      [100, 200],
    ]);
  });

  test('caps the number of slices at limit', () {
    final slices = priorCategoryHistory(
      categoryName: 'Groceries',
      currentPeriod: current,
      allPeriods: all,
      limit: 1,
    );

    expect(slices.map((s) => s.amounts), [
      [300, 400],
    ]);
  });

  test('skips periods where the category is absent or never used', () {
    final empty = _period(
      id: 'empty',
      startDate: DateTime(2026, 2, 15),
      categories: [_groceries('c4', const [])],
    );
    final unrelated = _period(
      id: 'unrelated',
      startDate: DateTime(2026, 2, 20),
      categories: [_groceries('c5', [50], name: 'Transport')],
    );

    final slices = priorCategoryHistory(
      categoryName: 'Groceries',
      currentPeriod: current,
      allPeriods: [...all, empty, unrelated],
      limit: 5,
    );

    expect(slices.map((s) => s.amounts), [
      [300, 400],
      [100, 200],
    ]);
  });

  test('matches the category name ignoring case and whitespace', () {
    final slices = priorCategoryHistory(
      categoryName: '  groceries ',
      currentPeriod: current,
      allPeriods: all,
      limit: 5,
    );

    expect(slices, hasLength(2));
  });

  test('reports each period length from the next period start', () {
    final slices = priorCategoryHistory(
      categoryName: 'Groceries',
      currentPeriod: current,
      allPeriods: all,
      limit: 5,
    );

    // previous: 2026-02-01 .. 2026-02-28 inclusive
    expect(slices.first.lengthDays, 28);
    // older: 2026-01-01 .. 2026-01-31 inclusive
    expect(slices.last.lengthDays, 31);
  });

  test('returns nothing when the current period is the earliest', () {
    expect(
      priorCategoryHistory(
        categoryName: 'Groceries',
        currentPeriod: older,
        allPeriods: all,
        limit: 5,
      ),
      isEmpty,
    );
  });

  test('total sums the slice amounts', () {
    expect(
      const CategoryPeriodSlice(amounts: [1, 2, 3], lengthDays: 10).total,
      6,
    );
  });
}
