# Stage 2: Architecture & State Management

## App Architecture Overview
The app will use a **Feature-first** (layer-by-feature) architecture to maintain high cohesion. The features align with the core entities:
1. `period_management` (Handling period lifecycle: create, load, list files)
2. `budget_dashboard` (Viewing the current period totals)
3. `category_details` (Managing planned and factual expenses inside a category)
4. `settings` (Managing default preferences and templates)

## Tech Stack & Libraries
- **Framework**: Flutter (Targeting Desktop: Windows, macOS, Linux).
- **State Management**: `hooks_riverpod` or `riverpod` (v3 with code generators and riverpod_annotation) using Notifiers for predictable state mutations and easy testability.
- **Routing**: `go_router` for declarative navigation between dashboard, category details, and period creation screens.
- **Storage / File I/O**:
  - `path_provider`: To resolve the local documents/app-data directory (or a custom git repo path selected by the user).
  - `yaml` (parsing) and `json2yaml` (or equivalent writer) to serialize models.
  - *Note*: Ensure the YAML writer sorts keys alphabetically.
- **Modelling**: `freezed` or `json_serializable` to generate `fromJson` / `toJson`.

## State Management Flow
1. **Repository Layer**:
   - `PeriodRepository`: Reads/Writes the period YAML files. Defines methods like `List<String> getAvailablePeriods()`, `Period loadPeriod(String id)`, `void savePeriod(Period period)`.
2. **Provider / Notifier Layer**:
   - `periodListProvider`: Provides the list of available files to be loaded.
   - `currentPeriodNotifier`: The active loaded `Period`. It exposes methods like:
     - `addFactExpense(categoryId, expense)`
     - `removeFactExpense(categoryId, expenseId)`
     - `togglePlannedExpense(categoryId, expenseId)`
     - `updateCategoryLimit(categoryId, newLimit)`
   - *Side-effect*: Every time the `currentPeriodNotifier` mutates the state, it debounces for 1-2 seconds and calls `PeriodRepository.savePeriod(state)`.
3. **Computed Providers**:
   - `periodStatsProvider`: Listens to `currentPeriodNotifier` and calculates the totals (Planned to Facts, Remaining limits, Heat indicators). Keeps complex math out of the UI.

## File System Strategy
- User configures a **root directory** (which they can independently initialize as a git repository).
- Files inside the directory:
  - `template.yaml` (The base template).
  - `YYYY_MM.yaml` (The tracking files).
- The app watches the directory (using `Directory.watch()`) or re-reads on focus to stay synced if git pull changes the files underneath.
