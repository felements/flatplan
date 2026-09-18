# FlatPlan Project Context

## Application Overview
FlatPlan is a Flutter budget-tracking app (desktop today, mobile planned) storing periods as YAML files inside named **vaults**. Full specification is in the `doc/` folder (`01_storage_models.md` through `05_implementation_plan.md`). Always consult these documents for detailed requirements.

## Current Progress
- **Stages 1 through 5** and **Phase 6 (vaults and the storage abstraction)** are **COMPLETED**; Phase 7.1 (GitLab provider) is **COMPLETED**; further Phase 7 candidates are listed in `doc/05_implementation_plan.md`.
- Flutter desktop app with GoRouter routing and responsive `AppShell` with a 220 px dark sidebar.
- Dashboard, Category Details, and Settings pages are live. Periods are created from the sidebar's "Next period" button (`showNewPeriodDialog`), not from Settings.
- Period rollover logic generates new periods from existing ones or from scratch (cold-start).
- Periods are persisted as sorted YAML files inside the selected **vault**. The default vault lives in the application support directory (`<app support>/periods`); a vault can also be a user-picked folder, or a remote GitLab vault; WebDAV, S3 and other providers are still on the roadmap.
- Vaults are created, switched and removed from the sidebar switcher and Settings → Vaults; the pre-vault folder setting migrates into the first vault automatically.

## Important Technical Decisions & Deviations

1. **State Management**: Riverpod 3.x (`hooks_riverpod`, `riverpod_annotation`, `riverpod_generator`) — explicit user permission overriding the default Flutter rules.
2. **Data Models** (`lib/src/models/`): `freezed` + `json_annotation` with `sealed class` syntax. Global `snake_case` serialization enforced in `build.yaml`.
3. **Storage**: domain code writes through `VaultWorkspace` (`lib/src/storage/vault_workspace.dart`), never `dart:io` directly. `PeriodRepository` handles YAML with recursive key-sorting via `SplayTreeMap` and `json2yaml`. Vaults are named in `<app support>/vaults.json` (`VaultRegistryService`) and opened by `VaultResolver`. Remote vaults work on an app-private mirror moved by `lib/src/sync/` (`SyncEngine`, `SyncJournal`, `SyncScheduler`, `RemoteStore`); `gitlab` is the first registered provider (`lib/src/sync/gitlab/`): one atomic commit per push, git blob ids as versions, a personal access token in the platform keychain (`SecureVaultSecrets` over `flutter_secure_storage`), and one pinned certificate per self-hosted vault. A `Lock` shared by the app-facing `DirectoryWorkspace` and the `SyncEngine` keeps a local write from landing while the engine resolves that file. Design: `docs/superpowers/specs/2026-09-16-vaults-and-storage-abstraction-design.md` and `docs/superpowers/specs/2026-09-16-gitlab-vault-provider-design.md`.
4. **Derived figures live in `lib/src/logic/`, never in a view.** `CategoryStats` / `PeriodStats` and the functions producing them sit in `logic/period_stats.dart`; `periodStatsProvider` and the views are thin callers. Screens that need stats for a specific period call `periodStatsFor` / `categoryStatsFor` directly rather than recomputing inline — three divergent copies of that maths previously left the category detail screen silently missing its daily-allowance figures.

## Key Architecture
- `lib/src/app_theme.dart` — Centralized `AppTheme` with dark (primary) and light themes, Outfit font, gold/teal/coral palette
- `lib/src/models/` — Freezed data classes: `Period`, `Category`, `PlannedExpense`, `FactExpense`, `DueDate`, plus the `CategoryBudget` extension for effective-limit maths
- `lib/src/storage/` — `VaultWorkspace` (+ `DirectoryWorkspace`, `MemoryWorkspace`), `PeriodRepository`, `PeriodStatsWriter`, `AppPaths`, `VaultRegistryService`, `VaultSecrets`, `SecureVaultSecrets`, `VaultResolver`, macOS security-scoped bookmarks
- `lib/src/sync/` — provider-independent sync: `RemoteStore` contract, `SyncJournal`, `ConflictPolicy` (newest `last_modified` wins, loser kept as `<name>.conflict-<stamp>`), `SyncEngine`, `SyncScheduler`, `SyncStatus`, `Lock`
  - `lib/src/sync/gitlab/` — `GitLabSettings`, `GitLabApi` (+ `gitlab_http.dart` pinned client), `gitBlobSha`, `GitLabRemoteStore`, `gitlab_provider.dart` registration
- `lib/src/logic/` — Provider-free domain maths: `period_logic.dart` (rollover/bootstrap), `period_extensions.dart` (period end dates, due-date resolution), `period_stats.dart` (`CategoryStats` / `PeriodStats` and the functions deriving them), `period_history.dart` (per-category history read by period membership), `spending_trend.dart` (projection from the previous period's rate), `basket_insight.dart` (basket statistics and safe-per-shop advice), `period_stats_markdown.dart` (AI stats rendering)
- `lib/src/providers/` — Riverpod providers binding storage to logic: `appPathsProvider`, `vaultsProvider` (registry), `openVaultProvider`, `currentSyncStatusProvider`, `periodRepositoryProvider` (async, errors with `VaultUnavailable`), `currentPeriodProvider`, `periodProvider`, `allPeriodsProvider`, `periodStatsProvider`, `currentPeriodStatsSyncProvider`, the settings providers, `gitLabApiFactoryProvider`, and `GitLabConnectController`
- `lib/src/routing/` — GoRouter with `StatefulShellRoute` (Dashboard + Settings branches)
- `lib/src/views/` — `DashboardView`, `CategoryDetailView`, `CategoryEditorView`, `SettingsView`, `AppShell`, `VaultListView`, `VaultFormView`, `GitLabVaultForm`, and the `vault_kinds.dart` descriptor list
- `lib/src/components/` — `CategoryTile`, `SummaryCard`, `PeriodLoadBanner`, the `showCategoryDialog` / `showPlannedExpenseDialog` / `showNewPeriodDialog` editors, `VaultSwitcher`, `VaultAccessBanner`, `BrokenRegistryBanner`, `SyncLifecycleBridge`

## Design Guidelines
See `doc/08_design_guidelines.md` for the full visual identity — color palette (gold `#D4A84B`, teal `#5A8F7B`, coral `#E07A5F`), Outfit typography, component standards (16 px radius cards, 12 px buttons/inputs), sidebar spec, and spacing conventions. All new UI must follow this document.

## Domain Glossary
See `doc/07_domain_glossary.md` for a full reference of domain entities (Period, Category, PlannedExpense, FactExpense, DueDate) and key concepts (Mandatory/Optional scope, Daily Allowance, Heat Indicator, Period Rollover, Cold-Start, Template, Base Currency).
