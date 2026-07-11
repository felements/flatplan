import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'security_scoped_bookmarks.dart';

/// The resolved, usable data directory plus any access problem encountered
/// while resolving it.
class StorageDirectory {
  /// An accessible directory path safe to read/write. This is the user's
  /// configured folder when reachable, otherwise the default fallback.
  final String path;

  /// The folder the user configured (for display), even when access to it
  /// failed and [path] fell back to the default.
  final String? configuredPath;

  /// Whether [path] is the built-in default rather than a user choice.
  final bool isDefault;

  /// A human-readable reason the configured folder could not be used, or
  /// `null` when everything is fine. When set, the UI should prompt the user
  /// to re-select their folder.
  final String? accessError;

  const StorageDirectory({
    required this.path,
    this.configuredPath,
    this.isDefault = false,
    this.accessError,
  });

  @override
  bool operator ==(Object other) =>
      other is StorageDirectory &&
      other.path == path &&
      other.configuredPath == configuredPath &&
      other.isDefault == isDefault &&
      other.accessError == accessError;

  @override
  int get hashCode => Object.hash(path, configuredPath, isDefault, accessError);
}

/// Persists the user's chosen data directory and, on sandboxed macOS,
/// re-establishes access across app restarts via security-scoped bookmarks.
class StorageSettingsService {
  static const _key = 'data_directory';
  static const _bookmarkKey = 'data_directory_bookmark';

  /// Bookmark helper, or `null` on platforms that are not sandboxed here and
  /// can use the saved path directly.
  final SecurityScopedBookmarks? _bookmarks;

  /// Override for the default directory, used in tests.
  final Future<String> Function()? _defaultDirectoryOverride;

  StorageSettingsService({
    SecurityScopedBookmarks? bookmarks,
    bool? useBookmarks,
    Future<String> Function()? defaultDirectory,
  }) : _bookmarks = (useBookmarks ?? Platform.isMacOS)
           ? (bookmarks ?? MacosSecurityScopedBookmarks())
           : null,
       _defaultDirectoryOverride = defaultDirectory;

  /// Resolves the configured data directory into a usable, accessible path.
  ///
  /// On macOS this re-opens the user-selected folder through its stored
  /// security-scoped bookmark. If the folder can no longer be accessed
  /// (permission lost, moved, or deleted) it falls back to the default
  /// directory and reports the failure via [StorageDirectory.accessError],
  /// so the app never gets stuck on an unreadable path.
  Future<StorageDirectory> resolveDataDirectory() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPath = prefs.getString(_key);

    if (savedPath == null || savedPath.isEmpty) {
      return StorageDirectory(path: await _defaultDirectory(), isDefault: true);
    }

    // Not sandboxed here (non-macOS): the saved path is usable as-is.
    final bookmarks = _bookmarks;
    if (bookmarks == null) {
      return StorageDirectory(path: savedPath, configuredPath: savedPath);
    }

    final bookmark = prefs.getString(_bookmarkKey);
    if (bookmark == null) {
      // A path was saved without a bookmark (e.g. configured by an older
      // build). We cannot regain sandbox access — fall back and ask the user
      // to re-select the folder.
      return StorageDirectory(
        path: await _defaultDirectory(),
        configuredPath: savedPath,
        isDefault: true,
        accessError:
            'FlatPlan no longer has permission to open "$savedPath". '
            'Re-select the folder in Settings to restore access.',
      );
    }

    try {
      final resolvedPath = await bookmarks.resolvePath(bookmark);
      final granted = await bookmarks.startAccessing(resolvedPath);
      if (!granted) {
        throw const FileSystemException('Access to the folder was denied');
      }
      return StorageDirectory(path: resolvedPath, configuredPath: savedPath);
    } catch (e) {
      return StorageDirectory(
        path: await _defaultDirectory(),
        configuredPath: savedPath,
        isDefault: true,
        accessError:
            'FlatPlan could not open "$savedPath" ($e). Using the default '
            'folder — re-select the folder in Settings to fix this.',
      );
    }
  }

  /// Persists a new data directory. On macOS also stores a security-scoped
  /// bookmark so access survives app restarts.
  ///
  /// A just-picked folder is already accessible for this session (granted by
  /// the open panel), so we only record the path + bookmark here. Access for
  /// future launches is (re)established in [resolveDataDirectory], which the
  /// caller invokes immediately after — `startAccessing` only works on a path
  /// that was obtained by resolving a bookmark, not on a freshly picked one.
  Future<void> setDataDirectory(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, path);

    final bookmarks = _bookmarks;
    if (bookmarks != null) {
      final bookmark = await bookmarks.bookmarkForPath(path);
      await prefs.setString(_bookmarkKey, bookmark);
    } else {
      await prefs.remove(_bookmarkKey);
    }
  }

  /// Clears any custom folder + bookmark, reverting to the default directory.
  Future<void> resetToDefault() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    await prefs.remove(_bookmarkKey);
  }

  Future<String> _defaultDirectory() =>
      _defaultDirectoryOverride?.call() ??
      StorageSettingsService.defaultDirectory();

  /// Default: `<app_support>/flatplan/periods`.
  ///
  /// Uses `getApplicationSupportDirectory()` which resolves to a writable
  /// location on all platforms, including MSIX-packaged Windows apps.
  static Future<String> defaultDirectory() async {
    final appSupport = await getApplicationSupportDirectory();
    return p.join(appSupport.path, 'periods');
  }
}
