import 'package:flatplan/src/sync/gitlab/git_blob.dart';
import 'package:flatplan/src/sync/gitlab/gitlab_api.dart';
import 'package:flatplan/src/sync/gitlab/gitlab_remote_store.dart';
import 'package:flatplan/src/sync/gitlab/gitlab_settings.dart';
import 'package:flatplan/src/sync/remote_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_gitlab.dart';

void main() {
  late FakeGitLab gitlab;
  late GitLabRemoteStore store;

  GitLabRemoteStore make({String folder = 'budget'}) => GitLabRemoteStore(
    api: GitLabApi(client: gitlab.client, baseUrl: FakeGitLab.baseUrl, token: gitlab.validToken),
    settings: GitLabSettings(
      baseUrl: FakeGitLab.baseUrl,
      projectId: gitlab.projectId,
      projectPath: gitlab.projectPath,
      branch: 'main',
      folder: folder,
    ),
  );

  setUp(() {
    gitlab = FakeGitLab();
    store = make();
  });

  group('listTree', () {
    test('returns direct blobs with the folder prefix stripped', () async {
      gitlab.files['budget/a.yaml'] = 'a';
      gitlab.files['budget/sub/b.yaml'] = 'b';
      gitlab.files['other/c.yaml'] = 'c';

      final tree = await store.listTree();

      expect(tree, {'a.yaml': gitBlobSha('a')});
    });

    test('works at the repository root', () async {
      gitlab.files['a.yaml'] = 'a';
      gitlab.files['budget/b.yaml'] = 'b';

      expect(await make(folder: '').listTree(), {'a.yaml': gitBlobSha('a')});
    });

    test('an empty repository is an empty tree', () async {
      gitlab.emptyRepo = true;
      expect(await store.listTree(), isEmpty);
      expect(gitlab.calls, ['GET /api/v4/projects/42/repository/tree?ref=main&path=budget&per_page=100&page=1', 'GET /api/v4/projects/42']);
    });

    test('a missing folder on an existing branch is an empty tree', () async {
      gitlab.files['README.md'] = 'hi';
      expect(await store.listTree(), isEmpty);
      expect(gitlab.calls.last, 'GET /api/v4/projects/42/repository/branches/main');
    });

    test('a missing branch is an error, never an empty tree', () async {
      gitlab.files['README.md'] = 'hi';
      gitlab.branches.clear();
      gitlab.branches.add('develop');
      await expectLater(
        store.listTree(),
        throwsA(isA<GitLabApiException>().having((e) => e.message, 'message', contains("Branch 'main'"))),
      );
    });
  });

  test('read returns content and the blob id', () async {
    gitlab.files['budget/a.yaml'] = 'id: p1\n';
    final file = await store.read('a.yaml');
    expect(file.content, 'id: p1\n');
    expect(file.version, gitBlobSha('id: p1\n'));
  });

  group('writeBatch', () {
    test('creates, updates and deletes in one commit and returns blob ids', () async {
      gitlab.files['budget/old.yaml'] = 'old';
      gitlab.files['budget/gone.yaml'] = 'gone';

      final versions = await store.writeBatch([
        const RemotePut(name: 'new.yaml', content: 'new', expectedVersion: null),
        RemotePut(name: 'old.yaml', content: 'changed', expectedVersion: gitBlobSha('old')),
        RemoteDelete(name: 'gone.yaml', expectedVersion: gitBlobSha('gone')),
      ]);

      expect(versions, {'new.yaml': gitBlobSha('new'), 'old.yaml': gitBlobSha('changed')});
      expect(gitlab.files, {'budget/new.yaml': 'new', 'budget/old.yaml': 'changed'});
      expect(gitlab.calls.where((c) => c.startsWith('POST')).length, 1);
    });

    test('a create whose name already exists is a conflict and sends nothing', () async {
      gitlab.files['budget/a.yaml'] = 'theirs';
      await expectLater(
        store.writeBatch([const RemotePut(name: 'a.yaml', content: 'mine', expectedVersion: null)]),
        throwsA(isA<RemoteConflict>().having((c) => c.names, 'names', ['a.yaml'])),
      );
      expect(gitlab.files['budget/a.yaml'], 'theirs');
      expect(gitlab.calls.any((c) => c.startsWith('POST')), isFalse);
    });

    test('an update whose expected version is stale is a conflict', () async {
      gitlab.files['budget/a.yaml'] = 'v2';
      await expectLater(
        store.writeBatch([RemotePut(name: 'a.yaml', content: 'v3', expectedVersion: gitBlobSha('v1'))]),
        throwsA(isA<RemoteConflict>()),
      );
    });

    test('an update or delete of a file that is gone is a conflict', () async {
      await expectLater(
        store.writeBatch([RemotePut(name: 'a.yaml', content: 'x', expectedVersion: gitBlobSha('v1'))]),
        throwsA(isA<RemoteConflict>()),
      );
      await expectLater(
        store.writeBatch([RemoteDelete(name: 'a.yaml', expectedVersion: gitBlobSha('v1'))]),
        throwsA(isA<RemoteConflict>()),
      );
    });

    test('a delete whose expected version is stale is a conflict', () async {
      gitlab.files['budget/a.yaml'] = 'v2';
      await expectLater(
        store.writeBatch([RemoteDelete(name: 'a.yaml', expectedVersion: gitBlobSha('v1'))]),
        throwsA(isA<RemoteConflict>()),
      );
    });

    test('identical content is dropped from the commit', () async {
      gitlab.files['budget/same.yaml'] = 'same';
      gitlab.files['budget/diff.yaml'] = 'one';

      final versions = await store.writeBatch([
        RemotePut(name: 'same.yaml', content: 'same', expectedVersion: gitBlobSha('same')),
        RemotePut(name: 'diff.yaml', content: 'two', expectedVersion: gitBlobSha('one')),
      ]);

      expect(versions, {'same.yaml': gitBlobSha('same'), 'diff.yaml': gitBlobSha('two')});
      expect(gitlab.files['budget/diff.yaml'], 'two');
    });

    test('an all-identical batch sends no commit', () async {
      gitlab.files['budget/same.yaml'] = 'same';
      final versions = await store.writeBatch([
        RemotePut(name: 'same.yaml', content: 'same', expectedVersion: gitBlobSha('same')),
      ]);
      expect(versions, {'same.yaml': gitBlobSha('same')});
      expect(gitlab.calls.any((c) => c.startsWith('POST')), isFalse);
    });

    test('the first commit into an empty repository creates the branch', () async {
      gitlab.emptyRepo = true;
      gitlab.branches.clear();
      await store.writeBatch([const RemotePut(name: 'a.yaml', content: 'a', expectedVersion: null)]);
      expect(gitlab.branches, ['main']);
      expect(gitlab.files['budget/a.yaml'], 'a');
    });

    test('a refused push is rewritten with a hint', () async {
      gitlab.failWith['/commit-refused'] = 400;
      await expectLater(
        store.writeBatch([const RemotePut(name: 'a.yaml', content: 'a', expectedVersion: null)]),
        throwsA(isA<GitLabApiException>()
            .having((e) => e.message, 'message', contains("GitLab refused the push to 'main'"))
            .having((e) => e.message, 'message', contains('Maintainer'))),
      );
    });

    test('the commit message names the number of files', () async {
      await store.writeBatch([
        const RemotePut(name: 'a.yaml', content: 'a', expectedVersion: null),
        const RemotePut(name: 'b.yaml', content: 'b', expectedVersion: null),
      ]);
      // The fake does not keep messages; assert on the store's constant instead.
      expect(GitLabRemoteStore.commitMessage(2), 'FlatPlan sync: 2 files');
      expect(GitLabRemoteStore.commitMessage(1), 'FlatPlan sync: 1 file');
    });
  });
}
