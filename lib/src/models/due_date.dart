import 'package:freezed_annotation/freezed_annotation.dart';

part 'due_date.freezed.dart';
part 'due_date.g.dart';

@Freezed(unionKey: 'type', unionValueCase: FreezedUnionCase.snake)
sealed class DueDate with _$DueDate {
  const factory DueDate.exact({required DateTime date}) = _Exact;
  const factory DueDate.dayOfMonth({required int day}) = _DayOfMonth;

  factory DueDate.fromJson(Map<String, dynamic> json) =>
      _$DueDateFromJson(json);
}
