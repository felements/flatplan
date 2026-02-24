# Domain Glossary

Quick-reference for the domain language used throughout FlatPlan's codebase and specification documents.

## Core Entities

| Entity | Dart Class | Description |
|---|---|---|
| **Period** | `Period` | The root tracking unit — a timeframe (typically one month) containing all categories and expenses. Stored as a single YAML file. Has `startDate`, `endDate`, `baseCurrency`, and a list of `categories`. |
| **Category** | `Category` | A named budget group within a period. Has an optional spending `limit`, a `isMandatory` flag for scope classification, and contains both planned and factual expenses. |
| **Planned Expense** | `PlannedExpense` | A scheduled/expected expense inside a category. Has a required `description`, `amount`, `dueDate`, and an `isCompleted` flag that is checked off when paid. Rolls over to the next period with `isCompleted` reset to `false`. |
| **Fact Expense** | `FactExpense` | An actual recorded spending entry. Has `amount`, optional `description`, and a `timestamp` that preserves chronological order. Never rolls over — cleared on period creation. |
| **Due Date** | `DueDate` | A sealed union describing when a planned expense is due. Two variants: `exact` (specific `DateTime`) and `dayOfMonth` (recurring day number). |

## Key Domain Concepts

| Concept | Description |
|---|---|
| **Mandatory vs Optional Scope** | Every category is either mandatory (`isMandatory: true`) or optional. This split lets the user see the "free budget" remaining after all mandatory commitments. |
| **Limit** | An optional spending cap on a category. When set, enables remaining-budget and daily-allowance calculations. |
| **Daily Allowance** | Per-category feature (`isDailyAllowance: true`). Computes `remainingLimit / daysLeft` to show how much the user can spend per day for the rest of the period. |
| **Heat Indicator** | A 0.0–1.0+ ratio (`totalSpent / limit`) that visually signals overspending — turns red when > 1.0. |
| **Period Rollover** | Creating the next period from an existing one. Keeps categories and planned expenses (resetting `isCompleted`), drops all fact expenses. Planned expenses with an exact due date are treated as one-time and dropped. |
| **Cold-Start** | Creating the very first period when no previous periods or templates exist. Uses `createEmptyPeriod` to bootstrap a blank period. |
| **Template** | A period-like YAML file without fact expenses, used as a reusable base for instantiating new periods. |
| **Base Currency** | A per-period currency code (e.g. `EUR`, `USD`) stored in `baseCurrency`. |
