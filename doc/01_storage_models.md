# Stage 1: Storage Structure & Models

## Overview
The app relies on local file storage using **YAML files**. To prevent merge conflicts and line drift in Git, all YAML keys must be sorted alphabetically when saved. The exception is the list of fact expenses which must preserve chronological order (implemented via an incrementing order number or timestamp for each expense record). Every tracking period (e.g., a month) is represented by a single YAML file.

## File Types
1. **Period Data File**: Contains all data (categories, planned, and factual expenses) for a specific period.
2. **Template File**: A base structure without factual expenses, used to quickly instantiate a new period.

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
- **Load Period**: Parse a sorted YAML into the `Period` Dart model.
- **Save Period**: Serialize the `Period` Dart model into YAML, sort the keys, and write to disk.
- **Create Next Period**: Use the current period or a template. 
  - Keep `categories`.
  - Keep `plannedExpenses` (reset `isCompleted` flag).
  - Clear `factExpenses` (drop all facts, no exceptions).
