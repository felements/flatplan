import 'package:flatplan/src/storage/vault_workspace.dart';
import 'package:flatplan/src/sync/conflict_policy.dart';
import 'package:flatplan/src/sync/lock.dart';
import 'package:flatplan/src/sync/sync_engine.dart';
import 'package:flatplan/src/sync/sync_journal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'in_memory_remote_store.dart';

/// A mirror whose reads and writes can pause, so a test can inject a
/// concurrent write exactly while the engine is inside its
/// compare-and-resolve block, or inside the write of a clean pulled file.
class _PausingWorkspace extends MemoryWorkspace {
  _PausingWorkspace({required super.files});

  Future<void> Function(String name)? onRead;
  Future<void> Function(String name)? onWrite;

  @override
  Future<String> readString(String name) async {
    await onRead?.call(name);
    return super.readString(name);
  }

  @override
  Future<void> writeString(String name, String content) async {
    await onWrite?.call(name);
    return super.writeString(name, content);
  }
}

void main() {
  test('a local write during pull resolution keeps the name dirty', () async {
    final files = <String, String>{};
    final journal = SyncJournal();
    final lock = Lock();
    final mirror = _PausingWorkspace(files: files);
    final app = MemoryWorkspace(files: files, changeListener: journal, lock: lock);
    final remote = InMemoryRemoteStore();
    final engine = SyncEngine(
      mirror: mirror,
      remote: remote,
      journal: journal,
      policy: ConflictPolicy(timestampOf: periodLastModified),
      lock: lock,
    );

    remote.seed('a.yaml', 'v1');
    files['a.yaml'] = 'v1';
    journal.dirty.add('a.yaml');

    Future<void>? pendingWrite;
    var writeDone = false;
    mirror.onRead = (name) async {
      if (pendingWrite != null) return;
      pendingWrite = app.writeString('a.yaml', 'v2').then((_) => writeDone = true);
      await Future<void>.delayed(Duration.zero);
      expect(writeDone, isFalse, reason: 'the write must wait for the lock');
    };

    final failure = await engine.pull();
    await pendingWrite;

    expect(failure, isNull);
    expect(files['a.yaml'], 'v2');
    expect(journal.dirty, contains('a.yaml'));
  });

  test('a local write while a clean file is pulled is not overwritten', () async {
    final files = <String, String>{};
    final journal = SyncJournal();
    final lock = Lock();
    final mirror = _PausingWorkspace(files: files);
    final app = MemoryWorkspace(files: files, changeListener: journal, lock: lock);
    final remote = InMemoryRemoteStore();
    final engine = SyncEngine(
      mirror: mirror,
      remote: remote,
      journal: journal,
      policy: ConflictPolicy(timestampOf: periodLastModified),
      lock: lock,
    );

    // Not dirty: the engine takes the straight "write what the remote has"
    // path, which must still hold the lock.
    remote.seed('a.yaml', 'remote');

    Future<void>? pendingWrite;
    var writeDone = false;
    mirror.onWrite = (name) async {
      if (pendingWrite != null) return;
      expect(journal.dirty, isNot(contains('a.yaml')));
      pendingWrite = app.writeString('a.yaml', 'mine').then((_) => writeDone = true);
      await Future<void>.delayed(Duration.zero);
      expect(writeDone, isFalse, reason: 'the write must wait for the lock');
    };

    final failure = await engine.pull();
    await pendingWrite;

    expect(failure, isNull);
    expect(files['a.yaml'], 'mine', reason: 'the local save must survive the pull');
    expect(journal.dirty, contains('a.yaml'), reason: 'and still be pushed');
  });

  test('a local write during push snapshot keeps the name dirty', () async {
    final files = <String, String>{};
    final journal = SyncJournal();
    final lock = Lock();
    final mirror = _PausingWorkspace(files: files);
    final app = MemoryWorkspace(files: files, changeListener: journal, lock: lock);
    final remote = InMemoryRemoteStore();
    final engine = SyncEngine(
      mirror: mirror,
      remote: remote,
      journal: journal,
      policy: ConflictPolicy(timestampOf: periodLastModified),
      lock: lock,
    );

    await app.writeString('a.yaml', 'v1');

    Future<void>? pendingWrite;
    mirror.onRead = (name) async {
      if (pendingWrite != null) return;
      pendingWrite = app.writeString('a.yaml', 'v2');
      await Future<void>.delayed(Duration.zero);
    };

    final failure = await engine.push();
    await pendingWrite;

    expect(failure, isNull);
    expect(remote.files['a.yaml']!.content, 'v1');
    expect(files['a.yaml'], 'v2');
    expect(journal.dirty, contains('a.yaml'), reason: 'v2 still has to be pushed');
  });
}
