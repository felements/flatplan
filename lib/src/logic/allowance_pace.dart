import '../models/models.dart';

/// How far back the pace estimate looks for comparable purchases.
///
/// Deliberately a plain date window rather than "this period plus the
/// previous one": on the first days of a period there is not enough
/// history inside it to say anything, and period lengths vary.
const int paceLookbackDays = 30;

/// Fewest purchases needed before a cadence is worth suggesting.
const int minPaceSamples = 2;

/// Fact-expense amounts that feed the pace estimate for [categoryName].
///
/// Category ids are regenerated on every rollover, so a category is tracked
/// across periods by name.
List<double> paceSamples({
  required String categoryName,
  required List<Period> allPeriods,
  required DateTime asOf,
}) {
  final key = categoryName.trim().toLowerCase();
  final windowStart = asOf.subtract(const Duration(days: paceLookbackDays));
  final samples = <double>[];

  for (final period in allPeriods) {
    for (final category in period.categories) {
      if (category.name.trim().toLowerCase() != key) continue;
      for (final expense in category.factExpenses) {
        if (!expense.timestamp.isAfter(windowStart)) continue;
        if (expense.timestamp.isAfter(asOf)) continue;
        samples.add(expense.amount);
      }
    }
  }

  return samples;
}

/// A "spend about [amount] every [frequencyDays] days" suggestion.
class AllowancePace {
  const AllowancePace({required this.frequencyDays, required this.amount});

  final int frequencyDays;
  final double amount;
}

/// The cadence the remaining budget affords at the user's typical purchase
/// size, or null when history is too thin to say.
AllowancePace? estimateAllowancePace({
  required List<double> samples,
  required double remaining,
  required int daysLeft,
  required int periodLengthDays,
}) {
  if (samples.length < minPaceSamples) return null;

  // 20% trimmed mean — drop the cheapest fifth so the odd small top-up
  // does not drag the typical purchase size down.
  final sorted = [...samples]..sort();
  final kept = sorted.sublist((sorted.length * 0.2).floor());
  if (kept.isEmpty) return null;

  final average = kept.fold<double>(0, (sum, a) => sum + a) / kept.length;
  if (average <= 0) return null;

  final affordablePurchases = remaining / average;
  if (affordablePurchases <= 0) return null;

  final frequencyDays = (daysLeft / affordablePurchases).round();
  // A cadence sparser than half the period is not a rhythm — suppress it
  // rather than suggest "spend 1000 every 20 days".
  if (frequencyDays > periodLengthDays / 2) return null;

  return AllowancePace(frequencyDays: frequencyDays, amount: average);
}

/// The pace suggestion for [category] within [period], or null when the
/// category has no daily allowance, the period is over, or the history is
/// too thin.
AllowancePace? paceForCategory({
  required Category category,
  required Period period,
  required DateTime endDate,
  required List<Period> allPeriods,
  required DateTime now,
}) {
  if (!category.isDailyAllowance) return null;

  // A closed period has no days left to spread spending over, and browsing
  // one must not fold in purchases made after it ended.
  final daysLeft = endDate.difference(now).inDays;
  if (daysLeft < 1) return null;

  final spent = category.factExpenses.fold<double>(0, (s, e) => s + e.amount);

  return estimateAllowancePace(
    samples: paceSamples(
      categoryName: category.name,
      allPeriods: allPeriods,
      asOf: now,
    ),
    remaining: category.effectiveLimit - spent,
    daysLeft: daysLeft,
    periodLengthDays: endDate.difference(period.startDate).inDays + 1,
  );
}
