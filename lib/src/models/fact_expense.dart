import 'package:freezed_annotation/freezed_annotation.dart';

part 'fact_expense.freezed.dart';
part 'fact_expense.g.dart';

@freezed
sealed class FactExpense with _$FactExpense {
  const factory FactExpense({
    required String id,
    required double amount,
    String? description,
    required DateTime timestamp,
    String? linkedPlannedExpenseId,
  }) = _FactExpense;

  factory FactExpense.fromJson(Map<String, dynamic> json) =>
      _$FactExpenseFromJson(json);
}
