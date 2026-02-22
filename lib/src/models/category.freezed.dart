// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'category.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Category {

 String get id; String get name; String? get description; bool get isMandatory; double? get limit; bool get isDailyAllowance; List<PlannedExpense> get plannedExpenses; List<FactExpense> get factExpenses;
/// Create a copy of Category
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CategoryCopyWith<Category> get copyWith => _$CategoryCopyWithImpl<Category>(this as Category, _$identity);

  /// Serializes this Category to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Category&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.isMandatory, isMandatory) || other.isMandatory == isMandatory)&&(identical(other.limit, limit) || other.limit == limit)&&(identical(other.isDailyAllowance, isDailyAllowance) || other.isDailyAllowance == isDailyAllowance)&&const DeepCollectionEquality().equals(other.plannedExpenses, plannedExpenses)&&const DeepCollectionEquality().equals(other.factExpenses, factExpenses));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,description,isMandatory,limit,isDailyAllowance,const DeepCollectionEquality().hash(plannedExpenses),const DeepCollectionEquality().hash(factExpenses));

@override
String toString() {
  return 'Category(id: $id, name: $name, description: $description, isMandatory: $isMandatory, limit: $limit, isDailyAllowance: $isDailyAllowance, plannedExpenses: $plannedExpenses, factExpenses: $factExpenses)';
}


}

/// @nodoc
abstract mixin class $CategoryCopyWith<$Res>  {
  factory $CategoryCopyWith(Category value, $Res Function(Category) _then) = _$CategoryCopyWithImpl;
@useResult
$Res call({
 String id, String name, String? description, bool isMandatory, double? limit, bool isDailyAllowance, List<PlannedExpense> plannedExpenses, List<FactExpense> factExpenses
});




}
/// @nodoc
class _$CategoryCopyWithImpl<$Res>
    implements $CategoryCopyWith<$Res> {
  _$CategoryCopyWithImpl(this._self, this._then);

  final Category _self;
  final $Res Function(Category) _then;

/// Create a copy of Category
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? description = freezed,Object? isMandatory = null,Object? limit = freezed,Object? isDailyAllowance = null,Object? plannedExpenses = null,Object? factExpenses = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,isMandatory: null == isMandatory ? _self.isMandatory : isMandatory // ignore: cast_nullable_to_non_nullable
as bool,limit: freezed == limit ? _self.limit : limit // ignore: cast_nullable_to_non_nullable
as double?,isDailyAllowance: null == isDailyAllowance ? _self.isDailyAllowance : isDailyAllowance // ignore: cast_nullable_to_non_nullable
as bool,plannedExpenses: null == plannedExpenses ? _self.plannedExpenses : plannedExpenses // ignore: cast_nullable_to_non_nullable
as List<PlannedExpense>,factExpenses: null == factExpenses ? _self.factExpenses : factExpenses // ignore: cast_nullable_to_non_nullable
as List<FactExpense>,
  ));
}

}


/// Adds pattern-matching-related methods to [Category].
extension CategoryPatterns on Category {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Category value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Category() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Category value)  $default,){
final _that = this;
switch (_that) {
case _Category():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Category value)?  $default,){
final _that = this;
switch (_that) {
case _Category() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String? description,  bool isMandatory,  double? limit,  bool isDailyAllowance,  List<PlannedExpense> plannedExpenses,  List<FactExpense> factExpenses)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Category() when $default != null:
return $default(_that.id,_that.name,_that.description,_that.isMandatory,_that.limit,_that.isDailyAllowance,_that.plannedExpenses,_that.factExpenses);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String? description,  bool isMandatory,  double? limit,  bool isDailyAllowance,  List<PlannedExpense> plannedExpenses,  List<FactExpense> factExpenses)  $default,) {final _that = this;
switch (_that) {
case _Category():
return $default(_that.id,_that.name,_that.description,_that.isMandatory,_that.limit,_that.isDailyAllowance,_that.plannedExpenses,_that.factExpenses);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String? description,  bool isMandatory,  double? limit,  bool isDailyAllowance,  List<PlannedExpense> plannedExpenses,  List<FactExpense> factExpenses)?  $default,) {final _that = this;
switch (_that) {
case _Category() when $default != null:
return $default(_that.id,_that.name,_that.description,_that.isMandatory,_that.limit,_that.isDailyAllowance,_that.plannedExpenses,_that.factExpenses);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Category implements Category {
  const _Category({required this.id, required this.name, this.description, required this.isMandatory, this.limit, this.isDailyAllowance = false, final  List<PlannedExpense> plannedExpenses = const [], final  List<FactExpense> factExpenses = const []}): _plannedExpenses = plannedExpenses,_factExpenses = factExpenses;
  factory _Category.fromJson(Map<String, dynamic> json) => _$CategoryFromJson(json);

@override final  String id;
@override final  String name;
@override final  String? description;
@override final  bool isMandatory;
@override final  double? limit;
@override@JsonKey() final  bool isDailyAllowance;
 final  List<PlannedExpense> _plannedExpenses;
@override@JsonKey() List<PlannedExpense> get plannedExpenses {
  if (_plannedExpenses is EqualUnmodifiableListView) return _plannedExpenses;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_plannedExpenses);
}

 final  List<FactExpense> _factExpenses;
@override@JsonKey() List<FactExpense> get factExpenses {
  if (_factExpenses is EqualUnmodifiableListView) return _factExpenses;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_factExpenses);
}


/// Create a copy of Category
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CategoryCopyWith<_Category> get copyWith => __$CategoryCopyWithImpl<_Category>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CategoryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Category&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.isMandatory, isMandatory) || other.isMandatory == isMandatory)&&(identical(other.limit, limit) || other.limit == limit)&&(identical(other.isDailyAllowance, isDailyAllowance) || other.isDailyAllowance == isDailyAllowance)&&const DeepCollectionEquality().equals(other._plannedExpenses, _plannedExpenses)&&const DeepCollectionEquality().equals(other._factExpenses, _factExpenses));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,description,isMandatory,limit,isDailyAllowance,const DeepCollectionEquality().hash(_plannedExpenses),const DeepCollectionEquality().hash(_factExpenses));

@override
String toString() {
  return 'Category(id: $id, name: $name, description: $description, isMandatory: $isMandatory, limit: $limit, isDailyAllowance: $isDailyAllowance, plannedExpenses: $plannedExpenses, factExpenses: $factExpenses)';
}


}

/// @nodoc
abstract mixin class _$CategoryCopyWith<$Res> implements $CategoryCopyWith<$Res> {
  factory _$CategoryCopyWith(_Category value, $Res Function(_Category) _then) = __$CategoryCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String? description, bool isMandatory, double? limit, bool isDailyAllowance, List<PlannedExpense> plannedExpenses, List<FactExpense> factExpenses
});




}
/// @nodoc
class __$CategoryCopyWithImpl<$Res>
    implements _$CategoryCopyWith<$Res> {
  __$CategoryCopyWithImpl(this._self, this._then);

  final _Category _self;
  final $Res Function(_Category) _then;

/// Create a copy of Category
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? description = freezed,Object? isMandatory = null,Object? limit = freezed,Object? isDailyAllowance = null,Object? plannedExpenses = null,Object? factExpenses = null,}) {
  return _then(_Category(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,isMandatory: null == isMandatory ? _self.isMandatory : isMandatory // ignore: cast_nullable_to_non_nullable
as bool,limit: freezed == limit ? _self.limit : limit // ignore: cast_nullable_to_non_nullable
as double?,isDailyAllowance: null == isDailyAllowance ? _self.isDailyAllowance : isDailyAllowance // ignore: cast_nullable_to_non_nullable
as bool,plannedExpenses: null == plannedExpenses ? _self._plannedExpenses : plannedExpenses // ignore: cast_nullable_to_non_nullable
as List<PlannedExpense>,factExpenses: null == factExpenses ? _self._factExpenses : factExpenses // ignore: cast_nullable_to_non_nullable
as List<FactExpense>,
  ));
}


}

// dart format on
