// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'due_date.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
DueDate _$DueDateFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'exact':
          return _Exact.fromJson(
            json
          );
                case 'day_of_month':
          return _DayOfMonth.fromJson(
            json
          );
                case 'day_of_week':
          return _DayOfWeek.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'type',
  'DueDate',
  'Invalid union type "${json['type']}"!'
);
        }
      
}

/// @nodoc
mixin _$DueDate {



  /// Serializes this DueDate to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DueDate);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'DueDate()';
}


}

/// @nodoc
class $DueDateCopyWith<$Res>  {
$DueDateCopyWith(DueDate _, $Res Function(DueDate) __);
}


/// Adds pattern-matching-related methods to [DueDate].
extension DueDatePatterns on DueDate {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( _Exact value)?  exact,TResult Function( _DayOfMonth value)?  dayOfMonth,TResult Function( _DayOfWeek value)?  dayOfWeek,required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Exact() when exact != null:
return exact(_that);case _DayOfMonth() when dayOfMonth != null:
return dayOfMonth(_that);case _DayOfWeek() when dayOfWeek != null:
return dayOfWeek(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( _Exact value)  exact,required TResult Function( _DayOfMonth value)  dayOfMonth,required TResult Function( _DayOfWeek value)  dayOfWeek,}){
final _that = this;
switch (_that) {
case _Exact():
return exact(_that);case _DayOfMonth():
return dayOfMonth(_that);case _DayOfWeek():
return dayOfWeek(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( _Exact value)?  exact,TResult? Function( _DayOfMonth value)?  dayOfMonth,TResult? Function( _DayOfWeek value)?  dayOfWeek,}){
final _that = this;
switch (_that) {
case _Exact() when exact != null:
return exact(_that);case _DayOfMonth() when dayOfMonth != null:
return dayOfMonth(_that);case _DayOfWeek() when dayOfWeek != null:
return dayOfWeek(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( DateTime date)?  exact,TResult Function( int day)?  dayOfMonth,TResult Function( int weekday)?  dayOfWeek,required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Exact() when exact != null:
return exact(_that.date);case _DayOfMonth() when dayOfMonth != null:
return dayOfMonth(_that.day);case _DayOfWeek() when dayOfWeek != null:
return dayOfWeek(_that.weekday);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( DateTime date)  exact,required TResult Function( int day)  dayOfMonth,required TResult Function( int weekday)  dayOfWeek,}) {final _that = this;
switch (_that) {
case _Exact():
return exact(_that.date);case _DayOfMonth():
return dayOfMonth(_that.day);case _DayOfWeek():
return dayOfWeek(_that.weekday);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( DateTime date)?  exact,TResult? Function( int day)?  dayOfMonth,TResult? Function( int weekday)?  dayOfWeek,}) {final _that = this;
switch (_that) {
case _Exact() when exact != null:
return exact(_that.date);case _DayOfMonth() when dayOfMonth != null:
return dayOfMonth(_that.day);case _DayOfWeek() when dayOfWeek != null:
return dayOfWeek(_that.weekday);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Exact implements DueDate {
  const _Exact({required this.date, final  String? $type}): $type = $type ?? 'exact';
  factory _Exact.fromJson(Map<String, dynamic> json) => _$ExactFromJson(json);

 final  DateTime date;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of DueDate
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ExactCopyWith<_Exact> get copyWith => __$ExactCopyWithImpl<_Exact>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ExactToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Exact&&(identical(other.date, date) || other.date == date));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,date);

@override
String toString() {
  return 'DueDate.exact(date: $date)';
}


}

/// @nodoc
abstract mixin class _$ExactCopyWith<$Res> implements $DueDateCopyWith<$Res> {
  factory _$ExactCopyWith(_Exact value, $Res Function(_Exact) _then) = __$ExactCopyWithImpl;
@useResult
$Res call({
 DateTime date
});




}
/// @nodoc
class __$ExactCopyWithImpl<$Res>
    implements _$ExactCopyWith<$Res> {
  __$ExactCopyWithImpl(this._self, this._then);

  final _Exact _self;
  final $Res Function(_Exact) _then;

/// Create a copy of DueDate
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? date = null,}) {
  return _then(_Exact(
date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

/// @nodoc
@JsonSerializable()

class _DayOfMonth implements DueDate {
  const _DayOfMonth({required this.day, final  String? $type}): $type = $type ?? 'day_of_month';
  factory _DayOfMonth.fromJson(Map<String, dynamic> json) => _$DayOfMonthFromJson(json);

 final  int day;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of DueDate
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DayOfMonthCopyWith<_DayOfMonth> get copyWith => __$DayOfMonthCopyWithImpl<_DayOfMonth>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DayOfMonthToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DayOfMonth&&(identical(other.day, day) || other.day == day));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,day);

@override
String toString() {
  return 'DueDate.dayOfMonth(day: $day)';
}


}

/// @nodoc
abstract mixin class _$DayOfMonthCopyWith<$Res> implements $DueDateCopyWith<$Res> {
  factory _$DayOfMonthCopyWith(_DayOfMonth value, $Res Function(_DayOfMonth) _then) = __$DayOfMonthCopyWithImpl;
@useResult
$Res call({
 int day
});




}
/// @nodoc
class __$DayOfMonthCopyWithImpl<$Res>
    implements _$DayOfMonthCopyWith<$Res> {
  __$DayOfMonthCopyWithImpl(this._self, this._then);

  final _DayOfMonth _self;
  final $Res Function(_DayOfMonth) _then;

/// Create a copy of DueDate
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? day = null,}) {
  return _then(_DayOfMonth(
day: null == day ? _self.day : day // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
@JsonSerializable()

class _DayOfWeek implements DueDate {
  const _DayOfWeek({required this.weekday, final  String? $type}): $type = $type ?? 'day_of_week';
  factory _DayOfWeek.fromJson(Map<String, dynamic> json) => _$DayOfWeekFromJson(json);

 final  int weekday;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of DueDate
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DayOfWeekCopyWith<_DayOfWeek> get copyWith => __$DayOfWeekCopyWithImpl<_DayOfWeek>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DayOfWeekToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DayOfWeek&&(identical(other.weekday, weekday) || other.weekday == weekday));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,weekday);

@override
String toString() {
  return 'DueDate.dayOfWeek(weekday: $weekday)';
}


}

/// @nodoc
abstract mixin class _$DayOfWeekCopyWith<$Res> implements $DueDateCopyWith<$Res> {
  factory _$DayOfWeekCopyWith(_DayOfWeek value, $Res Function(_DayOfWeek) _then) = __$DayOfWeekCopyWithImpl;
@useResult
$Res call({
 int weekday
});




}
/// @nodoc
class __$DayOfWeekCopyWithImpl<$Res>
    implements _$DayOfWeekCopyWith<$Res> {
  __$DayOfWeekCopyWithImpl(this._self, this._then);

  final _DayOfWeek _self;
  final $Res Function(_DayOfWeek) _then;

/// Create a copy of DueDate
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? weekday = null,}) {
  return _then(_DayOfWeek(
weekday: null == weekday ? _self.weekday : weekday // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
