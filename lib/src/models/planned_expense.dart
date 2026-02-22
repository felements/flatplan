import 'package:freezed_annotation/freezed_annotation.dart';
import 'due_date.dart';

part 'planned_expense.freezed.dart';
part 'planned_expense.g.dart';

@freezed
sealed class PlannedExpense with _$PlannedExpense {
  const factory PlannedExpense({
    required String id,
    required String description,
    required double amount,
    required DueDate dueDate,
    @Default(false) bool isCompleted,
  }) = _PlannedExpense;

  factory PlannedExpense.fromJson(Map<String, dynamic> json) =>
      _$PlannedExpenseFromJson(json);
}
