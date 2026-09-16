import 'package:flatplan/src/models/models.dart';
import 'package:flatplan/src/sync/gitlab/gitlab_provider.dart';
import 'package:flatplan/src/sync/gitlab/gitlab_remote_store.dart';
import 'package:flatplan/src/sync/remote_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const location = RemoteVaultLocation(
    kind: 'gitlab',
    settings: {
      'base_url': 'https://gitlab.example.com',
      'project_id': 42,
      'project_path': 'g/r',
      'branch': 'main',
      'folder': 'budget',
    },
    secretNames: ['token'],
  );

  test('registers under the gitlab kind', () {
    final registry = RemoteStoreRegistry();
    registerGitLabProvider(registry);
    expect(registry.supports('gitlab'), isTrue);
  });

  test('builds a store from settings and the token without a request', () async {
    final store = await gitLabStoreFactory(location, {'token': 't'});
    expect(store, isA<GitLabRemoteStore>());
    expect((store as GitLabRemoteStore).settings.projectId, 42);
  });

  test('a missing token is a StateError', () async {
    await expectLater(gitLabStoreFactory(location, {}), throwsStateError);
  });
}
