# Stage 1: Storage Structure & Models

## Overview
The app stores everything as **YAML files** inside a **vault**: a named folder of period files. A vault is a local folder (the default one lives in the application support directory; the user can also pick any folder) or a remote location: a folder in a GitLab repository today, with WebDAV and S3 on the roadmap, which the app mirrors locally and syncs. To prevent merge conflicts and line drift in Git, all YAML keys must be sorted alphabetically when saved. The exception is the list of fact expenses which must preserve chronological order (implemented via an incrementing order number or timestamp for each expense record). Every tracking period (e.g., a month) is represented by a single YAML file.

## File Types
1. **Period Data File** (`YYYY-MM-<slug>.yaml`, e.g. `2026-09-september.yaml`): Contains all data (categories, planned, and factual expenses) for a specific period. The slug is derived from the period name; a file that fails to load keeps its name reserved so it is never overwritten.
2. **Template File** (`<slug>.yaml` with `template` in the name): A base structure without factual expenses, used to quickly instantiate a new period.
3. **Stats Snapshot** (`current_stats.md`): A derived Markdown summary of the current period for AI insights, regenerated on every change and never read back.
4. **Conflict Side File** (`<name>.conflict-<yyyy-MM-dd-HHmm>.yaml`): Written by the sync engine when a remote vault and the local mirror both changed the same file; holds the losing copy. Files whose name contains `.conflict-` are never loaded as periods.

## Vault Files Outside the Vault
- `<app support>/vaults.json`: the vault registry (every known vault and the last selected one). Written atomically; a corrupt copy is moved to `vaults.json.broken-<stamp>` and a fresh registry is created.
- `<app support>/vaults/<vaultId>/`: a remote vault's private area holding `files/` (the mirror) and `sync.json` (the sync journal: remote versions per file, dirty names, timestamps). Local vaults created without picking a folder also live under `files/` here.
- Secrets (tokens, keys) never enter any of these files; they belong in the platform keychain (`VaultSecrets`).

## Data Models

### 1. Period
The root model representing a specific tracking timeframe.
- `id` (String): Unique identifier (e.g., UUID or "YYYY-MM").
- `name` (String): Display name (e.g., "January 2024"). Can be overridden by the user.
- `startDate` (DateTime): The exact day the period starts.
- `endDate` (DateTime): The exact day the period ends (computed based on the next period start if it exists, or as the same day in the next month, e.g., if period starts on 7th May, the last day is 6th June).
- `baseCurrency` (String): Currency code (e.g., "USD", "EUR").
- `lastModified` (DateTime): Last modification timestamp to track resume point.
- `categories` (List<Category>): All categories defined in this period.

### 2. Category
A grouping for expenses with budget limits and tracking behavior.
- `id` (String): Unique identifier.
- `name` (String): Display name.
- `description` (String?): A short description to indicate what payments could be tagged for this category.
- `isMandatory` (bool): If true, belongs to mandatory budget scope, otherwise optional/free budget.
- `limit` (double?): The overall budget limit for the category.
- `isDailyAllowance` (bool): If true, enables a daily allowance counter based on remaining limit and days left.
- `plannedExpenses` (List<PlannedExpense>): Upcoming or recurring planned expenses.
- `factExpenses` (List<FactExpense>): Actual spending records.

### 3. PlannedExpense
An expense that is expected/scheduled but hasn't necessarily occurred yet.
- `id` (String): Unique identifier.
- `description` (String): Must present a description (not just sum).
- `amount` (double): The scheduled value.
- `dueDate` (DueDate): When it should be paid. Can be:
  - Exact Date (e.g., 2024-01-15)
  - Day of Month (e.g., 15th of every month)
- `isCompleted` (bool): True if checked off (completed factually).

### 4. FactExpense
An actual tracking entry of spent money.
- `id` (String): Unique identifier.
- `amount` (double): The exact amount spent.
- `description` (String?): Optional comment or exact merchant.
- `timestamp` (DateTime): Keeps the exact order of the tracked expenses.

## Storage Operations
All reads and writes go through `VaultWorkspace` (`lib/src/storage/vault_workspace.dart`), a flat list/read/write/delete interface over the selected vault. Domain code never touches paths.
- **Load Period**: List the workspace, parse each sorted YAML into the `Period` Dart model, and report unreadable files instead of dropping them.
- **Save Period**: Serialize the `Period` Dart model into YAML, sort the keys, and write through the workspace. For a remote vault the write also marks the file dirty in `sync.json` before the bytes land.
- **Create Next Period**: Use the current period or a template. 
  - Keep `categories`.
  - Keep `plannedExpenses` (reset `isCompleted` flag).
  - Clear `factExpenses` (drop all facts, no exceptions).
