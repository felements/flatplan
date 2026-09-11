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
