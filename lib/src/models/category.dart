import 'package:freezed_annotation/freezed_annotation.dart';
import 'planned_expense.dart';
import 'fact_expense.dart';

part 'category.freezed.dart';
part 'category.g.dart';

@freezed
sealed class Category with _$Category {
  const factory Category({
    required String id,
    required String name,
    String? description,
    required bool isMandatory,
    double? limit,
    @Default(false) bool isDailyAllowance,
    @Default([]) List<PlannedExpense> plannedExpenses,
    @Default([]) List<FactExpense> factExpenses,
  }) = _Category;

  factory Category.fromJson(Map<String, dynamic> json) =>
      _$CategoryFromJson(json);
}
