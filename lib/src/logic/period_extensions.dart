import '../models/models.dart';

/// Default period length in days when no subsequent period exists.
const int defaultPeriodLengthDays = 30;

/// Whole calendar days from [from] to [to], ignoring the time of day.
///
/// `to.difference(from).inDays` cannot do this job. It truncates, so a
/// period ending 20 calendar days from now reads as 19 when `now` carries
/// any time of day at all — which it does, since `DateTime.now()` is
/// stamped onto a period's start date whenever the date picker is left
/// untouched. It is also local-time arithmetic, so a span crossing a
/// spring-forward is an hour short and loses another whole day.
///
/// Both errors shrink the count, and every figure divided by it —
/// the daily allowance, the projection, the trips left — is inflated in
/// the "you can spend more" direction as a result, the opposite of what
/// these insights are for.
///
/// Rebuilding both ends as UTC midnights drops the time of day and takes
/// the arithmetic out of any zone with a DST rule, so the answer is the
/// plain difference in calendar dates. Negative when [to] precedes [from].
int wholeDaysBetween(DateTime from, DateTime to) {
  final f = DateTime.utc(from.year, from.month, from.day);
  final t = DateTime.utc(to.year, to.month, to.day);
  return t.difference(f).inDays;
}

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
