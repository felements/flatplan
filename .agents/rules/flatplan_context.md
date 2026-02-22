---
trigger: always_on
---

# FlatPlan Project Context

## Application Overview
FlatPlan is a Flutter desktop budget-tracking app (Windows, macOS, Linux) using local YAML file storage. Full specification is in the `doc/` folder (`01_storage_models.md` through `05_implementation_plan.md`). Always consult these documents for detailed requirements.

## Current Progress
- **Stages 1 through 5** are **COMPLETED**.
- Flutter desktop app with GoRouter routing and responsive `AppShell` with `NavigationRail`.
- Dashboard, Category Details, and Settings pages are live.
- Period rollover logic generates new periods from existing ones or from scratch (cold-start).
- Periods are persisted as sorted YAML files in `~/Documents/flatplan/periods/`.

## Important Technical Decisions & Deviations

1. **State Management**: Riverpod 3.x (`hooks_riverpod`, `riverpod_annotation`, `riverpod_generator`) — explicit user permission overriding the default Flutter rules.
2. **Data Models** (`lib/src/models/`): `freezed` + `json_annotation` with `sealed class` syntax. Global `snake_case` serialization enforced in `build.yaml`.
3. **Storage** (`lib/src/storage/period_repository.dart`): YAML files via `path_provider`, recursive key-sorting with `SplayTreeMap`, output via `json2yaml`.

## Key Architecture
- `lib/src/models/` — Freezed data classes: `Period`, `Category`, `PlannedExpense`, `FactExpense`, `DueDate`
- `lib/src/storage/` — `PeriodRepository` for YAML read/write
- `lib/src/logic/` — `createNextPeriod`, `createEmptyPeriod` rollover/bootstrap functions
- `lib/src/providers/` — Riverpod providers: `currentPeriodProvider`, `periodStatsProvider`, `periodRepositoryProvider`
- `lib/src/routing/` — GoRouter with `StatefulShellRoute` (Dashboard + Settings branches)
- `lib/src/views/` — `DashboardView`, `CategoryDetailView`, `SettingsView`, `AppShell`
- `lib/src/components/` — `CategoryTile`, `SummaryCard`

## Domain Glossary
See `doc/07_domain_glossary.md` for a full reference of domain entities (Period, Category, PlannedExpense, FactExpense, DueDate) and key concepts (Mandatory/Optional scope, Daily Allowance, Heat Indicator, Period Rollover, Cold-Start, Template, Base Currency).
