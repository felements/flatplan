import 'package:flatplan/src/logic/period_extensions.dart';
import 'package:flatplan/src/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final periodStart = DateTime(2026, 2, 1);
  final now = DateTime(2026, 2, 25);

  test('exact due date passes through unchanged', () {
    final due = resolveDueDate(
      DueDate.exact(date: DateTime(2026, 2, 10)),
      now: now,
      periodStart: periodStart,
    );
    expect(due, DateTime(2026, 2, 10));
  });

  test('dayOfMonth resolves within the current month', () {
    final due = resolveDueDate(
      const DueDate.dayOfMonth(day: 27),
      now: now,
      periodStart: periodStart,
    );
    expect(due, DateTime(2026, 2, 27));
  });

  test('dayOfMonth before the period start shifts one month forward', () {
    // Period starts on the 15th; day 5 of "now"'s month lands before it.
    final due = resolveDueDate(
      const DueDate.dayOfMonth(day: 5),
      now: DateTime(2026, 2, 20),
      periodStart: DateTime(2026, 2, 15),
    );
    expect(due, DateTime(2026, 3, 5));
  });
}
