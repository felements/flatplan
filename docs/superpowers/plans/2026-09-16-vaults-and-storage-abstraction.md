# Vaults and Storage Abstraction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the user keep several named vaults of period files, switch between them Obsidian-style, and make the storage layer ready for remote providers through a local mirror plus a sync engine.

**Architecture:** Domain storage code (`PeriodRepository`, `PeriodStatsWriter`) writes through a small `VaultWorkspace` interface backed by a local folder. A `Vault` registry (`vaults.json`) names each folder. For remote vaults the folder is an app-private mirror; a `SyncEngine` with a persisted `SyncJournal` moves files to and from a version-aware `RemoteStore`, resolving conflicts newest-wins with a side file. No real remote provider ships here, only the in-memory test store.

**Tech Stack:** Flutter 3.47 / Dart 3.11, Riverpod 3 with `riverpod_generator`, `freezed` 3 + `json_serializable` (snake_case via `build.yaml`), `go_router`, `path_provider`, `shared_preferences`, `file_picker`, `crypto` (content hashes), `yaml`, `intl`. Generated `*.g.dart` / `*.freezed.dart` files are committed.

**Spec:** `docs/superpowers/specs/2026-09-16-vaults-and-storage-abstraction-design.md`

## Global Constraints

- Every dependency in the core path must work on Android. No desktop-only plugin outside `VaultResolver` and the local-folder form.
- Serialisation is `snake_case` for every model (`build.yaml` sets `field_rename: snake`, `explicit_to_json: true`).
- Registry file: `<application support>/vaults.json`, schema `{ version: 1, last_selected_vault_id, vaults: [...] }`, written atomically (temp file then rename).
- Per-vault private area: `<application support>/vaults/<vaultId>/` holding `files/` and `sync.json`.
- Existing default periods folder `<application support>/periods` must keep working untouched after migration.
- Conflict side file name: `<stem>.conflict-<yyyy-MM-dd-HHmm><ext>`; the repository skips any file name containing `.conflict-`.
- Sync triggers: pull on open; push 15 s after the last dirty mark; push on `AppLifecycleState.paused`; push on "Sync now"; push with 5 s timeout before switching vaults. At most three conflict rounds per push.
- Removing a vault never deletes user files. It deletes only the vault's private area and its secrets.
- Removing the last vault is not allowed.
- Copy: access errors use these exact strings:
  - unknown remote kind: `This vault type is not supported in this version.`
  - missing secret: `Sign in to this vault again in its settings.`
  - missing user-picked folder: `The folder "<path>" could not be found. Choose it again in the vault settings.`
- Design guidelines in `doc/08_design_guidelines.md`: cards 16 px radius, buttons and inputs 12 px, sidebar item styling reused from `AppShell`.
- Commands: `flutter test`, `flutter analyze`, `dart run build_runner build --delete-conflicting-outputs`. All three must be clean before each commit that touches generated code.
- Commit messages end with `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.

**Deviations from the spec, decided while planning** (spec updated in Task 16):
- `flutter_secure_storage` is not added yet. `VaultSecrets` is an interface with an in-memory implementation; the keychain implementation ships with the first remote provider, which is the first code that stores a secret. Adding the plugin now would only add platform setup risk with no caller.
- Sync status is tracked for the open vault only. Other vaults show no status in the manage list.
- When the selected vault cannot be opened, the dashboard shows a dedicated "vault unavailable" view with a button to the vault's settings, rather than the generic empty state.
- `periodRepositoryProvider` becomes a `Future` provider so that nothing runs against a placeholder folder while the vault resolves.

---

## File structure

New files and their single responsibility:

| File | Responsibility |
|---|---|
| `lib/src/storage/vault_workspace.dart` | `VaultWorkspace` interface, `WorkspaceChangeListener`, `DirectoryWorkspace`, `MemoryWorkspace` |
| `lib/src/models/vault.dart` | `Vault`, `VaultLocation` (freezed) |
| `lib/src/models/vault_registry.dart` | `VaultRegistry` (freezed) with `selected` |
| `lib/src/storage/app_paths.dart` | `AppPaths`: the handful of app-support paths, computed once |
| `lib/src/storage/vault_registry_service.dart` | read/write `vaults.json`, corrupt-file handling, migration from shared_preferences |
| `lib/src/storage/vault_secrets.dart` | `VaultSecrets` interface, `MemoryVaultSecrets` |
| `lib/src/sync/remote_store.dart` | `RemoteStore`, `RemoteFile`, `RemoteChange`, `RemoteConflict`, `RemoteStoreRegistry` |
| `lib/src/sync/sync_journal.dart` | `SyncJournal`, `JournalEntry`, `contentHash` |
| `lib/src/sync/conflict_policy.dart` | `ConflictPolicy`, `periodConflictPolicy`, `conflictFileName` |
| `lib/src/sync/sync_engine.dart` | pull, push, recovery, `SyncFailure` |
| `lib/src/sync/sync_status.dart` | `SyncState`, `SyncStatus` |
| `lib/src/sync/sync_scheduler.dart` | timers, single-flight, status reporting |
| `lib/src/storage/vault_resolver.dart` | `OpenVault`, `VaultResolver` |
| `lib/src/providers/app_paths_provider.dart` | `appPathsProvider` |
| `lib/src/providers/vaults_provider.dart` | `vaultRegistryServiceProvider`, `vaultSecretsProvider`, `Vaults` notifier, `selectedVaultProvider` |
| `lib/src/providers/open_vault_provider.dart` | `vaultResolverProvider`, `openVaultProvider`, `SyncStatusNotifier` |
| `lib/src/components/vault_switcher.dart` | sidebar footer switcher |
| `lib/src/components/vault_access_banner.dart` | the access-error banner used by Settings and the dashboard |
| `lib/src/views/vault_kinds.dart` | `VaultKindDescriptor` list |
| `lib/src/views/vault_list_view.dart` | `/settings/vaults` |
| `lib/src/views/vault_form_view.dart` | `/settings/vaults/new`, `/settings/vaults/:id/edit`, `LocalVaultForm` |
| `lib/src/components/sync_lifecycle_bridge.dart` | pushes on app pause |
| `test/storage/workspace_contract.dart` | shared contract suite |
| `test/sync/in_memory_remote_store.dart` | test double for `RemoteStore` |

Removed: `lib/src/storage/storage_settings_service.dart`, `lib/src/providers/storage_settings_provider.dart` (+ `.g.dart`), `test/storage_settings_service_test.dart`.

---

### Task 1: `VaultWorkspace` with directory and memory implementations

**Files:**
- Create: `lib/src/storage/vault_workspace.dart`
- Create: `test/storage/workspace_contract.dart`
- Create: `test/storage/vault_workspace_test.dart`

**Interfaces:**
- Produces:
  - `abstract interface class WorkspaceChangeListener { Future<void> onChanged(String name); }`
  - `abstract interface class VaultWorkspace { String get displayPath; Future<List<String>> listFiles(); Future<bool> exists(String name); Future<String> readString(String name); Future<void> writeString(String name, String content); Future<void> delete(String name); }`
  - `class DirectoryWorkspace implements VaultWorkspace { DirectoryWorkspace(String path, {WorkspaceChangeListener? changeListener}); final String path; }`
  - `class MemoryWorkspace implements VaultWorkspace { MemoryWorkspace({Map<String, String>? files, WorkspaceChangeListener? changeListener}); final Map<String, String> files; }`
  - `void runWorkspaceContract(String label, Future<VaultWorkspace> Function() create)` (test helper)

- [ ] **Step 1: Write the contract suite and the failing tests**

`test/storage/workspace_contract.dart`:

```dart
import 'package:flatplan/src/storage/vault_workspace.dart';
import 'package:flutter_test/flutter_test.dart';

/// Behaviour every [VaultWorkspace] implementation must share.
void runWorkspaceContract(
  String label,
  Future<VaultWorkspace> Function() create,
) {
  group('$label contract', () {
    late VaultWorkspace ws;

    setUp(() async {
      ws = await create();
    });

    test('lists nothing when empty', () async {
      expect(await ws.listFiles(), isEmpty);
    });

    test('write then read round-trips and lists the name', () async {
      await ws.writeString('a.yaml', 'x: 1');

      expect(await ws.readString('a.yaml'), 'x: 1');
      expect(await ws.listFiles(), ['a.yaml']);
      expect(await ws.exists('a.yaml'), isTrue);
    });

    test('listFiles is sorted by name', () async {
      await ws.writeString('b.yaml', '');
      await ws.writeString('a.yaml', '');

      expect(await ws.listFiles(), ['a.yaml', 'b.yaml']);
    });

    test('overwrite replaces content', () async {
      await ws.writeString('a.yaml', 'one');
      await ws.writeString('a.yaml', 'two');

      expect(await ws.readString('a.yaml'), 'two');
      expect(await ws.listFiles(), ['a.yaml']);
    });

    test('delete removes the file and is a no-op for a missing one', () async {
      await ws.writeString('a.yaml', 'x');
      await ws.delete('a.yaml');
      await ws.delete('a.yaml');

      expect(await ws.exists('a.yaml'), isFalse);
      expect(await ws.listFiles(), isEmpty);
    });

    test('exists is false for a missing file', () async {
      expect(await ws.exists('nope.yaml'), isFalse);
    });

    test('readString of a missing file throws', () async {
      expect(() => ws.readString('nope.yaml'), throwsA(anything));
    });
  });
}
```

`test/storage/vault_workspace_test.dart`:

```dart
import 'dart:io';

import 'package:flatplan/src/storage/vault_workspace.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'workspace_contract.dart';

/// Records each notification and whether the file existed at that moment,
/// which proves the mark happens before the write lands.
class _RecordingListener implements WorkspaceChangeListener {
  _RecordingListener(this.dir);
  final String dir;
  final List<String> names = [];
  final List<bool> existedAtNotify = [];

  @override
  Future<void> onChanged(String name) async {
    names.add(name);
    existedAtNotify.add(File(p.join(dir, name)).existsSync());
  }
}

void main() {
  runWorkspaceContract('MemoryWorkspace', () async => MemoryWorkspace());

  group('DirectoryWorkspace', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('flatplan_ws_');
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    runWorkspaceContract(
      'DirectoryWorkspace',
      () async => DirectoryWorkspace(p.join(tempDir.path, 'files')),
    );

    test('creates the folder on first write', () async {
      final dir = p.join(tempDir.path, 'fresh');
      final ws = DirectoryWorkspace(dir);
      expect(Directory(dir).existsSync(), isFalse);

      await ws.writeString('a.yaml', 'x');

      expect(File(p.join(dir, 'a.yaml')).readAsStringSync(), 'x');
    });

    test('lists only regular files, not subfolders', () async {
      final ws = DirectoryWorkspace(tempDir.path);
      Directory(p.join(tempDir.path, 'sub')).createSync();
      await ws.writeString('a.yaml', 'x');

      expect(await ws.listFiles(), ['a.yaml']);
    });

    test('displayPath is the folder path', () {
      expect(DirectoryWorkspace('/tmp/x').displayPath, '/tmp/x');
    });

    test('notifies the listener before a write lands and on delete', () async {
      final listener = _RecordingListener(tempDir.path);
      final ws = DirectoryWorkspace(tempDir.path, changeListener: listener);

      await ws.writeString('a.yaml', 'x');
      expect(listener.names, ['a.yaml']);
      expect(listener.existedAtNotify, [false]);

      await ws.delete('a.yaml');
      expect(listener.names, ['a.yaml', 'a.yaml']);
    });

    test('does not notify when deleting a missing file', () async {
      final listener = _RecordingListener(tempDir.path);
      final ws = DirectoryWorkspace(tempDir.path, changeListener: listener);

      await ws.delete('missing.yaml');

      expect(listener.names, isEmpty);
    });
  });

  group('MemoryWorkspace', () {
    test('notifies the listener on write and delete', () async {
      final calls = <String>[];
      final ws = MemoryWorkspace(changeListener: _CallbackListener(calls.add));

      await ws.writeString('a.yaml', 'x');
      await ws.delete('a.yaml');
      await ws.delete('a.yaml');

      expect(calls, ['a.yaml', 'a.yaml']);
    });
  });
}

class _CallbackListener implements WorkspaceChangeListener {
  _CallbackListener(this.callback);
  final void Function(String) callback;

  @override
  Future<void> onChanged(String name) async => callback(name);
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/storage/vault_workspace_test.dart`
Expected: compile error, `vault_workspace.dart` does not exist.

- [ ] **Step 3: Implement the workspace file**

`lib/src/storage/vault_workspace.dart`:

```dart
import 'dart:io';

import 'package:path/path.dart' as p;

/// Told about every write and delete in a workspace, before it happens.
///
/// The sync journal implements this to mark a file dirty, so a crash a
/// millisecond after the write still leaves the change scheduled.
abstract interface class WorkspaceChangeListener {
  Future<void> onChanged(String name);
}

/// The only surface domain storage code uses to touch a vault's files.
///
/// Flat: names are plain file names, there are no subfolders.
abstract interface class VaultWorkspace {
  /// Human-readable location for the UI and error messages.
  String get displayPath;

  /// Names of regular files, sorted. Empty when nothing exists yet.
  Future<List<String>> listFiles();

  Future<bool> exists(String name);

  /// Throws when [name] does not exist.
  Future<String> readString(String name);

  /// Creates the folder when needed.
  Future<void> writeString(String name, String content);

  /// A no-op when [name] does not exist.
  Future<void> delete(String name);
}

/// A workspace over a real folder. Used both for the user's own folder and
/// for the app-private mirror of a remote vault; the [changeListener] is
/// the only difference between the two.
class DirectoryWorkspace implements VaultWorkspace {
  final String path;
  final WorkspaceChangeListener? changeListener;

  DirectoryWorkspace(this.path, {this.changeListener});

  @override
  String get displayPath => path;

  File _file(String name) => File(p.join(path, name));

  @override
  Future<List<String>> listFiles() async {
    final dir = Directory(path);
    if (!await dir.exists()) return const [];
    final names = <String>[];
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is File) names.add(p.basename(entity.path));
    }
    names.sort();
    return names;
  }

  @override
  Future<bool> exists(String name) => _file(name).exists();

  @override
  Future<String> readString(String name) => _file(name).readAsString();

  @override
  Future<void> writeString(String name, String content) async {
    await changeListener?.onChanged(name);
    final dir = Directory(path);
    if (!await dir.exists()) await dir.create(recursive: true);
    await _file(name).writeAsString(content, flush: true);
  }

  @override
  Future<void> delete(String name) async {
    final file = _file(name);
    if (!await file.exists()) return;
    await changeListener?.onChanged(name);
    await file.delete();
  }
}

/// An in-memory workspace for tests.
class MemoryWorkspace implements VaultWorkspace {
  /// Pass a shared [files] map to give two instances one view of the same
  /// data, e.g. an unlistened mirror and a journal-listened app workspace.
  final Map<String, String> files;
  final WorkspaceChangeListener? changeListener;

  MemoryWorkspace({Map<String, String>? files, this.changeListener})
    : files = files ?? {};

  @override
  String get displayPath => 'in-memory';

  @override
  Future<List<String>> listFiles() async => files.keys.toList()..sort();

  @override
  Future<bool> exists(String name) async => files.containsKey(name);

  @override
  Future<String> readString(String name) async {
    final content = files[name];
    if (content == null) {
      throw FileSystemException('File not found', name);
    }
    return content;
  }

  @override
  Future<void> writeString(String name, String content) async {
    await changeListener?.onChanged(name);
    files[name] = content;
  }

  @override
  Future<void> delete(String name) async {
    if (!files.containsKey(name)) return;
    await changeListener?.onChanged(name);
    files.remove(name);
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/storage/vault_workspace_test.dart && flutter analyze`
Expected: all pass, no analyzer issues.

- [ ] **Step 5: Commit**

```bash
git add lib/src/storage/vault_workspace.dart test/storage/
git commit -m "feat: add VaultWorkspace with directory and memory implementations

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 2: Period repository and stats writer over `VaultWorkspace`

**Files:**
- Modify: `lib/src/storage/period_repository.dart`
- Modify: `lib/src/storage/period_stats_writer.dart`
- Modify: `lib/src/providers/repository_provider.dart`
- Modify: `lib/src/providers/current_period_stats_sync_provider.dart:26-27`
- Modify: `lib/src/components/period_load_warning.dart` (no code change needed, `path` is not read; verify)
- Modify tests: `test/storage_test.dart`, `test/period_load_warning_test.dart`, `test/all_periods_provider_test.dart`, `test/current_period_stats_sync_provider_test.dart`, `test/period_refresh_test.dart`, `test/period_stats_provider_test.dart`, `test/dashboard_historical_pace_test.dart`, `test/category_detail_pace_test.dart`, `test/category_dialog_threshold_test.dart`

**Interfaces:**
- Consumes: `VaultWorkspace`, `DirectoryWorkspace`, `MemoryWorkspace` from Task 1.
- Produces:
  - `PeriodRepository({required VaultWorkspace workspace})`, field `workspace`
  - `PeriodLoadFailure({required String fileName, required String location, required String message})` (`path` renamed to `location`)
  - `PeriodStatsWriter({required VaultWorkspace workspace})`
  - Repository skips names containing `.conflict-`.

- [ ] **Step 1: Rewrite `test/storage_test.dart` against `MemoryWorkspace` and add the two new cases**

Replace the whole file:

```dart
import 'package:flatplan/src/models/models.dart';
import 'package:flatplan/src/storage/period_repository.dart';
import 'package:flatplan/src/storage/vault_workspace.dart';
import 'package:flutter_test/flutter_test.dart';

Period _period({
  required String id,
  required String name,
  DateTime? startDate,
}) => Period(
  id: id,
  name: name,
  startDate: startDate ?? DateTime(2026, 3, 1),
  baseCurrency: 'EUR',
  lastModified: DateTime(2026, 3, 1),
);

void main() {
  group('PeriodRepository', () {
    late MemoryWorkspace ws;
    late PeriodRepository repo;

    setUp(() {
      ws = MemoryWorkspace();
      repo = PeriodRepository(workspace: ws);
    });

    test('generates human-readable filename for normal period', () async {
      await repo.savePeriod(
        _period(
          id: '1234-uuid',
          name: 'October 2025 Budget',
          startDate: DateTime(2025, 10, 1),
        ),
      );

      expect(await ws.listFiles(), ['2025-10-october_2025_budget.yaml']);
    });

    test('generates filename for template', () async {
      await repo.savePeriod(
        _period(
          id: '5678-uuid',
          name: 'My Custom Template',
          startDate: DateTime(2025, 1, 1),
        ),
      );

      expect(await ws.listFiles(), ['my_custom_template.yaml']);
    });

    test('filenameForPeriod returns the physical filename after save and load',
        () async {
      await repo.savePeriod(_period(id: 'abc-uuid', name: 'March 2026'));
      expect(repo.filenameForPeriod('abc-uuid'), '2026-03-march_2026.yaml');

      final freshRepo = PeriodRepository(workspace: ws);
      expect(freshRepo.filenameForPeriod('abc-uuid'), isNull);
      await freshRepo.loadAllPeriods();
      expect(
        freshRepo.filenameForPeriod('abc-uuid'),
        '2026-03-march_2026.yaml',
      );
    });

    test('handles empty or special character names gracefully', () async {
      await repo.savePeriod(
        _period(
          id: 'uuid-1111',
          name: '!!! --- ***',
          startDate: DateTime(2026, 3, 5),
        ),
      );

      expect(await ws.listFiles(), ['2026-03-uuid-1111.yaml']);
    });

    test('loadAll reports malformed YAML and still returns valid periods',
        () async {
      await repo.savePeriod(_period(id: 'good-uuid', name: 'March 2026'));
      await ws.writeString('broken.yaml', 'foo: [1, 2');

      final result = await PeriodRepository(workspace: ws).loadAll();

      expect(result.periods.map((p) => p.id), ['good-uuid']);
      expect(result.failures.length, 1);
      expect(result.failures.single.fileName, 'broken.yaml');
      expect(result.failures.single.location, 'in-memory/broken.yaml');
      expect(result.failures.single.message, contains('line 1'));
    });

    test('loadAll reports a document whose top level is not a mapping',
        () async {
      await ws.writeString('list.yaml', '- one\n- two\n');

      final result = await repo.loadAll();

      expect(result.periods, isEmpty);
      expect(result.failures.single.fileName, 'list.yaml');
      expect(result.failures.single.message, contains('not a mapping'));
    });

    test('loadAll reports a period with an invalid field', () async {
      await ws.writeString(
        'bad_field.yaml',
        'id: x\nname: y\nstart_date: not-a-date\n',
      );

      final result = await repo.loadAll();

      expect(result.periods, isEmpty);
      expect(result.failures.single.fileName, 'bad_field.yaml');
    });

    test('loadAll ignores files that are not yaml', () async {
      await ws.writeString('current_stats.md', '# stats');

      final result = await repo.loadAll();

      expect(result.periods, isEmpty);
      expect(result.failures, isEmpty);
    });

    test('loadAll skips conflict side files so ids stay unique', () async {
      await repo.savePeriod(_period(id: 'dup-uuid', name: 'March 2026'));
      final content = await ws.readString('2026-03-march_2026.yaml');
      await ws.writeString(
        '2026-03-march_2026.conflict-2026-09-16-1432.yaml',
        content,
      );

      final result = await PeriodRepository(workspace: ws).loadAll();

      expect(result.periods.map((p) => p.id), ['dup-uuid']);
      expect(result.failures, isEmpty);
    });

    test('savePeriod does not reuse the filename of a file that failed to load',
        () async {
      await ws.writeString('2026-03-march_2026.yaml', 'foo: [1, 2');
      await repo.loadAll();

      await repo.savePeriod(_period(id: 'new-uuid', name: 'March 2026'));

      expect(await ws.readString('2026-03-march_2026.yaml'), 'foo: [1, 2');
      expect(
        repo.filenameForPeriod('new-uuid'),
        isNot('2026-03-march_2026.yaml'),
      );
    });

    test('deletes legacy file when saving with new filename', () async {
      await ws.writeString('legacy-uuid.yaml', 'fake content');

      await repo.savePeriod(
        _period(id: 'legacy-uuid', name: 'March 2026 update'),
      );

      expect(await ws.listFiles(), ['2026-03-march_2026_update.yaml']);
    });
  });
}
```

- [ ] **Step 2: Update the other tests to build repositories from a workspace**

In `test/period_load_warning_test.dart` change the helper:

```dart
PeriodLoadFailure _failure(String fileName, String message) =>
    PeriodLoadFailure(
      fileName: fileName,
      location: '/periods/$fileName',
      message: message,
    );
```

In every test file listed below, apply these exact replacements. Keep the temp directory where the test also writes raw files (`all_periods_provider_test.dart`, `current_period_stats_sync_provider_test.dart`); drop it elsewhere.

| Old | New |
|---|---|
| `PeriodRepository(directoryPath: tempDir.path)` | `PeriodRepository(workspace: DirectoryWorkspace(tempDir.path))` |
| `import 'package:flatplan/src/storage/period_repository.dart';` | keep, and add `import 'package:flatplan/src/storage/vault_workspace.dart';` |

Files: `test/all_periods_provider_test.dart`, `test/current_period_stats_sync_provider_test.dart`, `test/period_refresh_test.dart`, `test/period_stats_provider_test.dart`, `test/dashboard_historical_pace_test.dart`, `test/category_detail_pace_test.dart`, `test/category_dialog_threshold_test.dart`.

For `test/period_stats_provider_test.dart`, `test/dashboard_historical_pace_test.dart`, `test/category_detail_pace_test.dart`, `test/category_dialog_threshold_test.dart` and `test/period_refresh_test.dart`, which never touch raw files, go further: replace the temp-dir setup with `PeriodRepository(workspace: MemoryWorkspace())`, delete the `tearDown` that removes the directory, and drop the `dart:io` import. Example for `period_refresh_test.dart`:

```dart
  setUp(() {
    repo = PeriodRepository(workspace: MemoryWorkspace());
    container = ProviderContainer(
      overrides: [periodRepositoryProvider.overrideWith((ref) => repo)],
    );
  });

  tearDown(() {
    container.dispose();
  });
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `flutter test test/storage_test.dart`
Expected: compile error, no named parameter `workspace`.

- [ ] **Step 4: Rewrite the repository and writer**

`lib/src/storage/period_repository.dart`, replace the class header, `loadAll`, and `savePeriod`; keep `_describeLoadError`, `_generateFilename`, `_firstUnreservedFilename`, `_cloneYamlNode`, `_sortKeysAlphabetically` unchanged. Remove the `dart:io` import and `_getStorageDirectory`.

```dart
import 'dart:collection';
import 'dart:developer' show log;

import 'package:json2yaml/json2yaml.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:yaml/yaml.dart';

import '../models/models.dart';
import 'vault_workspace.dart';

/// A period file that could not be read back into a [Period].
///
/// The file is left untouched so the user can repair it.
class PeriodLoadFailure {
  /// The file's name within the vault, e.g. `2026-03-march.yaml`.
  final String fileName;

  /// Where the file lives, as the user should see it:
  /// the vault's display path plus the file name.
  final String location;

  /// A human-readable reason the file could not be read, including the
  /// line and column when the YAML parser reported one.
  final String message;

  const PeriodLoadFailure({
    required this.fileName,
    required this.location,
    required this.message,
  });

  @override
  bool operator ==(Object other) =>
      other is PeriodLoadFailure &&
      other.fileName == fileName &&
      other.location == location &&
      other.message == message;

  @override
  int get hashCode => Object.hash(fileName, location, message);
}

/// The outcome of reading every period file in the vault:
/// the periods that loaded, plus the files that did not.
class PeriodLoadResult {
  final List<Period> periods;
  final List<PeriodLoadFailure> failures;

  const PeriodLoadResult({required this.periods, required this.failures});

  bool get hasFailures => failures.isNotEmpty;
}

/// Repository for YAML storage of tracking periods inside one vault.
class PeriodRepository {
  /// The vault's files. The repository never touches the filesystem directly.
  final VaultWorkspace workspace;

  /// Cache of period ID to its physical filename to preserve filenames on save.
  final Map<String, String> _idToFilename = {};

  /// Filenames that failed to load, reserved so [savePeriod] never overwrites
  /// a file the user may still be able to repair.
  final Set<String> _failedFilenames = {};

  PeriodRepository({required this.workspace});

  /// The physical YAML filename for [periodId], or null if the period has
  /// not been loaded or saved by this repository instance yet.
  String? filenameForPeriod(String periodId) => _idToFilename[periodId];

  /// Loads all periods, discarding any files that could not be read.
  /// Use [loadAll] to also learn which files failed.
  Future<List<Period>> loadAllPeriods() async => (await loadAll()).periods;

  /// True for a conflict side file written by the sync engine. Such a file
  /// holds a copy of a period and must not load as a duplicate id.
  static bool isConflictFile(String name) => name.contains('.conflict-');

  /// Loads all periods, reporting unreadable files as [PeriodLoadFailure]s
  /// rather than silently dropping them.
  Future<PeriodLoadResult> loadAll() async {
    final periods = <Period>[];
    final failures = <PeriodLoadFailure>[];
    _idToFilename.clear();
    _failedFilenames.clear();

    for (final fileName in await workspace.listFiles()) {
      if (!fileName.endsWith('.yaml') || isConflictFile(fileName)) continue;
      try {
        final content = await workspace.readString(fileName);
        if (content.trim().isEmpty) continue;

        final yamlDoc = loadYaml(content);
        if (yamlDoc is! YamlMap) {
          throw const FormatException('top level is not a mapping');
        }
        final map = _cloneYamlNode(yamlDoc) as Map<String, dynamic>;
        final period = Period.fromJson(map);
        _idToFilename[period.id] = fileName;
        periods.add(period);
      } catch (e) {
        final message = _describeLoadError(e);
        final location = '${workspace.displayPath}/$fileName';
        _failedFilenames.add(fileName);
        failures.add(
          PeriodLoadFailure(
            fileName: fileName,
            location: location,
            message: message,
          ),
        );
        log(
          'Failed to load period from $location: $message',
          name: 'flatplan.storage',
        );
      }
    }

    failures.sort((a, b) => a.fileName.compareTo(b.fileName));
    return PeriodLoadResult(periods: periods, failures: failures);
  }

  // _describeLoadError unchanged

  /// Saves a period to its YAML file.
  Future<void> savePeriod(Period period) async {
    // Keep existing filename if loaded, otherwise generate a new one
    final filename = _idToFilename[period.id] ?? _generateFilename(period);
    _idToFilename[period.id] = filename;

    // Remove legacy file if it exists to avoid duplicates
    final legacyName = '${period.id}.yaml';
    if (legacyName != filename && await workspace.exists(legacyName)) {
      await workspace.delete(legacyName);
    }

    final jsonMap = period.toJson();
    final sortedMap = _sortKeysAlphabetically(jsonMap);

    // json2yaml formatting generates clean YAML output.
    final yamlString = json2yaml(sortedMap, yamlStyle: YamlStyle.generic);
    await workspace.writeString(filename, yamlString);
  }

  // _generateFilename, _firstUnreservedFilename, _cloneYamlNode,
  // _sortKeysAlphabetically unchanged
}
```

`lib/src/storage/period_stats_writer.dart`, whole file:

```dart
import 'vault_workspace.dart';

/// Writes/removes the single current-period stats snapshot next to the
/// period YAML files, so it rides along with the vault.
class PeriodStatsWriter {
  static const fileName = 'current_stats.md';

  final VaultWorkspace workspace;

  PeriodStatsWriter({required this.workspace});

  Future<void> writeStatsFile(String markdown) =>
      workspace.writeString(fileName, markdown);

  Future<void> deleteStatsFile() async {
    if (await workspace.exists(fileName)) {
      await workspace.delete(fileName);
    }
  }
}
```

`lib/src/providers/repository_provider.dart` (interim, replaced again in Task 11):

```dart
import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../storage/period_repository.dart';
import '../storage/vault_workspace.dart';
import 'storage_settings_provider.dart';

part 'repository_provider.g.dart';

/// Provides a [PeriodRepository] wired to the user-selected data directory.
///
/// Re-creates automatically whenever [storageSettingsProvider] changes.
@riverpod
PeriodRepository periodRepository(Ref ref) {
  final dirAsync = ref.watch(storageSettingsProvider);
  final path = dirAsync.value?.path ?? _fallbackPath();
  return PeriodRepository(workspace: DirectoryWorkspace(path));
}

/// Temporary fallback while [storageSettingsProvider] resolves.
String _fallbackPath() {
  return '${Directory.systemTemp.path}/flatplan_fallback';
}
```

In `lib/src/providers/current_period_stats_sync_provider.dart` change line 27:

```dart
  final writer = PeriodStatsWriter(workspace: repo.workspace);
```

- [ ] **Step 5: Run the full suite and the analyzer**

Run: `flutter test && flutter analyze`
Expected: all pass. If `flutter analyze` reports an unused `dart:io` import in any test, remove it.

- [ ] **Step 6: Commit**

```bash
git add -A lib/src/storage lib/src/providers test
git commit -m "refactor: write periods and stats through VaultWorkspace

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 3: `Vault`, `VaultLocation`, `VaultRegistry` models

**Files:**
- Create: `lib/src/models/vault.dart`
- Create: `lib/src/models/vault_registry.dart`
- Modify: `lib/src/models/models.dart`
- Create: `test/vault_model_test.dart`

**Interfaces:**
- Produces:
  - `Vault({required String id, required String name, required VaultLocation location, required DateTime createdAt})`
  - `VaultLocation.local({required String path, String? bookmark})` as `LocalVaultLocation`
  - `VaultLocation.remote({required String kind, Map<String, dynamic> settings = const {}, List<String> secretNames = const []})` as `RemoteVaultLocation`
  - `VaultRegistry({int version = 1, String? lastSelectedVaultId, List<Vault> vaults = const [], String? brokenRegistryFile})` with `Vault? get selected` and `Vault? byId(String id)`
  - JSON: `location` serialises with a `type` discriminator, `local` or `remote`.

- [ ] **Step 1: Write the failing tests**

`test/vault_model_test.dart`:

```dart
import 'dart:convert';

import 'package:flatplan/src/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final created = DateTime.utc(2026, 9, 16, 10, 0);

  test('local vault serialises snake_case with a type discriminator', () {
    final vault = Vault(
      id: 'v1',
      name: 'My budget',
      location: const VaultLocation.local(path: '/tmp/periods', bookmark: 'b'),
      createdAt: created,
    );

    final json = vault.toJson();

    expect(json['created_at'], created.toIso8601String());
    expect(json['location'], {
      'type': 'local',
      'path': '/tmp/periods',
      'bookmark': 'b',
    });
    expect(Vault.fromJson(jsonDecode(jsonEncode(json))), vault);
  });

  test('remote vault keeps settings and secret names', () {
    final vault = Vault(
      id: 'v2',
      name: 'Work',
      location: const VaultLocation.remote(
        kind: 'gitlab',
        settings: {'repo': 'group/budget', 'branch': 'main'},
        secretNames: ['token'],
      ),
      createdAt: created,
    );

    final json = vault.toJson();

    expect(json['location']['type'], 'remote');
    expect(json['location']['secret_names'], ['token']);
    expect(Vault.fromJson(jsonDecode(jsonEncode(json))), vault);
  });

  test('an unknown remote kind survives a round trip', () {
    final json = {
      'id': 'v3',
      'name': 'Future',
      'created_at': created.toIso8601String(),
      'location': {'type': 'remote', 'kind': 'teleport', 'settings': {}},
    };

    final vault = Vault.fromJson(json);

    expect((vault.location as RemoteVaultLocation).kind, 'teleport');
    expect(jsonDecode(jsonEncode(vault.toJson()))['location']['kind'], 'teleport');
  });

  group('VaultRegistry', () {
    final a = Vault(
      id: 'a',
      name: 'A',
      location: const VaultLocation.local(path: '/a'),
      createdAt: created,
    );
    final b = Vault(
      id: 'b',
      name: 'B',
      location: const VaultLocation.local(path: '/b'),
      createdAt: created,
    );

    test('selected returns the last selected vault', () {
      final registry = VaultRegistry(lastSelectedVaultId: 'b', vaults: [a, b]);
      expect(registry.selected, b);
    });

    test('selected falls back to the first vault when the id is stale', () {
      final registry = VaultRegistry(lastSelectedVaultId: 'gone', vaults: [a, b]);
      expect(registry.selected, a);
    });

    test('selected is null for an empty registry', () {
      expect(const VaultRegistry().selected, isNull);
    });

    test('brokenRegistryFile is not serialised', () {
      final registry = VaultRegistry(vaults: [a], brokenRegistryFile: '/x');
      expect(registry.toJson().containsKey('broken_registry_file'), isFalse);
      expect(registry.toJson()['version'], 1);
    });
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/vault_model_test.dart`
Expected: compile error, `Vault` undefined.

- [ ] **Step 3: Write the models**

`lib/src/models/vault.dart`:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'vault.freezed.dart';
part 'vault.g.dart';

/// A named place that holds one set of period files.
@freezed
sealed class Vault with _$Vault {
  const factory Vault({
    required String id,
    required String name,
    required VaultLocation location,
    required DateTime createdAt,
  }) = _Vault;

  factory Vault.fromJson(Map<String, dynamic> json) => _$VaultFromJson(json);
}

/// Where a vault's files live.
///
/// `local` is a folder the app reads directly: the default app-support
/// folder, a user-picked folder, or an app-private folder on mobile.
/// `remote` is a provider such as `gitlab` or `webdav`; the app works on a
/// local mirror and a sync engine talks to the provider. `settings` holds
/// non-secret provider configuration; secrets live in the keychain under the
/// names listed in `secretNames`. An unknown `kind` is preserved untouched.
@Freezed(unionKey: 'type')
sealed class VaultLocation with _$VaultLocation {
  const factory VaultLocation.local({
    required String path,
    String? bookmark,
  }) = LocalVaultLocation;

  const factory VaultLocation.remote({
    required String kind,
    @Default({}) Map<String, dynamic> settings,
    @Default([]) List<String> secretNames,
  }) = RemoteVaultLocation;

  factory VaultLocation.fromJson(Map<String, dynamic> json) =>
      _$VaultLocationFromJson(json);
}
```

`lib/src/models/vault_registry.dart`:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

import 'vault.dart';

part 'vault_registry.freezed.dart';
part 'vault_registry.g.dart';

/// The contents of `vaults.json`: every known vault and which one is open.
@freezed
sealed class VaultRegistry with _$VaultRegistry {
  const VaultRegistry._();

  const factory VaultRegistry({
    @Default(1) int version,
    String? lastSelectedVaultId,
    @Default([]) List<Vault> vaults,

    /// Set at runtime when the registry file was corrupt and moved aside.
    /// Never written to disk.
    @JsonKey(includeFromJson: false, includeToJson: false)
    String? brokenRegistryFile,
  }) = _VaultRegistry;

  factory VaultRegistry.fromJson(Map<String, dynamic> json) =>
      _$VaultRegistryFromJson(json);

  Vault? byId(String id) => vaults.where((v) => v.id == id).firstOrNull;

  /// The vault to open: the last selected one, or the first when that id
  /// no longer exists. Null only for an empty registry.
  Vault? get selected {
    final id = lastSelectedVaultId;
    if (id != null) {
      final match = byId(id);
      if (match != null) return match;
    }
    return vaults.firstOrNull;
  }
}
```

Add to `lib/src/models/models.dart`:

```dart
export 'vault.dart';
export 'vault_registry.dart';
```

- [ ] **Step 4: Generate code and run the tests**

Run: `dart run build_runner build --delete-conflicting-outputs && flutter test test/vault_model_test.dart && flutter analyze`
Expected: generated `vault.freezed.dart`, `vault.g.dart`, `vault_registry.freezed.dart`, `vault_registry.g.dart`; tests pass.

If the union `type` values come out as `local`/`remote` but the test expects them elsewhere, the `@Freezed(unionKey: 'type')` default case (`FreezedUnionCase.none`) uses the constructor name, which is what the tests assert.

- [ ] **Step 5: Commit**

```bash
git add lib/src/models test/vault_model_test.dart
git commit -m "feat: add Vault, VaultLocation and VaultRegistry models

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 4: `AppPaths`, `VaultSecrets`, and `VaultRegistryService` with migration

**Files:**
- Create: `lib/src/storage/app_paths.dart`
- Create: `lib/src/storage/vault_secrets.dart`
- Create: `lib/src/storage/vault_registry_service.dart`
- Create: `test/vault_registry_service_test.dart`

**Interfaces:**
- Consumes: `Vault`, `VaultLocation`, `VaultRegistry` from Task 3.
- Produces:
  - `class AppPaths { AppPaths({required String appSupportDir}); String get registryFile; String get vaultsDir; String get defaultPeriodsDir; String privateAreaFor(String vaultId); String mirrorFor(String vaultId); String journalFor(String vaultId); static Future<AppPaths> resolve(); }`
  - `abstract interface class VaultSecrets { Future<String?> read(String vaultId, String name); Future<void> write(String vaultId, String name, String value); Future<void> deleteAll(String vaultId, List<String> names); }` and `class MemoryVaultSecrets implements VaultSecrets { final Map<String, String> values; }` keyed `vault.<id>.<name>`.
  - `class LegacyStorageSettings { final String path; final String? bookmark; }`
  - `class VaultRegistryService { VaultRegistryService({required AppPaths paths, required Future<LegacyStorageSettings?> Function() readLegacy, required Future<void> Function() clearLegacy, String Function() newId}); Future<VaultRegistry> loadOrCreate(); Future<void> save(VaultRegistry registry); factory VaultRegistryService.withSharedPreferences(AppPaths paths); }`

- [ ] **Step 1: Write the failing tests**

`test/vault_registry_service_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:flatplan/src/models/models.dart';
import 'package:flatplan/src/storage/app_paths.dart';
import 'package:flatplan/src/storage/vault_registry_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;
  late AppPaths paths;
  LegacyStorageSettings? legacy;
  var legacyCleared = 0;

  VaultRegistryService service() => VaultRegistryService(
    paths: paths,
    readLegacy: () async => legacy,
    clearLegacy: () async => legacyCleared++,
    newId: () => 'fixed-id',
  );

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('flatplan_registry_');
    paths = AppPaths(appSupportDir: tempDir.path);
    legacy = null;
    legacyCleared = 0;
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('AppPaths', () {
    test('derives every location from the app support directory', () {
      expect(paths.registryFile, p.join(tempDir.path, 'vaults.json'));
      expect(paths.defaultPeriodsDir, p.join(tempDir.path, 'periods'));
      expect(paths.vaultsDir, p.join(tempDir.path, 'vaults'));
      expect(paths.privateAreaFor('v1'), p.join(tempDir.path, 'vaults', 'v1'));
      expect(paths.mirrorFor('v1'), p.join(tempDir.path, 'vaults', 'v1', 'files'));
      expect(paths.journalFor('v1'), p.join(tempDir.path, 'vaults', 'v1', 'sync.json'));
    });
  });

  group('loadOrCreate', () {
    test('creates a default local vault at the old periods folder', () async {
      final registry = await service().loadOrCreate();

      expect(registry.vaults.length, 1);
      final vault = registry.vaults.single;
      expect(vault.id, 'fixed-id');
      expect(vault.name, 'My budget');
      expect(vault.location, VaultLocation.local(path: paths.defaultPeriodsDir));
      expect(registry.lastSelectedVaultId, 'fixed-id');
      expect(File(paths.registryFile).existsSync(), isTrue);
      expect(legacyCleared, 1);
    });

    test('migrates a configured folder and bookmark from the old settings',
        () async {
      legacy = const LegacyStorageSettings(
        path: '/Users/me/Documents/budget',
        bookmark: 'bm',
      );

      final registry = await service().loadOrCreate();

      final vault = registry.vaults.single;
      expect(vault.name, 'budget');
      expect(
        vault.location,
        const VaultLocation.local(path: '/Users/me/Documents/budget', bookmark: 'bm'),
      );
      expect(legacyCleared, 1);
    });

    test('reads an existing registry without touching legacy settings',
        () async {
      final first = await service().loadOrCreate();
      legacy = const LegacyStorageSettings(path: '/elsewhere');

      final second = await service().loadOrCreate();

      expect(second, first);
      expect(legacyCleared, 1);
    });

    test('moves a corrupt registry aside and reports it', () async {
      File(paths.registryFile).writeAsStringSync('{ not json');

      final registry = await service().loadOrCreate();

      expect(registry.vaults.single.name, 'My budget');
      expect(registry.brokenRegistryFile, '${paths.registryFile}.broken');
      expect(File('${paths.registryFile}.broken').readAsStringSync(), '{ not json');
      expect(jsonDecode(File(paths.registryFile).readAsStringSync())['version'], 1);
    });

    test('a registry with the wrong shape counts as corrupt', () async {
      File(paths.registryFile).writeAsStringSync('[1, 2, 3]');

      final registry = await service().loadOrCreate();

      expect(registry.brokenRegistryFile, isNotNull);
    });
  });

  group('save', () {
    test('writes snake_case json and leaves no temp file behind', () async {
      final registry = VaultRegistry(
        lastSelectedVaultId: 'a',
        vaults: [
          Vault(
            id: 'a',
            name: 'A',
            location: const VaultLocation.local(path: '/a'),
            createdAt: DateTime.utc(2026, 1, 1),
          ),
        ],
      );

      await service().save(registry);

      final json = jsonDecode(File(paths.registryFile).readAsStringSync());
      expect(json['last_selected_vault_id'], 'a');
      expect(json['vaults'][0]['location']['type'], 'local');
      expect(File('${paths.registryFile}.tmp').existsSync(), isFalse);
      expect(await service().loadOrCreate(), registry);
    });
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/vault_registry_service_test.dart`
Expected: compile error, `AppPaths` undefined.

- [ ] **Step 3: Write the three files**

`lib/src/storage/app_paths.dart`:

```dart
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// The few app-support locations the storage layer needs, derived from one
/// root so tests can point everything at a temp directory.
class AppPaths {
  final String appSupportDir;

  const AppPaths({required this.appSupportDir});

  /// `<app support>/vaults.json`
  String get registryFile => p.join(appSupportDir, 'vaults.json');

  /// `<app support>/periods`, the pre-vault default folder. Kept as the
  /// default vault's path so nothing moves on upgrade.
  String get defaultPeriodsDir => p.join(appSupportDir, 'periods');

  /// `<app support>/vaults`, the root of every per-vault private area.
  String get vaultsDir => p.join(appSupportDir, 'vaults');

  String privateAreaFor(String vaultId) => p.join(vaultsDir, vaultId);

  String mirrorFor(String vaultId) => p.join(privateAreaFor(vaultId), 'files');

  String journalFor(String vaultId) =>
      p.join(privateAreaFor(vaultId), 'sync.json');

  /// Resolves the real application support directory. Writable on every
  /// platform, including MSIX-packaged Windows apps.
  static Future<AppPaths> resolve() async {
    final dir = await getApplicationSupportDirectory();
    return AppPaths(appSupportDir: dir.path);
  }
}
```

`lib/src/storage/vault_secrets.dart`:

```dart
/// Secret values (tokens, access keys) for remote vaults.
///
/// The keychain-backed implementation ships with the first remote provider.
/// Keys are `vault.<vaultId>.<name>`.
abstract interface class VaultSecrets {
  Future<String?> read(String vaultId, String name);
  Future<void> write(String vaultId, String name, String value);
  Future<void> deleteAll(String vaultId, List<String> names);
}

String vaultSecretKey(String vaultId, String name) => 'vault.$vaultId.$name';

/// In-memory secrets for tests and for builds without a keychain plugin.
class MemoryVaultSecrets implements VaultSecrets {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String vaultId, String name) async =>
      values[vaultSecretKey(vaultId, name)];

  @override
  Future<void> write(String vaultId, String name, String value) async {
    values[vaultSecretKey(vaultId, name)] = value;
  }

  @override
  Future<void> deleteAll(String vaultId, List<String> names) async {
    for (final name in names) {
      values.remove(vaultSecretKey(vaultId, name));
    }
  }
}
```

`lib/src/storage/vault_registry_service.dart`:

```dart
import 'dart:convert';
import 'dart:developer' show log;
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import 'app_paths.dart';

/// The pre-vault configuration: one folder plus its macOS bookmark.
class LegacyStorageSettings {
  final String path;
  final String? bookmark;

  const LegacyStorageSettings({required this.path, this.bookmark});
}

/// Reads and writes `vaults.json`, and creates it on first launch from the
/// pre-vault settings.
class VaultRegistryService {
  static const legacyPathKey = 'data_directory';
  static const legacyBookmarkKey = 'data_directory_bookmark';
  static const defaultVaultName = 'My budget';

  final AppPaths paths;
  final Future<LegacyStorageSettings?> Function() _readLegacy;
  final Future<void> Function() _clearLegacy;
  final String Function() _newId;

  VaultRegistryService({
    required this.paths,
    required Future<LegacyStorageSettings?> Function() readLegacy,
    required Future<void> Function() clearLegacy,
    String Function()? newId,
  }) : _readLegacy = readLegacy,
       _clearLegacy = clearLegacy,
       _newId = newId ?? (() => const Uuid().v4());

  /// Production wiring: legacy settings come from shared_preferences.
  factory VaultRegistryService.withSharedPreferences(AppPaths paths) {
    return VaultRegistryService(
      paths: paths,
      readLegacy: () async {
        final prefs = await SharedPreferences.getInstance();
        final path = prefs.getString(legacyPathKey);
        if (path == null || path.isEmpty) return null;
        return LegacyStorageSettings(
          path: path,
          bookmark: prefs.getString(legacyBookmarkKey),
        );
      },
      clearLegacy: () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(legacyPathKey);
        await prefs.remove(legacyBookmarkKey);
      },
    );
  }

  File get _file => File(paths.registryFile);

  /// Loads the registry, or creates it from the legacy settings (or the
  /// default folder) when absent. A corrupt file is moved to
  /// `vaults.json.broken` and reported through
  /// [VaultRegistry.brokenRegistryFile].
  Future<VaultRegistry> loadOrCreate() async {
    String? brokenFile;
    if (await _file.exists()) {
      try {
        final decoded = jsonDecode(await _file.readAsString());
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('registry is not a JSON object');
        }
        return VaultRegistry.fromJson(decoded);
      } catch (e) {
        brokenFile = '${paths.registryFile}.broken';
        log('Corrupt vault registry ($e), moving to $brokenFile',
            name: 'flatplan.storage');
        await _file.rename(brokenFile);
      }
    }

    final registry = await _bootstrap();
    await save(registry);
    // Only forget the legacy keys once the new registry is safely on disk,
    // so a failed first launch can retry the migration.
    await _clearLegacy();
    return registry.copyWith(brokenRegistryFile: brokenFile);
  }

  Future<VaultRegistry> _bootstrap() async {
    final legacy = await _readLegacy();
    final id = _newId();
    final Vault vault;
    if (legacy != null) {
      vault = Vault(
        id: id,
        name: p.basename(legacy.path),
        location: VaultLocation.local(
          path: legacy.path,
          bookmark: legacy.bookmark,
        ),
        createdAt: DateTime.now(),
      );
    } else {
      vault = Vault(
        id: id,
        name: defaultVaultName,
        location: VaultLocation.local(path: paths.defaultPeriodsDir),
        createdAt: DateTime.now(),
      );
    }
    return VaultRegistry(lastSelectedVaultId: id, vaults: [vault]);
  }

  /// Writes atomically: temp file, then rename over the registry.
  Future<void> save(VaultRegistry registry) async {
    await _file.parent.create(recursive: true);
    final tmp = File('${paths.registryFile}.tmp');
    const encoder = JsonEncoder.withIndent('  ');
    await tmp.writeAsString(encoder.convert(registry.toJson()), flush: true);
    await tmp.rename(paths.registryFile);
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/vault_registry_service_test.dart && flutter analyze`
Expected: pass. The `'reads an existing registry'` test compares registries with `==`; `createdAt` round-trips through ISO strings, which preserves equality for `DateTime.now()` values because `toIso8601String` keeps microseconds.

- [ ] **Step 5: Commit**

```bash
git add lib/src/storage/app_paths.dart lib/src/storage/vault_secrets.dart lib/src/storage/vault_registry_service.dart test/vault_registry_service_test.dart
git commit -m "feat: add the vault registry service with legacy migration

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 5: `RemoteStore` contract and the in-memory test store

**Files:**
- Create: `lib/src/sync/remote_store.dart`
- Create: `test/sync/in_memory_remote_store.dart`
- Create: `test/sync/in_memory_remote_store_test.dart`

**Interfaces:**
- Consumes: `RemoteVaultLocation` from Task 3.
- Produces:
  - `class RemoteFile { final String content; final String version; }`
  - `sealed class RemoteChange { final String name; final String? expectedVersion; }`, `final class RemotePut extends RemoteChange { final String content; RemotePut({required String name, required String content, required String? expectedVersion}); }`, `final class RemoteDelete extends RemoteChange { RemoteDelete({required String name, required String expectedVersion}); }`
  - `class RemoteConflict implements Exception { final List<String> names; }`
  - `abstract interface class RemoteStore { Future<Map<String, String>> listTree(); Future<RemoteFile> read(String name); Future<Map<String, String>> writeBatch(List<RemoteChange> changes); }` where `writeBatch` returns the new version of every put; deleted names are absent from the result.
  - `typedef RemoteStoreFactory = Future<RemoteStore> Function(RemoteVaultLocation location, Map<String, String> secrets);`
  - `class RemoteStoreRegistry { void register(String kind, RemoteStoreFactory factory); RemoteStoreFactory? factoryFor(String kind); bool supports(String kind); }`
  - Test double `class InMemoryRemoteStore implements RemoteStore { final Map<String, RemoteFile> files; int? failAfterWrites; Object? failure; Future<void> Function()? onWriteBatch; final List<String> calls; void seed(String name, String content); void remove(String name); }`

- [ ] **Step 1: Write the failing tests for the test double**

`test/sync/in_memory_remote_store_test.dart`:

```dart
import 'dart:io';

import 'package:flatplan/src/sync/remote_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'in_memory_remote_store.dart';

void main() {
  late InMemoryRemoteStore store;

  setUp(() => store = InMemoryRemoteStore());

  test('seed assigns versions and listTree reports them', () async {
    store.seed('a.yaml', 'x');
    store.seed('b.yaml', 'y');

    final tree = await store.listTree();

    expect(tree.keys, ['a.yaml', 'b.yaml']);
    expect(tree['a.yaml'], isNot(tree['b.yaml']));
    expect((await store.read('a.yaml')).content, 'x');
  });

  test('writeBatch applies puts and deletes and returns put versions',
      () async {
    store.seed('old.yaml', 'x');
    final oldVersion = (await store.listTree())['old.yaml']!;

    final versions = await store.writeBatch([
      RemotePut(name: 'new.yaml', content: 'n', expectedVersion: null),
      RemoteDelete(name: 'old.yaml', expectedVersion: oldVersion),
    ]);

    expect(versions.keys, ['new.yaml']);
    expect(await store.listTree(), {'new.yaml': versions['new.yaml']});
  });

  test('writeBatch rejects the whole batch on a stale expected version',
      () async {
    store.seed('a.yaml', 'x');

    await expectLater(
      store.writeBatch([
        RemotePut(name: 'a.yaml', content: 'y', expectedVersion: 'stale'),
        RemotePut(name: 'b.yaml', content: 'z', expectedVersion: null),
      ]),
      throwsA(isA<RemoteConflict>().having((c) => c.names, 'names', ['a.yaml'])),
    );
    expect(await store.listTree(), hasLength(1));
  });

  test('a put with a null expected version conflicts when the file exists',
      () async {
    store.seed('a.yaml', 'x');

    expect(
      () => store.writeBatch([
        RemotePut(name: 'a.yaml', content: 'y', expectedVersion: null),
      ]),
      throwsA(isA<RemoteConflict>()),
    );
  });

  test('failAfterWrites applies part of the batch then throws', () async {
    store.failAfterWrites = 1;

    await expectLater(
      store.writeBatch([
        RemotePut(name: 'a.yaml', content: '1', expectedVersion: null),
        RemotePut(name: 'b.yaml', content: '2', expectedVersion: null),
      ]),
      throwsA(isA<SocketException>()),
    );

    expect((await store.listTree()).keys, ['a.yaml']);
  });

  test('failure makes every call throw', () async {
    store.failure = const SocketException('offline');

    expect(store.listTree, throwsA(isA<SocketException>()));
  });

  test('RemoteStoreRegistry looks factories up by kind', () async {
    final registry = RemoteStoreRegistry();
    expect(registry.supports('memory'), isFalse);

    registry.register('memory', (location, secrets) async => store);

    expect(registry.supports('memory'), isTrue);
    expect(registry.factoryFor('memory'), isNotNull);
    expect(registry.factoryFor('nope'), isNull);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/sync/in_memory_remote_store_test.dart`
Expected: compile error, `remote_store.dart` missing.

- [ ] **Step 3: Write the contract and the test double**

`lib/src/sync/remote_store.dart`:

```dart
import '../models/models.dart';

/// A file as the provider holds it, with the provider's version token.
class RemoteFile {
  final String content;

  /// Opaque: an etag, a blob SHA, a revision id. Only ever compared for
  /// equality.
  final String version;

  const RemoteFile({required this.content, required this.version});
}

/// One change in a push batch. [expectedVersion] is the version the change
/// was based on, so a store that can check it rejects stale writes.
sealed class RemoteChange {
  final String name;
  final String? expectedVersion;

  const RemoteChange({required this.name, required this.expectedVersion});
}

final class RemotePut extends RemoteChange {
  final String content;

  /// [expectedVersion] is null for a file the remote should not have yet.
  const RemotePut({
    required super.name,
    required this.content,
    required super.expectedVersion,
  });
}

final class RemoteDelete extends RemoteChange {
  const RemoteDelete({
    required super.name,
    required String expectedVersion,
  }) : super(expectedVersion: expectedVersion);
}

/// Thrown by [RemoteStore.writeBatch] when an expected version is stale.
/// The engine responds by pulling again and rebuilding the batch.
class RemoteConflict implements Exception {
  final List<String> names;

  const RemoteConflict(this.names);

  @override
  String toString() => 'RemoteConflict(${names.join(', ')})';
}

/// The whole surface a provider implements. Only the sync engine calls it.
abstract interface class RemoteStore {
  /// File name to version for every file in the vault's remote folder.
  Future<Map<String, String>> listTree();

  Future<RemoteFile> read(String name);

  /// Applies every change, atomically where the provider allows it (git
  /// providers make one commit). Returns the new version of each put;
  /// deleted names are absent. Throws [RemoteConflict] when it can detect a
  /// stale [RemoteChange.expectedVersion].
  Future<Map<String, String>> writeBatch(List<RemoteChange> changes);
}

/// Builds a store for a remote vault from its non-secret settings and the
/// secrets read from the keychain, keyed by name.
typedef RemoteStoreFactory =
    Future<RemoteStore> Function(
      RemoteVaultLocation location,
      Map<String, String> secrets,
    );

/// Which remote kinds this build can open. Each provider registers itself
/// here; an unregistered kind is "not supported in this version".
class RemoteStoreRegistry {
  final Map<String, RemoteStoreFactory> _factories = {};

  void register(String kind, RemoteStoreFactory factory) {
    _factories[kind] = factory;
  }

  RemoteStoreFactory? factoryFor(String kind) => _factories[kind];

  bool supports(String kind) => _factories.containsKey(kind);
}
```

`test/sync/in_memory_remote_store.dart`:

```dart
import 'dart:io';

import 'package:flatplan/src/sync/remote_store.dart';

/// A [RemoteStore] held in memory, with knobs to simulate another device,
/// a lost connection mid-batch, and being offline.
class InMemoryRemoteStore implements RemoteStore {
  final Map<String, RemoteFile> files = {};
  int _counter = 0;

  /// When set, [writeBatch] throws a [SocketException] after applying this
  /// many changes, like a non-atomic store losing the connection.
  int? failAfterWrites;

  /// When set, every call throws it, like being offline.
  Object? failure;

  /// Runs inside [writeBatch] before anything is applied, so a test can
  /// simulate a local edit landing while a push is in flight.
  Future<void> Function()? onWriteBatch;

  /// Every call, for asserting how many round trips the engine made.
  final List<String> calls = [];

  String _nextVersion() => 'v${++_counter}';

  /// Another device wrote this file directly.
  void seed(String name, String content) {
    files[name] = RemoteFile(content: content, version: _nextVersion());
  }

  /// Another device deleted this file directly.
  void remove(String name) => files.remove(name);

  void _checkFailure() {
    final f = failure;
    if (f != null) throw f;
  }

  @override
  Future<Map<String, String>> listTree() async {
    _checkFailure();
    calls.add('listTree');
    return {for (final e in files.entries) e.key: e.value.version};
  }

  @override
  Future<RemoteFile> read(String name) async {
    _checkFailure();
    calls.add('read $name');
    final file = files[name];
    if (file == null) throw StateError('remote has no $name');
    return file;
  }

  @override
  Future<Map<String, String>> writeBatch(List<RemoteChange> changes) async {
    _checkFailure();
    calls.add('writeBatch ${changes.length}');
    await onWriteBatch?.call();

    final stale = [
      for (final change in changes)
        if (files[change.name]?.version != change.expectedVersion) change.name,
    ];
    if (stale.isNotEmpty) throw RemoteConflict(stale);

    final versions = <String, String>{};
    var applied = 0;
    for (final change in changes) {
      final limit = failAfterWrites;
      if (limit != null && applied >= limit) {
        throw const SocketException('connection lost mid-batch');
      }
      switch (change) {
        case RemotePut():
          final version = _nextVersion();
          files[change.name] =
              RemoteFile(content: change.content, version: version);
          versions[change.name] = version;
        case RemoteDelete():
          files.remove(change.name);
      }
      applied++;
    }
    return versions;
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/sync/in_memory_remote_store_test.dart && flutter analyze`
Expected: pass.

- [ ] **Step 5: Commit**

```bash
git add lib/src/sync/remote_store.dart test/sync/
git commit -m "feat: define the RemoteStore contract and an in-memory test store

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 6: `SyncJournal` and `ConflictPolicy`

**Files:**
- Modify: `pubspec.yaml` (add `crypto: ^3.0.7` under `dependencies`)
- Create: `lib/src/sync/sync_journal.dart`
- Create: `lib/src/sync/conflict_policy.dart`
- Create: `test/sync/sync_journal_test.dart`
- Create: `test/sync/conflict_policy_test.dart`

**Interfaces:**
- Consumes: `WorkspaceChangeListener` (Task 1), `PeriodStatsWriter.fileName` (Task 2).
- Produces:
  - `String contentHash(String content)` (sha256 hex)
  - `class JournalEntry { final String version; final String contentHash; }` with `==`, `toJson`, `fromJson`
  - `class SyncJournal implements WorkspaceChangeListener { SyncJournal({String? filePath}); static Future<SyncJournal> load(String filePath); final Map<String, JournalEntry> baseline; final Set<String> dirty; DateTime? lastPullAt; DateTime? lastPushAt; String? lastError; bool needsFullRescan; void Function(String name)? onDirty; Future<void> save(); Map<String, dynamic> toJson(); }`
  - `class ConflictPolicy { const ConflictPolicy({required DateTime? Function(String name, String content) timestampOf, Set<String> derivedFiles, DateTime Function() now}); }`
  - `DateTime? periodLastModified(String name, String content)`
  - `final ConflictPolicy periodConflictPolicy`
  - `String conflictFileName(String name, DateTime at)`

- [ ] **Step 1: Write the failing tests**

`test/sync/sync_journal_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:flatplan/src/sync/sync_journal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;
  late String journalPath;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('flatplan_journal_');
    journalPath = p.join(tempDir.path, 'v1', 'sync.json');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('contentHash is stable and differs by content', () {
    expect(contentHash('a'), contentHash('a'));
    expect(contentHash('a'), isNot(contentHash('b')));
    expect(contentHash('a'), hasLength(64));
  });

  test('load of a missing file gives an empty journal', () async {
    final journal = await SyncJournal.load(journalPath);

    expect(journal.baseline, isEmpty);
    expect(journal.dirty, isEmpty);
    expect(journal.needsFullRescan, isFalse);
  });

  test('onChanged marks dirty, persists, then notifies', () async {
    final journal = await SyncJournal.load(journalPath);
    final notified = <String>[];
    journal.onDirty = notified.add;

    await journal.onChanged('a.yaml');

    expect(journal.dirty, {'a.yaml'});
    expect(notified, ['a.yaml']);
    final onDisk = jsonDecode(File(journalPath).readAsStringSync());
    expect(onDisk['dirty'], ['a.yaml']);
  });

  test('save round-trips every field in snake_case', () async {
    final journal = await SyncJournal.load(journalPath);
    journal.baseline['a.yaml'] =
        const JournalEntry(version: 'v1', contentHash: 'h1');
    journal.dirty.add('b.yaml');
    journal.lastPullAt = DateTime.utc(2026, 9, 16, 10);
    journal.lastPushAt = DateTime.utc(2026, 9, 16, 11);
    journal.lastError = 'boom';
    await journal.save();

    final reloaded = await SyncJournal.load(journalPath);

    expect(reloaded.baseline, {
      'a.yaml': const JournalEntry(version: 'v1', contentHash: 'h1'),
    });
    expect(reloaded.dirty, {'b.yaml'});
    expect(reloaded.lastPullAt, DateTime.utc(2026, 9, 16, 10));
    expect(reloaded.lastPushAt, DateTime.utc(2026, 9, 16, 11));
    expect(reloaded.lastError, 'boom');
    final raw = jsonDecode(File(journalPath).readAsStringSync());
    expect(raw['baseline']['a.yaml']['content_hash'], 'h1');
    expect(raw['last_pull_at'], isA<String>());
    expect(File('$journalPath.tmp').existsSync(), isFalse);
  });

  test('a corrupt journal starts empty and asks for a full rescan', () async {
    File(journalPath).createSync(recursive: true);
    File(journalPath).writeAsStringSync('{ nope');

    final journal = await SyncJournal.load(journalPath);

    expect(journal.needsFullRescan, isTrue);
    expect(journal.dirty, isEmpty);
  });

  test('an in-memory journal saves nothing', () async {
    final journal = SyncJournal();
    await journal.onChanged('a.yaml');
    expect(journal.dirty, {'a.yaml'});
  });
}
```

`test/sync/conflict_policy_test.dart`:

```dart
import 'package:flatplan/src/sync/conflict_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('periodLastModified reads last_modified from period yaml', () {
    final ts = periodLastModified(
      '2026-09-september.yaml',
      'id: p1\nlast_modified: 2026-09-10T08:30:00.000\nname: September\n',
    );

    expect(ts, DateTime(2026, 9, 10, 8, 30));
  });

  test('periodLastModified is null for non-yaml, broken yaml, or no field', () {
    expect(periodLastModified('current_stats.md', 'last_modified: x'), isNull);
    expect(periodLastModified('a.yaml', 'foo: [1, 2'), isNull);
    expect(periodLastModified('a.yaml', 'id: p1\n'), isNull);
    expect(periodLastModified('a.yaml', '- a\n- b\n'), isNull);
  });

  test('periodConflictPolicy treats the stats file as derived', () {
    expect(periodConflictPolicy.derivedFiles, {'current_stats.md'});
  });

  test('conflictFileName keeps stem and extension around a timestamp', () {
    expect(
      conflictFileName('2026-09-september.yaml', DateTime(2026, 9, 16, 14, 32)),
      '2026-09-september.conflict-2026-09-16-1432.yaml',
    );
    expect(
      conflictFileName('notes', DateTime(2026, 1, 2, 3, 4)),
      'notes.conflict-2026-01-02-0304',
    );
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/sync/sync_journal_test.dart test/sync/conflict_policy_test.dart`
Expected: compile errors, files missing.

- [ ] **Step 3: Add `crypto` and write both files**

In `pubspec.yaml` under `dependencies:` add:

```yaml
  crypto: ^3.0.7
```

Run `flutter pub get`.

`lib/src/sync/sync_journal.dart`:

```dart
import 'dart:convert';
import 'dart:developer' show log;
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../storage/vault_workspace.dart';

/// SHA-256 hex of [content]. Used to tell "changed" from "re-written with
/// the same bytes" without keeping copies.
String contentHash(String content) =>
    sha256.convert(utf8.encode(content)).toString();

/// What the remote held for one file at the last pull.
class JournalEntry {
  final String version;
  final String contentHash;

  const JournalEntry({required this.version, required this.contentHash});

  Map<String, dynamic> toJson() => {
    'version': version,
    'content_hash': contentHash,
  };

  factory JournalEntry.fromJson(Map<String, dynamic> json) => JournalEntry(
    version: json['version'] as String,
    contentHash: json['content_hash'] as String,
  );

  @override
  bool operator ==(Object other) =>
      other is JournalEntry &&
      other.version == version &&
      other.contentHash == contentHash;

  @override
  int get hashCode => Object.hash(version, contentHash);
}

/// The persisted sync state of one remote vault: `sync.json`.
///
/// Written after every state change so a crash at any point loses nothing.
/// As the mirror's [WorkspaceChangeListener] it marks a file dirty before
/// the write lands.
class SyncJournal implements WorkspaceChangeListener {
  /// Null for an in-memory journal (tests): [save] is then a no-op.
  final String? filePath;

  /// Remote version and content hash per file, as of the last pull.
  final Map<String, JournalEntry> baseline = {};

  /// Files changed locally since the last successful push.
  final Set<String> dirty = {};

  DateTime? lastPullAt;
  DateTime? lastPushAt;
  String? lastError;

  /// True when the journal file was unreadable. The engine then treats
  /// every mirror file as dirty on the next pull, so a stale baseline can
  /// never make it overwrite local edits.
  bool needsFullRescan = false;

  /// Called after a name is marked dirty. The scheduler hooks in here.
  void Function(String name)? onDirty;

  SyncJournal({this.filePath});

  static Future<SyncJournal> load(String filePath) async {
    final journal = SyncJournal(filePath: filePath);
    final file = File(filePath);
    if (await file.exists()) {
      try {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('journal is not a JSON object');
        }
        journal._apply(decoded);
      } catch (e) {
        log('Unreadable sync journal $filePath ($e); rescanning',
            name: 'flatplan.sync');
        journal.needsFullRescan = true;
      }
    }
    return journal;
  }

  @override
  Future<void> onChanged(String name) async {
    dirty.add(name);
    await save();
    onDirty?.call(name);
  }

  Future<void> save() async {
    final path = filePath;
    if (path == null) return;
    final file = File(path);
    await file.parent.create(recursive: true);
    final tmp = File('$path.tmp');
    await tmp.writeAsString(jsonEncode(toJson()), flush: true);
    await tmp.rename(path);
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    'baseline': {for (final e in baseline.entries) e.key: e.value.toJson()},
    'dirty': dirty.toList()..sort(),
    'last_pull_at': lastPullAt?.toIso8601String(),
    'last_push_at': lastPushAt?.toIso8601String(),
    'last_error': lastError,
  };

  void _apply(Map<String, dynamic> json) {
    final base = json['baseline'] as Map<String, dynamic>? ?? {};
    for (final e in base.entries) {
      baseline[e.key] = JournalEntry.fromJson(e.value as Map<String, dynamic>);
    }
    dirty.addAll((json['dirty'] as List<dynamic>? ?? []).cast<String>());
    lastPullAt = _date(json['last_pull_at']);
    lastPushAt = _date(json['last_push_at']);
    lastError = json['last_error'] as String?;
  }

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}
```

`lib/src/sync/conflict_policy.dart`:

```dart
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../storage/period_stats_writer.dart';

/// How the engine settles a file edited on both sides since the last pull.
///
/// Newest [timestampOf] wins; the loser is kept as a side file. When a
/// timestamp is missing on either side, local wins. [derivedFiles] are
/// regenerated from other data, so local wins silently with no side file.
class ConflictPolicy {
  final DateTime? Function(String name, String content) timestampOf;
  final Set<String> derivedFiles;
  final DateTime Function() now;

  const ConflictPolicy({
    required this.timestampOf,
    this.derivedFiles = const {},
    this.now = DateTime.now,
  });
}

/// Reads `last_modified` from a period YAML file. Null for anything else,
/// including unreadable YAML.
DateTime? periodLastModified(String name, String content) {
  if (!name.endsWith('.yaml')) return null;
  try {
    final doc = loadYaml(content);
    if (doc is! YamlMap) return null;
    final value = doc['last_modified'];
    return value is String ? DateTime.tryParse(value) : null;
  } on YamlException {
    return null;
  }
}

/// The app's policy: period files carry `last_modified`; the stats file is
/// derived.
final periodConflictPolicy = ConflictPolicy(
  timestampOf: periodLastModified,
  derivedFiles: {PeriodStatsWriter.fileName},
);

/// `2026-09-september.yaml` at 2026-09-16 14:32 becomes
/// `2026-09-september.conflict-2026-09-16-1432.yaml`.
String conflictFileName(String name, DateTime at) {
  final ext = p.extension(name);
  final stem = p.basenameWithoutExtension(name);
  final stamp = DateFormat('yyyy-MM-dd-HHmm').format(at);
  return '$stem.conflict-$stamp$ext';
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/sync/ && flutter analyze`
Expected: pass.

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/src/sync/sync_journal.dart lib/src/sync/conflict_policy.dart test/sync/
git commit -m "feat: add the sync journal and the conflict policy

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 7: `SyncEngine` pull

**Files:**
- Create: `lib/src/sync/sync_engine.dart`
- Create: `test/sync/sync_engine_pull_test.dart`

**Interfaces:**
- Consumes: `VaultWorkspace`, `MemoryWorkspace` (Task 1), `RemoteStore`, `RemoteFile` (Task 5), `SyncJournal`, `JournalEntry`, `contentHash`, `ConflictPolicy`, `conflictFileName` (Task 6), `InMemoryRemoteStore` (Task 5, test).
- Produces:
  - `class SyncFailure { final String message; final bool isOffline; factory SyncFailure.from(Object error); }`
  - `class SyncEngine { SyncEngine({required VaultWorkspace mirror, required RemoteStore remote, required SyncJournal journal, required ConflictPolicy policy}); static const maxConflictRounds = 3; Future<SyncFailure?> pull(); Future<SyncFailure?> push(); }` (push lands in Task 8; stub it to throw `UnimplementedError` here)
  - `mirror` must be the **unlistened** workspace over the mirror folder. The engine adds side files to `journal.dirty` itself.

- [ ] **Step 1: Write the failing pull tests**

`test/sync/sync_engine_pull_test.dart`:

```dart
import 'package:flatplan/src/storage/vault_workspace.dart';
import 'package:flatplan/src/sync/conflict_policy.dart';
import 'package:flatplan/src/sync/sync_engine.dart';
import 'package:flatplan/src/sync/sync_journal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'in_memory_remote_store.dart';

final fixedNow = DateTime(2026, 9, 16, 14, 32);

String period(String lastModified, {String note = ''}) =>
    'id: p1\nlast_modified: $lastModified\nnote: $note\n';

void main() {
  late Map<String, String> files;
  late MemoryWorkspace mirror; // unlistened, what the engine writes through
  late MemoryWorkspace app; // journal-listened, what the app writes through
  late SyncJournal journal;
  late InMemoryRemoteStore remote;
  late SyncEngine engine;

  setUp(() {
    files = {};
    journal = SyncJournal();
    mirror = MemoryWorkspace(files: files);
    app = MemoryWorkspace(files: files, changeListener: journal);
    remote = InMemoryRemoteStore();
    engine = SyncEngine(
      mirror: mirror,
      remote: remote,
      journal: journal,
      policy: ConflictPolicy(
        timestampOf: periodLastModified,
        derivedFiles: {'current_stats.md'},
        now: () => fixedNow,
      ),
    );
  });

  test('first pull copies every remote file into an empty mirror', () async {
    remote.seed('a.yaml', period('2026-09-01T00:00:00'));
    remote.seed('current_stats.md', '# stats');

    final failure = await engine.pull();

    expect(failure, isNull);
    expect(files.keys, containsAll(['a.yaml', 'current_stats.md']));
    expect(journal.baseline.keys, containsAll(['a.yaml', 'current_stats.md']));
    expect(journal.baseline['a.yaml']!.version, (await remote.listTree())['a.yaml']);
    expect(journal.dirty, isEmpty);
    expect(journal.lastPullAt, fixedNow);
  });

  test('a second pull reads only files whose version changed', () async {
    remote.seed('a.yaml', 'a1');
    remote.seed('b.yaml', 'b1');
    await engine.pull();
    remote.calls.clear();
    remote.seed('b.yaml', 'b2');

    await engine.pull();

    expect(remote.calls, ['listTree', 'read b.yaml']);
    expect(files['b.yaml'], 'b2');
  });

  test('remote change to a clean file replaces the mirror copy', () async {
    remote.seed('a.yaml', 'one');
    await engine.pull();
    remote.seed('a.yaml', 'two');

    await engine.pull();

    expect(files['a.yaml'], 'two');
    expect(journal.dirty, isEmpty);
  });

  test('a dirty file with identical remote content just adopts the version',
      () async {
    await app.writeString('a.yaml', 'same');
    remote.seed('a.yaml', 'same');

    await engine.pull();

    expect(journal.dirty, isEmpty);
    expect(journal.baseline['a.yaml']!.contentHash, contentHash('same'));
  });

  group('conflict, newest last_modified wins', () {
    test('remote newer: remote replaces local, local kept as side file',
        () async {
      remote.seed('p.yaml', period('2026-09-01T00:00:00'));
      await engine.pull();
      await app.writeString('p.yaml', period('2026-09-10T00:00:00', note: 'local'));
      remote.seed('p.yaml', period('2026-09-12T00:00:00', note: 'remote'));

      await engine.pull();

      expect(files['p.yaml'], period('2026-09-12T00:00:00', note: 'remote'));
      expect(
        files['p.conflict-2026-09-16-1432.yaml'],
        period('2026-09-10T00:00:00', note: 'local'),
      );
      expect(journal.dirty, {'p.conflict-2026-09-16-1432.yaml'});
      expect(journal.baseline['p.yaml']!.version, (await remote.listTree())['p.yaml']);
    });

    test('local newer: local stays dirty, remote kept as side file', () async {
      remote.seed('p.yaml', period('2026-09-01T00:00:00'));
      await engine.pull();
      await app.writeString('p.yaml', period('2026-09-12T00:00:00', note: 'local'));
      remote.seed('p.yaml', period('2026-09-10T00:00:00', note: 'remote'));

      await engine.pull();

      expect(files['p.yaml'], period('2026-09-12T00:00:00', note: 'local'));
      expect(
        files['p.conflict-2026-09-16-1432.yaml'],
        period('2026-09-10T00:00:00', note: 'remote'),
      );
      expect(journal.dirty, {'p.yaml', 'p.conflict-2026-09-16-1432.yaml'});
    });

    test('missing timestamp on either side: local wins with a side file',
        () async {
      remote.seed('notes.txt', 'v1');
      await engine.pull();
      await app.writeString('notes.txt', 'local');
      remote.seed('notes.txt', 'remote');

      await engine.pull();

      expect(files['notes.txt'], 'local');
      expect(files['notes.conflict-2026-09-16-1432.txt'], 'remote');
      expect(journal.dirty, {'notes.txt', 'notes.conflict-2026-09-16-1432.txt'});
    });

    test('derived file: local wins silently', () async {
      remote.seed('current_stats.md', 'v1');
      await engine.pull();
      await app.writeString('current_stats.md', 'local');
      remote.seed('current_stats.md', 'remote');

      await engine.pull();

      expect(files['current_stats.md'], 'local');
      expect(files.keys.where((k) => k.contains('.conflict-')), isEmpty);
      expect(journal.dirty, {'current_stats.md'});
    });

    test('deleted locally but edited remotely: remote copy is restored',
        () async {
      remote.seed('p.yaml', period('2026-09-01T00:00:00'));
      await engine.pull();
      await app.delete('p.yaml');
      remote.seed('p.yaml', period('2026-09-12T00:00:00'));

      await engine.pull();

      expect(files['p.yaml'], period('2026-09-12T00:00:00'));
      expect(journal.dirty, isEmpty);
    });
  });

  group('remote deletions', () {
    test('a clean file deleted remotely is deleted locally', () async {
      remote.seed('a.yaml', 'x');
      await engine.pull();
      remote.remove('a.yaml');

      await engine.pull();

      expect(files, isEmpty);
      expect(journal.baseline, isEmpty);
    });

    test('a dirty file deleted remotely is kept and will be re-created',
        () async {
      remote.seed('a.yaml', 'x');
      await engine.pull();
      await app.writeString('a.yaml', 'edited');
      remote.remove('a.yaml');

      await engine.pull();

      expect(files['a.yaml'], 'edited');
      expect(journal.baseline.containsKey('a.yaml'), isFalse);
      expect(journal.dirty, {'a.yaml'});
    });
  });

  test('a journal needing a full rescan marks every mirror file dirty first',
      () async {
    files['a.yaml'] = 'local';
    journal.needsFullRescan = true;
    remote.seed('a.yaml', 'remote');

    await engine.pull();

    expect(journal.needsFullRescan, isFalse);
    expect(files['a.yaml'], 'local'); // not silently overwritten
    expect(files['a.conflict-2026-09-16-1432.yaml'], 'remote');
  });

  test('a network error is reported as offline and recorded', () async {
    remote.failure = const SocketException('no route');

    final failure = await engine.pull();

    expect(failure, isNotNull);
    expect(failure!.isOffline, isTrue);
    expect(journal.lastError, contains('no route'));
  });

  test('a successful pull clears the last error', () async {
    journal.lastError = 'old';

    await engine.pull();

    expect(journal.lastError, isNull);
  });
}
```

Add `import 'dart:io';` at the top of the test for `SocketException`.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/sync/sync_engine_pull_test.dart`
Expected: compile error, `sync_engine.dart` missing.

- [ ] **Step 3: Write the engine with pull and a stub push**

`lib/src/sync/sync_engine.dart`:

```dart
import 'dart:async';
import 'dart:io';

import '../storage/vault_workspace.dart';
import 'conflict_policy.dart';
import 'remote_store.dart';
import 'sync_journal.dart';

/// Why a pull or push did not complete. Nothing is lost either way: the
/// journal keeps every dirty name and the next trigger tries again.
class SyncFailure {
  final String message;

  /// True for connectivity problems, which the UI shows as "Offline"
  /// rather than as an error.
  final bool isOffline;

  const SyncFailure({required this.message, required this.isOffline});

  factory SyncFailure.from(Object error) => SyncFailure(
    message: error.toString(),
    isOffline:
        error is SocketException ||
        error is TimeoutException ||
        error is HttpException,
  );
}

/// Moves files between the local mirror and a [RemoteStore].
///
/// [mirror] must be the workspace *without* the journal as its change
/// listener: the engine records dirtiness itself, and pulled files must
/// not become dirty.
class SyncEngine {
  static const maxConflictRounds = 3;

  final VaultWorkspace mirror;
  final RemoteStore remote;
  final SyncJournal journal;
  final ConflictPolicy policy;

  SyncEngine({
    required this.mirror,
    required this.remote,
    required this.journal,
    required this.policy,
  });

  /// Brings the mirror up to date with the remote. Never throws.
  Future<SyncFailure?> pull() async {
    try {
      await _pull();
      journal.lastError = null;
      await journal.save();
      return null;
    } catch (e) {
      return _recordFailure(e);
    }
  }

  /// Sends every dirty file to the remote as one batch. Lands in Task 8.
  Future<SyncFailure?> push() => throw UnimplementedError();

  Future<SyncFailure> _recordFailure(Object error) async {
    final failure = SyncFailure.from(error);
    journal.lastError = failure.message;
    await journal.save();
    return failure;
  }

  Future<void> _pull() async {
    if (journal.needsFullRescan) {
      journal.dirty.addAll(await mirror.listFiles());
      journal.needsFullRescan = false;
      await journal.save();
    }

    final tree = await remote.listTree();

    for (final entry in tree.entries) {
      final name = entry.key;
      final version = entry.value;
      if (journal.baseline[name]?.version == version) continue;

      final remoteFile = await remote.read(name);
      final remoteEntry = JournalEntry(
        version: version,
        contentHash: contentHash(remoteFile.content),
      );

      if (!journal.dirty.contains(name)) {
        await mirror.writeString(name, remoteFile.content);
        journal.baseline[name] = remoteEntry;
        continue;
      }

      final local =
          await mirror.exists(name) ? await mirror.readString(name) : null;
      if (local == remoteFile.content) {
        // An interrupted earlier push already landed this file.
        journal.dirty.remove(name);
      } else {
        await _resolveConflict(name, local, remoteFile.content);
      }
      journal.baseline[name] = remoteEntry;
    }

    for (final name in journal.baseline.keys.toList()) {
      if (tree.containsKey(name)) continue;
      journal.baseline.remove(name);
      if (journal.dirty.contains(name)) continue; // push re-creates it
      await mirror.delete(name);
    }

    journal.lastPullAt = policy.now();
    await journal.save();
  }

  /// [local] is null when the file was deleted locally.
  Future<void> _resolveConflict(
    String name,
    String? local,
    String remoteContent,
  ) async {
    if (local == null) {
      // Deleted here, edited there: keeping the edit loses nothing.
      await mirror.writeString(name, remoteContent);
      journal.dirty.remove(name);
      return;
    }
    if (policy.derivedFiles.contains(name)) return; // local wins, stays dirty

    final localTs = policy.timestampOf(name, local);
    final remoteTs = policy.timestampOf(name, remoteContent);
    final remoteWins =
        localTs != null && remoteTs != null && remoteTs.isAfter(localTs);

    final sideName = conflictFileName(name, policy.now());
    if (remoteWins) {
      await mirror.writeString(sideName, local);
      await mirror.writeString(name, remoteContent);
      journal.dirty.remove(name);
    } else {
      await mirror.writeString(sideName, remoteContent);
    }
    journal.dirty.add(sideName);
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/sync/sync_engine_pull_test.dart && flutter analyze`
Expected: pass.

- [ ] **Step 5: Commit**

```bash
git add lib/src/sync/sync_engine.dart test/sync/sync_engine_pull_test.dart
git commit -m "feat: add SyncEngine pull with newest-wins conflict handling

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 8: `SyncEngine` push and recovery

**Files:**
- Modify: `lib/src/sync/sync_engine.dart`
- Create: `test/sync/sync_engine_push_test.dart`

**Interfaces:**
- Consumes: everything from Task 7.
- Produces: `Future<SyncFailure?> push()` implemented as specified.

- [ ] **Step 1: Write the failing push tests**

`test/sync/sync_engine_push_test.dart`:

```dart
import 'dart:io';

import 'package:flatplan/src/storage/vault_workspace.dart';
import 'package:flatplan/src/sync/conflict_policy.dart';
import 'package:flatplan/src/sync/sync_engine.dart';
import 'package:flatplan/src/sync/sync_journal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'in_memory_remote_store.dart';

final fixedNow = DateTime(2026, 9, 16, 14, 32);

String period(String lastModified, {String note = ''}) =>
    'id: p1\nlast_modified: $lastModified\nnote: $note\n';

void main() {
  late Map<String, String> files;
  late MemoryWorkspace mirror;
  late MemoryWorkspace app;
  late SyncJournal journal;
  late InMemoryRemoteStore remote;
  late SyncEngine engine;

  setUp(() {
    files = {};
    journal = SyncJournal();
    mirror = MemoryWorkspace(files: files);
    app = MemoryWorkspace(files: files, changeListener: journal);
    remote = InMemoryRemoteStore();
    engine = SyncEngine(
      mirror: mirror,
      remote: remote,
      journal: journal,
      policy: ConflictPolicy(
        timestampOf: periodLastModified,
        derivedFiles: {'current_stats.md'},
        now: () => fixedNow,
      ),
    );
  });

  test('nothing dirty: push makes no remote calls', () async {
    final failure = await engine.push();

    expect(failure, isNull);
    expect(remote.calls, isEmpty);
  });

  test('pushes new files as one batch and records their versions', () async {
    await app.writeString('a.yaml', 'a');
    await app.writeString('b.yaml', 'b');

    final failure = await engine.push();

    expect(failure, isNull);
    expect(remote.calls.where((c) => c.startsWith('writeBatch')), ['writeBatch 2']);
    expect((await remote.read('a.yaml')).content, 'a');
    expect(journal.dirty, isEmpty);
    expect(journal.baseline['a.yaml']!.version, (await remote.listTree())['a.yaml']);
    expect(journal.baseline['a.yaml']!.contentHash, contentHash('a'));
    expect(journal.lastPushAt, fixedNow);
  });

  test('pushes a local delete as a remote delete', () async {
    remote.seed('a.yaml', 'x');
    await engine.pull();
    await app.delete('a.yaml');

    await engine.push();

    expect(await remote.listTree(), isEmpty);
    expect(journal.baseline, isEmpty);
    expect(journal.dirty, isEmpty);
  });

  test('a file created and deleted before any push is simply forgotten',
      () async {
    await app.writeString('tmp.yaml', 'x');
    await app.delete('tmp.yaml');

    await engine.push();

    expect(journal.dirty, isEmpty);
    expect(remote.calls.where((c) => c.startsWith('writeBatch')), isEmpty);
  });

  test('an interrupted push leaves everything dirty, and a re-run heals',
      () async {
    await app.writeString('a.yaml', 'a');
    await app.writeString('b.yaml', 'b');
    remote.failAfterWrites = 1;

    final first = await engine.push();

    expect(first, isNotNull);
    expect(first!.isOffline, isTrue);
    expect(journal.dirty, {'a.yaml', 'b.yaml'});
    expect(journal.lastError, isNotNull);

    remote.failAfterWrites = null;
    remote.calls.clear();
    final second = await engine.push();

    expect(second, isNull);
    expect(remote.calls.last, 'writeBatch 1'); // only the file still missing
    expect(await remote.listTree(), hasLength(2));
    expect(journal.dirty, isEmpty);
    expect(journal.lastError, isNull);
  });

  test('a remote conflict triggers a re-pull and a second attempt', () async {
    remote.seed('p.yaml', period('2026-09-01T00:00:00'));
    await engine.pull();
    await app.writeString('p.yaml', period('2026-09-12T00:00:00', note: 'local'));
    // Another device commits between our pull and our write.
    remote.onWriteBatch = () async {
      if (remote.calls.where((c) => c.startsWith('writeBatch')).length == 1) {
        remote.seed('p.yaml', period('2026-09-05T00:00:00', note: 'other'));
      }
    };

    final failure = await engine.push();

    expect(failure, isNull);
    expect(remote.calls.where((c) => c.startsWith('writeBatch')), hasLength(2));
    expect((await remote.read('p.yaml')).content, contains('local'));
    expect(files['p.conflict-2026-09-16-1432.yaml'], contains('other'));
    expect((await remote.listTree()).keys, contains('p.conflict-2026-09-16-1432.yaml'));
  });

  test('gives up after three conflict rounds and keeps everything dirty',
      () async {
    await app.writeString('a.yaml', 'mine');
    remote.onWriteBatch = () async => remote.seed('a.yaml', 'theirs-${remote.calls.length}');

    final failure = await engine.push();

    expect(failure, isNotNull);
    expect(failure!.isOffline, isFalse);
    expect(remote.calls.where((c) => c.startsWith('writeBatch')), hasLength(3));
    expect(journal.dirty, contains('a.yaml'));
  });

  test('a local edit during the push keeps that file dirty', () async {
    await app.writeString('a.yaml', 'v1');
    remote.onWriteBatch = () async => app.writeString('a.yaml', 'v2');

    await engine.push();

    expect((await remote.read('a.yaml')).content, 'v1');
    expect(journal.dirty, {'a.yaml'});
    expect(journal.baseline['a.yaml']!.contentHash, contentHash('v1'));
  });

  test('offline: dirty set untouched, error recorded', () async {
    await app.writeString('a.yaml', 'a');
    remote.failure = const SocketException('offline');

    final failure = await engine.push();

    expect(failure!.isOffline, isTrue);
    expect(journal.dirty, {'a.yaml'});
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/sync/sync_engine_push_test.dart`
Expected: FAIL with `UnimplementedError`.

- [ ] **Step 3: Implement push**

Replace the stub in `lib/src/sync/sync_engine.dart`:

```dart
  /// Sends every dirty file to the remote as one batch, pulling first so
  /// conflicts are settled locally. Retries up to [maxConflictRounds] when
  /// the remote moved underneath. Never throws.
  Future<SyncFailure?> push() async {
    try {
      for (var round = 1; round <= maxConflictRounds; round++) {
        if (journal.dirty.isEmpty) return await _succeed();
        await _pull();
        final snapshot = await _snapshot();
        if (snapshot.changes.isEmpty) return await _succeed();
        try {
          final versions = await remote.writeBatch(snapshot.changes);
          await _commit(snapshot, versions);
          journal.lastPushAt = policy.now();
          return await _succeed();
        } on RemoteConflict {
          continue;
        }
      }
      return _recordFailure(
        StateError('The remote kept changing during sync; will retry later.'),
      );
    } catch (e) {
      return _recordFailure(e);
    }
  }

  Future<SyncFailure?> _succeed() async {
    journal.lastError = null;
    await journal.save();
    return null;
  }

  /// What is about to be pushed: the batch, plus the hash of each pushed
  /// content (null for a delete) so a later edit can be told apart.
  Future<_Snapshot> _snapshot() async {
    final changes = <RemoteChange>[];
    final hashes = <String, String?>{};
    for (final name in journal.dirty.toList()) {
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
    }
    return _Snapshot(changes: changes, hashes: hashes);
  }

  Future<void> _commit(_Snapshot snapshot, Map<String, String> versions) async {
    for (final entry in snapshot.hashes.entries) {
      final name = entry.key;
      final pushedHash = entry.value;
      if (pushedHash == null) {
        journal.baseline.remove(name);
      } else {
        final version = versions[name];
        if (version != null) {
          journal.baseline[name] =
              JournalEntry(version: version, contentHash: pushedHash);
        }
      }
      final currentHash = await mirror.exists(name)
          ? contentHash(await mirror.readString(name))
          : null;
      if (currentHash == pushedHash) journal.dirty.remove(name);
    }
  }
}

class _Snapshot {
  final List<RemoteChange> changes;
  final Map<String, String?> hashes;

  const _Snapshot({required this.changes, required this.hashes});
}
```

Also remove the closing `}` of the class that preceded the stub so the new members sit inside `SyncEngine`, with `_Snapshot` after it.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/sync/ && flutter analyze`
Expected: pass.

- [ ] **Step 5: Commit**

```bash
git add lib/src/sync/sync_engine.dart test/sync/sync_engine_push_test.dart
git commit -m "feat: add SyncEngine push with interrupted-push recovery

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 9: `SyncStatus` and `SyncScheduler`

**Files:**
- Create: `lib/src/sync/sync_status.dart`
- Create: `lib/src/sync/sync_scheduler.dart`
- Create: `test/sync/sync_status_test.dart`
- Create: `test/sync/sync_scheduler_test.dart`

**Interfaces:**
- Consumes: `SyncEngine`, `SyncFailure` (Tasks 7, 8), `SyncJournal.onDirty` (Task 6).
- Produces:
  - `enum SyncState { idle, syncing, offline, error }`
  - `class SyncStatus { const SyncStatus({required SyncState state, required int dirtyCount, DateTime? lastPullAt, DateTime? lastPushAt, String? lastError}); String describe(DateTime now); }`
  - `class SyncScheduler { SyncScheduler({required SyncEngine engine, required void Function(SyncStatus) onStatus, Duration idleDelay = const Duration(seconds: 15), Duration switchTimeout = const Duration(seconds: 5)}); SyncStatus get status; void noteChange(String name); Future<void> pullNow(); Future<void> syncNow(); Future<void> onAppPaused(); Future<void> flushBeforeSwitch(); void dispose(); }`

- [ ] **Step 1: Write the failing tests**

`test/sync/sync_status_test.dart`:

```dart
import 'package:flatplan/src/sync/sync_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 9, 16, 12, 0);

  SyncStatus idle({int dirty = 0, DateTime? pushed, DateTime? pulled}) =>
      SyncStatus(
        state: SyncState.idle,
        dirtyCount: dirty,
        lastPushAt: pushed,
        lastPullAt: pulled,
      );

  test('describe covers every state', () {
    expect(
      const SyncStatus(state: SyncState.syncing, dirtyCount: 0).describe(now),
      'Syncing…',
    );
    expect(
      const SyncStatus(state: SyncState.offline, dirtyCount: 2).describe(now),
      'Offline · 2 changes pending',
    );
    expect(
      const SyncStatus(state: SyncState.offline, dirtyCount: 0).describe(now),
      'Offline',
    );
    expect(
      const SyncStatus(state: SyncState.error, dirtyCount: 0, lastError: 'x')
          .describe(now),
      'Sync failed',
    );
    expect(idle(dirty: 1).describe(now), '1 change pending');
    expect(idle(dirty: 3).describe(now), '3 changes pending');
    expect(idle().describe(now), 'Not synced yet');
  });

  test('describe formats how long ago the last sync was', () {
    expect(idle(pushed: now.subtract(const Duration(seconds: 20))).describe(now),
        'Synced just now');
    expect(idle(pushed: now.subtract(const Duration(minutes: 2))).describe(now),
        'Synced 2 min ago');
    expect(idle(pulled: now.subtract(const Duration(hours: 3))).describe(now),
        'Synced 3 h ago');
    expect(idle(pushed: now.subtract(const Duration(days: 2))).describe(now),
        'Synced 2 d ago');
  });

  test('the most recent of pull and push counts', () {
    final status = idle(
      pulled: now.subtract(const Duration(minutes: 1)),
      pushed: now.subtract(const Duration(hours: 1)),
    );
    expect(status.describe(now), 'Synced 1 min ago');
  });
}
```

`test/sync/sync_scheduler_test.dart`:

```dart
import 'dart:async';
import 'dart:io';

import 'package:flatplan/src/storage/vault_workspace.dart';
import 'package:flatplan/src/sync/conflict_policy.dart';
import 'package:flatplan/src/sync/sync_engine.dart';
import 'package:flatplan/src/sync/sync_journal.dart';
import 'package:flatplan/src/sync/sync_scheduler.dart';
import 'package:flatplan/src/sync/sync_status.dart';
import 'package:flutter_test/flutter_test.dart';

import 'in_memory_remote_store.dart';

void main() {
  late Map<String, String> files;
  late MemoryWorkspace app;
  late SyncJournal journal;
  late InMemoryRemoteStore remote;
  late SyncScheduler scheduler;
  late List<SyncStatus> statuses;

  setUp(() {
    files = {};
    journal = SyncJournal();
    app = MemoryWorkspace(files: files, changeListener: journal);
    remote = InMemoryRemoteStore();
    statuses = [];
    scheduler = SyncScheduler(
      engine: SyncEngine(
        mirror: MemoryWorkspace(files: files),
        remote: remote,
        journal: journal,
        policy: periodConflictPolicy,
      ),
      onStatus: statuses.add,
      idleDelay: const Duration(milliseconds: 30),
      switchTimeout: const Duration(milliseconds: 50),
    );
    journal.onDirty = scheduler.noteChange;
  });

  tearDown(() => scheduler.dispose());

  test('pushes once after the idle delay following the last change', () async {
    await app.writeString('a.yaml', 'a');
    await Future<void>.delayed(const Duration(milliseconds: 15));
    await app.writeString('b.yaml', 'b');
    expect(remote.calls, isEmpty);

    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(remote.calls.where((c) => c.startsWith('writeBatch')), ['writeBatch 2']);
    expect(scheduler.status.state, SyncState.idle);
    expect(scheduler.status.dirtyCount, 0);
  });

  test('reports the dirty count as soon as a change is noted', () async {
    await app.writeString('a.yaml', 'a');

    expect(statuses.last.dirtyCount, 1);
    expect(statuses.last.state, SyncState.idle);
  });

  test('syncNow pushes immediately and reports syncing then idle', () async {
    await app.writeString('a.yaml', 'a');

    await scheduler.syncNow();

    expect(statuses.map((s) => s.state), containsAllInOrder([SyncState.syncing, SyncState.idle]));
    expect(await remote.listTree(), hasLength(1));
  });

  test('onAppPaused pushes without waiting for the idle delay', () async {
    await app.writeString('a.yaml', 'a');

    await scheduler.onAppPaused();

    expect(await remote.listTree(), hasLength(1));
  });

  test('pullNow pulls', () async {
    remote.seed('a.yaml', 'x');

    await scheduler.pullNow();

    expect(files['a.yaml'], 'x');
  });

  test('offline failure shows as offline and keeps changes', () async {
    await app.writeString('a.yaml', 'a');
    remote.failure = const SocketException('down');

    await scheduler.syncNow();

    expect(scheduler.status.state, SyncState.offline);
    expect(scheduler.status.dirtyCount, 1);
  });

  test('a trigger during a run queues exactly one re-run', () async {
    await app.writeString('a.yaml', 'a');
    final gate = Completer<void>();
    remote.onWriteBatch = () => gate.future;

    final first = scheduler.syncNow();
    await Future<void>.delayed(Duration.zero);
    final second = scheduler.syncNow();
    final third = scheduler.syncNow();
    remote.onWriteBatch = null;
    gate.complete();
    await Future.wait([first, second, third]);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    // One batch carried the change; the queued re-run found nothing dirty
    // and made no remote call, but it did run: syncing was reported twice.
    expect(remote.calls.where((c) => c.startsWith('writeBatch')), hasLength(1));
    expect(statuses.where((s) => s.state == SyncState.syncing).length, 2);
  });

  test('flushBeforeSwitch returns after the timeout even if the push hangs',
      () async {
    await app.writeString('a.yaml', 'a');
    remote.onWriteBatch = () => Completer<void>().future;

    final stopwatch = Stopwatch()..start();
    await scheduler.flushBeforeSwitch();

    expect(stopwatch.elapsedMilliseconds, lessThan(500));
  });

  test('dispose cancels a pending idle push', () async {
    await app.writeString('a.yaml', 'a');
    scheduler.dispose();

    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(remote.calls, isEmpty);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/sync/sync_status_test.dart test/sync/sync_scheduler_test.dart`
Expected: compile errors, files missing.

- [ ] **Step 3: Write both files**

`lib/src/sync/sync_status.dart`:

```dart
enum SyncState { idle, syncing, offline, error }

/// What the switcher and Settings show for the open remote vault.
class SyncStatus {
  final SyncState state;
  final int dirtyCount;
  final DateTime? lastPullAt;
  final DateTime? lastPushAt;
  final String? lastError;

  const SyncStatus({
    required this.state,
    required this.dirtyCount,
    this.lastPullAt,
    this.lastPushAt,
    this.lastError,
  });

  /// One short line for the UI.
  String describe(DateTime now) {
    final pending = dirtyCount == 1 ? '1 change pending' : '$dirtyCount changes pending';
    switch (state) {
      case SyncState.syncing:
        return 'Syncing…';
      case SyncState.offline:
        return dirtyCount > 0 ? 'Offline · $pending' : 'Offline';
      case SyncState.error:
        return 'Sync failed';
      case SyncState.idle:
        if (dirtyCount > 0) return pending;
        final last = _latest(lastPullAt, lastPushAt);
        if (last == null) return 'Not synced yet';
        return 'Synced ${_ago(now.difference(last))}';
    }
  }

  static DateTime? _latest(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.isAfter(b) ? a : b;
  }

  static String _ago(Duration d) {
    if (d.inMinutes < 1) return 'just now';
    if (d.inHours < 1) return '${d.inMinutes} min ago';
    if (d.inDays < 1) return '${d.inHours} h ago';
    return '${d.inDays} d ago';
  }
}
```

`lib/src/sync/sync_scheduler.dart`:

```dart
import 'dart:async';

import 'sync_engine.dart';
import 'sync_status.dart';

/// Decides *when* the engine runs. Triggers are coarse and single-flight:
/// a trigger during a run queues exactly one re-run.
class SyncScheduler {
  final SyncEngine engine;
  final void Function(SyncStatus) onStatus;
  final Duration idleDelay;
  final Duration switchTimeout;

  Timer? _idleTimer;
  Future<void>? _running;
  bool _rerunQueued = false;
  bool _disposed = false;
  SyncStatus _status = const SyncStatus(state: SyncState.idle, dirtyCount: 0);

  SyncScheduler({
    required this.engine,
    required this.onStatus,
    this.idleDelay = const Duration(seconds: 15),
    this.switchTimeout = const Duration(seconds: 5),
  });

  SyncStatus get status => _status;

  /// A file was marked dirty. Restarts the idle timer.
  void noteChange(String name) {
    if (_disposed) return;
    _idleTimer?.cancel();
    _idleTimer = Timer(idleDelay, () => _run(push: true));
    _emit(_status.state == SyncState.syncing ? SyncState.syncing : SyncState.idle);
  }

  Future<void> pullNow() => _run(push: false);

  Future<void> syncNow() => _run(push: true);

  Future<void> onAppPaused() {
    _idleTimer?.cancel();
    return _run(push: true);
  }

  /// Best effort before switching vaults: the switch proceeds regardless.
  Future<void> flushBeforeSwitch() async {
    _idleTimer?.cancel();
    try {
      await _run(push: true).timeout(switchTimeout);
    } on TimeoutException {
      // The engine keeps running in the background; the journal has it all.
    }
  }

  void dispose() {
    _disposed = true;
    _idleTimer?.cancel();
  }

  Future<void> _run({required bool push}) {
    final running = _running;
    if (running != null) {
      _rerunQueued = true;
      return running;
    }
    final future = _execute(push: push).whenComplete(() {
      _running = null;
      if (_rerunQueued && !_disposed) {
        _rerunQueued = false;
        unawaited(_run(push: true));
      }
    });
    _running = future;
    return future;
  }

  Future<void> _execute({required bool push}) async {
    if (_disposed) return;
    _emit(SyncState.syncing);
    final failure = push ? await engine.push() : await engine.pull();
    if (_disposed) return;
    if (failure == null) {
      _emit(SyncState.idle);
    } else {
      _emit(failure.isOffline ? SyncState.offline : SyncState.error);
    }
  }

  void _emit(SyncState state) {
    final journal = engine.journal;
    _status = SyncStatus(
      state: state,
      dirtyCount: journal.dirty.length,
      lastPullAt: journal.lastPullAt,
      lastPushAt: journal.lastPushAt,
      lastError: journal.lastError,
    );
    onStatus(_status);
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/sync/ && flutter analyze`
Expected: pass. If the queued re-run test is flaky on timing, raise its final delay to 30 ms; the assertion is on call counts, not timing.

- [ ] **Step 5: Commit**

```bash
git add lib/src/sync/sync_status.dart lib/src/sync/sync_scheduler.dart test/sync/sync_status_test.dart test/sync/sync_scheduler_test.dart
git commit -m "feat: add SyncStatus and the single-flight SyncScheduler

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 10: `VaultResolver` and `OpenVault`

**Files:**
- Create: `lib/src/storage/vault_resolver.dart`
- Create: `test/storage/fake_bookmarks.dart` (moved out of `test/storage_settings_service_test.dart`)
- Create: `test/vault_resolver_test.dart`

**Interfaces:**
- Consumes: `Vault`, `LocalVaultLocation`, `RemoteVaultLocation` (Task 3), `AppPaths`, `VaultSecrets` (Task 4), `DirectoryWorkspace` (Task 1), `RemoteStoreRegistry` (Task 5), `SyncJournal` (Task 6), `SyncEngine` (Tasks 7-8), `SyncScheduler`, `SyncStatus` (Task 9), `SecurityScopedBookmarks` and `MacosSecurityScopedBookmarks` (existing `lib/src/storage/security_scoped_bookmarks.dart`), `periodConflictPolicy` (Task 6).
- Produces:
  - `class OpenVault { const OpenVault({required Vault vault, VaultWorkspace? workspace, SyncScheduler? scheduler, String? accessError}); bool get isUsable; bool get isRemote; void dispose(); }`
  - `class VaultResolver { VaultResolver({required AppPaths paths, required RemoteStoreRegistry remoteStores, required VaultSecrets secrets, SecurityScopedBookmarks? bookmarks, bool? useBookmarks, ConflictPolicy? policy, Duration idleDelay, Duration switchTimeout}); Future<OpenVault> open(Vault vault, {void Function(SyncStatus)? onStatus}); Future<String?> bookmarkFor(String path); static const unsupportedKindError; static const missingSecretError; static String missingFolderError(String path); }`
  - The resolver does **not** pull. The provider that opens a vault triggers the first pull.

- [ ] **Step 1: Move `FakeBookmarks` into a shared test file**

`test/storage/fake_bookmarks.dart`:

```dart
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
```

In `test/storage_settings_service_test.dart` delete the `FakeBookmarks` class and add `import 'storage/fake_bookmarks.dart';`. (The whole file is deleted in Task 11; this keeps it compiling until then.)

- [ ] **Step 2: Write the failing resolver tests**

`test/vault_resolver_test.dart`:

```dart
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
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `flutter test test/vault_resolver_test.dart`
Expected: compile error, `vault_resolver.dart` missing.

- [ ] **Step 4: Write the resolver**

`lib/src/storage/vault_resolver.dart`:

```dart
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/models.dart';
import '../sync/conflict_policy.dart';
import '../sync/remote_store.dart';
import '../sync/sync_engine.dart';
import '../sync/sync_journal.dart';
import '../sync/sync_scheduler.dart';
import '../sync/sync_status.dart';
import 'app_paths.dart';
import 'security_scoped_bookmarks.dart';
import 'vault_secrets.dart';
import 'vault_workspace.dart';

/// A vault the app can work in, or the reason it cannot.
class OpenVault {
  final Vault vault;

  /// Null when [accessError] is set.
  final VaultWorkspace? workspace;

  /// Present for remote vaults only.
  final SyncScheduler? scheduler;

  /// Why the vault could not be opened. The vault stays selected; the UI
  /// explains and points at the vault's settings.
  final String? accessError;

  const OpenVault({
    required this.vault,
    this.workspace,
    this.scheduler,
    this.accessError,
  });

  bool get isUsable => workspace != null;

  bool get isRemote => vault.location is RemoteVaultLocation;

  void dispose() => scheduler?.dispose();
}

/// Turns a [Vault] into an [OpenVault]. Every platform quirk lives here:
/// macOS bookmarks, folders that may not exist yet, provider lookup.
class VaultResolver {
  static const unsupportedKindError =
      'This vault type is not supported in this version.';
  static const missingSecretError =
      'Sign in to this vault again in its settings.';
  static String missingFolderError(String path) =>
      'The folder "$path" could not be found. '
      'Choose it again in the vault settings.';

  final AppPaths paths;
  final RemoteStoreRegistry remoteStores;
  final VaultSecrets secrets;
  final ConflictPolicy policy;
  final Duration idleDelay;
  final Duration switchTimeout;

  /// Null on platforms without sandbox bookmarks.
  final SecurityScopedBookmarks? _bookmarks;

  VaultResolver({
    required this.paths,
    required this.remoteStores,
    required this.secrets,
    SecurityScopedBookmarks? bookmarks,
    bool? useBookmarks,
    ConflictPolicy? policy,
    this.idleDelay = const Duration(seconds: 15),
    this.switchTimeout = const Duration(seconds: 5),
  }) : _bookmarks = (useBookmarks ?? Platform.isMacOS)
           ? (bookmarks ?? MacosSecurityScopedBookmarks())
           : null,
       policy = policy ?? periodConflictPolicy;

  /// A bookmark for a just-picked folder, or null where bookmarks are not
  /// needed. Called by the local-folder form when the user picks a folder.
  Future<String?> bookmarkFor(String path) =>
      _bookmarks?.bookmarkForPath(path) ?? Future.value(null);

  Future<OpenVault> open(
    Vault vault, {
    void Function(SyncStatus)? onStatus,
  }) {
    switch (vault.location) {
      case LocalVaultLocation(:final path, :final bookmark):
        return _openLocal(vault, path, bookmark);
      case final RemoteVaultLocation location:
        return _openRemote(vault, location, onStatus);
    }
  }

  Future<OpenVault> _openLocal(
    Vault vault,
    String path,
    String? bookmark,
  ) async {
    var resolvedPath = path;
    final bookmarks = _bookmarks;
    if (bookmarks != null && bookmark != null) {
      try {
        resolvedPath = await bookmarks.resolvePath(bookmark);
        final granted = await bookmarks.startAccessing(resolvedPath);
        if (!granted) {
          throw const FileSystemException('Access to the folder was denied');
        }
      } catch (e) {
        return OpenVault(
          vault: vault,
          accessError:
              'FlatPlan could not open "$path" ($e). '
              'Choose the folder again in the vault settings.',
        );
      }
    }

    // Folders inside the app's own area are created on first write. A
    // user-picked folder that is gone is a problem the user must fix.
    final insideApp = p.isWithin(paths.appSupportDir, resolvedPath);
    if (!insideApp && !await Directory(resolvedPath).exists()) {
      return OpenVault(vault: vault, accessError: missingFolderError(path));
    }
    return OpenVault(vault: vault, workspace: DirectoryWorkspace(resolvedPath));
  }

  Future<OpenVault> _openRemote(
    Vault vault,
    RemoteVaultLocation location,
    void Function(SyncStatus)? onStatus,
  ) async {
    final factory = remoteStores.factoryFor(location.kind);
    if (factory == null) {
      return OpenVault(vault: vault, accessError: unsupportedKindError);
    }

    final secretValues = <String, String>{};
    for (final name in location.secretNames) {
      final value = await secrets.read(vault.id, name);
      if (value == null) {
        return OpenVault(vault: vault, accessError: missingSecretError);
      }
      secretValues[name] = value;
    }

    final store = await factory(location, secretValues);
    final journal = await SyncJournal.load(paths.journalFor(vault.id));
    final mirrorPath = paths.mirrorFor(vault.id);
    final engine = SyncEngine(
      mirror: DirectoryWorkspace(mirrorPath),
      remote: store,
      journal: journal,
      policy: policy,
    );
    final scheduler = SyncScheduler(
      engine: engine,
      onStatus: onStatus ?? (_) {},
      idleDelay: idleDelay,
      switchTimeout: switchTimeout,
    );
    journal.onDirty = scheduler.noteChange;

    return OpenVault(
      vault: vault,
      workspace: DirectoryWorkspace(mirrorPath, changeListener: journal),
      scheduler: scheduler,
    );
  }
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/vault_resolver_test.dart test/storage_settings_service_test.dart && flutter analyze`
Expected: pass.

- [ ] **Step 6: Commit**

```bash
git add lib/src/storage/vault_resolver.dart test/storage/fake_bookmarks.dart test/vault_resolver_test.dart test/storage_settings_service_test.dart
git commit -m "feat: add VaultResolver turning a vault into a workspace

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 11: Providers: registry, open vault, async repository; remove the old storage settings

**Files:**
- Create: `lib/src/providers/app_paths_provider.dart`
- Create: `lib/src/providers/vaults_provider.dart`
- Create: `lib/src/providers/open_vault_provider.dart`
- Create: `lib/src/components/vault_banners.dart`
- Modify: `lib/src/providers/repository_provider.dart`
- Modify: `lib/src/providers/all_periods_provider.dart:12-16`
- Modify: `lib/src/providers/period_notifier_provider.dart:23-27, 259-262`
- Modify: `lib/src/providers/current_period_provider.dart:18-20, 52-55, 253-256`
- Modify: `lib/src/providers/current_period_stats_sync_provider.dart:26`
- Modify: `lib/src/views/settings_view.dart:1-16, 26, 53-192`
- Delete: `lib/src/storage/storage_settings_service.dart`, `lib/src/providers/storage_settings_provider.dart`, `lib/src/providers/storage_settings_provider.g.dart`, `test/storage_settings_service_test.dart`
- Create: `test/vaults_provider_test.dart`
- Create: `test/open_vault_provider_test.dart`
- Create: `test/support/fake_vaults.dart`

**Interfaces:**
- Consumes: everything from Tasks 3, 4, 10.
- Produces:
  - `appPathsProvider`: `Future<AppPaths>`, keepAlive
  - `vaultRegistryServiceProvider`: `Future<VaultRegistryService>`, keepAlive
  - `vaultSecretsProvider`: `VaultSecrets`, keepAlive
  - `vaultsProvider`: `Vaults extends _$Vaults`, `Future<VaultRegistry> build()`, `Future<void> select(String id)`, `Future<void> add(Vault vault)`, `Future<void> update(Vault vault)`, `Future<void> remove(String id)`, `void dismissBrokenRegistryNotice()`; `remove` throws `StateError` for the last vault
  - `remoteStoreRegistryProvider`: `RemoteStoreRegistry`, keepAlive
  - `vaultResolverProvider`: `Future<VaultResolver>`, keepAlive
  - `currentSyncStatusProvider`: `CurrentSyncStatus extends _$CurrentSyncStatus`, `SyncStatus? build()`, `void set(SyncStatus? status)`
  - `openVaultProvider`: `Future<OpenVault>`, keepAlive; pulls on open; flushes and disposes the previous scheduler on rebuild
  - `periodRepositoryProvider`: now `Future<PeriodRepository>`; throws `VaultUnavailable(message)` when the open vault has no workspace
  - `class VaultUnavailable implements Exception { final String message; }`
  - `class VaultAccessBanner extends StatelessWidget { const VaultAccessBanner({required String message}); }`
  - Test helper `class FakeVaults extends Vaults { FakeVaults(VaultRegistry registry); final List<String> selected; final List<Vault> added; final List<Vault> updated; final List<String> removed; }`

- [ ] **Step 1: Write the failing provider tests**

`test/support/fake_vaults.dart`:

```dart
import 'package:flatplan/src/models/models.dart';
import 'package:flatplan/src/providers/vaults_provider.dart';

/// A [Vaults] notifier over a fixed registry that records mutations
/// instead of touching disk.
class FakeVaults extends Vaults {
  FakeVaults(this.registry);

  VaultRegistry registry;
  final List<String> selected = [];
  final List<Vault> added = [];
  final List<Vault> updated = [];
  final List<String> removed = [];

  @override
  Future<VaultRegistry> build() async => registry;

  @override
  Future<void> select(String id) async {
    selected.add(id);
    registry = registry.copyWith(lastSelectedVaultId: id);
    state = AsyncData(registry);
  }

  @override
  Future<void> add(Vault vault) async {
    added.add(vault);
    registry = registry.copyWith(
      vaults: [...registry.vaults, vault],
      lastSelectedVaultId: vault.id,
    );
    state = AsyncData(registry);
  }

  @override
  Future<void> update(Vault vault) async {
    updated.add(vault);
    registry = registry.copyWith(
      vaults: [for (final v in registry.vaults) v.id == vault.id ? vault : v],
    );
    state = AsyncData(registry);
  }

  @override
  Future<void> remove(String id) async {
    removed.add(id);
    registry = registry.copyWith(
      vaults: registry.vaults.where((v) => v.id != id).toList(),
    );
    state = AsyncData(registry);
  }

  @override
  void dismissBrokenRegistryNotice() {
    registry = registry.copyWith(brokenRegistryFile: null);
    state = AsyncData(registry);
  }
}
```

`test/vaults_provider_test.dart`:

```dart
import 'dart:io';

import 'package:flatplan/src/models/models.dart';
import 'package:flatplan/src/providers/app_paths_provider.dart';
import 'package:flatplan/src/providers/vaults_provider.dart';
import 'package:flatplan/src/storage/app_paths.dart';
import 'package:flatplan/src/storage/vault_registry_service.dart';
import 'package:flatplan/src/storage/vault_secrets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;
  late AppPaths paths;
  late MemoryVaultSecrets secrets;
  late ProviderContainer container;
  var ids = 0;

  Vault vault(String id, {VaultLocation? location}) => Vault(
    id: id,
    name: 'Vault $id',
    location: location ?? VaultLocation.local(path: '/tmp/$id'),
    createdAt: DateTime.utc(2026, 1, 1),
  );

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('flatplan_vaults_');
    paths = AppPaths(appSupportDir: tempDir.path);
    secrets = MemoryVaultSecrets();
    ids = 0;
    container = ProviderContainer(
      overrides: [
        appPathsProvider.overrideWith((ref) async => paths),
        vaultSecretsProvider.overrideWith((ref) => secrets),
        vaultRegistryServiceProvider.overrideWith(
          (ref) async => VaultRegistryService(
            paths: paths,
            readLegacy: () async => null,
            clearLegacy: () async {},
            newId: () => 'id-${++ids}',
          ),
        ),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('build creates the default vault on first launch', () async {
    final registry = await container.read(vaultsProvider.future);

    expect(registry.vaults.single.name, 'My budget');
    expect(registry.selected!.id, 'id-1');
  });

  test('add appends, selects, and persists', () async {
    await container.read(vaultsProvider.future);

    await container.read(vaultsProvider.notifier).add(vault('b'));

    final registry = await container.read(vaultsProvider.future);
    expect(registry.vaults.map((v) => v.id), ['id-1', 'b']);
    expect(registry.selected!.id, 'b');
    expect(File(paths.registryFile).readAsStringSync(), contains('"b"'));
  });

  test('select changes the selected vault and ignores unknown ids', () async {
    await container.read(vaultsProvider.future);
    await container.read(vaultsProvider.notifier).add(vault('b'));

    await container.read(vaultsProvider.notifier).select('id-1');
    expect((await container.read(vaultsProvider.future)).selected!.id, 'id-1');

    await container.read(vaultsProvider.notifier).select('nope');
    expect((await container.read(vaultsProvider.future)).selected!.id, 'id-1');
  });

  test('update replaces a vault by id', () async {
    await container.read(vaultsProvider.future);

    await container
        .read(vaultsProvider.notifier)
        .update(vault('id-1').copyWith(name: 'Renamed'));

    expect((await container.read(vaultsProvider.future)).vaults.single.name, 'Renamed');
  });

  test('remove forgets the vault, its secrets and its private area only',
      () async {
    await container.read(vaultsProvider.future);
    final remote = vault(
      'r',
      location: const VaultLocation.remote(kind: 'x', secretNames: ['token']),
    );
    await container.read(vaultsProvider.notifier).add(remote);
    await secrets.write('r', 'token', 't');
    final area = Directory(paths.mirrorFor('r'))..createSync(recursive: true);
    File(p.join(area.path, 'a.yaml')).writeAsStringSync('x');
    final userFolder = Directory(p.join(tempDir.path, 'user'))..createSync();
    await container.read(vaultsProvider.notifier).update(
      vault('id-1', location: VaultLocation.local(path: userFolder.path)),
    );

    await container.read(vaultsProvider.notifier).remove('r');

    final registry = await container.read(vaultsProvider.future);
    expect(registry.vaults.map((v) => v.id), ['id-1']);
    expect(registry.selected!.id, 'id-1');
    expect(await secrets.read('r', 'token'), isNull);
    expect(Directory(paths.privateAreaFor('r')).existsSync(), isFalse);
    expect(userFolder.existsSync(), isTrue);
  });

  test('removing the selected vault selects the first remaining one',
      () async {
    await container.read(vaultsProvider.future);
    await container.read(vaultsProvider.notifier).add(vault('b'));
    await container.read(vaultsProvider.notifier).add(vault('c'));

    await container.read(vaultsProvider.notifier).remove('c');

    expect((await container.read(vaultsProvider.future)).selected!.id, 'id-1');
  });

  test('the last vault cannot be removed', () async {
    await container.read(vaultsProvider.future);

    expect(
      () => container.read(vaultsProvider.notifier).remove('id-1'),
      throwsStateError,
    );
  });

  test('dismissBrokenRegistryNotice clears the notice', () async {
    File(paths.registryFile).writeAsStringSync('{ nope');
    final registry = await container.read(vaultsProvider.future);
    expect(registry.brokenRegistryFile, isNotNull);

    container.read(vaultsProvider.notifier).dismissBrokenRegistryNotice();

    expect((await container.read(vaultsProvider.future)).brokenRegistryFile, isNull);
  });
}
```

`test/open_vault_provider_test.dart`:

```dart
import 'dart:io';

import 'package:flatplan/src/models/models.dart';
import 'package:flatplan/src/providers/app_paths_provider.dart';
import 'package:flatplan/src/providers/open_vault_provider.dart';
import 'package:flatplan/src/providers/repository_provider.dart';
import 'package:flatplan/src/providers/vaults_provider.dart';
import 'package:flatplan/src/storage/app_paths.dart';
import 'package:flatplan/src/storage/vault_resolver.dart';
import 'package:flatplan/src/storage/vault_secrets.dart';
import 'package:flatplan/src/sync/remote_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:path/path.dart' as p;

import 'support/fake_vaults.dart';
import 'sync/in_memory_remote_store.dart';

void main() {
  late Directory tempDir;
  late AppPaths paths;
  late RemoteStoreRegistry stores;
  late InMemoryRemoteStore remote;
  late FakeVaults fakeVaults;
  late ProviderContainer container;
  final created = DateTime.utc(2026, 1, 1);

  Vault localVault(String id) => Vault(
    id: id,
    name: id,
    location: VaultLocation.local(path: p.join(tempDir.path, id)),
    createdAt: created,
  );

  Vault remoteVault() => Vault(
    id: 'r',
    name: 'Remote',
    location: const VaultLocation.remote(kind: 'memory'),
    createdAt: created,
  );

  ProviderContainer makeContainer(VaultRegistry registry) {
    fakeVaults = FakeVaults(registry);
    return ProviderContainer(
      overrides: [
        appPathsProvider.overrideWith((ref) async => paths),
        remoteStoreRegistryProvider.overrideWith((ref) => stores),
        vaultsProvider.overrideWith(() => fakeVaults),
        vaultResolverProvider.overrideWith(
          (ref) async => VaultResolver(
            paths: paths,
            remoteStores: stores,
            secrets: MemoryVaultSecrets(),
            useBookmarks: false,
            idleDelay: const Duration(milliseconds: 20),
            switchTimeout: const Duration(milliseconds: 200),
          ),
        ),
      ],
    );
  }

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('flatplan_open_');
    paths = AppPaths(appSupportDir: p.join(tempDir.path, 'support'));
    stores = RemoteStoreRegistry();
    remote = InMemoryRemoteStore();
    stores.register('memory', (location, secrets) async => remote);
    Directory(p.join(tempDir.path, 'a')).createSync();
    Directory(p.join(tempDir.path, 'b')).createSync();
  });

  tearDown(() {
    container.dispose();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('opens the selected vault and builds a repository over it', () async {
    container = makeContainer(
      VaultRegistry(lastSelectedVaultId: 'a', vaults: [localVault('a'), localVault('b')]),
    );

    final open = await container.read(openVaultProvider.future);
    final repo = await container.read(periodRepositoryProvider.future);

    expect(open.vault.id, 'a');
    expect(repo.workspace.displayPath, p.join(tempDir.path, 'a'));
  });

  test('selecting another vault re-opens and rebuilds the repository',
      () async {
    container = makeContainer(
      VaultRegistry(lastSelectedVaultId: 'a', vaults: [localVault('a'), localVault('b')]),
    );
    container.listen(periodRepositoryProvider, (_, _) {});
    await container.read(periodRepositoryProvider.future);

    await container.read(vaultsProvider.notifier).select('b');

    final repo = await container.read(periodRepositoryProvider.future);
    expect(repo.workspace.displayPath, p.join(tempDir.path, 'b'));
  });

  test('a vault with an access error makes the repository unavailable',
      () async {
    final missing = Vault(
      id: 'm',
      name: 'Missing',
      location: VaultLocation.local(path: p.join(tempDir.path, 'gone')),
      createdAt: created,
    );
    container = makeContainer(VaultRegistry(lastSelectedVaultId: 'm', vaults: [missing]));

    final open = await container.read(openVaultProvider.future);

    expect(open.accessError, isNotNull);
    await expectLater(
      container.read(periodRepositoryProvider.future),
      throwsA(isA<VaultUnavailable>().having((e) => e.message, 'message', open.accessError)),
    );
  });

  test('a remote vault pulls on open and publishes its status', () async {
    remote.seed('x.yaml', 'x');
    container = makeContainer(VaultRegistry(lastSelectedVaultId: 'r', vaults: [remoteVault()]));

    final open = await container.read(openVaultProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(await open.workspace!.readString('x.yaml'), 'x');
    expect(container.read(currentSyncStatusProvider), isNotNull);
    expect(container.read(currentSyncStatusProvider)!.lastPullAt, isNotNull);
  });

  test('switching away from a remote vault flushes its pending changes',
      () async {
    container = makeContainer(
      VaultRegistry(lastSelectedVaultId: 'r', vaults: [remoteVault(), localVault('a')]),
    );
    container.listen(openVaultProvider, (_, _) {});
    final open = await container.read(openVaultProvider.future);
    await open.workspace!.writeString('new.yaml', 'n');

    await container.read(vaultsProvider.notifier).select('a');
    await container.read(openVaultProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect((await remote.listTree()).keys, contains('new.yaml'));
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/vaults_provider_test.dart test/open_vault_provider_test.dart`
Expected: compile errors, providers missing.

- [ ] **Step 3: Write the providers**

`lib/src/providers/app_paths_provider.dart`:

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../storage/app_paths.dart';

part 'app_paths_provider.g.dart';

/// The app-support locations, resolved once per app run.
@Riverpod(keepAlive: true)
Future<AppPaths> appPaths(Ref ref) => AppPaths.resolve();
```

`lib/src/providers/vaults_provider.dart`:

```dart
import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/models.dart';
import '../storage/vault_registry_service.dart';
import '../storage/vault_secrets.dart';
import 'app_paths_provider.dart';

part 'vaults_provider.g.dart';

@Riverpod(keepAlive: true)
Future<VaultRegistryService> vaultRegistryService(Ref ref) async {
  final paths = await ref.watch(appPathsProvider.future);
  return VaultRegistryService.withSharedPreferences(paths);
}

/// Secret storage for remote vaults. In-memory until the first remote
/// provider brings the keychain implementation.
@Riverpod(keepAlive: true)
VaultSecrets vaultSecrets(Ref ref) => MemoryVaultSecrets();

/// The vault registry: every known vault and which one is selected.
@Riverpod(keepAlive: true)
class Vaults extends _$Vaults {
  @override
  Future<VaultRegistry> build() async {
    final service = await ref.watch(vaultRegistryServiceProvider.future);
    return service.loadOrCreate();
  }

  /// Makes [id] the open vault. Unknown ids are ignored.
  Future<void> select(String id) async {
    final registry = await future;
    if (registry.byId(id) == null || registry.selected?.id == id) return;
    await _save(registry.copyWith(lastSelectedVaultId: id));
  }

  /// Appends [vault] and selects it.
  Future<void> add(Vault vault) async {
    final registry = await future;
    await _save(
      registry.copyWith(
        vaults: [...registry.vaults, vault],
        lastSelectedVaultId: vault.id,
      ),
    );
  }

  /// Replaces the vault with the same id.
  Future<void> update(Vault vault) async {
    final registry = await future;
    await _save(
      registry.copyWith(
        vaults: [
          for (final v in registry.vaults) v.id == vault.id ? vault : v,
        ],
      ),
    );
  }

  /// Forgets [id]: deletes its secrets and its app-private area, never the
  /// user's own files. Throws [StateError] for the last vault.
  Future<void> remove(String id) async {
    final registry = await future;
    if (registry.vaults.length <= 1) {
      throw StateError('The last vault cannot be removed.');
    }
    final vault = registry.byId(id);
    if (vault == null) return;

    if (vault.location case RemoteVaultLocation(:final secretNames)) {
      await ref.read(vaultSecretsProvider).deleteAll(id, secretNames);
    }
    final paths = await ref.read(appPathsProvider.future);
    final area = Directory(paths.privateAreaFor(id));
    if (await area.exists()) await area.delete(recursive: true);

    final remaining = registry.vaults.where((v) => v.id != id).toList();
    final selectedId = registry.selected?.id == id
        ? remaining.first.id
        : registry.lastSelectedVaultId;
    await _save(
      registry.copyWith(vaults: remaining, lastSelectedVaultId: selectedId),
    );
  }

  void dismissBrokenRegistryNotice() {
    final registry = state.value;
    if (registry == null) return;
    state = AsyncData(registry.copyWith(brokenRegistryFile: null));
  }

  Future<void> _save(VaultRegistry registry) async {
    final service = await ref.read(vaultRegistryServiceProvider.future);
    await service.save(registry);
    state = AsyncData(registry);
  }
}
```

`lib/src/providers/open_vault_provider.dart`:

```dart
import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../storage/vault_resolver.dart';
import '../sync/remote_store.dart';
import '../sync/sync_status.dart';
import 'app_paths_provider.dart';
import 'vaults_provider.dart';

part 'open_vault_provider.g.dart';

/// Remote kinds this build can open. Empty until a provider registers.
@Riverpod(keepAlive: true)
RemoteStoreRegistry remoteStoreRegistry(Ref ref) => RemoteStoreRegistry();

@Riverpod(keepAlive: true)
Future<VaultResolver> vaultResolver(Ref ref) async {
  final paths = await ref.watch(appPathsProvider.future);
  return VaultResolver(
    paths: paths,
    remoteStores: ref.watch(remoteStoreRegistryProvider),
    secrets: ref.watch(vaultSecretsProvider),
  );
}

/// Sync status of the open vault. Null for local vaults.
@Riverpod(keepAlive: true)
class CurrentSyncStatus extends _$CurrentSyncStatus {
  @override
  SyncStatus? build() => null;

  void set(SyncStatus? status) => state = status;
}

/// The selected vault, resolved. Re-resolves when the selection changes;
/// the outgoing remote vault gets a best-effort push first.
@Riverpod(keepAlive: true)
Future<OpenVault> openVault(Ref ref) async {
  final registry = await ref.watch(vaultsProvider.future);
  final vault = registry.selected;
  if (vault == null) throw StateError('No vault is configured.');

  final resolver = await ref.watch(vaultResolverProvider.future);
  final open = await resolver.open(
    vault,
    onStatus: (status) => ref.read(currentSyncStatusProvider.notifier).set(status),
  );
  ref.read(currentSyncStatusProvider.notifier).set(open.scheduler?.status);

  ref.onDispose(() {
    final scheduler = open.scheduler;
    if (scheduler != null) {
      unawaited(scheduler.flushBeforeSwitch().whenComplete(scheduler.dispose));
    }
  });

  unawaited(open.scheduler?.pullNow());
  return open;
}
```

`lib/src/providers/repository_provider.dart`, whole file:

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../storage/period_repository.dart';
import 'open_vault_provider.dart';

part 'repository_provider.g.dart';

/// The selected vault cannot be worked in. Carries the resolver's message.
class VaultUnavailable implements Exception {
  final String message;

  const VaultUnavailable(this.message);

  @override
  String toString() => message;
}

/// A [PeriodRepository] over the open vault. Rebuilds when the vault
/// changes; errors with [VaultUnavailable] when the vault cannot be opened,
/// so nothing ever runs against a placeholder folder.
@riverpod
Future<PeriodRepository> periodRepository(Ref ref) async {
  final open = await ref.watch(openVaultProvider.future);
  final workspace = open.workspace;
  if (workspace == null) {
    throw VaultUnavailable(open.accessError ?? 'The vault could not be opened.');
  }
  return PeriodRepository(workspace: workspace);
}
```

Consumers of `periodRepositoryProvider`, exact edits:

`lib/src/providers/all_periods_provider.dart`:
```dart
@riverpod
Future<PeriodLoadResult> periodLoadResult(Ref ref) async {
  final repo = await ref.watch(periodRepositoryProvider.future);
  return repo.loadAll();
}
```

`lib/src/providers/period_notifier_provider.dart`, in `build`:
```dart
    final repo = await ref.watch(periodRepositoryProvider.future);
```
and in `_debouncedSave`:
```dart
        final repo = await ref.read(periodRepositoryProvider.future);
```

`lib/src/providers/current_period_provider.dart`, in `build`, `setPeriod` and `_debouncedSave`, the same two substitutions (`ref.watch(...)` becomes `await ref.watch(periodRepositoryProvider.future)`, `ref.read(...)` becomes `await ref.read(periodRepositoryProvider.future)`).

`lib/src/providers/current_period_stats_sync_provider.dart`:
```dart
  final repo = await ref.watch(periodRepositoryProvider.future);
  final writer = PeriodStatsWriter(workspace: repo.workspace);
```

`lib/src/components/vault_banners.dart`:

```dart
import 'package:flutter/material.dart';

/// Explains why the selected vault cannot be opened. Rendered by Settings
/// and by the dashboard's unavailable view.
class VaultAccessBanner extends StatelessWidget {
  final String message;

  const VaultAccessBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

`lib/src/views/settings_view.dart`: remove the imports of `file_picker`, `storage_settings_provider`; add imports of `../components/vault_banners.dart`, `../providers/open_vault_provider.dart`, and `../models/models.dart` is already there. Replace line 26 with:

```dart
    final openVaultAsync = ref.watch(openVaultProvider);
```

Replace the whole "Data Storage" card (from `_SectionHeader(icon: Icons.folder_rounded, title: 'Data Storage')` through the `const SizedBox(height: 32),` that precedes the AI Insights header) with:

```dart
          _SectionHeader(icon: Icons.folder_rounded, title: 'Vault'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                width: 0.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                openVaultAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text(
                    'Error opening vault: $e',
                    style: TextStyle(color: colorScheme.error),
                  ),
                  data: (open) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        open.vault.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          switch (open.vault.location) {
                            LocalVaultLocation(:final path) => path,
                            RemoteVaultLocation(:final kind) => '$kind vault',
                          },
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontFamily: 'monospace',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (open.accessError != null) ...[
                        const SizedBox(height: 12),
                        VaultAccessBanner(message: open.accessError!),
                      ],
                    ],
                  ),
                ),
                if (loadFailures.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  PeriodLoadFailureList(failures: loadFailures),
                ],
                const SizedBox(height: 10),
                Text(
                  'A vault is a folder of period files. Switch or manage '
                  'vaults from the bottom of the sidebar.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
```

Delete `lib/src/storage/storage_settings_service.dart`, `lib/src/providers/storage_settings_provider.dart`, `lib/src/providers/storage_settings_provider.g.dart`, `test/storage_settings_service_test.dart`. `lib/src/storage/security_scoped_bookmarks.dart` stays (the resolver uses it). `shared_preferences` stays (AI stats toggle and legacy migration).

- [ ] **Step 4: Generate, test, analyze**

Run: `dart run build_runner build --delete-conflicting-outputs && flutter test && flutter analyze`
Expected: pass. Existing tests that override `periodRepositoryProvider.overrideWith((ref) => repo)` still compile because a sync return satisfies `FutureOr`.

- [ ] **Step 5: Commit**

```bash
git add -A lib test
git commit -m "feat: open the selected vault through providers and drop the old storage settings

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 12: Sidebar vault switcher and the dashboard's unavailable view

**Files:**
- Create: `lib/src/components/vault_switcher.dart`
- Modify: `lib/src/components/vault_banners.dart` (add `BrokenRegistryBanner`)
- Modify: `lib/src/views/app_shell.dart:9-10, 156-172`
- Modify: `lib/src/views/dashboard_view.dart:12-17, 48-58, 390-430`
- Create: `test/vault_switcher_test.dart`
- Create: `test/dashboard_vault_state_test.dart`

**Interfaces:**
- Consumes: `vaultsProvider`, `openVaultProvider`, `currentSyncStatusProvider`, `VaultUnavailable` (Task 11), `SyncStatus.describe` (Task 9), `FakeVaults` (Task 11 test helper).
- Produces:
  - `class VaultSwitcher extends ConsumerWidget { const VaultSwitcher({required VoidCallback onManage}); }` — a `PopupMenuButton<String>` whose items are vault ids plus the sentinel `VaultSwitcher.manageValue`
  - `class BrokenRegistryBanner extends StatelessWidget { const BrokenRegistryBanner({required String brokenFile, required VoidCallback onDismiss}); }`

- [ ] **Step 1: Write the failing widget tests**

`test/vault_switcher_test.dart`:

```dart
import 'package:flatplan/src/components/vault_switcher.dart';
import 'package:flatplan/src/models/models.dart';
import 'package:flatplan/src/providers/open_vault_provider.dart';
import 'package:flatplan/src/providers/vaults_provider.dart';
import 'package:flatplan/src/storage/vault_resolver.dart';
import 'package:flatplan/src/storage/vault_workspace.dart';
import 'package:flatplan/src/sync/sync_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'support/fake_vaults.dart';

void main() {
  final created = DateTime.utc(2026, 1, 1);
  final home = Vault(
    id: 'home',
    name: 'Home',
    location: const VaultLocation.local(path: '/home'),
    createdAt: created,
  );
  final work = Vault(
    id: 'work',
    name: 'Work',
    location: const VaultLocation.remote(kind: 'gitlab'),
    createdAt: created,
  );

  late FakeVaults fakeVaults;
  var manageTaps = 0;

  Widget app({
    required Vault selected,
    SyncStatus? status,
    String? accessError,
  }) {
    fakeVaults = FakeVaults(
      VaultRegistry(lastSelectedVaultId: selected.id, vaults: [home, work]),
    );
    return ProviderScope(
      overrides: [
        vaultsProvider.overrideWith(() => fakeVaults),
        openVaultProvider.overrideWith(
          (ref) async => OpenVault(
            vault: selected,
            workspace: accessError == null ? MemoryWorkspace() : null,
            accessError: accessError,
          ),
        ),
        currentSyncStatusProvider.overrideWith(() => _FixedStatus(status)),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 220,
            child: VaultSwitcher(onManage: () => manageTaps++),
          ),
        ),
      ),
    );
  }

  setUp(() => manageTaps = 0);

  testWidgets('shows the selected vault name', (tester) async {
    await tester.pumpWidget(app(selected: home));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.byIcon(Icons.unfold_more_rounded), findsOneWidget);
  });

  testWidgets('shows the sync status line for a remote vault', (tester) async {
    await tester.pumpWidget(app(
      selected: work,
      status: const SyncStatus(state: SyncState.idle, dirtyCount: 3),
    ));
    await tester.pumpAndSettle();

    expect(find.text('3 changes pending'), findsOneWidget);
  });

  testWidgets('shows a needs-attention line when the vault cannot open',
      (tester) async {
    await tester.pumpWidget(app(selected: home, accessError: 'nope'));
    await tester.pumpAndSettle();

    expect(find.text('Needs attention'), findsOneWidget);
  });

  testWidgets('menu lists every vault, checks the current one, and selects',
      (tester) async {
    await tester.pumpWidget(app(selected: home));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();

    expect(find.text('Work'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.text('Manage vaults…'), findsOneWidget);

    await tester.tap(find.text('Work'));
    await tester.pumpAndSettle();

    expect(fakeVaults.selected, ['work']);
  });

  testWidgets('Manage vaults… calls onManage', (tester) async {
    await tester.pumpWidget(app(selected: home));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manage vaults…'));
    await tester.pumpAndSettle();

    expect(manageTaps, 1);
    expect(fakeVaults.selected, isEmpty);
  });
}

class _FixedStatus extends CurrentSyncStatus {
  _FixedStatus(this.fixed);
  final SyncStatus? fixed;

  @override
  SyncStatus? build() => fixed;
}
```

`test/dashboard_vault_state_test.dart`:

```dart
import 'package:flatplan/src/models/models.dart';
import 'package:flatplan/src/providers/open_vault_provider.dart';
import 'package:flatplan/src/providers/repository_provider.dart';
import 'package:flatplan/src/providers/vaults_provider.dart';
import 'package:flatplan/src/storage/period_repository.dart';
import 'package:flatplan/src/storage/vault_resolver.dart';
import 'package:flatplan/src/storage/vault_workspace.dart';
import 'package:flatplan/src/views/dashboard_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'support/fake_vaults.dart';

void main() {
  final vault = Vault(
    id: 'v',
    name: 'Home',
    location: const VaultLocation.local(path: '/gone'),
    createdAt: DateTime.utc(2026, 1, 1),
  );

  testWidgets('an unavailable vault shows its error and a settings button',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vaultsProvider.overrideWith(
            () => FakeVaults(VaultRegistry(lastSelectedVaultId: 'v', vaults: [vault])),
          ),
          openVaultProvider.overrideWith(
            (ref) async => OpenVault(vault: vault, accessError: 'Folder is gone.'),
          ),
          periodRepositoryProvider.overrideWith(
            (ref) => throw const VaultUnavailable('Folder is gone.'),
          ),
        ],
        child: const MaterialApp(home: DashboardView()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Vault unavailable'), findsOneWidget);
    expect(find.text('Folder is gone.'), findsOneWidget);
    expect(find.text('Open vault settings'), findsOneWidget);
  });

  testWidgets('a broken registry shows a dismissible banner', (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final fake = FakeVaults(
      VaultRegistry(
        lastSelectedVaultId: 'v',
        vaults: [vault],
        brokenRegistryFile: '/support/vaults.json.broken',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vaultsProvider.overrideWith(() => fake),
          openVaultProvider.overrideWith(
            (ref) async => OpenVault(vault: vault, workspace: MemoryWorkspace()),
          ),
          periodRepositoryProvider.overrideWith(
            (ref) => PeriodRepository(workspace: MemoryWorkspace()),
          ),
        ],
        child: const MaterialApp(home: DashboardView()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('vaults.json.broken'), findsOneWidget);

    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();

    expect(find.textContaining('vaults.json.broken'), findsNothing);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/vault_switcher_test.dart test/dashboard_vault_state_test.dart`
Expected: compile error, `vault_switcher.dart` missing; dashboard test fails on missing texts.

- [ ] **Step 3: Write the switcher, the banner, and wire the shell and dashboard**

`lib/src/components/vault_switcher.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../models/models.dart';
import '../providers/open_vault_provider.dart';
import '../providers/vaults_provider.dart';

/// The sidebar footer control: current vault name, a status line, and a
/// menu to switch vaults or open the manage screen.
class VaultSwitcher extends ConsumerWidget {
  static const manageValue = '__manage__';

  final VoidCallback onManage;

  const VaultSwitcher({super.key, required this.onManage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final registry = ref.watch(vaultsProvider).value;
    final open = ref.watch(openVaultProvider).value;
    final status = ref.watch(currentSyncStatusProvider);

    final current = open?.vault ?? registry?.selected;
    if (current == null) return const SizedBox.shrink();

    final String? subtitle;
    final bool attention;
    if (open?.accessError != null) {
      subtitle = 'Needs attention';
      attention = true;
    } else if (current.location is RemoteVaultLocation && status != null) {
      subtitle = status.describe(DateTime.now());
      attention = false;
    } else {
      subtitle = null;
      attention = false;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: PopupMenuButton<String>(
          tooltip: 'Switch vault',
          position: PopupMenuPosition.over,
          onSelected: (value) {
            if (value == manageValue) {
              onManage();
            } else {
              ref.read(vaultsProvider.notifier).select(value);
            }
          },
          itemBuilder: (context) => [
            for (final vault in registry?.vaults ?? const <Vault>[])
              PopupMenuItem<String>(
                value: vault.id,
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      child: vault.id == current.id
                          ? Icon(
                              Icons.check_rounded,
                              size: 18,
                              color: colorScheme.primary,
                            )
                          : null,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(vault.name, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
            const PopupMenuDivider(),
            const PopupMenuItem<String>(
              value: manageValue,
              child: Text('Manage vaults…'),
            ),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        current.name,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: attention
                                ? colorScheme.error
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  Icons.unfold_more_rounded,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

Append to `lib/src/components/vault_banners.dart`:

```dart
/// Shown once on the dashboard after a corrupt `vaults.json` was moved
/// aside and a fresh registry created.
class BrokenRegistryBanner extends StatelessWidget {
  final String brokenFile;
  final VoidCallback onDismiss;

  const BrokenRegistryBanner({
    super.key,
    required this.brokenFile,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 20,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Your vault list could not be read. It was moved to '
              '$brokenFile and a fresh list was created. Your period files '
              'are untouched.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onErrorContainer,
              ),
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: onDismiss,
            style: TextButton.styleFrom(
              foregroundColor: colorScheme.onErrorContainer,
            ),
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
  }
}
```

`lib/src/views/app_shell.dart`: add `import '../components/vault_switcher.dart';` and replace the Settings item block (the `Padding(padding: const EdgeInsets.only(bottom: 16), child: _SidebarItem(... 'Settings' ...))`) with:

```dart
                // ─── Vault switcher + Settings (anchored to bottom) ───
                VaultSwitcher(onManage: () => context.go('/settings/vaults')),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _SidebarItem(
                    icon: Icons.settings_rounded,
                    label: 'Settings',
                    isSelected: selectedIndex == 1,
                    onTap: () => navigationShell.goBranch(
                      1,
                      initialLocation: selectedIndex == 1,
                    ),
                  ),
                ),
```

`lib/src/views/dashboard_view.dart`:

Add imports:
```dart
import '../components/vault_banners.dart';
import '../providers/open_vault_provider.dart';
import '../providers/repository_provider.dart';
import '../providers/vaults_provider.dart';
```

After the `loadFailures` declaration add:
```dart
    final openVault = ref.watch(openVaultProvider).value;
    final brokenRegistryFile = ref.watch(vaultsProvider).value?.brokenRegistryFile;
```

Change the `error:` branch of `periodAsync.when` to:
```dart
      error: (err, stack) => err is VaultUnavailable
          ? _buildVaultUnavailable(context, err.message, openVault?.vault.id)
          : Center(child: Text('Error: $err')),
```

In the `return Scaffold(body: Column(children: [...]))` at the end of `build` (currently `lib/src/views/dashboard_view.dart:373-385`), insert the broken-registry banner as the first child, above the existing `Padding` that holds `PeriodLoadBanner`:
```dart
          if (brokenRegistryFile != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: BrokenRegistryBanner(
                brokenFile: brokenRegistryFile,
                onDismiss: () => ref
                    .read(vaultsProvider.notifier)
                    .dismissBrokenRegistryNotice(),
              ),
            ),
```

Add next to `_buildEmptyState`:
```dart
  /// The selected vault cannot be opened. Explains why and points at the
  /// vault's settings; other vaults stay reachable from the sidebar.
  Widget _buildVaultUnavailable(
    BuildContext context,
    String message,
    String? vaultId,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: colorScheme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.folder_off_outlined,
                size: 40,
                color: colorScheme.error.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Vault unavailable',
              style: theme.textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            VaultAccessBanner(message: message),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => GoRouter.of(context).go(
                vaultId == null ? '/settings/vaults' : '/settings/vaults/$vaultId/edit',
              ),
              icon: const Icon(Icons.settings_rounded),
              label: const Text('Open vault settings'),
            ),
          ],
        ),
      ),
    );
  }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test && flutter analyze`
Expected: pass. In the dashboard test the settings button is rendered but not tapped, because there is no router in that test.

- [ ] **Step 5: Commit**

```bash
git add lib/src/components/vault_switcher.dart lib/src/components/vault_banners.dart lib/src/views/app_shell.dart lib/src/views/dashboard_view.dart test/vault_switcher_test.dart test/dashboard_vault_state_test.dart
git commit -m "feat: add the sidebar vault switcher and the vault-unavailable view

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 13: Vault kinds, the manage list, and its route

**Files:**
- Create: `lib/src/views/vault_kinds.dart`
- Create: `lib/src/views/vault_list_view.dart`
- Modify: `lib/src/routing/app_router.dart:72-78`
- Modify: `lib/src/views/settings_view.dart` (add the "Manage vaults" button under the vault card text)
- Create: `test/vault_list_view_test.dart`

**Interfaces:**
- Consumes: `vaultsProvider`, `openVaultProvider`, `currentSyncStatusProvider`, `FakeVaults`.
- Produces:
  - `class VaultKindDescriptor { const VaultKindDescriptor({required String kind, required String label, required IconData icon, required String Function(Vault) locationLine}); }`
  - `const localVaultKind`, `VaultKindDescriptor unsupportedVaultKind(String kind)`, `List<VaultKindDescriptor> get vaultKinds`, `VaultKindDescriptor vaultKindFor(Vault vault)`
  - `class VaultListView extends ConsumerWidget`
  - Route `/settings/vaults`

- [ ] **Step 1: Write the failing tests**

`test/vault_list_view_test.dart`:

```dart
import 'package:flatplan/src/models/models.dart';
import 'package:flatplan/src/providers/open_vault_provider.dart';
import 'package:flatplan/src/providers/vaults_provider.dart';
import 'package:flatplan/src/storage/vault_resolver.dart';
import 'package:flatplan/src/storage/vault_workspace.dart';
import 'package:flatplan/src/views/vault_kinds.dart';
import 'package:flatplan/src/views/vault_list_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'support/fake_vaults.dart';

void main() {
  final created = DateTime.utc(2026, 1, 1);
  final home = Vault(
    id: 'home',
    name: 'Home',
    location: const VaultLocation.local(path: '/Users/me/budget'),
    createdAt: created,
  );
  final future = Vault(
    id: 'f',
    name: 'Future',
    location: const VaultLocation.remote(kind: 'teleport'),
    createdAt: created,
  );

  late FakeVaults fakeVaults;

  Widget app(List<Vault> vaults, {String? accessError}) {
    fakeVaults = FakeVaults(
      VaultRegistry(lastSelectedVaultId: vaults.first.id, vaults: vaults),
    );
    return ProviderScope(
      overrides: [
        vaultsProvider.overrideWith(() => fakeVaults),
        openVaultProvider.overrideWith(
          (ref) async => OpenVault(
            vault: vaults.first,
            workspace: accessError == null ? MemoryWorkspace() : null,
            accessError: accessError,
          ),
        ),
      ],
      child: const MaterialApp(home: VaultListView()),
    );
  }

  test('vaultKindFor describes local, and unknown remote kinds', () {
    expect(vaultKindFor(home).label, 'Local folder');
    expect(vaultKindFor(home).locationLine(home), '/Users/me/budget');
    expect(vaultKindFor(future).label, 'Unsupported (teleport)');
  });

  testWidgets('lists vaults with location, current chip and kind', (tester) async {
    await tester.pumpWidget(app([home, future]));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('/Users/me/budget'), findsOneWidget);
    expect(find.text('Current'), findsOneWidget);
    expect(find.text('Future'), findsOneWidget);
    expect(find.textContaining('not supported'), findsOneWidget);
    expect(find.text('New vault'), findsOneWidget);
  });

  testWidgets('shows a needs-attention chip when the current vault cannot open',
      (tester) async {
    await tester.pumpWidget(app([home, future], accessError: 'gone'));
    await tester.pumpAndSettle();

    expect(find.text('Needs attention'), findsOneWidget);
  });

  testWidgets('remove asks for confirmation and forgets the vault', (tester) async {
    await tester.pumpWidget(app([home, future]));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert_rounded).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(find.text('Remove "Future"?'), findsOneWidget);
    expect(find.textContaining('not deleted'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();

    expect(fakeVaults.removed, ['f']);
  });

  testWidgets('the last vault cannot be removed', (tester) async {
    await tester.pumpWidget(app([home]));
    await tester.pumpAndSettle();

    expect(find.text('The last vault cannot be removed.'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();

    final item = tester.widget<PopupMenuItem<String>>(
      find.widgetWithText(PopupMenuItem<String>, 'Remove'),
    );
    expect(item.enabled, isFalse);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/vault_list_view_test.dart`
Expected: compile errors, files missing.

- [ ] **Step 3: Write the kinds, the list view, the route, and the Settings button**

`lib/src/views/vault_kinds.dart`:

```dart
import 'package:flutter/material.dart';

import '../models/models.dart';

/// How the UI presents one kind of vault. A provider spec adds one of
/// these (and a form) and nothing else in the UI changes.
class VaultKindDescriptor {
  /// `local`, or a remote kind such as `gitlab`.
  final String kind;
  final String label;
  final IconData icon;

  /// One line describing where a vault of this kind lives.
  final String Function(Vault vault) locationLine;

  const VaultKindDescriptor({
    required this.kind,
    required this.label,
    required this.icon,
    required this.locationLine,
  });
}

String _localPath(Vault vault) => switch (vault.location) {
  LocalVaultLocation(:final path) => path,
  RemoteVaultLocation() => '',
};

const localVaultKind = VaultKindDescriptor(
  kind: 'local',
  label: 'Local folder',
  icon: Icons.folder_rounded,
  locationLine: _localPath,
);

/// A remote kind this build does not know.
VaultKindDescriptor unsupportedVaultKind(String kind) => VaultKindDescriptor(
  kind: kind,
  label: 'Unsupported ($kind)',
  icon: Icons.cloud_off_rounded,
  locationLine: (_) => 'This vault type is not supported in this version.',
);

/// Kinds a user can create. Providers append to this list.
List<VaultKindDescriptor> get vaultKinds => const [localVaultKind];

VaultKindDescriptor vaultKindFor(Vault vault) => switch (vault.location) {
  LocalVaultLocation() => localVaultKind,
  RemoteVaultLocation(:final kind) =>
    vaultKinds.where((d) => d.kind == kind).firstOrNull ??
        unsupportedVaultKind(kind),
};
```

`lib/src/views/vault_list_view.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../models/models.dart';
import '../providers/open_vault_provider.dart';
import '../providers/vaults_provider.dart';
import 'vault_kinds.dart';

/// `/settings/vaults`: every vault, with edit, remove and sync actions.
class VaultListView extends ConsumerWidget {
  const VaultListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final registry = ref.watch(vaultsProvider).value;
    final open = ref.watch(openVaultProvider).value;
    final status = ref.watch(currentSyncStatusProvider);
    final vaults = registry?.vaults ?? const <Vault>[];
    final canRemove = vaults.length > 1;

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(32),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 28),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Vaults',
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => context.go('/settings/vaults/new'),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('New vault'),
                ),
              ],
            ),
          ),
          for (final vault in vaults) ...[
            _VaultCard(
              vault: vault,
              isCurrent: vault.id == open?.vault.id,
              accessError: vault.id == open?.vault.id ? open?.accessError : null,
              statusLine: vault.id == open?.vault.id &&
                      vault.location is RemoteVaultLocation
                  ? status?.describe(DateTime.now())
                  : null,
              canSyncNow: vault.id == open?.vault.id && open?.scheduler != null,
              canRemove: canRemove,
              onSyncNow: () => open?.scheduler?.syncNow(),
              onEdit: () => context.go('/settings/vaults/${vault.id}/edit'),
              onRemove: () => _confirmRemove(context, ref, vault),
            ),
            const SizedBox(height: 12),
          ],
          if (!canRemove)
            Text(
              'The last vault cannot be removed.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    Vault vault,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove "${vault.name}"?'),
        content: const Text(
          'FlatPlan will forget this vault. Your files are not deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(vaultsProvider.notifier).remove(vault.id);
    }
  }
}

class _VaultCard extends StatelessWidget {
  final Vault vault;
  final bool isCurrent;
  final String? accessError;
  final String? statusLine;
  final bool canSyncNow;
  final bool canRemove;
  final VoidCallback onSyncNow;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  const _VaultCard({
    required this.vault,
    required this.isCurrent,
    required this.accessError,
    required this.statusLine,
    required this.canSyncNow,
    required this.canRemove,
    required this.onSyncNow,
    required this.onEdit,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final kind = vaultKindFor(vault);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(kind.icon, color: colorScheme.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        vault.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCurrent) ...[
                      const SizedBox(width: 8),
                      _Chip(label: 'Current', color: colorScheme.primary),
                    ],
                    if (accessError != null) ...[
                      const SizedBox(width: 8),
                      _Chip(label: 'Needs attention', color: colorScheme.error),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  kind.locationLine(vault),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontFamily: 'monospace',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (statusLine != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    statusLine!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (canSyncNow)
            TextButton.icon(
              onPressed: onSyncNow,
              icon: const Icon(Icons.sync_rounded, size: 18),
              label: const Text('Sync now'),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) => value == 'edit' ? onEdit() : onRemove(),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(
                value: 'remove',
                enabled: canRemove,
                child: const Text('Remove'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}
```

`lib/src/routing/app_router.dart`: import `../views/vault_list_view.dart` and replace the Settings branch route with:

```dart
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsView(),
                routes: [
                  GoRoute(
                    path: 'vaults',
                    builder: (context, state) => const VaultListView(),
                  ),
                ],
              ),
```

`lib/src/views/settings_view.dart`: add `import 'package:go_router/go_router.dart';` and, directly after the `Text('A vault is a folder of period files. ...')` inside the vault card, add:

```dart
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => context.go('/settings/vaults'),
                    icon: const Icon(Icons.inventory_2_outlined, size: 18),
                    label: const Text('Manage vaults'),
                  ),
                ),
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test && flutter analyze`
Expected: pass.

- [ ] **Step 5: Commit**

```bash
git add lib/src/views/vault_kinds.dart lib/src/views/vault_list_view.dart lib/src/routing/app_router.dart lib/src/views/settings_view.dart test/vault_list_view_test.dart
git commit -m "feat: add the vault manage list at /settings/vaults

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 14: The vault form with the local-folder kind

**Files:**
- Create: `lib/src/views/vault_form_view.dart`
- Modify: `lib/src/views/vault_kinds.dart` (add `buildForm` to the descriptor)
- Modify: `lib/src/routing/app_router.dart` (add `new` and `:id/edit` under `vaults`)
- Create: `test/vault_form_view_test.dart`

**Interfaces:**
- Consumes: `vaultsProvider`, `appPathsProvider`, `vaultResolverProvider` (Task 11), `FakeVaults`, `file_picker`.
- Produces:
  - `VaultKindDescriptor` gains `final Widget Function(BuildContext context, Vault? existing) buildForm;`
  - `class VaultFormView extends ConsumerWidget { const VaultFormView({String? vaultId}); }`
  - `class LocalVaultForm extends HookConsumerWidget { const LocalVaultForm({Vault? existing, bool? canPickFolder}); }` — `canPickFolder` defaults to `Platform.isMacOS || Platform.isWindows || Platform.isLinux`
  - Routes `/settings/vaults/new`, `/settings/vaults/:id/edit`

- [ ] **Step 1: Write the failing tests**

`test/vault_form_view_test.dart`:

```dart
import 'package:flatplan/src/models/models.dart';
import 'package:flatplan/src/providers/app_paths_provider.dart';
import 'package:flatplan/src/providers/open_vault_provider.dart';
import 'package:flatplan/src/providers/vaults_provider.dart';
import 'package:flatplan/src/storage/app_paths.dart';
import 'package:flatplan/src/storage/vault_resolver.dart';
import 'package:flatplan/src/storage/vault_secrets.dart';
import 'package:flatplan/src/sync/remote_store.dart';
import 'package:flatplan/src/views/vault_form_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'support/fake_vaults.dart';

void main() {
  const paths = AppPaths(appSupportDir: '/support');
  final created = DateTime.utc(2026, 1, 1);
  final home = Vault(
    id: 'home',
    name: 'Home',
    location: const VaultLocation.local(path: '/Users/me/budget'),
    createdAt: created,
  );

  late FakeVaults fakeVaults;

  Widget app(Widget child, {List<Vault>? vaults}) {
    fakeVaults = FakeVaults(
      VaultRegistry(lastSelectedVaultId: 'home', vaults: vaults ?? [home]),
    );
    return ProviderScope(
      overrides: [
        vaultsProvider.overrideWith(() => fakeVaults),
        appPathsProvider.overrideWith((ref) async => paths),
        vaultResolverProvider.overrideWith(
          (ref) async => VaultResolver(
            paths: paths,
            remoteStores: RemoteStoreRegistry(),
            secrets: MemoryVaultSecrets(),
            useBookmarks: false,
          ),
        ),
      ],
      child: MaterialApp(home: child),
    );
  }

  testWidgets('on mobile the folder row is absent and the vault is app-private',
      (tester) async {
    await tester.pumpWidget(app(const LocalVaultForm(canPickFolder: false)));
    await tester.pumpAndSettle();

    expect(find.text('Choose folder…'), findsNothing);
    expect(find.textContaining('stored inside the app'), findsOneWidget);
  });

  testWidgets('on desktop the folder row is present', (tester) async {
    await tester.pumpWidget(app(const LocalVaultForm(canPickFolder: true)));
    await tester.pumpAndSettle();

    expect(find.text('Choose folder…'), findsOneWidget);
  });

  testWidgets('saving requires a name', (tester) async {
    await tester.pumpWidget(app(const LocalVaultForm(canPickFolder: false)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create vault'));
    await tester.pumpAndSettle();

    expect(find.text('Give the vault a name.'), findsOneWidget);
    expect(fakeVaults.added, isEmpty);
  });

  testWidgets('creating without a folder puts the vault in the private area',
      (tester) async {
    await tester.pumpWidget(app(const LocalVaultForm(canPickFolder: true)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Travel');
    await tester.tap(find.text('Create vault'));
    await tester.pumpAndSettle();

    final added = fakeVaults.added.single;
    expect(added.name, 'Travel');
    expect(added.location, VaultLocation.local(path: paths.mirrorFor(added.id)));
  });

  testWidgets('editing renames and keeps the folder', (tester) async {
    await tester.pumpWidget(app(LocalVaultForm(existing: home, canPickFolder: true)));
    await tester.pumpAndSettle();

    expect(find.text('/Users/me/budget'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Household');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final updated = fakeVaults.updated.single;
    expect(updated.id, 'home');
    expect(updated.name, 'Household');
    expect(updated.location, home.location);
  });

  testWidgets('VaultFormView opens the local form directly for a new vault',
      (tester) async {
    await tester.pumpWidget(app(const VaultFormView()));
    await tester.pumpAndSettle();

    expect(find.text('New vault'), findsOneWidget);
    expect(find.byType(LocalVaultForm), findsOneWidget);
  });

  testWidgets('VaultFormView edits an existing vault by id', (tester) async {
    await tester.pumpWidget(app(const VaultFormView(vaultId: 'home')));
    await tester.pumpAndSettle();

    expect(find.text('Edit vault'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('VaultFormView explains an unsupported remote kind', (tester) async {
    final future = Vault(
      id: 'f',
      name: 'Future',
      location: const VaultLocation.remote(kind: 'teleport'),
      createdAt: created,
    );
    await tester.pumpWidget(
      app(const VaultFormView(vaultId: 'f'), vaults: [home, future]),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('not supported in this version'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/vault_form_view_test.dart`
Expected: compile error, `vault_form_view.dart` missing.

- [ ] **Step 3: Write the form, extend the descriptor, add the routes**

`lib/src/views/vault_kinds.dart`: add the import `import 'vault_form_view.dart';`, the field and constructor parameter `required this.buildForm` of type `Widget Function(BuildContext context, Vault? existing)`, and set:

```dart
const localVaultKind = VaultKindDescriptor(
  kind: 'local',
  label: 'Local folder',
  icon: Icons.folder_rounded,
  locationLine: _localPath,
  buildForm: _localForm,
);

Widget _localForm(BuildContext context, Vault? existing) =>
    LocalVaultForm(existing: existing);
```

and in `unsupportedVaultKind`:

```dart
  buildForm: (context, existing) => const UnsupportedVaultNotice(),
```

`lib/src/views/vault_form_view.dart`:

```dart
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import '../providers/app_paths_provider.dart';
import '../providers/open_vault_provider.dart';
import '../providers/vaults_provider.dart';
import 'vault_kinds.dart';

/// `/settings/vaults/new` and `/settings/vaults/:id/edit`.
///
/// With one registered kind the chooser is skipped and the form opens
/// directly; the chooser appears once a second kind exists.
class VaultFormView extends ConsumerWidget {
  final String? vaultId;

  const VaultFormView({super.key, this.vaultId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final registry = ref.watch(vaultsProvider).value;
    final existing = vaultId == null ? null : registry?.byId(vaultId!);

    if (vaultId != null && registry != null && existing == null) {
      return const Scaffold(body: Center(child: Text('This vault no longer exists.')));
    }

    final Widget body;
    if (existing != null) {
      body = vaultKindFor(existing).buildForm(context, existing);
    } else if (vaultKinds.length == 1) {
      body = vaultKinds.single.buildForm(context, null);
    } else {
      body = _KindChooser(kinds: vaultKinds);
    }

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(32),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 28),
            child: Text(
              existing == null ? 'New vault' : 'Edit vault',
              style: theme.textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                width: 0.5,
              ),
            ),
            child: body,
          ),
        ],
      ),
    );
  }
}

class _KindChooser extends StatefulWidget {
  final List<VaultKindDescriptor> kinds;

  const _KindChooser({required this.kinds});

  @override
  State<_KindChooser> createState() => _KindChooserState();
}

class _KindChooserState extends State<_KindChooser> {
  VaultKindDescriptor? _chosen;

  @override
  Widget build(BuildContext context) {
    final chosen = _chosen;
    if (chosen != null) return chosen.buildForm(context, null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final kind in widget.kinds)
          ListTile(
            leading: Icon(kind.icon),
            title: Text(kind.label),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onTap: () => setState(() => _chosen = kind),
          ),
      ],
    );
  }
}

/// Shown in place of a form for a remote kind this build does not know.
class UnsupportedVaultNotice extends StatelessWidget {
  const UnsupportedVaultNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text(
      'This vault type is not supported in this version. '
      'Update FlatPlan to open it.',
    );
  }
}

/// Name plus, on desktop, an optional folder. Without a folder the vault
/// lives inside the app's private area.
class LocalVaultForm extends HookConsumerWidget {
  final Vault? existing;

  /// Whether a folder can be picked here. Defaults to the desktop
  /// platforms, where `file_picker` returns a readable path.
  final bool? canPickFolder;

  const LocalVaultForm({super.key, this.existing, this.canPickFolder});

  static bool get _desktop =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final pickFolder = canPickFolder ?? _desktop;
    final existingLocation = existing?.location as LocalVaultLocation?;
    final name = useTextEditingController(text: existing?.name ?? '');
    final pickedPath = useState<String?>(existingLocation?.path);
    final pickedBookmark = useState<String?>(existingLocation?.bookmark);
    final nameError = useState<String?>(null);
    final saving = useState(false);

    Future<void> choose() async {
      final picked = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select vault folder',
      );
      if (picked == null) return;
      final resolver = await ref.read(vaultResolverProvider.future);
      pickedBookmark.value = await resolver.bookmarkFor(picked);
      pickedPath.value = picked;
    }

    Future<void> save() async {
      final trimmed = name.text.trim();
      if (trimmed.isEmpty) {
        nameError.value = 'Give the vault a name.';
        return;
      }
      saving.value = true;
      final id = existing?.id ?? const Uuid().v4();
      final paths = await ref.read(appPathsProvider.future);
      final vault = Vault(
        id: id,
        name: trimmed,
        location: VaultLocation.local(
          path: pickedPath.value ?? paths.mirrorFor(id),
          bookmark: pickedBookmark.value,
        ),
        createdAt: existing?.createdAt ?? DateTime.now(),
      );
      final vaults = ref.read(vaultsProvider.notifier);
      if (existing == null) {
        await vaults.add(vault);
      } else {
        await vaults.update(vault);
      }
      if (!context.mounted) return;
      final navigator = Navigator.of(context);
      if (navigator.canPop()) navigator.pop();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: name,
          decoration: InputDecoration(
            labelText: 'Name',
            errorText: nameError.value,
          ),
          onChanged: (_) => nameError.value = null,
        ),
        const SizedBox(height: 20),
        if (pickFolder) ...[
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    pickedPath.value ?? 'Stored inside the app until you choose a folder.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontFamily: pickedPath.value == null ? null : 'monospace',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: choose,
                icon: const Icon(Icons.folder_open_rounded),
                label: const Text('Choose folder…'),
              ),
            ],
          ),
        ] else
          Text(
            'This vault is stored inside the app on this device.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: saving.value ? null : save,
            child: Text(existing == null ? 'Create vault' : 'Save'),
          ),
        ),
      ],
    );
  }
}
```

`lib/src/routing/app_router.dart`: import `../views/vault_form_view.dart` and nest under the `vaults` route:

```dart
                  GoRoute(
                    path: 'vaults',
                    builder: (context, state) => const VaultListView(),
                    routes: [
                      GoRoute(
                        path: 'new',
                        builder: (context, state) => const VaultFormView(),
                      ),
                      GoRoute(
                        path: ':id/edit',
                        builder: (context, state) => VaultFormView(
                          vaultId: state.pathParameters['id'],
                        ),
                      ),
                    ],
                  ),
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test && flutter analyze`
Expected: pass. If the analyzer flags the `Vault?` cast in `existingLocation`, replace it with `existing?.location is LocalVaultLocation ? existing!.location as LocalVaultLocation : null`.

- [ ] **Step 5: Commit**

```bash
git add lib/src/views/vault_form_view.dart lib/src/views/vault_kinds.dart lib/src/routing/app_router.dart test/vault_form_view_test.dart
git commit -m "feat: add the vault form with the local-folder kind

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 15: Push when the app goes to the background

**Files:**
- Create: `lib/src/components/sync_lifecycle_bridge.dart`
- Modify: `lib/main.dart:18-25`
- Create: `test/sync_lifecycle_bridge_test.dart`

**Interfaces:**
- Consumes: `openVaultProvider` (Task 11), `SyncScheduler.onAppPaused` (Task 9).
- Produces: `class SyncLifecycleBridge extends ConsumerStatefulWidget { const SyncLifecycleBridge({required Widget child}); }`

- [ ] **Step 1: Write the failing test**

`test/sync_lifecycle_bridge_test.dart`:

```dart
import 'package:flatplan/src/components/sync_lifecycle_bridge.dart';
import 'package:flatplan/src/models/models.dart';
import 'package:flatplan/src/providers/open_vault_provider.dart';
import 'package:flatplan/src/storage/vault_resolver.dart';
import 'package:flatplan/src/storage/vault_workspace.dart';
import 'package:flatplan/src/sync/conflict_policy.dart';
import 'package:flatplan/src/sync/sync_engine.dart';
import 'package:flatplan/src/sync/sync_journal.dart';
import 'package:flatplan/src/sync/sync_scheduler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'sync/in_memory_remote_store.dart';

void main() {
  testWidgets('pausing the app pushes pending changes', (tester) async {
    final files = <String, String>{};
    final journal = SyncJournal();
    final remote = InMemoryRemoteStore();
    final scheduler = SyncScheduler(
      engine: SyncEngine(
        mirror: MemoryWorkspace(files: files),
        remote: remote,
        journal: journal,
        policy: periodConflictPolicy,
      ),
      onStatus: (_) {},
      idleDelay: const Duration(hours: 1),
    );
    journal.onDirty = scheduler.noteChange;
    final workspace = MemoryWorkspace(files: files, changeListener: journal);
    final vault = Vault(
      id: 'r',
      name: 'Remote',
      location: const VaultLocation.remote(kind: 'memory'),
      createdAt: DateTime.utc(2026, 1, 1),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          openVaultProvider.overrideWith(
            (ref) async => OpenVault(
              vault: vault,
              workspace: workspace,
              scheduler: scheduler,
            ),
          ),
        ],
        child: const MaterialApp(
          home: SyncLifecycleBridge(child: SizedBox()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await workspace.writeString('a.yaml', 'a');
    expect(remote.files, isEmpty);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();

    expect(remote.files.keys, ['a.yaml']);
    scheduler.dispose();
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/sync_lifecycle_bridge_test.dart`
Expected: compile error, file missing.

- [ ] **Step 3: Write the bridge and mount it**

`lib/src/components/sync_lifecycle_bridge.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../providers/open_vault_provider.dart';

/// Pushes the open remote vault when the app goes to the background, the
/// moment Android may kill it. Local vaults have no scheduler and are
/// unaffected. Also keeps [openVaultProvider] alive for the app's lifetime.
class SyncLifecycleBridge extends ConsumerStatefulWidget {
  final Widget child;

  const SyncLifecycleBridge({super.key, required this.child});

  @override
  ConsumerState<SyncLifecycleBridge> createState() => _SyncLifecycleBridgeState();
}

class _SyncLifecycleBridgeState extends ConsumerState<SyncLifecycleBridge> {
  late final AppLifecycleListener _listener;

  @override
  void initState() {
    super.initState();
    _listener = AppLifecycleListener(onPause: _onPause);
  }

  void _onPause() {
    final open = ref.read(openVaultProvider).value;
    open?.scheduler?.onAppPaused();
  }

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(openVaultProvider);
    return widget.child;
  }
}
```

`lib/main.dart`: import `src/components/sync_lifecycle_bridge.dart` and add to `MaterialApp.router`:

```dart
      builder: (context, child) => SyncLifecycleBridge(child: child!),
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test && flutter analyze`
Expected: pass.

- [ ] **Step 5: Commit**

```bash
git add lib/src/components/sync_lifecycle_bridge.dart lib/main.dart test/sync_lifecycle_bridge_test.dart
git commit -m "feat: push pending vault changes when the app is paused

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 16: Documentation: README, AGENTS.md, CHANGELOG, architecture note, spec deviations

**Files:**
- Modify: `README.md:7, 21-28, 59-67`
- Modify: `AGENTS.md` (Application Overview, decision 3, Key Architecture storage/providers lines)
- Modify: `CHANGELOG.md:9-14`
- Modify: `doc/02_architecture.md:14-15, 35`
- Modify: `docs/superpowers/specs/2026-09-16-vaults-and-storage-abstraction-design.md` (section 8 and a new "Implementation notes" section)

- [ ] **Step 1: README**

Replace line 7 with:

```markdown
> Your financial planning in "flat" files. Simple, private, and fully under your control.
```

Replace the section from `## 🏛️ The "Local-First" Philosophy` through item 4 with:

```markdown
## 🏛️ Your Data, Your Storage

Flatplan is built on a few key principles:

1.  **💻 You Own Your Data.** Your budget lives in plain files in a place you choose: a folder on your device, or your own private storage such as a Git repository, a WebDAV server, or an S3 bucket. FlatPlan runs no server of its own and never sees your data.
2.  **✨ Total Transparency:** By using YAML, you can view (and even edit) your data in a plain text editor at any time.
3.  **🔄 Sync Freedom.** Keep it local and sync with **Git**, **Syncthing** or **Dropbox** as you do today, or point FlatPlan straight at your private storage. Remote vaults are on the roadmap; local folders work now.
4.  **🔒 Private by Default:** The app requires no registration, does not connect to your bank accounts, and sends no "anonymous" telemetry.
```

In "How It Works (Storage Concept)" replace the first line with:

```markdown
Flatplan doesn't use a database. Your entire setup lives in a **vault**: a named folder of period files. Keep several vaults (home, a side project, a shared household) and switch between them from the sidebar.
```

- [ ] **Step 2: AGENTS.md**

Replace the first sentence of "Application Overview" with:

```markdown
FlatPlan is a Flutter budget-tracking app (desktop today, mobile planned) storing periods as YAML files inside named **vaults**.
```

Replace decision 3 with:

```markdown
3. **Storage**: domain code writes through `VaultWorkspace` (`lib/src/storage/vault_workspace.dart`), never `dart:io` directly. `PeriodRepository` handles YAML with recursive key-sorting via `SplayTreeMap` and `json2yaml`. Vaults are named in `<app support>/vaults.json` (`VaultRegistryService`) and opened by `VaultResolver`. Remote vaults work on an app-private mirror moved by `lib/src/sync/` (`SyncEngine`, `SyncJournal`, `SyncScheduler`, `RemoteStore`); no real remote provider is registered yet. Design: `docs/superpowers/specs/2026-09-16-vaults-and-storage-abstraction-design.md`.
```

Replace the `lib/src/storage/` and `lib/src/providers/` lines in "Key Architecture" with:

```markdown
- `lib/src/storage/` — `VaultWorkspace` (+ `DirectoryWorkspace`, `MemoryWorkspace`), `PeriodRepository`, `PeriodStatsWriter`, `AppPaths`, `VaultRegistryService`, `VaultSecrets`, `VaultResolver`, macOS security-scoped bookmarks
- `lib/src/sync/` — provider-independent sync: `RemoteStore` contract, `SyncJournal`, `ConflictPolicy` (newest `last_modified` wins, loser kept as `<name>.conflict-<stamp>`), `SyncEngine`, `SyncScheduler`, `SyncStatus`
- `lib/src/providers/` — Riverpod providers binding storage to logic: `appPathsProvider`, `vaultsProvider` (registry), `openVaultProvider`, `currentSyncStatusProvider`, `periodRepositoryProvider` (async, errors with `VaultUnavailable`), `currentPeriodProvider`, `periodProvider`, `allPeriodsProvider`, `periodStatsProvider`, `currentPeriodStatsSyncProvider`, and the settings providers
```

Add to the `lib/src/views/` line: `VaultListView`, `VaultFormView`; to `lib/src/components/`: `VaultSwitcher`, `VaultAccessBanner`, `BrokenRegistryBanner`, `SyncLifecycleBridge`.

- [ ] **Step 3: CHANGELOG**

Under `## [Unreleased]`, above `### Planned`, add:

```markdown
### Added
- Vaults: keep several named folders of period files and switch between them from the sidebar. Manage them under Settings → Vaults. The existing folder becomes the first vault automatically.
- Storage abstraction and a sync engine (local mirror, persisted change journal, newest-wins conflict handling with side files) preparing for remote vaults on GitLab, GitHub, WebDAV, S3 and Google Drive.

### Changed
- "Change Folder" and "Reset to default folder" moved into the vault's edit form.
```

- [ ] **Step 4: Architecture doc**

In `doc/02_architecture.md` replace the `path_provider` bullet with:

```markdown
  - `path_provider`: resolves the application support directory, which holds `vaults.json` and each vault's app-private area. Domain code never touches paths; it writes through `VaultWorkspace`.
```

and the "root directory" bullet (line 35) with:

```markdown
- User keeps one or more **vaults**. A local vault is a folder (which they can independently initialize as a git repository). A remote vault is mirrored locally and synced by the engine in `lib/src/sync/`.
```

- [ ] **Step 5: Spec deviations**

In the spec, section 8 "File map", replace `pubspec.yaml (adds flutter_secure_storage)` with `pubspec.yaml (adds crypto)`, and append this section before "9. Follow-ups":

```markdown
## Implementation notes

Decided while planning, see `docs/superpowers/plans/2026-09-16-vaults-and-storage-abstraction.md`:

- `flutter_secure_storage` is deferred to the first remote provider, the first code that stores a secret. `VaultSecrets` is the interface; `MemoryVaultSecrets` is the only implementation for now.
- Sync status is tracked for the open vault only.
- When the selected vault cannot be opened, the dashboard shows a dedicated "Vault unavailable" view with a button to the vault's edit form.
- `periodRepositoryProvider` is a `Future` provider that errors with `VaultUnavailable`, so nothing runs against a placeholder folder while the vault resolves.
- The push before switching vaults runs from `openVaultProvider`'s dispose hook, in the background, with the 5 s timeout.
- A corrupt `sync.json` makes the engine treat every mirror file as dirty on the next pull, so a lost baseline can never cause local edits to be overwritten silently.
```

- [ ] **Step 6: Verify and commit**

Run: `flutter test && flutter analyze`
Expected: pass (docs only, but confirm nothing regressed).

```bash
git add README.md AGENTS.md CHANGELOG.md doc/02_architecture.md docs/superpowers/specs/2026-09-16-vaults-and-storage-abstraction-design.md
git commit -m "docs: describe vaults and the storage abstraction

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

## Final verification

- [ ] `flutter test` green, `flutter analyze` clean, `dart run build_runner build --delete-conflicting-outputs` produces no diff.
- [ ] Manual run on macOS (`flutter run -d macos`): the existing folder appears as the first vault, selected. Create a second local vault without a folder, add a period, switch back and forth from the sidebar, remove the second vault, confirm the first vault's files are untouched and `<app support>/vaults/<id>/` is gone.
- [ ] Manual run: pick a folder, quit, relaunch, confirm the bookmark still opens it. Rename the folder on disk, relaunch, confirm the "Vault unavailable" view and the "Needs attention" line in the switcher.
