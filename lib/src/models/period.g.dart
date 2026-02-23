// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'period.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Period _$PeriodFromJson(Map<String, dynamic> json) => _Period(
  id: json['id'] as String,
  name: json['name'] as String,
  startDate: DateTime.parse(json['start_date'] as String),
  baseCurrency: json['base_currency'] as String,
  lastModified: DateTime.parse(json['last_modified'] as String),
  categories:
      (json['categories'] as List<dynamic>?)
          ?.map((e) => Category.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

Map<String, dynamic> _$PeriodToJson(_Period instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'start_date': instance.startDate.toIso8601String(),
  'base_currency': instance.baseCurrency,
  'last_modified': instance.lastModified.toIso8601String(),
  'categories': instance.categories.map((e) => e.toJson()).toList(),
};
