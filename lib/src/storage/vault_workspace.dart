import 'dart:io';

import 'package:path/path.dart' as p;

/// Told about every write and delete in a workspace, before it happens.
///
/// The sync journal implements this to mark a file dirty, so a crash a
/// millisecond after the write still leaves the change scheduled.
abstract interface class WorkspaceChangeListener {
  Future<void> onChanged(String name);
}

/// The only surface domain storage code uses to touch a vault's files.
///
/// Flat: names are plain file names, there are no subfolders.
abstract interface class VaultWorkspace {
  /// Human-readable location for the UI and error messages.
  String get displayPath;

  /// Names of regular files, sorted. Empty when nothing exists yet.
  Future<List<String>> listFiles();

  Future<bool> exists(String name);

  /// Throws when [name] does not exist.
  Future<String> readString(String name);

  /// Creates the folder when needed.
  Future<void> writeString(String name, String content);

  /// A no-op when [name] does not exist.
  Future<void> delete(String name);
}

/// A workspace over a real folder. Used both for the user's own folder and
/// for the app-private mirror of a remote vault; the [changeListener] is
/// the only difference between the two.
class DirectoryWorkspace implements VaultWorkspace {
  final String path;
  final WorkspaceChangeListener? changeListener;

  DirectoryWorkspace(this.path, {this.changeListener});

  @override
  String get displayPath => path;

  File _file(String name) => File(p.join(path, name));

  @override
  Future<List<String>> listFiles() async {
    final dir = Directory(path);
    if (!await dir.exists()) return const [];
    final names = <String>[];
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is File) names.add(p.basename(entity.path));
    }
    names.sort();
    return names;
  }

  @override
  Future<bool> exists(String name) => _file(name).exists();

  @override
  Future<String> readString(String name) => _file(name).readAsString();

  @override
  Future<void> writeString(String name, String content) async {
    await changeListener?.onChanged(name);
    final dir = Directory(path);
    if (!await dir.exists()) await dir.create(recursive: true);
    await _file(name).writeAsString(content, flush: true);
  }

  @override
  Future<void> delete(String name) async {
    final file = _file(name);
    if (!await file.exists()) return;
    await changeListener?.onChanged(name);
    await file.delete();
  }
}

/// An in-memory workspace for tests.
class MemoryWorkspace implements VaultWorkspace {
  /// Pass a shared [files] map to give two instances one view of the same
  /// data, e.g. an unlistened mirror and a journal-listened app workspace.
  final Map<String, String> files;
  final WorkspaceChangeListener? changeListener;

  MemoryWorkspace({Map<String, String>? files, this.changeListener})
    : files = files ?? {};

  @override
  String get displayPath => 'in-memory';

  @override
  Future<List<String>> listFiles() async => files.keys.toList()..sort();

  @override
  Future<bool> exists(String name) async => files.containsKey(name);

  @override
  Future<String> readString(String name) async {
    final content = files[name];
    if (content == null) {
      throw FileSystemException('File not found', name);
    }
    return content;
  }

  @override
  Future<void> writeString(String name, String content) async {
    await changeListener?.onChanged(name);
    files[name] = content;
  }

  @override
  Future<void> delete(String name) async {
    if (!files.containsKey(name)) return;
    await changeListener?.onChanged(name);
    files.remove(name);
  }
}
