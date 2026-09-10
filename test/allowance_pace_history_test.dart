import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flatplan/src/models/models.dart';
import 'package:flatplan/src/providers/period_stats_provider.dart';
import 'package:flatplan/src/providers/repository_provider.dart';
import 'package:flatplan/src/storage/period_repository.dart';

DateTime _midnightDaysAgo(int days) {
  final d = DateTime.now().subtract(Duration(days: days));
  return DateTime(d.year, d.month, d.day);
}

FactExpense _fact(String id, double amount, int daysAgo) => FactExpense(
  id: id,
  amount: amount,
  timestamp: _midnightDaysAgo(daysAgo).add(const Duration(hours: 12)),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('daily-allowance pace early in a period', () {
    late Directory tempDir;
    late ProviderContainer container;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('flatplan_pace_test_');
      final repo = PeriodRepository(directoryPath: tempDir.path);

      // Previous period: a month of steady 1000-a-visit grocery runs.
      await repo.savePeriod(
        Period(
          id: 'previous',
          name: 'Previous',
          startDate: _midnightDaysAgo(32),
          baseCurrency: 'EUR',
          lastModified: _midnightDaysAgo(32),
          categories: [
            Category(
              id: 'old-groceries',
              name: 'Groceries',
              type: CategoryType.optionalExpense,
              limit: 14000,
              isDailyAllowance: true,
              factExpenses: [
                _fact('o1', 1000, 20),
                _fact('o2', 1000, 15),
                _fact('o3', 1000, 10),
                _fact('o4', 1000, 5),
              ],
            ),
          ],
        ),
      );

      // Current period started two days ago with nothing spent yet.
      await repo.savePeriod(
        Period(
          id: 'current',
          name: 'Current',
          startDate: _midnightDaysAgo(2),
          baseCurrency: 'EUR',
          lastModified: _midnightDaysAgo(2),
          categories: [
            Category(
              id: 'new-groceries',
              name: 'Groceries',
              type: CategoryType.optionalExpense,
              limit: 14000,
              isDailyAllowance: true,
            ),
          ],
        ),
      );

      container = ProviderContainer(
        overrides: [periodRepositoryProvider.overrideWith((ref) => repo)],
      );
      container.listen(periodStatsProvider, (_, _) {});
    });

    tearDown(() {
      container.dispose();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('uses last period spending when this period has no history yet', () async {
      final stats = await container.read(periodStatsProvider.future);
      final groceries = stats!.categoryStats
          .firstWhere((c) => c.categoryId == 'new-groceries');

      // 14000 left over 27 remaining days at a typical 1000 a visit.
      expect(groceries.expectedPurchaseAmount, 1000);
      expect(groceries.expectedPurchaseFrequencyDays, 2);
    });
  });
}
