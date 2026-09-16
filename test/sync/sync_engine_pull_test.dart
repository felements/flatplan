import 'dart:io';

import 'package:flatplan/src/storage/vault_workspace.dart';
import 'package:flatplan/src/sync/conflict_policy.dart';
import 'package:flatplan/src/sync/sync_engine.dart';
import 'package:flatplan/src/sync/sync_journal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'in_memory_remote_store.dart';

final fixedNow = DateTime(2026, 9, 16, 14, 32);

String period(String lastModified, {String note = ''}) =>
    'id: p1\nlast_modified: $lastModified\nnote: $note\n';

void main() {
  late Map<String, String> files;
  late MemoryWorkspace mirror; // unlistened, what the engine writes through
  late MemoryWorkspace app; // journal-listened, what the app writes through
  late SyncJournal journal;
  late InMemoryRemoteStore remote;
  late SyncEngine engine;

  setUp(() {
    files = {};
    journal = SyncJournal();
    mirror = MemoryWorkspace(files: files);
    app = MemoryWorkspace(files: files, changeListener: journal);
    remote = InMemoryRemoteStore();
    engine = SyncEngine(
      mirror: mirror,
      remote: remote,
      journal: journal,
      policy: ConflictPolicy(
        timestampOf: periodLastModified,
        derivedFiles: {'current_stats.md'},
        now: () => fixedNow,
      ),
    );
  });

  test('first pull copies every remote file into an empty mirror', () async {
    remote.seed('a.yaml', period('2026-09-01T00:00:00'));
    remote.seed('current_stats.md', '# stats');

    final failure = await engine.pull();

    expect(failure, isNull);
    expect(files.keys, containsAll(['a.yaml', 'current_stats.md']));
    expect(journal.baseline.keys, containsAll(['a.yaml', 'current_stats.md']));
    expect(journal.baseline['a.yaml']!.version, (await remote.listTree())['a.yaml']);
    expect(journal.dirty, isEmpty);
    expect(journal.lastPullAt, fixedNow);
  });

  test('a second pull reads only files whose version changed', () async {
    remote.seed('a.yaml', 'a1');
    remote.seed('b.yaml', 'b1');
    await engine.pull();
    remote.calls.clear();
    remote.seed('b.yaml', 'b2');

    await engine.pull();

    expect(remote.calls, ['listTree', 'read b.yaml']);
    expect(files['b.yaml'], 'b2');
  });

  test('remote change to a clean file replaces the mirror copy', () async {
    remote.seed('a.yaml', 'one');
    await engine.pull();
    remote.seed('a.yaml', 'two');

    await engine.pull();

    expect(files['a.yaml'], 'two');
    expect(journal.dirty, isEmpty);
  });

  test('a dirty file with identical remote content just adopts the version',
      () async {
    await app.writeString('a.yaml', 'same');
    remote.seed('a.yaml', 'same');

    await engine.pull();

    expect(journal.dirty, isEmpty);
    expect(journal.baseline['a.yaml']!.contentHash, contentHash('same'));
  });

  group('conflict, newest last_modified wins', () {
    test('remote newer: remote replaces local, local kept as side file',
        () async {
      remote.seed('p.yaml', period('2026-09-01T00:00:00'));
      await engine.pull();
      await app.writeString('p.yaml', period('2026-09-10T00:00:00', note: 'local'));
      remote.seed('p.yaml', period('2026-09-12T00:00:00', note: 'remote'));

      await engine.pull();

      expect(files['p.yaml'], period('2026-09-12T00:00:00', note: 'remote'));
      expect(
        files['p.conflict-2026-09-16-1432.yaml'],
        period('2026-09-10T00:00:00', note: 'local'),
      );
      expect(journal.dirty, {'p.conflict-2026-09-16-1432.yaml'});
      expect(journal.baseline['p.yaml']!.version, (await remote.listTree())['p.yaml']);
    });

    test('local newer: local stays dirty, remote kept as side file', () async {
      remote.seed('p.yaml', period('2026-09-01T00:00:00'));
      await engine.pull();
      await app.writeString('p.yaml', period('2026-09-12T00:00:00', note: 'local'));
      remote.seed('p.yaml', period('2026-09-10T00:00:00', note: 'remote'));

      await engine.pull();

      expect(files['p.yaml'], period('2026-09-12T00:00:00', note: 'local'));
      expect(
        files['p.conflict-2026-09-16-1432.yaml'],
        period('2026-09-10T00:00:00', note: 'remote'),
      );
      expect(journal.dirty, {'p.yaml', 'p.conflict-2026-09-16-1432.yaml'});
    });

    test('missing timestamp on either side: local wins with a side file',
        () async {
      remote.seed('notes.txt', 'v1');
      await engine.pull();
      await app.writeString('notes.txt', 'local');
      remote.seed('notes.txt', 'remote');

      await engine.pull();

      expect(files['notes.txt'], 'local');
      expect(files['notes.conflict-2026-09-16-1432.txt'], 'remote');
      expect(journal.dirty, {'notes.txt', 'notes.conflict-2026-09-16-1432.txt'});
    });

    test('derived file: local wins silently', () async {
      remote.seed('current_stats.md', 'v1');
      await engine.pull();
      await app.writeString('current_stats.md', 'local');
      remote.seed('current_stats.md', 'remote');

      await engine.pull();

      expect(files['current_stats.md'], 'local');
      expect(files.keys.where((k) => k.contains('.conflict-')), isEmpty);
      expect(journal.dirty, {'current_stats.md'});
    });

    test('deleted locally but edited remotely: remote copy is restored',
        () async {
      remote.seed('p.yaml', period('2026-09-01T00:00:00'));
      await engine.pull();
      await app.delete('p.yaml');
      remote.seed('p.yaml', period('2026-09-12T00:00:00'));

      await engine.pull();

      expect(files['p.yaml'], period('2026-09-12T00:00:00'));
      expect(journal.dirty, isEmpty);
    });
  });

  group('remote deletions', () {
    test('a clean file deleted remotely is deleted locally', () async {
      remote.seed('a.yaml', 'x');
      await engine.pull();
      remote.remove('a.yaml');

      await engine.pull();

      expect(files, isEmpty);
      expect(journal.baseline, isEmpty);
    });

    test('a dirty file deleted remotely is kept and will be re-created',
        () async {
      remote.seed('a.yaml', 'x');
      await engine.pull();
      await app.writeString('a.yaml', 'edited');
      remote.remove('a.yaml');

      await engine.pull();

      expect(files['a.yaml'], 'edited');
      expect(journal.baseline.containsKey('a.yaml'), isFalse);
      expect(journal.dirty, {'a.yaml'});
    });
  });

  test('a journal needing a full rescan marks every mirror file dirty first',
      () async {
    files['a.yaml'] = 'local';
    journal.needsFullRescan = true;
    remote.seed('a.yaml', 'remote');

    await engine.pull();

    expect(journal.needsFullRescan, isFalse);
    expect(files['a.yaml'], 'local'); // not silently overwritten
    expect(files['a.conflict-2026-09-16-1432.yaml'], 'remote');
  });

  test('a network error is reported as offline and recorded', () async {
    remote.failure = const SocketException('no route');

    final failure = await engine.pull();

    expect(failure, isNotNull);
    expect(failure!.isOffline, isTrue);
    expect(journal.lastError, contains('no route'));
  });

  test('a successful pull clears the last error', () async {
    journal.lastError = 'old';

    await engine.pull();

    expect(journal.lastError, isNull);
  });
}
