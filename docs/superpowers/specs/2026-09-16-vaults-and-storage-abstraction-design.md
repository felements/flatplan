# Vaults and the storage abstraction

Date: 2026-09-16
Status: approved design, awaiting implementation plan

## Summary

FlatPlan today reads and writes one folder of period YAML files through
absolute paths and `dart:io`. This design introduces **vaults**: named
places that hold one set of period files, managed Obsidian-style from the
sidebar. It also introduces the abstraction that lets a vault live somewhere
other than a local folder, so that GitLab, GitHub, WebDAV, S3 and Google
Drive can each be added later as a thin adapter.

This spec ships:

- the vault model, registry, and migration of the current configuration
- a `VaultWorkspace` interface that the period repository writes through
- a `SyncEngine` with a persisted journal, conflict policy, and recovery,
  tested against an in-memory remote
- the vault switcher and manage screens, with one vault kind: local folder
- a README rewording

It does **not** ship any real remote provider, the Android platform target,
or a responsive layout. Each is a follow-up spec.

## Decisions already made

These were settled in brainstorming and are not re-opened here.

| Question | Decision | Why |
|---|---|---|
| How does the app relate to a remote vault? | **Local mirror + sync.** The app only ever touches a local folder. A sync engine moves files to and from the provider. | Works offline on a phone. A vault is a dozen small YAML files, so a full mirror costs nothing. No git on the device, the mirror is a snapshot with no history. |
| What happens when both sides changed the same file? | **Newest `last_modified` wins, loser kept as a side file.** | Never destroys data, needs no dialog, keeps the "your data is plain files" promise. A per-file chooser can be layered on later. |
| Filesystem abstraction or store abstraction for remotes? | **Filesystem interface for the local side only (`VaultWorkspace`). Version-aware store for the remote side (`RemoteStore`).** | Remotes are not filesystems: they have versions, atomic batches, auth. With a mirror, only the sync engine calls the remote, and it needs exactly "list tree with versions" and "write a batch". |
| Where does the manage UI live? | **Routes inside the shell**, not a dialog. | Deep-linkable, testable like other views, works unchanged on a phone. |
| What does removing a vault do? | **Forget only.** Never deletes user files. | User's explicit requirement. |
| Technology | **Stay on Flutter.** | Already ships Android and iOS from this codebase. Every dependency in the core path must work on Android. |

## 1. Vault model and registry

### Model

New freezed types in `lib/src/models/vault.dart`, serialised `snake_case`
like the other models.

```
Vault {
  String id            // uuid v4
  String name
  VaultLocation location
  DateTime createdAt
}

sealed VaultLocation
  local(String path, String? bookmark)
  remote(String kind, Map<String, dynamic> settings, List<String> secretNames)
```

- `local` covers the default app-support folder, any user-picked folder,
  and app-private folders on mobile. `bookmark` is the macOS
  security-scoped bookmark, which moves here from shared_preferences
  because it belongs to the folder.
- `remote.kind` is a string such as `gitlab`, `github`, `webdav`, `s3`,
  `google_drive`. `settings` is a plain non-secret map (repo URL, branch,
  subfolder, bucket, endpoint). Each provider spec defines its own keys.
  `secretNames` lists which secrets exist in secure storage for this vault.
- A `kind` this build does not know is preserved on round trip and shown
  as "not supported in this version". It never crashes the app. Phone and
  desktop builds will drift.

### Registry

One JSON file, `<application support>/vaults.json`:

```json
{
  "version": 1,
  "last_selected_vault_id": "…",
  "vaults": [ { "id": "…", "name": "…", "location": { "type": "local", "path": "…", "bookmark": null }, "created_at": "…" } ]
}
```

`VaultRegistryService` (`lib/src/storage/vault_registry_service.dart`)
reads and writes it. Writes are atomic: write `vaults.json.tmp`, then
rename over `vaults.json`. The last-selected id lives in the same file, so
"remember the last vault" needs no other store.

The registry is never empty after first launch. The UI refuses to remove
the last vault (section 4), so no "no vault" mode exists.

### Secrets

Tokens and access keys go into the platform keychain or keystore via
`flutter_secure_storage`, keyed `vault.<vaultId>.<secretName>`. They never
enter `vaults.json`. `VaultSecrets` is a thin interface over the plugin so
tests use a map. Removing a vault deletes every secret listed in
`secretNames`.

### Per-vault private area

`<application support>/vaults/<vaultId>/`:

- `files/` the mirror of a remote vault
- `sync.json` the sync journal (section 3)

Local vaults do not use this area, except that a local vault created on
mobile, or on desktop without picking a folder, has its `path` set to
`<application support>/vaults/<vaultId>/files/`.

Removing a vault deletes this directory and nothing else.

### Migration on first launch after upgrade

Runs once, when `vaults.json` is absent:

1. If the old `data_directory` shared-preferences key exists, create a
   local vault named after the folder's base name, with `bookmark` taken
   from the old `data_directory_bookmark` key.
2. Otherwise create a local vault named "My budget" whose `path` is the
   existing default folder, `<application support>/periods`. No files move.
3. Select it, write the registry, then remove the two old keys.

### Platform rule

A local vault at a user-picked path is offered only where `file_picker`
returns a path `dart:io` can read: macOS, Windows, Linux. On Android and
iOS a new local vault is always created in the per-vault private area.
Downstream code sees the same `local` location either way. User-picked
folders on Android go through the Storage Access Framework and are a
future provider, not a special case here.

## 2. Workspace and resolver

### `VaultWorkspace`

The only thing domain storage code talks to.
`lib/src/storage/vault_workspace.dart`:

```dart
abstract interface class VaultWorkspace {
  String get displayPath;                    // for UI and error messages
  Future<List<String>> listFiles();          // regular files, flat, no subfolders
  Future<bool> exists(String name);
  Future<String> readString(String name);
  Future<void> writeString(String name, String content);
  Future<void> delete(String name);
}
```

Implementations in this spec:

- `DirectoryWorkspace(path, {SyncJournal? journal})`, backed by `dart:io`.
  Creates the folder on first write. When a journal is present, every
  `writeString` and `delete` marks the name dirty **before** returning.
  Local and mirrored vaults both use this class. The journal is the only
  difference.
- `MemoryWorkspace`, a map, for tests.

A shared contract test suite runs against both.

### Repository changes

`PeriodRepository` and `PeriodStatsWriter` take a `VaultWorkspace` instead
of a `directoryPath`. Filename generation, YAML parsing, key sorting, the
reserved-name logic for unreadable files, and the legacy `<id>.yaml`
cleanup stay exactly where they are.

Two small changes:

- `PeriodLoadFailure.path` becomes `location`, built from `displayPath`
  and the file name, since a mirror path is not something the user should
  be told to open.
- File names containing `.conflict-` are skipped when loading periods.
  A conflict side file (section 3) would otherwise load as a duplicate
  period id.

### `VaultResolver`

Turns a `Vault` into an `OpenVault`:

```dart
class OpenVault {
  final Vault vault;
  final VaultWorkspace? workspace;   // null when accessError is set
  final SyncEngine? syncEngine;      // remote vaults only
  final String? accessError;
}
```

It is where platform quirks live, and nowhere else:

- `local` on macOS: resolve the bookmark, start accessing, return the
  workspace. On failure return `accessError` with the same wording as
  today's `StorageDirectory.accessError`. The existing
  `SecurityScopedBookmarks` interface and its test fake are reused
  unchanged. A local vault without a bookmark on macOS (a freshly created
  app-private one, or a path written by an older build) is used as is and
  reports an access error only if the folder is unreadable.
- `local` elsewhere: use the path as is.
- `remote`: ensure the private area exists, load the journal, look up a
  `RemoteStoreFactory` for `kind` in `RemoteStoreRegistry`, return a
  `DirectoryWorkspace` over `files/` with the journal, plus a `SyncEngine`.
  Unknown `kind`: `accessError` "This vault type is not supported in this
  version", no workspace.
- `remote` whose secrets are missing (keystore wiped, restored backup):
  `accessError` "Sign in to this vault again in its settings".

`RemoteStoreRegistry` is empty in production in this spec. Tests register
`InMemoryRemoteStore`.

The fallback-to-default-folder behaviour of `StorageSettingsService` is
dropped. A broken vault looks broken rather than silently showing another
folder's data.

### Providers

`storageSettingsProvider`, `StorageSettingsService` and `StorageDirectory`
are removed. In their place:

- `vaultRegistryProvider`: `AsyncNotifier<VaultRegistry>` with
  `select(id)`, `add(vault)`, `update(vault)`, `remove(id)`.
- `selectedVaultProvider`: the selected `Vault`, derived from the registry.
- `openVaultProvider`: watches `selectedVaultProvider` and resolves it
  through `VaultResolver`. Disposes the previous `SyncEngine` when the
  selection changes.
- `periodRepositoryProvider`: builds `PeriodRepository` from the open
  vault's workspace. While the vault is resolving, or when it has an
  access error, this provider is in a loading or error state and the
  dashboard shows its existing loading or empty view. The temp-directory
  fallback in the current provider goes away.
- `currentPeriodStatsSyncProvider` builds its `PeriodStatsWriter` from the
  same workspace.

Switching vaults is `select(id)`: the open vault re-resolves, the
repository rebuilds, every period provider reloads. Before the switch the
outgoing vault's engine gets a best-effort push with a short timeout
(section 3), and the switch proceeds whether or not it succeeded.

## 3. Sync engine

Everything in this section is provider-independent and lives in
`lib/src/sync/`.

### `RemoteStore`

The entire surface a provider implements:

```dart
abstract interface class RemoteStore {
  Future<Map<String, String>> listTree();                 // name -> version
  Future<RemoteFile> read(String name);                   // content + version
  Future<Map<String, String>> writeBatch(List<RemoteChange> changes); // name -> new version
}

sealed class RemoteChange
  put(String name, String content, String? expectedVersion)
  delete(String name, String expectedVersion)

class RemoteConflict implements Exception { final List<String> names; }
```

- A version is an opaque string: an etag, a blob SHA, a revision id.
- `writeBatch` is atomic where the provider allows it (git providers make
  one commit). S3 and WebDAV write file by file, and the engine tolerates
  a partial failure, see recovery below.
- A store throws `RemoteConflict` when it can detect that an
  `expectedVersion` is stale. Stores that cannot detect it simply write.
  The engine's own pull step catches what the store cannot.

### `SyncJournal`

`sync.json` in the vault's private area. Written atomically after every
state change.

```json
{
  "version": 1,
  "baseline": { "2026-09-september.yaml": { "version": "…", "content_hash": "…" } },
  "dirty": [ "2026-09-september.yaml" ],
  "last_pull_at": "…",
  "last_push_at": "…",
  "last_error": null
}
```

- `baseline`: what the remote looked like at the last pull, per file.
- `dirty`: names changed locally since the last successful push. Added by
  `DirectoryWorkspace` before a write returns, so a crash a millisecond
  later still leaves the change scheduled.

### Pull

Runs on vault open, on "Sync now", and always as the first step of a push.

1. `listTree()`. For each name whose version differs from the baseline,
   `read` it.
2. Name not dirty locally: write the remote content into the mirror,
   update the baseline entry.
3. Name dirty locally and content identical to the remote: update the
   baseline entry only. This is how an interrupted previous push heals.
4. Name dirty locally and content differs: **conflict.** Apply the policy:
   - The engine is given a `ConflictPolicy` with a
     `DateTime? Function(String name, String content) timestampOf` and a
     `Set<String> derivedFiles`. The app supplies an extractor that reads
     `last_modified` from period YAML and returns null for anything else.
     `derivedFiles` is `{ current_stats.md }`.
   - Newest timestamp wins. If either timestamp is null, local wins.
   - The loser is written to the mirror as
     `<stem>.conflict-<yyyy-MM-dd-HHmm>.<ext>` and marked dirty, so it
     reaches every device. The user deletes it by hand once reviewed.
   - If the remote copy won, its content replaces the mirror file and the
     name leaves `dirty`. If local won, the name stays dirty.
   - Either way the baseline entry becomes the remote's current version,
     so the following push carries the right `expectedVersion`.
   - Derived files: local always wins, no side file.
5. Name in the baseline but absent from the remote tree: deleted remotely.
   If not dirty, delete it from the mirror and the baseline. If dirty, keep
   the local copy, drop the baseline entry, leave it dirty, so the push
   re-creates it.
6. Write the journal with `last_pull_at`.

### Push

1. `dirty` empty: done.
2. Pull.
3. Snapshot: for each dirty name, capture the current content (or absence)
   and the baseline version. Build the batch: `put` with
   `expectedVersion` from the baseline, or `delete` when the file is gone
   locally. A name that is dirty, absent locally, and absent from the
   baseline was created and deleted before it was ever pushed: it produces
   no change and is dropped from `dirty`.
4. `writeBatch`. On success: update each baseline entry with the returned
   version and the pushed content hash, and remove a name from `dirty`
   only if its current content hash still equals the snapshot's. Write the
   journal with `last_push_at`, clear `last_error`.
5. On `RemoteConflict`: return to step 2. At most three rounds, then stop
   and record the error. Everything stays dirty.
6. On any other error, including no network: leave `dirty` as is, record
   the error, stop. Nothing is lost. The next trigger tries again.

### Recovery after a partial, non-atomic push

Needs no special code. The re-run's pull finds the already-written files
"changed" remotely with content equal to the local content, step 3 of pull
adopts the new versions, and the batch shrinks to what is actually left.

### Triggers

All coarse, all single-flight per vault. A trigger that arrives while a
run is in progress queues exactly one re-run.

- pull when a vault is opened
- push 15 seconds after the last dirty mark with no further marks
- push immediately on `AppLifecycleState.paused` (the Android case)
- push on "Sync now"
- push before switching away from a vault, best effort, 5 second timeout

`SyncScheduler` owns the timer and the lifecycle observer and calls the
engine. The engine itself has no timers, so tests drive it directly.

### Status

`SyncStatus { state: idle | syncing | offline | error, dirtyCount,
lastPullAt, lastPushAt, lastError }`, exposed per vault by
`syncStatusProvider(vaultId)`. The sidebar switcher and Settings read it.
Repository code never sees any of it. A period save cannot fail because of
the network, because it only writes to the mirror.

## 4. UI

Follows `doc/08_design_guidelines.md`: 12 px radius on menu items, sidebar
item styling reused from `AppShell`.

### Sidebar footer switcher

Sits above the Settings item. Shows the vault name with an up/down
chevron. For a remote vault, a `bodySmall` status line underneath:
"Synced 2 min ago", "3 changes pending", "Offline", "Sync failed".
Tapping opens a popup menu: every vault, a check on the current one, a
divider, "Manage vaults…". Selecting a vault calls `select(id)`.

### Manage screens

Three routes in the existing Settings branch of the router:

- `/settings/vaults`. A list. Each row: name, a location line ("~/Documents/budget", or later "GitLab · group/repo/budget"), a status chip (access error, sync state), a "Sync now" button on remote vaults, and an overflow menu with Edit and Remove. A "New vault" button. Remove asks for confirmation and repeats that files are not deleted. Removing the last vault is disabled with a hint.
- `/settings/vaults/new`. A kind chooser followed by the kind's form. The chooser is driven by a `VaultKindDescriptor` list (kind, label, icon, form builder). This spec registers one descriptor, **Local folder**. A provider spec adds one descriptor and one form, and nothing else in the UI changes.
- `/settings/vaults/:id/edit`. The same form, pre-filled. For a remote vault of an unknown kind, the form shows only the name and the "not supported" notice.

### Local folder form

Fields: name, and on macOS, Windows and Linux a folder row with
"Choose folder…" that calls the existing `file_picker` directory picker.
When no folder is chosen, the vault is created in the per-vault private
area and the row says so. On Android and iOS the folder row is absent and
one line explains the vault is stored inside the app.

### Settings page

The "Data Storage" section becomes: current vault name, its location line,
the access-error banner when the resolver reports one (moved from the
current folder card), and a "Manage vaults" button. "Change Folder" and
"Reset to default folder" are removed, the edit form does that job. The AI
stats toggle stays.

### Access errors

The vault stays selected, the banner explains, the dashboard shows its
empty state, and other vaults remain switchable from the footer.

## 5. README

Replace the tagline and the "Local-First Philosophy" section:

> Your financial planning in "flat" files. Simple, private, and fully under your control.

> ## 🏛️ Your Data, Your Storage
> 1. **You Own Your Data.** Your budget lives in plain files in a place you choose: a folder on your device, or your own private storage such as a Git repository, a WebDAV server, or an S3 bucket. FlatPlan runs no server of its own and never sees your data.
> 2. **Total Transparency.** (unchanged)
> 3. **Sync Freedom.** Keep it local and sync with Git, Syncthing or Dropbox as you do today, or point FlatPlan straight at your private storage. Remote vaults are on the roadmap, local folders work now.
> 4. **Private by Default.** (unchanged)

In "How It Works", add one sentence introducing vaults: a vault is a named
folder of period files, and you can keep several and switch between them.

Update `AGENTS.md` to describe the storage layer as vault-based and to list
the new files.

## 6. Error handling

Errors surface. Nothing falls back silently.

- Registry unreadable or corrupt: rename it to `vaults.json.broken`, start
  with a fresh registry holding the default local vault, show a one-time
  banner on the dashboard naming the broken file. User files are untouched.
- Vault cannot be resolved: see section 4.
- Sync errors: recorded in the journal, shown in the switcher status and
  on the manage list, never thrown into period editing.
- Secret missing for a remote vault: access error asking the user to sign
  in again, the edit form re-asks.
- Migration failure: leave the old shared-preferences keys in place so a
  retry on the next launch is possible, and start on the default vault.

## 7. Testing

All with fakes. No network. Temp directories only for `DirectoryWorkspace`
itself and the registry file.

- **Workspace contract suite** run against `DirectoryWorkspace` and
  `MemoryWorkspace`: list, exists, read, write, delete, create-on-write,
  and journal marking before the write returns.
- **`PeriodRepository`, `PeriodStatsWriter`**: existing tests migrated to
  `MemoryWorkspace`, plus the `.conflict-` skip and the new
  `PeriodLoadFailure.location`.
- **`VaultRegistryService`**: round trip, atomic write, corrupt file
  becomes `.broken` plus fresh registry, migration from both old-key
  cases, unknown remote kind preserved on round trip.
- **`VaultResolver`**: local with bookmark, local with stale bookmark
  (reusing `FakeBookmarks`), local without bookmark, remote via a fake
  factory, remote with missing secret, unknown kind.
- **`SyncEngine` against `InMemoryRemoteStore`**: first pull into an empty
  mirror, push of new files, push of a delete, interrupted push (store
  throws after writing half the batch, re-run heals and pushes the rest),
  each conflict branch (local newer, remote newer, timestamp missing,
  derived file), remote delete versus local dirty, three-round conflict
  give-up, dirty mark during a running push keeps the name dirty, journal
  written after each step.
- **`SyncScheduler`**: debounce, lifecycle trigger, single-flight with one
  queued re-run.
- **Providers**: registry select/add/update/remove, `openVaultProvider`
  re-resolves on select, repository rebuilds.
- **Widgets**: switcher menu lists vaults and selects, manage list shows
  status chips and disables removing the last vault, local form hides the
  folder row on a fake mobile platform, Settings shows the access banner.

## 8. File map

New:

```
lib/src/models/vault.dart
lib/src/storage/vault_workspace.dart        VaultWorkspace, DirectoryWorkspace, MemoryWorkspace
lib/src/storage/vault_registry_service.dart
lib/src/storage/vault_secrets.dart
lib/src/storage/vault_resolver.dart
lib/src/sync/remote_store.dart              RemoteStore, RemoteChange, RemoteFile, RemoteConflict
lib/src/sync/remote_store_registry.dart
lib/src/sync/sync_journal.dart
lib/src/sync/sync_engine.dart
lib/src/sync/sync_scheduler.dart
lib/src/sync/conflict_policy.dart
lib/src/providers/vault_registry_provider.dart
lib/src/providers/open_vault_provider.dart
lib/src/providers/sync_status_provider.dart
lib/src/views/vault_list_view.dart
lib/src/views/vault_form_view.dart
lib/src/components/vault_switcher.dart
test/sync/in_memory_remote_store.dart
```

Changed: `period_repository.dart`, `period_stats_writer.dart`,
`repository_provider.dart`, `current_period_stats_sync_provider.dart`,
`app_router.dart`, `app_shell.dart`, `settings_view.dart`,
`period_load_warning.dart`, `README.md`, `AGENTS.md`, `pubspec.yaml`
(adds `flutter_secure_storage`).

Removed: `storage_settings_service.dart`, `storage_settings_provider.dart`
and their tests, replaced by the registry and resolver tests.

## 9. Follow-ups, each its own spec

- First remote provider. WebDAV is the simplest and exercises the
  non-atomic path. GitLab is the simplest atomic one.
- Android platform target and responsive shell.
- Per-file "keep mine / take theirs" chooser on top of the conflict policy.
- Android user-picked folders through the Storage Access Framework.
