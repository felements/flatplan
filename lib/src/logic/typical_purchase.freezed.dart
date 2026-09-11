// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'typical_purchase.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$TypicalPurchase {

/// The median purchase over the recent history.
 double get amount;/// Days between purchases of that size at the remaining budget.
 int get everyDays;/// How many past purchases the median was taken over.
 int get purchasesUsed;
/// Create a copy of TypicalPurchase
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TypicalPurchaseCopyWith<TypicalPurchase> get copyWith => _$TypicalPurchaseCopyWithImpl<TypicalPurchase>(this as TypicalPurchase, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TypicalPurchase&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.everyDays, everyDays) || other.everyDays == everyDays)&&(identical(other.purchasesUsed, purchasesUsed) || other.purchasesUsed == purchasesUsed));
}


@override
int get hashCode => Object.hash(runtimeType,amount,everyDays,purchasesUsed);

@override
String toString() {
  return 'TypicalPurchase(amount: $amount, everyDays: $everyDays, purchasesUsed: $purchasesUsed)';
}


}

/// @nodoc
abstract mixin class $TypicalPurchaseCopyWith<$Res>  {
  factory $TypicalPurchaseCopyWith(TypicalPurchase value, $Res Function(TypicalPurchase) _then) = _$TypicalPurchaseCopyWithImpl;
@useResult
$Res call({
 double amount, int everyDays, int purchasesUsed
});




}
/// @nodoc
class _$TypicalPurchaseCopyWithImpl<$Res>
    implements $TypicalPurchaseCopyWith<$Res> {
  _$TypicalPurchaseCopyWithImpl(this._self, this._then);

  final TypicalPurchase _self;
  final $Res Function(TypicalPurchase) _then;

/// Create a copy of TypicalPurchase
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? amount = null,Object? everyDays = null,Object? purchasesUsed = null,}) {
  return _then(_self.copyWith(
amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as double,everyDays: null == everyDays ? _self.everyDays : everyDays // ignore: cast_nullable_to_non_nullable
as int,purchasesUsed: null == purchasesUsed ? _self.purchasesUsed : purchasesUsed // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [TypicalPurchase].
extension TypicalPurchasePatterns on TypicalPurchase {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TypicalPurchase value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TypicalPurchase() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TypicalPurchase value)  $default,){
final _that = this;
switch (_that) {
case _TypicalPurchase():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TypicalPurchase value)?  $default,){
final _that = this;
switch (_that) {
case _TypicalPurchase() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double amount,  int everyDays,  int purchasesUsed)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TypicalPurchase() when $default != null:
return $default(_that.amount,_that.everyDays,_that.purchasesUsed);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double amount,  int everyDays,  int purchasesUsed)  $default,) {final _that = this;
switch (_that) {
case _TypicalPurchase():
return $default(_that.amount,_that.everyDays,_that.purchasesUsed);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double amount,  int everyDays,  int purchasesUsed)?  $default,) {final _that = this;
switch (_that) {
case _TypicalPurchase() when $default != null:
return $default(_that.amount,_that.everyDays,_that.purchasesUsed);case _:
  return null;

}
}

}

/// @nodoc


class _TypicalPurchase implements TypicalPurchase {
  const _TypicalPurchase({required this.amount, required this.everyDays, required this.purchasesUsed});
  

/// The median purchase over the recent history.
@override final  double amount;
/// Days between purchases of that size at the remaining budget.
@override final  int everyDays;
/// How many past purchases the median was taken over.
@override final  int purchasesUsed;

/// Create a copy of TypicalPurchase
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TypicalPurchaseCopyWith<_TypicalPurchase> get copyWith => __$TypicalPurchaseCopyWithImpl<_TypicalPurchase>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TypicalPurchase&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.everyDays, everyDays) || other.everyDays == everyDays)&&(identical(other.purchasesUsed, purchasesUsed) || other.purchasesUsed == purchasesUsed));
}


@override
int get hashCode => Object.hash(runtimeType,amount,everyDays,purchasesUsed);

@override
String toString() {
  return 'TypicalPurchase(amount: $amount, everyDays: $everyDays, purchasesUsed: $purchasesUsed)';
}


}

/// @nodoc
abstract mixin class _$TypicalPurchaseCopyWith<$Res> implements $TypicalPurchaseCopyWith<$Res> {
  factory _$TypicalPurchaseCopyWith(_TypicalPurchase value, $Res Function(_TypicalPurchase) _then) = __$TypicalPurchaseCopyWithImpl;
@override @useResult
$Res call({
 double amount, int everyDays, int purchasesUsed
});




}
/// @nodoc
class __$TypicalPurchaseCopyWithImpl<$Res>
    implements _$TypicalPurchaseCopyWith<$Res> {
  __$TypicalPurchaseCopyWithImpl(this._self, this._then);

  final _TypicalPurchase _self;
  final $Res Function(_TypicalPurchase) _then;

/// Create a copy of TypicalPurchase
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? amount = null,Object? everyDays = null,Object? purchasesUsed = null,}) {
  return _then(_TypicalPurchase(
amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as double,everyDays: null == everyDays ? _self.everyDays : everyDays // ignore: cast_nullable_to_non_nullable
as int,purchasesUsed: null == purchasesUsed ? _self.purchasesUsed : purchasesUsed // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
