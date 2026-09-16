# GitLab Vault Provider Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A vault can live in a folder of a GitLab repository (gitlab.com or self-hosted), synced through the REST API with a personal access token, with the keychain-backed secrets and the pull/write lock the previous spec required.

**Architecture:** `GitLabRemoteStore` implements the existing `RemoteStore` contract over a thin typed `GitLabApi` client built on `package:http`; versions are git blob SHAs, and every push is one atomic commit. A `GitLabConnectController` (ChangeNotifier) drives the connect wizard so the `GitLabVaultForm` widget only renders. Secrets move to `flutter_secure_storage`; a `Lock` shared between the app-facing `DirectoryWorkspace` and the `SyncEngine` closes the pull/write race.

**Tech Stack:** Flutter 3.47 / Dart 3.11, Riverpod 3 (hooks_riverpod, riverpod_annotation), flutter_hooks, `http` 1.6, `flutter_secure_storage` 11.2, `crypto`.

**Spec:** `docs/superpowers/specs/2026-09-16-gitlab-vault-provider-design.md`

## Global Constraints

- Every dependency must work on Android and iOS as well as macOS, Windows, Linux. No platform-specific code outside `gitlab_http.dart` (dart:io `HttpClient`) and `SecureVaultSecrets`.
- Opening a vault makes no network request.
- Domain code never touches `dart:io` directly; the store talks only to `GitLabApi`.
- Names inside a vault are plain file names (see `assertSafeName` in `lib/src/storage/vault_workspace.dart`); the repository path of a name is `<folder>/<name>`, or `<name>` when the folder is empty.
- The settings map keys are exactly: `base_url`, `project_id`, `project_path`, `branch`, `folder`, `cert_fingerprint`. The secret name is `token`. The kind string is `gitlab`.
- Fingerprints are SHA-256 of the certificate's DER bytes, upper-case hex pairs joined by `:`.
- Every request sends `PRIVATE-TOKEN: <token>` and times out after 30 seconds.
- UI follows `doc/08_design_guidelines.md`: 12 px radius on inputs and buttons, 16 px on cards. Reuse the existing `LocalVaultForm` structure in `lib/src/views/vault_form_view.dart` for spacing and the save button.
- Run `flutter analyze` before every commit; the CI runs it and `flutter test`.
- Commit messages: imperative, prefixed `feat:`, `fix:`, `test:`, `docs:`, `chore:`; end with `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.
- Work on branch `feat/gitlab-provider`, created from `docs/gitlab-provider-spec` (which holds the spec and this plan).

## File structure

New files and their single responsibility:

| file | responsibility |
|---|---|
| `lib/src/sync/lock.dart` | `Lock`: future-chained mutex |
| `lib/src/sync/gitlab/git_blob.dart` | `gitBlobSha`: git blob object id of a string |
| `lib/src/sync/gitlab/gitlab_settings.dart` | `GitLabSettings`: typed view of the settings map, location line, path helpers |
| `lib/src/sync/gitlab/gitlab_api.dart` | `GitLabApi`: typed HTTP calls, response DTOs, error mapping |
| `lib/src/sync/gitlab/gitlab_http.dart` | `PinnedClient` / `buildGitLabClient`: the dart:io client with the certificate pin |
| `lib/src/sync/gitlab/gitlab_remote_store.dart` | `GitLabRemoteStore`: the `RemoteStore` implementation |
| `lib/src/sync/gitlab/gitlab_provider.dart` | `gitLabStoreFactory`, `registerGitLabProvider` |
| `lib/src/storage/secure_vault_secrets.dart` | `SecureVaultSecrets` over flutter_secure_storage |
| `lib/src/providers/gitlab_connect_controller.dart` | `GitLabConnectController` (ChangeNotifier) and `gitLabApiFactoryProvider` |
| `lib/src/views/gitlab_vault_form.dart` | `GitLabVaultForm` widget and the trust dialog |
| `test/sync/gitlab/fake_gitlab.dart` | `FakeGitLab`: scripted MockClient handler used by api, store, controller and widget tests |
| `test/storage/secrets_contract.dart` | shared `VaultSecrets` contract |
| `test/fixtures/self_signed.pem`, `test/fixtures/self_signed.key` | TLS fixture for the pin test |

Modified: `lib/src/sync/remote_store.dart`, `lib/src/sync/sync_engine.dart`, `lib/src/storage/vault_workspace.dart`, `lib/src/storage/vault_resolver.dart`, `lib/src/providers/open_vault_provider.dart`, `lib/src/providers/vaults_provider.dart`, `lib/src/views/vault_kinds.dart`, `pubspec.yaml`, `macos/Runner/DebugProfile.entitlements`, `macos/Runner/Release.entitlements`, `.github/workflows/release.yml`, `.github/workflows/ci.yml`, docs.

---

### Task 1: `Lock` and the pull/write race

**Files:**
- Create: `lib/src/sync/lock.dart`
- Modify: `lib/src/storage/vault_workspace.dart` (both workspaces gain an optional `lock`)
- Modify: `lib/src/sync/sync_engine.dart` (`_pull` dirty branch, `_snapshot`, `_commit` run per name inside the lock; the `TODO(sync)` comment goes)
- Modify: `lib/src/storage/vault_resolver.dart:148-175` (`_openRemote` creates one `Lock` and wires it)
- Test: `test/sync/lock_test.dart`, `test/sync/sync_engine_lock_test.dart`

**Interfaces:**
- Produces: `class Lock { Future<T> synchronized<T>(Future<T> Function() action); }`
- Produces: `DirectoryWorkspace(String path, {WorkspaceChangeListener? changeListener, Lock? lock})`, `MemoryWorkspace({Map<String,String>? files, WorkspaceChangeListener? changeListener, Lock? lock})`
- Produces: `SyncEngine({required mirror, required remote, required journal, required policy, Lock? lock})` — `lock` defaults to a fresh `Lock()`.

- [ ] **Step 1: Write the failing `Lock` test**

`test/sync/lock_test.dart`:

```dart
import 'dart:async';

import 'package:flatplan/src/sync/lock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('actions run one at a time in call order', () async {
    final lock = Lock();
    final log = <String>[];
    final gate = Completer<void>();

    final first = lock.synchronized(() async {
      log.add('first start');
      await gate.future;
      log.add('first end');
    });
    final second = lock.synchronized(() async {
      log.add('second');
    });
    await Future<void>.delayed(Duration.zero);
    expect(log, ['first start']);

    gate.complete();
    await Future.wait([first, second]);
    expect(log, ['first start', 'first end', 'second']);
  });

  test('a failing action releases the lock and rethrows', () async {
    final lock = Lock();
    await expectLater(
      lock.synchronized(() async => throw StateError('boom')),
      throwsStateError,
    );
    expect(await lock.synchronized(() async => 42), 42);
  });

  test('returns the action result', () async {
    expect(await Lock().synchronized(() async => 'x'), 'x');
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/sync/lock_test.dart`
Expected: FAIL, `lock.dart` does not exist.

- [ ] **Step 3: Implement `Lock`**

`lib/src/sync/lock.dart`:

```dart
import 'dart:async';

/// A future-chained mutex. Actions run one at a time in call order. Not
/// reentrant: an action must not call [synchronized] on the same lock.
class Lock {
  Future<void> _tail = Future.value();

  Future<T> synchronized<T>(Future<T> Function() action) {
    final previous = _tail;
    final done = Completer<void>();
    _tail = done.future;
    return previous.then((_) => action()).whenComplete(done.complete);
  }
}
```

- [ ] **Step 4: Run the lock test**

Run: `flutter test test/sync/lock_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Write the failing race test**

`test/sync/sync_engine_lock_test.dart`. It reproduces the race from the vaults spec §9: the remote has `a.yaml` = `v1`, the mirror has the same content and the name is dirty; while the engine reads the local copy to compare, the app writes `v2`. With the lock the app write waits, lands after the engine's comparison, and re-marks the name dirty.

```dart
import 'package:flatplan/src/storage/vault_workspace.dart';
import 'package:flatplan/src/sync/conflict_policy.dart';
import 'package:flatplan/src/sync/lock.dart';
import 'package:flatplan/src/sync/sync_engine.dart';
import 'package:flatplan/src/sync/sync_journal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'in_memory_remote_store.dart';

/// A mirror whose reads can pause, so a test can inject a concurrent write
/// exactly while the engine is inside its compare-and-resolve block.
class _PausingWorkspace extends MemoryWorkspace {
  _PausingWorkspace({required super.files});

  Future<void> Function(String name)? onRead;

  @override
  Future<String> readString(String name) async {
    await onRead?.call(name);
    return super.readString(name);
  }
}

void main() {
  test('a local write during pull resolution keeps the name dirty', () async {
    final files = <String, String>{};
    final journal = SyncJournal();
    final lock = Lock();
    final mirror = _PausingWorkspace(files: files);
    final app = MemoryWorkspace(files: files, changeListener: journal, lock: lock);
    final remote = InMemoryRemoteStore();
    final engine = SyncEngine(
      mirror: mirror,
      remote: remote,
      journal: journal,
      policy: ConflictPolicy(timestampOf: periodLastModified),
      lock: lock,
    );

    remote.seed('a.yaml', 'v1');
    files['a.yaml'] = 'v1';
    journal.dirty.add('a.yaml');

    Future<void>? pendingWrite;
    var writeDone = false;
    mirror.onRead = (name) async {
      if (pendingWrite != null) return;
      pendingWrite = app.writeString('a.yaml', 'v2').then((_) => writeDone = true);
      await Future<void>.delayed(Duration.zero);
      expect(writeDone, isFalse, reason: 'the write must wait for the lock');
    };

    final failure = await engine.pull();
    await pendingWrite;

    expect(failure, isNull);
    expect(files['a.yaml'], 'v2');
    expect(journal.dirty, contains('a.yaml'));
  });

  test('a local write during push snapshot keeps the name dirty', () async {
    final files = <String, String>{};
    final journal = SyncJournal();
    final lock = Lock();
    final mirror = _PausingWorkspace(files: files);
    final app = MemoryWorkspace(files: files, changeListener: journal, lock: lock);
    final remote = InMemoryRemoteStore();
    final engine = SyncEngine(
      mirror: mirror,
      remote: remote,
      journal: journal,
      policy: ConflictPolicy(timestampOf: periodLastModified),
      lock: lock,
    );

    await app.writeString('a.yaml', 'v1');

    Future<void>? pendingWrite;
    mirror.onRead = (name) async {
      if (pendingWrite != null) return;
      pendingWrite = app.writeString('a.yaml', 'v2');
      await Future<void>.delayed(Duration.zero);
    };

    final failure = await engine.push();
    await pendingWrite;

    expect(failure, isNull);
    expect(remote.files['a.yaml']!.content, 'v1');
    expect(files['a.yaml'], 'v2');
    expect(journal.dirty, contains('a.yaml'), reason: 'v2 still has to be pushed');
  });
}
```

- [ ] **Step 6: Run it to verify it fails**

Run: `flutter test test/sync/sync_engine_lock_test.dart`
Expected: FAIL to compile: `MemoryWorkspace` has no `lock` parameter, `SyncEngine` has no `lock` parameter.

- [ ] **Step 7: Add the lock to both workspaces**

In `lib/src/storage/vault_workspace.dart`, add `import '../sync/lock.dart';` and change both classes:

```dart
class DirectoryWorkspace implements VaultWorkspace {
  final String path;
  final WorkspaceChangeListener? changeListener;

  /// Shared with the sync engine of a remote vault so a local write can
  /// never land while the engine is comparing or resolving that file.
  final Lock? lock;

  DirectoryWorkspace(this.path, {this.changeListener, this.lock});

  Future<T> _guarded<T>(Future<T> Function() action) =>
      lock?.synchronized(action) ?? action();

  // listFiles, exists, readString unchanged

  @override
  Future<void> writeString(String name, String content) {
    assertSafeName(name);
    return _guarded(() async {
      await changeListener?.onChanged(name);
      final dir = Directory(path);
      if (!await dir.exists()) await dir.create(recursive: true);
      await _file(name).writeAsString(content, flush: true);
    });
  }

  @override
  Future<void> delete(String name) {
    assertSafeName(name);
    return _guarded(() async {
      final file = _file(name);
      if (!await file.exists()) return;
      await changeListener?.onChanged(name);
      await file.delete();
    });
  }
}
```

Apply the same shape to `MemoryWorkspace`: add `final Lock? lock;`, the constructor parameter `this.lock`, the `_guarded` helper, and wrap the bodies of `writeString` and `delete`.

- [ ] **Step 8: Add the lock to the engine**

In `lib/src/sync/sync_engine.dart`:

```dart
import 'lock.dart';
// ...
class SyncEngine {
  static const maxConflictRounds = 3;

  final VaultWorkspace mirror;
  final RemoteStore remote;
  final SyncJournal journal;
  final ConflictPolicy policy;

  /// Shared with the app-facing workspace. Held while a dirty file is read,
  /// compared and resolved, so a concurrent local write waits and then
  /// re-marks the name dirty instead of being stranded.
  final Lock lock;

  SyncEngine({
    required this.mirror,
    required this.remote,
    required this.journal,
    required this.policy,
    Lock? lock,
  }) : lock = lock ?? Lock();
```

In `_snapshot`, wrap the per-name body:

```dart
    for (final name in journal.dirty.toList()) {
      await lock.synchronized(() async {
        final base = journal.baseline[name];
        if (await mirror.exists(name)) {
          final content = await mirror.readString(name);
          changes.add(
            RemotePut(name: name, content: content, expectedVersion: base?.version),
          );
          hashes[name] = contentHash(content);
        } else if (base != null) {
          changes.add(RemoteDelete(name: name, expectedVersion: base.version));
          hashes[name] = null;
        } else {
          // Created and deleted before it was ever pushed.
          journal.dirty.remove(name);
        }
      });
    }
```

In `_commit`, wrap the per-entry body in `await lock.synchronized(() async { ... });` the same way (the whole body from `final name = entry.key;` to `if (currentHash == pushedHash) journal.dirty.remove(name);`).

In `_pull`, replace the block that starts with the `// TODO(sync)` comment:

```dart
      await lock.synchronized(() async {
        final local =
            await mirror.exists(name) ? await mirror.readString(name) : null;
        if (local == remoteFile.content) {
          // An interrupted earlier push already landed this file.
          journal.dirty.remove(name);
        } else {
          await _resolveConflict(name, local, remoteFile.content);
        }
        journal.baseline[name] = remoteEntry;
      });
```

- [ ] **Step 9: Wire the lock in the resolver**

In `lib/src/storage/vault_resolver.dart` `_openRemote`, after the journal is loaded:

```dart
    final journal = await SyncJournal.load(paths.journalFor(vault.id));
    final mirrorPath = paths.mirrorFor(vault.id);
    // One lock per vault: the app-facing workspace and the engine share it.
    // The engine's own mirror workspace does not take it, because the engine
    // already holds it when it writes and the lock is not reentrant.
    final lock = Lock();
    final engine = SyncEngine(
      mirror: DirectoryWorkspace(mirrorPath),
      remote: store,
      journal: journal,
      policy: policy,
      lock: lock,
    );
    // ... scheduler unchanged ...
    return OpenVault(
      vault: vault,
      workspace: DirectoryWorkspace(mirrorPath, changeListener: journal, lock: lock),
      scheduler: scheduler,
    );
```

Add `import '../sync/lock.dart';`.

- [ ] **Step 10: Run the whole suite**

Run: `flutter analyze && flutter test`
Expected: all green, including the two new race tests and every existing engine and workspace test.

- [ ] **Step 11: Commit**

```bash
git add lib/src/sync/lock.dart lib/src/storage/vault_workspace.dart lib/src/sync/sync_engine.dart lib/src/storage/vault_resolver.dart test/sync/lock_test.dart test/sync/sync_engine_lock_test.dart
git commit -m "feat: lock local writes against the sync engine's per-file resolution"
```

---

### Task 2: Remote store exceptions and offline classification

**Files:**
- Modify: `lib/src/sync/remote_store.dart` (add two exceptions after `RemoteConflict`)
- Modify: `lib/src/sync/sync_engine.dart:20-30` (`SyncFailure.from`)
- Test: `test/sync/sync_failure_test.dart`

**Interfaces:**
- Produces: `class RemoteUnreachable implements Exception { final String message; const RemoteUnreachable(this.message); }` with `toString() => message`.
- Produces: `class RemoteAuthRejected implements Exception { final String message; const RemoteAuthRejected([this.message = 'The provider rejected the token. Replace it in the vault settings.']); }` with `toString() => message`.
- `SyncFailure.from(RemoteUnreachable(...))` has `isOffline == true`.

- [ ] **Step 1: Write the failing test**

`test/sync/sync_failure_test.dart`:

```dart
import 'dart:io';

import 'package:flatplan/src/sync/remote_store.dart';
import 'package:flatplan/src/sync/sync_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('RemoteUnreachable is offline and keeps its message', () {
    final failure = SyncFailure.from(const RemoteUnreachable('Could not reach host'));
    expect(failure.isOffline, isTrue);
    expect(failure.message, 'Could not reach host');
  });

  test('RemoteAuthRejected is an error with a user-facing message', () {
    final failure = SyncFailure.from(const RemoteAuthRejected());
    expect(failure.isOffline, isFalse);
    expect(failure.message, contains('Replace it in the vault settings'));
  });

  test('socket errors stay offline', () {
    expect(SyncFailure.from(const SocketException('x')).isOffline, isTrue);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/sync/sync_failure_test.dart`
Expected: FAIL, `RemoteUnreachable` undefined.

- [ ] **Step 3: Add the exceptions and the mapping**

Append to `lib/src/sync/remote_store.dart` after `RemoteConflict`:

```dart
/// The provider could not be reached: no network, a timeout, a handshake
/// failure, or the server asking to come back later (429, 502, 503, 504).
/// The engine shows this as "Offline" and retries on the next trigger.
class RemoteUnreachable implements Exception {
  final String message;

  const RemoteUnreachable(this.message);

  @override
  String toString() => message;
}

/// The provider refused the stored credentials (HTTP 401).
class RemoteAuthRejected implements Exception {
  final String message;

  const RemoteAuthRejected([
    this.message =
        'The provider rejected the token. Replace it in the vault settings.',
  ]);

  @override
  String toString() => message;
}
```

In `sync_engine.dart`, `SyncFailure.from`:

```dart
  factory SyncFailure.from(Object error) => SyncFailure(
    message: error.toString(),
    isOffline:
        error is RemoteUnreachable ||
        error is SocketException ||
        error is TimeoutException ||
        error is HttpException,
  );
```

- [ ] **Step 4: Run the tests**

Run: `flutter analyze && flutter test test/sync`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/src/sync/remote_store.dart lib/src/sync/sync_engine.dart test/sync/sync_failure_test.dart
git commit -m "feat: add unreachable and auth-rejected remote store errors"
```

---

### Task 3: `gitBlobSha`

**Files:**
- Create: `lib/src/sync/gitlab/git_blob.dart`
- Test: `test/sync/gitlab/git_blob_test.dart`

**Interfaces:**
- Produces: `String gitBlobSha(String content)` — 40-char lower-case hex SHA-1 of `"blob <utf8 byte length>\0" + utf8 bytes`.

- [ ] **Step 1: Write the failing test**

The expected values come from `git hash-object --stdin`: the empty blob, `printf 'hello\n'`, and `printf 'Größe: 5 €\n'` (the last one has 14 bytes but 11 code units, so it catches a length bug).

```dart
import 'package:flatplan/src/sync/gitlab/git_blob.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('empty content hashes to the empty git blob', () {
    expect(gitBlobSha(''), 'e69de29bb2d1d6434b8b29ae775ad8c2e48c5391');
  });

  test('matches git hash-object for ASCII content', () {
    expect(gitBlobSha('hello\n'), 'ce013625030ba8dba906f756967f9e9ca394464a');
  });

  test('uses the UTF-8 byte length, not the code-unit length', () {
    expect(gitBlobSha('Größe: 5 €\n'), '172dbb623ac2f4951918c960d75321a87fb78e9e');
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/sync/gitlab/git_blob_test.dart`
Expected: FAIL, file missing.

- [ ] **Step 3: Implement**

`lib/src/sync/gitlab/git_blob.dart`:

```dart
import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Git's blob object id for [content]: SHA-1 of `"blob <len>\0" + bytes`.
/// Equal to the `id` the GitLab tree endpoint returns for a file, so a
/// push can report the new version of a file without another request.
String gitBlobSha(String content) {
  final bytes = utf8.encode(content);
  final header = utf8.encode('blob ${bytes.length} ');
  return sha1.convert([...header, ...bytes]).toString();
}
```

- [ ] **Step 4: Run the test**

Run: `flutter test test/sync/gitlab/git_blob_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/src/sync/gitlab/git_blob.dart test/sync/gitlab/git_blob_test.dart
git commit -m "feat: compute git blob ids locally"
```

---

### Task 4: `GitLabSettings`

**Files:**
- Create: `lib/src/sync/gitlab/gitlab_settings.dart`
- Test: `test/sync/gitlab/gitlab_settings_test.dart`

**Interfaces:**
- Produces:

```dart
class GitLabSettings {
  static const kind = 'gitlab';
  static const secretName = 'token';
  static const gitLabCom = 'https://gitlab.com';
  final String baseUrl; final int projectId; final String projectPath;
  final String branch; final String folder; final String? certFingerprint;
  const GitLabSettings({required this.baseUrl, required this.projectId, required this.projectPath, required this.branch, this.folder = '', this.certFingerprint});
  factory GitLabSettings.fromSettings(Map<String, dynamic> settings);
  Map<String, dynamic> toSettings();
  GitLabSettings copyWith({String? folder, String? certFingerprint, bool clearFingerprint = false});
  String get host;               // Uri.parse(baseUrl).host
  bool get isGitLabCom;          // host == 'gitlab.com'
  String get locationLine;       // "GitLab · group/repo/budget" or "<host> · group/repo/budget"
  String pathOf(String name);    // "<folder>/<name>" or "<name>"
  static String normalizeBaseUrl(String raw);  // trim, strip trailing slashes, add https:// when no scheme
  static String normalizeFolder(String raw);   // trim, strip leading/trailing slashes
}
```

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flatplan/src/sync/gitlab/gitlab_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const full = GitLabSettings(
    baseUrl: 'https://gitlab.example.com',
    projectId: 42,
    projectPath: 'group/repo',
    branch: 'main',
    folder: 'budget',
    certFingerprint: 'AB:CD',
  );

  test('round-trips through the settings map with snake_case keys', () {
    final map = full.toSettings();
    expect(map, {
      'base_url': 'https://gitlab.example.com',
      'project_id': 42,
      'project_path': 'group/repo',
      'branch': 'main',
      'folder': 'budget',
      'cert_fingerprint': 'AB:CD',
    });
    final back = GitLabSettings.fromSettings(map);
    expect(back.toSettings(), map);
  });

  test('omits the fingerprint key when unset and accepts a string project id', () {
    final s = GitLabSettings.fromSettings({
      'base_url': 'https://gitlab.com',
      'project_id': '7',
      'project_path': 'me/budget',
      'branch': 'main',
    });
    expect(s.projectId, 7);
    expect(s.folder, '');
    expect(s.certFingerprint, isNull);
    expect(s.toSettings().containsKey('cert_fingerprint'), isFalse);
  });

  test('location line names GitLab for gitlab.com and the host otherwise', () {
    expect(full.locationLine, 'gitlab.example.com · group/repo/budget');
    final com = GitLabSettings(
      baseUrl: GitLabSettings.gitLabCom,
      projectId: 1,
      projectPath: 'me/budget',
      branch: 'main',
    );
    expect(com.isGitLabCom, isTrue);
    expect(com.locationLine, 'GitLab · me/budget');
  });

  test('pathOf joins the folder only when set', () {
    expect(full.pathOf('a.yaml'), 'budget/a.yaml');
    expect(full.copyWith(folder: '').pathOf('a.yaml'), 'a.yaml');
  });

  test('normalisers strip slashes and add a scheme', () {
    expect(GitLabSettings.normalizeBaseUrl(' gitlab.example.com/ '), 'https://gitlab.example.com');
    expect(GitLabSettings.normalizeBaseUrl('http://10.0.0.5:8080//'), 'http://10.0.0.5:8080');
    expect(GitLabSettings.normalizeFolder(' /budget/2026/ '), 'budget/2026');
    expect(GitLabSettings.normalizeFolder('/'), '');
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/sync/gitlab/gitlab_settings_test.dart`
Expected: FAIL, file missing.

- [ ] **Step 3: Implement**

```dart
/// Typed view over a GitLab vault's non-secret settings map. The store, the
/// form and the location line go through this and never read raw keys.
class GitLabSettings {
  static const kind = 'gitlab';
  static const secretName = 'token';
  static const gitLabCom = 'https://gitlab.com';

  final String baseUrl;
  final int projectId;
  final String projectPath;
  final String branch;
  final String folder;
  final String? certFingerprint;

  const GitLabSettings({
    required this.baseUrl,
    required this.projectId,
    required this.projectPath,
    required this.branch,
    this.folder = '',
    this.certFingerprint,
  });

  factory GitLabSettings.fromSettings(Map<String, dynamic> settings) =>
      GitLabSettings(
        baseUrl: settings['base_url'] as String,
        projectId: int.parse(settings['project_id'].toString()),
        projectPath: settings['project_path'] as String,
        branch: settings['branch'] as String,
        folder: settings['folder'] as String? ?? '',
        certFingerprint: settings['cert_fingerprint'] as String?,
      );

  Map<String, dynamic> toSettings() => {
    'base_url': baseUrl,
    'project_id': projectId,
    'project_path': projectPath,
    'branch': branch,
    'folder': folder,
    if (certFingerprint != null) 'cert_fingerprint': certFingerprint,
  };

  GitLabSettings copyWith({
    String? folder,
    String? certFingerprint,
    bool clearFingerprint = false,
  }) => GitLabSettings(
    baseUrl: baseUrl,
    projectId: projectId,
    projectPath: projectPath,
    branch: branch,
    folder: folder ?? this.folder,
    certFingerprint:
        clearFingerprint ? null : (certFingerprint ?? this.certFingerprint),
  );

  String get host => Uri.parse(baseUrl).host;

  bool get isGitLabCom => host == 'gitlab.com';

  String get locationLine {
    final where = isGitLabCom ? 'GitLab' : host;
    final path = folder.isEmpty ? projectPath : '$projectPath/$folder';
    return '$where · $path';
  }

  String pathOf(String name) => folder.isEmpty ? name : '$folder/$name';

  static String normalizeBaseUrl(String raw) {
    var value = raw.trim().replaceAll(RegExp(r'/+$'), '');
    if (!value.contains('://')) value = 'https://$value';
    return value;
  }

  static String normalizeFolder(String raw) =>
      raw.trim().replaceAll(RegExp(r'^/+|/+$'), '');
}
```

- [ ] **Step 4: Run the test**

Run: `flutter test test/sync/gitlab/gitlab_settings_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/src/sync/gitlab/gitlab_settings.dart test/sync/gitlab/gitlab_settings_test.dart
git commit -m "feat: add the typed GitLab vault settings"
```

---

### Task 5: `GitLabApi` and the `FakeGitLab` test double

**Files:**
- Create: `lib/src/sync/gitlab/gitlab_api.dart`
- Create: `test/sync/gitlab/fake_gitlab.dart`
- Test: `test/sync/gitlab/gitlab_api_test.dart`
- Modify: `pubspec.yaml` (add `http: ^1.6.0` under dependencies)

**Interfaces:**
- Consumes: `RemoteUnreachable`, `RemoteAuthRejected` (Task 2), `gitBlobSha` (Task 3, used by the fake).
- Produces (all in `gitlab_api.dart`):

```dart
class GitLabApiException implements Exception { final int status; final String message; toString() => message; }
class CertificateRejected implements Exception { final String host; final String subject; final String fingerprint; toString() => 'The certificate of $host is not trusted.'; }
class ProjectSummary { final int id; final String name; final String pathWithNamespace; final String defaultBranch; final bool emptyRepo; factory ProjectSummary.fromJson(Map<String, dynamic>); }
class TreeEntry { final String id; final String name; final String type; final String path; bool get isBlob; }
class RawFile { final String content; final String blobId; }
class CommitAction { final String action; final String filePath; final String? content; Map<String, dynamic> toJson(); }
class TokenInfo { final List<String> scopes; final bool isFineGrained; }
class GitLabApi {
  GitLabApi({required http.Client client, required String baseUrl, required String token, Duration timeout = const Duration(seconds: 30), CertificateRejected? Function()? takeRejectedCertificate});
  Future<List<ProjectSummary>> searchProjects(String query);
  Future<ProjectSummary> projectByPath(String path);
  Future<ProjectSummary> project(int id);
  Future<List<String>> branches(int id);
  Future<bool> branchExists(int id, String name);
  Future<List<TreeEntry>> tree(int id, String ref, String path);   // follows x-next-page
  Future<RawFile> rawFile(int id, String ref, String path);
  Future<String> commit(int id, String branch, String message, List<CommitAction> actions); // returns commit sha
  Future<TokenInfo> tokenInfo();
}
```

- Produces (`fake_gitlab.dart`): `class FakeGitLab { ... http.Client get client; }` described in Step 3.

- [ ] **Step 1: Add the dependency**

In `pubspec.yaml` under `dependencies:` add `http: ^1.6.0` after `crypto`. Run `flutter pub get`.

- [ ] **Step 2: Write the fake**

`test/sync/gitlab/fake_gitlab.dart`. It answers the exact endpoints the app uses, keeps a repository as `path -> content`, and computes blob ids with `gitBlobSha` so the store's locally computed versions match.

```dart
import 'dart:convert';
import 'dart:io';

import 'package:flatplan/src/sync/gitlab/git_blob.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A scripted GitLab: enough of the REST API for FlatPlan, in memory.
class FakeGitLab {
  static const baseUrl = 'https://gitlab.test';

  /// Repository files by full path, e.g. `budget/2026-09-september.yaml`.
  final Map<String, String> files = {};
  final List<String> branches = ['main'];
  bool emptyRepo = false;
  int projectId = 42;
  String projectPath = 'group/repo';
  String projectName = 'repo';
  String defaultBranch = 'main';

  /// Projects returned by the search, in order. Defaults to the one above.
  List<Map<String, dynamic>>? searchResults;

  String validToken = 'glpat-secret';
  List<String> tokenScopes = ['api'];
  bool fineGrained = false;

  /// When set, `/personal_access_tokens/self` answers with this status.
  int? tokenInfoStatus;

  /// Path prefix -> status code, to force errors on specific endpoints.
  final Map<String, int> failWith = {};

  /// When set, every request throws it (offline).
  Object? throwOnRequest;

  /// Message returned with a forced 400 on commit.
  String commitErrorMessage = 'You are not allowed to push into this branch';

  /// Every request, as `METHOD path?query`.
  final List<String> calls = [];
  int treePageSize = 100;

  late final http.Client client = MockClient(_handle);

  Map<String, dynamic> get _projectJson => {
    'id': projectId,
    'name': projectName,
    'path_with_namespace': projectPath,
    'default_branch': defaultBranch,
    'empty_repo': emptyRepo,
  };

  Future<http.Response> _handle(http.Request request) async {
    final error = throwOnRequest;
    if (error != null) throw error;
    final path = request.url.path;
    calls.add('${request.method} $path${request.url.hasQuery ? '?${request.url.query}' : ''}');

    if (request.headers['PRIVATE-TOKEN'] != validToken) {
      return _json(401, {'message': '401 Unauthorized'});
    }
    for (final entry in failWith.entries) {
      if (path.startsWith('/api/v4${entry.key}')) {
        return _json(entry.value, {'message': 'forced ${entry.value}'});
      }
    }

    final p = '/api/v4/projects/$projectId';
    if (path == '/api/v4/projects' && request.method == 'GET') {
      final results = searchResults ?? [_projectJson];
      final q = request.url.queryParameters['search'] ?? '';
      return _json(200, [
        for (final r in results)
          if ((r['path_with_namespace'] as String).contains(q) ||
              (r['name'] as String).contains(q))
            r,
      ]);
    }
    if (path == '/api/v4/projects/${Uri.encodeComponent(projectPath)}' ||
        path == '/api/v4/projects/$projectPath') {
      return _json(200, _projectJson);
    }
    if (path == p) return _json(200, _projectJson);
    if (path == '$p/repository/branches') {
      return _json(200, [for (final b in branches) {'name': b}]);
    }
    if (path.startsWith('$p/repository/branches/')) {
      final name = Uri.decodeComponent(path.split('/').last);
      return branches.contains(name)
          ? _json(200, {'name': name})
          : _json(404, {'message': '404 Branch Not Found'});
    }
    if (path == '$p/repository/tree') return _tree(request);
    if (path.startsWith('$p/repository/files/') && path.endsWith('/raw')) {
      final encoded = path.substring('$p/repository/files/'.length, path.length - '/raw'.length);
      final filePath = Uri.decodeComponent(encoded);
      final content = files[filePath];
      if (content == null) return _json(404, {'message': '404 File Not Found'});
      return http.Response(content, 200, headers: {
        'x-gitlab-blob-id': gitBlobSha(content),
        'content-type': 'text/plain; charset=utf-8',
      });
    }
    if (path == '$p/repository/commits' && request.method == 'POST') {
      return _commit(request);
    }
    if (path == '/api/v4/personal_access_tokens/self') {
      final status = tokenInfoStatus;
      if (status != null) return _json(status, {'message': 'forced $status'});
      return _json(200, {
        'id': 1,
        'scopes': fineGrained ? <String>[] : tokenScopes,
        if (fineGrained)
          'granular_scopes': [
            {'access': 'selected_memberships', 'permissions': ['read_repository'], 'project_id': projectId, 'group_id': null},
          ],
      });
    }
    return _json(404, {'message': '404 Not Found'});
  }

  http.Response _tree(http.Request request) {
    if (emptyRepo) return _json(404, {'message': '404 Tree Not Found'});
    final ref = request.url.queryParameters['ref'];
    if (ref != null && !branches.contains(ref)) {
      return _json(404, {'message': '404 Tree Not Found'});
    }
    final folder = request.url.queryParameters['path'] ?? '';
    final prefix = folder.isEmpty ? '' : '$folder/';
    final entries = <Map<String, dynamic>>[];
    final seenDirs = <String>{};
    for (final path in files.keys.toList()..sort()) {
      if (!path.startsWith(prefix)) continue;
      final rest = path.substring(prefix.length);
      final slash = rest.indexOf('/');
      if (slash == -1) {
        entries.add({'id': gitBlobSha(files[path]!), 'name': rest, 'type': 'blob', 'path': path, 'mode': '100644'});
      } else {
        final dir = rest.substring(0, slash);
        if (seenDirs.add(dir)) {
          entries.add({'id': 'tree-$dir', 'name': dir, 'type': 'tree', 'path': '$prefix$dir', 'mode': '040000'});
        }
      }
    }
    if (folder.isNotEmpty && entries.isEmpty) {
      return _json(404, {'message': '404 Tree Not Found'});
    }
    final page = int.parse(request.url.queryParameters['page'] ?? '1');
    final start = (page - 1) * treePageSize;
    final slice = entries.skip(start).take(treePageSize).toList();
    final hasNext = start + treePageSize < entries.length;
    return http.Response(jsonEncode(slice), 200, headers: {
      'content-type': 'application/json',
      'x-next-page': hasNext ? '${page + 1}' : '',
    });
  }

  http.Response _commit(http.Request request) {
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    final branch = body['branch'] as String;
    if (failWith.containsKey('/commit-refused')) {
      return _json(400, {'message': commitErrorMessage});
    }
    final actions = (body['actions'] as List).cast<Map<String, dynamic>>();
    for (final a in actions) {
      final path = a['file_path'] as String;
      switch (a['action']) {
        case 'create':
          if (files.containsKey(path)) {
            return _json(400, {'message': 'A file with this name already exists'});
          }
          files[path] = a['content'] as String;
        case 'update':
          if (!files.containsKey(path)) {
            return _json(400, {'message': "A file with this name doesn't exist"});
          }
          files[path] = a['content'] as String;
        case 'delete':
          if (!files.containsKey(path)) {
            return _json(400, {'message': "A file with this name doesn't exist"});
          }
          files.remove(path);
      }
    }
    if (emptyRepo) {
      emptyRepo = false;
      if (!branches.contains(branch)) branches.add(branch);
    }
    return _json(201, {'id': 'commit-${calls.length}'});
  }

  static http.Response _json(int status, Object body) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );
}

/// The error the http package throws for a dropped socket.
Object socketDropped() => const SocketException('connection refused');
```

- [ ] **Step 3: Write the failing api tests**

`test/sync/gitlab/gitlab_api_test.dart`:

```dart
import 'dart:async';

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

  test('tokenInfo reports legacy scopes and fine-grained tokens', () async {
    expect((await api.tokenInfo()).scopes, ['api']);
    gitlab.fineGrained = true;
    expect((await api.tokenInfo()).isFineGrained, isTrue);
  });

  test('401 becomes RemoteAuthRejected', () async {
    api = GitLabApi(client: gitlab.client, baseUrl: FakeGitLab.baseUrl, token: 'wrong');
    await expectLater(api.project(42), throwsA(isA<RemoteAuthRejected>()));
  });

  test('403 keeps GitLab message in GitLabApiException', () async {
    gitlab.failWith['/projects/42/repository/tree'] = 403;
    await expectLater(
      api.tree(42, 'main', ''),
      throwsA(isA<GitLabApiException>().having((e) => e.status, 'status', 403).having((e) => e.message, 'message', 'forced 403')),
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
```

Add `import 'dart:io' show HandshakeException;` at the top of the test.

- [ ] **Step 4: Run it to verify it fails**

Run: `flutter test test/sync/gitlab/gitlab_api_test.dart`
Expected: FAIL, `gitlab_api.dart` missing.

- [ ] **Step 5: Implement `GitLabApi`**

`lib/src/sync/gitlab/gitlab_api.dart`:

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../remote_store.dart';

/// A non-2xx answer other than 401 and the "come back later" statuses.
class GitLabApiException implements Exception {
  final int status;
  final String message;

  const GitLabApiException(this.status, this.message);

  @override
  String toString() => message;
}

/// The server presented a certificate the system does not trust and that
/// does not match the vault's pinned fingerprint. Carries what the user
/// needs to decide whether to trust it.
class CertificateRejected implements Exception {
  final String host;
  final String subject;
  final String fingerprint;

  const CertificateRejected({
    required this.host,
    required this.subject,
    required this.fingerprint,
  });

  @override
  String toString() =>
      'The certificate of $host is not trusted. '
      'Trust it in the vault settings.';
}

class ProjectSummary {
  final int id;
  final String name;
  final String pathWithNamespace;
  final String defaultBranch;
  final bool emptyRepo;

  const ProjectSummary({
    required this.id,
    required this.name,
    required this.pathWithNamespace,
    required this.defaultBranch,
    required this.emptyRepo,
  });

  factory ProjectSummary.fromJson(Map<String, dynamic> json) => ProjectSummary(
    id: json['id'] as int,
    name: json['name'] as String,
    pathWithNamespace: json['path_with_namespace'] as String,
    defaultBranch: json['default_branch'] as String? ?? 'main',
    emptyRepo: json['empty_repo'] as bool? ?? false,
  );
}

class TreeEntry {
  final String id;
  final String name;
  final String type;
  final String path;

  const TreeEntry({required this.id, required this.name, required this.type, required this.path});

  bool get isBlob => type == 'blob';

  factory TreeEntry.fromJson(Map<String, dynamic> json) => TreeEntry(
    id: json['id'] as String,
    name: json['name'] as String,
    type: json['type'] as String,
    path: json['path'] as String,
  );
}

class RawFile {
  final String content;
  final String blobId;

  const RawFile({required this.content, required this.blobId});
}

class CommitAction {
  final String action; // create | update | delete
  final String filePath;
  final String? content;

  const CommitAction({required this.action, required this.filePath, this.content});

  Map<String, dynamic> toJson() => {
    'action': action,
    'file_path': filePath,
    if (content != null) 'content': content,
  };
}

class TokenInfo {
  final List<String> scopes;

  /// True for a fine-grained token, which reports `granular_scopes`
  /// instead of `scopes`.
  final bool isFineGrained;

  const TokenInfo({required this.scopes, required this.isFineGrained});
}

/// Thin typed client over the GitLab REST API v4. Every method throws
/// [RemoteUnreachable], [RemoteAuthRejected], [CertificateRejected] or
/// [GitLabApiException]; nothing else escapes.
class GitLabApi {
  final http.Client client;
  final String baseUrl;
  final String token;
  final Duration timeout;

  /// Set by the pinned client: returns and clears the certificate it just
  /// rejected, so a handshake failure can be reported as an offer to trust.
  final CertificateRejected? Function()? takeRejectedCertificate;

  GitLabApi({
    required this.client,
    required this.baseUrl,
    required this.token,
    this.timeout = const Duration(seconds: 30),
    this.takeRejectedCertificate,
  });

  Future<List<ProjectSummary>> searchProjects(String query) async {
    final body = await _getJson('/projects', {
      'membership': 'true',
      'min_access_level': '30',
      'simple': 'true',
      'search_namespaces': 'true',
      'order_by': 'last_activity_at',
      'per_page': '50',
      'search': query,
    });
    return [for (final p in body as List) ProjectSummary.fromJson(p as Map<String, dynamic>)];
  }

  Future<ProjectSummary> projectByPath(String path) async =>
      ProjectSummary.fromJson(await _getJson('/projects/${Uri.encodeComponent(path)}') as Map<String, dynamic>);

  Future<ProjectSummary> project(int id) async =>
      ProjectSummary.fromJson(await _getJson('/projects/$id') as Map<String, dynamic>);

  Future<List<String>> branches(int id) async {
    final body = await _getJson('/projects/$id/repository/branches', {'per_page': '100'});
    return [for (final b in body as List) (b as Map<String, dynamic>)['name'] as String];
  }

  Future<bool> branchExists(int id, String name) async {
    try {
      await _getJson('/projects/$id/repository/branches/${Uri.encodeComponent(name)}');
      return true;
    } on GitLabApiException catch (e) {
      if (e.status == 404) return false;
      rethrow;
    }
  }

  Future<List<TreeEntry>> tree(int id, String ref, String path) async {
    final entries = <TreeEntry>[];
    var page = 1;
    while (true) {
      final response = await _send('GET', '/projects/$id/repository/tree', query: {
        'ref': ref,
        'path': path,
        'per_page': '100',
        'page': '$page',
      });
      entries.addAll([
        for (final e in jsonDecode(response.body) as List) TreeEntry.fromJson(e as Map<String, dynamic>),
      ]);
      final next = response.headers['x-next-page'];
      if (next == null || next.isEmpty) return entries;
      page = int.parse(next);
    }
  }

  Future<RawFile> rawFile(int id, String ref, String path) async {
    final response = await _send(
      'GET',
      '/projects/$id/repository/files/${Uri.encodeComponent(path)}/raw',
      query: {'ref': ref},
    );
    final blobId = response.headers['x-gitlab-blob-id'];
    if (blobId == null) {
      throw GitLabApiException(response.statusCode, 'GitLab did not return a blob id for $path');
    }
    return RawFile(content: utf8.decode(response.bodyBytes), blobId: blobId);
  }

  Future<String> commit(int id, String branch, String message, List<CommitAction> actions) async {
    final body = await _postJson('/projects/$id/repository/commits', {
      'branch': branch,
      'commit_message': message,
      'actions': [for (final a in actions) a.toJson()],
    });
    return (body as Map<String, dynamic>)['id'] as String;
  }

  Future<TokenInfo> tokenInfo() async {
    final body = await _getJson('/personal_access_tokens/self') as Map<String, dynamic>;
    return TokenInfo(
      scopes: ((body['scopes'] as List?) ?? const []).cast<String>(),
      isFineGrained: body['granular_scopes'] != null,
    );
  }

  Future<Object?> _getJson(String path, [Map<String, String>? query]) async =>
      jsonDecode((await _send('GET', path, query: query)).body);

  Future<Object?> _postJson(String path, Map<String, dynamic> body) async =>
      jsonDecode((await _send('POST', path, jsonBody: body)).body);

  Uri _uri(String path, Map<String, String>? query) =>
      Uri.parse('$baseUrl/api/v4$path').replace(queryParameters: query);

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? jsonBody,
  }) async {
    final uri = _uri(path, query);
    final request = http.Request(method, uri)
      ..headers['PRIVATE-TOKEN'] = token
      ..headers['Accept'] = 'application/json';
    if (jsonBody != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(jsonBody);
    }

    final http.Response response;
    try {
      final streamed = await client.send(request).timeout(timeout);
      response = await http.Response.fromStream(streamed).timeout(timeout);
    } on HandshakeException catch (e) {
      final rejected = takeRejectedCertificate?.call();
      if (rejected != null) throw rejected;
      throw RemoteUnreachable('Secure connection to ${uri.host} failed: ${e.message}');
    } on TimeoutException {
      throw RemoteUnreachable('${uri.host} did not answer within ${timeout.inSeconds} s.');
    } on http.ClientException catch (e) {
      throw RemoteUnreachable('Could not reach ${uri.host}: ${e.message}');
    } on SocketException catch (e) {
      throw RemoteUnreachable('Could not reach ${uri.host}: ${e.message}');
    } on HttpException catch (e) {
      throw RemoteUnreachable('Could not reach ${uri.host}: ${e.message}');
    }

    final status = response.statusCode;
    if (status >= 200 && status < 300) return response;
    if (status == 401) throw RemoteAuthRejected(
      'GitLab rejected the token. Replace it in the vault settings.',
    );
    if (status == 429 || status == 502 || status == 503 || status == 504) {
      throw RemoteUnreachable('${uri.host} answered $status; will retry later.');
    }
    throw GitLabApiException(status, _messageOf(response));
  }

  static String _messageOf(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message'] ?? decoded['error'];
        if (message is String) return message;
        if (message != null) return message.toString();
      }
    } on FormatException {
      // Not JSON; fall through to the status line.
    }
    return 'HTTP ${response.statusCode}';
  }
}
```

- [ ] **Step 6: Run the api tests**

Run: `flutter analyze && flutter test test/sync/gitlab/gitlab_api_test.dart`
Expected: PASS (all tests, including the four "come back later" statuses).

- [ ] **Step 7: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/src/sync/gitlab/gitlab_api.dart test/sync/gitlab/fake_gitlab.dart test/sync/gitlab/gitlab_api_test.dart
git commit -m "feat: add the typed GitLab API client and its scripted fake"
```

---

### Task 6: Pinned HTTP client

**Files:**
- Create: `lib/src/sync/gitlab/gitlab_http.dart`
- Create: `test/fixtures/self_signed.pem`, `test/fixtures/self_signed.key`
- Test: `test/sync/gitlab/gitlab_http_test.dart`

**Interfaces:**
- Consumes: `CertificateRejected`, `GitLabApi` (Task 5), `GitLabSettings` (Task 4).
- Produces:

```dart
String certificateFingerprint(List<int> der);   // "AB:CD:..." SHA-256, 32 pairs
class PinnedClient { final http.Client client; CertificateRejected? takeRejected(); void close(); }
PinnedClient buildGitLabClient({required String host, String? certFingerprint, Duration timeout = const Duration(seconds: 30)});
GitLabApi gitLabApiFor({required GitLabSettings settings, required String token, http.Client? client});
```

`gitLabApiFor` is what production code calls: it builds the pinned client from the settings (or uses the given `client` in tests) and wires `takeRejectedCertificate`.

- [ ] **Step 1: Create the TLS fixture**

Run once and commit the two files:

```bash
mkdir -p test/fixtures
openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
  -keyout test/fixtures/self_signed.key -out test/fixtures/self_signed.pem \
  -subj "/CN=localhost" -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"
```

- [ ] **Step 2: Write the failing test**

`test/sync/gitlab/gitlab_http_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:flatplan/src/sync/gitlab/gitlab_api.dart';
import 'package:flatplan/src/sync/gitlab/gitlab_http.dart';
import 'package:flutter_test/flutter_test.dart';

/// DER bytes of the first certificate in a PEM file.
List<int> derOf(String pem) {
  final base64Body = pem
      .split('\n')
      .where((l) => l.isNotEmpty && !l.startsWith('-----'))
      .join();
  return base64.decode(base64Body);
}

void main() {
  test('fingerprint is upper-case SHA-256 pairs joined by colons', () {
    final fp = certificateFingerprint(utf8.encode('x'));
    expect(fp, matches(RegExp(r'^([0-9A-F]{2}:){31}[0-9A-F]{2}$')));
  });

  group('against a self-signed server', () {
    late HttpServer server;
    late String fingerprint;

    setUp(() async {
      final pem = File('test/fixtures/self_signed.pem').readAsStringSync();
      fingerprint = certificateFingerprint(derOf(pem));
      final context = SecurityContext()
        ..useCertificateChain('test/fixtures/self_signed.pem')
        ..usePrivateKey('test/fixtures/self_signed.key');
      server = await HttpServer.bindSecure('localhost', 0, context);
      server.listen((req) {
        req.response
          ..headers.contentType = ContentType.json
          ..write('{"id": 1, "name": "x", "path_with_namespace": "g/x", "default_branch": "main", "empty_repo": false}')
          ..close();
      });
    });

    tearDown(() => server.close(force: true));

    test('an unpinned client is offered the certificate', () async {
      final pinned = buildGitLabClient(host: 'localhost');
      final api = GitLabApi(
        client: pinned.client,
        baseUrl: 'https://localhost:${server.port}',
        token: 't',
        takeRejectedCertificate: pinned.takeRejected,
      );
      await expectLater(
        api.project(1),
        throwsA(isA<CertificateRejected>()
            .having((e) => e.fingerprint, 'fingerprint', fingerprint)
            .having((e) => e.host, 'host', 'localhost')
            .having((e) => e.subject, 'subject', contains('localhost'))),
      );
      pinned.close();
    });

    test('a client pinned to the right fingerprint succeeds', () async {
      final pinned = buildGitLabClient(host: 'localhost', certFingerprint: fingerprint);
      final api = GitLabApi(
        client: pinned.client,
        baseUrl: 'https://localhost:${server.port}',
        token: 't',
        takeRejectedCertificate: pinned.takeRejected,
      );
      expect((await api.project(1)).id, 1);
      pinned.close();
    });

    test('a client pinned to another fingerprint is offered the certificate', () async {
      final pinned = buildGitLabClient(host: 'localhost', certFingerprint: 'AA:BB');
      final api = GitLabApi(
        client: pinned.client,
        baseUrl: 'https://localhost:${server.port}',
        token: 't',
        takeRejectedCertificate: pinned.takeRejected,
      );
      await expectLater(api.project(1), throwsA(isA<CertificateRejected>()));
      pinned.close();
    });
  });
}
```

- [ ] **Step 3: Run it to verify it fails**

Run: `flutter test test/sync/gitlab/gitlab_http_test.dart`
Expected: FAIL, file missing.

- [ ] **Step 4: Implement**

`lib/src/sync/gitlab/gitlab_http.dart`:

```dart
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import 'gitlab_api.dart';
import 'gitlab_settings.dart';

/// SHA-256 of a certificate's DER bytes as `AB:CD:…`, the form shown to
/// the user and stored in the vault settings.
String certificateFingerprint(List<int> der) {
  final hex = sha256.convert(der).toString().toUpperCase();
  final pairs = <String>[];
  for (var i = 0; i < hex.length; i += 2) {
    pairs.add(hex.substring(i, i + 2));
  }
  return pairs.join(':');
}

/// An HTTP client that trusts at most one extra certificate, identified
/// by fingerprint, for one host. Any other untrusted certificate is
/// recorded so the caller can offer it to the user.
class PinnedClient {
  final http.Client client;
  final HttpClient _io;
  CertificateRejected? _rejected;

  PinnedClient._(this.client, this._io);

  /// The certificate rejected by the last failed handshake, if any. Clears
  /// it, so a later success does not report a stale offer.
  CertificateRejected? takeRejected() {
    final value = _rejected;
    _rejected = null;
    return value;
  }

  void close() {
    client.close();
    _io.close(force: true);
  }
}

PinnedClient buildGitLabClient({
  required String host,
  String? certFingerprint,
  Duration timeout = const Duration(seconds: 30),
}) {
  final io = HttpClient()..connectionTimeout = timeout;
  late final PinnedClient pinned;
  io.badCertificateCallback = (X509Certificate cert, String requestHost, int port) {
    final fingerprint = certificateFingerprint(cert.der);
    if (requestHost == host && certFingerprint != null && fingerprint == certFingerprint) {
      return true;
    }
    pinned._rejected = CertificateRejected(
      host: requestHost,
      subject: cert.subject,
      fingerprint: fingerprint,
    );
    return false;
  };
  pinned = PinnedClient._(IOClient(io), io);
  return pinned;
}

/// The API client production code uses for a vault. Tests pass [client]
/// to skip the real network.
GitLabApi gitLabApiFor({
  required GitLabSettings settings,
  required String token,
  http.Client? client,
}) {
  if (client != null) {
    return GitLabApi(client: client, baseUrl: settings.baseUrl, token: token);
  }
  final pinned = buildGitLabClient(
    host: settings.host,
    certFingerprint: settings.certFingerprint,
  );
  return GitLabApi(
    client: pinned.client,
    baseUrl: settings.baseUrl,
    token: token,
    takeRejectedCertificate: pinned.takeRejected,
  );
}
```

- [ ] **Step 5: Run the tests**

Run: `flutter analyze && flutter test test/sync/gitlab/gitlab_http_test.dart`
Expected: PASS (4 tests). If `bindSecure` fails on the CI runner for the fixture, the fixture's SAN must include `localhost`; regenerate with the command in Step 1.

- [ ] **Step 6: Commit**

```bash
git add lib/src/sync/gitlab/gitlab_http.dart test/fixtures test/sync/gitlab/gitlab_http_test.dart
git commit -m "feat: pin one trusted certificate per GitLab vault"
```

---

### Task 7: `GitLabRemoteStore`

**Files:**
- Create: `lib/src/sync/gitlab/gitlab_remote_store.dart`
- Test: `test/sync/gitlab/gitlab_remote_store_test.dart`, `test/sync/gitlab/gitlab_engine_test.dart`

**Interfaces:**
- Consumes: `GitLabApi`, `TreeEntry`, `CommitAction`, `GitLabApiException` (Task 5); `GitLabSettings` (Task 4); `gitBlobSha` (Task 3); `RemoteStore`, `RemotePut`, `RemoteDelete`, `RemoteFile`, `RemoteConflict` (`lib/src/sync/remote_store.dart`).
- Produces: `class GitLabRemoteStore implements RemoteStore { GitLabRemoteStore({required GitLabApi api, required GitLabSettings settings}); }` and `static const commitMessagePrefix = 'FlatPlan sync'`.

- [ ] **Step 1: Write the failing store tests**

`test/sync/gitlab/gitlab_remote_store_test.dart`:

```dart
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
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/sync/gitlab/gitlab_remote_store_test.dart`
Expected: FAIL, file missing.

- [ ] **Step 3: Implement the store**

`lib/src/sync/gitlab/gitlab_remote_store.dart`:

```dart
import '../remote_store.dart';
import 'git_blob.dart';
import 'gitlab_api.dart';
import 'gitlab_settings.dart';

/// A vault folder in a GitLab repository. Versions are git blob ids, so
/// identical content is never a conflict and a push can report new
/// versions without another request. Every push is one commit.
class GitLabRemoteStore implements RemoteStore {
  static const commitMessagePrefix = 'FlatPlan sync';

  final GitLabApi api;
  final GitLabSettings settings;

  GitLabRemoteStore({required this.api, required this.settings});

  static String commitMessage(int count) =>
      '$commitMessagePrefix: $count ${count == 1 ? 'file' : 'files'}';

  @override
  Future<Map<String, String>> listTree() async {
    final List<TreeEntry> entries;
    try {
      entries = await api.tree(settings.projectId, settings.branch, settings.folder);
    } on GitLabApiException catch (e) {
      if (e.status != 404) rethrow;
      // An empty answer makes the engine delete mirror files that are no
      // longer on the remote, so find out what is actually missing first.
      final project = await api.project(settings.projectId);
      if (project.emptyRepo) return const {};
      if (await api.branchExists(settings.projectId, settings.branch)) {
        return const {}; // the folder does not exist yet
      }
      throw GitLabApiException(
        404,
        "Branch '${settings.branch}' was not found in ${settings.projectPath}.",
      );
    }
    final prefix = settings.folder.isEmpty ? '' : '${settings.folder}/';
    return {
      for (final e in entries)
        if (e.isBlob && e.path == '$prefix${e.name}') e.name: e.id,
    };
  }

  @override
  Future<RemoteFile> read(String name) async {
    final file = await api.rawFile(settings.projectId, settings.branch, settings.pathOf(name));
    return RemoteFile(content: file.content, version: file.blobId);
  }

  @override
  Future<Map<String, String>> writeBatch(List<RemoteChange> changes) async {
    final current = await listTree();

    final stale = <String>[];
    for (final change in changes) {
      final live = current[change.name];
      switch (change) {
        case RemotePut(:final expectedVersion):
          if (expectedVersion == null ? live != null : live != expectedVersion) {
            stale.add(change.name);
          }
        case RemoteDelete(:final expectedVersion):
          if (live != expectedVersion) stale.add(change.name);
      }
    }
    if (stale.isNotEmpty) throw RemoteConflict(stale);

    final versions = <String, String>{};
    final actions = <CommitAction>[];
    for (final change in changes) {
      switch (change) {
        case RemotePut(:final name, :final content, :final expectedVersion):
          final sha = gitBlobSha(content);
          versions[name] = sha;
          if (sha == expectedVersion) continue; // already on the remote
          actions.add(CommitAction(
            action: expectedVersion == null ? 'create' : 'update',
            filePath: settings.pathOf(name),
            content: content,
          ));
        case RemoteDelete(:final name):
          actions.add(CommitAction(action: 'delete', filePath: settings.pathOf(name)));
      }
    }
    if (actions.isEmpty) return versions;

    try {
      await api.commit(
        settings.projectId,
        settings.branch,
        commitMessage(actions.length),
        actions,
      );
    } on GitLabApiException catch (e) {
      if (e.status == 400 && _looksLikeRefusal(e.message)) {
        throw GitLabApiException(
          400,
          "GitLab refused the push to '${settings.branch}': ${e.message}. "
          'Use another branch or a token with the Maintainer role.',
        );
      }
      rethrow;
    }
    return versions;
  }

  static bool _looksLikeRefusal(String message) {
    final lower = message.toLowerCase();
    return lower.contains('protected') ||
        lower.contains('not allowed') ||
        lower.contains('permission');
  }
}
```

- [ ] **Step 4: Run the store tests**

Run: `flutter analyze && flutter test test/sync/gitlab/gitlab_remote_store_test.dart`
Expected: PASS.

- [ ] **Step 5: Write the engine-over-GitLab test**

`test/sync/gitlab/gitlab_engine_test.dart` runs the engine's main scenarios through the real store and the fake server, proving the pieces fit:

```dart
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
```

- [ ] **Step 6: Run it**

Run: `flutter test test/sync/gitlab/gitlab_engine_test.dart`
Expected: PASS. If the newer-wins test fails on the side file name, check `conflictFileName` in `lib/src/sync/conflict_policy.dart` for the stamp format; the assertion only checks for `.conflict-`.

- [ ] **Step 7: Commit**

```bash
git add lib/src/sync/gitlab/gitlab_remote_store.dart test/sync/gitlab/gitlab_remote_store_test.dart test/sync/gitlab/gitlab_engine_test.dart
git commit -m "feat: add the GitLab remote store"
```

---

### Task 8: Keychain secrets, provider registration, platform setup

**Files:**
- Create: `lib/src/storage/secure_vault_secrets.dart`, `lib/src/sync/gitlab/gitlab_provider.dart`
- Create: `test/storage/secrets_contract.dart`, `test/storage/secure_vault_secrets_test.dart`, `test/sync/gitlab/gitlab_provider_test.dart`
- Modify: `lib/src/providers/vaults_provider.dart:19-22` (`vaultSecretsProvider`), `lib/src/providers/open_vault_provider.dart:13-15` (`remoteStoreRegistryProvider`)
- Modify: `pubspec.yaml` (`flutter_secure_storage: ^11.2.0`), `macos/Runner/DebugProfile.entitlements`, `macos/Runner/Release.entitlements`, `.github/workflows/release.yml:103-106`, `.github/workflows/ci.yml` (Linux test runner needs `libsecret-1-dev` too, since `flutter test` compiles the plugin registrant)
- Test containers that build `openVaultProvider` without overriding `vaultSecretsProvider` must now override it: check `test/open_vault_provider_test.dart:75` (already does), `test/dashboard_vault_state_test.dart`, `test/vault_switcher_test.dart`, `test/vault_list_view_test.dart`, `test/sync_lifecycle_bridge_test.dart`; add `vaultSecretsProvider.overrideWith((ref) => MemoryVaultSecrets())` wherever `openVaultProvider` or `vaultsProvider.remove` is exercised.

**Interfaces:**
- Produces: `class SecureVaultSecrets implements VaultSecrets { SecureVaultSecrets([FlutterSecureStorage? storage]); }`
- Produces: `Future<RemoteStore> gitLabStoreFactory(RemoteVaultLocation location, Map<String, String> secrets)` and `void registerGitLabProvider(RemoteStoreRegistry registry)`.
- Produces: `RemoteStoreRegistry remoteStoreRegistry(Ref ref)` now returns a registry with `gitlab` registered.

- [ ] **Step 1: Add the dependency and platform files**

`pubspec.yaml`: add `flutter_secure_storage: ^11.2.0` after `http`. Run `flutter pub get`.

Both macOS entitlements files: add inside `<dict>`:

```xml
	<key>com.apple.security.network.client</key>
	<true/>
	<key>keychain-access-groups</key>
	<array/>
```

`.github/workflows/release.yml`, Linux dependencies step: append ` libsecret-1-dev` to the `apt-get install` line. `.github/workflows/ci.yml`: add a step before "Setup Flutter":

```yaml
      - name: Install Linux dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y libsecret-1-dev
```

Verify the Debian package picks libsecret up automatically: `flutter_to_debian` derives `Depends` by scanning the bundle's shared libraries when configured from `pubspec.yaml`, which this project does. No config change.

- [ ] **Step 2: Write the secrets contract and the failing test**

`test/storage/secrets_contract.dart`:

```dart
import 'package:flatplan/src/storage/vault_secrets.dart';
import 'package:flutter_test/flutter_test.dart';

void runSecretsContract(String label, Future<VaultSecrets> Function() create) {
  group('$label contract', () {
    late VaultSecrets secrets;

    setUp(() async => secrets = await create());

    test('a missing secret reads as null', () async {
      expect(await secrets.read('v1', 'token'), isNull);
    });

    test('write then read round-trips per vault and name', () async {
      await secrets.write('v1', 'token', 'a');
      await secrets.write('v2', 'token', 'b');
      expect(await secrets.read('v1', 'token'), 'a');
      expect(await secrets.read('v2', 'token'), 'b');
      expect(await secrets.read('v1', 'other'), isNull);
    });

    test('overwrite replaces the value', () async {
      await secrets.write('v1', 'token', 'a');
      await secrets.write('v1', 'token', 'b');
      expect(await secrets.read('v1', 'token'), 'b');
    });

    test('deleteAll removes only the listed names of that vault', () async {
      await secrets.write('v1', 'token', 'a');
      await secrets.write('v1', 'other', 'o');
      await secrets.write('v2', 'token', 'b');
      await secrets.deleteAll('v1', ['token', 'missing']);
      expect(await secrets.read('v1', 'token'), isNull);
      expect(await secrets.read('v1', 'other'), 'o');
      expect(await secrets.read('v2', 'token'), 'b');
    });
  });
}
```

`test/storage/secure_vault_secrets_test.dart`:

```dart
import 'package:flatplan/src/storage/secure_vault_secrets.dart';
import 'package:flatplan/src/storage/vault_secrets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'secrets_contract.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  runSecretsContract('MemoryVaultSecrets', () async => MemoryVaultSecrets());
  runSecretsContract('SecureVaultSecrets', () async {
    FlutterSecureStorage.setMockInitialValues({});
    return SecureVaultSecrets();
  });
}
```

- [ ] **Step 3: Run it to verify it fails**

Run: `flutter test test/storage/secure_vault_secrets_test.dart`
Expected: FAIL, `secure_vault_secrets.dart` missing.

- [ ] **Step 4: Implement `SecureVaultSecrets`**

`lib/src/storage/secure_vault_secrets.dart`:

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'vault_secrets.dart';

/// [VaultSecrets] over the platform keychain or keystore. Keys are
/// `vault.<vaultId>.<name>`; nothing else in the app touches the plugin.
class SecureVaultSecrets implements VaultSecrets {
  final FlutterSecureStorage storage;

  SecureVaultSecrets([FlutterSecureStorage? storage])
    : storage = storage ?? const FlutterSecureStorage();

  @override
  Future<String?> read(String vaultId, String name) =>
      storage.read(key: vaultSecretKey(vaultId, name));

  @override
  Future<void> write(String vaultId, String name, String value) =>
      storage.write(key: vaultSecretKey(vaultId, name), value: value);

  @override
  Future<void> deleteAll(String vaultId, List<String> names) async {
    for (final name in names) {
      await storage.delete(key: vaultSecretKey(vaultId, name));
    }
  }
}
```

- [ ] **Step 5: Run the secrets tests**

Run: `flutter test test/storage/secure_vault_secrets_test.dart`
Expected: PASS (8 tests). If `setMockInitialValues` is not found, check the installed plugin version exposes it (`grep -rn setMockInitialValues ~/.pub-cache/hosted/pub.dev/flutter_secure_storage-*/lib`) and, if it is under a different name in 11.x, use that.

- [ ] **Step 6: Write the failing provider test**

`test/sync/gitlab/gitlab_provider_test.dart`:

```dart
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
```

- [ ] **Step 7: Implement the provider and switch the providers**

`lib/src/sync/gitlab/gitlab_provider.dart`:

```dart
import '../../models/models.dart';
import '../remote_store.dart';
import 'gitlab_http.dart';
import 'gitlab_remote_store.dart';
import 'gitlab_settings.dart';

/// Builds a [GitLabRemoteStore] for a vault. Makes no request: bad
/// credentials surface at the first sync, so opening works offline.
Future<RemoteStore> gitLabStoreFactory(
  RemoteVaultLocation location,
  Map<String, String> secrets,
) async {
  final settings = GitLabSettings.fromSettings(location.settings);
  final token = secrets[GitLabSettings.secretName];
  if (token == null) {
    throw StateError('The GitLab vault has no token in secure storage.');
  }
  return GitLabRemoteStore(
    api: gitLabApiFor(settings: settings, token: token),
    settings: settings,
  );
}

void registerGitLabProvider(RemoteStoreRegistry registry) =>
    registry.register(GitLabSettings.kind, gitLabStoreFactory);
```

`lib/src/providers/open_vault_provider.dart`:

```dart
import '../sync/gitlab/gitlab_provider.dart';
// ...
/// Remote kinds this build can open.
@Riverpod(keepAlive: true)
RemoteStoreRegistry remoteStoreRegistry(Ref ref) =>
    RemoteStoreRegistry()..let(registerGitLabProvider);
```

Dart has no `let`; write it as:

```dart
RemoteStoreRegistry remoteStoreRegistry(Ref ref) {
  final registry = RemoteStoreRegistry();
  registerGitLabProvider(registry);
  return registry;
}
```

`lib/src/providers/vaults_provider.dart`:

```dart
import '../storage/secure_vault_secrets.dart';
// ...
/// Secret storage for remote vaults: the platform keychain or keystore.
/// Tests override this with [MemoryVaultSecrets].
@Riverpod(keepAlive: true)
VaultSecrets vaultSecrets(Ref ref) => SecureVaultSecrets();
```

Run `dart run build_runner build --delete-conflicting-outputs` to refresh the `.g.dart` files.

- [ ] **Step 8: Fix test containers**

Run `flutter test`. Any test that now touches the real plugin fails with a `MissingPluginException`; add `vaultSecretsProvider.overrideWith((ref) => MemoryVaultSecrets())` to that test's `ProviderScope` or `ProviderContainer` overrides. Expected candidates are listed under Files above.

- [ ] **Step 9: Run everything**

Run: `flutter analyze && flutter test`
Expected: PASS.

- [ ] **Step 10: Commit**

```bash
git add pubspec.yaml pubspec.lock macos/Runner/DebugProfile.entitlements macos/Runner/Release.entitlements .github/workflows lib/src/storage/secure_vault_secrets.dart lib/src/sync/gitlab/gitlab_provider.dart lib/src/providers test/storage test/sync/gitlab/gitlab_provider_test.dart test
git commit -m "feat: register the GitLab provider and keep vault secrets in the keychain"
```

---

### Task 9: `GitLabConnectController`

**Files:**
- Create: `lib/src/providers/gitlab_connect_controller.dart`
- Test: `test/gitlab_connect_controller_test.dart`

**Interfaces:**
- Consumes: `GitLabApi`, `ProjectSummary`, `TokenInfo`, `CertificateRejected`, `GitLabApiException` (Task 5); `gitLabApiFor` (Task 6); `GitLabSettings` (Task 4); `RemoteUnreachable`, `RemoteAuthRejected` (Task 2).
- Produces:

```dart
typedef GitLabApiFactory = GitLabApi Function({required GitLabSettings settings, required String token});
@Riverpod(keepAlive: true) GitLabApiFactory gitLabApiFactory(Ref ref);   // production: gitLabApiFor without a client

enum ConnectStep { server, token, project, target }
enum FolderCheckKind { periodFiles, empty, newRepository, error }
class FolderCheck { final FolderCheckKind kind; final int count; final String? message; String describe(); }

class GitLabConnectController extends ChangeNotifier {
  GitLabConnectController({required GitLabApiFactory apiFactory, GitLabSettings? existing});
  bool selfHosted; String baseUrl; String? certFingerprint;
  ConnectStep step; bool busy; String? connectError; CertificateRejected? pendingCertificate;
  String? token;                       // kept in memory until save
  List<ProjectSummary> projects; ProjectSummary? project; List<String> branches; String? branch;
  String folder; FolderCheck? folderCheck; String? suggestedName;
  void setSelfHosted(bool value); void setBaseUrl(String raw);
  Future<void> connect(String token);   // probes; on success step = project
  Future<void> trustCertificate();      // stores pendingCertificate.fingerprint, reruns connect
  void dismissCertificate();
  Future<void> search(String query);    // debounced 300 ms
  Future<void> selectProject(ProjectSummary p);   // branches, default, step = target, checkFolder
  void selectBranch(String name);
  Future<void> setFolder(String raw);   // normalise + checkFolder
  Future<void> verifyReplacementToken(String token); // edit form: probes against the stored project
  bool get canSave;
  GitLabSettings toSettings();
}
```

- [ ] **Step 1: Write the failing tests**

`test/gitlab_connect_controller_test.dart`:

```dart
import 'dart:io';

import 'package:flatplan/src/providers/gitlab_connect_controller.dart';
import 'package:flatplan/src/sync/gitlab/gitlab_api.dart';
import 'package:flatplan/src/sync/gitlab/gitlab_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'sync/gitlab/fake_gitlab.dart';

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
      return gitlab.client.send(request).then(http.Response.fromStream);
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
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/gitlab_connect_controller_test.dart`
Expected: FAIL, file missing.

- [ ] **Step 3: Implement**

`lib/src/providers/gitlab_connect_controller.dart`:

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../sync/gitlab/gitlab_api.dart';
import '../sync/gitlab/gitlab_http.dart';
import '../sync/gitlab/gitlab_settings.dart';
import '../sync/remote_store.dart';

part 'gitlab_connect_controller.g.dart';

typedef GitLabApiFactory =
    GitLabApi Function({required GitLabSettings settings, required String token});

/// How the connect flow builds an API client. Tests override this with a
/// factory over a `MockClient`.
@Riverpod(keepAlive: true)
GitLabApiFactory gitLabApiFactory(Ref ref) =>
    ({required settings, required token}) =>
        gitLabApiFor(settings: settings, token: token);

enum ConnectStep { server, token, project, target }

enum FolderCheckKind { periodFiles, empty, newRepository, error }

class FolderCheck {
  final FolderCheckKind kind;
  final int count;
  final String? message;

  const FolderCheck.periodFiles(this.count)
    : kind = FolderCheckKind.periodFiles,
      message = null;
  const FolderCheck.empty() : kind = FolderCheckKind.empty, count = 0, message = null;
  const FolderCheck.newRepository()
    : kind = FolderCheckKind.newRepository,
      count = 0,
      message = null;
  const FolderCheck.error(this.message) : kind = FolderCheckKind.error, count = 0;

  String describe() => switch (kind) {
    FolderCheckKind.periodFiles =>
      '$count period ${count == 1 ? 'file' : 'files'} found',
    FolderCheckKind.empty => 'Empty, files will be created on first sync',
    FolderCheckKind.newRepository =>
      'New repository, the branch will be created on first sync',
    FolderCheckKind.error => message ?? 'Could not read the folder',
  };
}

/// Drives the GitLab connect wizard: server, token, project, branch and
/// folder. Owns the API client during setup so the form only renders.
class GitLabConnectController extends ChangeNotifier {
  static const searchDebounce = Duration(milliseconds: 300);
  static const legacyScopeError =
      'This legacy token needs the "api" scope. Create a new token with '
      'that scope, or a fine-grained token with the permissions listed below.';

  final GitLabApiFactory apiFactory;

  bool selfHosted = false;
  String baseUrl = GitLabSettings.gitLabCom;
  String? certFingerprint;
  ConnectStep step = ConnectStep.token;
  bool busy = false;
  String? connectError;
  CertificateRejected? pendingCertificate;

  /// Verified token, kept only until the form saves it to secure storage.
  String? token;

  List<ProjectSummary> projects = const [];
  ProjectSummary? project;
  List<String> branches = const [];
  String? branch;
  String folder = 'budget';
  FolderCheck? folderCheck;
  String? suggestedName;

  GitLabApi? _api;
  Timer? _searchTimer;

  GitLabConnectController({required this.apiFactory, GitLabSettings? existing}) {
    if (existing != null) {
      selfHosted = !existing.isGitLabCom;
      baseUrl = existing.baseUrl;
      certFingerprint = existing.certFingerprint;
      project = ProjectSummary(
        id: existing.projectId,
        name: existing.projectPath.split('/').last,
        pathWithNamespace: existing.projectPath,
        defaultBranch: existing.branch,
        emptyRepo: false,
      );
      branch = existing.branch;
      branches = [existing.branch];
      folder = existing.folder;
      step = ConnectStep.target;
    }
  }

  void setSelfHosted(bool value) {
    selfHosted = value;
    if (!value) baseUrl = GitLabSettings.gitLabCom;
    notifyListeners();
  }

  void setBaseUrl(String raw) {
    baseUrl = GitLabSettings.normalizeBaseUrl(raw);
    notifyListeners();
  }

  GitLabSettings _probeSettings() => GitLabSettings(
    baseUrl: baseUrl,
    projectId: project?.id ?? 0,
    projectPath: project?.pathWithNamespace ?? '',
    branch: branch ?? 'main',
    folder: folder,
    certFingerprint: certFingerprint,
  );

  Future<void> connect(String candidate) => _run(() async {
    connectError = null;
    pendingCertificate = null;
    token = null;
    final api = apiFactory(settings: _probeSettings(), token: candidate);
    projects = await api.searchProjects('');
    if (!await _legacyScopeOk(api)) {
      connectError = legacyScopeError;
      return;
    }
    _api = api;
    token = candidate;
    step = ConnectStep.project;
  });

  /// Best effort: only a legacy token can answer, and only a legacy token
  /// can lack `api`. A fine-grained token either reports granular scopes
  /// or cannot read tokens at all (403); both continue.
  Future<bool> _legacyScopeOk(GitLabApi api) async {
    try {
      final info = await api.tokenInfo();
      return info.isFineGrained || info.scopes.contains('api');
    } on GitLabApiException catch (e) {
      if (e.status == 403 || e.status == 404) return true;
      rethrow;
    }
  }

  Future<void> trustCertificate() async {
    final offer = pendingCertificate;
    final candidate = _pendingToken;
    if (offer == null || candidate == null) return;
    certFingerprint = offer.fingerprint;
    pendingCertificate = null;
    notifyListeners();
    if (step == ConnectStep.target) {
      await verifyReplacementToken(candidate);
    } else {
      await connect(candidate);
    }
  }

  void dismissCertificate() {
    pendingCertificate = null;
    notifyListeners();
  }

  String? _pendingToken;

  Future<void> search(String query) {
    _searchTimer?.cancel();
    final completer = Completer<void>();
    _searchTimer = Timer(searchDebounce, () async {
      await _run(() async {
        final api = _api;
        if (api == null) return;
        projects = await api.searchProjects(query);
        if (projects.isEmpty && query.contains('/')) {
          try {
            projects = [await api.projectByPath(query.trim())];
          } on GitLabApiException catch (e) {
            if (e.status != 404) rethrow;
          }
        }
      });
      completer.complete();
    });
    return completer.future;
  }

  Future<void> selectProject(ProjectSummary chosen) => _run(() async {
    final api = _api!;
    project = chosen;
    suggestedName = chosen.name;
    branches = await api.branches(chosen.id);
    if (branches.isEmpty) branches = [chosen.defaultBranch];
    branch = branches.contains(chosen.defaultBranch) ? chosen.defaultBranch : branches.first;
    step = ConnectStep.target;
    await _checkFolder(api);
  });

  void selectBranch(String name) {
    branch = name;
    notifyListeners();
    final api = _api;
    if (api != null) unawaited(_run(() => _checkFolder(api)));
  }

  Future<void> setFolder(String raw) => _run(() async {
    folder = GitLabSettings.normalizeFolder(raw);
    final api = _api;
    if (api != null) await _checkFolder(api);
  });

  Future<void> _checkFolder(GitLabApi api) async {
    final chosen = project;
    final ref = branch;
    if (chosen == null || ref == null) return;
    try {
      final entries = await api.tree(chosen.id, ref, folder);
      final prefix = folder.isEmpty ? '' : '$folder/';
      final periods = entries.where(
        (e) =>
            e.isBlob &&
            e.path == '$prefix${e.name}' &&
            e.name.endsWith('.yaml') &&
            !e.name.contains('.conflict-'),
      );
      folderCheck = periods.isEmpty ? const FolderCheck.empty() : FolderCheck.periodFiles(periods.length);
    } on GitLabApiException catch (e) {
      if (e.status == 404) {
        final fresh = await api.project(chosen.id);
        folderCheck = fresh.emptyRepo ? const FolderCheck.newRepository() : const FolderCheck.empty();
      } else {
        folderCheck = FolderCheck.error(e.message);
      }
    }
  }

  /// Edit form: proves [candidate] can read the stored project.
  Future<void> verifyReplacementToken(String candidate) => _run(() async {
    connectError = null;
    pendingCertificate = null;
    token = null;
    final api = apiFactory(settings: _probeSettings(), token: candidate);
    await api.searchProjects('');
    if (!await _legacyScopeOk(api)) {
      connectError = legacyScopeError;
      return;
    }
    await api.project(project!.id);
    _api = api;
    token = candidate;
  });

  bool get canSave =>
      token != null && project != null && branch != null && step == ConnectStep.target;

  GitLabSettings toSettings() => GitLabSettings(
    baseUrl: baseUrl,
    projectId: project!.id,
    projectPath: project!.pathWithNamespace,
    branch: branch!,
    folder: folder,
    certFingerprint: certFingerprint,
  );

  /// Runs one wizard action: sets [busy], maps every failure to
  /// [connectError] or [pendingCertificate], and notifies.
  Future<void> _run(Future<void> Function() action) async {
    busy = true;
    notifyListeners();
    try {
      await action();
    } on CertificateRejected catch (e) {
      pendingCertificate = e;
    } on RemoteAuthRejected {
      connectError = 'GitLab rejected this token. Check it and try again.';
    } on RemoteUnreachable catch (e) {
      connectError = 'Could not reach $baseUrl. ${e.message}';
    } on GitLabApiException catch (e) {
      connectError = e.message;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    super.dispose();
  }
}
```

`connect` and `verifyReplacementToken` must remember the candidate for `trustCertificate`: set `_pendingToken = candidate;` as their first line.

- [ ] **Step 4: Generate and run**

Run: `dart run build_runner build --delete-conflicting-outputs && flutter analyze && flutter test test/gitlab_connect_controller_test.dart`
Expected: PASS (13 tests). The certificate test relies on `_run` catching `CertificateRejected` from `searchProjects`; the fake `takeRejectedCertificate` returns the offer once.

- [ ] **Step 5: Commit**

```bash
git add lib/src/providers/gitlab_connect_controller.dart lib/src/providers/gitlab_connect_controller.g.dart test/gitlab_connect_controller_test.dart
git commit -m "feat: add the GitLab connect controller"
```

---

### Task 10: `GitLabVaultForm`, the kind descriptor, and the create flow

**Files:**
- Create: `lib/src/views/gitlab_vault_form.dart`
- Modify: `lib/src/views/vault_kinds.dart` (add `gitLabVaultKind`, extend `vaultKinds`)
- Test: `test/gitlab_vault_form_test.dart`, extend `test/vault_form_view_test.dart` with a chooser test

**Interfaces:**
- Consumes: `GitLabConnectController`, `gitLabApiFactoryProvider`, `ConnectStep`, `FolderCheck` (Task 9); `GitLabSettings` (Task 4); `CertificateRejected` (Task 5); `vaultsProvider`, `vaultSecretsProvider` (`lib/src/providers/vaults_provider.dart`); `VaultKindDescriptor`, `vaultKinds`, `vaultKindFor` (`lib/src/views/vault_kinds.dart`).
- Produces: `class GitLabVaultForm extends HookConsumerWidget { const GitLabVaultForm({super.key, this.existing}); }`, `const gitLabVaultKind`, `Future<bool> showTrustCertificateDialog(BuildContext, CertificateRejected)`.

- [ ] **Step 1: Write the failing widget tests**

`test/gitlab_vault_form_test.dart`:

```dart
import 'package:flatplan/src/models/models.dart';
import 'package:flatplan/src/providers/gitlab_connect_controller.dart';
import 'package:flatplan/src/providers/vaults_provider.dart';
import 'package:flatplan/src/storage/vault_secrets.dart';
import 'package:flatplan/src/sync/gitlab/gitlab_api.dart';
import 'package:flatplan/src/views/gitlab_vault_form.dart';
import 'package:flatplan/src/views/vault_kinds.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'support/fake_vaults.dart';
import 'sync/gitlab/fake_gitlab.dart';

void main() {
  late FakeGitLab gitlab;
  late FakeVaults fakeVaults;
  late MemoryVaultSecrets secrets;
  final created = DateTime.utc(2026, 1, 1);
  final home = Vault(
    id: 'home',
    name: 'Home',
    location: const VaultLocation.local(path: '/Users/me/budget'),
    createdAt: created,
  );

  Widget app(Widget child, {CertificateRejected? offer}) {
    fakeVaults = FakeVaults(VaultRegistry(lastSelectedVaultId: 'home', vaults: [home]));
    var offered = false;
    return ProviderScope(
      overrides: [
        vaultsProvider.overrideWith(() => fakeVaults),
        vaultSecretsProvider.overrideWith((ref) => secrets),
        gitLabApiFactoryProvider.overrideWith(
          (ref) => ({required settings, required token}) => GitLabApi(
            client: gitlab.client,
            baseUrl: settings.baseUrl,
            token: token,
            takeRejectedCertificate: () {
              if (offer == null || offered) return null;
              offered = true;
              gitlab.throwOnRequest = null;
              return offer;
            },
          ),
        ),
      ],
      child: MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child))),
    );
  }

  setUp(() {
    gitlab = FakeGitLab();
    secrets = MemoryVaultSecrets();
  });

  Future<void> connect(WidgetTester tester, {String? url}) async {
    if (url != null) {
      await tester.tap(find.text('Self-hosted instance'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('gitlab-url')), url);
    }
    await tester.enterText(find.byKey(const Key('gitlab-token')), gitlab.validToken);
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();
  }

  testWidgets('starts with the token step and no url field', (tester) async {
    await tester.pumpWidget(app(const GitLabVaultForm()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('gitlab-url')), findsNothing);
    expect(find.text('Connect'), findsOneWidget);
    expect(find.text('Create vault'), findsNothing);
  });

  testWidgets('the self-hosted checkbox reveals the url field', (tester) async {
    await tester.pumpWidget(app(const GitLabVaultForm()));
    await tester.tap(find.text('Self-hosted instance'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('gitlab-url')), findsOneWidget);
  });

  testWidgets('the token help lists the fine-grained permissions and the legacy scope', (tester) async {
    await tester.pumpWidget(app(const GitLabVaultForm()));
    await tester.tap(find.text('How to create a token'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Commit: Create'), findsOneWidget);
    expect(find.textContaining('Repository: Read'), findsOneWidget);
    expect(find.textContaining('api'), findsWidgets);
  });

  testWidgets('connecting reveals projects, selecting reveals branch, folder and name', (tester) async {
    gitlab.files['budget/2026-09-september.yaml'] = 'id: p\n';
    await tester.pumpWidget(app(const GitLabVaultForm()));
    await connect(tester, url: FakeGitLab.baseUrl);

    expect(find.text('Connected'), findsOneWidget);
    expect(find.text('group/repo'), findsOneWidget);

    await tester.tap(find.text('group/repo'));
    await tester.pumpAndSettle();

    expect(find.text('1 period file found'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'repo'), findsOneWidget);
    expect(find.text('Create vault'), findsOneWidget);
  });

  testWidgets('a rejected token shows the error and stays on the token step', (tester) async {
    gitlab.validToken = 'other';
    await tester.pumpWidget(app(const GitLabVaultForm()));
    await tester.enterText(find.byKey(const Key('gitlab-token')), 'wrong');
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();

    expect(find.textContaining('rejected'), findsOneWidget);
    expect(find.text('group/repo'), findsNothing);
  });

  testWidgets('an untrusted certificate opens the trust dialog and trusting continues', (tester) async {
    gitlab.throwOnRequest = const HandshakeException('untrusted');
    final offer = CertificateRejected(host: 'gitlab.test', subject: 'CN=gitlab.test', fingerprint: 'AA:BB:CC');
    await tester.pumpWidget(app(const GitLabVaultForm(), offer: offer));
    await connect(tester, url: FakeGitLab.baseUrl);

    expect(find.text('Trust this certificate?'), findsOneWidget);
    expect(find.textContaining('AA:BB:CC'), findsOneWidget);

    await tester.tap(find.text('Trust'));
    await tester.pumpAndSettle();

    expect(find.text('Connected'), findsOneWidget);
  });

  testWidgets('creating writes the secret first and then adds the vault', (tester) async {
    await tester.pumpWidget(app(const GitLabVaultForm()));
    await connect(tester, url: FakeGitLab.baseUrl);
    await tester.tap(find.text('group/repo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create vault'));
    await tester.pumpAndSettle();

    final vault = fakeVaults.added.single;
    expect(vault.name, 'repo');
    final location = vault.location as RemoteVaultLocation;
    expect(location.kind, 'gitlab');
    expect(location.secretNames, ['token']);
    expect(location.settings['project_id'], 42);
    expect(location.settings['folder'], 'budget');
    expect(await secrets.read(vault.id, 'token'), gitlab.validToken);
  });

  test('the descriptor renders the location line', () {
    final vault = Vault(
      id: 'g',
      name: 'G',
      location: const VaultLocation.remote(
        kind: 'gitlab',
        settings: {'base_url': 'https://gitlab.com', 'project_id': 1, 'project_path': 'me/budget', 'branch': 'main', 'folder': 'budget'},
        secretNames: ['token'],
      ),
      createdAt: created,
    );
    expect(vaultKindFor(vault), same(gitLabVaultKind));
    expect(gitLabVaultKind.locationLine(vault), 'GitLab · me/budget/budget');
    expect(vaultKinds.map((k) => k.kind), ['local', 'gitlab']);
  });
}
```

Add `import 'dart:io' show HandshakeException;` at the top.

In `test/vault_form_view_test.dart` add one test that `/settings/vaults/new` now shows the chooser with both kinds:

```dart
  testWidgets('a new vault starts with the kind chooser', (tester) async {
    await tester.pumpWidget(app(const VaultFormView()));
    await tester.pumpAndSettle();

    expect(find.text('Local folder'), findsOneWidget);
    expect(find.text('GitLab'), findsOneWidget);
  });
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/gitlab_vault_form_test.dart test/vault_form_view_test.dart`
Expected: FAIL, `gitlab_vault_form.dart` missing, `gitLabVaultKind` undefined.

- [ ] **Step 3: Register the kind**

In `lib/src/views/vault_kinds.dart`:

```dart
import '../sync/gitlab/gitlab_settings.dart';
import 'gitlab_vault_form.dart';

String _gitLabLocation(Vault vault) => switch (vault.location) {
  RemoteVaultLocation(:final settings) =>
    GitLabSettings.fromSettings(settings).locationLine,
  LocalVaultLocation() => '',
};

Widget _gitLabForm(BuildContext context, Vault? existing) =>
    GitLabVaultForm(key: ValueKey(existing?.id), existing: existing);

const gitLabVaultKind = VaultKindDescriptor(
  kind: GitLabSettings.kind,
  label: 'GitLab',
  icon: Icons.cloud_rounded,
  locationLine: _gitLabLocation,
  buildForm: _gitLabForm,
);

/// Kinds a user can create. Providers append to this list.
List<VaultKindDescriptor> get vaultKinds => const [localVaultKind, gitLabVaultKind];
```

- [ ] **Step 4: Implement the form**

`lib/src/views/gitlab_vault_form.dart`. Layout mirrors `LocalVaultForm`: a `Column` inside `Material(type: MaterialType.transparency)`, 20 px between fields, `FilledButton` on the right.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import '../providers/gitlab_connect_controller.dart';
import '../providers/vaults_provider.dart';
import '../sync/gitlab/gitlab_api.dart';
import '../sync/gitlab/gitlab_settings.dart';

/// Create or edit a GitLab vault. One scrolling column that reveals each
/// step as the previous one succeeds; nothing needs a wide screen.
class GitLabVaultForm extends HookConsumerWidget {
  final Vault? existing;

  const GitLabVaultForm({super.key, this.existing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final existingSettings = switch (existing?.location) {
      RemoteVaultLocation(:final settings) => GitLabSettings.fromSettings(settings),
      _ => null,
    };
    final controller = useMemoized(
      () => GitLabConnectController(
        apiFactory: ref.read(gitLabApiFactoryProvider),
        existing: existingSettings,
      ),
      [existing?.id],
    );
    useEffect(() => controller.dispose, [controller]);
    useListenable(controller);

    final name = useTextEditingController(text: existing?.name ?? '');
    final url = useTextEditingController(text: existingSettings?.baseUrl ?? '');
    final token = useTextEditingController();
    final search = useTextEditingController();
    final folder = useTextEditingController(text: controller.folder);
    final nameError = useState<String?>(null);
    final saving = useState(false);
    final nameTouched = useState(existing != null);

    // Suggest the project name once, unless the user already typed one.
    useEffect(() {
      final suggested = controller.suggestedName;
      if (suggested != null && !nameTouched.value && name.text.isEmpty) {
        name.text = suggested;
      }
      return null;
    }, [controller.suggestedName]);

    // The trust dialog opens whenever the controller records an offer.
    useEffect(() {
      final offer = controller.pendingCertificate;
      if (offer == null) return null;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!context.mounted) return;
        final trusted = await showTrustCertificateDialog(context, offer);
        if (trusted) {
          await controller.trustCertificate();
        } else {
          controller.dismissCertificate();
        }
      });
      return null;
    }, [controller.pendingCertificate]);

    Future<void> save() async {
      final trimmed = name.text.trim();
      if (trimmed.isEmpty) {
        nameError.value = 'Give the vault a name.';
        return;
      }
      saving.value = true;
      try {
        final id = existing?.id ?? const Uuid().v4();
        final secrets = ref.read(vaultSecretsProvider);
        final newToken = controller.token;
        // Secret first: a crash between the two leaves an orphan secret,
        // never a vault without a token.
        if (newToken != null) {
          await secrets.write(id, GitLabSettings.secretName, newToken);
        }
        final settings = existing == null
            ? controller.toSettings()
            : existingSettings!.copyWith(certFingerprint: controller.certFingerprint);
        final vault = Vault(
          id: id,
          name: trimmed,
          location: VaultLocation.remote(
            kind: GitLabSettings.kind,
            settings: settings.toSettings(),
            secretNames: const [GitLabSettings.secretName],
          ),
          createdAt: existing?.createdAt ?? DateTime.now(),
        );
        final vaults = ref.read(vaultsProvider.notifier);
        if (existing == null) {
          await vaults.add(vault);
        } else {
          await vaults.updateVault(vault);
        }
        if (!context.mounted) return;
        final navigator = Navigator.of(context);
        if (navigator.canPop()) navigator.pop();
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save the vault: $e')),
        );
      } finally {
        if (context.mounted) saving.value = false;
      }
    }

    final isEdit = existing != null;
    final hint = theme.textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
    );

    return Material(
      type: MaterialType.transparency,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Server
          CheckboxListTile(
            key: const Key('gitlab-self-hosted'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Self-hosted instance'),
            value: controller.selfHosted,
            onChanged: isEdit ? null : (v) => controller.setSelfHosted(v ?? false),
          ),
          if (controller.selfHosted) ...[
            TextField(
              key: const Key('gitlab-url'),
              controller: url,
              enabled: !isEdit,
              decoration: const InputDecoration(
                labelText: 'Instance URL',
                hintText: 'https://gitlab.example.com',
                helperText: 'http:// is allowed for internal servers.',
              ),
              onChanged: controller.setBaseUrl,
            ),
            const SizedBox(height: 20),
          ],
          // 2. Token
          if (!isEdit) ...[
            _TokenField(controller: token, busy: controller.busy, onConnect: () => controller.connect(token.text.trim())),
            const _TokenHelp(),
            if (controller.connectError != null) _ErrorLine(controller.connectError!),
            if (controller.step.index >= ConnectStep.project.index)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Connected', style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.primary)),
              ),
            const SizedBox(height: 20),
          ],
          // 3. Project
          if (!isEdit && controller.step.index >= ConnectStep.project.index) ...[
            TextField(
              key: const Key('gitlab-search'),
              controller: search,
              decoration: const InputDecoration(
                labelText: 'Project',
                hintText: 'Type to search, or paste group/repo',
              ),
              onChanged: controller.search,
            ),
            for (final p in controller.projects)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(p.name),
                subtitle: Text(p.pathWithNamespace),
                selected: controller.project?.id == p.id,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onTap: () => controller.selectProject(p),
              ),
            const SizedBox(height: 20),
          ],
          // 4. Branch and folder
          if (controller.step == ConnectStep.target) ...[
            if (isEdit) ...[
              Text('Location', style: theme.textTheme.labelLarge),
              Text(existingSettings!.locationLine, style: theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace')),
              Text('To use a different repository or folder, create a new vault.', style: hint),
            ] else ...[
              DropdownButtonFormField<String>(
                key: const Key('gitlab-branch'),
                initialValue: controller.branch,
                decoration: const InputDecoration(labelText: 'Branch'),
                items: [for (final b in controller.branches) DropdownMenuItem(value: b, child: Text(b))],
                onChanged: (b) => b == null ? null : controller.selectBranch(b),
              ),
              const SizedBox(height: 20),
              TextField(
                key: const Key('gitlab-folder'),
                controller: folder,
                decoration: const InputDecoration(
                  labelText: 'Folder',
                  helperText: 'Empty means the repository root.',
                ),
                onSubmitted: controller.setFolder,
                onTapOutside: (_) => controller.setFolder(folder.text),
              ),
              if (controller.folderCheck != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(controller.folderCheck!.describe(), style: hint),
                ),
            ],
            const SizedBox(height: 20),
            // 5. Name
            TextField(
              key: const Key('gitlab-name'),
              controller: name,
              decoration: InputDecoration(labelText: 'Name', errorText: nameError.value),
              onChanged: (_) {
                nameTouched.value = true;
                nameError.value = null;
              },
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: saving.value || (!isEdit && !controller.canSave) ? null : save,
                child: Text(isEdit ? 'Save' : 'Create vault'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TokenField extends StatelessWidget {
  final TextEditingController controller;
  final bool busy;
  final VoidCallback onConnect;

  const _TokenField({required this.controller, required this.busy, required this.onConnect});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            key: const Key('gitlab-token'),
            controller: controller,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(labelText: 'Personal access token'),
            onSubmitted: (_) => onConnect(),
          ),
        ),
        const SizedBox(width: 12),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: ElevatedButton(
            onPressed: busy ? null : onConnect,
            child: const Text('Connect'),
          ),
        ),
      ],
    );
  }
}

class _TokenHelp extends StatelessWidget {
  const _TokenHelp();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text('How to create a token', style: Theme.of(context).textTheme.bodyMedium),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Fine-grained token (recommended)', style: style?.copyWith(fontWeight: FontWeight.bold)),
              Text(
                'User settings → Access → Personal access tokens → Generate token → '
                'Fine-grained. Under "Group and project access" pick the vault '
                'repository, then grant Project: Read, Branch: Read, Repository: Read '
                'and Commit: Create. Under the User tab grant Project: Read. '
                'Available on every tier from GitLab 19.2.',
                style: style,
              ),
              const SizedBox(height: 8),
              Text('Legacy token', style: style?.copyWith(fontWeight: FontWeight.bold)),
              Text(
                'Scope "api". Needed on instances older than GitLab 18.10. Admins can '
                'block legacy tokens after a date they set; GitLab then answers with '
                'the fine-grained permissions to use instead.',
                style: style,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ErrorLine extends StatelessWidget {
  final String message;

  const _ErrorLine(this.message);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(message, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
    );
  }
}

/// Asks whether to trust [offer]. Returns true when the user chose Trust.
Future<bool> showTrustCertificateDialog(BuildContext context, CertificateRejected offer) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Trust this certificate?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${offer.host} presented a certificate your system does not trust.'),
          const SizedBox(height: 12),
          Text('Subject: ${offer.subject}'),
          const SizedBox(height: 4),
          SelectableText('SHA-256: ${offer.fingerprint}', style: const TextStyle(fontFamily: 'monospace')),
          const SizedBox(height: 12),
          const Text('Only this exact certificate will be accepted. Compare the fingerprint with your server before trusting it.'),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Trust')),
      ],
    ),
  );
  return result ?? false;
}
```

- [ ] **Step 5: Run the widget tests**

Run: `flutter analyze && flutter test test/gitlab_vault_form_test.dart test/vault_form_view_test.dart`
Expected: PASS. If the search debounce keeps `pumpAndSettle` waiting, the tests above never type into the search field, so no timer is pending; if `useListenable` does not rebuild on `notifyListeners`, check the hook import (`flutter_hooks`).

- [ ] **Step 6: Commit**

```bash
git add lib/src/views/gitlab_vault_form.dart lib/src/views/vault_kinds.dart test/gitlab_vault_form_test.dart test/vault_form_view_test.dart
git commit -m "feat: add the GitLab vault kind and its connect form"
```

---

### Task 11: Edit form: replace token, trust again

**Files:**
- Modify: `lib/src/views/gitlab_vault_form.dart` (edit-only section)
- Modify: `lib/src/providers/gitlab_connect_controller.dart` (add `Future<void> fetchCurrentCertificate()`)
- Test: extend `test/gitlab_vault_form_test.dart`, `test/gitlab_connect_controller_test.dart`

**Interfaces:**
- Produces on the controller: `Future<void> fetchCurrentCertificate()` — clears `certFingerprint`, calls `searchProjects('')` with the stored token candidate `_pendingToken ?? ''` only to trigger the handshake, and lets `_run` record `pendingCertificate`. Since the edit form has no token in memory, the widget passes the token it reads from secrets: signature is `Future<void> fetchCurrentCertificate(String token)`.

- [ ] **Step 1: Write the failing tests**

Add to `test/gitlab_vault_form_test.dart`:

```dart
  Vault gitLabVault({String? fingerprint}) => Vault(
    id: 'g',
    name: 'Budget',
    location: VaultLocation.remote(
      kind: 'gitlab',
      settings: {
        'base_url': FakeGitLab.baseUrl,
        'project_id': 42,
        'project_path': 'group/repo',
        'branch': 'main',
        'folder': 'budget',
        if (fingerprint != null) 'cert_fingerprint': fingerprint,
      },
      secretNames: const ['token'],
    ),
    createdAt: created,
  );

  testWidgets('the edit form shows the location read-only and a token replacement', (tester) async {
    await secrets.write('g', 'token', 'old');
    await tester.pumpWidget(app(GitLabVaultForm(existing: gitLabVault())));
    await tester.pumpAndSettle();

    expect(find.text('gitlab.test · group/repo/budget'), findsOneWidget);
    expect(find.byKey(const Key('gitlab-branch')), findsNothing);
    expect(find.text('Token stored'), findsOneWidget);
    expect(find.text('Replace token'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('replacing the token verifies it and saves the new secret', (tester) async {
    await secrets.write('g', 'token', 'old');
    await tester.pumpWidget(app(GitLabVaultForm(existing: gitLabVault())));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Replace token'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('gitlab-token')), gitlab.validToken);
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();
    expect(find.text('Connected'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(fakeVaults.updated.single.name, 'Budget');
    expect(await secrets.read('g', 'token'), gitlab.validToken);
  });

  testWidgets('a missing secret makes the token field required', (tester) async {
    await tester.pumpWidget(app(GitLabVaultForm(existing: gitLabVault())));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('gitlab-token')), findsOneWidget);
    expect(find.text('Token stored'), findsNothing);
  });

  testWidgets('a self-hosted vault shows the trusted fingerprint and can trust again', (tester) async {
    await secrets.write('g', 'token', gitlab.validToken);
    await tester.pumpWidget(app(GitLabVaultForm(existing: gitLabVault(fingerprint: 'AA:BB'))));
    await tester.pumpAndSettle();

    expect(find.textContaining('AA:BB'), findsOneWidget);
    expect(find.text('Trust again'), findsOneWidget);
  });
```

The form reads the secret in a `useEffect` on mount, which is why the tests seed `secrets` before pumping; the "missing secret" test seeds nothing.

Add to `test/gitlab_connect_controller_test.dart`:

```dart
  test('fetchCurrentCertificate records the offer without changing the pin until trusted', () async {
    final existing = GitLabSettings(baseUrl: FakeGitLab.baseUrl, projectId: 42, projectPath: 'group/repo', branch: 'main', certFingerprint: 'OLD');
    final offer = CertificateRejected(host: 'gitlab.test', subject: 'CN=x', fingerprint: 'NEW');
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      if (calls == 1) throw const HandshakeException('changed');
      return gitlab.client.send(request).then(http.Response.fromStream);
    });
    controller = make(client: client, offer: offer, existing: existing);

    await controller.fetchCurrentCertificate(gitlab.validToken);
    expect(controller.pendingCertificate, same(offer));
    expect(controller.certFingerprint, 'OLD');

    await controller.trustCertificate();
    expect(controller.certFingerprint, 'NEW');
    expect(controller.token, gitlab.validToken);
  });
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/gitlab_vault_form_test.dart test/gitlab_connect_controller_test.dart`
Expected: FAIL on the new tests only.

- [ ] **Step 3: Add `fetchCurrentCertificate` to the controller**

```dart
  /// Edit form: reaches the server with the stored token so a changed
  /// certificate is offered again. The pin changes only on
  /// [trustCertificate].
  Future<void> fetchCurrentCertificate(String storedToken) {
    _pendingToken = storedToken;
    return _run(() async {
      final api = apiFactory(settings: _probeSettings(), token: storedToken);
      await api.searchProjects('');
      _api = api;
      token = storedToken;
    });
  }
```

`trustCertificate` already calls `verifyReplacementToken(candidate)` when `step == ConnectStep.target`, which re-verifies with the new pin and sets `token`.

- [ ] **Step 4: Add the edit-only section to the form**

In `GitLabVaultForm.build`, add state and a mount effect:

```dart
    final storedToken = useState<String?>(null);
    final tokenLoaded = useState(false);
    final replacing = useState(false);
    useEffect(() {
      if (existing == null) return null;
      ref.read(vaultSecretsProvider).read(existing!.id, GitLabSettings.secretName).then((value) {
        if (!context.mounted) return;
        storedToken.value = value;
        tokenLoaded.value = true;
      });
      return null;
    }, [existing?.id]);
```

Replace the `if (!isEdit) ...[ token step ]` block with one that handles both:

```dart
          if (!isEdit || replacing.value || (tokenLoaded.value && storedToken.value == null)) ...[
            _TokenField(
              controller: token,
              busy: controller.busy,
              onConnect: () => isEdit
                  ? controller.verifyReplacementToken(token.text.trim())
                  : controller.connect(token.text.trim()),
            ),
            const _TokenHelp(),
            if (controller.connectError != null) _ErrorLine(controller.connectError!),
            if (controller.token != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Connected', style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.primary)),
              ),
            const SizedBox(height: 20),
          ] else if (isEdit && tokenLoaded.value) ...[
            Row(
              children: [
                Expanded(child: Text('Token stored', style: theme.textTheme.bodyMedium)),
                TextButton(onPressed: () => replacing.value = true, child: const Text('Replace token')),
              ],
            ),
            const SizedBox(height: 20),
          ],
```

In the edit branch of step 4, after the location lines, add the certificate row for self-hosted vaults:

```dart
              if (existingSettings.certFingerprint != null || controller.certFingerprint != null) ...[
                const SizedBox(height: 12),
                Text('Trusted certificate', style: theme.textTheme.labelLarge),
                Text(controller.certFingerprint ?? existingSettings.certFingerprint!, style: const TextStyle(fontFamily: 'monospace')),
                TextButton(
                  onPressed: storedToken.value == null
                      ? null
                      : () => controller.fetchCurrentCertificate(storedToken.value!),
                  child: const Text('Trust again'),
                ),
              ],
```

`save()` already writes `controller.token` when set and keeps the existing settings with an updated fingerprint, so a replaced token or a re-trusted certificate is saved with no further change. The "Connected" check in the create path (`controller.step.index >= ConnectStep.project.index`) is replaced by `controller.token != null` above, which holds in both flows.

- [ ] **Step 5: Run the tests**

Run: `flutter analyze && flutter test test/gitlab_vault_form_test.dart test/gitlab_connect_controller_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/src/views/gitlab_vault_form.dart lib/src/providers/gitlab_connect_controller.dart test/gitlab_vault_form_test.dart test/gitlab_connect_controller_test.dart
git commit -m "feat: replace the token and re-trust the certificate of a GitLab vault"
```

---

### Task 12: Documentation

**Files:**
- Modify: `AGENTS.md`, `doc/05_implementation_plan.md`, `doc/01_storage_models.md`, `doc/02_architecture.md`, `doc/06_ai_context.md`, `README.md`, `PRIVACY.md`

- [ ] **Step 1: `AGENTS.md`**

In "Important Technical Decisions" item 3, replace "no real remote provider is registered yet" with: "`gitlab` is the first registered provider (`lib/src/sync/gitlab/`): one atomic commit per push, git blob ids as versions, a personal access token in the platform keychain (`SecureVaultSecrets` over `flutter_secure_storage`), and one pinned certificate per self-hosted vault. A `Lock` shared by the app-facing `DirectoryWorkspace` and the `SyncEngine` keeps a local write from landing while the engine resolves that file. Design: `docs/superpowers/specs/2026-09-16-gitlab-vault-provider-design.md`."

In "Key Architecture":
- `lib/src/storage/` line: add `SecureVaultSecrets`.
- `lib/src/sync/` line: add `Lock`, and a new sub-bullet: `lib/src/sync/gitlab/` — `GitLabSettings`, `GitLabApi` (+ `gitlab_http.dart` pinned client), `gitBlobSha`, `GitLabRemoteStore`, `gitlab_provider.dart` registration.
- `lib/src/providers/` line: add `gitLabApiFactoryProvider` and `GitLabConnectController`.
- `lib/src/views/` line: add `GitLabVaultForm`.

In "Current Progress": add "Phase 7.1 (GitLab provider) is COMPLETED."

- [ ] **Step 2: `doc/05_implementation_plan.md`**

Replace the Phase 7 candidates list with:

```markdown
## Phase 7: Remote providers and mobile

### 7.1 GitLab vault provider (completed)
The first remote provider: a folder in a GitLab repository, on gitlab.com or self-hosted, through the REST API with a personal access token (fine-grained or legacy). Brought the keychain-backed secrets and the pull/write lock with it. Designed and executed from `docs/superpowers/specs/2026-09-16-gitlab-vault-provider-design.md` and its plan.

### Candidates (not started)
1. **WebDAV provider**: the first non-atomic store, exercising per-file writes and partial-failure recovery.
2. **GitHub provider**: a near copy of GitLab over the contents and git data APIs.
3. **Android target and responsive shell**: the 220 px sidebar becomes a drawer or bottom navigation on narrow widths.
4. **Per-file conflict chooser** ("keep mine / take theirs") on top of the newest-wins policy.
5. **Android user-picked folders** through the Storage Access Framework.
6. **OAuth sign-in for gitlab.com**, where one registered application serves everyone.
```

- [ ] **Step 3: `doc/01_storage_models.md`, `doc/02_architecture.md`, `doc/06_ai_context.md`**

`01`, Overview sentence: change "or, on the roadmap, a remote location such as a GitLab repository, a WebDAV server or an S3 bucket" to "or a remote location: a folder in a GitLab repository today, with WebDAV and S3 on the roadmap".

`02`, line 40: after "A remote vault is mirrored locally and synced by the engine in `lib/src/sync/`." add "The GitLab provider (`lib/src/sync/gitlab/`) pushes every batch as one commit and uses git blob ids as file versions."

`06`, Next Steps: replace "the first remote provider (WebDAV or GitLab)" with "further remote providers (WebDAV, GitHub)".

- [ ] **Step 4: `README.md` and `PRIVACY.md`**

README "Sync Freedom": "Keep it local and sync with **Git**, **Syncthing** or **Dropbox** as you do today, or point FlatPlan straight at your private storage. GitLab vaults work now (gitlab.com or your own instance); WebDAV and others are on the roadmap."

`PRIVACY.md`: add a section:

```markdown
## Remote vaults

A GitLab vault sends your period files to the GitLab server you configured and nowhere else. The access token you enter is stored in your operating system's keychain or keystore, never in a plain file, and is sent only to that server. FlatPlan makes no request to any server until you create a remote vault.
```

- [ ] **Step 5: Commit**

```bash
git add AGENTS.md doc README.md PRIVACY.md
git commit -m "docs: describe the GitLab vault provider"
```

---

### Task 13: Show the sync error text

The spec (section 6) wants the 401, 403, certificate and refused-push messages visible in the switcher status and the vault list. Both already render `SyncStatus.describe()`, which says only "Sync failed"; make it carry the message.

**Files:**
- Modify: `lib/src/sync/sync_status.dart:25-27`
- Test: `test/sync/sync_status_test.dart:28-32`

- [ ] **Step 1: Change the expectation**

In `test/sync/sync_status_test.dart` replace the error assertion with:

```dart
    expect(
      const SyncStatus(state: SyncState.error, dirtyCount: 0, lastError: 'GitLab rejected the token.')
          .describe(now),
      'Sync failed: GitLab rejected the token.',
    );
    expect(
      const SyncStatus(state: SyncState.error, dirtyCount: 0).describe(now),
      'Sync failed',
    );
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/sync/sync_status_test.dart`
Expected: FAIL on the first new assertion.

- [ ] **Step 3: Implement**

In `SyncStatus.describe`:

```dart
      case SyncState.error:
        final error = lastError;
        return error == null || error.isEmpty ? 'Sync failed' : 'Sync failed: $error';
```

- [ ] **Step 4: Run the suite**

Run: `flutter analyze && flutter test`
Expected: PASS. The switcher's status `Text` already uses `overflow: TextOverflow.ellipsis` in `lib/src/components/vault_switcher.dart`; if it does not, add `maxLines: 2, overflow: TextOverflow.ellipsis` there.

- [ ] **Step 5: Commit**

```bash
git add lib/src/sync/sync_status.dart test/sync/sync_status_test.dart lib/src/components/vault_switcher.dart
git commit -m "feat: show the sync error message in the vault status line"
```
