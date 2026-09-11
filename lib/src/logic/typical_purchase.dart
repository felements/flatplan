import 'package:freezed_annotation/freezed_annotation.dart';

import '../models/models.dart';
import 'period_extensions.dart';
import 'period_history.dart';

part 'typical_purchase.freezed.dart';

/// How many complete prior periods the typical purchase is drawn from.
const int typicalPurchaseHistoryPeriods = 3;

/// Fewest purchases before a typical size is worth quoting.
const int minTypicalPurchases = 3;

/// A typical purchase in this category, and how often the remaining budget
/// affords one.
@freezed
sealed class TypicalPurchase with _$TypicalPurchase {
  const factory TypicalPurchase({
    /// The median purchase over the recent history.
    required double amount,

    /// Days between purchases of that size at the remaining budget.
    required int everyDays,

    /// How many past purchases the median was taken over.
    required int purchasesUsed,
  }) = _TypicalPurchase;
}

double _median(List<double> values) {
  final sorted = [...values]..sort();
  final middle = sorted.length ~/ 2;
  if (sorted.length.isOdd) return sorted[middle];
  return (sorted[middle - 1] + sorted[middle]) / 2;
}

/// The typical purchase and its affordable cadence for [category], or null
/// when the figure would be meaningless.
///
/// This is the counterpart to the basket insight, for categories where a
/// fact expense really is one purchase. Groceries is the exception: a single
/// trip is entered as many receipt lines, so a per-row median describes a
/// line rather than a shop. Setting a big-purchase threshold switches a
/// category to the basket insight instead, and this one stands down.
///
/// The median rather than the mean: this spending is right-skewed, and a few
/// large one-offs — a service bill among many small fuel entries — drag a
/// mean far above anything the user actually spends in a normal week.
TypicalPurchase? typicalPurchaseFor({
  required Category category,
  required Period period,
  required DateTime endDate,
  required List<Period> allPeriods,
  required DateTime now,
}) {
  if (!category.isDailyAllowance) return null;
  // The basket insight owns any category with a threshold set.
  if (category.bigPurchaseThreshold != null) return null;

  // Stated explicitly to match the sibling insights, though a closed period
  // would also fall out of the cadence guard below.
  final daysLeft = wholeDaysBetween(now, endDate);
  if (daysLeft < 1) return null;

  final spent = category.factExpenses.fold<double>(0, (s, e) => s + e.amount);
  final remaining = category.effectiveLimit - spent;
  if (remaining <= 0) return null;

  final history = priorCategoryHistory(
    categoryName: category.name,
    currentPeriod: period,
    allPeriods: allPeriods,
    limit: typicalPurchaseHistoryPeriods,
  );
  final amounts = [for (final slice in history) ...slice.amounts];
  if (amounts.length < minTypicalPurchases) return null;

  final amount = _median(amounts);
  if (amount <= 0) return null;

  final affordable = remaining / amount;

  final everyDays = (daysLeft / affordable).round();
  // Under a day is not a cadence, it is the per-day figure restated less
  // accurately — the degeneracy this insight replaced.
  if (everyDays < 1) return null;

  // Sparser than half the period is not a rhythm either.
  final periodLengthDays = wholeDaysBetween(period.startDate, endDate) + 1;
  if (everyDays > periodLengthDays / 2) return null;

  return TypicalPurchase(
    amount: amount,
    everyDays: everyDays,
    purchasesUsed: amounts.length,
  );
}
