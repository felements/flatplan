import 'dart:async';
import 'dart:io';

import 'package:flatplan/src/storage/vault_workspace.dart';
import 'package:flatplan/src/sync/conflict_policy.dart';
import 'package:flatplan/src/sync/remote_store.dart';
import 'package:flatplan/src/sync/sync_engine.dart';
import 'package:flatplan/src/sync/sync_journal.dart';
import 'package:flatplan/src/sync/sync_scheduler.dart';
import 'package:flatplan/src/sync/sync_status.dart';
import 'package:flutter_test/flutter_test.dart';

import 'in_memory_remote_store.dart';

void main() {
  late Map<String, String> files;
  late MemoryWorkspace app;
  late SyncJournal journal;
  late InMemoryRemoteStore remote;
  late SyncScheduler scheduler;
  late List<SyncStatus> statuses;

  setUp(() {
    files = {};
    journal = SyncJournal();
    app = MemoryWorkspace(files: files, changeListener: journal);
    remote = InMemoryRemoteStore();
    statuses = [];
    scheduler = SyncScheduler(
      engine: SyncEngine(
        mirror: MemoryWorkspace(files: files),
        remote: remote,
        journal: journal,
        policy: periodConflictPolicy,
      ),
      onStatus: statuses.add,
      idleDelay: const Duration(milliseconds: 30),
      switchTimeout: const Duration(milliseconds: 50),
    );
    journal.onDirty = scheduler.noteChange;
  });

  tearDown(() => scheduler.dispose());

  test('pushes once after the idle delay following the last change', () async {
    await app.writeString('a.yaml', 'a');
    await Future<void>.delayed(const Duration(milliseconds: 15));
    await app.writeString('b.yaml', 'b');
    expect(remote.calls, isEmpty);

    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(remote.calls.where((c) => c.startsWith('writeBatch')), ['writeBatch 2']);
    expect(scheduler.status.state, SyncState.idle);
    expect(scheduler.status.dirtyCount, 0);
  });

  test('reports the dirty count as soon as a change is noted', () async {
    await app.writeString('a.yaml', 'a');

    expect(statuses.last.dirtyCount, 1);
    expect(statuses.last.state, SyncState.idle);
  });

  test('syncNow pushes immediately and reports syncing then idle', () async {
    await app.writeString('a.yaml', 'a');

    await scheduler.syncNow();

    expect(statuses.map((s) => s.state), containsAllInOrder([SyncState.syncing, SyncState.idle]));
    expect(await remote.listTree(), hasLength(1));
  });

  test('onAppPaused pushes without waiting for the idle delay', () async {
    await app.writeString('a.yaml', 'a');

    await scheduler.onAppPaused();

    expect(await remote.listTree(), hasLength(1));
  });

  test('pullNow pulls', () async {
    remote.seed('a.yaml', 'x');

    await scheduler.pullNow();

    expect(files['a.yaml'], 'x');
  });

  test('offline failure shows as offline and keeps changes', () async {
    await app.writeString('a.yaml', 'a');
    remote.failure = const SocketException('down');

    await scheduler.syncNow();

    expect(scheduler.status.state, SyncState.offline);
    expect(scheduler.status.dirtyCount, 1);
  });

  test('a trigger during a run queues exactly one re-run', () async {
    await app.writeString('a.yaml', 'a');
    final gate = Completer<void>();
    remote.onWriteBatch = () => gate.future;

    final first = scheduler.syncNow();
    await Future<void>.delayed(Duration.zero);
    final second = scheduler.syncNow();
    final third = scheduler.syncNow();
    remote.onWriteBatch = null;
    gate.complete();
    await Future.wait([first, second, third]);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    // One batch carried the change; the queued re-run found nothing dirty
    // and made no remote call, but it did run: syncing was reported twice.
    expect(remote.calls.where((c) => c.startsWith('writeBatch')), hasLength(1));
    expect(statuses.where((s) => s.state == SyncState.syncing).length, 2);
  });

  test('syncNow on a clean vault pulls', () async {
    remote.seed('a.yaml', 'x');

    await scheduler.syncNow();

    expect(files['a.yaml'], 'x');
    expect(remote.calls, ['listTree', 'read a.yaml']);
  });

  test('a pullNow queued behind a running push still pulls afterwards', () async {
    await app.writeString('a.yaml', 'a');
    final gate = Completer<void>();
    remote.onWriteBatch = () => gate.future;

    final push = scheduler.syncNow();
    await Future<void>.delayed(Duration.zero);
    final pull = scheduler.pullNow();
    remote.onWriteBatch = null;
    gate.complete();
    await Future.wait([push, pull]);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(remote.calls.where((c) => c == 'listTree').length, 2);
    expect(remote.calls.where((c) => c.startsWith('writeBatch')), hasLength(1));
  });

  test('noteChange keeps an offline status', () async {
    await app.writeString('a.yaml', 'a');
    remote.failure = const SocketException('down');
    await scheduler.syncNow();
    expect(scheduler.status.state, SyncState.offline);

    await app.writeString('b.yaml', 'b');

    expect(scheduler.status.state, SyncState.offline);
    expect(scheduler.status.dirtyCount, 2);
  });

  test('flushBeforeSwitch returns after the timeout even if the push hangs',
      () async {
    await app.writeString('a.yaml', 'a');
    remote.onWriteBatch = () => Completer<void>().future;

    final stopwatch = Stopwatch()..start();
    await scheduler.flushBeforeSwitch();

    expect(stopwatch.elapsedMilliseconds, lessThan(500));
  });

  test('flushBeforeSwitch waits for a running pull and then pushes', () async {
    final gate = Completer<void>();
    remote.onListTree = () => gate.future;
    final pull = scheduler.pullNow();
    await Future<void>.delayed(Duration.zero);
    await app.writeString('a.yaml', 'a');
    remote.onListTree = null;
    Future<void>.delayed(const Duration(milliseconds: 10), gate.complete);

    await scheduler.flushBeforeSwitch();
    await pull;

    expect((await remote.listTree()).keys, contains('a.yaml'));
  });

  test('dispose cancels a pending idle push', () async {
    await app.writeString('a.yaml', 'a');
    scheduler.dispose();

    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(remote.calls, isEmpty);
  });

  test('a rejected token marks the status as needing attention', () async {
    remote.failure = const RemoteAuthRejected('GitLab rejected the token.');
    await app.writeString('a.yaml', 'a');

    await scheduler.syncNow();

    expect(scheduler.status.state, SyncState.error);
    expect(scheduler.status.needsAttention, isTrue);
    expect(scheduler.status.lastError, 'GitLab rejected the token.');
  });

  test('being offline does not need attention', () async {
    remote.failure = const SocketException('down');
    await app.writeString('a.yaml', 'a');

    await scheduler.syncNow();

    expect(scheduler.status.state, SyncState.offline);
    expect(scheduler.status.needsAttention, isFalse);
  });
}
