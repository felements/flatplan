# Stage 5: Implementation Plan (AI Prompts)

This document breaks down the development phases. When feeding this to an AI assistant, provide the previous specification files (`01_storage_models.md` through `04_core_logic_stats.md`) as context, then instruct the AI to execute these phases one by one.

## Phase 1: Setup & Storage Models
1. **Init**: Create a new Flutter desktop project. Add dependencies: `hooks_riverpod`, `go_router`, `freezed`, `yaml`, `path_provider`.
2. **Models Directory (`lib/src/models/`)**: Implement the data classes (`Period`, `Category`, `PlannedExpense`, `FactExpense`) using `freezed` or standard Dart data classes with JSON/YAML serialization.
3. **Storage Directory (`lib/src/storage/`)**: Create a `PeriodRepository` that can read/write these models to `.yaml` files in the app's documents directory. Sort dictionary keys alphabetically before saving.

## Phase 2: Core Logic & State Management
1. **Logic Directory (`lib/src/logic/`)**: Implement the rollover logic functions (create next period from current period/template, filtering `isOneTime` items, resetting `isCompleted`).
2. **Providers Directory (`lib/src/providers/`)**:
   - Create `currentPeriodNotifier` to hold the active period and handle mutations (add/remove expenses).
   - Add a debouncer to auto-save to the `PeriodRepository` locally on state mutation.
   - Create `periodStatsProvider` to compute totals, remaining budgets, and heat indicators as defined in `04_core_logic_stats.md`.

## Phase 3: Routing & Basic Navigation
1. **Router (`lib/src/routing/`)**: Set up `go_router` with routes for `/` (DashboardView), `/category/:id` (CategoryDetailView), and `/settings` (SettingsView).
2. **Shell**: Create a basic desktop layout frame (e.g., standard explicit sidebar or top app bar) hosting a `RouterOutlet`.

## Phase 4: UI Development (Dashboard & Categories)
1. **Views Directory (`lib/src/views/`)**: Build `DashboardView`. Hook it up to the stats provider to render the Summary Cards. Render the two lists of Categories (Mandatory and Optional) with heat indicator progress bars. 
2. **Build `CategoryDetailView`**: 
   - Render the Planned expenses list with checkboxes.
   - Render the Fact expenses list.
   - Create an input row/FAB to quickly add a new `FactExpense`. 
   - Ensure checking a planned expense correctly mutations the state (e.g., creates a linked fact expense).

## Phase 5: Polish & Template Management
1. **Settings / Initialization View**: Build the screen to define the `template.yaml` and generate new months.
2. **Polish**: Add empty states, error handling for corrupted YAML files, and configure window sizing for Desktop targets (`window_manager` or `desktop_window` package). Ensure the UI is clean to match a modern desktop experience.
