import 'dart:io';

import 'package:flatplan/src/models/models.dart';
import 'package:flatplan/src/providers/all_periods_provider.dart';
import 'package:flatplan/src/providers/repository_provider.dart';
import 'package:flatplan/src/storage/period_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  late Directory tempDir;
  late ProviderContainer container;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('flatplan_periods_test_');
    final repo = PeriodRepository(directoryPath: tempDir.path);
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

  test('periodLoadFailuresProvider lists files that failed to load', () async {
    await File('${tempDir.path}/broken.yaml').writeAsString('foo: [1, 2');

    final failures = await container.read(periodLoadFailuresProvider.future);

    expect(failures.map((f) => f.fileName), ['broken.yaml']);
  });

  test('allPeriodsProvider still returns valid periods next to a broken file',
      () async {
    await PeriodRepository(directoryPath: tempDir.path).savePeriod(
      Period(
        id: 'good-uuid',
        name: 'March 2026',
        startDate: DateTime(2026, 3, 1),
        baseCurrency: 'EUR',
        lastModified: DateTime(2026, 1, 1),
      ),
    );
    await File('${tempDir.path}/broken.yaml').writeAsString('foo: [1, 2');

    final periods = await container.read(allPeriodsProvider.future);

    expect(periods.map((p) => p.id), ['good-uuid']);
  });
}
