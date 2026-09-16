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
  late MemoryWorkspace mirror;
  late MemoryWorkspace app;
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

  test('nothing dirty: push makes no remote calls', () async {
    final failure = await engine.push();

    expect(failure, isNull);
    expect(remote.calls, isEmpty);
  });

  test('pushes new files as one batch and records their versions', () async {
    await app.writeString('a.yaml', 'a');
    await app.writeString('b.yaml', 'b');

    final failure = await engine.push();

    expect(failure, isNull);
    expect(remote.calls.where((c) => c.startsWith('writeBatch')), ['writeBatch 2']);
    expect((await remote.read('a.yaml')).content, 'a');
    expect(journal.dirty, isEmpty);
    expect(journal.baseline['a.yaml']!.version, (await remote.listTree())['a.yaml']);
    expect(journal.baseline['a.yaml']!.contentHash, contentHash('a'));
    expect(journal.lastPushAt, fixedNow);
  });

  test('pushes a local delete as a remote delete', () async {
    remote.seed('a.yaml', 'x');
    await engine.pull();
    await app.delete('a.yaml');

    await engine.push();

    expect(await remote.listTree(), isEmpty);
    expect(journal.baseline, isEmpty);
    expect(journal.dirty, isEmpty);
  });

  test('a file created and deleted before any push is simply forgotten',
      () async {
    await app.writeString('tmp.yaml', 'x');
    await app.delete('tmp.yaml');

    await engine.push();

    expect(journal.dirty, isEmpty);
    expect(remote.calls.where((c) => c.startsWith('writeBatch')), isEmpty);
  });

  test('an interrupted push leaves everything dirty, and a re-run heals',
      () async {
    await app.writeString('a.yaml', 'a');
    await app.writeString('b.yaml', 'b');
    remote.failAfterWrites = 1;

    final first = await engine.push();

    expect(first, isNotNull);
    expect(first!.isOffline, isTrue);
    expect(journal.dirty, {'a.yaml', 'b.yaml'});
    expect(journal.lastError, isNotNull);

    remote.failAfterWrites = null;
    remote.calls.clear();
    final second = await engine.push();

    expect(second, isNull);
    expect(remote.calls.last, 'writeBatch 1'); // only the file still missing
    expect(await remote.listTree(), hasLength(2));
    expect(journal.dirty, isEmpty);
    expect(journal.lastError, isNull);
  });

  test('a remote conflict triggers a re-pull and a second attempt', () async {
    remote.seed('p.yaml', period('2026-09-01T00:00:00'));
    await engine.pull();
    await app.writeString('p.yaml', period('2026-09-12T00:00:00', note: 'local'));
    // Another device commits between our pull and our write.
    remote.onWriteBatch = () async {
      if (remote.calls.where((c) => c.startsWith('writeBatch')).length == 1) {
        remote.seed('p.yaml', period('2026-09-05T00:00:00', note: 'other'));
      }
    };

    final failure = await engine.push();

    expect(failure, isNull);
    expect(remote.calls.where((c) => c.startsWith('writeBatch')), hasLength(2));
    expect((await remote.read('p.yaml')).content, contains('local'));
    expect(files['p.conflict-2026-09-16-1432.yaml'], contains('other'));
    expect((await remote.listTree()).keys, contains('p.conflict-2026-09-16-1432.yaml'));
  });

  test('gives up after three conflict rounds and keeps everything dirty',
      () async {
    await app.writeString('a.yaml', 'mine');
    remote.onWriteBatch = () async => remote.seed('a.yaml', 'theirs-${remote.calls.length}');

    final failure = await engine.push();

    expect(failure, isNotNull);
    expect(failure!.isOffline, isFalse);
    expect(remote.calls.where((c) => c.startsWith('writeBatch')), hasLength(3));
    expect(journal.dirty, contains('a.yaml'));
  });

  test('a local edit during the push keeps that file dirty', () async {
    await app.writeString('a.yaml', 'v1');
    remote.onWriteBatch = () async => app.writeString('a.yaml', 'v2');

    await engine.push();

    expect((await remote.read('a.yaml')).content, 'v1');
    expect(journal.dirty, {'a.yaml'});
    expect(journal.baseline['a.yaml']!.contentHash, contentHash('v1'));
  });

  test('offline: dirty set untouched, error recorded', () async {
    await app.writeString('a.yaml', 'a');
    remote.failure = const SocketException('offline');

    final failure = await engine.push();

    expect(failure!.isOffline, isTrue);
    expect(journal.dirty, {'a.yaml'});
  });
}
