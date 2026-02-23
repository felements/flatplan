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
        endDate: DateTime(2025, 10, 31),
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
        endDate: DateTime(2025, 1, 31),
        baseCurrency: 'EUR',
        lastModified: DateTime.now(),
      );

      await repo.savePeriod(period);

      final files = tempDir.listSync().whereType<File>().toList();
      expect(files.length, 1);
      final filename = files.first.path.split(Platform.pathSeparator).last;
      
      expect(filename, 'my_custom_template.yaml');
    });

    test('handles empty or special character names gracefully', () async {
      final period = Period(
        id: 'uuid-1111',
        name: '!!! --- ***',
        startDate: DateTime(2026, 3, 5),
        endDate: DateTime(2026, 4, 4),
        baseCurrency: 'EUR',
        lastModified: DateTime.now(),
      );

      await repo.savePeriod(period);

      final files = tempDir.listSync().whereType<File>().toList();
      expect(files.length, 1);
      final filename = files.first.path.split(Platform.pathSeparator).last;
      
      expect(filename, '2026-03-uuid-1111.yaml');
    });

    test('deletes legacy file when saving with new filename', () async {
      final legacyFile = File('${tempDir.path}/legacy-uuid.yaml');
      await legacyFile.writeAsString('fake content');

      final period = Period(
        id: 'legacy-uuid',
        name: 'March 2026 update',
        startDate: DateTime(2026, 3, 1),
        endDate: DateTime(2026, 3, 31),
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
