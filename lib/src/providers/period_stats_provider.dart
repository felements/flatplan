import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'all_periods_provider.dart';
import 'current_period_provider.dart';
import '../logic/period_extensions.dart';
import '../models/category_type.dart';

part 'period_stats_provider.freezed.dart';
part 'period_stats_provider.g.dart';

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

@riverpod
FutureOr<PeriodStats?> periodStats(Ref ref) async {
  final currentPeriod = await ref.watch(currentPeriodProvider.future);
  if (currentPeriod == null) return null;

  final allPeriods = await ref.watch(allPeriodsProvider.future);
  final endDate = effectiveEndDate(currentPeriod, allPeriods);

  double totalMandatoryBudget = 0;
  double totalMandatorySpent = 0;
  double totalOptionalBudget = 0;
  double totalOptionalSpent = 0;
  double totalIncome = 0;
  double totalFactIncome = 0;
  double effectiveTotalExpenseForFreeBalance = 0;

  final categoryStatsList = <CategoryStats>[];

  for (final category in currentPeriod.categories) {
    // 1. Calculate Spent
    final spent = category.factExpenses.fold<double>(
      0,
      (previousValue, element) => previousValue + element.amount,
    );

    // 2. Calculate Planned constraints
    final planned = category.plannedExpenses.fold<double>(
      0,
      (previousValue, element) => previousValue + element.amount,
    );

    // 3. Category budget limit (fallback to planned if no hard limit is set)
    final limit = category.limit ?? planned;

    final remaining = limit - spent;
    final heatPercentage = limit > 0 ? (spent / limit) : 0.0;
    final isOverBudget = spent > limit;

    int daysLeft = endDate.difference(DateTime.now()).inDays;
    // ensure at least 1 day to prevent division by zero
    if (daysLeft < 1) daysLeft = 1;

    double? dailyAllowanceAmount;
    int? expectedPurchaseFrequencyDays;
    double? expectedPurchaseAmount;
    if (category.isDailyAllowance) {
      dailyAllowanceAmount = remaining > 0 ? remaining / daysLeft : 0.0;

      if (category.factExpenses.length >= 2 && remaining > 0) {
        // Calculate 20% Trimmed Mean (drop the lowest 20% of expenses)
        final sortedExpenses =
            category.factExpenses.map((e) => e.amount).toList()..sort();
        final dropCount = (sortedExpenses.length * 0.2).floor();
        final keptExpenses = sortedExpenses.sublist(dropCount);

        if (keptExpenses.isNotEmpty) {
          final keptSpent = keptExpenses.fold<double>(
            0,
            (prev, amount) => prev + amount,
          );
          final avgExpense = keptSpent / keptExpenses.length;

          if (avgExpense > 0) {
            final affordablePurchases = remaining / avgExpense;
            if (affordablePurchases > 0) {
              expectedPurchaseFrequencyDays = (daysLeft / affordablePurchases)
                  .round();
              expectedPurchaseAmount = avgExpense;
            }
          }
        }
      }
    }

    // 4. Aggregate totals
    if (category.type == CategoryType.mandatoryExpense) {
      totalMandatoryBudget += limit;
      totalMandatorySpent += spent;
      effectiveTotalExpenseForFreeBalance += spent > limit ? spent : limit;
    } else if (category.type == CategoryType.optionalExpense) {
      totalOptionalBudget += limit;
      totalOptionalSpent += spent;
      effectiveTotalExpenseForFreeBalance += spent > limit ? spent : limit;
    } else if (category.type == CategoryType.income) {
      totalIncome += limit;
      totalFactIncome += spent;
    }

    categoryStatsList.add(
      CategoryStats(
        categoryId: category.id,
        name: category.name,
        type: category.type,
        limit: limit,
        totalSpent: spent,
        totalPlanned: planned,
        remaining: remaining,
        heatPercentage: heatPercentage,
        isOverBudget: isOverBudget,
        isDailyAllowance: category.isDailyAllowance,
        dailyAllowanceAmount: dailyAllowanceAmount,
        expectedPurchaseFrequencyDays: expectedPurchaseFrequencyDays,
        expectedPurchaseAmount: expectedPurchaseAmount,
      ),
    );
  }

  // Sort categories by highest heat percentage (closest to over budget)
  categoryStatsList.sort(
    (a, b) => b.heatPercentage.compareTo(a.heatPercentage),
  );

  final totalBudget = totalMandatoryBudget + totalOptionalBudget;
  final totalSpent = totalMandatorySpent + totalOptionalSpent;
  final overallRemaining = totalBudget - totalSpent;
  final remainingFreeBalance =
      totalFactIncome - effectiveTotalExpenseForFreeBalance;

  return PeriodStats(
    totalMandatoryBudget: totalMandatoryBudget,
    totalMandatorySpent: totalMandatorySpent,
    totalOptionalBudget: totalOptionalBudget,
    totalOptionalSpent: totalOptionalSpent,
    totalBudget: totalBudget,
    totalSpent: totalSpent,
    overallRemaining: overallRemaining,
    remainingFreeBalance: remainingFreeBalance,
    totalIncome: totalIncome,
    totalFactIncome: totalFactIncome,
    categoryStats: categoryStatsList,
  );
}
