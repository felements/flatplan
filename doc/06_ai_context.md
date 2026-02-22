# AI Context: FlatPlan Implementation State

This document provides context for future AI assistants continuing the development of FlatPlan. Always read this file before proceeding with new implementation phases.

## Current Progress
- **Stages 1 through 5** are **COMPLETED**.
- The project is initialized as a Flutter application with Desktop support (Windows, macOS, Linux).
- The full routing (GoRouter) and responsive `AppShell` with a `NavigationRail` is live.
- The Dashboard, Category Details, and Settings pages are live, tracking dynamic expenditures mapping via Riverpod.
- The business logic to generate brand new tracking periods based on previous YAML configs is functional and saves to the user Documents dir.

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

## Domain Glossary

See [`07_domain_glossary.md`](07_domain_glossary.md) for a full reference of all domain entities and concepts.

## Next Steps

The defined original implementation pipeline (`05_implementation_plan.md`) is now fully built out. 

When resuming development, you should work with the user to outline **Post-Launch Feature Requests / Upgrades (Phase 6)**. This could involve items like:
- Integrating Charts for visual analytics.
- Defining strict `template.yaml` fallback parsing when the user deletes the active tracking period from disk manually.
- Building the UI implementation for deleting a specific `FactExpense`.
