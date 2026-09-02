import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/models.dart';
import '../storage/period_repository.dart';
import 'repository_provider.dart';

part 'all_periods_provider.g.dart';

/// Reads every period file once, keeping both the periods that loaded and
/// the files that could not be read.
@riverpod
Future<PeriodLoadResult> periodLoadResult(Ref ref) {
  final repo = ref.watch(periodRepositoryProvider);
  return repo.loadAll();
}

/// Provides all stored periods sorted descending by start date.
@riverpod
Future<List<Period>> allPeriods(Ref ref) async {
  final result = await ref.watch(periodLoadResultProvider.future);
  final periods = [...result.periods];
  periods.sort((a, b) => b.startDate.compareTo(a.startDate));
  return periods;
}

/// Period files that could not be read, for surfacing in the UI.
@riverpod
Future<List<PeriodLoadFailure>> periodLoadFailures(Ref ref) async {
  final result = await ref.watch(periodLoadResultProvider.future);
  return result.failures;
}
