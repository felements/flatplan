import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'all_periods_provider.dart';
import 'current_period_provider.dart';
import '../logic/period_stats.dart';

export '../logic/period_stats.dart'
    show CategoryStats, PeriodStats, PlannedExpenseStatus;

part 'period_stats_provider.g.dart';

@riverpod
FutureOr<PeriodStats?> periodStats(Ref ref) async {
  final currentPeriod = await ref.watch(currentPeriodProvider.future);
  if (currentPeriod == null) return null;

  final allPeriods = await ref.watch(allPeriodsProvider.future);

  return periodStatsFor(
    period: currentPeriod,
    allPeriods: allPeriods,
    now: DateTime.now(),
  );
}
