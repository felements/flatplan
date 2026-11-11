import 'package:flatplan/src/logic/period_extensions.dart';
import 'package:flatplan/src/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final periodStart = DateTime(2026, 2, 1);

  test('exact due date passes through unchanged', () {
    final due = resolveDueDate(
      DueDate.exact(date: DateTime(2026, 2, 10)),
      periodStart: periodStart,
    );
    expect(due, DateTime(2026, 2, 10));
  });

  test('dayOfMonth on or after the start day stays in the start month', () {
    final due = resolveDueDate(
      const DueDate.dayOfMonth(day: 27),
      periodStart: periodStart,
    );
    expect(due, DateTime(2026, 2, 27));
  });

  test('dayOfMonth before the period start shifts one month forward', () {
    // Period starts on the 15th; day 5 comes before the start day.
    final due = resolveDueDate(
      const DueDate.dayOfMonth(day: 5),
      periodStart: DateTime(2026, 2, 15),
    );
    expect(due, DateTime(2026, 3, 5));
  });

  test('dayOfMonth in the period tail stays in the period start month', () {
    // Period 7 Nov → 8 Dec; on 5 Dec a day-25 payment was due on 25 Nov.
    final due = resolveDueDate(
      const DueDate.dayOfMonth(day: 25),
      periodStart: DateTime(2026, 11, 7),
    );
    expect(due, DateTime(2026, 11, 25));
  });

  test('dayOfMonth before the start day lands at the period end', () {
    // Day 1 in a period starting on the 7th is 1 Dec, not 1 Nov.
    final due = resolveDueDate(
      const DueDate.dayOfMonth(day: 1),
      periodStart: DateTime(2026, 11, 7),
    );
    expect(due, DateTime(2026, 12, 1));
  });
}
