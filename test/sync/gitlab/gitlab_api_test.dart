import 'dart:async';
import 'dart:io' show HandshakeException;

import 'package:flatplan/src/sync/gitlab/gitlab_api.dart';
import 'package:flatplan/src/sync/remote_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fake_gitlab.dart';

void main() {
  late FakeGitLab gitlab;
  late GitLabApi api;

  setUp(() {
    gitlab = FakeGitLab();
    api = GitLabApi(client: gitlab.client, baseUrl: FakeGitLab.baseUrl, token: gitlab.validToken);
  });

  test('sends the token header and hits /api/v4', () async {
    await api.project(42);
    expect(gitlab.calls, ['GET /api/v4/projects/42']);
  });

  test('search passes the membership and ordering parameters', () async {
    final projects = await api.searchProjects('rep');
    expect(projects.single.pathWithNamespace, 'group/repo');
    expect(projects.single.defaultBranch, 'main');
    final call = gitlab.calls.single;
    expect(call, contains('membership=true'));
    expect(call, contains('min_access_level=30'));
    expect(call, contains('order_by=last_activity_at'));
    expect(call, contains('search=rep'));
  });

  test('projectByPath url-encodes the slash', () async {
    final project = await api.projectByPath('group/repo');
    expect(project.id, 42);
    expect(gitlab.calls.single, 'GET /api/v4/projects/group%2Frepo');
  });

  test('tree follows x-next-page until it is empty', () async {
    gitlab.treePageSize = 2;
    for (var i = 0; i < 5; i++) {
      gitlab.files['budget/f$i.yaml'] = 'v$i';
    }
    final entries = await api.tree(42, 'main', 'budget');
    expect(entries.map((e) => e.name), ['f0.yaml', 'f1.yaml', 'f2.yaml', 'f3.yaml', 'f4.yaml']);
    expect(gitlab.calls.length, 3);
    expect(gitlab.calls.first, contains('per_page=100'));
  });

  test('tree stops instead of throwing on a malformed x-next-page', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      return http.Response(
        '[{"id": "a", "name": "f.yaml", "type": "blob", "path": "budget/f.yaml"}]',
        200,
        headers: {'content-type': 'application/json', 'x-next-page': 'abc'},
      );
    });
    final scrambled = GitLabApi(client: client, baseUrl: FakeGitLab.baseUrl, token: 't');

    final entries = await scrambled.tree(42, 'main', 'budget');

    expect(entries.single.name, 'f.yaml');
    expect(calls, 1, reason: 'there is no page to continue with');
  });

  test('rawFile encodes the path and reads the blob id header', () async {
    gitlab.files['budget/2026-09-september.yaml'] = 'id: p1\n';
    final file = await api.rawFile(42, 'main', 'budget/2026-09-september.yaml');
    expect(file.content, 'id: p1\n');
    expect(file.blobId, hasLength(40));
    expect(gitlab.calls.single, startsWith('GET /api/v4/projects/42/repository/files/budget%2F2026-09-september.yaml/raw'));
  });

  test('commit posts the actions and returns the sha', () async {
    final sha = await api.commit(42, 'main', 'msg', [
      const CommitAction(action: 'create', filePath: 'budget/a.yaml', content: 'a'),
    ]);
    expect(sha, startsWith('commit-'));
    expect(gitlab.files['budget/a.yaml'], 'a');
  });

  test('tokenInfo reads the expiry date when present', () async {
    expect((await api.tokenInfo()).expiresAt, isNull);
    gitlab.tokenExpiresAt = '2026-12-31';
    expect((await api.tokenInfo()).expiresAt, DateTime(2026, 12, 31));
  });

  test('tokenInfo reports legacy scopes and fine-grained tokens', () async {
    expect((await api.tokenInfo()).scopes, ['api']);
    gitlab.fineGrained = true;
    expect((await api.tokenInfo()).isFineGrained, isTrue);
  });

  test('branches returns the fake branch names in order', () async {
    gitlab.branches.addAll(['dev', 'staging']);
    expect(await api.branches(42), ['main', 'dev', 'staging']);
  });

  test('branchExists returns true for an existing branch and false on 404', () async {
    expect(await api.branchExists(42, 'main'), isTrue);
    expect(await api.branchExists(42, 'missing'), isFalse);
  });

  test('branchExists rethrows other errors as GitLabApiException', () async {
    gitlab.failWith['/projects/42/repository/branches/'] = 403;
    await expectLater(
      api.branchExists(42, 'main'),
      throwsA(isA<GitLabApiException>().having((e) => e.status, 'status', 403)),
    );
  });

  test('401 becomes RemoteAuthRejected', () async {
    api = GitLabApi(client: gitlab.client, baseUrl: FakeGitLab.baseUrl, token: 'wrong');
    await expectLater(api.project(42), throwsA(isA<RemoteAuthRejected>()));
  });

  test('401 with an error description says why the token was rejected', () async {
    final client = MockClient((_) async => http.Response(
      '{"error":"invalid_token","error_description":"Token is expired. You can either do re-authorization or token refresh."}',
      401,
      headers: {'content-type': 'application/json'},
    ));
    api = GitLabApi(client: client, baseUrl: FakeGitLab.baseUrl, token: 't');
    await expectLater(
      api.project(42),
      throwsA(isA<RemoteAuthRejected>().having(
        (e) => e.message,
        'message',
        'GitLab rejected the token: Token is expired. Replace it in the vault settings.',
      )),
    );
  });

  test('CertificateRejected needs the user\'s attention', () {
    const rejected = CertificateRejected(host: 'h', subject: 's', fingerprint: 'f');
    expect(rejected, isA<RemoteNeedsAttention>());
  });

  test('403 keeps GitLab message in GitLabApiException', () async {
    gitlab.failWith['/projects/42/repository/tree'] = 403;
    await expectLater(
      api.tree(42, 'main', ''),
      throwsA(isA<GitLabApiException>().having((e) => e.status, 'status', 403).having((e) => e.message, 'message', 'forced 403')),
    );
  });

  test('a 2xx non-JSON body becomes GitLabApiException', () async {
    final client = MockClient((_) async => http.Response('<html>Log in to GitLab</html>', 200));
    api = GitLabApi(client: client, baseUrl: FakeGitLab.baseUrl, token: 't');
    await expectLater(
      api.project(42),
      throwsA(isA<GitLabApiException>().having((e) => e.status, 'status', 200)),
    );
  });

  test('a 2xx JSON body of the wrong shape becomes GitLabApiException', () async {
    final client = MockClient(
      (_) async => http.Response('{}', 200, headers: {'content-type': 'application/json'}),
    );
    api = GitLabApi(client: client, baseUrl: FakeGitLab.baseUrl, token: 't');
    await expectLater(
      api.branches(42),
      throwsA(isA<GitLabApiException>().having((e) => e.status, 'status', 200)),
    );
  });

  for (final status in [429, 502, 503, 504]) {
    test('$status becomes RemoteUnreachable', () async {
      gitlab.failWith['/projects/42'] = status;
      await expectLater(api.project(42), throwsA(isA<RemoteUnreachable>()));
    });
  }

  test('a dropped socket becomes RemoteUnreachable', () async {
    gitlab.throwOnRequest = socketDropped();
    await expectLater(api.project(42), throwsA(isA<RemoteUnreachable>()));
  });

  test('a ClientException becomes RemoteUnreachable', () async {
    final client = MockClient((_) async => throw http.ClientException('reset'));
    api = GitLabApi(client: client, baseUrl: FakeGitLab.baseUrl, token: 't');
    await expectLater(api.project(42), throwsA(isA<RemoteUnreachable>()));
  });

  test('a slow server times out as RemoteUnreachable', () async {
    final client = MockClient((_) => Completer<http.Response>().future);
    api = GitLabApi(client: client, baseUrl: FakeGitLab.baseUrl, token: 't', timeout: const Duration(milliseconds: 20));
    await expectLater(api.project(42), throwsA(isA<RemoteUnreachable>()));
  });

  test('a handshake failure with a recorded certificate becomes CertificateRejected', () async {
    final rejected = CertificateRejected(host: 'gitlab.test', subject: 'CN=gitlab.test', fingerprint: 'AA:BB');
    final client = MockClient((_) async => throw const HandshakeException('bad cert'));
    api = GitLabApi(client: client, baseUrl: FakeGitLab.baseUrl, token: 't', takeRejectedCertificate: () => rejected);
    await expectLater(api.project(42), throwsA(same(rejected)));
  });
}
