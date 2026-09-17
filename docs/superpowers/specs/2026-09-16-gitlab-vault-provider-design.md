# GitLab vault provider

Date: 2026-09-16
Status: approved design, awaiting implementation plan

## Summary

The first remote vault provider. A vault can live in a folder of a GitLab
repository, on gitlab.com or on a self-hosted instance, reached through the
REST API with a personal access token. The app keeps working on its local
mirror; the existing `SyncEngine` moves files through a new
`GitLabRemoteStore`.

This spec ships:

- `GitLabRemoteStore`, a `RemoteStore` over the GitLab REST API
- the keychain-backed `VaultSecrets` that the vaults spec deferred
- the lock between local writes and the engine's pull that the vaults spec
  listed as a precondition
- the "GitLab" vault kind: a connect flow that verifies the token, picks the
  project, branch and folder, and trusts a self-signed certificate on request
- platform entitlements and packaging changes for network access and the
  keychain
- documentation updates

It does not ship OAuth sign-in, a per-file conflict chooser, the Android
target, or any other provider. Everything here must keep working unchanged
when the Android and iOS targets arrive.

## Decisions already made

| Question | Decision | Why |
|---|---|---|
| How does the app authenticate? | **Personal access token**, either kind GitLab offers: fine-grained (recommended) or legacy. | OAuth needs an application registered on every instance, which self-hosted users cannot be asked to do. Tokens work identically on gitlab.com and self-hosted, on desktop and on a phone. |
| How does the store detect a stale write? | **Compare git blob SHAs from a fresh tree listing, then commit once.** | One atomic commit per push. Blob SHAs are content identity, so identical content is never a conflict and new versions are computable locally. GitLab's own `last_commit_id` check needs one HEAD request per file and answers with a non-specific 400. |
| What carries HTTP? | **`package:http` with an injectable `Client`.** | Runs on every Flutter platform; tests script responses with `MockClient` and need no server. |
| How is a self-signed certificate handled? | **Trust one certificate by SHA-256 fingerprint**, shown and confirmed on first connect. | A blanket "skip verification" lets anyone on the path capture a token that reaches every project the user can. The pin costs one dialog. |
| How is the project chosen? | **Searchable list**, which also resolves a typed `group/repo` path. | Works at phone width. A fine-grained token scoped to one project may return an empty search, so the typed path is the fallback. |
| How is the folder chosen? | **Text field, verified on save.** | Git has no empty folders, so a browser cannot show a folder that does not exist yet. The first push creates it. |
| What can be edited after creation? | **Name, token, and the trusted certificate.** Server, project, branch and folder are fixed. | The mirror and journal belong to one remote location. Pointing them elsewhere would push one folder's files into another. A different location is a new vault. |

## 1. Vault location and secrets

### Settings

A GitLab vault is `VaultLocation.remote(kind: 'gitlab', settings: {...},
secretNames: ['token'])`. Settings keys, all non-secret:

| key | example | notes |
|---|---|---|
| `base_url` | `https://gitlab.com` | scheme, host, optional port and path prefix. No trailing slash. Plain `http://` is allowed. |
| `project_id` | `12345` | numeric id, used in every API path |
| `project_path` | `group/repo` | for the location line and the edit form |
| `branch` | `main` | |
| `folder` | `budget` | no leading or trailing slash. Empty string means the repository root. |
| `cert_fingerprint` | `AB:CD:…` | SHA-256 of the trusted certificate's DER bytes, upper-case hex pairs joined by colons. Absent when the system trust store is used. |

`GitLabSettings` (`lib/src/sync/gitlab/gitlab_settings.dart`) is a typed
view over this map with `fromSettings` and `toSettings`, so the store, the
form and the location line never read raw keys.

The location line is "GitLab · group/repo/budget" for gitlab.com and
"gitlab.example.com · group/repo/budget" for a self-hosted host. The folder
part is omitted when the folder is empty.

### Secrets

`SecureVaultSecrets` (`lib/src/storage/secure_vault_secrets.dart`)
implements `VaultSecrets` over `flutter_secure_storage`. Keys stay
`vault.<vaultId>.<name>`. `vaultSecretsProvider` switches from
`MemoryVaultSecrets` to it; test containers override the provider with
`MemoryVaultSecrets`, as the fake-vaults test support already does for the
registry.

Creating a vault writes the token first and the registry entry second, so a
crash between the two leaves an orphan secret rather than a vault with no
token. Orphan secrets are harmless and are not cleaned up.

## 2. `GitLabRemoteStore`

All in `lib/src/sync/gitlab/`.

### `gitlab_api.dart`

A thin typed client over `http.Client`. Every request sends
`PRIVATE-TOKEN: <token>` and `Accept: application/json`, and times out
after 30 seconds. Methods:

| method | endpoint |
|---|---|
| `searchProjects(query)` | `GET /projects?membership=true&min_access_level=30&simple=true&search_namespaces=true&order_by=last_activity_at&per_page=50&search=<q>` |
| `projectByPath(path)` | `GET /projects/<url-encoded path>` |
| `project(id)` | `GET /projects/:id` |
| `branches(id)` | `GET /projects/:id/repository/branches` |
| `branch(id, name)` | `GET /projects/:id/repository/branches/:name` |
| `tree(id, ref, path)` | `GET /projects/:id/repository/tree?path=&ref=&per_page=100&page=n`, following the `x-next-page` header until it is empty |
| `rawFile(id, ref, path)` | `GET /projects/:id/repository/files/<url-encoded path>/raw?ref=` |
| `commit(id, branch, message, actions)` | `POST /projects/:id/repository/commits` |
| `tokenInfo()` | `GET /personal_access_tokens/self` |

Path segments such as `budget/2026-09-september.yaml` are encoded with
`Uri.encodeComponent`, so the slash becomes `%2F`.

Responses map to exceptions defined in `remote_store.dart` and here:

| response | exception | engine shows |
|---|---|---|
| socket, handshake, timeout, 429, 502, 503, 504 | `RemoteUnreachable(message)` | Offline |
| 401 | `RemoteAuthRejected()` | "GitLab rejected the token. Replace it in the vault settings." |
| 403 | `GitLabApiException(403, message)` | GitLab's own message, which for a fine-grained token names the missing permission |
| other non-2xx | `GitLabApiException(status, message)` | "Sync failed" with the message |

`message` is GitLab's `message` or `error` JSON field when present, else
the status line. A handshake failure caused by an untrusted certificate is
`CertificateRejected(host, subject, fingerprint)` instead of
`RemoteUnreachable`, so the connect flow can offer to trust it and the sync
status can say the certificate changed.

`SyncFailure.from` in `sync_engine.dart` gains `RemoteUnreachable` in its
offline list. Nothing else in the engine changes for this section.

### `gitlab_http.dart`

`buildGitLabClient(settings)` returns an `IOClient` over a `dart:io`
`HttpClient` with `connectionTimeout` of 30 seconds. When
`cert_fingerprint` is set, `badCertificateCallback` accepts a certificate
only if the request host equals the vault's host and the SHA-256 of the
certificate's DER bytes equals the stored fingerprint. Otherwise it records
the offered certificate's subject and fingerprint for the connect flow and
returns false.

Plain `http://` needs no special handling. Dart sockets are not subject to
Android's cleartext policy or iOS App Transport Security, so no platform
exception is needed when those targets arrive.

### `git_blob.dart`

`gitBlobSha(String content)` returns the hex SHA-1 of
`"blob <byte length>\0" + UTF-8 bytes`, using the `crypto` package already
in the project. This is git's blob object id, the same value the tree
endpoint returns as `id`.

### `gitlab_remote_store.dart`

`GitLabRemoteStore(api, settings)` implements `RemoteStore`. Names are
file names inside the vault folder; the repository path of a name is
`<folder>/<name>`, or `<name>` when the folder is empty.

`listTree()`:

1. `api.tree(projectId, branch, folder)`.
2. Keep entries with `type == "blob"` whose `path` is directly inside the
   folder. Drop subfolders. Return `name -> id`.
3. On 404, decide what is missing before answering "empty", because an
   empty answer makes the engine delete mirror files that are no longer on
   the remote:
   - `api.project(id)`. If it reports `empty_repo: true`, return an empty
     map: the repository has no commits yet.
   - Otherwise `api.branch(id, branch)`. If the branch exists, the folder
     does not: return an empty map.
   - If the branch is missing, throw `GitLabApiException(404, "Branch
     '<branch>' was not found in <project_path>")`.

`read(name)`: `api.rawFile`, version from the `X-Gitlab-Blob-Id` response
header. A 404 throws `GitLabApiException`, since the engine only reads names
it just listed.

`writeBatch(changes)`:

1. `listTree()` for the current blob ids.
2. Collect stale names: a `RemotePut` with `expectedVersion` null whose
   name exists, a put with a non-null `expectedVersion` that differs from
   the current id or whose name is gone, a `RemoteDelete` whose
   `expectedVersion` differs or whose name is gone. If any, throw
   `RemoteConflict(names)` and change nothing.
3. Drop every put whose `gitBlobSha(content)` equals its `expectedVersion`:
   the content is already on the remote, and GitLab rejects a commit with no
   changes. Their version is returned unchanged.
4. If no actions remain, return the versions without a request.
5. Build actions: `create` for a put with `expectedVersion` null, `update`
   otherwise, `delete` for a delete. Content is sent as text.
6. `api.commit(projectId, branch, "FlatPlan sync: <n> file(s)", actions)`.
   `start_branch` is omitted, so on an empty repository the commit creates
   the branch. GitLab records the token's owner as author.
7. Return `name -> gitBlobSha(content)` for every put.

If the locally computed SHA ever differed from what GitLab stores, the next
pull would see a "changed" file with identical content and adopt the
remote's id through the engine's existing heal step. No data is at risk.

A 400 on the commit whose message mentions the branch being protected or
the user not being allowed to push is rethrown as
`GitLabApiException(400, "GitLab refused the push to '<branch>': <message>.
Use another branch or a token with the Maintainer role.")`.

### Registration

`gitLabStoreFactory` in `gitlab_provider.dart` builds the store from a
`RemoteVaultLocation` and the `token` secret. `remoteStoreRegistryProvider`
in `open_vault_provider.dart` registers it under `gitlab`. Tests that need
an empty registry override the provider.

Opening a vault makes no network request. Bad or expired credentials
surface at the first sync as `RemoteAuthRejected`, so a phone with no signal
still opens its mirror.

## 3. The pull/write lock

The vaults spec recorded this race: a local save that lands between the
engine reading a dirty file and resolving its conflict can be dropped from
`dirty` and overwritten by the next pull. Local vaults have no engine, so
the first remote provider must close it.

`lib/src/sync/lock.dart` adds `Lock`, a future-chained mutex with one
method, `Future<T> synchronized<T>(Future<T> Function() action)`.

- `DirectoryWorkspace` accepts an optional `lock`. `writeString` and
  `delete` run the file operation and the change-listener call inside it.
- `SyncEngine` accepts an optional `lock`. In `_pull`, every name is
  handled under one acquisition of it: the dirty check itself, then either
  the plain write of a clean file or the compare-and-resolve of a dirty
  one, and the journal update. A local save that starts mid-pull therefore
  either is seen by the dirty check or waits for the lock and re-marks the
  name dirty; it can never be overwritten in between. Removing a file the
  remote deleted takes the lock the same way. In `_snapshot`, reading each
  dirty file runs inside it too, so the hash the engine records matches the
  bytes it sent.
- `VaultResolver._openRemote` creates one `Lock` per vault and passes it to
  the app-facing workspace and to the engine. The engine's own mirror
  workspace does not take the lock: the engine already holds it when it
  writes, and the lock is not reentrant.

The `TODO(sync)` in `sync_engine.dart` goes away with this.

## 4. Connect flow

### Controller

`GitLabConnectController` (`lib/src/providers/gitlab_connect_controller.dart`)
is a Riverpod notifier holding the wizard state and owning the `GitLabApi`
during setup, so the form only renders and dispatches. It is created with
an `http.Client` factory so tests inject `MockClient`. State:

```
GitLabConnectState {
  bool selfHosted
  String baseUrl                 // "https://gitlab.com" when not self-hosted
  String? certFingerprint
  ConnectStep step               // server, token, project, target, done
  CertificateOffer? pendingCertificate
  String? connectError
  List<ProjectSummary> projects
  ProjectSummary? project
  List<String> branches
  String? branch
  String folder                  // default "budget"
  FolderCheck? folderCheck       // periodFiles(n) | empty | newRepository | error(msg)
}
```

`connect(token)` runs the probes in order and stops at the first failure
with a message naming the fix:

1. `searchProjects("")`. A `CertificateRejected` sets `pendingCertificate`
   and stops; `trustCertificate()` stores the fingerprint and reruns
   `connect`. 401: "GitLab rejected this token." 403: GitLab's message,
   which names the missing permission (`User → Project: Read`).
   `RemoteUnreachable`: "Could not reach <base_url>."
2. Best effort `tokenInfo()`. If it answers with `scopes` that lack `api`
   and no `granular_scopes`, stop: "This legacy token needs the `api`
   scope." If it answers with `granular_scopes`, or fails with 403 (a
   fine-grained token without permission to read tokens), continue. This
   is the only way to catch a `read_api` token before the first push.
3. Step becomes `project`, with the first page of results shown.

`search(query)` debounces 300 ms and calls `searchProjects`. When the query
looks like a path (contains `/`) and the search is empty, it also calls
`projectByPath` and shows that project if found. `selectProject(p)` calls
`branches`, preselects the project's `default_branch`, sets the vault name
suggestion to the project name, and moves to `target`. 403 on either call
names `Project: Read` or `Branch: Read`.

`checkFolder()` runs on `target` entry and whenever the folder field
settles: `tree(project, branch, folder)` counted as period files (names
ending `.yaml` without `.conflict-`), else `empty`, else `newRepository`
when the project is `empty_repo`, else GitLab's 403 message naming
`Repository: Read`.

`Commit: Create` cannot be probed without writing. Its absence appears at
the first push as the sync error in section 2, and "Replace token" in the
edit form fixes it.

### Form

`GitLabVaultForm` (`lib/src/views/gitlab_vault_form.dart`), registered as
`gitLabVaultKind` in `vault_kinds.dart` with label "GitLab" and icon
`Icons.cloud_rounded`. `vaultKinds` becomes `[localVaultKind,
gitLabVaultKind]`; `VaultFormView` already shows the kind chooser once two
kinds exist.

One scrolling column that reveals steps as they succeed. Nothing needs
hover or a wide screen:

1. **Server.** Checkbox "Self-hosted instance", unchecked by default, which
   means gitlab.com and shows no URL field. Checked: a URL field, hint "https://gitlab.example.com,
   http:// is allowed for internal servers".
2. **Token.** A password field and a "Connect" button. Under it an
   expandable "How to create a token" with two parts:
   - **Fine-grained (recommended).** User settings → Access → Personal
     access tokens → Generate token → Fine-grained. Under "Group and
     project access" pick the vault repository, then grant: Project: Read,
     Branch: Read, Repository: Read, Commit: Create. Under the User tab
     grant Project: Read. Available on every tier and every instance from
     GitLab 19.2.
   - **Legacy.** Scope `api`. Needed on instances older than GitLab 18.10.
     Group or instance admins can block legacy tokens after a date they
     set, in which case GitLab answers with an error naming the fine-grained
     permissions to use instead.
   No validation of the token's shape: old tokens have no prefix, newer
   ones start with `glpat-`, and self-hosted admins can set a custom
   prefix. Success shows "Connected" and reveals the next step.
3. **Project.** Search field with the result list underneath, each row
   showing name and path. Hint: "Type to search, or paste group/repo".
4. **Branch and folder.** Branch dropdown. Folder text field, default
   `budget`, and a status line from `folderCheck`: "3 period files found",
   "Empty, files will be created on first sync", "New repository, the
   branch will be created on first sync".
5. **Name** prefilled from the project, and "Create vault".

The trust dialog, opened when `pendingCertificate` is set: title "Trust
this certificate?", the host, the certificate subject, the fingerprint in
groups, a warning that only this exact certificate will be accepted, and
buttons "Trust" and "Cancel".

Create writes the secret, then adds the vault through `vaultsProvider`, and
pops. The vault opens through the existing resolver, and its first
`syncNow()` pulls the folder into the mirror.

### Edit form

The same widget with `existing` set. Server, project, branch and folder are
shown read-only with the hint "To use a different repository or folder,
create a new vault." The token field shows "Token stored" and a "Replace
token" button that runs the connect probes with the new token against the
stored project and saves the secret on success. When the resolver reported
the missing-secret access error, the field is empty and required. A
self-hosted vault also shows "Trusted certificate: <fingerprint>" with a
"Trust again" action that fetches the current certificate and offers it.

## 5. Platform work

- `pubspec.yaml`: add `http` and `flutter_secure_storage`.
- macOS: add `com.apple.security.network.client` and an empty
  `keychain-access-groups` array to both `DebugProfile.entitlements` and
  `Release.entitlements`. Without the first the sandbox blocks every
  request; without the second the keychain write fails.
- Linux: the release workflow installs `libsecret-1-dev` alongside the GTK
  packages. Configured from `pubspec.yaml`, as here, `flutter_to_debian`
  derives `Depends:` from the shared libraries the bundle links against, so
  installing `libsecret-1-dev` in the release job is enough and no runtime
  dependency has to be declared by hand; verify the generated control file
  lists `libsecret-1-0` on the next release. Without a running secret
  service the keychain write throws, which the form reports as "Could not
  save the vault" rather than crashing.
- Windows: nothing.
- Android and iOS: nothing in this layer. Recorded so nobody adds a
  cleartext exception later.

## 6. Error handling

Nothing falls back silently. Sync errors reach the switcher status line and
the vault list, never period editing.

| situation | behaviour |
|---|---|
| no network, timeout, 429, 5xx | Offline. Dirty files wait for the next trigger. |
| 401 during sync | "GitLab rejected the token. Replace it in the vault settings." |
| 403 during sync | GitLab's message. For a fine-grained token it names the permission, for a legacy token blocked by an enforcement date it says a fine-grained token is required. |
| certificate changed since it was trusted | "The server's certificate changed. Trust it again in the vault settings." Never re-trusted automatically. |
| tree 404 | Resolved as in section 2: empty repository or missing folder are empty; a missing branch is an error, so the mirror is never emptied by mistake. |
| protected branch or no push permission | The 400 message with the hint to use another branch or a Maintainer token. |
| stale versions | `RemoteConflict`, handled by the engine's existing three-round retry. |
| keychain unavailable | The form's save fails with the platform error in a snack bar; the vault is not created. |
| secret missing at open | Existing resolver behaviour: access error "Sign in to this vault again in its settings", the edit form's token field is required. |

## 7. Testing

All with fakes. No network except one local TLS test.

- **`gitBlobSha`**: matches a known git blob id, for example the empty
  blob `e69de29bb2d1d6434b8b29ae775ad8c2e48c5391` and one multi-byte
  UTF-8 string hashed with `git hash-object` beforehand.
- **`GitLabApi` against `MockClient`**: token header, JSON accept header,
  path encoding of `budget/2026-09-september.yaml`, tree pagination across
  two pages, `X-Gitlab-Blob-Id` extraction, every status mapping in the
  table of section 2, message extraction from `message` and `error`
  fields, 30-second timeout mapped to `RemoteUnreachable`.
- **`GitLabRemoteStore`**: `listTree` keeps only direct blobs and strips
  the folder prefix; root folder with empty `folder`; the three 404
  outcomes; `read` version from the header; `writeBatch` action mapping
  for create, update and delete; stale detection for each of the five
  cases in section 2 with nothing sent; identical-content puts dropped and
  an all-identical batch sending no request; returned versions equal
  `gitBlobSha`; the protected-branch 400 rewrite. Then the whole engine
  suite's push and pull scenarios run once against `GitLabRemoteStore` over
  a scripted fake GitLab built on `MockClient`, mirroring the
  `InMemoryRemoteStore` tests.
- **Certificate pin**: fingerprint formatting; `badCertificateCallback`
  accepts the pinned certificate for the vault host only; a widget-free
  test starts a local `HttpServer` with a self-signed certificate from
  test fixtures and proves a mismatched fingerprint yields
  `CertificateRejected` with the offered fingerprint while the matching
  one succeeds.
- **`Lock` and the race**: `Lock` serialises overlapping actions; an
  engine test where `DirectoryWorkspace.writeString` is called while the
  engine is between reading a dirty file and resolving it, asserting the
  name is still dirty afterwards and the newer content survives.
- **`SecureVaultSecrets`**: the `VaultSecrets` contract (read, write,
  deleteAll, missing name) run against `MemoryVaultSecrets` and against
  `SecureVaultSecrets` over the plugin's mock platform.
- **`GitLabConnectController`** with scripted responses: happy path;
  certificate offer then trust then success; 401; fine-grained 403 message
  surfaced; legacy `read_api` token stopped at `tokenInfo`; fine-grained
  token whose `tokenInfo` is 403 proceeds; empty search resolved by a typed
  path; folder check for each outcome; branch preselection.
- **Widgets**: the kind chooser lists GitLab; the form reveals steps in
  order; the self-hosted checkbox shows the URL field; the trust dialog
  appears and "Trust" continues; the edit form shows the location
  read-only and "Replace token"; the location line for gitlab.com and for
  a self-hosted host.
- **Resolver and providers**: `remoteStoreRegistryProvider` supports
  `gitlab`; opening a GitLab vault makes no request; `vaultSecretsProvider`
  overridden in the shared test container.

## 8. Documentation

- `AGENTS.md`: list the new files, say `gitlab` is registered, and note the
  keychain-backed secrets and the lock.
- `doc/05_implementation_plan.md`: move "first remote provider" from
  candidates to completed, with WebDAV and others as new candidates.
- `doc/01_storage_models.md` and `doc/02_architecture.md`: mention the
  GitLab vault kind where remote vaults are described.
- `README.md`: "Sync Freedom" says GitLab vaults work now and other
  providers are on the roadmap.
- `PRIVACY.md`: state that a GitLab vault sends period files to the GitLab
  server the user configured and nowhere else, and that the token is kept
  in the platform keychain.

## 9. File map

New:

```
lib/src/sync/gitlab/gitlab_settings.dart
lib/src/sync/gitlab/gitlab_api.dart
lib/src/sync/gitlab/gitlab_http.dart
lib/src/sync/gitlab/git_blob.dart
lib/src/sync/gitlab/gitlab_remote_store.dart
lib/src/sync/gitlab/gitlab_provider.dart
lib/src/sync/lock.dart
lib/src/storage/secure_vault_secrets.dart
lib/src/providers/gitlab_connect_controller.dart
lib/src/views/gitlab_vault_form.dart
test/sync/gitlab/fake_gitlab.dart            scripted MockClient handler
test/sync/gitlab/*_test.dart
test/fixtures/self_signed.pem, self_signed.key
```

Changed: `remote_store.dart` (`RemoteUnreachable`, `RemoteAuthRejected`),
`sync_engine.dart` (offline list, lock), `vault_workspace.dart` (lock),
`vault_resolver.dart` (lock wiring), `open_vault_provider.dart`
(registration), `vaults_provider.dart` (secure secrets),
`vault_kinds.dart`, `pubspec.yaml`, both macOS entitlements,
`.github/workflows/release.yml`, the docs in section 8.

## 10. Follow-ups, each its own spec

- WebDAV provider, the first non-atomic store.
- GitHub provider, a near copy of this one over the contents and git data
  APIs.
- OAuth sign-in for gitlab.com only, where one registered application
  serves everyone.
- Per-file "keep mine / take theirs" chooser.
- A tree browser for the folder field, if users ask for it.
