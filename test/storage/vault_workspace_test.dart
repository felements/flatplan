import 'dart:io';

import 'package:flatplan/src/storage/vault_workspace.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'workspace_contract.dart';

/// Records each notification and whether the file existed at that moment,
/// which proves the mark happens before the write lands.
class _RecordingListener implements WorkspaceChangeListener {
  _RecordingListener(this.dir);
  final String dir;
  final List<String> names = [];
  final List<bool> existedAtNotify = [];

  @override
  Future<void> onChanged(String name) async {
    names.add(name);
    existedAtNotify.add(File(p.join(dir, name)).existsSync());
  }
}

void main() {
  runWorkspaceContract('MemoryWorkspace', () async => MemoryWorkspace());

  group('DirectoryWorkspace', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('flatplan_ws_');
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    runWorkspaceContract(
      'DirectoryWorkspace',
      () async => DirectoryWorkspace(p.join(tempDir.path, 'files')),
    );

    test('creates the folder on first write', () async {
      final dir = p.join(tempDir.path, 'fresh');
      final ws = DirectoryWorkspace(dir);
      expect(Directory(dir).existsSync(), isFalse);

      await ws.writeString('a.yaml', 'x');

      expect(File(p.join(dir, 'a.yaml')).readAsStringSync(), 'x');
    });

    test('lists only regular files, not subfolders', () async {
      final ws = DirectoryWorkspace(tempDir.path);
      Directory(p.join(tempDir.path, 'sub')).createSync();
      await ws.writeString('a.yaml', 'x');

      expect(await ws.listFiles(), ['a.yaml']);
    });

    test('displayPath is the folder path', () {
      expect(DirectoryWorkspace('/tmp/x').displayPath, '/tmp/x');
    });

    test('notifies the listener before a write lands and on delete', () async {
      final listener = _RecordingListener(tempDir.path);
      final ws = DirectoryWorkspace(tempDir.path, changeListener: listener);

      await ws.writeString('a.yaml', 'x');
      expect(listener.names, ['a.yaml']);
      expect(listener.existedAtNotify, [false]);

      await ws.delete('a.yaml');
      expect(listener.names, ['a.yaml', 'a.yaml']);
    });

    test('does not notify when deleting a missing file', () async {
      final listener = _RecordingListener(tempDir.path);
      final ws = DirectoryWorkspace(tempDir.path, changeListener: listener);

      await ws.delete('missing.yaml');

      expect(listener.names, isEmpty);
    });
  });

  group('MemoryWorkspace', () {
    test('notifies the listener on write and delete', () async {
      final calls = <String>[];
      final ws = MemoryWorkspace(changeListener: _CallbackListener(calls.add));

      await ws.writeString('a.yaml', 'x');
      await ws.delete('a.yaml');
      await ws.delete('a.yaml');

      expect(calls, ['a.yaml', 'a.yaml']);
    });

    test('two instances over one map see each other\'s files', () async {
      final shared = <String, String>{};
      final a = MemoryWorkspace(files: shared);
      final b = MemoryWorkspace(files: shared);

      await a.writeString('x.yaml', 'from a');

      expect(await b.readString('x.yaml'), 'from a');
      await b.delete('x.yaml');
      expect(await a.exists('x.yaml'), isFalse);
    });
  });
}

class _CallbackListener implements WorkspaceChangeListener {
  _CallbackListener(this.callback);
  final void Function(String) callback;

  @override
  Future<void> onChanged(String name) async => callback(name);
}
