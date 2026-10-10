import 'package:flatplan/src/models/models.dart';
import 'package:flatplan/src/providers/all_periods_provider.dart';
import 'package:flatplan/src/providers/current_period_provider.dart';
import 'package:flatplan/src/providers/period_notifier_provider.dart';
import 'package:flatplan/src/providers/repository_provider.dart';
import 'package:flatplan/src/storage/period_repository.dart';
import 'package:flatplan/src/storage/vault_workspace.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Long enough to cover the 500 ms save debounce plus the disk round-trip.
const _afterDebounce = Duration(milliseconds: 800);

Period _period() => Period(
  id: 'p1',
  name: 'September 2026',
  startDate: DateTime(2026, 9, 1),
  baseCurrency: 'EUR',
  lastModified: DateTime(2026, 9, 1),
  categories: const [
    Category(
      id: 'c1',
      name: 'Groceries',
      type: CategoryType.optionalExpense,
      limit: 500,
    ),
  ],
);

void main() {
  late MemoryWorkspace workspace;
  late PeriodRepository repo;
  late ProviderContainer container;

  setUp(() async {
    workspace = MemoryWorkspace();
    repo = PeriodRepository(workspace: workspace);
    await repo.savePeriod(_period());
    container = ProviderContainer(
      overrides: [periodRepositoryProvider.overrideWith((ref) => repo)],
    );
  });

  tearDown(() {
    container.dispose();
  });

  /// What the dashboard watches; see period_refresh_test.dart for why the
  /// failures listener matters.
  void listenLikeDashboard() {
    container.listen(periodLoadFailuresProvider, (_, _) {});
    container.listen(allPeriodsProvider, (_, _) {});
    container.listen(currentPeriodProvider, (_, _) {});
  }

  /// Reads the vault back through a fresh repository, as the next app start
  /// would.
  Future<List<Period>> readBack() =>
      PeriodRepository(workspace: workspace).loadAllPeriods();

  test('writes the new name and start date before returning', () async {
    container.listen(periodProvider('p1'), (_, _) {});

    // Called before the notifier has finished loading, as a fast Save in a
    // freshly opened dialog would.
    await container
        .read(periodProvider('p1').notifier)
        .updateDetails(name: 'Autumn', startDate: DateTime(2026, 9, 3));

    final saved = (await readBack()).single;
    expect(saved.name, 'Autumn');
    expect(saved.startDate, DateTime(2026, 9, 3));
    expect(saved.lastModified.isAfter(DateTime(2026, 9, 1)), isTrue);
  });

  test('refreshes the period list and the current period', () async {
    listenLikeDashboard();
    await container.read(allPeriodsProvider.future);
    await container.read(currentPeriodProvider.future);
    container.listen(periodProvider('p1'), (_, _) {});

    await container
        .read(periodProvider('p1').notifier)
        .updateDetails(name: 'Autumn', startDate: DateTime(2026, 9, 3));

    final periods = await container.read(allPeriodsProvider.future);
    expect(periods.single.name, 'Autumn');
    final current = await container.read(currentPeriodProvider.future);
    expect(current!.startDate, DateTime(2026, 9, 3));
  });

  test('keeps an edit that is still waiting on the save debounce', () async {
    container.listen(periodProvider('p1'), (_, _) {});
    await container.read(periodProvider('p1').future);
    final notifier = container.read(periodProvider('p1').notifier);

    notifier.addFactExpense(
      'c1',
      FactExpense(id: 'f1', amount: 42, timestamp: DateTime(2026, 9, 10)),
    );
    await notifier.updateDetails(
      name: 'Autumn',
      startDate: DateTime(2026, 9, 3),
    );
    // Let the debounce window pass: a stale debounced save would land now
    // and put the old name back.
    await Future<void>.delayed(_afterDebounce);

    final saved = (await readBack()).single;
    expect(saved.name, 'Autumn');
    expect(saved.categories.single.factExpenses.map((e) => e.amount), [42]);
  });

  test('rewrites the period\'s own file rather than adding one', () async {
    listenLikeDashboard();
    await container.read(allPeriodsProvider.future);
    container.listen(periodProvider('p1'), (_, _) {});

    await container
        .read(periodProvider('p1').notifier)
        .updateDetails(name: 'Autumn', startDate: DateTime(2026, 10, 3));

    expect(await workspace.listFiles(), ['2026-09-september_2026.yaml']);
  });
}
