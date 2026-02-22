import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../storage/period_repository.dart';

part 'repository_provider.g.dart';

@riverpod
PeriodRepository periodRepository(Ref ref) {
  return PeriodRepository();
}
