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

/// History for [categoryName] from the periods preceding [currentPeriod],
/// newest first, capped at [limit] slices.
///
/// Matching is by name because [createNextPeriod] regenerates category ids
/// on every rollover, so ids cannot link a category across periods.
///
/// With the default [skipEmpty], periods where the category is absent or
/// has no spending are passed over rather than counted as an empty slice —
/// an empty slice would drag a share or cadence statistic toward a value
/// the user never lived, and a period with no basket in it has no cadence
/// to contribute.
///
/// Pass `skipEmpty: false` when the position of a slice is what matters
/// rather than its content. A rate wants the genuinely preceding period:
/// a period with no spending in this category is real data meaning the
/// rate was zero, and skipping it would report the rate from two periods
/// back under a "last period" label.
///
/// A period where the category does not exist at all is skipped either way.
/// That is absence of data, not a zero — quoting "averaging 0/day" for a
/// category the user had not created yet states something that never
/// happened.
List<CategoryPeriodSlice> priorCategoryHistory({
  required String categoryName,
  required Period currentPeriod,
  required List<Period> allPeriods,
  required int limit,
  bool skipEmpty = true,
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
    var categoryExisted = false;
    for (final category in period.categories) {
      if (category.name.trim().toLowerCase() != key) continue;
      categoryExisted = true;
      for (final expense in category.factExpenses) {
        amounts.add(expense.amount);
      }
    }
    if (!categoryExisted) continue;
    if (amounts.isEmpty && skipEmpty) continue;

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
