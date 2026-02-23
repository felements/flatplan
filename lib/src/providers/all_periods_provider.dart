import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/models.dart';
import 'repository_provider.dart';

part 'all_periods_provider.g.dart';

/// Provides all stored periods sorted descending by start date.
@riverpod
Future<List<Period>> allPeriods(Ref ref) async {
  final repo = ref.watch(periodRepositoryProvider);
  final periods = await repo.loadAllPeriods();
  periods.sort((a, b) => b.startDate.compareTo(a.startDate));
  return periods;
}
