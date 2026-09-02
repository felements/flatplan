import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flatplan/src/models/models.dart';
import 'package:flatplan/src/storage/period_repository.dart';

void main() {
  group('PeriodRepository', () {
    late Directory tempDir;
    late PeriodRepository repo;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('flatplan_test_');
      repo = PeriodRepository(directoryPath: tempDir.path);
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('generates human-readable filename for normal period', () async {
      final period = Period(
        id: '1234-uuid',
        name: 'October 2025 Budget',
        startDate: DateTime(2025, 10, 1),

        baseCurrency: 'EUR',
        lastModified: DateTime.now(),
      );

      await repo.savePeriod(period);

      final files = tempDir.listSync().whereType<File>().toList();
      expect(files.length, 1);
      final filename = files.first.path.split(Platform.pathSeparator).last;

      expect(filename, '2025-10-october_2025_budget.yaml');
    });

    test('generates filename for template', () async {
      final period = Period(
        id: '5678-uuid',
        name: 'My Custom Template',
        startDate: DateTime(2025, 1, 1),

        baseCurrency: 'EUR',
        lastModified: DateTime.now(),
      );

      await repo.savePeriod(period);

      final files = tempDir.listSync().whereType<File>().toList();
      expect(files.length, 1);
      final filename = files.first.path.split(Platform.pathSeparator).last;

      expect(filename, 'my_custom_template.yaml');
    });

    test('filenameForPeriod returns the physical filename after save and load',
        () async {
      final period = Period(
        id: 'abc-uuid',
        name: 'March 2026',
        startDate: DateTime(2026, 3, 1),
        baseCurrency: 'EUR',
        lastModified: DateTime.now(),
      );

      await repo.savePeriod(period);
      expect(repo.filenameForPeriod('abc-uuid'), '2026-03-march_2026.yaml');

      final freshRepo = PeriodRepository(directoryPath: tempDir.path);
      expect(freshRepo.filenameForPeriod('abc-uuid'), isNull);
      await freshRepo.loadAllPeriods();
      expect(
        freshRepo.filenameForPeriod('abc-uuid'),
        '2026-03-march_2026.yaml',
      );
    });

    test('handles empty or special character names gracefully', () async {
      final period = Period(
        id: 'uuid-1111',
        name: '!!! --- ***',
        startDate: DateTime(2026, 3, 5),

        baseCurrency: 'EUR',
        lastModified: DateTime.now(),
      );

      await repo.savePeriod(period);

      final files = tempDir.listSync().whereType<File>().toList();
      expect(files.length, 1);
      final filename = files.first.path.split(Platform.pathSeparator).last;

      expect(filename, '2026-03-uuid-1111.yaml');
    });

    test('loadAll reports malformed YAML and still returns valid periods',
        () async {
      final period = Period(
        id: 'good-uuid',
        name: 'March 2026',
        startDate: DateTime(2026, 3, 1),
        baseCurrency: 'EUR',
        lastModified: DateTime.now(),
      );
      await repo.savePeriod(period);
      await File('${tempDir.path}/broken.yaml').writeAsString('foo: [1, 2');

      final result =
          await PeriodRepository(directoryPath: tempDir.path).loadAll();

      expect(result.periods.map((p) => p.id), ['good-uuid']);
      expect(result.failures.length, 1);
      expect(result.failures.single.fileName, 'broken.yaml');
      expect(result.failures.single.message, contains('line 1'));
    });

    test('loadAll reports a document whose top level is not a mapping',
        () async {
      await File('${tempDir.path}/list.yaml').writeAsString('- one\n- two\n');

      final result = await repo.loadAll();

      expect(result.periods, isEmpty);
      expect(result.failures.single.fileName, 'list.yaml');
      expect(result.failures.single.message, contains('not a mapping'));
    });

    test('loadAll reports a period with an invalid field', () async {
      await File('${tempDir.path}/bad_field.yaml')
          .writeAsString('id: x\nname: y\nstart_date: not-a-date\n');

      final result = await repo.loadAll();

      expect(result.periods, isEmpty);
      expect(result.failures.single.fileName, 'bad_field.yaml');
    });

    test('savePeriod does not reuse the filename of a file that failed to load',
        () async {
      final corrupt = File('${tempDir.path}/2026-03-march_2026.yaml');
      await corrupt.writeAsString('foo: [1, 2');
      await repo.loadAll();

      final period = Period(
        id: 'new-uuid',
        name: 'March 2026',
        startDate: DateTime(2026, 3, 1),
        baseCurrency: 'EUR',
        lastModified: DateTime.now(),
      );
      await repo.savePeriod(period);

      expect(corrupt.readAsStringSync(), 'foo: [1, 2');
      expect(repo.filenameForPeriod('new-uuid'),
          isNot('2026-03-march_2026.yaml'));
    });

    test('deletes legacy file when saving with new filename', () async {
      final legacyFile = File('${tempDir.path}/legacy-uuid.yaml');
      await legacyFile.writeAsString('fake content');

      final period = Period(
        id: 'legacy-uuid',
        name: 'March 2026 update',
        startDate: DateTime(2026, 3, 1),

        baseCurrency: 'EUR',
        lastModified: DateTime.now(),
      );

      await repo.savePeriod(period);

      final files = tempDir.listSync().whereType<File>().toList();
      expect(files.length, 1);
      final filename = files.first.path.split(Platform.pathSeparator).last;

      expect(filename, '2026-03-march_2026_update.yaml');
      expect(legacyFile.existsSync(), isFalse);
    });
  });
}
