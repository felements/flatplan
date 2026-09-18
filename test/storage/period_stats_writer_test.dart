import 'package:flatplan/src/storage/period_stats_writer.dart';
import 'package:flatplan/src/storage/vault_workspace.dart';
import 'package:flutter_test/flutter_test.dart';

/// Counts every write the workspace is told about, the way the sync
/// journal would mark a file dirty.
class _CountingListener implements WorkspaceChangeListener {
  final List<String> changed = [];

  @override
  Future<void> onChanged(String name) async => changed.add(name);
}

const _v1 = '# Budget Stats\n\n- Today: 2026-09-19 (day 19 of 30)\n'
    '- Generated: 2026-09-19 10:00\n- Spent: 120\n';
const _v1Later = '# Budget Stats\n\n- Today: 2026-09-19 (day 19 of 30)\n'
    '- Generated: 2026-09-19 10:45\n- Spent: 120\n';
const _v2 = '# Budget Stats\n\n- Today: 2026-09-19 (day 19 of 30)\n'
    '- Generated: 2026-09-19 10:50\n- Spent: 150\n';

void main() {
  late _CountingListener listener;
  late MemoryWorkspace workspace;
  late PeriodStatsWriter writer;

  setUp(() {
    listener = _CountingListener();
    workspace = MemoryWorkspace(changeListener: listener);
    writer = PeriodStatsWriter(workspace: workspace);
  });

  test('the first write lands', () async {
    await writer.writeStatsFile(_v1);

    expect(await workspace.readString(PeriodStatsWriter.fileName), _v1);
    expect(listener.changed, [PeriodStatsWriter.fileName]);
  });

  test('a rewrite that only moves the generation time is skipped', () async {
    await writer.writeStatsFile(_v1);
    await writer.writeStatsFile(_v1Later);

    expect(await workspace.readString(PeriodStatsWriter.fileName), _v1);
    expect(listener.changed, hasLength(1), reason: 'no dirty mark, no commit');
  });

  test('a rewrite with a real change lands', () async {
    await writer.writeStatsFile(_v1);
    await writer.writeStatsFile(_v2);

    expect(await workspace.readString(PeriodStatsWriter.fileName), _v2);
    expect(listener.changed, hasLength(2));
  });

  test('sameExceptGenerated ignores only the Generated line', () {
    expect(PeriodStatsWriter.sameExceptGenerated(_v1, _v1Later), isTrue);
    expect(PeriodStatsWriter.sameExceptGenerated(_v1, _v2), isFalse);
    expect(PeriodStatsWriter.sameExceptGenerated('', _v1), isFalse);
  });
}
