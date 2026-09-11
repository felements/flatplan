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
/// daily allowance, the period has ended, or there is no preceding period
/// to compare against.
///
/// The single most recent prior period is the basis rather than an average:
/// spending rates were observed to trend steadily rather than oscillate, so
/// an average lags the current trajectory.
///
/// The history is requested with `skipEmpty: false` so "last period" means
/// the period immediately before this one, whatever it holds. A preceding
/// period with no spending in this category is a rate of zero — real data,
/// and a legitimate trend. Skipping it would quietly report the rate from
/// two periods ago while the UI labels it "last period".
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
    skipEmpty: false,
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
