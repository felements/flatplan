import 'dart:io';

import 'package:flatplan/src/sync/remote_store.dart';

/// A [RemoteStore] held in memory, with knobs to simulate another device,
/// a lost connection mid-batch, and being offline.
class InMemoryRemoteStore implements RemoteStore {
  final Map<String, RemoteFile> files = {};
  int _counter = 0;

  /// When set, [writeBatch] throws a [SocketException] after applying this
  /// many changes, like a non-atomic store losing the connection.
  int? failAfterWrites;

  /// When set, every call throws it, like being offline.
  Object? failure;

  /// When true, [writeBatch] applies the changes but returns no versions,
  /// like a store whose write response carries no revision id.
  bool omitVersions = false;

  /// Runs inside [writeBatch] before anything is applied, so a test can
  /// simulate a local edit landing while a push is in flight.
  Future<void> Function()? onWriteBatch;

  /// Runs inside [listTree] before it returns, so a test can simulate a
  /// pull that is still in flight.
  Future<void> Function()? onListTree;

  /// Every call, for asserting how many round trips the engine made.
  final List<String> calls = [];

  String _nextVersion() => 'v${++_counter}';

  /// Another device wrote this file directly.
  void seed(String name, String content) {
    files[name] = RemoteFile(content: content, version: _nextVersion());
  }

  /// Another device deleted this file directly.
  void remove(String name) => files.remove(name);

  void _checkFailure() {
    final f = failure;
    if (f != null) throw f;
  }

  @override
  Future<Map<String, String>> listTree() async {
    _checkFailure();
    await onListTree?.call();
    calls.add('listTree');
    return {for (final e in files.entries) e.key: e.value.version};
  }

  @override
  Future<RemoteFile> read(String name) async {
    _checkFailure();
    calls.add('read $name');
    final file = files[name];
    if (file == null) throw StateError('remote has no $name');
    return file;
  }

  @override
  Future<Map<String, String>> writeBatch(List<RemoteChange> changes) async {
    _checkFailure();
    calls.add('writeBatch ${changes.length}');
    await onWriteBatch?.call();

    final stale = [
      for (final change in changes)
        if (files[change.name]?.version != change.expectedVersion) change.name,
    ];
    if (stale.isNotEmpty) throw RemoteConflict(stale);

    final versions = <String, String>{};
    var applied = 0;
    for (final change in changes) {
      final limit = failAfterWrites;
      if (limit != null && applied >= limit) {
        throw const SocketException('connection lost mid-batch');
      }
      switch (change) {
        case RemotePut():
          final version = _nextVersion();
          files[change.name] =
              RemoteFile(content: change.content, version: version);
          versions[change.name] = version;
        case RemoteDelete():
          files.remove(change.name);
      }
      applied++;
    }
    return omitVersions ? const {} : versions;
  }
}
