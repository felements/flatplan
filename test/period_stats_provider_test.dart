import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flatplan/src/models/models.dart';
import 'package:flatplan/src/providers/period_stats_provider.dart';
import 'package:flatplan/src/providers/repository_provider.dart';
import 'package:flatplan/src/storage/period_repository.dart';

PlannedExpense _planned(String id, double amount) => PlannedExpense(
  id: id,
  description: 'item $id',
  amount: amount,
  dueDate: DueDate.exact(date: DateTime(2099, 1, 1)),
);

FactExpense _fact(String id, double amount) => FactExpense(
  id: id,
  amount: amount,
  timestamp: DateTime(2026, 1, 1),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('periodStats with max(planned, limit) rule', () {
    late Directory tempDir;
    late ProviderContainer container;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('flatplan_stats_test_');
      final repo = PeriodRepository(directoryPath: tempDir.path);

      // Period starts 5 days ago so currentPeriodProvider picks it
      // (effective end = start + 30 days, which spans today).
      final start = DateTime.now().subtract(const Duration(days: 5));
      final period = Period(
        id: 'test-period',
        name: 'Test Period',
        startDate: DateTime(start.year, start.month, start.day),
        baseCurrency: 'EUR',
        lastModified: DateTime(2026, 1, 1),
        categories: [
          // planned (1200) > limit (1000) → effective 1200, flag true
          Category(
            id: 'rent',
            name: 'Rent',
            type: CategoryType.mandatoryExpense,
            limit: 1000,
            plannedExpenses: [_planned('r1', 700), _planned('r2', 500)],
            factExpenses: [_fact('rf1', 500)],
          ),
          // limit (300) > planned (100) → effective 300, flag false
          Category(
            id: 'fun',
            name: 'Fun',
            type: CategoryType.optionalExpense,
            limit: 300,
            plannedExpenses: [_planned('f1', 100)],
          ),
          // no limit → effective = planned (400), flag false
          Category(
            id: 'groceries',
            name: 'Groceries',
            type: CategoryType.optionalExpense,
            plannedExpenses: [_planned('g1', 400)],
          ),
          // income: planned (3500) > limit (3000) → effective 3500, flag true
          Category(
            id: 'salary',
            name: 'Salary',
            type: CategoryType.income,
            limit: 3000,
            plannedExpenses: [_planned('s1', 3500)],
            factExpenses: [_fact('sf1', 2000)],
          ),
        ],
      );
      await repo.savePeriod(period);

      container = ProviderContainer(
        overrides: [periodRepositoryProvider.overrideWith((ref) => repo)],
      );
      // periodStatsProvider (and its dependency chain) are autoDispose;
      // a bare container.read(...future) doesn't hold a listener, so the
      // provider can be torn down mid-await. Keep it alive for the test.
      container.listen(periodStatsProvider, (_, _) {});
    });

    tearDown(() {
      container.dispose();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('per-category effective limits and flags', () async {
      final stats = await container.read(periodStatsProvider.future);
      expect(stats, isNotNull);

      final byId = {for (final c in stats!.categoryStats) c.categoryId: c};

      expect(byId['rent']!.limit, 1200);
      expect(byId['rent']!.plannedExceedsLimit, isTrue);
      expect(byId['rent']!.remaining, 700); // 1200 - 500 spent
      expect(byId['rent']!.heatPercentage, closeTo(500 / 1200, 0.0001));

      expect(byId['fun']!.limit, 300);
      expect(byId['fun']!.plannedExceedsLimit, isFalse);

      expect(byId['groceries']!.limit, 400);
      expect(byId['groceries']!.plannedExceedsLimit, isFalse);

      expect(byId['salary']!.limit, 3500);
      expect(byId['salary']!.plannedExceedsLimit, isTrue);
    });

    test('rollups reflect the max rule', () async {
      final stats = await container.read(periodStatsProvider.future);
      expect(stats, isNotNull);

      expect(stats!.totalMandatoryBudget, 1200);
      expect(stats.totalOptionalBudget, 700); // 300 + 400
      expect(stats.totalBudget, 1900);
      expect(stats.totalIncome, 3500);
      expect(stats.totalFactIncome, 2000);
      expect(stats.totalSpent, 500);
      expect(stats.overallRemaining, 1400); // 1900 - 500
      // free balance = factIncome - sum(max(spent, effectiveLimit)) per
      // expense category = 2000 - (1200 + 300 + 400)
      expect(stats.remainingFreeBalance, 100);
    });
  });
}
