import 'dart:io';

import 'package:flatplan/src/models/models.dart';
import 'package:flatplan/src/providers/all_periods_provider.dart';
import 'package:flatplan/src/providers/current_period_provider.dart';
import 'package:flatplan/src/providers/period_notifier_provider.dart';
import 'package:flatplan/src/providers/repository_provider.dart';
import 'package:flatplan/src/storage/period_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Long enough to cover the 500 ms save debounce plus the disk round-trip.
const _afterDebounce = Duration(milliseconds: 800);

Period _period({List<FactExpense> facts = const []}) => Period(
  id: 'p1',
  name: 'September 2026',
  startDate: DateTime(2026, 9, 1),
  baseCurrency: 'EUR',
  lastModified: DateTime(2026, 9, 1),
  categories: [
    Category(
      id: 'c1',
      name: 'Groceries',
      type: CategoryType.optionalExpense,
      limit: 500,
      factExpenses: facts,
    ),
  ],
);

void main() {
  late Directory tempDir;
  late PeriodRepository repo;
  late ProviderContainer container;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('flatplan_refresh_test_');
    repo = PeriodRepository(directoryPath: tempDir.path);
    container = ProviderContainer(
      overrides: [periodRepositoryProvider.overrideWith((ref) => repo)],
    );
  });

  tearDown(() {
    container.dispose();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  /// Mirrors what the dashboard watches. The failures listener matters: it
  /// keeps [periodLoadResultProvider] alive, so invalidating only the derived
  /// [allPeriodsProvider] would replay a cached, pre-save read.
  void listenLikeDashboard() {
    container.listen(periodLoadFailuresProvider, (_, _) {});
    container.listen(allPeriodsProvider, (_, _) {});
    container.listen(currentPeriodProvider, (_, _) {});
  }

  test('adding a fact expense refreshes allPeriodsProvider', () async {
    await repo.savePeriod(_period());
    listenLikeDashboard();
    await container.read(periodLoadFailuresProvider.future);
    await container.read(allPeriodsProvider.future);

    // CategoryDetailView watches this notifier; without a listener it would
    // auto-dispose and the debounced save would never run.
    container.listen(periodProvider('p1'), (_, _) {});
    await container.read(periodProvider('p1').future);
    container
        .read(periodProvider('p1').notifier)
        .addFactExpense(
          'c1',
          FactExpense(id: 'f1', amount: 42, timestamp: DateTime(2026, 9, 10)),
        );
    await Future<void>.delayed(_afterDebounce);

    final periods = await container.read(allPeriodsProvider.future);
    expect(
      periods.single.categories.single.factExpenses.map((e) => e.amount),
      [42],
      reason: 'the dashboard reads the period it renders from here',
    );
  });

  test('adding a fact expense refreshes currentPeriodProvider', () async {
    await repo.savePeriod(_period());
    listenLikeDashboard();
    await container.read(periodLoadFailuresProvider.future);
    await container.read(currentPeriodProvider.future);

    // CategoryDetailView watches this notifier; without a listener it would
    // auto-dispose and the debounced save would never run.
    container.listen(periodProvider('p1'), (_, _) {});
    await container.read(periodProvider('p1').future);
    container
        .read(periodProvider('p1').notifier)
        .addFactExpense(
          'c1',
          FactExpense(id: 'f1', amount: 42, timestamp: DateTime(2026, 9, 10)),
        );
    await Future<void>.delayed(_afterDebounce);

    final current = await container.read(currentPeriodProvider.future);
    expect(current!.categories.single.factExpenses.map((e) => e.amount), [42]);
  });

  test('setPeriod makes the new period visible to allPeriodsProvider', () async {
    listenLikeDashboard();
    await container.read(periodLoadFailuresProvider.future);
    expect(await container.read(allPeriodsProvider.future), isEmpty);

    await container.read(currentPeriodProvider.notifier).setPeriod(_period());

    final periods = await container.read(allPeriodsProvider.future);
    expect(
      periods.map((p) => p.id),
      ['p1'],
      reason: 'a cold-start period must appear in the sidebar immediately',
    );
  });
}
