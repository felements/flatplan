import 'package:freezed_annotation/freezed_annotation.dart';

import 'allowance_pace.dart';
import 'period_extensions.dart';
import '../models/models.dart';

part 'period_stats.freezed.dart';

enum PlannedExpenseStatus { completed, pending, overdue }

@freezed
sealed class CategoryStats with _$CategoryStats {
  const factory CategoryStats({
    required String categoryId,
    required String name,
    required CategoryType type,
    required double limit,
    required double totalSpent,
    required double totalPlanned,
    required double remaining,
    required double heatPercentage,
    required bool isOverBudget,
    required bool isDailyAllowance,
    @Default(false) bool plannedExceedsLimit,
    @Default([]) List<PlannedExpenseStatus> plannedExpenseStatuses,
    double? dailyAllowanceAmount,
    int? expectedPurchaseFrequencyDays,
    double? expectedPurchaseAmount,
  }) = _CategoryStats;
}

@freezed
sealed class PeriodStats with _$PeriodStats {
  const factory PeriodStats({
    required double totalMandatoryBudget,
    required double totalMandatorySpent,
    required double totalOptionalBudget,
    required double totalOptionalSpent,
    required double totalBudget,
    required double totalSpent,
    required double overallRemaining,
    required double remainingFreeBalance,
    required double totalIncome,
    required double totalFactIncome,
    required List<CategoryStats> categoryStats,
  }) = _PeriodStats;
}

/// Derived figures for a single [category] inside [period].
///
/// Pure: everything it needs is passed in, so the dashboard, the category
/// detail screen and the stats provider all read the same numbers.
CategoryStats categoryStatsFor({
  required Category category,
  required Period period,
  required DateTime endDate,
  required List<Period> allPeriods,
  required DateTime now,
}) {
  final spent = category.factExpenses.fold<double>(
    0,
    (previousValue, element) => previousValue + element.amount,
  );

  final planned = category.plannedTotal;

  // Effective budget: max of planned total and hard limit when a limit is
  // set, otherwise the planned total.
  final limit = category.effectiveLimit;

  final remaining = limit - spent;

  int daysLeft = endDate.difference(now).inDays;
  // Ensure at least 1 day to prevent division by zero.
  if (daysLeft < 1) daysLeft = 1;

  final pace = paceForCategory(
    category: category,
    period: period,
    endDate: endDate,
    allPeriods: allPeriods,
    now: now,
  );

  final isActivePeriod =
      now.isAfter(period.startDate.subtract(const Duration(days: 1))) &&
      now.isBefore(endDate.add(const Duration(days: 1)));

  final plannedExpenseStatuses = <PlannedExpenseStatus>[];
  for (final exp in category.plannedExpenses) {
    if (exp.isCompleted) {
      plannedExpenseStatuses.add(PlannedExpenseStatus.completed);
      continue;
    }
    bool isOverdue = false;
    if (isActivePeriod) {
      final expDate = resolveDueDate(
        exp.dueDate,
        now: now,
        periodStart: period.startDate,
      );
      if (now.isAfter(expDate.add(const Duration(days: 1)))) {
        isOverdue = true;
      }
    }
    plannedExpenseStatuses.add(
      isOverdue ? PlannedExpenseStatus.overdue : PlannedExpenseStatus.pending,
    );
  }

  return CategoryStats(
    categoryId: category.id,
    name: category.name,
    type: category.type,
    limit: limit,
    totalSpent: spent,
    totalPlanned: planned,
    remaining: remaining,
    heatPercentage: limit > 0 ? (spent / limit) : 0.0,
    isOverBudget: spent > limit,
    isDailyAllowance: category.isDailyAllowance,
    plannedExceedsLimit: category.plannedExceedsLimit,
    plannedExpenseStatuses: plannedExpenseStatuses,
    dailyAllowanceAmount: category.isDailyAllowance
        ? (remaining > 0 ? remaining / daysLeft : 0.0)
        : null,
    expectedPurchaseFrequencyDays: pace?.frequencyDays,
    expectedPurchaseAmount: pace?.amount,
  );
}

/// Derived figures for a whole [period], current or historical.
PeriodStats periodStatsFor({
  required Period period,
  required List<Period> allPeriods,
  required DateTime now,
}) {
  final endDate = effectiveEndDate(period, allPeriods);

  double totalMandatoryBudget = 0;
  double totalMandatorySpent = 0;
  double totalOptionalBudget = 0;
  double totalOptionalSpent = 0;
  double totalIncome = 0;
  double totalFactIncome = 0;
  double effectiveTotalExpenseForFreeBalance = 0;

  final categoryStatsList = <CategoryStats>[];

  for (final category in period.categories) {
    final stats = categoryStatsFor(
      category: category,
      period: period,
      endDate: endDate,
      allPeriods: allPeriods,
      now: now,
    );

    switch (category.type) {
      case CategoryType.mandatoryExpense:
        totalMandatoryBudget += stats.limit;
        totalMandatorySpent += stats.totalSpent;
        effectiveTotalExpenseForFreeBalance += stats.isOverBudget
            ? stats.totalSpent
            : stats.limit;
      case CategoryType.optionalExpense:
        totalOptionalBudget += stats.limit;
        totalOptionalSpent += stats.totalSpent;
        effectiveTotalExpenseForFreeBalance += stats.isOverBudget
            ? stats.totalSpent
            : stats.limit;
      case CategoryType.income:
        totalIncome += stats.limit;
        totalFactIncome += stats.totalSpent;
    }

    categoryStatsList.add(stats);
  }

  // Sort categories by highest heat percentage (closest to over budget).
  categoryStatsList.sort((a, b) => b.heatPercentage.compareTo(a.heatPercentage));

  final totalBudget = totalMandatoryBudget + totalOptionalBudget;
  final totalSpent = totalMandatorySpent + totalOptionalSpent;

  return PeriodStats(
    totalMandatoryBudget: totalMandatoryBudget,
    totalMandatorySpent: totalMandatorySpent,
    totalOptionalBudget: totalOptionalBudget,
    totalOptionalSpent: totalOptionalSpent,
    totalBudget: totalBudget,
    totalSpent: totalSpent,
    overallRemaining: totalBudget - totalSpent,
    remainingFreeBalance: totalFactIncome - effectiveTotalExpenseForFreeBalance,
    totalIncome: totalIncome,
    totalFactIncome: totalFactIncome,
    categoryStats: categoryStatsList,
  );
}
