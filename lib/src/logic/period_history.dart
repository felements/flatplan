import '../models/models.dart';
import 'period_extensions.dart';

/// One prior period's slice of a single category's spending history.
class CategoryPeriodSlice {
  const CategoryPeriodSlice({required this.amounts, required this.lengthDays});

  /// Every fact-expense amount booked to the category in that period.
  final List<double> amounts;

  /// The period's length in days, inclusive of both end dates.
  final int lengthDays;

  double get total => amounts.fold<double>(0, (sum, a) => sum + a);
}

/// History for [categoryName] from the complete periods preceding
/// [currentPeriod], newest first, capped at [limit] slices.
///
/// Matching is by name because [createNextPeriod] regenerates category ids
/// on every rollover, so ids cannot link a category across periods.
/// Periods where the category is absent or has no spending are skipped
/// rather than counted as an empty slice — an empty slice would drag a
/// share or cadence statistic toward a value the user never lived.
List<CategoryPeriodSlice> priorCategoryHistory({
  required String categoryName,
  required Period currentPeriod,
  required List<Period> allPeriods,
  required int limit,
}) {
  final key = categoryName.trim().toLowerCase();
  final sorted = [...allPeriods]
    ..sort((a, b) => a.startDate.compareTo(b.startDate));
  final currentIndex = sorted.indexWhere((p) => p.id == currentPeriod.id);
  if (currentIndex < 1) return const [];

  final slices = <CategoryPeriodSlice>[];
  for (var i = currentIndex - 1; i >= 0 && slices.length < limit; i--) {
    final period = sorted[i];
    final amounts = <double>[];
    for (final category in period.categories) {
      if (category.name.trim().toLowerCase() != key) continue;
      for (final expense in category.factExpenses) {
        amounts.add(expense.amount);
      }
    }
    if (amounts.isEmpty) continue;

    final end = effectiveEndDate(period, allPeriods);
    slices.add(
      CategoryPeriodSlice(
        amounts: amounts,
        lengthDays: end.difference(period.startDate).inDays + 1,
      ),
    );
  }
  return slices;
}
