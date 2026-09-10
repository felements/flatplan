import 'package:flutter_test/flutter_test.dart';
import 'package:flatplan/src/logic/allowance_pace.dart';
import 'package:flatplan/src/models/models.dart';

FactExpense _fact(double amount, DateTime timestamp) =>
    FactExpense(id: 'f-$amount-${timestamp.toIso8601String()}', amount: amount, timestamp: timestamp);

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

void main() {
  final asOf = DateTime(2026, 3, 10, 12);

  group('paceSamples', () {
    test('pulls expenses from a same-named category in an earlier period', () {
      final periods = [
        _period(
          id: 'previous',
          startDate: DateTime(2026, 2, 1),
          categories: [
            Category(
              id: 'old-id',
              name: 'Groceries',
              factExpenses: [
                _fact(900, DateTime(2026, 2, 20)),
                _fact(1100, DateTime(2026, 2, 25)),
              ],
            ),
          ],
        ),
        _period(
          id: 'current',
          startDate: DateTime(2026, 3, 8),
          categories: [
            Category(
              id: 'new-id',
              name: 'Groceries',
              factExpenses: [_fact(1000, DateTime(2026, 3, 9))],
            ),
          ],
        ),
      ];

      final samples = paceSamples(
        categoryName: 'Groceries',
        allPeriods: periods,
        asOf: asOf,
      );

      expect(samples..sort(), [900, 1000, 1100]);
    });
    test('excludes expenses outside the 30-day window ending at asOf', () {
      final periods = [
        _period(
          id: 'p',
          startDate: DateTime(2026, 1, 1),
          categories: [
            Category(
              id: 'c',
              name: 'Groceries',
              factExpenses: [
                _fact(10, DateTime(2026, 2, 8, 11)), // 30d + 1h before asOf
                _fact(20, DateTime(2026, 2, 9)), // inside the window
                _fact(30, DateTime(2026, 3, 11)), // after asOf
              ],
            ),
          ],
        ),
      ];

      final samples = paceSamples(
        categoryName: 'Groceries',
        allPeriods: periods,
        asOf: asOf,
      );

      expect(samples, [20]);
    });
    test('matches category names ignoring case and surrounding whitespace', () {
      final periods = [
        _period(
          id: 'p',
          startDate: DateTime(2026, 2, 20),
          categories: [
            Category(
              id: 'c',
              name: '  groceries ',
              factExpenses: [_fact(700, DateTime(2026, 3, 1))],
            ),
          ],
        ),
      ];

      final samples = paceSamples(
        categoryName: 'Groceries',
        allPeriods: periods,
        asOf: asOf,
      );

      expect(samples, [700]);
    });
  });

  group('estimateAllowancePace', () {
    test('returns null when fewer than two samples are available', () {
      final pace = estimateAllowancePace(
        samples: [1000],
        remaining: 10000,
        daysLeft: 20,
        periodLengthDays: 30,
      );

      expect(pace, isNull);
    });
    test('derives the cadence from the 20% trimmed mean of past purchases', () {
      final pace = estimateAllowancePace(
        samples: [200, 1000, 1000, 1000, 1000],
        remaining: 10000,
        daysLeft: 20,
        periodLengthDays: 30,
      );

      // The lowest 20% (the 200 outlier) is dropped, so the typical purchase
      // is 1000, not the raw 840 average.
      expect(pace!.amount, 1000);
      expect(pace.frequencyDays, 2);
    });
    test('returns null when the affordable cadence is sparser than half the period', () {
      // Only one 1000 purchase is affordable across the 20 remaining days,
      // which is not a rhythm worth suggesting in a 30-day period.
      final pace = estimateAllowancePace(
        samples: [1000, 1000],
        remaining: 1000,
        daysLeft: 20,
        periodLengthDays: 30,
      );

      expect(pace, isNull);
    });
    test('returns null when the category has nothing left to spend', () {
      final pace = estimateAllowancePace(
        samples: [1000, 1000],
        remaining: -500,
        daysLeft: 20,
        periodLengthDays: 30,
      );

      expect(pace, isNull);
    });
  });
  group('paceForCategory', () {
    Category groceries(List<FactExpense> facts) => Category(
      id: 'c',
      name: 'Groceries',
      limit: 14000,
      isDailyAllowance: true,
      factExpenses: facts,
    );

    test('returns null once the period has ended', () {
      final ended = _period(
        id: 'ended',
        startDate: DateTime(2026, 1, 1),
        categories: [
          groceries([
            _fact(1000, DateTime(2026, 1, 10)),
            _fact(1000, DateTime(2026, 1, 15)),
            _fact(1000, DateTime(2026, 1, 20)),
            _fact(1000, DateTime(2026, 1, 25)),
          ]),
        ],
      );

      final pace = paceForCategory(
        category: ended.categories.first,
        period: ended,
        endDate: DateTime(2026, 1, 31),
        allPeriods: [ended],
        now: DateTime(2026, 2, 20),
      );

      // There are no days left to pace anything over, so a cadence would be
      // arithmetic noise rather than a suggestion.
      expect(pace, isNull);
    });

    test('returns null for a category without a daily allowance', () {
      final period = _period(
        id: 'p',
        startDate: DateTime(2026, 3, 1),
        categories: [
          Category(
            id: 'c',
            name: 'Groceries',
            limit: 14000,
            factExpenses: [
              _fact(1000, DateTime(2026, 3, 2)),
              _fact(1000, DateTime(2026, 3, 4)),
            ],
          ),
        ],
      );

      final pace = paceForCategory(
        category: period.categories.first,
        period: period,
        endDate: DateTime(2026, 3, 31),
        allPeriods: [period],
        now: DateTime(2026, 3, 10),
      );

      expect(pace, isNull);
    });
  });
}
