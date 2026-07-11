import 'dart:io';

import 'package:macos_secure_bookmarks/macos_secure_bookmarks.dart';

/// Thin abstraction over macOS security-scoped bookmarks.
///
/// Sandboxed macOS apps only get access to a user-selected folder for the
/// current launch. To keep access across restarts the folder must be stored
/// as a security-scoped bookmark and re-opened on the next launch. This
/// interface isolates that platform-channel behaviour so the storage logic
/// (and its fallback handling) can be unit-tested with a fake.
abstract interface class SecurityScopedBookmarks {
  /// Creates a persistable bookmark string granting future access to [path].
  Future<String> bookmarkForPath(String path);

  /// Resolves a previously created [bookmark] back into a directory path.
  Future<String> resolvePath(String bookmark);

  /// Re-establishes access to [path]. Returns `true` on success.
  Future<bool> startAccessing(String path);
}

/// Real implementation backed by the `macos_secure_bookmarks` plugin.
class MacosSecurityScopedBookmarks implements SecurityScopedBookmarks {
  final SecureBookmarks _bookmarks = SecureBookmarks();

  @override
  Future<String> bookmarkForPath(String path) =>
      _bookmarks.bookmark(Directory(path));

  @override
  Future<String> resolvePath(String bookmark) async {
    final resolved = await _bookmarks.resolveBookmark(
      bookmark,
      isDirectory: true,
    );
    return resolved.path;
  }

  @override
  Future<bool> startAccessing(String path) =>
      _bookmarks.startAccessingSecurityScopedResource(Directory(path));
}
