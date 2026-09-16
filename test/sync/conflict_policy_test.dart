import 'package:flatplan/src/sync/conflict_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('periodLastModified reads last_modified from period yaml', () {
    final ts = periodLastModified(
      '2026-09-september.yaml',
      'id: p1\nlast_modified: 2026-09-10T08:30:00.000\nname: September\n',
    );

    expect(ts, DateTime(2026, 9, 10, 8, 30));
  });

  test('periodLastModified is null for non-yaml, broken yaml, or no field', () {
    expect(periodLastModified('current_stats.md', 'last_modified: x'), isNull);
    expect(periodLastModified('a.yaml', 'foo: [1, 2'), isNull);
    expect(periodLastModified('a.yaml', 'id: p1\n'), isNull);
    expect(periodLastModified('a.yaml', '- a\n- b\n'), isNull);
  });

  test('periodConflictPolicy treats the stats file as derived', () {
    expect(periodConflictPolicy.derivedFiles, {'current_stats.md'});
  });

  test('conflictFileName keeps stem and extension around a timestamp', () {
    expect(
      conflictFileName('2026-09-september.yaml', DateTime(2026, 9, 16, 14, 32)),
      '2026-09-september.conflict-2026-09-16-1432.yaml',
    );
    expect(
      conflictFileName('notes', DateTime(2026, 1, 2, 3, 4)),
      'notes.conflict-2026-01-02-0304',
    );
  });
}
