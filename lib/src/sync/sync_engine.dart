import 'dart:async';
import 'dart:io';

import '../storage/vault_workspace.dart';
import 'conflict_policy.dart';
import 'remote_store.dart';
import 'sync_journal.dart';

/// Why a pull or push did not complete. Nothing is lost either way: the
/// journal keeps every dirty name and the next trigger tries again.
class SyncFailure {
  final String message;

  /// True for connectivity problems, which the UI shows as "Offline"
  /// rather than as an error.
  final bool isOffline;

  const SyncFailure({required this.message, required this.isOffline});

  factory SyncFailure.from(Object error) => SyncFailure(
    message: error.toString(),
    isOffline:
        error is SocketException ||
        error is TimeoutException ||
        error is HttpException,
  );
}

/// Moves files between the local mirror and a [RemoteStore].
///
/// [mirror] must be the workspace *without* the journal as its change
/// listener: the engine records dirtiness itself, and pulled files must
/// not become dirty.
class SyncEngine {
  static const maxConflictRounds = 3;

  final VaultWorkspace mirror;
  final RemoteStore remote;
  final SyncJournal journal;
  final ConflictPolicy policy;

  SyncEngine({
    required this.mirror,
    required this.remote,
    required this.journal,
    required this.policy,
  });

  /// Brings the mirror up to date with the remote. Never throws.
  Future<SyncFailure?> pull() async {
    try {
      await _pull();
      journal.lastError = null;
      await journal.save();
      return null;
    } catch (e) {
      return _recordFailure(e);
    }
  }

  /// Sends every dirty file to the remote as one batch. Lands in Task 8.
  Future<SyncFailure?> push() => throw UnimplementedError();

  Future<SyncFailure> _recordFailure(Object error) async {
    final failure = SyncFailure.from(error);
    journal.lastError = failure.message;
    await journal.save();
    return failure;
  }

  Future<void> _pull() async {
    if (journal.needsFullRescan) {
      journal.dirty.addAll(await mirror.listFiles());
      journal.needsFullRescan = false;
      await journal.save();
    }

    final tree = await remote.listTree();

    for (final entry in tree.entries) {
      final name = entry.key;
      final version = entry.value;
      if (journal.baseline[name]?.version == version) continue;

      final remoteFile = await remote.read(name);
      final remoteEntry = JournalEntry(
        version: version,
        contentHash: contentHash(remoteFile.content),
      );

      if (!journal.dirty.contains(name)) {
        await mirror.writeString(name, remoteFile.content);
        journal.baseline[name] = remoteEntry;
        continue;
      }

      final local =
          await mirror.exists(name) ? await mirror.readString(name) : null;
      if (local == remoteFile.content) {
        // An interrupted earlier push already landed this file.
        journal.dirty.remove(name);
      } else {
        await _resolveConflict(name, local, remoteFile.content);
      }
      journal.baseline[name] = remoteEntry;
    }

    for (final name in journal.baseline.keys.toList()) {
      if (tree.containsKey(name)) continue;
      journal.baseline.remove(name);
      if (journal.dirty.contains(name)) continue; // push re-creates it
      await mirror.delete(name);
    }

    journal.lastPullAt = policy.now();
    await journal.save();
  }

  /// [local] is null when the file was deleted locally.
  Future<void> _resolveConflict(
    String name,
    String? local,
    String remoteContent,
  ) async {
    if (local == null) {
      // Deleted here, edited there: keeping the edit loses nothing.
      await mirror.writeString(name, remoteContent);
      journal.dirty.remove(name);
      return;
    }
    if (policy.derivedFiles.contains(name)) return; // local wins, stays dirty

    final localTs = policy.timestampOf(name, local);
    final remoteTs = policy.timestampOf(name, remoteContent);
    final remoteWins =
        localTs != null && remoteTs != null && remoteTs.isAfter(localTs);

    final sideName = conflictFileName(name, policy.now());
    if (remoteWins) {
      await mirror.writeString(sideName, local);
      await mirror.writeString(name, remoteContent);
      journal.dirty.remove(name);
    } else {
      await mirror.writeString(sideName, remoteContent);
    }
    journal.dirty.add(sideName);
  }
}
