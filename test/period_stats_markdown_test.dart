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

  test('clamps day number when now is before the period range', () {
    final md = formatCurrentPeriodStatsMarkdown(
      period: _period(),
      stats: _stats([]),
      endDate: endDate,
      now: DateTime(2026, 1, 20), // before the period started
    );
    expect(md, contains('(day 1 of 28, 27 days remaining)'));
  });
}
