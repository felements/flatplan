# Stage 4: Core Logic & Computed Stats

## 1. Period Rollover Logic
When creating a new period (e.g., from January to February), the app must transition the data smoothly without copying historical facts.

### Steps to generate next Period:
1. **Base Object**: Duplicate the current `Period` object (or the `Template` object).
2. **Metadata**:
   - Update `id`, `name`, `startDate`, and `endDate` to match the new timeframe.
   - Update `lastModified` to current.
3. **Categories & Expenses**:
   - Keep all `Category` definitions.
   - Copy all `PlannedExpense` items, **BUT** set `isCompleted = false` for all of them.
   - Drop any `PlannedExpense` or `Category` that has an `isOneTime == true` flag, or if the `PlannedExpense` has an exact planned date (which inherently makes it one-time).
   - **CLEAR** all `FactExpense` items. Fact expenses are historical and never roll over.

## 2. Stat Computations
These calculations heavily drive the Dashboard UI and should be responsive (recalculated via State Management whenever an expense is modified).

### A. High-level Totals
- **Planned vs Planned**: `(Sum of all Income categories' Planned amounts) - (Sum of all Expense categories' Planned amounts)`
- **Fact vs Planned**: `(Sum of all Income categories' Fact amounts) - (Sum of all Expense categories' Planned amounts)`
- **Fact vs Fact**: `(Sum of all Income categories' Fact amounts) - (Sum of all Expense categories' Fact amounts)`

### B. In-Category Calculations
For every category:
- **Total Spent**: `Sum of all FactExpense amounts in this category`.
- **Remaining Limit**: `Category Limit - Total Spent`.
  - *If a limit is not set, this is infinity / unconstrained.*
- **Daily Allowance** (if enabled): 
  - `Days Remaining` = `Period.endDate - CurrentDate` (constrained to > 0).
  - `Daily Allowance` = `Remaining Limit / Days Remaining`.
- **Heat Indicator**: `min(1.0, Total Spent / limit)`. Becomes red when > 1.0.

### C. Total Spendings Overview
Calculated across all categories (both Mandatory and Optional scopes):
- **Total Free Spendings Remaining**: `Sum of (Remaining Limit) across all categories where (Remaining Limit > 0)`.
- **Total Out of Budget**: `Sum of absolute(Remaining Limit) across all categories where (Remaining Limit < 0)`.

*Note*: Completing a `PlannedExpense` (checking the checkbox) simply adds a corresponding `FactExpense` into the category (or is visually treated as a fact expense depending on the implementation details. Easiest approach is to insert a `FactExpense` with the identical amount and a "Planned: [Description]" comment).
