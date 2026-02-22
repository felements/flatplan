import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'current_period_provider.dart';

part 'period_stats_provider.freezed.dart';
part 'period_stats_provider.g.dart';

@freezed
sealed class CategoryStats with _$CategoryStats {
  const factory CategoryStats({
    required String categoryId,
    required String name,
    required bool isMandatory,
    required double limit,
    required double totalSpent,
    required double totalPlanned,
    required double remaining,
    required double heatPercentage,
    required bool isOverBudget,
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
    required List<CategoryStats> categoryStats,
  }) = _PeriodStats;
}

@riverpod
FutureOr<PeriodStats?> periodStats(Ref ref) async {
  final currentPeriod = await ref.watch(currentPeriodProvider.future);
  if (currentPeriod == null) return null;

  double totalMandatoryBudget = 0;
  double totalMandatorySpent = 0;
  double totalOptionalBudget = 0;
  double totalOptionalSpent = 0;

  final categoryStatsList = <CategoryStats>[];

  for (final category in currentPeriod.categories) {
    // 1. Calculate Spent
    final spent = category.factExpenses.fold<double>(
        0, (previousValue, element) => previousValue + element.amount);

    // 2. Calculate Planned constraints
    final planned = category.plannedExpenses.fold<double>(
        0, (previousValue, element) => previousValue + element.amount);

    // 3. Category budget limit (fallback to planned if no hard limit is set)
    final limit = category.limit ?? planned;

    final remaining = limit - spent;
    final heatPercentage = limit > 0 ? (spent / limit).clamp(0.0, 1.0) : 0.0;
    final isOverBudget = spent > limit;

    // 4. Aggregate totals
    if (category.isMandatory) {
      totalMandatoryBudget += limit;
      totalMandatorySpent += spent;
    } else {
      totalOptionalBudget += limit;
      totalOptionalSpent += spent;
    }

    categoryStatsList.add(CategoryStats(
      categoryId: category.id,
      name: category.name,
      isMandatory: category.isMandatory,
      limit: limit,
      totalSpent: spent,
      totalPlanned: planned,
      remaining: remaining,
      heatPercentage: heatPercentage,
      isOverBudget: isOverBudget,
    ));
  }

  // Sort categories by highest heat percentage (closest to over budget)
  categoryStatsList.sort((a, b) => b.heatPercentage.compareTo(a.heatPercentage));

  final totalBudget = totalMandatoryBudget + totalOptionalBudget;
  final totalSpent = totalMandatorySpent + totalOptionalSpent;
  final overallRemaining = totalBudget - totalSpent;

  return PeriodStats(
    totalMandatoryBudget: totalMandatoryBudget,
    totalMandatorySpent: totalMandatorySpent,
    totalOptionalBudget: totalOptionalBudget,
    totalOptionalSpent: totalOptionalSpent,
    totalBudget: totalBudget,
    totalSpent: totalSpent,
    overallRemaining: overallRemaining,
    categoryStats: categoryStatsList,
  );
}
