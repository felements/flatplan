// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'category.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Category _$CategoryFromJson(Map<String, dynamic> json) => _Category(
  id: json['id'] as String,
  name: json['name'] as String,
  description: json['description'] as String?,
  isMandatory: json['is_mandatory'] as bool,
  limit: (json['limit'] as num?)?.toDouble(),
  isDailyAllowance: json['is_daily_allowance'] as bool? ?? false,
  plannedExpenses:
      (json['planned_expenses'] as List<dynamic>?)
          ?.map((e) => PlannedExpense.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  factExpenses:
      (json['fact_expenses'] as List<dynamic>?)
          ?.map((e) => FactExpense.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

Map<String, dynamic> _$CategoryToJson(_Category instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'description': instance.description,
  'is_mandatory': instance.isMandatory,
  'limit': instance.limit,
  'is_daily_allowance': instance.isDailyAllowance,
  'planned_expenses': instance.plannedExpenses.map((e) => e.toJson()).toList(),
  'fact_expenses': instance.factExpenses.map((e) => e.toJson()).toList(),
};
