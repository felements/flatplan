// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'planned_expense.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PlannedExpense {

 String get id; String get description; double get amount; DueDate get dueDate; bool get isCompleted;
/// Create a copy of PlannedExpense
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlannedExpenseCopyWith<PlannedExpense> get copyWith => _$PlannedExpenseCopyWithImpl<PlannedExpense>(this as PlannedExpense, _$identity);

  /// Serializes this PlannedExpense to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PlannedExpense&&(identical(other.id, id) || other.id == id)&&(identical(other.description, description) || other.description == description)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.dueDate, dueDate) || other.dueDate == dueDate)&&(identical(other.isCompleted, isCompleted) || other.isCompleted == isCompleted));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,description,amount,dueDate,isCompleted);

@override
String toString() {
  return 'PlannedExpense(id: $id, description: $description, amount: $amount, dueDate: $dueDate, isCompleted: $isCompleted)';
}


}

/// @nodoc
abstract mixin class $PlannedExpenseCopyWith<$Res>  {
  factory $PlannedExpenseCopyWith(PlannedExpense value, $Res Function(PlannedExpense) _then) = _$PlannedExpenseCopyWithImpl;
@useResult
$Res call({
 String id, String description, double amount, DueDate dueDate, bool isCompleted
});


$DueDateCopyWith<$Res> get dueDate;

}
/// @nodoc
class _$PlannedExpenseCopyWithImpl<$Res>
    implements $PlannedExpenseCopyWith<$Res> {
  _$PlannedExpenseCopyWithImpl(this._self, this._then);

  final PlannedExpense _self;
  final $Res Function(PlannedExpense) _then;

/// Create a copy of PlannedExpense
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? description = null,Object? amount = null,Object? dueDate = null,Object? isCompleted = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as double,dueDate: null == dueDate ? _self.dueDate : dueDate // ignore: cast_nullable_to_non_nullable
as DueDate,isCompleted: null == isCompleted ? _self.isCompleted : isCompleted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of PlannedExpense
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DueDateCopyWith<$Res> get dueDate {
  
  return $DueDateCopyWith<$Res>(_self.dueDate, (value) {
    return _then(_self.copyWith(dueDate: value));
  });
}
}


/// Adds pattern-matching-related methods to [PlannedExpense].
extension PlannedExpensePatterns on PlannedExpense {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PlannedExpense value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PlannedExpense() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PlannedExpense value)  $default,){
final _that = this;
switch (_that) {
case _PlannedExpense():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PlannedExpense value)?  $default,){
final _that = this;
switch (_that) {
case _PlannedExpense() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String description,  double amount,  DueDate dueDate,  bool isCompleted)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PlannedExpense() when $default != null:
return $default(_that.id,_that.description,_that.amount,_that.dueDate,_that.isCompleted);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String description,  double amount,  DueDate dueDate,  bool isCompleted)  $default,) {final _that = this;
switch (_that) {
case _PlannedExpense():
return $default(_that.id,_that.description,_that.amount,_that.dueDate,_that.isCompleted);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String description,  double amount,  DueDate dueDate,  bool isCompleted)?  $default,) {final _that = this;
switch (_that) {
case _PlannedExpense() when $default != null:
return $default(_that.id,_that.description,_that.amount,_that.dueDate,_that.isCompleted);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PlannedExpense implements PlannedExpense {
  const _PlannedExpense({required this.id, required this.description, required this.amount, required this.dueDate, this.isCompleted = false});
  factory _PlannedExpense.fromJson(Map<String, dynamic> json) => _$PlannedExpenseFromJson(json);

@override final  String id;
@override final  String description;
@override final  double amount;
@override final  DueDate dueDate;
@override@JsonKey() final  bool isCompleted;

/// Create a copy of PlannedExpense
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PlannedExpenseCopyWith<_PlannedExpense> get copyWith => __$PlannedExpenseCopyWithImpl<_PlannedExpense>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PlannedExpenseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PlannedExpense&&(identical(other.id, id) || other.id == id)&&(identical(other.description, description) || other.description == description)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.dueDate, dueDate) || other.dueDate == dueDate)&&(identical(other.isCompleted, isCompleted) || other.isCompleted == isCompleted));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,description,amount,dueDate,isCompleted);

@override
String toString() {
  return 'PlannedExpense(id: $id, description: $description, amount: $amount, dueDate: $dueDate, isCompleted: $isCompleted)';
}


}

/// @nodoc
abstract mixin class _$PlannedExpenseCopyWith<$Res> implements $PlannedExpenseCopyWith<$Res> {
  factory _$PlannedExpenseCopyWith(_PlannedExpense value, $Res Function(_PlannedExpense) _then) = __$PlannedExpenseCopyWithImpl;
@override @useResult
$Res call({
 String id, String description, double amount, DueDate dueDate, bool isCompleted
});


@override $DueDateCopyWith<$Res> get dueDate;

}
/// @nodoc
class __$PlannedExpenseCopyWithImpl<$Res>
    implements _$PlannedExpenseCopyWith<$Res> {
  __$PlannedExpenseCopyWithImpl(this._self, this._then);

  final _PlannedExpense _self;
  final $Res Function(_PlannedExpense) _then;

/// Create a copy of PlannedExpense
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? description = null,Object? amount = null,Object? dueDate = null,Object? isCompleted = null,}) {
  return _then(_PlannedExpense(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as double,dueDate: null == dueDate ? _self.dueDate : dueDate // ignore: cast_nullable_to_non_nullable
as DueDate,isCompleted: null == isCompleted ? _self.isCompleted : isCompleted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of PlannedExpense
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DueDateCopyWith<$Res> get dueDate {
  
  return $DueDateCopyWith<$Res>(_self.dueDate, (value) {
    return _then(_self.copyWith(dueDate: value));
  });
}
}

// dart format on
