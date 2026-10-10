import 'package:flatplan/src/logic/period_extensions.dart';
import 'package:flatplan/src/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

Period _period(String id, DateTime start) => Period(
  id: id,
  name: id,
  startDate: start,
  baseCurrency: 'EUR',
  lastModified: DateTime(2026, 1, 1),
);

void main() {
  // Three periods in date order; `b` is the one being edited.
  final a = _period('a', DateTime(2026, 9, 1));
  final b = _period('b', DateTime(2026, 9, 10));
  final c = _period('c', DateTime(2026, 9, 20));
  final d = _period('d', DateTime(2026, 9, 30));
  final all = [d, a, c, b];

  group('isStartDateTaken', () {
    test('is true when another period starts that calendar day', () {
      // `c` starts at midnight; a pick carrying a time of day still clashes.
      expect(isStartDateTaken(b, DateTime(2026, 9, 20, 14, 30), all), isTrue);
    });

    test('is false for the period\'s own start day', () {
      expect(isStartDateTaken(b, DateTime(2026, 9, 10), all), isFalse);
    });

    test('is false for a day no period starts on', () {
      expect(isStartDateTaken(b, DateTime(2026, 9, 21), all), isFalse);
    });

    test('ignores the time of day on the other period\'s start', () {
      // Periods created without touching the picker carry DateTime.now().
      final late = _period('late', DateTime(2026, 9, 25, 18, 5));
      expect(
        isStartDateTaken(b, DateTime(2026, 9, 25), [...all, late]),
        isTrue,
      );
    });
  });

  group('periodsPassedBy', () {
    test('is empty when the start date does not change', () {
      expect(periodsPassedBy(b, DateTime(2026, 9, 10), all), isEmpty);
    });

    test('is empty for a move that stays between the neighbours', () {
      expect(periodsPassedBy(b, DateTime(2026, 9, 2), all), isEmpty);
      expect(periodsPassedBy(b, DateTime(2026, 9, 19), all), isEmpty);
    });

    test('lists the next period when moving past it', () {
      expect(periodsPassedBy(b, DateTime(2026, 9, 21), all), [c]);
    });

    test('lists every period passed, in date order', () {
      expect(periodsPassedBy(b, DateTime(2026, 10, 5), all), [c, d]);
    });

    test('lists the previous period when moving back past it', () {
      expect(periodsPassedBy(b, DateTime(2026, 8, 31), all), [a]);
    });
  });
}
