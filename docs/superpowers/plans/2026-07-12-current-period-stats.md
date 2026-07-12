# Current-Period Stats File Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Automatically write a human/LLM-readable `current_stats.md` snapshot of the current budget period into the periods directory on every data change, gated by a Settings toggle (default: enabled; disabling deletes the file).

**Architecture:** A pure Markdown formatter renders `Period` + `PeriodStats` into text. A reactive Riverpod provider (`currentPeriodStatsSyncProvider`) watches `periodStatsProvider` + a new settings toggle and writes/deletes the file as a side effect — no explicit hooks in mutation notifiers. Kept alive by a `ref.watch` in `AppShell`.

**Tech Stack:** Flutter (desktop), Riverpod v3 with codegen (`@riverpod` + generated `.g.dart` parts), freezed models, `shared_preferences`, `intl`.

**Spec:** `docs/superpowers/specs/2026-07-12-current-period-stats-design.md`

## Global Constraints

- The stats file is always `<periods_dir>/current_stats.md` — fixed name, overwritten in place.
- Settings toggle default: **enabled**. When disabled, the file is **deleted** (not left stale).
- All dates/times use local system time (`DateTime.now()`), never UTC — matches the rest of the codebase.
- File write/delete failures are swallowed silently (try/catch), matching `CurrentPeriod._debouncedSave` convention — a stats-file failure must never interrupt period editing.
- After adding/changing any `@riverpod` provider, run codegen: `dart run build_runner build --delete-conflicting-outputs`, and commit the generated `.g.dart` files.
- Test with `flutter test <path>`; lint with `flutter analyze` (must stay clean).
- The file contains only facts/figures — no AI instructions or tone guidance.

---

### Task 1: Extract `resolveDueDate` helper

The due-date resolution logic currently lives inline in the `periodStats` provider ([period_stats_provider.dart:140-151]). The Markdown formatter (Task 2) needs the same logic, so extract it into `period_extensions.dart` first.

**Files:**
- Modify: `lib/src/logic/period_extensions.dart`
- Modify: `lib/src/providers/period_stats_provider.dart:133-162`
- Test: `test/due_date_resolution_test.dart` (create)

**Interfaces:**
- Consumes: `DueDate` union type (`lib/src/models/due_date.dart`) with `.when(exact:, dayOfMonth:)`.
- Produces: `DateTime resolveDueDate(DueDate dueDate, {required DateTime now, required DateTime periodStart})` in `lib/src/logic/period_extensions.dart` — used by Task 2's formatter and by `periodStats`.

- [ ] **Step 1: Write the failing test**

Create `test/due_date_resolution_test.dart`:

```dart
import 'package:flatplan/src/logic/period_extensions.dart';
import 'package:flatplan/src/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final periodStart = DateTime(2026, 2, 1);
  final now = DateTime(2026, 2, 25);

  test('exact due date passes through unchanged', () {
    final due = resolveDueDate(
      DueDate.exact(date: DateTime(2026, 2, 10)),
      now: now,
      periodStart: periodStart,
    );
    expect(due, DateTime(2026, 2, 10));
  });

  test('dayOfMonth resolves within the current month', () {
    final due = resolveDueDate(
      const DueDate.dayOfMonth(day: 27),
      now: now,
      periodStart: periodStart,
    );
    expect(due, DateTime(2026, 2, 27));
  });

  test('dayOfMonth before the period start shifts one month forward', () {
    // Period starts on the 15th; day 5 of "now"'s month lands before it.
    final due = resolveDueDate(
      const DueDate.dayOfMonth(day: 5),
      now: DateTime(2026, 2, 20),
      periodStart: DateTime(2026, 2, 15),
    );
    expect(due, DateTime(2026, 3, 5));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/due_date_resolution_test.dart`
Expected: FAIL — `resolveDueDate` is not defined.

- [ ] **Step 3: Implement the helper**

Append to `lib/src/logic/period_extensions.dart`:

```dart
/// Resolves a [DueDate] to a concrete calendar date.
///
/// `dayOfMonth` dates resolve to that day in [now]'s month, shifted one
/// month forward when that lands before [periodStart] (the due day for
/// this period hasn't happened in the current calendar month yet).
DateTime resolveDueDate(
  DueDate dueDate, {
  required DateTime now,
  required DateTime periodStart,
}) {
  return dueDate.when(
    exact: (d) => d,
    dayOfMonth: (day) {
      final d = DateTime(now.year, now.month, day);
      if (d.isBefore(periodStart)) {
        return DateTime(now.year, now.month + 1, day);
      }
      return d;
    },
  );
}
```

(`period_extensions.dart` already imports `../models/models.dart`, which exports `DueDate`.)

- [ ] **Step 4: Switch `periodStats` to the helper**

In `lib/src/providers/period_stats_provider.dart`, replace the inline resolution inside the planned-expense status loop. Current code (lines 139-155):

```dart
        bool isOverdue = false;
        if (isActivePeriod) {
          final expDate = exp.dueDate.when(
            exact: (d) => d,
            dayOfMonth: (day) {
              final d = DateTime(now.year, now.month, day);
              // Shift into period if needed
              if (d.isBefore(currentPeriod.startDate)) {
                return DateTime(now.year, now.month + 1, day);
              }
              return d;
            },
          );
          if (now.isAfter(expDate.add(const Duration(days: 1)))) {
            isOverdue = true;
          }
        }
```

Replace with:

```dart
        bool isOverdue = false;
        if (isActivePeriod) {
          final expDate = resolveDueDate(
            exp.dueDate,
            now: now,
            periodStart: currentPeriod.startDate,
          );
          if (now.isAfter(expDate.add(const Duration(days: 1)))) {
            isOverdue = true;
          }
        }
```

The file already imports `../logic/period_extensions.dart`, so no import change is needed.

- [ ] **Step 5: Run all tests to verify nothing regressed**

Run: `flutter test`
Expected: ALL PASS (including the 3 new tests and the existing `period_stats_provider_test.dart`).

- [ ] **Step 6: Commit**

```bash
git add lib/src/logic/period_extensions.dart lib/src/providers/period_stats_provider.dart test/due_date_resolution_test.dart
git commit -m "refactor: extract resolveDueDate helper into period_extensions"
```

---

### Task 2: Markdown stats formatter

A pure, deterministic function that renders the snapshot. No I/O; `now` and `endDate` are parameters.

**Files:**
- Create: `lib/src/logic/period_stats_markdown.dart`
- Test: `test/period_stats_markdown_test.dart` (create)

**Interfaces:**
- Consumes: `Period`, `CategoryType` (models); `PeriodStats`, `CategoryStats` (from `lib/src/providers/period_stats_provider.dart`); `resolveDueDate` from Task 1.
- Produces: `String formatCurrentPeriodStatsMarkdown({required Period period, required PeriodStats stats, required DateTime endDate, required DateTime now})` — used by Task 4's sync provider.

- [ ] **Step 1: Write the failing test**

Create `test/period_stats_markdown_test.dart`:

```dart
import 'package:flatplan/src/logic/period_stats_markdown.dart';
import 'package:flatplan/src/models/models.dart';
import 'package:flatplan/src/providers/period_stats_provider.dart';
import 'package:flutter_test/flutter_test.dart';

Period _period({List<Category> categories = const []}) => Period(
  id: 'feb26',
  name: 'February 2026',
  startDate: DateTime(2026, 2, 1),
  baseCurrency: 'EUR',
  lastModified: DateTime(2026, 2, 25),
  categories: categories,
);

CategoryStats _catStats({
  required String id,
  required String name,
  CategoryType type = CategoryType.optionalExpense,
  double limit = 100,
  double spent = 0,
  bool isDailyAllowance = false,
  double? dailyAllowanceAmount,
}) => CategoryStats(
  categoryId: id,
  name: name,
  type: type,
  limit: limit,
  totalSpent: spent,
  totalPlanned: 0,
  remaining: limit - spent,
  heatPercentage: limit > 0 ? spent / limit : 0,
  isOverBudget: spent > limit,
  isDailyAllowance: isDailyAllowance,
  dailyAllowanceAmount: dailyAllowanceAmount,
);

PeriodStats _stats(List<CategoryStats> categoryStats) => PeriodStats(
  totalMandatoryBudget: 1200,
  totalMandatorySpent: 500,
  totalOptionalBudget: 700,
  totalOptionalSpent: 650,
  totalBudget: 1900,
  totalSpent: 1150,
  overallRemaining: 750,
  remainingFreeBalance: -50,
  totalIncome: 3500,
  totalFactIncome: 2000,
  categoryStats: categoryStats,
);

void main() {
  // Day 25 of a 28-day period (endDate 2026-02-28).
  final now = DateTime(2026, 2, 25, 14, 32);
  final endDate = DateTime(2026, 2, 28);

  test('renders meta and pacing sections', () {
    final md = formatCurrentPeriodStatsMarkdown(
      period: _period(),
      stats: _stats([]),
      endDate: endDate,
      now: now,
    );

    expect(md, contains('# Budget Stats — February 2026'));
    expect(md, contains('- Period: February 2026 (2026-02-01 → 2026-02-28)'));
    expect(md, contains('- Today: 2026-02-25 (day 25 of 28, 3 days remaining)'));
    expect(md, contains('- Generated: 2026-02-25 14:32'));
    expect(md, contains('- Currency: EUR'));
    expect(md, contains('- Time elapsed: 89% (25 / 28 days)'));
    // 1150 / 1900 = 60.5% → rounds to 61%
    expect(md, contains('- Budget spent: 61% (1,150 / 1,900 total budget)'));
    expect(md, contains('- Average daily spend so far: 46 / day')); // 1150/25
    expect(md, contains('- Projected total at this rate: 1,288 (vs. budget 1,900)'));
    expect(md, contains('- Free money remaining: -50'));
    expect(md, contains('- Income: 3,500 planned / 2,000 actual'));
  });

  test('renders category rows in given order with type and heat', () {
    final md = formatCurrentPeriodStatsMarkdown(
      period: _period(),
      stats: _stats([
        _catStats(
          id: 'home',
          name: 'Home',
          limit: 500,
          spent: 750,
          type: CategoryType.mandatoryExpense,
        ),
        _catStats(
          id: 'fun',
          name: 'Fun',
          limit: 200,
          spent: 50,
          isDailyAllowance: true,
          dailyAllowanceAmount: 50,
        ),
      ]),
      endDate: endDate,
      now: now,
    );

    expect(md, contains('| Home | Mandatory | no | 500 | 750 | -250 | 150% | yes |'));
    expect(md, contains('| Fun | Optional | yes (50/day left) | 200 | 50 | 150 | 25% | no |'));
    // Order preserved (already heat-sorted upstream).
    expect(md.indexOf('| Home |'), lessThan(md.indexOf('| Fun |')));
  });

  test('planned expenses table: overdue, upcoming, and filtering', () {
    final period = _period(categories: [
      Category(
        id: 'loans',
        name: 'Loans',
        type: CategoryType.mandatoryExpense,
        plannedExpenses: [
          // Overdue: due 2026-02-20, now is the 25th.
          PlannedExpense(
            id: 'p1',
            description: 'Mortgage',
            amount: 40158,
            dueDate: DueDate.exact(date: DateTime(2026, 2, 20)),
          ),
          // Upcoming within 14 days.
          const PlannedExpense(
            id: 'p2',
            description: 'Phone bill',
            amount: 650,
            dueDate: DueDate.dayOfMonth(day: 27),
          ),
          // Completed — excluded.
          PlannedExpense(
            id: 'p3',
            description: 'Paid already',
            amount: 10,
            isCompleted: true,
            dueDate: DueDate.exact(date: DateTime(2026, 2, 26)),
          ),
          // Beyond the 14-day window — excluded.
          PlannedExpense(
            id: 'p4',
            description: 'Far future',
            amount: 99,
            dueDate: DueDate.exact(date: DateTime(2026, 3, 20)),
          ),
        ],
      ),
    ]);

    final md = formatCurrentPeriodStatsMarkdown(
      period: period,
      stats: _stats([]),
      endDate: endDate,
      now: now,
    );

    expect(md, contains('| Loans | Mortgage | 40,158 | 2026-02-20 | overdue |'));
    expect(md, contains('| Loans | Phone bill | 650 | 2026-02-27 | pending |'));
    expect(md, isNot(contains('Paid already')));
    expect(md, isNot(contains('Far future')));
    // Sorted by due date: overdue Mortgage before pending Phone bill.
    expect(md.indexOf('Mortgage'), lessThan(md.indexOf('Phone bill')));
  });

  test('planned expenses section prints None. when nothing qualifies', () {
    final md = formatCurrentPeriodStatsMarkdown(
      period: _period(),
      stats: _stats([]),
      endDate: endDate,
      now: now,
    );
    expect(md, contains('## Planned Expenses — Overdue & Upcoming (next 14 days)\nNone.'));
  });

  test('summary totals count only expense categories', () {
    final md = formatCurrentPeriodStatsMarkdown(
      period: _period(),
      stats: _stats([
        _catStats(id: 'a', name: 'A', limit: 100, spent: 150),
        _catStats(id: 'b', name: 'B', limit: 100, spent: 10),
        _catStats(
          id: 'sal',
          name: 'Salary',
          type: CategoryType.income,
          limit: 3500,
          spent: 4000, // "over" for income means extra — must not count
        ),
      ]),
      endDate: endDate,
      now: now,
    );

    expect(md, contains('- Mandatory: 1,200 budget / 500 spent'));
    expect(md, contains('- Optional: 700 budget / 650 spent'));
    expect(md, contains('- Categories over budget: 1 of 2'));
  });

  test('clamps day number when now is outside the period range', () {
    final md = formatCurrentPeriodStatsMarkdown(
      period: _period(),
      stats: _stats([]),
      endDate: endDate,
      now: DateTime(2026, 3, 10), // after the period ended
    );
    expect(md, contains('(day 28 of 28, 0 days remaining)'));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/period_stats_markdown_test.dart`
Expected: FAIL — `period_stats_markdown.dart` does not exist.

- [ ] **Step 3: Implement the formatter**

Create `lib/src/logic/period_stats_markdown.dart`:

```dart
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../providers/period_stats_provider.dart';
import 'period_extensions.dart';

/// How far ahead (in days) an unpaid planned expense counts as "upcoming".
const int upcomingWindowDays = 14;

/// Renders a human/LLM-readable Markdown snapshot of the current period.
///
/// Pure function: all inputs, including [now], are passed in so the output
/// is fully deterministic and testable. Contains only facts and figures —
/// AI prompt instructions live in the downstream consumer, not here.
String formatCurrentPeriodStatsMarkdown({
  required Period period,
  required PeriodStats stats,
  required DateTime endDate,
  required DateTime now,
}) {
  final money = NumberFormat('#,##0.##');
  final dateFmt = DateFormat('yyyy-MM-dd');
  final dateTimeFmt = DateFormat('yyyy-MM-dd HH:mm');

  final totalDays = endDate.difference(period.startDate).inDays + 1;
  var dayNumber = now.difference(period.startDate).inDays + 1;
  if (dayNumber < 1) dayNumber = 1;
  if (dayNumber > totalDays) dayNumber = totalDays;
  final daysRemaining = totalDays - dayNumber;

  final timePct = (dayNumber / totalDays * 100).round();
  final spentPct = stats.totalBudget > 0
      ? (stats.totalSpent / stats.totalBudget * 100).round()
      : 0;
  final avgDaily = stats.totalSpent / dayNumber;
  final projected = avgDaily * totalDays;

  final buffer = StringBuffer()
    ..writeln('# Budget Stats — ${period.name}')
    ..writeln()
    ..writeln('## Meta')
    ..writeln(
      '- Period: ${period.name} '
      '(${dateFmt.format(period.startDate)} → ${dateFmt.format(endDate)})',
    )
    ..writeln(
      '- Today: ${dateFmt.format(now)} '
      '(day $dayNumber of $totalDays, $daysRemaining days remaining)',
    )
    ..writeln('- Generated: ${dateTimeFmt.format(now)}')
    ..writeln('- Currency: ${period.baseCurrency}')
    ..writeln()
    ..writeln('## Pacing')
    ..writeln('- Time elapsed: $timePct% ($dayNumber / $totalDays days)')
    ..writeln(
      '- Budget spent: $spentPct% (${money.format(stats.totalSpent)} '
      '/ ${money.format(stats.totalBudget)} total budget)',
    )
    ..writeln('- Average daily spend so far: ${money.format(avgDaily)} / day')
    ..writeln(
      '- Projected total at this rate: ${money.format(projected)} '
      '(vs. budget ${money.format(stats.totalBudget)})',
    )
    ..writeln(
      '- Free money remaining: ${money.format(stats.remainingFreeBalance)}',
    )
    ..writeln(
      '- Income: ${money.format(stats.totalIncome)} planned '
      '/ ${money.format(stats.totalFactIncome)} actual',
    )
    ..writeln()
    ..writeln('## Categories (sorted by budget heat, highest first)')
    ..writeln(
      '| Category | Type | Daily Allow. | Budget | Spent '
      '| Remaining | Heat | Over? |',
    )
    ..writeln('|---|---|---|---|---|---|---|---|');

  for (final c in stats.categoryStats) {
    final dailyAllow = !c.isDailyAllowance
        ? 'no'
        : c.dailyAllowanceAmount != null
        ? 'yes (${money.format(c.dailyAllowanceAmount)}/day left)'
        : 'yes';
    buffer.writeln(
      '| ${c.name} | ${_typeLabel(c.type)} | $dailyAllow '
      '| ${money.format(c.limit)} | ${money.format(c.totalSpent)} '
      '| ${money.format(c.remaining)} | ${(c.heatPercentage * 100).round()}% '
      '| ${c.isOverBudget ? 'yes' : 'no'} |',
    );
  }

  buffer
    ..writeln()
    ..writeln(
      '## Planned Expenses — Overdue & Upcoming '
      '(next $upcomingWindowDays days)',
    );

  final rows = <({DateTime due, String line})>[];
  for (final category in period.categories) {
    for (final exp in category.plannedExpenses) {
      if (exp.isCompleted) continue;
      final due = resolveDueDate(
        exp.dueDate,
        now: now,
        periodStart: period.startDate,
      );
      // Same overdue rule as periodStats: a full day of grace after the due
      // date before it flags as overdue.
      final isOverdue = now.isAfter(due.add(const Duration(days: 1)));
      final isUpcoming =
          !isOverdue &&
          !due.isAfter(now.add(const Duration(days: upcomingWindowDays)));
      if (!isOverdue && !isUpcoming) continue;
      rows.add((
        due: due,
        line:
            '| ${category.name} | ${exp.description} '
            '| ${money.format(exp.amount)} | ${dateFmt.format(due)} '
            '| ${isOverdue ? 'overdue' : 'pending'} |',
      ));
    }
  }
  rows.sort((a, b) => a.due.compareTo(b.due));

  if (rows.isEmpty) {
    buffer.writeln('None.');
  } else {
    buffer
      ..writeln('| Category | Description | Amount | Due | Status |')
      ..writeln('|---|---|---|---|---|');
    for (final row in rows) {
      buffer.writeln(row.line);
    }
  }

  final expenseCategories = stats.categoryStats
      .where((c) => c.type != CategoryType.income)
      .toList();
  final overCount = expenseCategories.where((c) => c.isOverBudget).length;

  buffer
    ..writeln()
    ..writeln('## Summary Totals')
    ..writeln(
      '- Mandatory: ${money.format(stats.totalMandatoryBudget)} budget '
      '/ ${money.format(stats.totalMandatorySpent)} spent',
    )
    ..writeln(
      '- Optional: ${money.format(stats.totalOptionalBudget)} budget '
      '/ ${money.format(stats.totalOptionalSpent)} spent',
    )
    ..writeln(
      '- Categories over budget: $overCount of ${expenseCategories.length}',
    );

  return buffer.toString();
}

String _typeLabel(CategoryType type) => switch (type) {
  CategoryType.mandatoryExpense => 'Mandatory',
  CategoryType.optionalExpense => 'Optional',
  CategoryType.income => 'Income',
};
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/period_stats_markdown_test.dart`
Expected: ALL PASS. If a `contains` assertion fails on number formatting, check locale — tests run under the default `en_US` locale, where `NumberFormat('#,##0.##')` renders `1150` as `1,150`.

- [ ] **Step 5: Commit**

```bash
git add lib/src/logic/period_stats_markdown.dart test/period_stats_markdown_test.dart
git commit -m "feat: add Markdown formatter for current-period stats"
```

---

### Task 3: Settings toggle — service + provider

**Files:**
- Create: `lib/src/storage/ai_stats_settings_service.dart`
- Create: `lib/src/providers/ai_stats_settings_provider.dart` (+ generated `.g.dart`)
- Test: `test/ai_stats_settings_service_test.dart` (create)

**Interfaces:**
- Consumes: `shared_preferences` (already a dependency).
- Produces:
  - `class AiStatsSettingsService { Future<bool> isEnabled(); Future<void> setEnabled(bool enabled); }`
  - `aiStatsSettingsProvider` — an async `@riverpod` class provider exposing `FutureOr<bool>` state and `Future<void> setEnabled(bool enabled)` on its notifier. Used by Task 4 (sync provider) and Task 5 (settings UI).

- [ ] **Step 1: Write the failing test**

Create `test/ai_stats_settings_service_test.dart`:

```dart
import 'package:flatplan/src/storage/ai_stats_settings_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('defaults to enabled when nothing is stored', () async {
    expect(await AiStatsSettingsService().isEnabled(), isTrue);
  });

  test('persists a disabled state across reads', () async {
    final service = AiStatsSettingsService();
    await service.setEnabled(false);
    expect(await AiStatsSettingsService().isEnabled(), isFalse);
  });

  test('re-enabling persists too', () async {
    final service = AiStatsSettingsService();
    await service.setEnabled(false);
    await service.setEnabled(true);
    expect(await service.isEnabled(), isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/ai_stats_settings_service_test.dart`
Expected: FAIL — `ai_stats_settings_service.dart` does not exist.

- [ ] **Step 3: Implement the service**

Create `lib/src/storage/ai_stats_settings_service.dart`:

```dart
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the "generate current-period stats file" toggle.
///
/// Defaults to enabled so the AI-insights pipeline works out of the box;
/// the user can opt out in Settings.
class AiStatsSettingsService {
  static const _key = 'ai_stats_enabled';

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? true;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, enabled);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/ai_stats_settings_service_test.dart`
Expected: ALL PASS.

- [ ] **Step 5: Add the provider**

Create `lib/src/providers/ai_stats_settings_provider.dart` (mirrors `storage_settings_provider.dart`):

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../storage/ai_stats_settings_service.dart';

part 'ai_stats_settings_provider.g.dart';

/// Exposes and manages the "generate current-period stats file" toggle.
@riverpod
class AiStatsSettings extends _$AiStatsSettings {
  final _service = AiStatsSettingsService();

  @override
  FutureOr<bool> build() => _service.isEnabled();

  Future<void> setEnabled(bool enabled) async {
    await _service.setEnabled(enabled);
    state = AsyncData(enabled);
  }
}
```

- [ ] **Step 6: Run codegen and verify it compiles**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: succeeds, generating `lib/src/providers/ai_stats_settings_provider.g.dart`.

Run: `flutter analyze`
Expected: No issues found.

- [ ] **Step 7: Commit**

```bash
git add lib/src/storage/ai_stats_settings_service.dart lib/src/providers/ai_stats_settings_provider.dart lib/src/providers/ai_stats_settings_provider.g.dart test/ai_stats_settings_service_test.dart
git commit -m "feat: add AI stats settings toggle service and provider"
```

---

### Task 4: File writer + reactive sync provider

**Files:**
- Create: `lib/src/storage/period_stats_writer.dart`
- Create: `lib/src/providers/current_period_stats_sync_provider.dart` (+ generated `.g.dart`)
- Test: `test/current_period_stats_sync_provider_test.dart` (create)

**Interfaces:**
- Consumes:
  - `formatCurrentPeriodStatsMarkdown(...)` (Task 2)
  - `aiStatsSettingsProvider` (Task 3)
  - Existing: `periodRepositoryProvider` (its `PeriodRepository.directoryPath` is public), `currentPeriodProvider`, `periodStatsProvider`, `allPeriodsProvider`, `effectiveEndDate`.
- Produces:
  - `class PeriodStatsWriter { PeriodStatsWriter({required String directoryPath}); Future<void> writeStatsFile(String markdown); Future<void> deleteStatsFile(); static const fileName = 'current_stats.md'; }`
  - `currentPeriodStatsSyncProvider` — `@riverpod Future<void>`; watching it keeps the sync alive (Task 5).

- [ ] **Step 1: Write the failing test**

Create `test/current_period_stats_sync_provider_test.dart` (setup mirrors `test/period_stats_provider_test.dart`):

```dart
import 'dart:io';

import 'package:flatplan/src/models/models.dart';
import 'package:flatplan/src/providers/ai_stats_settings_provider.dart';
import 'package:flatplan/src/providers/current_period_stats_sync_provider.dart';
import 'package:flatplan/src/providers/repository_provider.dart';
import 'package:flatplan/src/storage/period_repository.dart';
import 'package:flatplan/src/storage/period_stats_writer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late ProviderContainer container;

  File statsFile() => File('${tempDir.path}/${PeriodStatsWriter.fileName}');

  /// A period starting 5 days ago, so currentPeriodProvider picks it up
  /// (effective end = start + 30 days, which spans today).
  Period activePeriod() {
    final start = DateTime.now().subtract(const Duration(days: 5));
    return Period(
      id: 'test-period',
      name: 'Test Period',
      startDate: DateTime(start.year, start.month, start.day),
      baseCurrency: 'EUR',
      lastModified: DateTime(2026, 1, 1),
      categories: [
        Category(
          id: 'groceries',
          name: 'Groceries',
          type: CategoryType.mandatoryExpense,
          limit: 500,
          factExpenses: [
            FactExpense(id: 'f1', amount: 120, timestamp: DateTime(2026, 1, 1)),
          ],
        ),
      ],
    );
  }

  Future<ProviderContainer> makeContainer() async {
    final repo = PeriodRepository(directoryPath: tempDir.path);
    final c = ProviderContainer(
      overrides: [periodRepositoryProvider.overrideWith((ref) => repo)],
    );
    // The sync provider chain is autoDispose; hold a listener so it is not
    // torn down mid-await.
    c.listen(currentPeriodStatsSyncProvider, (_, _) {});
    return c;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tempDir = Directory.systemTemp.createTempSync('flatplan_sync_test_');
  });

  tearDown(() {
    container.dispose();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('writes current_stats.md when enabled and a current period exists',
      () async {
    await PeriodRepository(directoryPath: tempDir.path)
        .savePeriod(activePeriod());
    container = await makeContainer();

    await container.read(currentPeriodStatsSyncProvider.future);

    expect(statsFile().existsSync(), isTrue);
    final content = statsFile().readAsStringSync();
    expect(content, contains('# Budget Stats — Test Period'));
    expect(content, contains('| Groceries | Mandatory |'));
  });

  test('deletes the file when the toggle is switched off', () async {
    await PeriodRepository(directoryPath: tempDir.path)
        .savePeriod(activePeriod());
    container = await makeContainer();
    await container.read(currentPeriodStatsSyncProvider.future);
    expect(statsFile().existsSync(), isTrue);

    await container.read(aiStatsSettingsProvider.notifier).setEnabled(false);
    await container.read(currentPeriodStatsSyncProvider.future);

    expect(statsFile().existsSync(), isFalse);
  });

  test('does not write when disabled from the start', () async {
    SharedPreferences.setMockInitialValues({'ai_stats_enabled': false});
    await PeriodRepository(directoryPath: tempDir.path)
        .savePeriod(activePeriod());
    container = await makeContainer();

    await container.read(currentPeriodStatsSyncProvider.future);

    expect(statsFile().existsSync(), isFalse);
  });

  test('does not write when no period exists', () async {
    container = await makeContainer();

    await container.read(currentPeriodStatsSyncProvider.future);

    expect(statsFile().existsSync(), isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/current_period_stats_sync_provider_test.dart`
Expected: FAIL — `period_stats_writer.dart` and `current_period_stats_sync_provider.dart` do not exist.

- [ ] **Step 3: Implement the writer**

Create `lib/src/storage/period_stats_writer.dart`:

```dart
import 'dart:io';

/// Writes/removes the single current-period stats snapshot next to the
/// period YAML files, so it rides along with the user's git workflow.
class PeriodStatsWriter {
  static const fileName = 'current_stats.md';

  final String directoryPath;

  PeriodStatsWriter({required this.directoryPath});

  File get _file => File('$directoryPath/$fileName');

  Future<void> writeStatsFile(String markdown) async {
    final dir = Directory(directoryPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    await _file.writeAsString(markdown);
  }

  Future<void> deleteStatsFile() async {
    if (await _file.exists()) {
      await _file.delete();
    }
  }
}
```

- [ ] **Step 4: Implement the sync provider**

Create `lib/src/providers/current_period_stats_sync_provider.dart`:

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../logic/period_extensions.dart';
import '../logic/period_stats_markdown.dart';
import '../storage/period_stats_writer.dart';
import 'ai_stats_settings_provider.dart';
import 'all_periods_provider.dart';
import 'current_period_provider.dart';
import 'period_stats_provider.dart';
import 'repository_provider.dart';

part 'current_period_stats_sync_provider.g.dart';

/// Keeps `current_stats.md` in the periods directory in sync with the
/// current period's data.
///
/// Purely reactive: every mutation path already funnels into
/// [currentPeriodProvider] / [periodStatsProvider] invalidation, so watching
/// them regenerates the file on any change — no explicit hook needed in the
/// mutation notifiers. Must be kept alive by a `ref.watch` at the app root.
///
/// Write/delete failures are swallowed: a stats-file problem must never
/// interrupt normal period editing.
@riverpod
Future<void> currentPeriodStatsSync(Ref ref) async {
  final repo = ref.watch(periodRepositoryProvider);
  final writer = PeriodStatsWriter(directoryPath: repo.directoryPath);

  final enabled = await ref.watch(aiStatsSettingsProvider.future);
  if (!enabled) {
    try {
      await writer.deleteStatsFile();
    } catch (_) {}
    return;
  }

  final period = await ref.watch(currentPeriodProvider.future);
  final stats = await ref.watch(periodStatsProvider.future);
  if (period == null || stats == null) return;

  final allPeriods = await ref.watch(allPeriodsProvider.future);
  final endDate = effectiveEndDate(period, allPeriods);

  final markdown = formatCurrentPeriodStatsMarkdown(
    period: period,
    stats: stats,
    endDate: endDate,
    now: DateTime.now(),
  );
  try {
    await writer.writeStatsFile(markdown);
  } catch (_) {}
}
```

- [ ] **Step 5: Run codegen**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: succeeds, generating `lib/src/providers/current_period_stats_sync_provider.g.dart`.

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/current_period_stats_sync_provider_test.dart`
Expected: ALL PASS.

- [ ] **Step 7: Run full suite and analyzer**

Run: `flutter test && flutter analyze`
Expected: all tests pass, no analyzer issues.

- [ ] **Step 8: Commit**

```bash
git add lib/src/storage/period_stats_writer.dart lib/src/providers/current_period_stats_sync_provider.dart lib/src/providers/current_period_stats_sync_provider.g.dart test/current_period_stats_sync_provider_test.dart
git commit -m "feat: reactively sync current_stats.md with current period data"
```

---

### Task 5: Wire into the app — AppShell activation + Settings toggle UI

**Files:**
- Modify: `lib/src/views/app_shell.dart:17-21` (build method top)
- Modify: `lib/src/views/settings_view.dart` (imports + new section after Data Storage, around line 180)

**Interfaces:**
- Consumes: `currentPeriodStatsSyncProvider` (Task 4), `aiStatsSettingsProvider` (Task 3).
- Produces: nothing consumed by later tasks (final task).

- [ ] **Step 1: Keep the sync provider alive from AppShell**

In `lib/src/views/app_shell.dart`, add the import:

```dart
import '../providers/current_period_stats_sync_provider.dart';
```

and add one line at the top of `AppShell.build` (right after `final periodsAsync = ref.watch(allPeriodsProvider);`):

```dart
    // Keep the stats-file sync alive for the app's lifetime; the value is
    // irrelevant, only the subscription matters.
    ref.watch(currentPeriodStatsSyncProvider);
```

- [ ] **Step 2: Add the Settings toggle section**

In `lib/src/views/settings_view.dart`, add the import:

```dart
import '../providers/ai_stats_settings_provider.dart';
```

In `build`, next to the other watches (after `final storageDirAsync = ref.watch(storageSettingsProvider);`):

```dart
    final aiStatsEnabled = ref.watch(aiStatsSettingsProvider).value ?? true;
```

Then insert a new section between the Data Storage container and the "Active Tracking Instance" section header (i.e. immediately after the existing `const SizedBox(height: 32),` that follows the Data Storage container):

```dart
          // ─── AI Insights Data ─────────────────────────────
          _SectionHeader(
            icon: Icons.insights_rounded,
            title: 'AI Insights Data',
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                width: 0.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Generate current period stats',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                    Switch(
                      value: aiStatsEnabled,
                      onChanged: (value) => ref
                          .read(aiStatsSettingsProvider.notifier)
                          .setEnabled(value),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Writes a current_stats.md snapshot next to your period '
                  'files on every change, ready to feed AI spending insights. '
                  'Disabling removes the file.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
```

- [ ] **Step 3: Full suite + analyzer**

Run: `flutter test && flutter analyze`
Expected: all tests pass, no analyzer issues.

- [ ] **Step 4: Manual end-to-end verification**

Run: `flutter run -d linux` (or current desktop platform), then:
1. Open a period, add a fact expense, wait ~1s (debounced save) — verify `current_stats.md` appears in the periods directory and contains the new spend.
2. Open Settings → "AI Insights Data" — toggle off — verify the file disappears from the periods directory.
3. Toggle back on, edit any expense — verify the file reappears.

Expected: all three behaviors observed.

- [ ] **Step 5: Commit**

```bash
git add lib/src/views/app_shell.dart lib/src/views/settings_view.dart
git commit -m "feat: activate stats sync and add AI Insights Data settings toggle"
```
