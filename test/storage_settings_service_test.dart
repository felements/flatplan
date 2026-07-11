import 'package:flatplan/src/storage/security_scoped_bookmarks.dart';
import 'package:flatplan/src/storage/storage_settings_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fake bookmark store that records calls and can be told to fail resolution,
/// so the sandbox fallback logic is testable without the macOS platform channel.
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

void main() {
  const defaultDir = '/tmp/flatplan-default/periods';
  Future<String> defaultDirectory() async => defaultDir;

  StorageSettingsService service(FakeBookmarks bookmarks) =>
      StorageSettingsService(
        bookmarks: bookmarks,
        useBookmarks: true,
        defaultDirectory: defaultDirectory,
      );

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('returns default directory when nothing is configured', () async {
    final result = await service(FakeBookmarks()).resolveDataDirectory();

    expect(result.path, defaultDir);
    expect(result.isDefault, isTrue);
    expect(result.configuredPath, isNull);
    expect(result.accessError, isNull);
  });

  test('setDataDirectory stores a bookmark without accessing a raw path',
      () async {
    final bookmarks = FakeBookmarks();
    await service(bookmarks).setDataDirectory('/Users/me/Budget');

    // A freshly picked folder is already accessible; access is (re)established
    // later via resolveDataDirectory, not here — startAccessing only works on
    // a resolved path.
    expect(bookmarks.bookmarked, contains('/Users/me/Budget'));
    expect(bookmarks.accessed, isEmpty);
  });

  test('resolves the configured folder via its bookmark on next launch',
      () async {
    final bookmarks = FakeBookmarks();
    final svc = service(bookmarks);
    await svc.setDataDirectory('/Users/me/Budget');

    final result = await svc.resolveDataDirectory();

    expect(result.path, '/Users/me/Budget');
    expect(result.configuredPath, '/Users/me/Budget');
    expect(result.isDefault, isFalse);
    expect(result.accessError, isNull);
    expect(bookmarks.accessed, contains('/Users/me/Budget'));
  });

  test('falls back to default with an error when the bookmark is unusable',
      () async {
    final bookmarks = FakeBookmarks();
    final svc = service(bookmarks);
    await svc.setDataDirectory('/Users/me/Budget');

    // Simulate lost access on a later launch.
    bookmarks.resolveThrows = true;
    final result = await svc.resolveDataDirectory();

    expect(result.path, defaultDir);
    expect(result.isDefault, isTrue);
    expect(result.configuredPath, '/Users/me/Budget');
    expect(result.accessError, isNotNull);
    expect(result.accessError, contains('/Users/me/Budget'));
  });

  test('falls back to default with an error when access is denied', () async {
    final bookmarks = FakeBookmarks(startAccessingResult: false);
    final svc = service(bookmarks);
    await svc.setDataDirectory('/Users/me/Budget');

    final result = await svc.resolveDataDirectory();

    expect(result.path, defaultDir);
    expect(result.isDefault, isTrue);
    expect(result.accessError, isNotNull);
  });

  test('falls back when a path was saved without a bookmark (older build)',
      () async {
    SharedPreferences.setMockInitialValues({
      'data_directory': '/Users/me/Legacy',
    });

    final result = await service(FakeBookmarks()).resolveDataDirectory();

    expect(result.path, defaultDir);
    expect(result.isDefault, isTrue);
    expect(result.configuredPath, '/Users/me/Legacy');
    expect(result.accessError, isNotNull);
  });

  group('non-macOS (Windows/Linux — no sandbox bookmarks)', () {
    // useBookmarks:false disables the bookmark path entirely, mirroring
    // Platform.isMacOS == false on Windows/Linux.
    StorageSettingsService plain() => StorageSettingsService(
          useBookmarks: false,
          defaultDirectory: defaultDirectory,
        );

    test('uses the saved path directly, no bookmark, no access error',
        () async {
      SharedPreferences.setMockInitialValues({
        'data_directory': r'C:\Users\me\Budget',
      });

      final result = await plain().resolveDataDirectory();

      expect(result.path, r'C:\Users\me\Budget');
      expect(result.configuredPath, r'C:\Users\me\Budget');
      expect(result.isDefault, isFalse);
      expect(result.accessError, isNull);
    });

    test('setDataDirectory saves the path without storing a bookmark',
        () async {
      final svc = plain();
      await svc.setDataDirectory('/home/me/budget');

      final result = await svc.resolveDataDirectory();
      expect(result.path, '/home/me/budget');
      expect(result.accessError, isNull);
    });

    test('returns default when nothing configured', () async {
      final result = await plain().resolveDataDirectory();
      expect(result.path, defaultDir);
      expect(result.isDefault, isTrue);
    });
  });

  test('resetToDefault clears the configured folder and bookmark', () async {
    final bookmarks = FakeBookmarks();
    final svc = service(bookmarks);
    await svc.setDataDirectory('/Users/me/Budget');

    await svc.resetToDefault();
    final result = await svc.resolveDataDirectory();

    expect(result.path, defaultDir);
    expect(result.isDefault, isTrue);
    expect(result.configuredPath, isNull);
  });
}
