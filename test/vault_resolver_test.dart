import 'dart:io';

import 'package:flatplan/src/models/models.dart';
import 'package:flatplan/src/storage/app_paths.dart';
import 'package:flatplan/src/storage/vault_resolver.dart';
import 'package:flatplan/src/storage/vault_secrets.dart';
import 'package:flatplan/src/sync/remote_store.dart';
import 'package:flatplan/src/sync/sync_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'storage/fake_bookmarks.dart';
import 'sync/in_memory_remote_store.dart';

void main() {
  late Directory tempDir;
  late AppPaths paths;
  late RemoteStoreRegistry stores;
  late MemoryVaultSecrets secrets;
  final created = DateTime.utc(2026, 1, 1);

  Vault local(String path, {String? bookmark}) => Vault(
    id: 'v-local',
    name: 'Local',
    location: VaultLocation.local(path: path, bookmark: bookmark),
    createdAt: created,
  );

  Vault remote({String kind = 'memory', List<String> secretNames = const []}) =>
      Vault(
        id: 'v-remote',
        name: 'Remote',
        location: VaultLocation.remote(
          kind: kind,
          settings: const {'repo': 'x'},
          secretNames: secretNames,
        ),
        createdAt: created,
      );

  VaultResolver resolver({FakeBookmarks? bookmarks}) => VaultResolver(
    paths: paths,
    remoteStores: stores,
    secrets: secrets,
    bookmarks: bookmarks,
    useBookmarks: bookmarks != null,
    idleDelay: const Duration(hours: 1),
  );

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('flatplan_resolver_');
    paths = AppPaths(appSupportDir: p.join(tempDir.path, 'support'));
    stores = RemoteStoreRegistry();
    secrets = MemoryVaultSecrets();
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('local', () {
    test('opens an existing folder without bookmarks', () async {
      final dir = Directory(p.join(tempDir.path, 'budget'))..createSync();

      final open = await resolver().open(local(dir.path));

      expect(open.accessError, isNull);
      expect(open.workspace!.displayPath, dir.path);
      expect(open.scheduler, isNull);
      expect(open.isRemote, isFalse);
    });

    test('a folder inside the app support area may not exist yet', () async {
      final open = await resolver().open(local(paths.defaultPeriodsDir));

      expect(open.accessError, isNull);
      expect(open.workspace, isNotNull);
    });

    test('a missing user-picked folder is an access error', () async {
      final missing = p.join(tempDir.path, 'gone');

      final open = await resolver().open(local(missing));

      expect(open.workspace, isNull);
      expect(open.accessError, VaultResolver.missingFolderError(missing));
    });

    test('on macOS a bookmark is resolved and access started', () async {
      final dir = Directory(p.join(tempDir.path, 'picked'))..createSync();
      final bookmarks = FakeBookmarks();

      final open = await resolver(bookmarks: bookmarks)
          .open(local(dir.path, bookmark: 'bookmark::${dir.path}'));

      expect(open.accessError, isNull);
      expect(bookmarks.accessed, [dir.path]);
      expect(open.workspace!.displayPath, dir.path);
    });

    test('a stale bookmark is an access error pointing at vault settings',
        () async {
      final bookmarks = FakeBookmarks(resolveThrows: true);

      final open = await resolver(bookmarks: bookmarks)
          .open(local('/Users/me/budget', bookmark: 'old'));

      expect(open.workspace, isNull);
      expect(open.accessError, contains('/Users/me/budget'));
      expect(open.accessError, contains('Choose the folder again'));
    });

    test('denied access is an access error', () async {
      final bookmarks = FakeBookmarks(startAccessingResult: false);

      final open = await resolver(bookmarks: bookmarks)
          .open(local('/x', bookmark: 'bookmark::/x'));

      expect(open.accessError, isNotNull);
    });

    test('bookmarkFor returns a bookmark only where bookmarks are used',
        () async {
      final bookmarks = FakeBookmarks();

      expect(await resolver(bookmarks: bookmarks).bookmarkFor('/a'), 'bookmark::/a');
      expect(await resolver().bookmarkFor('/a'), isNull);
    });
  });

  group('remote', () {
    test('an unknown kind is not supported', () async {
      final open = await resolver().open(remote(kind: 'teleport'));

      expect(open.workspace, isNull);
      expect(open.accessError, VaultResolver.unsupportedKindError);
    });

    test('a missing secret asks the user to sign in again', () async {
      stores.register('memory', (location, s) async => InMemoryRemoteStore());

      final open = await resolver().open(remote(secretNames: ['token']));

      expect(open.workspace, isNull);
      expect(open.accessError, VaultResolver.missingSecretError);
    });

    test('opens a mirror with a journal and a scheduler', () async {
      late RemoteVaultLocation seenLocation;
      late Map<String, String> seenSecrets;
      stores.register('memory', (location, s) async {
        seenLocation = location;
        seenSecrets = s;
        return InMemoryRemoteStore();
      });
      await secrets.write('v-remote', 'token', 't0k');
      final statuses = <SyncStatus>[];

      final open = await resolver().open(
        remote(secretNames: ['token']),
        onStatus: statuses.add,
      );

      expect(open.accessError, isNull);
      expect(open.isRemote, isTrue);
      expect(open.workspace!.displayPath, paths.mirrorFor('v-remote'));
      expect(open.scheduler, isNotNull);
      expect(seenLocation.settings, {'repo': 'x'});
      expect(seenSecrets, {'token': 't0k'});

      // Writing through the workspace marks the journal dirty on disk and
      // tells the scheduler.
      await open.workspace!.writeString('a.yaml', 'x');
      expect(File(paths.journalFor('v-remote')).readAsStringSync(), contains('a.yaml'));
      expect(statuses.last.dirtyCount, 1);
      open.dispose();
    });
  });
}
