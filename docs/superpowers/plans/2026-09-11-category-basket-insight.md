# Category Pace and Basket Insights Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the degenerate "spend X every N days" figure on daily-allowance categories with two insights — a spending trend that projects the period total against the limit, and a basket insight that gives a safe per-shop amount after reserving for small incidental spending.

**Architecture:** All derived figures are pure functions in `lib/src/logic/`, consumed through the single `categoryStatsFor` entry point that the dashboard, category detail screen, stats provider and Markdown snapshot already share. History is read by **period membership** — which period file an expense lives in — never from `FactExpense.timestamp`, which records entry time rather than spend time. New logic lands in three new files; the obsolete `allowance_pace.dart` is deleted in the final task, so every intermediate task compiles and tests green.

**Tech Stack:** Flutter (desktop), Riverpod 3.x with `riverpod_annotation`, `freezed` + `json_serializable` (global `snake_case` via `build.yaml`), `intl` for currency formatting, `flutter_test` for unit and widget tests.

**Spec:** `docs/superpowers/specs/2026-09-11-category-basket-insight-design.md`

## Global Constraints

- History window for basket statistics is **fixed at 3 complete prior periods**, minimum **2**. Not configurable.
- Basket statistics take the **worst** value of each statistic across the window (max snack share, min trip spacing), never the mean.
- The snack reserve is anchored to `category.effectiveLimit`, **not** to `remaining`, and floors at zero.
- Trend uses the **single most recent complete prior period**, not an average.
- Prior-period history is matched by **category name**, normalised with `.trim().toLowerCase()`, because `createNextPeriod` regenerates category ids on every rollover.
- Never read `FactExpense.timestamp` for history windowing.
- All new model fields serialise `snake_case` (enforced globally in `build.yaml`); absent keys must deserialise to `null` and preserve current behaviour.
- Test fixtures are synthetic. No real budget data enters the repository.
- UI follows `doc/08_design_guidelines.md`.
- Run `dart run build_runner build --delete-conflicting-outputs` after any `freezed` change.
- Verification for every task: `flutter analyze` reports no issues and `flutter test` passes.

---

### Task 1: Prior-period category history

Both insights need the same thing: this category's expense amounts in the complete periods that came before the current one, each with that period's length in days. This task builds only that.

**Files:**
- Create: `lib/src/logic/period_history.dart`
- Test: `test/period_history_test.dart`

**Interfaces:**
- Consumes: `Period`, `Category` from `lib/src/models/models.dart`; `effectiveEndDate` from `lib/src/logic/period_extensions.dart`.
- Produces:
  - `class CategoryPeriodSlice` with `final List<double> amounts`, `final int lengthDays`, and `double get total`.
  - `List<CategoryPeriodSlice> priorCategoryHistory({required String categoryName, required Period currentPeriod, required List<Period> allPeriods, required int limit})` — newest period first.

- [ ] **Step 1: Write the failing test**

Create `test/period_history_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flatplan/src/logic/period_history.dart';
import 'package:flatplan/src/models/models.dart';

FactExpense _fact(double amount) =>
    FactExpense(id: 'f$amount', amount: amount, timestamp: DateTime(2026, 1, 1));

Period _period({
  required String id,
  required DateTime startDate,
  required List<Category> categories,
}) => Period(
  id: id,
  name: id,
  startDate: startDate,
  baseCurrency: 'EUR',
  lastModified: startDate,
  categories: categories,
);

Category _groceries(String id, List<double> amounts, {String name = 'Groceries'}) =>
    Category(
      id: id,
      name: name,
      factExpenses: amounts.map(_fact).toList(),
    );

void main() {
  final older = _period(
    id: 'older',
    startDate: DateTime(2026, 1, 1),
    categories: [_groceries('c1', [100, 200])],
  );
  final previous = _period(
    id: 'previous',
    startDate: DateTime(2026, 2, 1),
    categories: [_groceries('c2', [300, 400])],
  );
  final current = _period(
    id: 'current',
    startDate: DateTime(2026, 3, 1),
    categories: [_groceries('c3', [999])],
  );
  final all = [current, previous, older];

  test('returns prior periods newest first, excluding the current one', () {
    final slices = priorCategoryHistory(
      categoryName: 'Groceries',
      currentPeriod: current,
      allPeriods: all,
      limit: 5,
    );

    expect(slices.map((s) => s.amounts), [
      [300, 400],
      [100, 200],
    ]);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/period_history_test.dart`
Expected: FAIL — `Error when reading 'lib/src/logic/period_history.dart': No such file or directory`.

- [ ] **Step 3: Write minimal implementation**

Create `lib/src/logic/period_history.dart`:

```dart
import '../models/models.dart';
import 'period_extensions.dart';

/// One prior period's slice of a single category's spending history.
class CategoryPeriodSlice {
  const CategoryPeriodSlice({required this.amounts, required this.lengthDays});

  /// Every fact-expense amount booked to the category in that period.
  final List<double> amounts;

  /// The period's length in days, inclusive of both end dates.
  final int lengthDays;

  double get total => amounts.fold<double>(0, (sum, a) => sum + a);
}

/// History for [categoryName] from the complete periods preceding
/// [currentPeriod], newest first, capped at [limit] slices.
///
/// Matching is by name because [createNextPeriod] regenerates category ids
/// on every rollover, so ids cannot link a category across periods.
/// Periods where the category is absent or has no spending are skipped
/// rather than counted as an empty slice — an empty slice would drag a
/// share or cadence statistic toward a value the user never lived.
List<CategoryPeriodSlice> priorCategoryHistory({
  required String categoryName,
  required Period currentPeriod,
  required List<Period> allPeriods,
  required int limit,
}) {
  final key = categoryName.trim().toLowerCase();
  final sorted = [...allPeriods]
    ..sort((a, b) => a.startDate.compareTo(b.startDate));
  final currentIndex = sorted.indexWhere((p) => p.id == currentPeriod.id);
  if (currentIndex < 1) return const [];

  final slices = <CategoryPeriodSlice>[];
  for (var i = currentIndex - 1; i >= 0 && slices.length < limit; i--) {
    final period = sorted[i];
    final amounts = <double>[];
    for (final category in period.categories) {
      if (category.name.trim().toLowerCase() != key) continue;
      for (final expense in category.factExpenses) {
        amounts.add(expense.amount);
      }
    }
    if (amounts.isEmpty) continue;

    final end = effectiveEndDate(period, allPeriods);
    slices.add(
      CategoryPeriodSlice(
        amounts: amounts,
        lengthDays: end.difference(period.startDate).inDays + 1,
      ),
    );
  }
  return slices;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/period_history_test.dart`
Expected: PASS.

- [ ] **Step 5: Add the remaining behaviour tests**

Append inside `main()` in `test/period_history_test.dart`:

```dart
  test('caps the number of slices at limit', () {
    final slices = priorCategoryHistory(
      categoryName: 'Groceries',
      currentPeriod: current,
      allPeriods: all,
      limit: 1,
    );

    expect(slices.map((s) => s.amounts), [
      [300, 400],
    ]);
  });

  test('skips periods where the category is absent or never used', () {
    final empty = _period(
      id: 'empty',
      startDate: DateTime(2026, 2, 15),
      categories: [_groceries('c4', const [])],
    );
    final unrelated = _period(
      id: 'unrelated',
      startDate: DateTime(2026, 2, 20),
      categories: [_groceries('c5', [50], name: 'Transport')],
    );

    final slices = priorCategoryHistory(
      categoryName: 'Groceries',
      currentPeriod: current,
      allPeriods: [...all, empty, unrelated],
      limit: 5,
    );

    expect(slices.map((s) => s.amounts), [
      [300, 400],
      [100, 200],
    ]);
  });

  test('matches the category name ignoring case and whitespace', () {
    final slices = priorCategoryHistory(
      categoryName: '  groceries ',
      currentPeriod: current,
      allPeriods: all,
      limit: 5,
    );

    expect(slices, hasLength(2));
  });

  test('reports each period length from the next period start', () {
    final slices = priorCategoryHistory(
      categoryName: 'Groceries',
      currentPeriod: current,
      allPeriods: all,
      limit: 5,
    );

    // previous: 2026-02-01 .. 2026-02-28 inclusive
    expect(slices.first.lengthDays, 28);
    // older: 2026-01-01 .. 2026-01-31 inclusive
    expect(slices.last.lengthDays, 31);
  });

  test('returns nothing when the current period is the earliest', () {
    expect(
      priorCategoryHistory(
        categoryName: 'Groceries',
        currentPeriod: older,
        allPeriods: all,
        limit: 5,
      ),
      isEmpty,
    );
  });

  test('total sums the slice amounts', () {
    expect(
      const CategoryPeriodSlice(amounts: [1, 2, 3], lengthDays: 10).total,
      6,
    );
  });
```

- [ ] **Step 6: Run the tests**

Run: `flutter test test/period_history_test.dart`
Expected: PASS, 7 tests. If the length assertions fail, check `effectiveEndDate` is being passed the full unsorted `allPeriods` list, not the local `sorted` copy.

- [ ] **Step 7: Verify and commit**

```bash
flutter analyze
flutter test
git add lib/src/logic/period_history.dart test/period_history_test.dart
git commit -m "feat: read category history by period membership"
```

---

### Task 2: Spending trend

Projects the period total from the previous period's rate and compares it to the limit. This is Insight A.

**Files:**
- Create: `lib/src/logic/spending_trend.dart`
- Test: `test/spending_trend_test.dart`

**Interfaces:**
- Consumes: `priorCategoryHistory`, `CategoryPeriodSlice` from Task 1; `CategoryBudget.effectiveLimit` from `lib/src/models/category_budget.dart` (exported via `models.dart`).
- Produces:
  - `@freezed sealed class SpendingTrend` with `double recentDailyRate`, `double projectedTotal`, `double overshoot`, and `bool get isOverProjected`.
  - `SpendingTrend? spendingTrendFor({required Category category, required Period period, required DateTime endDate, required List<Period> allPeriods, required DateTime now})`.

- [ ] **Step 1: Write the failing test**

Create `test/spending_trend_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flatplan/src/logic/spending_trend.dart';
import 'package:flatplan/src/models/models.dart';

FactExpense _fact(double amount) =>
    FactExpense(id: 'f$amount', amount: amount, timestamp: DateTime(2026, 1, 1));

Period _period({
  required String id,
  required DateTime startDate,
  required List<Category> categories,
}) => Period(
  id: id,
  name: id,
  startDate: startDate,
  baseCurrency: 'EUR',
  lastModified: startDate,
  categories: categories,
);

Category _groceries(
  String id,
  List<double> amounts, {
  double limit = 1000,
  bool isDailyAllowance = true,
}) => Category(
  id: id,
  name: 'Groceries',
  limit: limit,
  isDailyAllowance: isDailyAllowance,
  factExpenses: amounts.map(_fact).toList(),
);

void main() {
  // Previous period: 3,000 spent across 30 days -> 100 / day.
  final previous = _period(
    id: 'previous',
    startDate: DateTime(2026, 2, 1),
    categories: [_groceries('c1', [1000, 1000, 1000])],
  );
  // Current period runs 2026-03-03 .. 2026-03-31 (previous ends the day before).
  final current = _period(
    id: 'current',
    startDate: DateTime(2026, 3, 3),
    categories: [_groceries('c2', [200])],
  );
  final all = [previous, current];
  final endDate = DateTime(2026, 3, 31);

  test('projects the period total from the previous period rate', () {
    final trend = spendingTrendFor(
      category: current.categories.first,
      period: current,
      endDate: endDate,
      allPeriods: all,
      now: DateTime(2026, 3, 11),
    );

    // previous: 3000 / 30 days = 100 / day
    expect(trend!.recentDailyRate, 100);
    // 20 days remain; 200 already spent -> 200 + 20 * 100
    expect(trend.projectedTotal, 2200);
    // limit is 1000
    expect(trend.overshoot, 1200);
    expect(trend.isOverProjected, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/spending_trend_test.dart`
Expected: FAIL — `No such file or directory` for `lib/src/logic/spending_trend.dart`.

- [ ] **Step 3: Write the implementation**

Create `lib/src/logic/spending_trend.dart`:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

import '../models/models.dart';
import 'period_history.dart';

part 'spending_trend.freezed.dart';

/// Where this period lands if the previous period's spending rate continues.
@freezed
sealed class SpendingTrend with _$SpendingTrend {
  const SpendingTrend._();

  const factory SpendingTrend({
    /// The previous complete period's spend per day for this category.
    required double recentDailyRate,

    /// What this period totals if [recentDailyRate] holds for the days left.
    required double projectedTotal,

    /// How far [projectedTotal] exceeds the limit; zero when on track.
    required double overshoot,
  }) = _SpendingTrend;

  bool get isOverProjected => overshoot > 0;
}

/// The trend for [category] in [period], or null when the category has no
/// daily allowance, the period has ended, or there is no complete prior
/// period to compare against.
///
/// The single most recent prior period is the basis rather than an average:
/// spending rates were observed to trend steadily rather than oscillate, so
/// an average lags the current trajectory.
SpendingTrend? spendingTrendFor({
  required Category category,
  required Period period,
  required DateTime endDate,
  required List<Period> allPeriods,
  required DateTime now,
}) {
  if (!category.isDailyAllowance) return null;

  final daysLeft = endDate.difference(now).inDays;
  if (daysLeft < 1) return null;

  final history = priorCategoryHistory(
    categoryName: category.name,
    currentPeriod: period,
    allPeriods: allPeriods,
    limit: 1,
  );
  if (history.isEmpty) return null;

  final previous = history.first;
  if (previous.lengthDays < 1) return null;

  final recentDailyRate = previous.total / previous.lengthDays;
  final spent = category.factExpenses.fold<double>(0, (s, e) => s + e.amount);
  final projectedTotal = spent + daysLeft * recentDailyRate;
  final overshoot = projectedTotal - category.effectiveLimit;

  return SpendingTrend(
    recentDailyRate: recentDailyRate,
    projectedTotal: projectedTotal,
    overshoot: overshoot > 0 ? overshoot : 0,
  );
}
```

- [ ] **Step 4: Generate and run**

```bash
dart run build_runner build --delete-conflicting-outputs
flutter test test/spending_trend_test.dart
```
Expected: PASS.

- [ ] **Step 5: Add the guard tests**

Append inside `main()` in `test/spending_trend_test.dart`:

```dart
  test('reports no overshoot when the projection lands inside the limit', () {
    final roomy = _period(
      id: 'current',
      startDate: DateTime(2026, 3, 3),
      categories: [_groceries('c2', [200], limit: 5000)],
    );

    final trend = spendingTrendFor(
      category: roomy.categories.first,
      period: roomy,
      endDate: endDate,
      allPeriods: [previous, roomy],
      now: DateTime(2026, 3, 11),
    );

    expect(trend!.projectedTotal, 2200);
    expect(trend.overshoot, 0);
    expect(trend.isOverProjected, isFalse);
  });

  test('returns null for a category without a daily allowance', () {
    final plain = _period(
      id: 'current',
      startDate: DateTime(2026, 3, 3),
      categories: [_groceries('c2', [200], isDailyAllowance: false)],
    );

    expect(
      spendingTrendFor(
        category: plain.categories.first,
        period: plain,
        endDate: endDate,
        allPeriods: [previous, plain],
        now: DateTime(2026, 3, 11),
      ),
      isNull,
    );
  });

  test('returns null once the period has ended', () {
    expect(
      spendingTrendFor(
        category: current.categories.first,
        period: current,
        endDate: endDate,
        allPeriods: all,
        now: DateTime(2026, 4, 15),
      ),
      isNull,
    );
  });

  test('returns null when there is no complete prior period', () {
    expect(
      spendingTrendFor(
        category: previous.categories.first,
        period: previous,
        endDate: DateTime(2026, 3, 2),
        allPeriods: all,
        now: DateTime(2026, 2, 10),
      ),
      isNull,
    );
  });
```

- [ ] **Step 6: Run the tests**

Run: `flutter test test/spending_trend_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 7: Verify and commit**

```bash
flutter analyze
flutter test
git add lib/src/logic/spending_trend.dart lib/src/logic/spending_trend.freezed.dart test/spending_trend_test.dart
git commit -m "feat: project period spending from the previous period rate"
```

---

### Task 3: Big-purchase threshold on Category

The one piece of human knowledge the data cannot supply. Non-null enables the basket insight and carries its threshold; there is no separate boolean.

**Files:**
- Modify: `lib/src/models/category.dart`
- Test: `test/category_threshold_serialization_test.dart`

**Interfaces:**
- Produces: `Category.bigPurchaseThreshold` of type `double?`, defaulting to `null`, serialising as `big_purchase_threshold`.

- [ ] **Step 1: Write the failing test**

Create `test/category_threshold_serialization_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flatplan/src/models/models.dart';

void main() {
  test('round-trips the big-purchase threshold as snake_case', () {
    const category = Category(
      id: 'c1',
      name: 'Groceries',
      bigPurchaseThreshold: 700,
    );

    final json = category.toJson();
    expect(json['big_purchase_threshold'], 700);
    expect(Category.fromJson(json).bigPurchaseThreshold, 700);
  });

  test('defaults to null when the key is absent', () {
    final category = Category.fromJson({'id': 'c1', 'name': 'Groceries'});
    expect(category.bigPurchaseThreshold, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/category_threshold_serialization_test.dart`
Expected: FAIL — `No named parameter with the name 'bigPurchaseThreshold'`.

- [ ] **Step 3: Add the field**

In `lib/src/models/category.dart`, add the field to the factory, immediately after `isDailyAllowance`:

```dart
    @Default(false) bool isDailyAllowance,

    /// Amounts at or above this count as baskets, below it as small
    /// incidental spending. Non-null enables the basket insight; the value
    /// is the user's own boundary, seeded from history but never inferred.
    double? bigPurchaseThreshold,
```

- [ ] **Step 4: Generate and run**

```bash
dart run build_runner build --delete-conflicting-outputs
flutter test test/category_threshold_serialization_test.dart
```
Expected: PASS, 2 tests.

- [ ] **Step 5: Confirm existing period files still load**

Run: `flutter test test/storage_test.dart`
Expected: PASS. Absent keys must deserialise to null; a failure here means the field was declared non-nullable or given a `@Default`.

- [ ] **Step 6: Verify and commit**

```bash
flutter analyze
flutter test
git add lib/src/models/category.dart lib/src/models/category.freezed.dart lib/src/models/category.g.dart test/category_threshold_serialization_test.dart
git commit -m "feat: add a big-purchase threshold to Category"
```

---

### Task 4: Basket statistics

Turns a category's recent history into the three numbers the advice needs. Takes the worst value of each statistic, never the mean.

**Files:**
- Create: `lib/src/logic/basket_insight.dart`
- Test: `test/basket_stats_test.dart`

**Interfaces:**
- Consumes: `priorCategoryHistory`, `CategoryPeriodSlice` from Task 1; `Category.bigPurchaseThreshold` from Task 3.
- Produces:
  - `const int basketHistoryPeriods = 3;` and `const int minBasketHistoryPeriods = 2;`
  - `@freezed sealed class BasketStats` with `double snackShare`, `double tripSpacingDays`, `double usualBasket`, `int periodsUsed`.
  - `BasketStats? basketStatsFor({required Category category, required Period period, required List<Period> allPeriods})`.
  - `double? suggestedBigPurchaseThreshold({required Category category, required Period period, required List<Period> allPeriods})`.

- [ ] **Step 1: Write the failing test**

Create `test/basket_stats_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flatplan/src/logic/basket_insight.dart';
import 'package:flatplan/src/models/models.dart';

FactExpense _fact(double amount) =>
    FactExpense(id: 'f$amount', amount: amount, timestamp: DateTime(2026, 1, 1));

Period _period({
  required String id,
  required DateTime startDate,
  required List<double> amounts,
}) => Period(
  id: id,
  name: id,
  startDate: startDate,
  baseCurrency: 'EUR',
  lastModified: startDate,
  categories: [
    Category(
      id: 'cat-$id',
      name: 'Groceries',
      isDailyAllowance: true,
      factExpenses: amounts.map(_fact).toList(),
    ),
  ],
);

void main() {
  // sliceA: 10 days, small [100,100]=200 of 2200 -> 9.1%; 2 baskets -> every 5d
  final sliceA = _period(
    id: 'a',
    startDate: DateTime(2026, 1, 1),
    amounts: [100, 100, 1000, 1000],
  );
  // sliceB: 12 days, small [100,200,300]=600 of 2600 -> 23.1%; 2 baskets -> every 6d
  final sliceB = _period(
    id: 'b',
    startDate: DateTime(2026, 1, 11),
    amounts: [100, 200, 300, 600, 1400],
  );
  final current = Period(
    id: 'current',
    name: 'current',
    startDate: DateTime(2026, 1, 23),
    baseCurrency: 'EUR',
    lastModified: DateTime(2026, 1, 23),
    categories: [
      const Category(
        id: 'cat-current',
        name: 'Groceries',
        limit: 10000,
        isDailyAllowance: true,
        bigPurchaseThreshold: 500,
      ),
    ],
  );
  final all = [sliceA, sliceB, current];

  test('takes the worst of each statistic across the window', () {
    final stats = basketStatsFor(
      category: current.categories.first,
      period: current,
      allPeriods: all,
    );

    // worst (highest) snack share is sliceB's 600/2600
    expect(stats!.snackShare, closeTo(600 / 2600, 0.0001));
    // tightest (lowest) spacing is sliceA's 10 days / 2 baskets
    expect(stats.tripSpacingDays, 5);
    // median of each slice's median basket: both are 1000
    expect(stats.usualBasket, 1000);
    expect(stats.periodsUsed, 2);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/basket_stats_test.dart`
Expected: FAIL — `No such file or directory` for `lib/src/logic/basket_insight.dart`.

- [ ] **Step 3: Write the implementation**

Create `lib/src/logic/basket_insight.dart`:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

import '../models/models.dart';
import 'period_history.dart';

part 'basket_insight.freezed.dart';

/// How many complete prior periods the basket statistics are drawn from.
///
/// Fixed, not configurable. A longer window was measured to be far noisier
/// than the trailing three because habits drift; a shorter one lets a single
/// unusual period swing the advice.
const int basketHistoryPeriods = 3;

/// Fewest complete prior periods before the insight is offered at all.
const int minBasketHistoryPeriods = 2;

/// What the recent history says about how this category is actually spent.
@freezed
sealed class BasketStats with _$BasketStats {
  const factory BasketStats({
    /// Fraction of spending that went on small incidental items, 0..1.
    /// The highest seen in the window, so the reserve is never too small.
    required double snackShare,

    /// Days between baskets. The tightest seen in the window, so the number
    /// of remaining trips is never underestimated.
    required double tripSpacingDays,

    /// A typical basket, shown as context so the advice can be judged.
    required double usualBasket,

    /// How many periods the figures were drawn from.
    required int periodsUsed,
  }) = _BasketStats;
}

double _median(List<double> values) {
  final sorted = [...values]..sort();
  final middle = sorted.length ~/ 2;
  if (sorted.length.isOdd) return sorted[middle];
  return (sorted[middle - 1] + sorted[middle]) / 2;
}

/// Basket statistics for [category], or null when it has no threshold set,
/// there is too little history, or a period in the window contains no
/// basket-sized purchase at all.
BasketStats? basketStatsFor({
  required Category category,
  required Period period,
  required List<Period> allPeriods,
}) {
  final threshold = category.bigPurchaseThreshold;
  if (threshold == null) return null;

  final history = priorCategoryHistory(
    categoryName: category.name,
    currentPeriod: period,
    allPeriods: allPeriods,
    limit: basketHistoryPeriods,
  );
  if (history.length < minBasketHistoryPeriods) return null;

  double? worstShare;
  double? tightestSpacing;
  final medians = <double>[];

  for (final slice in history) {
    final total = slice.total;
    if (total <= 0) return null;

    final baskets = slice.amounts.where((a) => a >= threshold).toList();
    // Without a basket in every period there is no cadence to measure.
    if (baskets.isEmpty) return null;

    final smallTotal = slice.amounts
        .where((a) => a < threshold)
        .fold<double>(0, (sum, a) => sum + a);

    final share = smallTotal / total;
    if (worstShare == null || share > worstShare) worstShare = share;

    final spacing = slice.lengthDays / baskets.length;
    if (tightestSpacing == null || spacing < tightestSpacing) {
      tightestSpacing = spacing;
    }

    medians.add(_median(baskets));
  }

  if (tightestSpacing == null || tightestSpacing <= 0) return null;

  return BasketStats(
    snackShare: worstShare!,
    tripSpacingDays: tightestSpacing,
    usualBasket: _median(medians),
    periodsUsed: history.length,
  );
}

/// A starting value for [Category.bigPurchaseThreshold], or null without
/// history: the mean amount across the same window, rounded to the nearest 50.
///
/// The mean rather than the median: spending of this shape is right-skewed,
/// so the median sits inside the cluster of small purchases while the mean
/// is pulled up between the two clusters by the money the baskets carry.
/// It is only a seed — the user is expected to correct it.
double? suggestedBigPurchaseThreshold({
  required Category category,
  required Period period,
  required List<Period> allPeriods,
}) {
  final history = priorCategoryHistory(
    categoryName: category.name,
    currentPeriod: period,
    allPeriods: allPeriods,
    limit: basketHistoryPeriods,
  );
  if (history.isEmpty) return null;

  final amounts = [for (final slice in history) ...slice.amounts];
  if (amounts.isEmpty) return null;

  final mean = amounts.fold<double>(0, (sum, a) => sum + a) / amounts.length;
  return (mean / 50).round() * 50;
}
```

- [ ] **Step 4: Generate and run**

```bash
dart run build_runner build --delete-conflicting-outputs
flutter test test/basket_stats_test.dart
```
Expected: PASS.

- [ ] **Step 5: Add the guard and suggestion tests**

Append inside `main()` in `test/basket_stats_test.dart`:

```dart
  test('returns null without a threshold set', () {
    final noThreshold = current.categories.first.copyWith(
      bigPurchaseThreshold: null,
    );

    expect(
      basketStatsFor(
        category: noThreshold,
        period: current,
        allPeriods: all,
      ),
      isNull,
    );
  });

  test('returns null below the minimum number of prior periods', () {
    expect(
      basketStatsFor(
        category: current.categories.first,
        period: current,
        allPeriods: [sliceA, current],
      ),
      isNull,
    );
  });

  test('returns null when a period in the window holds no basket', () {
    final snacksOnly = _period(
      id: 'c',
      startDate: DateTime(2026, 1, 11),
      amounts: [100, 200, 300],
    );

    expect(
      basketStatsFor(
        category: current.categories.first,
        period: current,
        allPeriods: [sliceA, snacksOnly, current],
      ),
      isNull,
    );
  });

  test('treats an amount exactly at the threshold as a basket', () {
    final atThreshold = _period(
      id: 'c',
      startDate: DateTime(2026, 1, 11),
      amounts: [100, 500],
    );

    final stats = basketStatsFor(
      category: current.categories.first,
      period: current,
      allPeriods: [sliceA, atThreshold, current],
    );

    // 500 counted as the sole basket, so only the 100 is small.
    expect(stats!.snackShare, closeTo(100 / 600, 0.0001));
  });

  test('suggests the mean amount rounded to the nearest 50', () {
    // sliceA + sliceB: [100,100,1000,1000,100,200,300,600,1400]
    // sum 4800 over 9 amounts = 533.33 -> 550
    expect(
      suggestedBigPurchaseThreshold(
        category: current.categories.first,
        period: current,
        allPeriods: all,
      ),
      550,
    );
  });

  test('suggests nothing without history', () {
    expect(
      suggestedBigPurchaseThreshold(
        category: current.categories.first,
        period: current,
        allPeriods: [current],
      ),
      isNull,
    );
  });
```

- [ ] **Step 6: Run the tests**

Run: `flutter test test/basket_stats_test.dart`
Expected: PASS, 7 tests.

- [ ] **Step 7: Verify and commit**

```bash
flutter analyze
flutter test
git add lib/src/logic/basket_insight.dart lib/src/logic/basket_insight.freezed.dart test/basket_stats_test.dart
git commit -m "feat: derive basket statistics from recent category history"
```

---

### Task 5: Basket advice

Turns the statistics into the number the user acts on: what is safe to spend on the next shop.

**Files:**
- Modify: `lib/src/logic/basket_insight.dart`
- Test: `test/basket_advice_test.dart`

**Interfaces:**
- Consumes: `BasketStats`, `basketStatsFor` from Task 4.
- Produces:
  - `@freezed sealed class BasketAdvice` with `double snackReserve`, `double basketBudget`, `double tripsLeft`, `double safeBasket`, `BasketStats stats`.
  - `BasketAdvice? basketAdviceFrom({required BasketStats stats, required double limit, required double remaining, required double smallSpentThisPeriod, required int daysLeft})`.
  - `BasketAdvice? basketAdviceFor({required Category category, required Period period, required DateTime endDate, required List<Period> allPeriods, required DateTime now})`.

- [ ] **Step 1: Write the failing test**

Create `test/basket_advice_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flatplan/src/logic/basket_insight.dart';

const _stats = BasketStats(
  snackShare: 0.30,
  tripSpacingDays: 2,
  usualBasket: 600,
  periodsUsed: 3,
);

void main() {
  test('reserves the snack share against the limit, then splits the rest', () {
    final advice = basketAdviceFrom(
      stats: _stats,
      limit: 10000,
      remaining: 8000,
      smallSpentThisPeriod: 500,
      daysLeft: 20,
    );

    // 0.30 * 10000 - 500 already spent on small items
    expect(advice!.snackReserve, 2500);
    expect(advice.basketBudget, 5500);
    expect(advice.tripsLeft, 10);
    expect(advice.safeBasket, 550);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/basket_advice_test.dart`
Expected: FAIL — `Method not found: 'basketAdviceFrom'`.

- [ ] **Step 3: Write the implementation**

Append to `lib/src/logic/basket_insight.dart`:

```dart
/// What is safe to spend on the next shop, and the reasoning behind it.
@freezed
sealed class BasketAdvice with _$BasketAdvice {
  const factory BasketAdvice({
    /// Budget held back for small incidental spending still to come.
    required double snackReserve,

    /// What is left for baskets once the reserve is held back.
    required double basketBudget,

    /// Baskets expected in the days remaining.
    required double tripsLeft,

    /// [basketBudget] divided across [tripsLeft].
    required double safeBasket,

    /// The history the advice was derived from.
    required BasketStats stats,
  }) = _BasketAdvice;
}

/// The advice given already-computed [stats] and this period's figures.
///
/// The reserve is anchored to [limit] rather than [remaining]: taking a
/// share of a shrinking base would quietly hand budget back to baskets as
/// small spending ate into it. Anchored to the limit and reduced by what
/// small items have already consumed, the reserve floors at zero, after
/// which every further small purchase tightens [safeBasket] directly
/// because [remaining] has fallen.
BasketAdvice? basketAdviceFrom({
  required BasketStats stats,
  required double limit,
  required double remaining,
  required double smallSpentThisPeriod,
  required int daysLeft,
}) {
  if (daysLeft < 1) return null;
  if (stats.tripSpacingDays <= 0) return null;

  final expectedSnacks = stats.snackShare * limit;
  final snackReserve = expectedSnacks - smallSpentThisPeriod;
  final reserve = snackReserve > 0 ? snackReserve : 0.0;

  final basketBudget = remaining - reserve;
  if (basketBudget <= 0) return null;

  final tripsLeft = daysLeft / stats.tripSpacingDays;
  if (tripsLeft <= 0) return null;

  return BasketAdvice(
    snackReserve: reserve,
    basketBudget: basketBudget,
    tripsLeft: tripsLeft,
    safeBasket: basketBudget / tripsLeft,
    stats: stats,
  );
}

/// The advice for [category] in [period], or null when the insight is off,
/// the period has ended, history is too thin, or nothing is left for baskets.
BasketAdvice? basketAdviceFor({
  required Category category,
  required Period period,
  required DateTime endDate,
  required List<Period> allPeriods,
  required DateTime now,
}) {
  final threshold = category.bigPurchaseThreshold;
  if (threshold == null) return null;

  final daysLeft = endDate.difference(now).inDays;
  if (daysLeft < 1) return null;

  final stats = basketStatsFor(
    category: category,
    period: period,
    allPeriods: allPeriods,
  );
  if (stats == null) return null;

  final spent = category.factExpenses.fold<double>(0, (s, e) => s + e.amount);
  final smallSpent = category.factExpenses
      .where((e) => e.amount < threshold)
      .fold<double>(0, (s, e) => s + e.amount);

  final limit = category.effectiveLimit;
  return basketAdviceFrom(
    stats: stats,
    limit: limit,
    remaining: limit - spent,
    smallSpentThisPeriod: smallSpent,
    daysLeft: daysLeft,
  );
}
```

- [ ] **Step 4: Generate and run**

```bash
dart run build_runner build --delete-conflicting-outputs
flutter test test/basket_advice_test.dart
```
Expected: PASS.

- [ ] **Step 5: Add the boundary tests**

Append inside `main()` in `test/basket_advice_test.dart`:

```dart
  test('floors the reserve at zero once small spending exhausts its share', () {
    final advice = basketAdviceFrom(
      stats: _stats,
      limit: 10000,
      remaining: 5000,
      smallSpentThisPeriod: 4000, // beyond the 3000 expected
      daysLeft: 20,
    );

    expect(advice!.snackReserve, 0);
    // the whole remainder is available, nothing is handed back
    expect(advice.basketBudget, 5000);
    expect(advice.safeBasket, 500);
  });

  test('returns null when nothing is left for baskets', () {
    expect(
      basketAdviceFrom(
        stats: _stats,
        limit: 10000,
        remaining: 2000, // below the 3000 reserve
        smallSpentThisPeriod: 0,
        daysLeft: 20,
      ),
      isNull,
    );
  });

  test('returns null once the period has ended', () {
    expect(
      basketAdviceFrom(
        stats: _stats,
        limit: 10000,
        remaining: 8000,
        smallSpentThisPeriod: 500,
        daysLeft: 0,
      ),
      isNull,
    );
  });
```

- [ ] **Step 6: Run the tests**

Run: `flutter test test/basket_advice_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 7: Verify and commit**

```bash
flutter analyze
flutter test
git add lib/src/logic/basket_insight.dart lib/src/logic/basket_insight.freezed.dart test/basket_advice_test.dart
git commit -m "feat: compute a safe per-basket amount from budget and history"
```

---

### Task 6: Surface both insights on CategoryStats

Adds the new figures alongside the existing ones. The old `expectedPurchase*` fields stay populated for now so every consumer keeps compiling; Task 11 removes them.

**Files:**
- Modify: `lib/src/logic/period_stats.dart`
- Test: `test/category_stats_insights_test.dart`

**Interfaces:**
- Consumes: `spendingTrendFor` (Task 2), `basketAdviceFor` (Task 5).
- Produces: `CategoryStats.trend` of type `SpendingTrend?` and `CategoryStats.basket` of type `BasketAdvice?`.

- [ ] **Step 1: Write the failing test**

Create `test/category_stats_insights_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flatplan/src/logic/period_stats.dart';
import 'package:flatplan/src/models/models.dart';

FactExpense _fact(double amount) =>
    FactExpense(id: 'f$amount', amount: amount, timestamp: DateTime(2026, 1, 1));

Period _prior({
  required String id,
  required DateTime startDate,
  required List<double> amounts,
}) => Period(
  id: id,
  name: id,
  startDate: startDate,
  baseCurrency: 'EUR',
  lastModified: startDate,
  categories: [
    Category(
      id: 'cat-$id',
      name: 'Groceries',
      limit: 10000,
      isDailyAllowance: true,
      bigPurchaseThreshold: 500,
      factExpenses: amounts.map(_fact).toList(),
    ),
  ],
);

void main() {
  final a = _prior(
    id: 'a',
    startDate: DateTime(2026, 1, 1),
    amounts: [100, 100, 1000, 1000],
  );
  final b = _prior(
    id: 'b',
    startDate: DateTime(2026, 1, 11),
    amounts: [100, 200, 300, 600, 1400],
  );
  final current = _prior(
    id: 'current',
    startDate: DateTime(2026, 1, 23),
    amounts: [200],
  );
  final all = [a, b, current];

  test('carries both insights onto CategoryStats', () {
    final stats = categoryStatsFor(
      category: current.categories.first,
      period: current,
      endDate: DateTime(2026, 2, 22),
      allPeriods: all,
      now: DateTime(2026, 1, 25),
    );

    expect(stats.trend, isNotNull);
    expect(stats.basket, isNotNull);
    expect(stats.basket!.stats.periodsUsed, 2);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/category_stats_insights_test.dart`
Expected: FAIL — `The getter 'trend' isn't defined for the class 'CategoryStats'`.

- [ ] **Step 3: Add the fields and populate them**

In `lib/src/logic/period_stats.dart`, add the imports:

```dart
import 'basket_insight.dart';
import 'spending_trend.dart';
```

Add to the `CategoryStats` factory, after `expectedPurchaseAmount`:

```dart
    /// Where this period lands at the previous period's rate.
    SpendingTrend? trend,

    /// What is safe to spend on the next shop.
    BasketAdvice? basket,
```

In `categoryStatsFor`, after the existing `final pace = paceForCategory(...)` call, add:

```dart
  final trend = spendingTrendFor(
    category: category,
    period: period,
    endDate: endDate,
    allPeriods: allPeriods,
    now: now,
  );

  final basket = basketAdviceFor(
    category: category,
    period: period,
    endDate: endDate,
    allPeriods: allPeriods,
    now: now,
  );
```

And add to the returned `CategoryStats(...)`:

```dart
    trend: trend,
    basket: basket,
```

- [ ] **Step 4: Generate and run**

```bash
dart run build_runner build --delete-conflicting-outputs
flutter test test/category_stats_insights_test.dart
```
Expected: PASS.

- [ ] **Step 5: Confirm nothing regressed**

Run: `flutter test`
Expected: PASS. Every existing test still passes because the old fields are untouched.

- [ ] **Step 6: Verify and commit**

```bash
flutter analyze
flutter test
git add lib/src/logic/period_stats.dart lib/src/logic/period_stats.freezed.dart test/category_stats_insights_test.dart
git commit -m "feat: expose trend and basket insights on CategoryStats"
```

---

### Task 7: Write the insights into the AI stats file

`current_stats.md` is the snapshot a downstream LLM job reads. It currently renders the old cadence text; it must carry the new insights instead.

**Files:**
- Modify: `lib/src/logic/period_stats_markdown.dart:83-97`
- Test: `test/period_stats_markdown_test.dart`

**Interfaces:**
- Consumes: `CategoryStats.trend`, `CategoryStats.basket` from Task 6.
- Produces: no new API — changes the rendered Markdown only.

- [ ] **Step 1: Write the failing test**

Append inside `main()` in `test/period_stats_markdown_test.dart`. The file already has a `_categoryStats(...)` helper; extend its parameter list with `SpendingTrend? trend` and `BasketAdvice? basket` passed straight through to the `CategoryStats` constructor, then add:

```dart
  test('renders the trend and basket insights for a daily allowance', () {
    final markdown = formatCurrentPeriodStatsMarkdown(
      period: _period(),
      stats: PeriodStats(
        totalMandatoryBudget: 0,
        totalMandatorySpent: 0,
        totalOptionalBudget: 10000,
        totalOptionalSpent: 2000,
        totalBudget: 10000,
        totalSpent: 2000,
        overallRemaining: 8000,
        remainingFreeBalance: 8000,
        totalIncome: 0,
        totalFactIncome: 0,
        categoryStats: [
          _categoryStats(
            name: 'Groceries',
            isDailyAllowance: true,
            dailyAllowanceAmount: 400,
            trend: const SpendingTrend(
              recentDailyRate: 520,
              projectedTotal: 12400,
              overshoot: 2400,
            ),
            basket: const BasketAdvice(
              snackReserve: 2500,
              basketBudget: 5500,
              tripsLeft: 10,
              safeBasket: 550,
              stats: BasketStats(
                snackShare: 0.3,
                tripSpacingDays: 2,
                usualBasket: 600,
                periodsUsed: 3,
              ),
            ),
          ),
        ],
      ),
      endDate: DateTime(2026, 2, 28),
      now: DateTime(2026, 2, 8),
    );

    expect(markdown, contains('### Groceries'));
    expect(markdown, contains('Safe per shop: 550'));
    expect(markdown, contains('every 2 days'));
    expect(markdown, contains('Reserved for small purchases: 2,500'));
    expect(markdown, contains('Recent rate: 520 / day'));
    expect(markdown, contains('projected 12,400'));
    expect(markdown, contains('over budget by 2,400'));
  });
```

Add the imports `package:flatplan/src/logic/basket_insight.dart` and `package:flatplan/src/logic/spending_trend.dart` at the top of the test file.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/period_stats_markdown_test.dart`
Expected: FAIL — the expected strings are absent from the output.

- [ ] **Step 3: Render the new section**

In `lib/src/logic/period_stats_markdown.dart`, replace the `cadence` local and the `dailyAllow` expression inside the category loop with:

```dart
    final dailyAllow = !c.isDailyAllowance
        ? 'no'
        : c.dailyAllowanceAmount != null
        ? 'yes (${money.format(c.dailyAllowanceAmount)}/day left)'
        : 'yes';
```

Then, after the category table loop closes, append a details section:

```dart
  final withInsights = stats.categoryStats
      .where((c) => c.trend != null || c.basket != null)
      .toList();

  if (withInsights.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln('## Daily allowance insights');

    for (final c in withInsights) {
      buffer
        ..writeln()
        ..writeln('### ${c.name}');

      final basket = c.basket;
      if (basket != null) {
        buffer
          ..writeln(
            '- Safe per shop: ${money.format(basket.safeBasket)} '
            '(about ${basket.tripsLeft.round()} shops left, '
            'one every ${money.format(basket.stats.tripSpacingDays)} days)',
          )
          ..writeln(
            '- Reserved for small purchases: '
            '${money.format(basket.snackReserve)} '
            '(${(basket.stats.snackShare * 100).round()}% of the budget '
            'historically goes on them)',
          )
          ..writeln(
            '- Left for shops: ${money.format(basket.basketBudget)}; '
            'usual shop is ${money.format(basket.stats.usualBasket)} '
            '(from ${basket.stats.periodsUsed} previous periods)',
          );
      }

      final trend = c.trend;
      if (trend != null) {
        buffer.writeln(
          '- Recent rate: ${money.format(trend.recentDailyRate)} / day '
          'last period, projected ${money.format(trend.projectedTotal)} '
          'this period'
          '${trend.isOverProjected ? ' — over budget by ${money.format(trend.overshoot)}' : ' — within budget'}',
        );
      }
    }
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/period_stats_markdown_test.dart`
Expected: PASS.

- [ ] **Step 5: Verify and commit**

```bash
flutter analyze
flutter test
git add lib/src/logic/period_stats_markdown.dart test/period_stats_markdown_test.dart
git commit -m "feat: write the allowance insights into the AI stats file"
```

---

### Task 8: Category tile

**Files:**
- Modify: `lib/src/components/category_tile.dart:9-34` (parameters) and `:146-185` (the allowance row)
- Modify: `lib/src/views/dashboard_view.dart:487-505` (formatting and wiring)
- Test: `test/category_tile_insights_test.dart`

**Interfaces:**
- Consumes: `CategoryStats.trend`, `CategoryStats.basket`.
- Produces: `CategoryTile` gains `String? safeBasketAmount`, `String? trendLine`, `bool isOverProjected`. It loses `expectedPurchaseFrequencyDays` and `expectedPurchaseAmount`.

- [ ] **Step 1: Write the failing test**

Create `test/category_tile_insights_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flatplan/src/components/category_tile.dart';

Widget _tile({
  String? dailyAllowanceAmount = '400',
  String? safeBasketAmount,
  String? trendLine,
  bool isOverProjected = false,
}) => MaterialApp(
  home: Scaffold(
    body: CategoryTile(
      title: 'Groceries',
      spentAmount: '2,000',
      limitAmount: '10,000',
      heatPercentage: 0.2,
      isOverBudget: false,
      dailyAllowanceAmount: dailyAllowanceAmount,
      safeBasketAmount: safeBasketAmount,
      trendLine: trendLine,
      isOverProjected: isOverProjected,
      onTap: () {},
    ),
  ),
);

void main() {
  testWidgets('leads with the safe-per-shop amount when available', (
    tester,
  ) async {
    await tester.pumpWidget(
      _tile(safeBasketAmount: '550', trendLine: 'averaging 520/day — heading 2,400 over'),
    );

    expect(find.textContaining('550 safe per shop'), findsOneWidget);
    expect(find.textContaining('400 / day left'), findsOneWidget);
    expect(
      find.textContaining('averaging 520/day — heading 2,400 over'),
      findsOneWidget,
    );
  });

  testWidgets('falls back to the daily figure alone', (tester) async {
    await tester.pumpWidget(_tile());

    expect(find.textContaining('400 / day left'), findsOneWidget);
    expect(find.textContaining('safe per shop'), findsNothing);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/category_tile_insights_test.dart`
Expected: FAIL — `No named parameter with the name 'safeBasketAmount'`.

- [ ] **Step 3: Change the tile**

In `lib/src/components/category_tile.dart`, replace the fields `expectedPurchaseFrequencyDays` and `expectedPurchaseAmount` with:

```dart
  final String? safeBasketAmount;
  final String? trendLine;
  final bool isOverProjected;
```

and their constructor entries with:

```dart
    this.safeBasketAmount,
    this.trendLine,
    this.isOverProjected = false,
```

Replace the whole `if (widget.dailyAllowanceAmount != null) ...[ ... ]` block with:

```dart
                    if (widget.dailyAllowanceAmount != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.today_rounded,
                            size: 14,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              widget.safeBasketAmount != null
                                  ? '${widget.safeBasketAmount} safe per shop · ${widget.dailyAllowanceAmount} / day left'
                                  : '${widget.dailyAllowanceAmount} / day left',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (widget.trendLine != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            widget.isOverProjected
                                ? Icons.trending_up_rounded
                                : Icons.check_circle_outline_rounded,
                            size: 14,
                            color: widget.isOverProjected
                                ? colorScheme.error
                                : colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              widget.trendLine!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: widget.isOverProjected
                                    ? colorScheme.error
                                    : colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/category_tile_insights_test.dart`
Expected: PASS.

- [ ] **Step 5: Wire the dashboard**

In `lib/src/views/dashboard_view.dart`, replace the `expectedPurchaseFrequencyDays:` and `expectedPurchaseAmount:` arguments in the `CategoryTile(...)` construction with:

```dart
            safeBasketAmount: c.basket != null
                ? NumberFormat.simpleCurrency(
                    name: formatter.currencyName,
                    decimalDigits: 0,
                  ).format(c.basket!.safeBasket)
                : null,
            trendLine: c.trend != null
                ? 'averaging ${NumberFormat.simpleCurrency(name: formatter.currencyName, decimalDigits: 0).format(c.trend!.recentDailyRate)}/day'
                      '${c.trend!.isOverProjected ? ' — heading ${NumberFormat.simpleCurrency(name: formatter.currencyName, decimalDigits: 0).format(c.trend!.overshoot)} over' : ' — within budget'}'
                : null,
            isOverProjected: c.trend?.isOverProjected ?? false,
```

- [ ] **Step 6: Verify and commit**

```bash
flutter analyze
flutter test
git add lib/src/components/category_tile.dart lib/src/views/dashboard_view.dart test/category_tile_insights_test.dart
git commit -m "feat: show safe-per-shop and trend on the category tile"
```

---

### Task 9: Category detail view

**Files:**
- Modify: `lib/src/views/category_detail_view.dart:320-364` (`_buildDailyAllowanceRow`)
- Test: `test/category_detail_pace_test.dart`

**Interfaces:**
- Consumes: `CategoryStats.trend`, `CategoryStats.basket`.
- Produces: no new API.

- [ ] **Step 1: Rewrite the existing widget test**

`test/category_detail_pace_test.dart` currently asserts `find.textContaining('every 2 days')` from the old cadence. Replace that expectation with:

```dart
    expect(find.textContaining('safe per shop'), findsOneWidget);
    expect(find.textContaining('Reserved for small purchases'), findsOneWidget);
```

and extend the fixture so the category carries `bigPurchaseThreshold: 500` and there are two prior periods with both small and basket-sized expenses, mirroring the fixture in `test/basket_stats_test.dart`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/category_detail_pace_test.dart`
Expected: FAIL — the new strings are absent.

- [ ] **Step 3: Replace the allowance row**

In `lib/src/views/category_detail_view.dart`, replace the body of `_buildDailyAllowanceRow` with a column. Keep the method signature so the call site at line 268 is unchanged:

```dart
    final roundedFormat = NumberFormat.simpleCurrency(
      name: period.baseCurrency,
      decimalDigits: 0,
    );
    final basket = catStats.basket;
    final trend = catStats.trend;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.today_rounded,
              size: 14,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              basket != null
                  ? '${roundedFormat.format(basket.safeBasket)} safe per shop · ${roundedFormat.format(catStats.dailyAllowanceAmount)} / day left'
                  : '${roundedFormat.format(catStats.dailyAllowanceAmount)} / day left',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        if (basket != null) ...[
          const SizedBox(height: 6),
          Text(
            'Reserved for small purchases: '
            '${roundedFormat.format(basket.snackReserve)} '
            '(${(basket.stats.snackShare * 100).round()}% historically)',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            'Left for shops: ${roundedFormat.format(basket.basketBudget)} '
            'across about ${basket.tripsLeft.round()} shops, '
            'one every ${basket.stats.tripSpacingDays.toStringAsFixed(1)} days',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            'Usual shop ${roundedFormat.format(basket.stats.usualBasket)}, '
            'from the last ${basket.stats.periodsUsed} periods',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (trend != null) ...[
          const SizedBox(height: 6),
          Text(
            'Averaging ${roundedFormat.format(trend.recentDailyRate)} / day '
            'last period — projected ${roundedFormat.format(trend.projectedTotal)}'
            '${trend.isOverProjected ? ', ${roundedFormat.format(trend.overshoot)} over budget' : ', within budget'}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: trend.isOverProjected
                  ? colorScheme.error
                  : colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/category_detail_pace_test.dart`
Expected: PASS.

- [ ] **Step 5: Verify and commit**

```bash
flutter analyze
flutter test
git add lib/src/views/category_detail_view.dart test/category_detail_pace_test.dart
git commit -m "feat: break the allowance insights out on the detail screen"
```

---

### Task 10: Threshold field in the category dialog

**Files:**
- Modify: `lib/src/components/category_dialog.dart:12-30` (state), `:105-125` (controls), `:135-170` (save)
- Test: `test/category_dialog_threshold_test.dart`

**Interfaces:**
- Consumes: `suggestedBigPurchaseThreshold` (Task 4), `Category.bigPurchaseThreshold` (Task 3).
- Produces: no new API.

- [ ] **Step 1: Write the failing test**

Create `test/category_dialog_threshold_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flatplan/src/components/category_dialog.dart';
import 'package:flatplan/src/models/models.dart';
import 'package:flatplan/src/providers/repository_provider.dart';
import 'package:flatplan/src/storage/period_repository.dart';
import 'dart:io';

void main() {
  testWidgets('offers a big-purchase threshold once daily allowance is on', (
    tester,
  ) async {
    final tempDir = Directory.systemTemp.createTempSync('flatplan_dialog_');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    final repo = PeriodRepository(directoryPath: tempDir.path);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [periodRepositoryProvider.overrideWith((ref) => repo)],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showCategoryDialog(
                    context,
                    ref,
                    const Category(
                      id: 'c1',
                      name: 'Groceries',
                      isDailyAllowance: true,
                    ),
                    periodId: 'p1',
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Big-purchase threshold'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/category_dialog_threshold_test.dart`
Expected: FAIL — `Expected: exactly one matching candidate, Actual: found 0`.

- [ ] **Step 3: Add the control**

In `lib/src/components/category_dialog.dart`, add next to the other controllers:

```dart
  final thresholdCtrl = TextEditingController(
    text: existing?.bigPurchaseThreshold?.toStringAsFixed(0) ?? '',
  );
```

Add after the `SwitchListTile`, inside the same `Column`:

```dart
                    if (isDailyAllowance)
                      TextField(
                        controller: thresholdCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Big-purchase threshold',
                          helperText:
                              'Amounts at or above this count as a shop; '
                              'below it as small incidental spending. '
                              'Leave empty to skip the per-shop advice.',
                        ),
                        keyboardType: TextInputType.number,
                      ),
```

In both the `updateCategory` and `addCategory` branches, add:

```dart
                        bigPurchaseThreshold: isDailyAllowance
                            ? double.tryParse(thresholdCtrl.text.trim())
                            : null,
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/category_dialog_threshold_test.dart`
Expected: PASS.

- [ ] **Step 5: Seed the field from history**

Still in `showCategoryDialog`, before `showDialog(`, seed the controller when editing an existing category that has no threshold yet:

```dart
  if (existing != null && existing.bigPurchaseThreshold == null) {
    final periods = ref.read(allPeriodsProvider).value ?? const <Period>[];
    final period = periods.where((p) => p.id == periodId).firstOrNull;
    if (period != null) {
      final suggestion = suggestedBigPurchaseThreshold(
        category: existing,
        period: period,
        allPeriods: periods,
      );
      if (suggestion != null) {
        thresholdCtrl.text = suggestion.toStringAsFixed(0);
      }
    }
  }
```

Add the imports `../logic/basket_insight.dart`, `../models/models.dart` and `../providers/all_periods_provider.dart`.

- [ ] **Step 6: Verify and commit**

```bash
flutter analyze
flutter test
git add lib/src/components/category_dialog.dart test/category_dialog_threshold_test.dart
git commit -m "feat: set a big-purchase threshold per category"
```

---

### Task 11: Delete the obsolete pace machinery

Everything now reads the new insights, so the trimmed-mean code and its `CategoryStats` fields have no consumers.

**Files:**
- Delete: `lib/src/logic/allowance_pace.dart`, `test/allowance_pace_test.dart`, `test/allowance_pace_history_test.dart`
- Modify: `lib/src/logic/period_stats.dart`

**Interfaces:**
- Produces: `CategoryStats` loses `expectedPurchaseFrequencyDays` and `expectedPurchaseAmount`.

- [ ] **Step 1: Remove the fields and their population**

In `lib/src/logic/period_stats.dart`: drop `import 'allowance_pace.dart';`, drop the `expectedPurchaseFrequencyDays` and `expectedPurchaseAmount` entries from the `CategoryStats` factory, drop the `final pace = paceForCategory(...)` call, and drop the two matching arguments from the returned `CategoryStats(...)`.

Keep the `dailyAllowanceAmount` computation exactly as it is — a finished period still shows its per-day figure.

- [ ] **Step 2: Delete the dead files**

```bash
git rm lib/src/logic/allowance_pace.dart test/allowance_pace_test.dart test/allowance_pace_history_test.dart
dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 3: Confirm nothing referenced them**

```bash
grep -rn "allowance_pace\|paceForCategory\|estimateAllowancePace\|paceSamples\|expectedPurchase" lib test --include=*.dart | grep -v "\.g\.dart\|\.freezed\.dart"
```
Expected: no output. Anything listed is a missed call site — fix it before continuing.

- [ ] **Step 4: Full verification**

```bash
flutter analyze
flutter test
```
Expected: no analyzer issues; all tests pass.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor: drop the trimmed-mean pace estimate"
```

- [ ] **Step 6: Update the PR**

The branch already has an open PR (#14) whose title describes only the sliding-window work this plan replaces.

```bash
gh pr edit 14 --title "Category allowance insights: spending trend and safe basket"
```

Rewrite the PR body to describe the final diff: the trend and basket insights, the `bigPurchaseThreshold` field, and the removal of the trimmed-mean estimate. Do not merge — a push to `main` triggers `release.yml`, which cuts and publishes a release.

---

## Self-Review

**Spec coverage.** Insight A → Task 2. Insight B statistics → Task 4. Insight B advice → Task 5. Reserve anchored to the limit → Task 5, Step 3. Conservative selection → Task 4, Step 3. Three-period window with a minimum of two → Task 4 constants. Human-set threshold → Tasks 3 and 10. History by period membership → Task 1. Model field → Task 3. Code structure → Tasks 1, 2, 4, 5, 6, 11. Tile → Task 8. Detail view → Task 9. Category editor → Task 10. Testing → every task. Out-of-scope items (spend date, splitting the category) are correctly absent.

**Gap found and closed.** The spec's "Code structure" section says `allowance_pace.dart` keeps `paceForCategory`. The plan instead builds `spending_trend.dart` as a new file and deletes `allowance_pace.dart` in Task 11. This is deliberate: reusing the old name mid-plan would collide with the old meaning and leave intermediate tasks unable to compile. The end state matches the spec — one pure function producing the trend, no trimmed-mean code.

**Gap found and closed.** The spec did not mention `period_stats_markdown.dart`, but it consumes the removed fields and is the input to a downstream LLM job. Added as Task 7.

**Gap found and closed.** The spec says the threshold suggestion is "computed from history" without naming a method. Task 4 specifies the mean rounded to the nearest 50, with the reasoning recorded in the doc comment.

**Type consistency.** `CategoryPeriodSlice.amounts` / `.lengthDays` / `.total` used identically in Tasks 2, 4. `BasketStats.snackShare` / `.tripSpacingDays` / `.usualBasket` / `.periodsUsed` consistent across Tasks 4, 5, 7, 9. `BasketAdvice.snackReserve` / `.basketBudget` / `.tripsLeft` / `.safeBasket` / `.stats` consistent across Tasks 5, 7, 8, 9. `SpendingTrend.recentDailyRate` / `.projectedTotal` / `.overshoot` / `.isOverProjected` consistent across Tasks 2, 6, 7, 8, 9. `CategoryStats.trend` / `.basket` introduced in Task 6 and used with those names in Tasks 7, 8, 9.
