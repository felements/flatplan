import 'dart:async';
import 'dart:io';

import 'package:flatplan/src/providers/gitlab_connect_controller.dart';
import 'package:flatplan/src/sync/gitlab/gitlab_api.dart';
import 'package:flatplan/src/sync/gitlab/gitlab_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'sync/gitlab/fake_gitlab.dart';

/// Wraps [inner] so any request matched by [when] blocks until [gate]
/// completes, then forwards a fresh (never-finalized) copy of the request.
http.Client pausing(
  http.Client inner, {
  required bool Function(http.Request) when,
  required Completer<void> gate,
}) {
  return MockClient((request) async {
    if (when(request)) await gate.future;
    final forwarded = http.Request(request.method, request.url)
      ..headers.addAll(request.headers)
      ..bodyBytes = request.bodyBytes;
    return inner.send(forwarded).then(http.Response.fromStream);
  });
}

/// A [GitLabApi] whose `searchProjects` always throws an exception type
/// `_run` does not specifically handle, to prove `busy` still falls back
/// to false when that happens.
class ThrowingApi extends GitLabApi {
  ThrowingApi() : super(client: http.Client(), baseUrl: 'https://example.test', token: 't');

  @override
  Future<List<ProjectSummary>> searchProjects(String query) {
    throw StateError('boom');
  }
}

void main() {
  late FakeGitLab gitlab;
  late GitLabConnectController controller;

  GitLabConnectController make({http.Client? client, CertificateRejected? offer, GitLabSettings? existing}) {
    var offered = false;
    return GitLabConnectController(
      existing: existing,
      apiFactory: ({required settings, required token}) => GitLabApi(
        client: client ?? gitlab.client,
        baseUrl: settings.baseUrl,
        token: token,
        takeRejectedCertificate: () {
          if (offer == null || offered) return null;
          offered = true;
          return offer;
        },
      ),
    );
  }

  setUp(() {
    gitlab = FakeGitLab();
    controller = make();
    controller.setSelfHosted(true);
    controller.setBaseUrl(FakeGitLab.baseUrl);
  });

  test('starts at the token step on gitlab.com', () {
    final fresh = make();
    expect(fresh.selfHosted, isFalse);
    expect(fresh.baseUrl, GitLabSettings.gitLabCom);
    expect(fresh.step, ConnectStep.token);
    expect(fresh.folder, 'budget');
  });

  test('connect with a legacy api token reaches the project step', () async {
    await controller.connect(gitlab.validToken);
    expect(controller.connectError, isNull);
    expect(controller.step, ConnectStep.project);
    expect(controller.projects.single.pathWithNamespace, 'group/repo');
    expect(gitlab.calls.first, startsWith('GET /api/v4/projects?'));
    expect(gitlab.calls[1], 'GET /api/v4/personal_access_tokens/self');
  });

  test('a rejected token stops with a message', () async {
    await controller.connect('wrong');
    expect(controller.step, ConnectStep.token);
    expect(controller.connectError, contains('rejected'));
  });

  test('a legacy read_api token is refused before any project is chosen', () async {
    gitlab.tokenScopes = ['read_api'];
    await controller.connect(gitlab.validToken);
    expect(controller.step, ConnectStep.token);
    expect(controller.connectError, contains('api'));
  });

  test('a fine-grained token proceeds even when it cannot inspect itself', () async {
    gitlab.fineGrained = true;
    gitlab.tokenInfoStatus = 403;
    await controller.connect(gitlab.validToken);
    expect(controller.step, ConnectStep.project);
  });

  test('a fine-grained 403 on search surfaces GitLab message', () async {
    gitlab.failWith['/projects'] = 403;
    await controller.connect(gitlab.validToken);
    expect(controller.connectError, 'forced 403');
  });

  test('an unreachable host names the url', () async {
    gitlab.throwOnRequest = socketDropped();
    await controller.connect(gitlab.validToken);
    expect(controller.connectError, contains('gitlab.test'));
  });

  test('an untrusted certificate is offered, then trusted, then connects', () async {
    final offer = CertificateRejected(host: 'gitlab.test', subject: 'CN=gitlab.test', fingerprint: 'AA:BB');
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      if (calls == 1) throw const HandshakeException('untrusted');
      // `request` is already finalized by this MockClient; forward a fresh
      // copy since http.Request can only be finalized once.
      final forwarded = http.Request(request.method, request.url)
        ..headers.addAll(request.headers)
        ..bodyBytes = request.bodyBytes;
      return gitlab.client.send(forwarded).then(http.Response.fromStream);
    });
    controller = make(client: client, offer: offer)
      ..setSelfHosted(true)
      ..setBaseUrl(FakeGitLab.baseUrl);

    await controller.connect(gitlab.validToken);
    expect(controller.pendingCertificate, same(offer));
    expect(controller.step, ConnectStep.token);

    await controller.trustCertificate();
    expect(controller.pendingCertificate, isNull);
    expect(controller.certFingerprint, 'AA:BB');
    expect(controller.step, ConnectStep.project);
  });

  test('search falls back to a typed path when the list is empty', () async {
    gitlab.searchResults = [];
    await controller.connect(gitlab.validToken);
    await controller.search('group/repo');
    expect(controller.projects.single.id, 42);
    expect(gitlab.calls.last, 'GET /api/v4/projects/group%2Frepo');
  });

  test('selecting a project loads branches, preselects the default and checks the folder', () async {
    gitlab.branches.addAll(['develop']);
    gitlab.files['budget/2026-09-september.yaml'] = 'id: p\n';
    gitlab.files['budget/2026-09-september.conflict-2026-09-01-1200.yaml'] = 'x';
    gitlab.files['budget/notes.md'] = 'x';
    await controller.connect(gitlab.validToken);

    await controller.selectProject(controller.projects.single);

    expect(controller.step, ConnectStep.target);
    expect(controller.branches, ['main', 'develop']);
    expect(controller.branch, 'main');
    expect(controller.suggestedName, 'repo');
    expect(controller.folderCheck!.kind, FolderCheckKind.periodFiles);
    expect(controller.folderCheck!.count, 1);
    expect(controller.folderCheck!.describe(), '1 period file found');
  });

  test('folder check reports empty, new repository and errors', () async {
    await controller.connect(gitlab.validToken);
    await controller.selectProject(controller.projects.single);
    expect(controller.folderCheck!.describe(), 'Empty, files will be created on first sync');

    gitlab.emptyRepo = true;
    await controller.setFolder('/budget/');
    expect(controller.folder, 'budget');
    expect(controller.folderCheck!.kind, FolderCheckKind.newRepository);

    gitlab.emptyRepo = false;
    gitlab.failWith['/projects/42/repository/tree'] = 403;
    await controller.setFolder('other');
    expect(controller.folderCheck!.kind, FolderCheckKind.error);
    expect(controller.folderCheck!.message, 'forced 403');
  });

  test('canSave and toSettings after the full flow', () async {
    await controller.connect(gitlab.validToken);
    expect(controller.canSave, isFalse);
    await controller.selectProject(controller.projects.single);
    controller.selectBranch('main');

    expect(controller.canSave, isTrue);
    expect(controller.token, gitlab.validToken);
    expect(controller.toSettings().toSettings(), {
      'base_url': FakeGitLab.baseUrl,
      'project_id': 42,
      'project_path': 'group/repo',
      'branch': 'main',
      'folder': 'budget',
    });
  });

  test('changing the url after a project is selected resets the connect state', () async {
    await controller.connect(gitlab.validToken);
    await controller.selectProject(controller.projects.single);
    expect(controller.canSave, isTrue);

    controller.setBaseUrl('https://other.test');

    expect(controller.canSave, isFalse);
    expect(controller.step, ConnectStep.token);
    expect(controller.project, isNull);
    expect(controller.token, isNull);
    expect(controller.branch, isNull);
    expect(controller.projects, isEmpty);
  });

  test('unchecking self-hosted after a project is selected resets the same way', () async {
    await controller.connect(gitlab.validToken);
    await controller.selectProject(controller.projects.single);
    controller.selectBranch('main');
    expect(controller.canSave, isTrue);

    controller.setSelfHosted(false);

    expect(controller.canSave, isFalse);
    expect(controller.step, ConnectStep.token);
    expect(controller.project, isNull);
    expect(controller.token, isNull);
    expect(controller.baseUrl, GitLabSettings.gitLabCom);
  });

  test('setBaseUrl before any connect stays quiet: no reset needed', () {
    final fresh = make();
    fresh.setBaseUrl('https://example.test');
    expect(fresh.step, ConnectStep.token);
    expect(fresh.connectError, isNull);
  });

  test('verifyReplacementToken checks the stored project', () async {
    final existing = GitLabSettings(baseUrl: FakeGitLab.baseUrl, projectId: 42, projectPath: 'group/repo', branch: 'main', folder: 'budget');
    controller = make(existing: existing);
    expect(controller.step, ConnectStep.target);
    expect(controller.selfHosted, isTrue);

    await controller.verifyReplacementToken('wrong');
    expect(controller.connectError, contains('rejected'));
    expect(controller.token, isNull);

    await controller.verifyReplacementToken(gitlab.validToken);
    expect(controller.connectError, isNull);
    expect(controller.token, gitlab.validToken);
    expect(gitlab.calls.last, 'GET /api/v4/projects/42');
  });

  test('busy stays true while an overlapping search finishes before a slower selection', () async {
    final gate = Completer<void>();
    final client = pausing(
      gitlab.client,
      when: (r) => r.url.path.contains('/repository/branches'),
      gate: gate,
    );
    controller = make(client: client)
      ..setSelfHosted(true)
      ..setBaseUrl(FakeGitLab.baseUrl);
    await controller.connect(gitlab.validToken);

    final selecting = controller.selectProject(controller.projects.single);
    await Future<void>.delayed(Duration.zero);
    expect(controller.busy, isTrue);

    await controller.search('');
    expect(controller.busy, isTrue, reason: 'selectProject is still awaiting the paused branches call');

    gate.complete();
    await selecting;
    expect(controller.busy, isFalse);
  });

  test('a disposed controller ignores a debounced search finishing later', () async {
    final gate = Completer<void>();
    final client = pausing(
      gitlab.client,
      when: (r) => r.url.queryParameters['search'] == 'x',
      gate: gate,
    );
    controller = make(client: client)
      ..setSelfHosted(true)
      ..setBaseUrl(FakeGitLab.baseUrl);
    await controller.connect(gitlab.validToken);

    final future = controller.search('x').timeout(const Duration(seconds: 2));
    await Future<void>.delayed(const Duration(milliseconds: 350));
    controller.dispose();
    gate.complete();

    // Must resolve without throwing: notifyListeners() must not fire on a
    // disposed ChangeNotifier once the paused request finally answers.
    await future;
  });

  test('search does not hang when a later query supersedes it', () async {
    await controller.connect(gitlab.validToken);
    gitlab.calls.clear();

    final first = controller.search('a').timeout(const Duration(seconds: 2));
    final second = controller.search('ab').timeout(const Duration(seconds: 2));
    await Future.wait([first, second]);

    expect(gitlab.calls.where((c) => c.endsWith('search=a')), isEmpty);
    expect(gitlab.calls.where((c) => c.endsWith('search=ab')), hasLength(1));
  });

  test('an untyped failure is reported instead of escaping _run', () async {
    final busyHistory = <bool>[];
    controller = GitLabConnectController(
      apiFactory: ({required settings, required token}) => ThrowingApi(),
    );
    controller.addListener(() => busyHistory.add(controller.busy));

    await controller.connect('t');

    expect(controller.connectError, contains('Unexpected error'));
    expect(controller.busy, isFalse);
    expect(busyHistory.last, isFalse);
  });

  test('a token whose scopes cannot be read still reaches the project step', () async {
    gitlab.tokenInfoStatus = 500;
    await controller.connect(gitlab.validToken);
    expect(controller.connectError, isNull);
    expect(controller.step, ConnectStep.project);

    // 429 arrives as RemoteUnreachable rather than GitLabApiException.
    controller = make()
      ..setSelfHosted(true)
      ..setBaseUrl(FakeGitLab.baseUrl);
    gitlab.tokenInfoStatus = 429;
    await controller.connect(gitlab.validToken);
    expect(controller.connectError, isNull);
    expect(controller.step, ConnectStep.project);
  });

  test('changing the server drops the trusted fingerprint', () async {
    final offer = CertificateRejected(host: 'gitlab.test', subject: 'CN=gitlab.test', fingerprint: 'AA:BB');
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      if (calls == 1) throw const HandshakeException('untrusted');
      final forwarded = http.Request(request.method, request.url)
        ..headers.addAll(request.headers)
        ..bodyBytes = request.bodyBytes;
      return gitlab.client.send(forwarded).then(http.Response.fromStream);
    });
    controller = make(client: client, offer: offer)
      ..setSelfHosted(true)
      ..setBaseUrl(FakeGitLab.baseUrl);

    await controller.connect(gitlab.validToken);
    await controller.trustCertificate();
    expect(controller.certFingerprint, 'AA:BB');

    controller.setBaseUrl('https://b.test');

    expect(controller.certFingerprint, isNull, reason: 'a pin belongs to one host');
  });

  test('a pending offer is not trusted for a server the form has moved to', () async {
    final offer = CertificateRejected(host: 'gitlab.test', subject: 'CN=gitlab.test', fingerprint: 'AA:BB');
    final client = MockClient((request) async => throw const HandshakeException('untrusted'));
    controller = make(client: client, offer: offer)
      ..setSelfHosted(true)
      ..setBaseUrl(FakeGitLab.baseUrl);

    await controller.connect(gitlab.validToken);
    expect(controller.pendingCertificate, same(offer));

    controller.setBaseUrl('https://other.test');
    await controller.trustCertificate();

    expect(controller.certFingerprint, isNull);
    expect(controller.pendingCertificate, isNull);
  });

  test('a search awaited across dispose does not hang', () async {
    await controller.connect(gitlab.validToken);

    final pending = controller.search('x');
    controller.dispose();

    await pending.timeout(const Duration(seconds: 1));
  });

  test('fetchCurrentCertificate records the offer without changing the pin until trusted', () async {
    final existing = GitLabSettings(baseUrl: FakeGitLab.baseUrl, projectId: 42, projectPath: 'group/repo', branch: 'main', certFingerprint: 'OLD');
    final offer = CertificateRejected(host: 'gitlab.test', subject: 'CN=x', fingerprint: 'NEW');
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      if (calls == 1) throw const HandshakeException('changed');
      // `request` is already finalized by this MockClient; forward a fresh
      // copy since http.Request can only be finalized once.
      final forwarded = http.Request(request.method, request.url)
        ..headers.addAll(request.headers)
        ..bodyBytes = request.bodyBytes;
      return gitlab.client.send(forwarded).then(http.Response.fromStream);
    });
    controller = make(client: client, offer: offer, existing: existing);

    await controller.fetchCurrentCertificate(gitlab.validToken);
    expect(controller.pendingCertificate, same(offer));
    expect(controller.certFingerprint, 'OLD');

    await controller.trustCertificate();
    expect(controller.certFingerprint, 'NEW');
    expect(controller.token, gitlab.validToken);
  });

  test('a stale search response does not overwrite newer results', () async {
    gitlab.searchResults = [
      {'id': 1, 'name': 'apple', 'path_with_namespace': 'group/apple', 'default_branch': 'main', 'empty_repo': false},
      {'id': 2, 'name': 'crab', 'path_with_namespace': 'group/crab', 'default_branch': 'main', 'empty_repo': false},
    ];
    final gate = Completer<void>();
    // Only the query='a' request pauses; connect()'s search='' and the
    // later search='ab' both go straight through.
    final client = pausing(
      gitlab.client,
      when: (r) => r.url.queryParameters['search'] == 'a',
      gate: gate,
    );
    controller = make(client: client)
      ..setSelfHosted(true)
      ..setBaseUrl(FakeGitLab.baseUrl);
    await controller.connect(gitlab.validToken);

    final first = controller.search('a');
    await Future<void>.delayed(const Duration(milliseconds: 350));

    final second = controller.search('ab');
    await second;
    expect(controller.projects.single.name, 'crab');

    // Release the paused 'a' request. Its answer is now stale and must
    // not clobber the 'ab' result already applied above.
    gate.complete();
    await first;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(controller.projects.single.name, 'crab');
  });
}
