// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'spending_trend.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SpendingTrend {

/// The previous complete period's spend per day for this category.
 double get recentDailyRate;/// What this period totals if [recentDailyRate] holds for the days left.
 double get projectedTotal;/// How far [projectedTotal] exceeds the limit; zero when on track.
 double get overshoot;
/// Create a copy of SpendingTrend
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SpendingTrendCopyWith<SpendingTrend> get copyWith => _$SpendingTrendCopyWithImpl<SpendingTrend>(this as SpendingTrend, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SpendingTrend&&(identical(other.recentDailyRate, recentDailyRate) || other.recentDailyRate == recentDailyRate)&&(identical(other.projectedTotal, projectedTotal) || other.projectedTotal == projectedTotal)&&(identical(other.overshoot, overshoot) || other.overshoot == overshoot));
}


@override
int get hashCode => Object.hash(runtimeType,recentDailyRate,projectedTotal,overshoot);

@override
String toString() {
  return 'SpendingTrend(recentDailyRate: $recentDailyRate, projectedTotal: $projectedTotal, overshoot: $overshoot)';
}


}

/// @nodoc
abstract mixin class $SpendingTrendCopyWith<$Res>  {
  factory $SpendingTrendCopyWith(SpendingTrend value, $Res Function(SpendingTrend) _then) = _$SpendingTrendCopyWithImpl;
@useResult
$Res call({
 double recentDailyRate, double projectedTotal, double overshoot
});




}
/// @nodoc
class _$SpendingTrendCopyWithImpl<$Res>
    implements $SpendingTrendCopyWith<$Res> {
  _$SpendingTrendCopyWithImpl(this._self, this._then);

  final SpendingTrend _self;
  final $Res Function(SpendingTrend) _then;

/// Create a copy of SpendingTrend
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? recentDailyRate = null,Object? projectedTotal = null,Object? overshoot = null,}) {
  return _then(_self.copyWith(
recentDailyRate: null == recentDailyRate ? _self.recentDailyRate : recentDailyRate // ignore: cast_nullable_to_non_nullable
as double,projectedTotal: null == projectedTotal ? _self.projectedTotal : projectedTotal // ignore: cast_nullable_to_non_nullable
as double,overshoot: null == overshoot ? _self.overshoot : overshoot // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [SpendingTrend].
extension SpendingTrendPatterns on SpendingTrend {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SpendingTrend value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SpendingTrend() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SpendingTrend value)  $default,){
final _that = this;
switch (_that) {
case _SpendingTrend():
return $default(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SpendingTrend value)?  $default,){
final _that = this;
switch (_that) {
case _SpendingTrend() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double recentDailyRate,  double projectedTotal,  double overshoot)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SpendingTrend() when $default != null:
return $default(_that.recentDailyRate,_that.projectedTotal,_that.overshoot);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double recentDailyRate,  double projectedTotal,  double overshoot)  $default,) {final _that = this;
switch (_that) {
case _SpendingTrend():
return $default(_that.recentDailyRate,_that.projectedTotal,_that.overshoot);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double recentDailyRate,  double projectedTotal,  double overshoot)?  $default,) {final _that = this;
switch (_that) {
case _SpendingTrend() when $default != null:
return $default(_that.recentDailyRate,_that.projectedTotal,_that.overshoot);case _:
  return null;

}
}

}

/// @nodoc


class _SpendingTrend extends SpendingTrend {
  const _SpendingTrend({required this.recentDailyRate, required this.projectedTotal, required this.overshoot}): super._();
  

/// The previous complete period's spend per day for this category.
@override final  double recentDailyRate;
/// What this period totals if [recentDailyRate] holds for the days left.
@override final  double projectedTotal;
/// How far [projectedTotal] exceeds the limit; zero when on track.
@override final  double overshoot;

/// Create a copy of SpendingTrend
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SpendingTrendCopyWith<_SpendingTrend> get copyWith => __$SpendingTrendCopyWithImpl<_SpendingTrend>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SpendingTrend&&(identical(other.recentDailyRate, recentDailyRate) || other.recentDailyRate == recentDailyRate)&&(identical(other.projectedTotal, projectedTotal) || other.projectedTotal == projectedTotal)&&(identical(other.overshoot, overshoot) || other.overshoot == overshoot));
}


@override
int get hashCode => Object.hash(runtimeType,recentDailyRate,projectedTotal,overshoot);

@override
String toString() {
  return 'SpendingTrend(recentDailyRate: $recentDailyRate, projectedTotal: $projectedTotal, overshoot: $overshoot)';
}


}

/// @nodoc
abstract mixin class _$SpendingTrendCopyWith<$Res> implements $SpendingTrendCopyWith<$Res> {
  factory _$SpendingTrendCopyWith(_SpendingTrend value, $Res Function(_SpendingTrend) _then) = __$SpendingTrendCopyWithImpl;
@override @useResult
$Res call({
 double recentDailyRate, double projectedTotal, double overshoot
});




}
/// @nodoc
class __$SpendingTrendCopyWithImpl<$Res>
    implements _$SpendingTrendCopyWith<$Res> {
  __$SpendingTrendCopyWithImpl(this._self, this._then);

  final _SpendingTrend _self;
  final $Res Function(_SpendingTrend) _then;

/// Create a copy of SpendingTrend
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? recentDailyRate = null,Object? projectedTotal = null,Object? overshoot = null,}) {
  return _then(_SpendingTrend(
recentDailyRate: null == recentDailyRate ? _self.recentDailyRate : recentDailyRate // ignore: cast_nullable_to_non_nullable
as double,projectedTotal: null == projectedTotal ? _self.projectedTotal : projectedTotal // ignore: cast_nullable_to_non_nullable
as double,overshoot: null == overshoot ? _self.overshoot : overshoot // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
