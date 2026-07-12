import 'dart:io';

import 'package:flatplan/src/models/models.dart';
import 'package:flatplan/src/providers/ai_stats_settings_provider.dart';
import 'package:flatplan/src/providers/current_period_stats_sync_provider.dart';
import 'package:flatplan/src/providers/repository_provider.dart';
import 'package:flatplan/src/storage/period_repository.dart';
import 'package:flatplan/src/storage/period_stats_writer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    final repo = PeriodRepository(directoryPath: tempDir.path);
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
    await PeriodRepository(directoryPath: tempDir.path)
        .savePeriod(activePeriod());
    container = await makeContainer();

    await container.read(currentPeriodStatsSyncProvider.future);

    expect(statsFile().existsSync(), isTrue);
    final content = statsFile().readAsStringSync();
    expect(content, contains('# Budget Stats — Test Period'));
    expect(content, contains('| Groceries | Mandatory |'));
  });

  test('deletes the file when the toggle is switched off', () async {
    await PeriodRepository(directoryPath: tempDir.path)
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
    await PeriodRepository(directoryPath: tempDir.path)
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
}
