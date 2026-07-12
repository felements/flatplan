# Effective Budget = max(planned, limit) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A category's effective budget figure becomes `max(sum(plannedExpenses), limit)` when both are set (instead of `limit` always winning), with an amber warning indicator wherever the plan outgrows the limit.

**Architecture:** One new extension on `Category` (`plannedTotal`, `effectiveLimit`, `plannedExceedsLimit`) becomes the single source of truth. The three duplicated derivation sites (`periodStats` provider, dashboard's historical `_computeStats`, category detail's `_computeCategoryStats`) switch to it. `CategoryStats` gains a `plannedExceedsLimit` flag; `CategoryTile` and the category-detail header render an amber icon from it. Everything downstream (heat %, remaining, rollups, free balance) picks up the new semantics automatically because it already keys off the effective-limit variable.

**Tech Stack:** Flutter/Dart, Freezed (code-gen via build_runner), Riverpod 3 (riverpod_generator), flutter_test.

**Spec:** `docs/superpowers/specs/2026-07-12-planned-vs-limit-max-design.md`

## Global Constraints

- Core rule: `limit == null` → `sum(plannedExpenses)`; `limit != null` → `max(sum(plannedExpenses), limit)`. Applies to ALL category types including `income`.
- `plannedExceedsLimit` is true only when `limit != null` AND `sum(plannedExpenses) > limit` (strictly greater — equal is false).
- Indicator icon: `Icons.warning_amber_rounded`, color `Color(0xFFE0A030)` (the app's existing amber), tooltip text exactly `Planned expenses exceed the limit`.
- No changes to YAML storage or the `Category`/`PlannedExpense` data models — the rule is purely derived.
- Freezed/Riverpod files are generated: after editing any `@freezed`/`@riverpod` file, run `dart run build_runner build --delete-conflicting-outputs`. Never hand-edit `*.freezed.dart` / `*.g.dart`.
- After each task, `flutter analyze` must report no new issues.

---

### Task 1: `CategoryBudget` extension (core rule)

**Files:**
- Create: `lib/src/models/category_budget.dart`
- Modify: `lib/src/models/models.dart` (add export)
- Test: `test/category_budget_test.dart`

**Interfaces:**
- Consumes: `Category` (existing Freezed model at `lib/src/models/category.dart` — fields `double? limit`, `List<PlannedExpense> plannedExpenses`).
- Produces: `extension CategoryBudget on Category` with getters `double get plannedTotal`, `double get effectiveLimit`, `bool get plannedExceedsLimit`. Exported via `package:flatplan/src/models/models.dart`. Tasks 2, 3, and 5 call these getters.

- [ ] **Step 1: Write the failing test**

Create `test/category_budget_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flatplan/src/models/models.dart';

PlannedExpense _planned(String id, double amount) => PlannedExpense(
  id: id,
  description: 'item $id',
  amount: amount,
  dueDate: DueDate.exact(date: DateTime(2026, 7, 15)),
);

void main() {
  group('CategoryBudget extension', () {
    test('no limit: effectiveLimit is sum of planned, flag is false', () {
      final cat = Category(
        id: 'c1',
        name: 'Groceries',
        plannedExpenses: [_planned('p1', 100), _planned('p2', 50)],
      );
      expect(cat.plannedTotal, 150);
      expect(cat.effectiveLimit, 150);
      expect(cat.plannedExceedsLimit, isFalse);
    });

    test('no limit, no planned: effectiveLimit is 0', () {
      final cat = Category(id: 'c1', name: 'Empty');
      expect(cat.plannedTotal, 0);
      expect(cat.effectiveLimit, 0);
      expect(cat.plannedExceedsLimit, isFalse);
    });

    test('limit only (no planned): effectiveLimit is limit', () {
      final cat = Category(id: 'c1', name: 'Fun', limit: 300);
      expect(cat.effectiveLimit, 300);
      expect(cat.plannedExceedsLimit, isFalse);
    });

    test('limit greater than planned sum: limit wins, flag false', () {
      final cat = Category(
        id: 'c1',
        name: 'Fun',
        limit: 300,
        plannedExpenses: [_planned('p1', 100)],
      );
      expect(cat.effectiveLimit, 300);
      expect(cat.plannedExceedsLimit, isFalse);
    });

    test('planned sum greater than limit: planned wins, flag true', () {
      final cat = Category(
        id: 'c1',
        name: 'Rent',
        limit: 1000,
        plannedExpenses: [_planned('p1', 700), _planned('p2', 500)],
      );
      expect(cat.effectiveLimit, 1200);
      expect(cat.plannedExceedsLimit, isTrue);
    });

    test('planned sum equal to limit: flag is false', () {
      final cat = Category(
        id: 'c1',
        name: 'Rent',
        limit: 1000,
        plannedExpenses: [_planned('p1', 1000)],
      );
      expect(cat.effectiveLimit, 1000);
      expect(cat.plannedExceedsLimit, isFalse);
    });

    test('income category follows the same rule', () {
      final cat = Category(
        id: 'c1',
        name: 'Salary',
        type: CategoryType.income,
        limit: 3000,
        plannedExpenses: [_planned('p1', 3500)],
      );
      expect(cat.effectiveLimit, 3500);
      expect(cat.plannedExceedsLimit, isTrue);
    });

    test('limit of 0 with planned items: planned wins, flag true', () {
      final cat = Category(
        id: 'c1',
        name: 'ZeroCap',
        limit: 0,
        plannedExpenses: [_planned('p1', 50)],
      );
      expect(cat.effectiveLimit, 50);
      expect(cat.plannedExceedsLimit, isTrue);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/category_budget_test.dart`
Expected: FAIL to compile with errors like `The getter 'plannedTotal' isn't defined for the type 'Category'`.

- [ ] **Step 3: Write the extension**

Create `lib/src/models/category_budget.dart`:

```dart
import 'dart:math' as math;

import 'category.dart';

/// Derived budget figures for a [Category].
///
/// [effectiveLimit] is the single figure all budget math keys off:
/// planned total when no limit is set, otherwise the max of the two —
/// a limit never hides a plan that has outgrown it.
extension CategoryBudget on Category {
  /// Sum of all planned expense amounts.
  double get plannedTotal =>
      plannedExpenses.fold<double>(0, (sum, e) => sum + e.amount);

  /// The effective budget figure for this category.
  double get effectiveLimit {
    final planned = plannedTotal;
    final hardLimit = limit;
    if (hardLimit == null) return planned;
    return math.max(planned, hardLimit);
  }

  /// True when a limit is set and planned expenses strictly exceed it.
  bool get plannedExceedsLimit {
    final hardLimit = limit;
    return hardLimit != null && plannedTotal > hardLimit;
  }
}
```

Add the export to `lib/src/models/models.dart` (after the existing `export 'category.dart';` line):

```dart
export 'category_budget.dart';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/category_budget_test.dart`
Expected: PASS (8 tests).

- [ ] **Step 5: Analyze and commit**

Run: `flutter analyze`
Expected: `No issues found!` (or only issues that pre-date this change — verify with `git stash && flutter analyze && git stash pop` if unsure).

```bash
git add lib/src/models/category_budget.dart lib/src/models/models.dart test/category_budget_test.dart
git commit -m "feat: add CategoryBudget extension with max(planned, limit) rule"
```

---

### Task 2: `CategoryStats.plannedExceedsLimit` + switch `periodStats` provider

**Files:**
- Modify: `lib/src/providers/period_stats_provider.dart:14-31` (CategoryStats fields), `:80-92` (derivation), `:179-196` (construction)
- Regenerate: `lib/src/providers/period_stats_provider.freezed.dart` (via build_runner — do not hand-edit)
- Test: `test/period_stats_provider_test.dart`

**Interfaces:**
- Consumes: `CategoryBudget` extension from Task 1 (`category.plannedTotal`, `category.effectiveLimit`, `category.plannedExceedsLimit`), already available via the file's existing `import '../models/models.dart';`.
- Produces: `CategoryStats` gains `@Default(false) bool plannedExceedsLimit`. Tasks 3, 4, 5 read `CategoryStats.plannedExceedsLimit`. The meaning of `CategoryStats.limit` is now the effective limit (max rule) — unchanged field name, new semantics.

- [ ] **Step 1: Write the failing test**

Create `test/period_stats_provider_test.dart`. It seeds a real `PeriodRepository` in a temp dir (same pattern as `test/storage_test.dart`) and overrides `periodRepositoryProvider`, so the real `currentPeriodProvider` → `periodStats` chain runs:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flatplan/src/models/models.dart';
import 'package:flatplan/src/providers/period_stats_provider.dart';
import 'package:flatplan/src/providers/repository_provider.dart';
import 'package:flatplan/src/storage/period_repository.dart';

PlannedExpense _planned(String id, double amount) => PlannedExpense(
  id: id,
  description: 'item $id',
  amount: amount,
  dueDate: DueDate.exact(date: DateTime(2099, 1, 1)),
);

FactExpense _fact(String id, double amount) => FactExpense(
  id: id,
  amount: amount,
  timestamp: DateTime(2026, 1, 1),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('periodStats with max(planned, limit) rule', () {
    late Directory tempDir;
    late ProviderContainer container;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('flatplan_stats_test_');
      final repo = PeriodRepository(directoryPath: tempDir.path);

      // Period starts 5 days ago so currentPeriodProvider picks it
      // (effective end = start + 30 days, which spans today).
      final start = DateTime.now().subtract(const Duration(days: 5));
      final period = Period(
        id: 'test-period',
        name: 'Test Period',
        startDate: DateTime(start.year, start.month, start.day),
        baseCurrency: 'EUR',
        lastModified: DateTime(2026, 1, 1),
        categories: [
          // planned (1200) > limit (1000) → effective 1200, flag true
          Category(
            id: 'rent',
            name: 'Rent',
            type: CategoryType.mandatoryExpense,
            limit: 1000,
            plannedExpenses: [_planned('r1', 700), _planned('r2', 500)],
            factExpenses: [_fact('rf1', 500)],
          ),
          // limit (300) > planned (100) → effective 300, flag false
          Category(
            id: 'fun',
            name: 'Fun',
            type: CategoryType.optionalExpense,
            limit: 300,
            plannedExpenses: [_planned('f1', 100)],
          ),
          // no limit → effective = planned (400), flag false
          Category(
            id: 'groceries',
            name: 'Groceries',
            type: CategoryType.optionalExpense,
            plannedExpenses: [_planned('g1', 400)],
          ),
          // income: planned (3500) > limit (3000) → effective 3500, flag true
          Category(
            id: 'salary',
            name: 'Salary',
            type: CategoryType.income,
            limit: 3000,
            plannedExpenses: [_planned('s1', 3500)],
            factExpenses: [_fact('sf1', 2000)],
          ),
        ],
      );
      await repo.savePeriod(period);

      container = ProviderContainer(
        overrides: [periodRepositoryProvider.overrideWith((ref) => repo)],
      );
    });

    tearDown(() {
      container.dispose();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('per-category effective limits and flags', () async {
      final stats = await container.read(periodStatsProvider.future);
      expect(stats, isNotNull);

      final byId = {for (final c in stats!.categoryStats) c.categoryId: c};

      expect(byId['rent']!.limit, 1200);
      expect(byId['rent']!.plannedExceedsLimit, isTrue);
      expect(byId['rent']!.remaining, 700); // 1200 - 500 spent
      expect(byId['rent']!.heatPercentage, closeTo(500 / 1200, 0.0001));

      expect(byId['fun']!.limit, 300);
      expect(byId['fun']!.plannedExceedsLimit, isFalse);

      expect(byId['groceries']!.limit, 400);
      expect(byId['groceries']!.plannedExceedsLimit, isFalse);

      expect(byId['salary']!.limit, 3500);
      expect(byId['salary']!.plannedExceedsLimit, isTrue);
    });

    test('rollups reflect the max rule', () async {
      final stats = await container.read(periodStatsProvider.future);
      expect(stats, isNotNull);

      expect(stats!.totalMandatoryBudget, 1200);
      expect(stats.totalOptionalBudget, 700); // 300 + 400
      expect(stats.totalBudget, 1900);
      expect(stats.totalIncome, 3500);
      expect(stats.totalFactIncome, 2000);
      expect(stats.totalSpent, 500);
      expect(stats.overallRemaining, 1400); // 1900 - 500
      // free balance = factIncome - sum(max(spent, effectiveLimit)) per
      // expense category = 2000 - (1200 + 300 + 400)
      expect(stats.remainingFreeBalance, 100);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/period_stats_provider_test.dart`
Expected: FAIL to compile with `The getter 'plannedExceedsLimit' isn't defined for the type 'CategoryStats'`.

- [ ] **Step 3: Add the field and switch the derivation**

In `lib/src/providers/period_stats_provider.dart`, add the field to `CategoryStats` (after `required bool isDailyAllowance,`):

```dart
      required bool isDailyAllowance,
      @Default(false) bool plannedExceedsLimit,
```

Replace the derivation block (currently lines 81-88):

```dart
    // 2. Calculate Planned constraints
    final planned = category.plannedTotal;

    // 3. Effective budget: max of planned total and hard limit when a
    //    limit is set, otherwise the planned total.
    final limit = category.effectiveLimit;
```

(This removes the local `fold` over `plannedExpenses` and the `category.limit ?? planned` line; the `remaining` / `heatPercentage` / `isOverBudget` lines below stay unchanged.)

In the `CategoryStats(...)` construction (currently lines 180-195), add after `isDailyAllowance: category.isDailyAllowance,`:

```dart
        isDailyAllowance: category.isDailyAllowance,
        plannedExceedsLimit: category.plannedExceedsLimit,
```

- [ ] **Step 4: Regenerate Freezed code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: exits 0, `period_stats_provider.freezed.dart` regenerated.

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/period_stats_provider_test.dart test/category_budget_test.dart`
Expected: PASS (all tests).

- [ ] **Step 6: Analyze and commit**

Run: `flutter analyze`
Expected: no new issues. Note: `dashboard_view.dart` and `category_detail_view.dart` still construct `CategoryStats` without the new field — that compiles because the field has a default; they are updated in Tasks 3 and 5.

```bash
git add lib/src/providers/period_stats_provider.dart lib/src/providers/period_stats_provider.freezed.dart test/period_stats_provider_test.dart
git commit -m "feat: periodStats uses max(planned, limit) effective budget"
```

---

### Task 3: Dashboard historical `_computeStats` switches to the extension

**Files:**
- Modify: `lib/src/views/dashboard_view.dart:502-511` (derivation), `:603-620` (CategoryStats construction)

**Interfaces:**
- Consumes: `CategoryBudget` extension (Task 1; `import '../models/models.dart';` already present in the file) and `CategoryStats.plannedExceedsLimit` (Task 2).
- Produces: historical periods shown on the dashboard use identical semantics to the live `periodStats` provider. No new API.

There is no test for this private widget method (it is a known duplicate of the provider logic — consolidation is explicitly out of scope per the spec). Verification is the analyzer plus the mirrored code matching Task 2's tested logic exactly.

- [ ] **Step 1: Switch the derivation**

In `_computeStats` in `lib/src/views/dashboard_view.dart`, replace (currently lines 507-511):

```dart
      final planned = category.plannedExpenses.fold<double>(
        0,
        (prev, e) => prev + e.amount,
      );
      final limit = category.limit ?? planned;
```

with:

```dart
      final planned = category.plannedTotal;
      final limit = category.effectiveLimit;
```

- [ ] **Step 2: Populate the flag in CategoryStats**

In the same method's `CategoryStats(...)` construction (currently line 603-620), add after `isDailyAllowance: category.isDailyAllowance,`:

```dart
          isDailyAllowance: category.isDailyAllowance,
          plannedExceedsLimit: category.plannedExceedsLimit,
```

- [ ] **Step 3: Analyze and run all tests**

Run: `flutter analyze && flutter test`
Expected: no new analyzer issues; all tests PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/src/views/dashboard_view.dart
git commit -m "feat: dashboard historical stats use max(planned, limit) rule"
```

---

### Task 4: Amber indicator on `CategoryTile` + dashboard wiring

**Files:**
- Modify: `lib/src/components/category_tile.dart` (new param + icon), `lib/src/views/dashboard_view.dart:459-486` (pass the flag)
- Test: `test/category_tile_test.dart`

**Interfaces:**
- Consumes: `CategoryStats.plannedExceedsLimit` (Task 2).
- Produces: `CategoryTile` gains constructor param `bool plannedExceedsLimit` (named, defaults to `false`). Dashboard passes `c.plannedExceedsLimit`.

- [ ] **Step 1: Write the failing widget test**

Create `test/category_tile_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flatplan/src/components/category_tile.dart';

Widget _tile({required bool plannedExceedsLimit}) => MaterialApp(
  home: Scaffold(
    body: CategoryTile(
      title: 'Rent',
      spentAmount: '€500',
      limitAmount: '€1,200',
      heatPercentage: 0.42,
      isOverBudget: false,
      plannedExceedsLimit: plannedExceedsLimit,
      onTap: () {},
    ),
  ),
);

void main() {
  testWidgets('shows amber warning icon when planned exceeds limit', (
    tester,
  ) async {
    await tester.pumpWidget(_tile(plannedExceedsLimit: true));

    final iconFinder = find.byIcon(Icons.warning_amber_rounded);
    expect(iconFinder, findsOneWidget);

    final tooltip = find.ancestor(
      of: iconFinder,
      matching: find.byType(Tooltip),
    );
    expect(tooltip, findsOneWidget);
    expect(
      tester.widget<Tooltip>(tooltip).message,
      'Planned expenses exceed the limit',
    );
  });

  testWidgets('no warning icon when flag is false', (tester) async {
    await tester.pumpWidget(_tile(plannedExceedsLimit: false));
    expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/category_tile_test.dart`
Expected: FAIL to compile with `No named parameter with the name 'plannedExceedsLimit'`.

- [ ] **Step 3: Add the param and icon to CategoryTile**

In `lib/src/components/category_tile.dart`, add the field after `final bool isIncome;` (line 13):

```dart
  final bool isIncome;
  final bool plannedExceedsLimit;
```

Add the constructor param after `this.isIncome = false,` (line 27):

```dart
    this.isIncome = false,
    this.plannedExceedsLimit = false,
```

In the top row, after the `'${widget.spentAmount} / ${widget.limitAmount}'` `Text` widget (closes at line 130, before the `],` of the Row's children), add:

```dart
                        if (widget.plannedExceedsLimit) ...[
                          const SizedBox(width: 6),
                          const Tooltip(
                            message: 'Planned expenses exceed the limit',
                            child: Icon(
                              Icons.warning_amber_rounded,
                              size: 16,
                              color: Color(0xFFE0A030),
                            ),
                          ),
                        ],
```

- [ ] **Step 4: Wire the flag from the dashboard**

In `_buildCategorySection` in `lib/src/views/dashboard_view.dart`, in the `CategoryTile(` construction (starts line 460), add after `isIncome: c.type == CategoryType.income,`:

```dart
            isIncome: c.type == CategoryType.income,
            plannedExceedsLimit: c.plannedExceedsLimit,
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/category_tile_test.dart && flutter analyze`
Expected: PASS (2 tests); no new analyzer issues.

- [ ] **Step 6: Commit**

```bash
git add lib/src/components/category_tile.dart lib/src/views/dashboard_view.dart test/category_tile_test.dart
git commit -m "feat: amber indicator on category tile when planned exceeds limit"
```

---

### Task 5: Category detail view — extension + header indicator

**Files:**
- Modify: `lib/src/views/category_detail_view.dart:137-162` (`_computeCategoryStats`), `:216-223` (header subtitle)

**Interfaces:**
- Consumes: `CategoryBudget` extension (Task 1; `import '../models/models.dart';` already present) and `CategoryStats.plannedExceedsLimit` (Task 2).
- Produces: detail view uses identical budget semantics; header shows the same amber indicator. No new API.

- [ ] **Step 1: Switch `_computeCategoryStats` to the extension**

In `lib/src/views/category_detail_view.dart`, replace (currently lines 142-146):

```dart
    final planned = category.plannedExpenses.fold<double>(
      0,
      (prev, e) => prev + e.amount,
    );
    final limit = category.limit ?? planned;
```

with:

```dart
    final planned = category.plannedTotal;
    final limit = category.effectiveLimit;
```

and in the `return CategoryStats(` below, add after `isDailyAllowance: category.isDailyAllowance,`:

```dart
      isDailyAllowance: category.isDailyAllowance,
      plannedExceedsLimit: category.plannedExceedsLimit,
```

- [ ] **Step 2: Add the header indicator**

In `_buildHeader`, the subtitle is currently (lines 216-223):

```dart
                Text(
                  category.type == CategoryType.income
                      ? 'Received: ${format.format(catStats.totalSpent)} / Expected: ${format.format(catStats.limit)}'
                      : 'Spent: ${format.format(catStats.totalSpent)} / Limit: ${format.format(catStats.limit)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
```

Replace it with a Row so the icon sits next to the text:

```dart
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      category.type == CategoryType.income
                          ? 'Received: ${format.format(catStats.totalSpent)} / Expected: ${format.format(catStats.limit)}'
                          : 'Spent: ${format.format(catStats.totalSpent)} / Limit: ${format.format(catStats.limit)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (catStats.plannedExceedsLimit) ...[
                      const SizedBox(width: 6),
                      const Tooltip(
                        message: 'Planned expenses exceed the limit',
                        child: Icon(
                          Icons.warning_amber_rounded,
                          size: 16,
                          color: Color(0xFFE0A030),
                        ),
                      ),
                    ],
                  ],
                ),
```

- [ ] **Step 3: Analyze and run the full test suite**

Run: `flutter analyze && flutter test`
Expected: no new analyzer issues; all tests PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/src/views/category_detail_view.dart
git commit -m "feat: category detail uses max(planned, limit) rule with header indicator"
```

---

### Task 6: End-to-end sanity check

**Files:** none modified.

**Interfaces:** none — verification only.

- [ ] **Step 1: Full suite**

Run: `flutter test && flutter analyze`
Expected: all tests PASS, no new analyzer issues.

- [ ] **Step 2: Manual smoke test**

Run: `flutter run -d macos`

Verify against a category that has both a limit and planned expenses summing above it (create one if needed):
1. Dashboard tile shows `spent / <planned sum>` (not the limit) with the amber icon; hovering the icon shows "Planned expenses exceed the limit".
2. Section subtotal and the Total Budget summary card include the larger figure.
3. Category detail header shows the larger figure and the amber icon; the Remaining badge measures against it.
4. A category whose limit exceeds its planned sum shows the limit and NO icon.
5. Quit the app.
