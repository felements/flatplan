# Effective budget = max(planned, limit)

**Date:** 2026-07-12
**Status:** Approved

## Problem

A category's effective budget figure is currently `category.limit ?? sum(plannedExpenses)`
(see `lib/src/providers/period_stats_provider.dart:88`). When a category has both a
spending limit and planned expenses, the limit always wins — even when the planned
expenses add up to more than the limit. This under-reports the real commitment: heat
percentage, remaining, total budget, and free balance all measure against a figure
smaller than what is actually planned.

## Decision

For a category with both planned expenses and a limit, the effective budget figure is
the **maximum** of the two.

### Core rule

- `limit == null` → `sum(plannedExpenses)`
- `limit != null` → `max(sum(plannedExpenses), limit)`

When there are no planned expenses the sum is 0, so a set limit still wins (unchanged
behavior). The rule applies uniformly to all category types, including `income`, where
the figure means "expected income".

A companion flag **`plannedExceedsLimit`** is true when `limit != null` and
`sum(plannedExpenses) > limit` (strictly greater).

### Edge case: `limit: 0`

A category with `limit: 0` and planned items now budgets the planned sum (and shows the
indicator), whereas previously a 0 limit hard-capped the budget at 0. This is the max
rule applied consistently, and is intentional.

## Architecture

### Single source of truth

New extension on `Category` in `lib/src/models/category_budget.dart` with three getters:

- `plannedTotal` — `sum(plannedExpenses.amount)`
- `effectiveLimit` — the core rule above
- `plannedExceedsLimit` — the flag above

### Call sites switched to the extension

The derivation is currently duplicated in three places; all three switch to the
extension so the rule cannot drift:

1. `lib/src/providers/period_stats_provider.dart:88` — main `periodStats` provider
2. `lib/src/views/dashboard_view.dart:511` — `_computeStats` for historical periods
3. `lib/src/views/category_detail_view.dart:146` — `_computeCategoryStats`

Everything downstream keys off that one effective-limit variable and picks up the new
semantics automatically: `heatPercentage`, `remaining`, `isOverBudget`, section
subtotals, `totalBudget`, `totalIncome`, and the free-balance computation (which
already uses `max(spent, limit)`).

### Stats model

`CategoryStats` (in `period_stats_provider.dart`) gains a `plannedExceedsLimit` bool
field, populated from the extension, so UI components can render the indicator without
recomputing. The dashboard and category-detail duplicate computations populate the same
flag via the extension.

## UI indicator

When `plannedExceedsLimit` is true, show a small amber warning icon next to the budget
figure, with tooltip "Planned expenses exceed the limit":

- Category tile: next to the `"{spent} / {limit}"` text
  (`lib/src/components/category_tile.dart:118`)
- Category detail header: next to the "Spent / Limit" figure
  (`lib/src/views/category_detail_view.dart:218`)

The heat/progress bar itself does not change color or meaning — it continues to show
spent vs. effective budget.

## Testing

There is currently no test coverage for any of these computations. Add:

1. **Extension unit tests** (`test/category_budget_test.dart`) covering: no limit;
   limit only (no planned); limit > planned sum; planned sum > limit; planned sum ==
   limit (flag must be false); income category; `limit: 0` with planned items.
2. **Provider-level test** of `periodStats` on a sample `Period` verifying the rollups
   (`totalBudget`, `overallRemaining`, `remainingFreeBalance`, per-category
   `heatPercentage`/`remaining`/`plannedExceedsLimit`) reflect the max rule.

## Out of scope

- Consolidating the three duplicated stats computations into one shared module
  (worthwhile, but an independent refactor).
- Any change to YAML storage or the `Category`/`PlannedExpense` data model — the rule
  is purely derived.
- Progress-bar color changes or other indicator treatments beyond the amber icon.
