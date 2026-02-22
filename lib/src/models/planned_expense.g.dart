// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'planned_expense.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PlannedExpense _$PlannedExpenseFromJson(Map<String, dynamic> json) =>
    _PlannedExpense(
      id: json['id'] as String,
      description: json['description'] as String,
      amount: (json['amount'] as num).toDouble(),
      dueDate: DueDate.fromJson(json['due_date'] as Map<String, dynamic>),
      isCompleted: json['is_completed'] as bool? ?? false,
    );

Map<String, dynamic> _$PlannedExpenseToJson(_PlannedExpense instance) =>
    <String, dynamic>{
      'id': instance.id,
      'description': instance.description,
      'amount': instance.amount,
      'due_date': instance.dueDate.toJson(),
      'is_completed': instance.isCompleted,
    };
