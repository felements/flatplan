import '../models/models.dart';

/// Default period length in days when no subsequent period exists.
const int defaultPeriodLengthDays = 30;

/// Returns the effective end date for [period] given the full [allPeriods] list.
///
/// If a subsequent period exists (sorted by `startDate`), returns
/// `nextPeriod.startDate - 1 day`. Otherwise returns
/// `period.startDate + 30 days`.
DateTime effectiveEndDate(Period period, List<Period> allPeriods) {
  // Work on a copy sorted ascending by startDate.
  final sorted = [...allPeriods]
    ..sort((a, b) => a.startDate.compareTo(b.startDate));

  final index = sorted.indexWhere((p) => p.id == period.id);

  if (index == -1 || index == sorted.length - 1) {
    // Last period or not found — default to 30 days.
    return period.startDate.add(const Duration(days: defaultPeriodLengthDays));
  }

  // End date is one day before the next period starts.
  return sorted[index + 1].startDate.subtract(const Duration(days: 1));
}

/// Resolves a [DueDate] to a concrete calendar date.
///
/// `dayOfMonth` dates resolve to that day in [now]'s month, shifted one
/// month forward when that lands before [periodStart] (the due day for
/// this period hasn't happened in the current calendar month yet).
DateTime resolveDueDate(
  DueDate dueDate, {
  required DateTime now,
  required DateTime periodStart,
}) {
  return dueDate.when(
    exact: (d) => d,
    dayOfMonth: (day) {
      final d = DateTime(now.year, now.month, day);
      if (d.isBefore(periodStart)) {
        return DateTime(now.year, now.month + 1, day);
      }
      return d;
    },
  );
}
