// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'due_date.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Exact _$ExactFromJson(Map<String, dynamic> json) => _Exact(
  date: DateTime.parse(json['date'] as String),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$ExactToJson(_Exact instance) => <String, dynamic>{
  'date': instance.date.toIso8601String(),
  'type': instance.$type,
};

_DayOfMonth _$DayOfMonthFromJson(Map<String, dynamic> json) => _DayOfMonth(
  day: (json['day'] as num).toInt(),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$DayOfMonthToJson(_DayOfMonth instance) =>
    <String, dynamic>{'day': instance.day, 'type': instance.$type};

_DayOfWeek _$DayOfWeekFromJson(Map<String, dynamic> json) => _DayOfWeek(
  weekday: (json['weekday'] as num).toInt(),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$DayOfWeekToJson(_DayOfWeek instance) =>
    <String, dynamic>{'weekday': instance.weekday, 'type': instance.$type};
