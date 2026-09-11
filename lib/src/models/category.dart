import 'package:freezed_annotation/freezed_annotation.dart';
import 'fact_expense.dart';
import 'planned_expense.dart';
import 'category_type.dart';

part 'category.freezed.dart';
part 'category.g.dart';

@freezed
sealed class Category with _$Category {
  const factory Category({
    required String id,
    required String name,
    String? description,
    @Default(CategoryType.optionalExpense) CategoryType type,
    double? limit,
    @Default(false) bool isDailyAllowance,

    /// Amounts at or above this count as baskets, below it as small
    /// incidental spending. Non-null enables the basket insight; the value
    /// is the user's own boundary, seeded from history but never inferred.
    double? bigPurchaseThreshold,
    @Default([]) List<PlannedExpense> plannedExpenses,
    @Default([]) List<FactExpense> factExpenses,
  }) = _Category;

  factory Category.fromJson(Map<String, dynamic> json) =>
      _$CategoryFromJson(json);
}
