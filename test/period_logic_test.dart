import 'package:flutter_test/flutter_test.dart';
import 'package:flatplan/src/logic/period_logic.dart';
import 'package:flatplan/src/models/models.dart';

Period _periodWith(List<PlannedExpense> plannedExpenses) => Period(
  id: 'period-1',
  name: 'July 2026',
  startDate: DateTime(2026, 7, 1),
  baseCurrency: 'EUR',
  lastModified: DateTime(2026, 7, 1),
  categories: [
    Category(id: 'c1', name: 'Bills', plannedExpenses: plannedExpenses),
  ],
);

void main() {
  group('createNextPeriod planned expense rollover', () {
    test('copies day-of-month planned expenses with isCompleted reset', () {
      final current = _periodWith([
        const PlannedExpense(
          id: 'p1',
          description: 'Rent',
          amount: 1200,
          dueDate: DueDate.dayOfMonth(day: 5),
          isCompleted: true,
        ),
      ]);

      final next = createNextPeriod(
        currentPeriod: current,
        newStartDate: DateTime(2026, 8, 1),
        newName: 'August 2026',
      );

      final copied = next.categories.single.plannedExpenses;
      expect(copied, hasLength(1));
      expect(copied.single.description, 'Rent');
      expect(copied.single.dueDate, const DueDate.dayOfMonth(day: 5));
      expect(copied.single.isCompleted, isFalse);
      expect(copied.single.id, isNot('p1'));
    });

    test('does not copy exact-date planned expenses', () {
      final current = _periodWith([
        PlannedExpense(
          id: 'p1',
          description: 'Car insurance',
          amount: 300,
          dueDate: DueDate.exact(date: DateTime(2026, 7, 15)),
        ),
        const PlannedExpense(
          id: 'p2',
          description: 'Rent',
          amount: 1200,
          dueDate: DueDate.dayOfMonth(day: 5),
        ),
      ]);

      final next = createNextPeriod(
        currentPeriod: current,
        newStartDate: DateTime(2026, 8, 1),
        newName: 'August 2026',
      );

      final copied = next.categories.single.plannedExpenses;
      expect(copied, hasLength(1));
      expect(copied.single.description, 'Rent');
    });

    test('category with only exact-date expenses rolls over empty', () {
      final current = _periodWith([
        PlannedExpense(
          id: 'p1',
          description: 'One-off purchase',
          amount: 80,
          dueDate: DueDate.exact(date: DateTime(2026, 7, 20)),
        ),
      ]);

      final next = createNextPeriod(
        currentPeriod: current,
        newStartDate: DateTime(2026, 8, 1),
        newName: 'August 2026',
      );

      expect(next.categories.single.plannedExpenses, isEmpty);
    });
  });
}
