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

/// @nodoc
mixin _$BasketAdvice {

/// Budget held back for small incidental spending still to come.
 double get snackReserve;/// What is left for baskets once the reserve is held back.
 double get basketBudget;/// Baskets expected in the days remaining.
 double get tripsLeft;/// [basketBudget] divided across [tripsLeft].
 double get safeBasket;/// The history the advice was derived from.
 BasketStats get stats;
/// Create a copy of BasketAdvice
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BasketAdviceCopyWith<BasketAdvice> get copyWith => _$BasketAdviceCopyWithImpl<BasketAdvice>(this as BasketAdvice, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BasketAdvice&&(identical(other.snackReserve, snackReserve) || other.snackReserve == snackReserve)&&(identical(other.basketBudget, basketBudget) || other.basketBudget == basketBudget)&&(identical(other.tripsLeft, tripsLeft) || other.tripsLeft == tripsLeft)&&(identical(other.safeBasket, safeBasket) || other.safeBasket == safeBasket)&&(identical(other.stats, stats) || other.stats == stats));
}


@override
int get hashCode => Object.hash(runtimeType,snackReserve,basketBudget,tripsLeft,safeBasket,stats);

@override
String toString() {
  return 'BasketAdvice(snackReserve: $snackReserve, basketBudget: $basketBudget, tripsLeft: $tripsLeft, safeBasket: $safeBasket, stats: $stats)';
}


}

/// @nodoc
abstract mixin class $BasketAdviceCopyWith<$Res>  {
  factory $BasketAdviceCopyWith(BasketAdvice value, $Res Function(BasketAdvice) _then) = _$BasketAdviceCopyWithImpl;
@useResult
$Res call({
 double snackReserve, double basketBudget, double tripsLeft, double safeBasket, BasketStats stats
});


$BasketStatsCopyWith<$Res> get stats;

}
/// @nodoc
class _$BasketAdviceCopyWithImpl<$Res>
    implements $BasketAdviceCopyWith<$Res> {
  _$BasketAdviceCopyWithImpl(this._self, this._then);

  final BasketAdvice _self;
  final $Res Function(BasketAdvice) _then;

/// Create a copy of BasketAdvice
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? snackReserve = null,Object? basketBudget = null,Object? tripsLeft = null,Object? safeBasket = null,Object? stats = null,}) {
  return _then(_self.copyWith(
snackReserve: null == snackReserve ? _self.snackReserve : snackReserve // ignore: cast_nullable_to_non_nullable
as double,basketBudget: null == basketBudget ? _self.basketBudget : basketBudget // ignore: cast_nullable_to_non_nullable
as double,tripsLeft: null == tripsLeft ? _self.tripsLeft : tripsLeft // ignore: cast_nullable_to_non_nullable
as double,safeBasket: null == safeBasket ? _self.safeBasket : safeBasket // ignore: cast_nullable_to_non_nullable
as double,stats: null == stats ? _self.stats : stats // ignore: cast_nullable_to_non_nullable
as BasketStats,
  ));
}
/// Create a copy of BasketAdvice
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BasketStatsCopyWith<$Res> get stats {
  
  return $BasketStatsCopyWith<$Res>(_self.stats, (value) {
    return _then(_self.copyWith(stats: value));
  });
}
}


/// Adds pattern-matching-related methods to [BasketAdvice].
extension BasketAdvicePatterns on BasketAdvice {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BasketAdvice value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BasketAdvice() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BasketAdvice value)  $default,){
final _that = this;
switch (_that) {
case _BasketAdvice():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BasketAdvice value)?  $default,){
final _that = this;
switch (_that) {
case _BasketAdvice() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double snackReserve,  double basketBudget,  double tripsLeft,  double safeBasket,  BasketStats stats)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BasketAdvice() when $default != null:
return $default(_that.snackReserve,_that.basketBudget,_that.tripsLeft,_that.safeBasket,_that.stats);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double snackReserve,  double basketBudget,  double tripsLeft,  double safeBasket,  BasketStats stats)  $default,) {final _that = this;
switch (_that) {
case _BasketAdvice():
return $default(_that.snackReserve,_that.basketBudget,_that.tripsLeft,_that.safeBasket,_that.stats);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double snackReserve,  double basketBudget,  double tripsLeft,  double safeBasket,  BasketStats stats)?  $default,) {final _that = this;
switch (_that) {
case _BasketAdvice() when $default != null:
return $default(_that.snackReserve,_that.basketBudget,_that.tripsLeft,_that.safeBasket,_that.stats);case _:
  return null;

}
}

}

/// @nodoc


class _BasketAdvice implements BasketAdvice {
  const _BasketAdvice({required this.snackReserve, required this.basketBudget, required this.tripsLeft, required this.safeBasket, required this.stats});
  

/// Budget held back for small incidental spending still to come.
@override final  double snackReserve;
/// What is left for baskets once the reserve is held back.
@override final  double basketBudget;
/// Baskets expected in the days remaining.
@override final  double tripsLeft;
/// [basketBudget] divided across [tripsLeft].
@override final  double safeBasket;
/// The history the advice was derived from.
@override final  BasketStats stats;

/// Create a copy of BasketAdvice
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BasketAdviceCopyWith<_BasketAdvice> get copyWith => __$BasketAdviceCopyWithImpl<_BasketAdvice>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BasketAdvice&&(identical(other.snackReserve, snackReserve) || other.snackReserve == snackReserve)&&(identical(other.basketBudget, basketBudget) || other.basketBudget == basketBudget)&&(identical(other.tripsLeft, tripsLeft) || other.tripsLeft == tripsLeft)&&(identical(other.safeBasket, safeBasket) || other.safeBasket == safeBasket)&&(identical(other.stats, stats) || other.stats == stats));
}


@override
int get hashCode => Object.hash(runtimeType,snackReserve,basketBudget,tripsLeft,safeBasket,stats);

@override
String toString() {
  return 'BasketAdvice(snackReserve: $snackReserve, basketBudget: $basketBudget, tripsLeft: $tripsLeft, safeBasket: $safeBasket, stats: $stats)';
}


}

/// @nodoc
abstract mixin class _$BasketAdviceCopyWith<$Res> implements $BasketAdviceCopyWith<$Res> {
  factory _$BasketAdviceCopyWith(_BasketAdvice value, $Res Function(_BasketAdvice) _then) = __$BasketAdviceCopyWithImpl;
@override @useResult
$Res call({
 double snackReserve, double basketBudget, double tripsLeft, double safeBasket, BasketStats stats
});


@override $BasketStatsCopyWith<$Res> get stats;

}
/// @nodoc
class __$BasketAdviceCopyWithImpl<$Res>
    implements _$BasketAdviceCopyWith<$Res> {
  __$BasketAdviceCopyWithImpl(this._self, this._then);

  final _BasketAdvice _self;
  final $Res Function(_BasketAdvice) _then;

/// Create a copy of BasketAdvice
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? snackReserve = null,Object? basketBudget = null,Object? tripsLeft = null,Object? safeBasket = null,Object? stats = null,}) {
  return _then(_BasketAdvice(
snackReserve: null == snackReserve ? _self.snackReserve : snackReserve // ignore: cast_nullable_to_non_nullable
as double,basketBudget: null == basketBudget ? _self.basketBudget : basketBudget // ignore: cast_nullable_to_non_nullable
as double,tripsLeft: null == tripsLeft ? _self.tripsLeft : tripsLeft // ignore: cast_nullable_to_non_nullable
as double,safeBasket: null == safeBasket ? _self.safeBasket : safeBasket // ignore: cast_nullable_to_non_nullable
as double,stats: null == stats ? _self.stats : stats // ignore: cast_nullable_to_non_nullable
as BasketStats,
  ));
}

/// Create a copy of BasketAdvice
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BasketStatsCopyWith<$Res> get stats {
  
  return $BasketStatsCopyWith<$Res>(_self.stats, (value) {
    return _then(_self.copyWith(stats: value));
  });
}
}

// dart format on
