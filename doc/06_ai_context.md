# AI Context: FlatPlan Implementation State

This document provides context for future AI assistants continuing the development of FlatPlan. Always read this file before proceeding with new implementation phases.

## Current Progress
- **Stage 1 (Setup & Storage Models)** is **COMPLETED**.
- The project is initialized as a Flutter application with Desktop support (Windows, macOS, Linux).

## Important Technical Decisions & Deviations

1. **State Management Constraint**: The user's original custom instructions prohibited third-party state managers, but after assessing the complexity of derived statistical state for this app, we received explicit permission to use **Riverpod 3.x**. We are using `hooks_riverpod`, `riverpod_annotation`, and `riverpod_generator` code generation.
2. **Data Models (`lib/src/models/`)**: 
   - We are using `freezed` and `json_annotation` for our data models. 
   - We are using `sealed class` (e.g., `sealed class Period with _$Period`) to satisfy Dart 3+ and Freezed 3+ requirements for abstract mixins. 
   - Global `snake_case` JSON serialization is enforced in `build.yaml`.
3. **Storage & YAML formatting (`lib/src/storage/period_repository.dart`)**:
   - The app reads and writes YAML files to the local documents directory via `path_provider`.
   - To satisfy the Git-friendly sorting requirement, we use a recursive key-sorting function utilizing `SplayTreeMap`.
   - We use the `json2yaml` package to output cleanly formatted YAML when saving models.

## Next Steps

When resuming development, begin with **Phase 4: UI Development (Dashboard & Categories)** found in `05_implementation_plan.md`.

**Required Initial Context for Phase 4:**
- Review `03_ui_pages_components.md` to understand the complex UI structures for the generic desktop elements.
- We have Riverpod state (`periodStatsProvider` and `currentPeriodProvider`) ready to hook into the Dashboard cards and list tiles.
- The `Category Detail View` requires implementing the checkboxes for planned expenses and a list of chronologically listed factual expenses.
