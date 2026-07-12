import 'package:flutter_test/flutter_test.dart';
import 'package:flatplan/src/models/models.dart';

PlannedExpense _planned(String id, double amount) => PlannedExpense(
  id: id,
  description: 'item $id',
  amount: amount,
  dueDate: DueDate.exact(date: DateTime(2026, 7, 15)),
);

void main() {
  group('CategoryBudget extension', () {
    test('no limit: effectiveLimit is sum of planned, flag is false', () {
      final cat = Category(
        id: 'c1',
        name: 'Groceries',
        plannedExpenses: [_planned('p1', 100), _planned('p2', 50)],
      );
      expect(cat.plannedTotal, 150);
      expect(cat.effectiveLimit, 150);
      expect(cat.plannedExceedsLimit, isFalse);
    });

    test('no limit, no planned: effectiveLimit is 0', () {
      final cat = Category(id: 'c1', name: 'Empty');
      expect(cat.plannedTotal, 0);
      expect(cat.effectiveLimit, 0);
      expect(cat.plannedExceedsLimit, isFalse);
    });

    test('limit only (no planned): effectiveLimit is limit', () {
      final cat = Category(id: 'c1', name: 'Fun', limit: 300);
      expect(cat.effectiveLimit, 300);
      expect(cat.plannedExceedsLimit, isFalse);
    });

    test('limit greater than planned sum: limit wins, flag false', () {
      final cat = Category(
        id: 'c1',
        name: 'Fun',
        limit: 300,
        plannedExpenses: [_planned('p1', 100)],
      );
      expect(cat.effectiveLimit, 300);
      expect(cat.plannedExceedsLimit, isFalse);
    });

    test('planned sum greater than limit: planned wins, flag true', () {
      final cat = Category(
        id: 'c1',
        name: 'Rent',
        limit: 1000,
        plannedExpenses: [_planned('p1', 700), _planned('p2', 500)],
      );
      expect(cat.effectiveLimit, 1200);
      expect(cat.plannedExceedsLimit, isTrue);
    });

    test('planned sum equal to limit: flag is false', () {
      final cat = Category(
        id: 'c1',
        name: 'Rent',
        limit: 1000,
        plannedExpenses: [_planned('p1', 1000)],
      );
      expect(cat.effectiveLimit, 1000);
      expect(cat.plannedExceedsLimit, isFalse);
    });

    test('income category follows the same rule', () {
      final cat = Category(
        id: 'c1',
        name: 'Salary',
        type: CategoryType.income,
        limit: 3000,
        plannedExpenses: [_planned('p1', 3500)],
      );
      expect(cat.effectiveLimit, 3500);
      expect(cat.plannedExceedsLimit, isTrue);
    });

    test('limit of 0 with planned items: planned wins, flag true', () {
      final cat = Category(
        id: 'c1',
        name: 'ZeroCap',
        limit: 0,
        plannedExpenses: [_planned('p1', 50)],
      );
      expect(cat.effectiveLimit, 50);
      expect(cat.plannedExceedsLimit, isTrue);
    });
  });
}
