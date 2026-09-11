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
    /// of remaining trips is never underestimated. Never below 1: see
    /// [basketStatsFor] for why a sub-daily cadence is withheld instead.
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
/// there is too little history, a period in the window contains no
/// basket-sized purchase at all, or the measured cadence comes out below
/// one shop per day.
///
/// The sub-daily guard matters because the count behind the cadence is
/// fact-expense *rows*, not trips: one shop is typically entered as several
/// receipt lines. A threshold set low enough that most rows clear it makes
/// [BasketStats.tripSpacingDays] fall under 1, and the advice degenerates
/// into a "per shop" figure smaller than a single day's allowance — the
/// exact failure this insight was designed to replace. Below one day the
/// number no longer describes shopping trips, so it is withheld rather than
/// shown; raising the threshold is the fix, and the user owns it.
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

  if (tightestSpacing == null || tightestSpacing < 1) return null;

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

  final rawTrips = daysLeft / stats.tripSpacingDays;
  // Fewer than one expected shop left still means one shop can happen, and
  // the whole remaining basket budget is what is safe to spend on it.
  // Without this floor, dividing by a fraction would report a "safe"
  // amount larger than the budget that is actually left.
  final tripsLeft = rawTrips < 1 ? 1.0 : rawTrips;

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
  if (!category.isDailyAllowance) return null;

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
