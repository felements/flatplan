# Stage 2: Architecture & State Management

## App Architecture Overview
The app will use a **Feature-first** (layer-by-feature) architecture to maintain high cohesion. The features align with the core entities:
1. `period_management` (Handling period lifecycle: create, load, list files)
2. `budget_dashboard` (Viewing the current period totals)
3. `category_details` (Managing planned and factual expenses inside a category)
4. `settings` (Managing default preferences and templates)

## Tech Stack & Libraries
- **Framework**: Flutter (Desktop today: Windows, macOS, Linux. Android and iOS are the next target, which is why every dependency on the storage path must work on mobile).
- **State Management**: `hooks_riverpod` or `riverpod` (v3 with code generators and riverpod_annotation) using Notifiers for predictable state mutations and easy testability.
- **Routing**: `go_router` for declarative navigation between dashboard, category details, and period creation screens.
- **Storage / File I/O**:
  - `path_provider`: resolves the application support directory, which holds `vaults.json` and each vault's app-private area. Domain code never touches paths; it writes through `VaultWorkspace`.
  - `yaml` (parsing) and `json2yaml` (or equivalent writer) to serialize models.
  - *Note*: Ensure the YAML writer sorts keys alphabetically.
- **Modelling**: `freezed` or `json_serializable` to generate `fromJson` / `toJson`.

## State Management Flow
1. **Vault Layer** (`lib/src/storage/`, `lib/src/sync/`):
   - `VaultRegistryService` reads and writes `vaults.json` and migrates the pre-vault folder setting into the first vault.
   - `VaultResolver` turns a `Vault` into an `OpenVault`: a `VaultWorkspace` to write through, plus, for remote vaults, a `SyncScheduler` around the `SyncEngine`. Platform quirks (macOS security-scoped bookmarks, missing folders, unknown provider kinds, missing secrets) live here and surface as an `accessError`.
   - `SyncEngine` moves files between the local mirror and a `RemoteStore` (list tree with versions, read, write a batch). Conflicts resolve newest `last_modified` wins with the loser kept as a side file; interrupted pushes heal on the next run.
2. **Repository Layer**:
   - `PeriodRepository`: Reads/Writes the period YAML files through a `VaultWorkspace`. `loadAll()` returns the periods that loaded plus the files that failed; `savePeriod(Period)` keeps a period's existing file name.
3. **Provider / Notifier Layer**:
   - `vaultsProvider`: the registry notifier (`select`, `add`, `updateVault`, `remove`). `openVaultProvider` resolves the selected vault and flushes the outgoing remote vault when the selection changes. `periodRepositoryProvider` is async and errors with `VaultUnavailable` when the vault cannot be opened, so nothing ever writes into a placeholder folder.
   - `allPeriodsProvider` / `periodLoadFailuresProvider`: the loaded periods and the unreadable files.
   - `currentPeriodNotifier`: The active loaded `Period`. It exposes methods like:
     - `addFactExpense(categoryId, expense)`
     - `removeFactExpense(categoryId, expenseId)`
     - `togglePlannedExpense(categoryId, expenseId)`
     - `updateCategoryLimit(categoryId, newLimit)`
   - *Side-effect*: Every time the `currentPeriodNotifier` mutates the state, it debounces for 500 ms and calls `PeriodRepository.savePeriod(state)` on the repository captured at edit time, so a vault switch inside the window cannot write into the wrong vault.
4. **Computed Providers**:
   - `periodStatsProvider`: Listens to `currentPeriodNotifier` and calculates the totals (Planned to Facts, Remaining limits, Heat indicators). Keeps complex math out of the UI.

## File System Strategy
- User keeps one or more **vaults**. A local vault is a folder (which they can independently initialize as a git repository). A remote vault is mirrored locally and synced by the engine in `lib/src/sync/`.
- Files inside a vault: `YYYY-MM-<slug>.yaml` tracking files, an optional template file, `current_stats.md`, and any `.conflict-` side files (see `01_storage_models.md`).
- Local vaults are re-read whenever a save invalidates the period providers; there is no directory watcher, so files changed underneath by git pull show up on the next launch or vault switch.
- Remote vaults pull when opened and push 15 s after the last edit, when the app goes to the background, on "Sync now", and before switching vaults. The journal in `sync.json` keeps every pending change across restarts.
