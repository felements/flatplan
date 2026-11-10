# Stats Page Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Stats page that graphs, period by period, the recorded totals of All (spent and earned), any category and any tag, with a category's per-period limit as a stepped line.

**Architecture:** All figures come from one provider-free module, `lib/src/logic/stats_series.dart`. It picks the periods, builds the subject list, and produces one value (and limit) per period per line. A chart component maps that onto `fl_chart`. A hooks-based `StatsView` holds the selection, search text and range, and lives in its own `StatefulShellBranch` (index 2), so its state survives navigation.

**Tech Stack:** Flutter 3.47 / Dart 3.11, Riverpod 3 (`allPeriodsProvider`), `flutter_hooks`, GoRouter `StatefulShellRoute`, `fl_chart` 1.3.1 (new), `intl`.

**Spec:** `docs/superpowers/specs/2026-11-10-stats-page-design.md`

## Global Constraints

- Derived figures live only in `lib/src/logic/` (AGENTS.md rule 4). Views and components map data to widgets and compute no sums.
- A period's All spent and earned must equal `periodStatsFor(...).totalSpent` / `.totalFactIncome`. A category value must equal `categoryStatsFor(...).totalSpent` for the same period, summed over same-key duplicates.
- Amounts: `NumberFormat.decimalPatternDigits(decimalDigits: 0)`, no currency symbol.
- X labels: `DateFormat('MMM yy').format(period.startDate)`; tooltip header: `period.name`.
- Colours: All's spent is `colorScheme.secondary` and earned is `colorScheme.primary`. Other lines take `statsPalette` (8 colours, no coral / `colorScheme.error`) in tick order, wrapping around.
- Limit line: the same colour at alpha 0.55, `dashArray [6, 4]`, width 2, stepped at the midpoint between periods, no dots.
- Current period: the stretch into it uses `dashArray [5, 4]`, and its point is hollow (the card colour as fill, the line colour as stroke).
- Cards use `summaryCardDecoration(context)` from `lib/src/components/summary_card.dart` (16 px radius per `doc/08_design_guidelines.md`).
- `fl_chart: ^1.3.1` is the only new dependency.
- Commits are local, conventional-commit headlines, each ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. **Do not push** until Task 5's final step, when everything is green.

## Review Focus

1. **A vault with a single period.** It must draw one point, not crash on `minX == maxX` (Task 3 test `a single period draws without errors`).
2. **Refunds that make a total negative.** The Y axis must reach below 0 instead of clipping (Task 3 test `y bounds reach below zero for a negative total`).
3. **Three years of periods.** The X labels must thin out rather than overlap (Task 3 test `bottom labels thin out past twelve periods`).
4. **A narrow window, about 900 px with the 220 px sidebar.** The page must lay out without overflow errors (Task 4 test `lays out in a narrow window without overflow`).
5. **The light theme.** The page must build and stay readable; it is only checked for exceptions (Task 4 test `builds under the light theme`).

---

### Task 1: Subjects, periods and selection rules

**Files:**
- Create: `lib/src/logic/stats_series.dart`
- Modify: `lib/src/logic/payment_tags.dart` (rename private `_spendingByTag` to public `spendingByTag`; `topTags` keeps using it)
- Create: `test/support/stats_fixtures.dart`
- Test: `test/stats_series_test.dart`

**Interfaces:**
- Consumes: `splitTags`, `spendingByTag(Period) → Map<String, double>` (expense categories only, full amount per tag) from `payment_tags.dart`.
- Produces:
  - `enum StatsSubjectKind { all, expenseCategory, incomeCategory, tag }`
  - `class StatsSubject` with `kind`, `key` and `label`:
    - `static const all` (label `'All'`, key `''`).
    - `factory StatsSubject.category(String name, {required bool income})`: the key is `categoryKey(name)` and the label is `name.trim()`.
    - `factory StatsSubject.tag(String tag)`: key and label are both `tag`.
    - `bool get hasLimit` is true for both category kinds.
    - `==` and `hashCode` use `kind` and `key` only.
  - `String categoryKey(String name)`, which returns `name.trim().toLowerCase()`.
  - `class SubjectCatalog { final List<StatsSubject> expenses, income, tags; }` and `SubjectCatalog subjectCatalog(List<Period> periods)`.
  - `class MonthRange { MonthRange(DateTime from, DateTime to); final DateTime from, to; }`: both ends are stored as `DateTime(y, m)`.
  - `List<Period> chartPeriods(List<Period> periods, {required DateTime today, MonthRange? range})`
  - `List<DateTime> availableMonths(List<Period> periods, {required DateTime today})`
  - `List<StatsSubject> toggleSubject(List<StatsSubject> selected, StatsSubject subject)`
  - Test helpers in `test/support/stats_fixtures.dart`:
    - `Period period(String id, DateTime start, List<Category> categories)`: the name is `DateFormat('MMMM yy').format(start)`, and the base currency is `'EUR'`.
    - `Category category(String name, {CategoryType type = CategoryType.optionalExpense, double? limit, List<double> planned = const [], List<(double, String?)> facts = const []})`: ids are derived from name and index.

- [ ] **Step 1: Write the fixtures and the failing tests** (`today = DateTime(2026, 11, 10)` throughout)

```dart
test('chartPeriods sorts by start date and drops periods starting after today', () {
  final ps = [period('oct', DateTime(2026, 10, 5), []), period('sep', DateTime(2026, 9, 5), []),
              period('nov', DateTime(2026, 11, 5), []), period('dec', DateTime(2026, 11, 11), [])];
  expect(chartPeriods(ps, today: today).map((p) => p.id), ['sep', 'oct', 'nov']);
  expect(chartPeriods([period('t', DateTime(2026, 11, 10), [])], today: today).map((p) => p.id), ['t']);
});
test('chartPeriods keeps periods whose start month is in the range, both ends included', () {
  // sep, oct, nov as above
  expect(chartPeriods(ps, today: today, range: MonthRange(DateTime(2026, 10), DateTime(2026, 11))).map((p) => p.id), ['oct', 'nov']);
  expect(chartPeriods(ps, today: today, range: MonthRange(DateTime(2026, 12), DateTime(2026, 12))), isEmpty);
});
test('availableMonths lists each start month once, oldest first, without future periods', () {
  // starts: Sep 5, Sep 25, Oct 5, Dec 1
  expect(availableMonths(ps, today: today), [DateTime(2026, 9), DateTime(2026, 10)]);
});
test('a category subject is keyed by trimmed lower-case name within its kind', () {
  expect(StatsSubject.category(' Groceries ', income: false), StatsSubject.category('groceries', income: false));
  expect(StatsSubject.category('Other', income: false), isNot(StatsSubject.category('Other', income: true)));
  expect(StatsSubject.category(' Groceries ', income: false).label, 'Groceries');
});
test('subjectCatalog groups subjects, names them as in the latest period and sorts them', () {
  // oct (Oct 5): groceries (optional), home (mandatory, fact (900, 'tiles #Renovation')), Salary (income, fact (5200, '#bonus'))
  // nov (Nov 5): Groceries (optional), home (optional), Other (optional), Other (income)
  final c = subjectCatalog(ps);
  expect(c.expenses.map((s) => s.label), ['Groceries', 'home', 'Other']);
  expect(c.income.map((s) => s.label), ['Other', 'Salary']);
  expect(c.tags.map((s) => s.label), ['renovation']); // #bonus is on income, so not listed
});
test('toggleSubject keeps All exclusive and never leaves nothing ticked', () {
  final g = StatsSubject.category('Groceries', income: false), t = StatsSubject.tag('renovation');
  expect(toggleSubject([StatsSubject.all], g), [g]);
  expect(toggleSubject([g], t), [g, t]);
  expect(toggleSubject([g, t], g), [t]);
  expect(toggleSubject([t], t), [StatsSubject.all]);
  expect(toggleSubject([g, t], StatsSubject.all), [StatsSubject.all]);
  expect(toggleSubject([StatsSubject.all], StatsSubject.all), [StatsSubject.all]);
});
```

- [ ] **Step 2: Run them and watch them fail**

Run: `flutter test test/stats_series_test.dart`
Expected: compilation failure (`stats_series.dart` does not exist).

- [ ] **Step 3: Implement `stats_series.dart` and make `spendingByTag` public**

How each function works:
- `chartPeriods` compares calendar days: a period is dropped when `DateTime(start.y, start.m, start.d)` is after `DateTime(today.y, today.m, today.d)`.
- `subjectCatalog`:
  - walks the periods newest first, so the first spelling seen for a key wins;
  - puts mandatory and optional categories in `expenses` and income categories in `income`;
  - takes tags from `spendingByTag(period).keys`;
  - sorts each group by `label.toLowerCase()`.

- [ ] **Step 4: Run the tests and watch them pass**

Run: `flutter test test/stats_series_test.dart test/payment_tags_test.dart`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add lib/src/logic/stats_series.dart lib/src/logic/payment_tags.dart test/support/stats_fixtures.dart test/stats_series_test.dart
git commit -m "feat: add stats subjects, chart periods and selection rules"
```

---

### Task 2: Per-period lines, limits and tooltip rows

**Files:**
- Modify: `lib/src/logic/stats_series.dart`
- Test: `test/stats_series_test.dart`, a new group `buildStatsChart`

**Interfaces:**
- Consumes:
  - from Task 1: `StatsSubject`, `MonthRange`, `chartPeriods`, `categoryKey`, `spendingByTag`;
  - from the models: `Category.effectiveLimit` (`models/category_budget.dart`);
  - `effectiveEndDate(period, allPeriods)` (`logic/period_extensions.dart`).
- Produces:
  - `enum StatsLineRole { spent, earned, value }`
  - `class StatsLine { StatsSubject subject; StatsLineRole role; List<double?> values; List<double?>? limits; String get label; }`:
    - `values` holds one entry per chart period, and `null` means a gap.
    - `limits` is non-null only for category subjects; a `null` entry means no limit in that period.
    - `label` is `'Spent'`, `'Earned'` or `subject.label`.
  - `class StatsChart { List<Period> periods; List<StatsLine> lines; int? inProgressIndex; bool get isEmpty; }`: `isEmpty` is true when every value in every line is `null` or `0`.
  - `StatsChart buildStatsChart({required List<Period> allPeriods, required List<StatsSubject> subjects, required DateTime today, MonthRange? range})`: `StatsSubject.all` expands to two lines, spent then earned. The lines follow `subjects` order.
  - `class StatsTooltipRow { StatsLine line; double value; double? limit; }` and `List<StatsTooltipRow> tooltipRows(StatsChart chart, int index)`: rows follow line order, and lines with a gap at `index` are left out.

- [ ] **Step 1: Write the failing tests**

Fixture, with `today = DateTime(2026, 11, 10)`:
- **sep** (Sep 5):
  - Groceries: limit 800, fact 820.
  - Home: mandatory, limit 1000, fact `(900, 'tiles #renovation')`.
  - Salary: income, limit 5000, fact 5200.
- **oct** (Oct 5):
  - Groceries: limit 750, planned `[500, 400]`, facts `(700, null)` and `(10, 'paint #renovation #tws')`.
  - Salary: income, limit 5000, fact `(5200, '#renovation')`.
- **nov** (Nov 5):
  - Groceries: limit 700, no facts.
  - Gifts: no limit, nothing planned, fact 50.
  - Salary: income, limit 5000, no facts.

```dart
test('All gives spent and earned lines equal to the dashboard totals', () {
  final chart = buildStatsChart(allPeriods: ps, subjects: [StatsSubject.all], today: today);
  expect(chart.lines.map((l) => l.label), ['Spent', 'Earned']);
  expect(chart.lines[0].values, [1720, 710, 50]);
  expect(chart.lines[1].values, [5200, 5200, 0]);
  for (var i = 0; i < 3; i++) {
    final s = periodStatsFor(period: chart.periods[i], allPeriods: ps, now: today);
    expect(chart.lines[0].values[i], s.totalSpent);
    expect(chart.lines[1].values[i], s.totalFactIncome);
  }
  expect(chart.lines.every((l) => l.limits == null), isTrue);
});
test('a category line matches its tile, with a gap where the category did not exist', () {
  // subjects: Home, Groceries (expense)
  expect(home.values, [900, null, null]);
  expect(groceries.values, [820, 710, 0]);
  // and each non-null value == categoryStatsFor(category:, period:, endDate: effectiveEndDate(p, ps), allPeriods: ps, now: today).totalSpent
});
test('a category limit line follows each period\'s effective limit', () {
  expect(groceries.limits, [800, 900, 700]);   // oct: planned 900 beats limit 750
  expect(home.limits, [1000, null, null]);
  expect(gifts.limits, [null, null, null]);    // no limit, nothing planned
});
test('an income category is its own subject and its limit is the planned income', () {
  expect(salary.values, [5200, 5200, 0]);
  expect(salary.limits, [5000, 5000, 5000]);
});
test('expense and income categories sharing a name stay apart', () {
  // one period: Other (optional) fact 30, Other (income) fact 100
  expect(expenseOther.values, [30]);
  expect(incomeOther.values, [100]);
});
test('same-key categories in one period add up, limits too', () {
  // one period: Groceries (limit 300, fact 10), groceries (limit 200, fact 20)
  expect(line.values, [30]);
  expect(line.limits, [500]);
});
test('a tag line sums expense payments carrying it, in full under each tag', () {
  expect(renovation.values, [900, 10, 0]);   // Salary's #renovation is income: not counted
  expect(tws.values, [0, 10, 0]);
  expect(renovation.limits, isNull);
});
test('a subject found nowhere gives gaps for a category and zeros for a tag', () {
  expect(nopeCategory.values, [null, null, null]);
  expect(nopeTag.values, [0, 0, 0]);
});
test('the period covering today is marked in progress', () {
  expect(buildStatsChart(allPeriods: ps, subjects: [StatsSubject.all], today: today).inProgressIndex, 2);
  expect(buildStatsChart(allPeriods: ps, subjects: [StatsSubject.all], today: DateTime(2027, 3, 1)).inProgressIndex, isNull);
});
test('a range limits the periods and moves the in-progress index', () {
  final chart = buildStatsChart(allPeriods: ps, subjects: [groceriesSubject], today: today,
      range: MonthRange(DateTime(2026, 10), DateTime(2026, 11)));
  expect(chart.periods.map((p) => p.id), ['oct', 'nov']);
  expect(chart.lines.single.values, [710, 0]);
  expect(chart.inProgressIndex, 1);
});
test('isEmpty only when every value is missing or zero', () {
  expect(buildStatsChart(allPeriods: ps, subjects: [StatsSubject.tag('nope')], today: today).isEmpty, isTrue);
  expect(buildStatsChart(allPeriods: ps, subjects: [StatsSubject.all], today: today).isEmpty, isFalse);
});
test('tooltipRows lists lines in order and skips gaps', () {
  final chart = buildStatsChart(allPeriods: ps, subjects: [homeSubject, groceriesSubject], today: today);
  final at0 = tooltipRows(chart, 0);
  expect(at0.map((r) => (r.line.label, r.value, r.limit)), [('Home', 900, 1000), ('Groceries', 820, 800)]);
  expect(tooltipRows(chart, 1).map((r) => (r.line.label, r.value, r.limit)), [('Groceries', 710, 900)]);
});
```

- [ ] **Step 2: Run them and watch them fail**

Run: `flutter test test/stats_series_test.dart`
Expected: compilation failure (`buildStatsChart` is not defined).

- [ ] **Step 3: Implement `buildStatsChart`, `StatsChart.isEmpty` and `tooltipRows`**

How it works:
- **Periods:** `chartPeriods(allPeriods, today:, range:)`.
- **In-progress index:** the index of the chart period whose start day ≤ today ≤ the day of `effectiveEndDate(p, allPeriods)`. Use `allPeriods` here, not just the chart's periods, so a range cannot change where a period ends.
- **Category value:** the sum of `factExpenses` over the period's categories whose `categoryKey(name)` and kind (`type == income`) match the subject. With no match the value is `null`.
- **Category limit:** the sum of `effectiveLimit` over the same categories. It is `null` with no match or when the sum is 0.
- **Tag value:** `spendingByTag(p)[key] ?? 0`.

- [ ] **Step 4: Run the tests and watch them pass**

Run: `flutter test test/stats_series_test.dart`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add lib/src/logic/stats_series.dart test/stats_series_test.dart
git commit -m "feat: compute per-period stats lines, limits and tooltip rows"
```

---

### Task 3: The line chart component

**Files:**
- Modify: `pubspec.yaml` and `pubspec.lock`, via `flutter pub add fl_chart:^1.3.1`
- Create: `lib/src/components/stats_line_chart.dart`
- Test: `test/stats_line_chart_test.dart`

**Interfaces:**
- Consumes: `StatsChart`, `StatsLine`, `tooltipRows` from Task 2.
- Produces:
  - `const statsPalette = <Color>[...]`: 8 colours, each readable on `#1E1E2E` and on the light card colour. Teal, gold and coral are left out.
  - `List<Color> statsLineColors(StatsChart chart, ColorScheme scheme)`: one colour per line, as in Global Constraints.
  - `int bottomLabelInterval(int periodCount)`, which returns `max(1, (periodCount / 12).ceil())`.
  - `({double minY, double maxY}) statsYBounds(StatsChart chart)`, taken over every value and limit:
    - `minY` is `lowest * 1.1` when the lowest is below 0, and `0` otherwise.
    - `maxY` is `highest * 1.1` when the highest is above 0, and `1` otherwise.
  - `class StatsLineChart extends StatelessWidget { const StatsLineChart({super.key, required this.chart, required this.colors}); final StatsChart chart; final List<Color> colors; }`

The bars, per line in order:
1. A **solid run** over the indices `0 .. (inProgressIndex ?? n) - 1`. It is left out when that range is empty.
2. When `inProgressIndex` is set, a **dashed stretch** over the indices `max(0, inProgressIndex - 1) .. inProgressIndex`. Its last dot is hollow.
3. When `limits != null`, a **limit bar**:
   - `isStepLineChart: true` with `LineChartStepData(stepDirection: LineChartStepData.stepDirectionMiddle)`;
   - colour as in Global Constraints, `dashArray [6, 4]`, `barWidth 2`, dots hidden.

A `null` value or limit becomes `FlSpot.nullSpot`.

Chart settings:
- `minX` is −0.5 and `maxX` is n − 0.5.
- Bottom titles only at whole-number x divisible by `bottomLabelInterval(n)`.
- Left titles use the Global Constraints number format.
- The tooltip's `getTooltipItems` returns one item for the first touched spot and `null` for the rest. That item shows:
  - `period.name` in bold;
  - one line per `tooltipRows(chart, x)` row, reading `label  value`;
  - for a row with a limit, an extra line reading `limit  value`.

- [ ] **Step 1: Add the dependency**

Run: `flutter pub add fl_chart:^1.3.1`
Expected: `+ fl_chart 1.3.1` and `+ equatable 3.0.0`.

- [ ] **Step 2: Write the failing tests** (read the bars through `tester.widget<LineChart>(find.byType(LineChart)).data.lineBarsData`)

```dart
testWidgets('draws a solid run, a dashed stretch into the current period and a stepped dashed limit', ...);
  // 3 periods, inProgressIndex 2, one line: Groceries, values [null, 710, 0], limits [800, 900, 700]
  expect(bars, hasLength(3));
  expect(bars[0].spots[0].isNull(), isTrue); expect(bars[0].spots[1], const FlSpot(1, 710)); expect(bars[0].dashArray, isNull);
  expect(bars[1].spots, const [FlSpot(1, 710), FlSpot(2, 0)]); expect(bars[1].dashArray, [5, 4]);
  expect(bars[2].isStepLineChart, isTrue); expect(bars[2].dashArray, [6, 4]);
  expect(bars[2].spots, const [FlSpot(0, 800), FlSpot(1, 900), FlSpot(2, 700)]);
  expect(bars[2].color, colors[0].withValues(alpha: 0.55));
testWidgets('without a period in progress each line is one solid run', ...);
  // tag line [0, 10, 0], inProgressIndex null → bars.length 1, spots.length 3
testWidgets('a single period draws without errors', ...);
  // 1 period, inProgressIndex 0 → bars[0].spots == [FlSpot(0, v)]; minX -0.5, maxX 0.5; tester.takeException() isNull
test('statsLineColors: All uses teal and gold, others the palette in order, wrapping', ...);
  // All → [scheme.secondary, scheme.primary]; 10 subject lines → colors[9] == statsPalette[1]; statsPalette does not contain scheme.error
test('bottom labels thin out past twelve periods', ...);
  // bottomLabelInterval: 1→1, 12→1, 13→2, 36→3
test('y bounds reach below zero for a negative total', ...);
  // values [-40, 100], limits [null, 120] → (minY: -44, maxY: 132); all zero → (minY: 0, maxY: 1)
```

- [ ] **Step 3: Run them and watch them fail**

Run: `flutter test test/stats_line_chart_test.dart`
Expected: compilation failure (`stats_line_chart.dart` does not exist).

- [ ] **Step 4: Implement `stats_line_chart.dart`**

Check each `fl_chart` name above against the 1.3.1 API (`FlSpot.nullSpot`, `LineChartStepData`, `FlDotCirclePainter`, `LineTouchTooltipData.getTooltipItems` / `getTooltipColor`). If a name differs, keep the behaviour this task describes.

- [ ] **Step 5: Run the tests and watch them pass**

Run: `flutter test test/stats_line_chart_test.dart`
Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/src/components/stats_line_chart.dart test/stats_line_chart_test.dart
git commit -m "feat: add the stats line chart on fl_chart"
```

---

### Task 4: The Stats page

**Files:**
- Create: `lib/src/views/stats_view.dart`
- Test: `test/stats_view_test.dart`. For the pump helper, copy `_pump` from `test/payment_tags_view_test.dart` (`ProviderScope` overriding `periodRepositoryProvider` with a `PeriodRepository(workspace: MemoryWorkspace())`) and wrap it in `MaterialApp(home: Scaffold(body: StatsView()))`.

**Interfaces:**
- Consumes:
  - `allPeriodsProvider`;
  - from Task 1: `subjectCatalog`, `availableMonths`, `toggleSubject`;
  - from Task 2: `buildStatsChart`;
  - from Task 3: `StatsLineChart`, `statsLineColors`;
  - `summaryCardDecoration`.
- Produces: `class StatsView extends HookConsumerWidget { const StatsView({super.key}); }`

The page:
- **State:** `useState` for:
  - `selected`, starting as `[StatsSubject.all]`;
  - `range`, a `MonthRange?` starting as `null`;
  - `query`, starting as `''`.

  `today` is `DateTime.now()`. The list is `subjectCatalog(allPeriods)`, built from every loaded period, so picking a range never shortens it. The chart is `buildStatsChart(allPeriods:, subjects: selected, today:, range:)`.
- **Header:**
  - On the left: `Icon(Icons.show_chart_rounded, size: 18, color: primary)`, 8 px, then `Text('Stats')` in titleLarge bold.
  - On the right: an `OutlinedButton` with `key: const ValueKey('stats-range')`. Its label is `'All periods'`, or `'${MMM yyyy from} – ${MMM yyyy to}'` when a range is set.
- **Range dialog:** the button opens it with `showDialog`. It contains:
  - `RadioListTile`s reading `'All periods'` and `'From – to'`;
  - two `DropdownButton<DateTime>`s keyed `stats-range-from` and `stats-range-to`, over `availableMonths`, labelled `MMM yyyy`;
  - a `'Apply'` button.

  Picking a from-month later than the to-month moves the to-month to match, and the reverse.
- **Body, from 640 px wide:** a `Row` with:
  - the list card (width 220, padding 12);
  - a 16 px gap;
  - the graph card (`Expanded`, padding 16).

  Below 640 px: a `Column` with the list card (height ≤ 240) above the graph card.
- **List card:**
  - A `TextField` with hint `'Search…'`, filtering every group by case-insensitive substring.
  - The groups `TOTALS` (one row reading `'All (spent & earned)'`), `EXPENSES`, `INCOME` and `TAGS`, in bodySmall muted letter-spaced caps. A group with no matching rows is hidden.
  - Each row has `key: ValueKey('stats-subject-${kind.name}-$key')`, a `Checkbox`, the label, and the line's colour dot when ticked. Tapping it calls `toggleSubject`.
- **Graph card:**
  - First, a legend: one dot and label per line.
  - Then `StatsLineChart` (height 320).
  - `chart.periods` empty, but the vault has periods: `Text('No periods in this range.')` instead of the chart.
  - `chart.isEmpty`: the chart is drawn, followed by `Text('Nothing recorded for these subjects in this range.')`.
  - No periods at all, with no range set: the page shows `Text('No periods to chart yet.')` in place of both cards.

- [ ] **Step 1: Write the failing tests**

The fixture holds three periods. Their start days come from `_midnightDaysAgo` (40, 70 and 5 days ago), so the newest one covers today. Categories: Groceries, Home and Salary (income), with a `#renovation` fact.

```dart
testWidgets('opens on All with spent and earned lines', ...);
  // Checkbox inside ValueKey('stats-subject-all-') is ticked; chart.lines labels == ['Spent', 'Earned']
testWidgets('ticking a category replaces All; unticking it brings All back', ...);
  // tap 'stats-subject-expenseCategory-groceries' → lines == ['Groceries'], All unticked; tap again → ['Spent', 'Earned']
testWidgets('several subjects make several lines in tick order', ...);
  // tap groceries, then 'stats-subject-tag-renovation' → lines == ['Groceries', 'renovation']
testWidgets('search filters the list', ...);
  // enterText 'gro' → find.text('Home') findsNothing, find.text('Groceries') findsOneWidget
testWidgets('a from–to range narrows the periods', ...);
  // open dialog, choose 'From – to', set from = to = newest start month, Apply → button label is that month twice, e.g. 'Nov 2026 – Nov 2026'; chart.periods.length == 1
testWidgets('an empty vault says there is nothing to chart', ...);
  // no periods → find.text('No periods to chart yet.') findsOneWidget
testWidgets('lays out in a narrow window without overflow', ...);
  // size Size(680, 800) → tester.takeException() isNull; both cards present
testWidgets('builds under the light theme', ...);
  // MaterialApp(theme: AppTheme.lightTheme) → takeException() isNull
```

Read the chart through `tester.widget<StatsLineChart>(find.byType(StatsLineChart)).chart`.

- [ ] **Step 2: Run them and watch them fail**

Run: `flutter test test/stats_view_test.dart`
Expected: compilation failure (`stats_view.dart` does not exist).

- [ ] **Step 3: Implement `StatsView` as described above**

- [ ] **Step 4: Run the tests and watch them pass**

Run: `flutter test test/stats_view_test.dart`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add lib/src/views/stats_view.dart test/stats_view_test.dart
git commit -m "feat: add the stats page with subject list and range picker"
```

---

### Task 5: Navigation, docs and delivery

**Files:**
- Modify:
  - `lib/src/routing/app_router.dart`: a third `StatefulShellBranch` (index 2), with `_shellNavigatorStatsKey` and `GoRoute(path: '/stats', builder: (_, _) => const StatsView())`.
  - `lib/src/views/app_shell.dart`: `_SidebarItem(icon: Icons.show_chart_rounded, label: 'Stats', isSelected: selectedIndex == 2, onTap: () => navigationShell.goBranch(2, initialLocation: selectedIndex == 2))`, placed directly after the Today item and before `_NextPeriodButton`.
- Test: `test/app_shell_stats_nav_test.dart`. Copy `pumpShell` from `test/app_shell_new_period_test.dart`, and add a third branch with `/stats` → `const Text('stats page')`.
- Docs:
  - `CHANGELOG.md`: `[Unreleased]` → Added.
  - `doc/03_ui_pages_components.md`: a new "Stats" page section.
  - `doc/08_design_guidelines.md`: in the Sidebar Navigation bullet, the order becomes Today, Stats, then "+ Next period".
  - `AGENTS.md`: in Key Architecture, add `stats_series.dart` to logic, `StatsView` to views, `StatsLineChart` to components, and mention the Stats branch in the routing line.

**Interfaces:**
- Consumes: `StatsView` from Task 4.

- [ ] **Step 1: Write the failing test**

```dart
testWidgets('Stats sits under Today, above Next period, and opens the stats page', ...);
  // dy(Today) < dy(Stats) < dy('Next period'); tap 'Stats'; pumpAndSettle → find.text('stats page') findsOneWidget
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/app_shell_stats_nav_test.dart`
Expected: FAIL, `find.text('Stats')` finds nothing.

- [ ] **Step 3: Add the branch and the sidebar item**

- [ ] **Step 4: Run it and watch it pass**

Run: `flutter test test/app_shell_stats_nav_test.dart test/app_shell_new_period_test.dart`
Expected: all pass.

- [ ] **Step 5: Write the docs.** CHANGELOG line, exactly:

`- A Stats page (sidebar → Stats) graphs recorded spending and income period by period. Tick All, any category or any tag — several at once — and choose all periods or a from–to month range. A ticked category also shows its limit in each period as a stepped dashed line.`

- [ ] **Step 6: Verify the whole branch**

Run: `dart format lib/src/logic/stats_series.dart lib/src/components/stats_line_chart.dart lib/src/views/stats_view.dart lib/src/views/app_shell.dart lib/src/routing/app_router.dart test/stats_series_test.dart test/stats_line_chart_test.dart test/stats_view_test.dart test/app_shell_stats_nav_test.dart test/support/stats_fixtures.dart`. Format only these files; formatting the whole tree touches unrelated files.

Then run `flutter analyze`. Expected: `No issues found!`.

Then run `flutter test`. Expected: all tests pass, with the total above today's 541.

- [ ] **Step 7: Look at it running**

Stop the running app, then run `GDK_BACKEND=x11 flutter run -d linux`, open Stats and take a screenshot. Check:
- All shows two lines;
- ticking a category draws its stepped limit;
- the current period's stretch is dashed.

Don't edit the user's vault data.

- [ ] **Step 8: Commit, then push and open the PR**

This happens only now, with everything green.

```bash
git add lib/src/routing/app_router.dart lib/src/views/app_shell.dart test/app_shell_stats_nav_test.dart CHANGELOG.md doc/03_ui_pages_components.md doc/08_design_guidelines.md AGENTS.md
git commit -m "feat: add Stats to the sidebar and document the page"
git push -u origin feat/stats-page
gh pr create --base main --title "feat: stats page with per-period trend lines" --body "<summary, test plan, then the Claude Code attribution line>"
```
