import 'package:flatplan/src/storage/security_scoped_bookmarks.dart';

/// Fake bookmark store that records calls and can be told to fail resolution,
/// so sandbox fallback logic is testable without the macOS platform channel.
class FakeBookmarks implements SecurityScopedBookmarks {
  FakeBookmarks({
    this.resolveThrows = false,
    this.startAccessingResult = true,
    this.resolvedPath,
  });

  bool resolveThrows;
  bool startAccessingResult;
  String? resolvedPath;

  final List<String> bookmarked = [];
  final List<String> accessed = [];

  @override
  Future<String> bookmarkForPath(String path) async {
    bookmarked.add(path);
    return 'bookmark::$path';
  }

  @override
  Future<String> resolvePath(String bookmark) async {
    if (resolveThrows) {
      throw const FormatException('stale bookmark');
    }
    return resolvedPath ?? bookmark.replaceFirst('bookmark::', '');
  }

  @override
  Future<bool> startAccessing(String path) async {
    accessed.add(path);
    return startAccessingResult;
  }
}
