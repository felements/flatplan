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
