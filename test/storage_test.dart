import 'package:flatplan/src/models/models.dart';
import 'package:flatplan/src/storage/period_repository.dart';
import 'package:flatplan/src/storage/vault_workspace.dart';
import 'package:flutter_test/flutter_test.dart';

Period _period({
  required String id,
  required String name,
  DateTime? startDate,
}) => Period(
  id: id,
  name: name,
  startDate: startDate ?? DateTime(2026, 3, 1),
  baseCurrency: 'EUR',
  lastModified: DateTime(2026, 3, 1),
);

void main() {
  group('PeriodRepository', () {
    late MemoryWorkspace ws;
    late PeriodRepository repo;

    setUp(() {
      ws = MemoryWorkspace();
      repo = PeriodRepository(workspace: ws);
    });

    test('generates human-readable filename for normal period', () async {
      await repo.savePeriod(
        _period(
          id: '1234-uuid',
          name: 'October 2025 Budget',
          startDate: DateTime(2025, 10, 1),
        ),
      );

      expect(await ws.listFiles(), ['2025-10-october_2025_budget.yaml']);
    });

    test('generates filename for template', () async {
      await repo.savePeriod(
        _period(
          id: '5678-uuid',
          name: 'My Custom Template',
          startDate: DateTime(2025, 1, 1),
        ),
      );

      expect(await ws.listFiles(), ['my_custom_template.yaml']);
    });

    test('filenameForPeriod returns the physical filename after save and load',
        () async {
      await repo.savePeriod(_period(id: 'abc-uuid', name: 'March 2026'));
      expect(repo.filenameForPeriod('abc-uuid'), '2026-03-march_2026.yaml');

      final freshRepo = PeriodRepository(workspace: ws);
      expect(freshRepo.filenameForPeriod('abc-uuid'), isNull);
      await freshRepo.loadAllPeriods();
      expect(
        freshRepo.filenameForPeriod('abc-uuid'),
        '2026-03-march_2026.yaml',
      );
    });

    test('handles empty or special character names gracefully', () async {
      await repo.savePeriod(
        _period(
          id: 'uuid-1111',
          name: '!!! --- ***',
          startDate: DateTime(2026, 3, 5),
        ),
      );

      expect(await ws.listFiles(), ['2026-03-uuid-1111.yaml']);
    });

    test('loadAll reports malformed YAML and still returns valid periods',
        () async {
      await repo.savePeriod(_period(id: 'good-uuid', name: 'March 2026'));
      await ws.writeString('broken.yaml', 'foo: [1, 2');

      final result = await PeriodRepository(workspace: ws).loadAll();

      expect(result.periods.map((p) => p.id), ['good-uuid']);
      expect(result.failures.length, 1);
      expect(result.failures.single.fileName, 'broken.yaml');
      expect(result.failures.single.location, 'in-memory/broken.yaml');
      expect(result.failures.single.message, contains('line 1'));
    });

    test('loadAll reports a document whose top level is not a mapping',
        () async {
      await ws.writeString('list.yaml', '- one\n- two\n');

      final result = await repo.loadAll();

      expect(result.periods, isEmpty);
      expect(result.failures.single.fileName, 'list.yaml');
      expect(result.failures.single.message, contains('not a mapping'));
    });

    test('loadAll reports a period with an invalid field', () async {
      await ws.writeString(
        'bad_field.yaml',
        'id: x\nname: y\nstart_date: not-a-date\n',
      );

      final result = await repo.loadAll();

      expect(result.periods, isEmpty);
      expect(result.failures.single.fileName, 'bad_field.yaml');
    });

    test('loadAll ignores files that are not yaml', () async {
      await ws.writeString('current_stats.md', '# stats');

      final result = await repo.loadAll();

      expect(result.periods, isEmpty);
      expect(result.failures, isEmpty);
    });

    test('loadAll skips conflict side files so ids stay unique', () async {
      await repo.savePeriod(_period(id: 'dup-uuid', name: 'March 2026'));
      final content = await ws.readString('2026-03-march_2026.yaml');
      await ws.writeString(
        '2026-03-march_2026.conflict-2026-09-16-1432.yaml',
        content,
      );

      final result = await PeriodRepository(workspace: ws).loadAll();

      expect(result.periods.map((p) => p.id), ['dup-uuid']);
      expect(result.failures, isEmpty);
    });

    test('savePeriod does not reuse the filename of a file that failed to load',
        () async {
      await ws.writeString('2026-03-march_2026.yaml', 'foo: [1, 2');
      await repo.loadAll();

      await repo.savePeriod(_period(id: 'new-uuid', name: 'March 2026'));

      expect(await ws.readString('2026-03-march_2026.yaml'), 'foo: [1, 2');
      expect(
        repo.filenameForPeriod('new-uuid'),
        isNot('2026-03-march_2026.yaml'),
      );
    });

    test('deletes legacy file when saving with new filename', () async {
      await ws.writeString('legacy-uuid.yaml', 'fake content');

      await repo.savePeriod(
        _period(id: 'legacy-uuid', name: 'March 2026 update'),
      );

      expect(await ws.listFiles(), ['2026-03-march_2026_update.yaml']);
    });
  });
}
