// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'period.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Period {

 String get id; String get name; DateTime get startDate; String get baseCurrency; DateTime get lastModified; List<Category> get categories;
/// Create a copy of Period
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PeriodCopyWith<Period> get copyWith => _$PeriodCopyWithImpl<Period>(this as Period, _$identity);

  /// Serializes this Period to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Period&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.startDate, startDate) || other.startDate == startDate)&&(identical(other.baseCurrency, baseCurrency) || other.baseCurrency == baseCurrency)&&(identical(other.lastModified, lastModified) || other.lastModified == lastModified)&&const DeepCollectionEquality().equals(other.categories, categories));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,startDate,baseCurrency,lastModified,const DeepCollectionEquality().hash(categories));

@override
String toString() {
  return 'Period(id: $id, name: $name, startDate: $startDate, baseCurrency: $baseCurrency, lastModified: $lastModified, categories: $categories)';
}


}

/// @nodoc
abstract mixin class $PeriodCopyWith<$Res>  {
  factory $PeriodCopyWith(Period value, $Res Function(Period) _then) = _$PeriodCopyWithImpl;
@useResult
$Res call({
 String id, String name, DateTime startDate, String baseCurrency, DateTime lastModified, List<Category> categories
});




}
/// @nodoc
class _$PeriodCopyWithImpl<$Res>
    implements $PeriodCopyWith<$Res> {
  _$PeriodCopyWithImpl(this._self, this._then);

  final Period _self;
  final $Res Function(Period) _then;

/// Create a copy of Period
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? startDate = null,Object? baseCurrency = null,Object? lastModified = null,Object? categories = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,startDate: null == startDate ? _self.startDate : startDate // ignore: cast_nullable_to_non_nullable
as DateTime,baseCurrency: null == baseCurrency ? _self.baseCurrency : baseCurrency // ignore: cast_nullable_to_non_nullable
as String,lastModified: null == lastModified ? _self.lastModified : lastModified // ignore: cast_nullable_to_non_nullable
as DateTime,categories: null == categories ? _self.categories : categories // ignore: cast_nullable_to_non_nullable
as List<Category>,
  ));
}

}


/// Adds pattern-matching-related methods to [Period].
extension PeriodPatterns on Period {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Period value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Period() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Period value)  $default,){
final _that = this;
switch (_that) {
case _Period():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Period value)?  $default,){
final _that = this;
switch (_that) {
case _Period() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  DateTime startDate,  String baseCurrency,  DateTime lastModified,  List<Category> categories)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Period() when $default != null:
return $default(_that.id,_that.name,_that.startDate,_that.baseCurrency,_that.lastModified,_that.categories);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  DateTime startDate,  String baseCurrency,  DateTime lastModified,  List<Category> categories)  $default,) {final _that = this;
switch (_that) {
case _Period():
return $default(_that.id,_that.name,_that.startDate,_that.baseCurrency,_that.lastModified,_that.categories);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  DateTime startDate,  String baseCurrency,  DateTime lastModified,  List<Category> categories)?  $default,) {final _that = this;
switch (_that) {
case _Period() when $default != null:
return $default(_that.id,_that.name,_that.startDate,_that.baseCurrency,_that.lastModified,_that.categories);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Period implements Period {
  const _Period({required this.id, required this.name, required this.startDate, required this.baseCurrency, required this.lastModified, final  List<Category> categories = const []}): _categories = categories;
  factory _Period.fromJson(Map<String, dynamic> json) => _$PeriodFromJson(json);

@override final  String id;
@override final  String name;
@override final  DateTime startDate;
@override final  String baseCurrency;
@override final  DateTime lastModified;
 final  List<Category> _categories;
@override@JsonKey() List<Category> get categories {
  if (_categories is EqualUnmodifiableListView) return _categories;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_categories);
}


/// Create a copy of Period
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PeriodCopyWith<_Period> get copyWith => __$PeriodCopyWithImpl<_Period>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PeriodToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Period&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.startDate, startDate) || other.startDate == startDate)&&(identical(other.baseCurrency, baseCurrency) || other.baseCurrency == baseCurrency)&&(identical(other.lastModified, lastModified) || other.lastModified == lastModified)&&const DeepCollectionEquality().equals(other._categories, _categories));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,startDate,baseCurrency,lastModified,const DeepCollectionEquality().hash(_categories));

@override
String toString() {
  return 'Period(id: $id, name: $name, startDate: $startDate, baseCurrency: $baseCurrency, lastModified: $lastModified, categories: $categories)';
}


}

/// @nodoc
abstract mixin class _$PeriodCopyWith<$Res> implements $PeriodCopyWith<$Res> {
  factory _$PeriodCopyWith(_Period value, $Res Function(_Period) _then) = __$PeriodCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, DateTime startDate, String baseCurrency, DateTime lastModified, List<Category> categories
});




}
/// @nodoc
class __$PeriodCopyWithImpl<$Res>
    implements _$PeriodCopyWith<$Res> {
  __$PeriodCopyWithImpl(this._self, this._then);

  final _Period _self;
  final $Res Function(_Period) _then;

/// Create a copy of Period
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? startDate = null,Object? baseCurrency = null,Object? lastModified = null,Object? categories = null,}) {
  return _then(_Period(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,startDate: null == startDate ? _self.startDate : startDate // ignore: cast_nullable_to_non_nullable
as DateTime,baseCurrency: null == baseCurrency ? _self.baseCurrency : baseCurrency // ignore: cast_nullable_to_non_nullable
as String,lastModified: null == lastModified ? _self.lastModified : lastModified // ignore: cast_nullable_to_non_nullable
as DateTime,categories: null == categories ? _self._categories : categories // ignore: cast_nullable_to_non_nullable
as List<Category>,
  ));
}


}

// dart format on
