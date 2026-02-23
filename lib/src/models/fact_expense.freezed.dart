// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'fact_expense.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$FactExpense {

 String get id; double get amount; String? get description; DateTime get timestamp; String? get linkedPlannedExpenseId;
/// Create a copy of FactExpense
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FactExpenseCopyWith<FactExpense> get copyWith => _$FactExpenseCopyWithImpl<FactExpense>(this as FactExpense, _$identity);

  /// Serializes this FactExpense to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FactExpense&&(identical(other.id, id) || other.id == id)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.description, description) || other.description == description)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.linkedPlannedExpenseId, linkedPlannedExpenseId) || other.linkedPlannedExpenseId == linkedPlannedExpenseId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,amount,description,timestamp,linkedPlannedExpenseId);

@override
String toString() {
  return 'FactExpense(id: $id, amount: $amount, description: $description, timestamp: $timestamp, linkedPlannedExpenseId: $linkedPlannedExpenseId)';
}


}

/// @nodoc
abstract mixin class $FactExpenseCopyWith<$Res>  {
  factory $FactExpenseCopyWith(FactExpense value, $Res Function(FactExpense) _then) = _$FactExpenseCopyWithImpl;
@useResult
$Res call({
 String id, double amount, String? description, DateTime timestamp, String? linkedPlannedExpenseId
});




}
/// @nodoc
class _$FactExpenseCopyWithImpl<$Res>
    implements $FactExpenseCopyWith<$Res> {
  _$FactExpenseCopyWithImpl(this._self, this._then);

  final FactExpense _self;
  final $Res Function(FactExpense) _then;

/// Create a copy of FactExpense
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? amount = null,Object? description = freezed,Object? timestamp = null,Object? linkedPlannedExpenseId = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as double,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,linkedPlannedExpenseId: freezed == linkedPlannedExpenseId ? _self.linkedPlannedExpenseId : linkedPlannedExpenseId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [FactExpense].
extension FactExpensePatterns on FactExpense {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FactExpense value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FactExpense() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FactExpense value)  $default,){
final _that = this;
switch (_that) {
case _FactExpense():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FactExpense value)?  $default,){
final _that = this;
switch (_that) {
case _FactExpense() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  double amount,  String? description,  DateTime timestamp,  String? linkedPlannedExpenseId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FactExpense() when $default != null:
return $default(_that.id,_that.amount,_that.description,_that.timestamp,_that.linkedPlannedExpenseId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  double amount,  String? description,  DateTime timestamp,  String? linkedPlannedExpenseId)  $default,) {final _that = this;
switch (_that) {
case _FactExpense():
return $default(_that.id,_that.amount,_that.description,_that.timestamp,_that.linkedPlannedExpenseId);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  double amount,  String? description,  DateTime timestamp,  String? linkedPlannedExpenseId)?  $default,) {final _that = this;
switch (_that) {
case _FactExpense() when $default != null:
return $default(_that.id,_that.amount,_that.description,_that.timestamp,_that.linkedPlannedExpenseId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FactExpense implements FactExpense {
  const _FactExpense({required this.id, required this.amount, this.description, required this.timestamp, this.linkedPlannedExpenseId});
  factory _FactExpense.fromJson(Map<String, dynamic> json) => _$FactExpenseFromJson(json);

@override final  String id;
@override final  double amount;
@override final  String? description;
@override final  DateTime timestamp;
@override final  String? linkedPlannedExpenseId;

/// Create a copy of FactExpense
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FactExpenseCopyWith<_FactExpense> get copyWith => __$FactExpenseCopyWithImpl<_FactExpense>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FactExpenseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FactExpense&&(identical(other.id, id) || other.id == id)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.description, description) || other.description == description)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.linkedPlannedExpenseId, linkedPlannedExpenseId) || other.linkedPlannedExpenseId == linkedPlannedExpenseId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,amount,description,timestamp,linkedPlannedExpenseId);

@override
String toString() {
  return 'FactExpense(id: $id, amount: $amount, description: $description, timestamp: $timestamp, linkedPlannedExpenseId: $linkedPlannedExpenseId)';
}


}

/// @nodoc
abstract mixin class _$FactExpenseCopyWith<$Res> implements $FactExpenseCopyWith<$Res> {
  factory _$FactExpenseCopyWith(_FactExpense value, $Res Function(_FactExpense) _then) = __$FactExpenseCopyWithImpl;
@override @useResult
$Res call({
 String id, double amount, String? description, DateTime timestamp, String? linkedPlannedExpenseId
});




}
/// @nodoc
class __$FactExpenseCopyWithImpl<$Res>
    implements _$FactExpenseCopyWith<$Res> {
  __$FactExpenseCopyWithImpl(this._self, this._then);

  final _FactExpense _self;
  final $Res Function(_FactExpense) _then;

/// Create a copy of FactExpense
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? amount = null,Object? description = freezed,Object? timestamp = null,Object? linkedPlannedExpenseId = freezed,}) {
  return _then(_FactExpense(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as double,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,linkedPlannedExpenseId: freezed == linkedPlannedExpenseId ? _self.linkedPlannedExpenseId : linkedPlannedExpenseId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
