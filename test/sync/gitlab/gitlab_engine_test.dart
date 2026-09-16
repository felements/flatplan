import 'package:flatplan/src/storage/vault_workspace.dart';
import 'package:flatplan/src/sync/conflict_policy.dart';
import 'package:flatplan/src/sync/gitlab/gitlab_api.dart';
import 'package:flatplan/src/sync/gitlab/gitlab_remote_store.dart';
import 'package:flatplan/src/sync/gitlab/gitlab_settings.dart';
import 'package:flatplan/src/sync/sync_engine.dart';
import 'package:flatplan/src/sync/sync_journal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_gitlab.dart';

final fixedNow = DateTime(2026, 9, 16, 14, 32);

String period(String lastModified, {String note = ''}) =>
    'id: p1\nlast_modified: $lastModified\nnote: $note\n';

void main() {
  late FakeGitLab gitlab;
  late Map<String, String> files;
  late MemoryWorkspace app;
  late SyncJournal journal;
  late SyncEngine engine;

  setUp(() {
    gitlab = FakeGitLab();
    files = {};
    journal = SyncJournal();
    app = MemoryWorkspace(files: files, changeListener: journal);
    final store = GitLabRemoteStore(
      api: GitLabApi(client: gitlab.client, baseUrl: FakeGitLab.baseUrl, token: gitlab.validToken),
      settings: GitLabSettings(
        baseUrl: FakeGitLab.baseUrl,
        projectId: gitlab.projectId,
        projectPath: gitlab.projectPath,
        branch: 'main',
        folder: 'budget',
      ),
    );
    engine = SyncEngine(
      mirror: MemoryWorkspace(files: files),
      remote: store,
      journal: journal,
      policy: ConflictPolicy(
        timestampOf: periodLastModified,
        derivedFiles: {'current_stats.md'},
        now: () => fixedNow,
      ),
    );
  });

  test('first pull mirrors the folder and ignores other paths', () async {
    gitlab.files['budget/a.yaml'] = period('2026-09-01T00:00:00');
    gitlab.files['README.md'] = 'not a period';

    expect(await engine.pull(), isNull);
    expect(files.keys, ['a.yaml']);
    expect(journal.baseline['a.yaml'], isNotNull);
  });

  test('a push creates the folder in an empty repository', () async {
    gitlab.emptyRepo = true;
    gitlab.branches.clear();
    await app.writeString('a.yaml', period('2026-09-01T00:00:00'));

    expect(await engine.push(), isNull);
    expect(gitlab.files.keys, ['budget/a.yaml']);
    expect(journal.dirty, isEmpty);
  });

  test('a second push after a local edit updates in place', () async {
    await app.writeString('a.yaml', period('2026-09-01T00:00:00'));
    await engine.push();
    await app.writeString('a.yaml', period('2026-09-02T00:00:00'));

    expect(await engine.push(), isNull);
    expect(gitlab.files['budget/a.yaml'], period('2026-09-02T00:00:00'));
    expect(journal.dirty, isEmpty);
  });

  test('a local delete reaches the remote', () async {
    await app.writeString('a.yaml', 'x');
    await engine.push();
    await app.delete('a.yaml');

    expect(await engine.push(), isNull);
    expect(gitlab.files, isEmpty);
  });

  test('a remote edit that is newer wins and keeps a side file', () async {
    await app.writeString('a.yaml', period('2026-09-01T00:00:00', note: 'mine'));
    await engine.push();
    gitlab.files['budget/a.yaml'] = period('2026-09-05T00:00:00', note: 'theirs');
    await app.writeString('a.yaml', period('2026-09-03T00:00:00', note: 'mine2'));

    expect(await engine.push(), isNull);
    expect(files['a.yaml'], contains('theirs'));
    expect(files.keys.any((k) => k.contains('.conflict-')), isTrue);
    expect(gitlab.files.keys.any((k) => k.contains('.conflict-')), isTrue);
  });

  test('a rejected token is an error, not offline', () async {
    gitlab.validToken = 'rotated';
    await app.writeString('a.yaml', 'x');

    final failure = await engine.push();
    expect(failure, isNotNull);
    expect(failure!.isOffline, isFalse);
    expect(failure.message, contains('rejected the token'));
    expect(journal.dirty, contains('a.yaml'));
  });

  test('a dropped connection is offline and keeps everything dirty', () async {
    gitlab.throwOnRequest = socketDropped();
    await app.writeString('a.yaml', 'x');

    final failure = await engine.push();
    expect(failure!.isOffline, isTrue);
    expect(journal.dirty, contains('a.yaml'));
  });
}
