import 'dart:io';

import 'package:flatplan/src/models/models.dart';
import 'package:flatplan/src/providers/ai_stats_settings_provider.dart';
import 'package:flatplan/src/providers/all_periods_provider.dart';
import 'package:flatplan/src/providers/current_period_provider.dart';
import 'package:flatplan/src/providers/current_period_stats_sync_provider.dart';
import 'package:flatplan/src/providers/repository_provider.dart';
import 'package:flatplan/src/storage/period_repository.dart';
import 'package:flatplan/src/storage/period_stats_writer.dart';
import 'package:flatplan/src/storage/vault_workspace.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records every write the workspace announces, as the sync journal would.
class _CountingListener implements WorkspaceChangeListener {
  final List<String> changed = [];

  @override
  Future<void> onChanged(String name) async => changed.add(name);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late ProviderContainer container;

  File statsFile() => File('${tempDir.path}/${PeriodStatsWriter.fileName}');

  /// A period starting 5 days ago, so currentPeriodProvider picks it up
  /// (effective end = start + 30 days, which spans today).
  Period activePeriod() {
    final start = DateTime.now().subtract(const Duration(days: 5));
    return Period(
      id: 'test-period',
      name: 'Test Period',
      startDate: DateTime(start.year, start.month, start.day),
      baseCurrency: 'EUR',
      lastModified: DateTime(2026, 1, 1),
      categories: [
        Category(
          id: 'groceries',
          name: 'Groceries',
          type: CategoryType.mandatoryExpense,
          limit: 500,
          factExpenses: [
            FactExpense(id: 'f1', amount: 120, timestamp: DateTime(2026, 1, 1)),
          ],
        ),
      ],
    );
  }

  Future<ProviderContainer> makeContainer() async {
    final repo = PeriodRepository(workspace: DirectoryWorkspace(tempDir.path));
    final c = ProviderContainer(
      overrides: [periodRepositoryProvider.overrideWith((ref) => repo)],
    );
    // The sync provider chain is autoDispose; hold a listener so it is not
    // torn down mid-await.
    c.listen(currentPeriodStatsSyncProvider, (_, _) {});
    return c;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tempDir = Directory.systemTemp.createTempSync('flatplan_sync_test_');
  });

  tearDown(() {
    container.dispose();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('writes current_stats.md when enabled and a current period exists',
      () async {
    await PeriodRepository(workspace: DirectoryWorkspace(tempDir.path))
        .savePeriod(activePeriod());
    container = await makeContainer();

    await container.read(currentPeriodStatsSyncProvider.future);

    expect(statsFile().existsSync(), isTrue);
    final content = statsFile().readAsStringSync();
    expect(content, contains('# Budget Stats — Test Period'));
    expect(content, contains('| Groceries | Mandatory |'));
  });

  test('stats file references the source period yaml filename', () async {
    await PeriodRepository(workspace: DirectoryWorkspace(tempDir.path))
        .savePeriod(activePeriod());
    container = await makeContainer();

    await container.read(currentPeriodStatsSyncProvider.future);

    final yamlName = tempDir
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .firstWhere((n) => n.endsWith('.yaml'));
    expect(statsFile().readAsStringSync(), contains('- Source: $yamlName'));
  });

  test('deletes the file when the toggle is switched off', () async {
    await PeriodRepository(workspace: DirectoryWorkspace(tempDir.path))
        .savePeriod(activePeriod());
    container = await makeContainer();
    await container.read(currentPeriodStatsSyncProvider.future);
    expect(statsFile().existsSync(), isTrue);

    await container.read(aiStatsSettingsProvider.notifier).setEnabled(false);
    await container.read(currentPeriodStatsSyncProvider.future);

    expect(statsFile().existsSync(), isFalse);
  });

  test('does not write when disabled from the start', () async {
    SharedPreferences.setMockInitialValues({'ai_stats_enabled': false});
    await PeriodRepository(workspace: DirectoryWorkspace(tempDir.path))
        .savePeriod(activePeriod());
    container = await makeContainer();

    await container.read(currentPeriodStatsSyncProvider.future);

    expect(statsFile().existsSync(), isFalse);
  });

  test('does not write when no period exists', () async {
    container = await makeContainer();

    await container.read(currentPeriodStatsSyncProvider.future);

    expect(statsFile().existsSync(), isFalse);
  });

  test('a reload with unchanged data does not touch the file', () async {
    final repo = PeriodRepository(workspace: DirectoryWorkspace(tempDir.path));
    await repo.savePeriod(activePeriod());
    final listener = _CountingListener();
    final listened = PeriodRepository(
      workspace: DirectoryWorkspace(tempDir.path, changeListener: listener),
    );
    container = ProviderContainer(
      overrides: [periodRepositoryProvider.overrideWith((ref) => listened)],
    );
    container.listen(currentPeriodStatsSyncProvider, (_, _) {});
    await container.read(currentPeriodStatsSyncProvider.future);
    expect(listener.changed, [PeriodStatsWriter.fileName]);

    // What a pull-triggered reload or a no-op save does.
    container.invalidate(allPeriodsProvider);
    container.invalidate(currentPeriodProvider);
    await container.read(currentPeriodStatsSyncProvider.future);

    expect(listener.changed, hasLength(1), reason: 'nothing changed, no write');
  });

  test('regenerates the file content when period data changes', () async {
    final repo = PeriodRepository(workspace: DirectoryWorkspace(tempDir.path));
    final period = activePeriod();
    await repo.savePeriod(period);
    container = await makeContainer();

    await container.read(currentPeriodStatsSyncProvider.future);
    expect(statsFile().existsSync(), isTrue);
    final initialContent = statsFile().readAsStringSync();
    expect(initialContent, contains('| Groceries | Mandatory | no | 500 | 120 | 380 | 24% | no |'));

    // Mimic PeriodNotifier._debouncedSave: persist the change, then
    // invalidate the providers it invalidates after a real edit.
    final updatedCategory = period.categories.first.copyWith(
      factExpenses: [
        ...period.categories.first.factExpenses,
        FactExpense(id: 'f2', amount: 80, timestamp: DateTime(2026, 1, 2)),
      ],
    );
    final updatedPeriod = period.copyWith(categories: [updatedCategory]);
    await repo.savePeriod(updatedPeriod);
    container.invalidate(allPeriodsProvider);
    container.invalidate(currentPeriodProvider);

    await container.read(currentPeriodStatsSyncProvider.future);

    final updatedContent = statsFile().readAsStringSync();
    expect(updatedContent, contains('| Groceries | Mandatory | no | 500 | 200 | 300 | 40% | no |'));
  });
}
