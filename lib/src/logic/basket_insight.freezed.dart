// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'basket_insight.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$BasketStats {

/// Fraction of spending that went on small incidental items, 0..1.
/// The highest seen in the window, so the reserve is never too small.
 double get snackShare;/// Days between baskets. The tightest seen in the window, so the number
/// of remaining trips is never underestimated.
 double get tripSpacingDays;/// A typical basket, shown as context so the advice can be judged.
 double get usualBasket;/// How many periods the figures were drawn from.
 int get periodsUsed;
/// Create a copy of BasketStats
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BasketStatsCopyWith<BasketStats> get copyWith => _$BasketStatsCopyWithImpl<BasketStats>(this as BasketStats, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BasketStats&&(identical(other.snackShare, snackShare) || other.snackShare == snackShare)&&(identical(other.tripSpacingDays, tripSpacingDays) || other.tripSpacingDays == tripSpacingDays)&&(identical(other.usualBasket, usualBasket) || other.usualBasket == usualBasket)&&(identical(other.periodsUsed, periodsUsed) || other.periodsUsed == periodsUsed));
}


@override
int get hashCode => Object.hash(runtimeType,snackShare,tripSpacingDays,usualBasket,periodsUsed);

@override
String toString() {
  return 'BasketStats(snackShare: $snackShare, tripSpacingDays: $tripSpacingDays, usualBasket: $usualBasket, periodsUsed: $periodsUsed)';
}


}

/// @nodoc
abstract mixin class $BasketStatsCopyWith<$Res>  {
  factory $BasketStatsCopyWith(BasketStats value, $Res Function(BasketStats) _then) = _$BasketStatsCopyWithImpl;
@useResult
$Res call({
 double snackShare, double tripSpacingDays, double usualBasket, int periodsUsed
});




}
/// @nodoc
class _$BasketStatsCopyWithImpl<$Res>
    implements $BasketStatsCopyWith<$Res> {
  _$BasketStatsCopyWithImpl(this._self, this._then);

  final BasketStats _self;
  final $Res Function(BasketStats) _then;

/// Create a copy of BasketStats
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? snackShare = null,Object? tripSpacingDays = null,Object? usualBasket = null,Object? periodsUsed = null,}) {
  return _then(_self.copyWith(
snackShare: null == snackShare ? _self.snackShare : snackShare // ignore: cast_nullable_to_non_nullable
as double,tripSpacingDays: null == tripSpacingDays ? _self.tripSpacingDays : tripSpacingDays // ignore: cast_nullable_to_non_nullable
as double,usualBasket: null == usualBasket ? _self.usualBasket : usualBasket // ignore: cast_nullable_to_non_nullable
as double,periodsUsed: null == periodsUsed ? _self.periodsUsed : periodsUsed // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [BasketStats].
extension BasketStatsPatterns on BasketStats {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BasketStats value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BasketStats() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BasketStats value)  $default,){
final _that = this;
switch (_that) {
case _BasketStats():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BasketStats value)?  $default,){
final _that = this;
switch (_that) {
case _BasketStats() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double snackShare,  double tripSpacingDays,  double usualBasket,  int periodsUsed)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BasketStats() when $default != null:
return $default(_that.snackShare,_that.tripSpacingDays,_that.usualBasket,_that.periodsUsed);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double snackShare,  double tripSpacingDays,  double usualBasket,  int periodsUsed)  $default,) {final _that = this;
switch (_that) {
case _BasketStats():
return $default(_that.snackShare,_that.tripSpacingDays,_that.usualBasket,_that.periodsUsed);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double snackShare,  double tripSpacingDays,  double usualBasket,  int periodsUsed)?  $default,) {final _that = this;
switch (_that) {
case _BasketStats() when $default != null:
return $default(_that.snackShare,_that.tripSpacingDays,_that.usualBasket,_that.periodsUsed);case _:
  return null;

}
}

}

/// @nodoc


class _BasketStats implements BasketStats {
  const _BasketStats({required this.snackShare, required this.tripSpacingDays, required this.usualBasket, required this.periodsUsed});
  

/// Fraction of spending that went on small incidental items, 0..1.
/// The highest seen in the window, so the reserve is never too small.
@override final  double snackShare;
/// Days between baskets. The tightest seen in the window, so the number
/// of remaining trips is never underestimated.
@override final  double tripSpacingDays;
/// A typical basket, shown as context so the advice can be judged.
@override final  double usualBasket;
/// How many periods the figures were drawn from.
@override final  int periodsUsed;

/// Create a copy of BasketStats
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BasketStatsCopyWith<_BasketStats> get copyWith => __$BasketStatsCopyWithImpl<_BasketStats>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BasketStats&&(identical(other.snackShare, snackShare) || other.snackShare == snackShare)&&(identical(other.tripSpacingDays, tripSpacingDays) || other.tripSpacingDays == tripSpacingDays)&&(identical(other.usualBasket, usualBasket) || other.usualBasket == usualBasket)&&(identical(other.periodsUsed, periodsUsed) || other.periodsUsed == periodsUsed));
}


@override
int get hashCode => Object.hash(runtimeType,snackShare,tripSpacingDays,usualBasket,periodsUsed);

@override
String toString() {
  return 'BasketStats(snackShare: $snackShare, tripSpacingDays: $tripSpacingDays, usualBasket: $usualBasket, periodsUsed: $periodsUsed)';
}


}

/// @nodoc
abstract mixin class _$BasketStatsCopyWith<$Res> implements $BasketStatsCopyWith<$Res> {
  factory _$BasketStatsCopyWith(_BasketStats value, $Res Function(_BasketStats) _then) = __$BasketStatsCopyWithImpl;
@override @useResult
$Res call({
 double snackShare, double tripSpacingDays, double usualBasket, int periodsUsed
});




}
/// @nodoc
class __$BasketStatsCopyWithImpl<$Res>
    implements _$BasketStatsCopyWith<$Res> {
  __$BasketStatsCopyWithImpl(this._self, this._then);

  final _BasketStats _self;
  final $Res Function(_BasketStats) _then;

/// Create a copy of BasketStats
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? snackShare = null,Object? tripSpacingDays = null,Object? usualBasket = null,Object? periodsUsed = null,}) {
  return _then(_BasketStats(
snackShare: null == snackShare ? _self.snackShare : snackShare // ignore: cast_nullable_to_non_nullable
as double,tripSpacingDays: null == tripSpacingDays ? _self.tripSpacingDays : tripSpacingDays // ignore: cast_nullable_to_non_nullable
as double,usualBasket: null == usualBasket ? _self.usualBasket : usualBasket // ignore: cast_nullable_to_non_nullable
as double,periodsUsed: null == periodsUsed ? _self.periodsUsed : periodsUsed // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
