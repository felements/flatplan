// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fact_expense.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_FactExpense _$FactExpenseFromJson(Map<String, dynamic> json) => _FactExpense(
  id: json['id'] as String,
  amount: (json['amount'] as num).toDouble(),
  description: json['description'] as String?,
  timestamp: DateTime.parse(json['timestamp'] as String),
);

Map<String, dynamic> _$FactExpenseToJson(_FactExpense instance) =>
    <String, dynamic>{
      'id': instance.id,
      'amount': instance.amount,
      'description': instance.description,
      'timestamp': instance.timestamp.toIso8601String(),
    };
