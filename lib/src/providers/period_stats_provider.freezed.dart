// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'period_stats_provider.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$CategoryStats {

 String get categoryId; String get name; CategoryType get type; double get limit; double get totalSpent; double get totalPlanned; double get remaining; double get heatPercentage; bool get isOverBudget; bool get isDailyAllowance; double? get dailyAllowanceAmount; int? get expectedPurchaseFrequencyDays; double? get expectedPurchaseAmount;
/// Create a copy of CategoryStats
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CategoryStatsCopyWith<CategoryStats> get copyWith => _$CategoryStatsCopyWithImpl<CategoryStats>(this as CategoryStats, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CategoryStats&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.name, name) || other.name == name)&&(identical(other.type, type) || other.type == type)&&(identical(other.limit, limit) || other.limit == limit)&&(identical(other.totalSpent, totalSpent) || other.totalSpent == totalSpent)&&(identical(other.totalPlanned, totalPlanned) || other.totalPlanned == totalPlanned)&&(identical(other.remaining, remaining) || other.remaining == remaining)&&(identical(other.heatPercentage, heatPercentage) || other.heatPercentage == heatPercentage)&&(identical(other.isOverBudget, isOverBudget) || other.isOverBudget == isOverBudget)&&(identical(other.isDailyAllowance, isDailyAllowance) || other.isDailyAllowance == isDailyAllowance)&&(identical(other.dailyAllowanceAmount, dailyAllowanceAmount) || other.dailyAllowanceAmount == dailyAllowanceAmount)&&(identical(other.expectedPurchaseFrequencyDays, expectedPurchaseFrequencyDays) || other.expectedPurchaseFrequencyDays == expectedPurchaseFrequencyDays)&&(identical(other.expectedPurchaseAmount, expectedPurchaseAmount) || other.expectedPurchaseAmount == expectedPurchaseAmount));
}


@override
int get hashCode => Object.hash(runtimeType,categoryId,name,type,limit,totalSpent,totalPlanned,remaining,heatPercentage,isOverBudget,isDailyAllowance,dailyAllowanceAmount,expectedPurchaseFrequencyDays,expectedPurchaseAmount);

@override
String toString() {
  return 'CategoryStats(categoryId: $categoryId, name: $name, type: $type, limit: $limit, totalSpent: $totalSpent, totalPlanned: $totalPlanned, remaining: $remaining, heatPercentage: $heatPercentage, isOverBudget: $isOverBudget, isDailyAllowance: $isDailyAllowance, dailyAllowanceAmount: $dailyAllowanceAmount, expectedPurchaseFrequencyDays: $expectedPurchaseFrequencyDays, expectedPurchaseAmount: $expectedPurchaseAmount)';
}


}

/// @nodoc
abstract mixin class $CategoryStatsCopyWith<$Res>  {
  factory $CategoryStatsCopyWith(CategoryStats value, $Res Function(CategoryStats) _then) = _$CategoryStatsCopyWithImpl;
@useResult
$Res call({
 String categoryId, String name, CategoryType type, double limit, double totalSpent, double totalPlanned, double remaining, double heatPercentage, bool isOverBudget, bool isDailyAllowance, double? dailyAllowanceAmount, int? expectedPurchaseFrequencyDays, double? expectedPurchaseAmount
});




}
/// @nodoc
class _$CategoryStatsCopyWithImpl<$Res>
    implements $CategoryStatsCopyWith<$Res> {
  _$CategoryStatsCopyWithImpl(this._self, this._then);

  final CategoryStats _self;
  final $Res Function(CategoryStats) _then;

/// Create a copy of CategoryStats
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? categoryId = null,Object? name = null,Object? type = null,Object? limit = null,Object? totalSpent = null,Object? totalPlanned = null,Object? remaining = null,Object? heatPercentage = null,Object? isOverBudget = null,Object? isDailyAllowance = null,Object? dailyAllowanceAmount = freezed,Object? expectedPurchaseFrequencyDays = freezed,Object? expectedPurchaseAmount = freezed,}) {
  return _then(_self.copyWith(
categoryId: null == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as CategoryType,limit: null == limit ? _self.limit : limit // ignore: cast_nullable_to_non_nullable
as double,totalSpent: null == totalSpent ? _self.totalSpent : totalSpent // ignore: cast_nullable_to_non_nullable
as double,totalPlanned: null == totalPlanned ? _self.totalPlanned : totalPlanned // ignore: cast_nullable_to_non_nullable
as double,remaining: null == remaining ? _self.remaining : remaining // ignore: cast_nullable_to_non_nullable
as double,heatPercentage: null == heatPercentage ? _self.heatPercentage : heatPercentage // ignore: cast_nullable_to_non_nullable
as double,isOverBudget: null == isOverBudget ? _self.isOverBudget : isOverBudget // ignore: cast_nullable_to_non_nullable
as bool,isDailyAllowance: null == isDailyAllowance ? _self.isDailyAllowance : isDailyAllowance // ignore: cast_nullable_to_non_nullable
as bool,dailyAllowanceAmount: freezed == dailyAllowanceAmount ? _self.dailyAllowanceAmount : dailyAllowanceAmount // ignore: cast_nullable_to_non_nullable
as double?,expectedPurchaseFrequencyDays: freezed == expectedPurchaseFrequencyDays ? _self.expectedPurchaseFrequencyDays : expectedPurchaseFrequencyDays // ignore: cast_nullable_to_non_nullable
as int?,expectedPurchaseAmount: freezed == expectedPurchaseAmount ? _self.expectedPurchaseAmount : expectedPurchaseAmount // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

}


/// Adds pattern-matching-related methods to [CategoryStats].
extension CategoryStatsPatterns on CategoryStats {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CategoryStats value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CategoryStats() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CategoryStats value)  $default,){
final _that = this;
switch (_that) {
case _CategoryStats():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CategoryStats value)?  $default,){
final _that = this;
switch (_that) {
case _CategoryStats() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String categoryId,  String name,  CategoryType type,  double limit,  double totalSpent,  double totalPlanned,  double remaining,  double heatPercentage,  bool isOverBudget,  bool isDailyAllowance,  double? dailyAllowanceAmount,  int? expectedPurchaseFrequencyDays,  double? expectedPurchaseAmount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CategoryStats() when $default != null:
return $default(_that.categoryId,_that.name,_that.type,_that.limit,_that.totalSpent,_that.totalPlanned,_that.remaining,_that.heatPercentage,_that.isOverBudget,_that.isDailyAllowance,_that.dailyAllowanceAmount,_that.expectedPurchaseFrequencyDays,_that.expectedPurchaseAmount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String categoryId,  String name,  CategoryType type,  double limit,  double totalSpent,  double totalPlanned,  double remaining,  double heatPercentage,  bool isOverBudget,  bool isDailyAllowance,  double? dailyAllowanceAmount,  int? expectedPurchaseFrequencyDays,  double? expectedPurchaseAmount)  $default,) {final _that = this;
switch (_that) {
case _CategoryStats():
return $default(_that.categoryId,_that.name,_that.type,_that.limit,_that.totalSpent,_that.totalPlanned,_that.remaining,_that.heatPercentage,_that.isOverBudget,_that.isDailyAllowance,_that.dailyAllowanceAmount,_that.expectedPurchaseFrequencyDays,_that.expectedPurchaseAmount);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String categoryId,  String name,  CategoryType type,  double limit,  double totalSpent,  double totalPlanned,  double remaining,  double heatPercentage,  bool isOverBudget,  bool isDailyAllowance,  double? dailyAllowanceAmount,  int? expectedPurchaseFrequencyDays,  double? expectedPurchaseAmount)?  $default,) {final _that = this;
switch (_that) {
case _CategoryStats() when $default != null:
return $default(_that.categoryId,_that.name,_that.type,_that.limit,_that.totalSpent,_that.totalPlanned,_that.remaining,_that.heatPercentage,_that.isOverBudget,_that.isDailyAllowance,_that.dailyAllowanceAmount,_that.expectedPurchaseFrequencyDays,_that.expectedPurchaseAmount);case _:
  return null;

}
}

}

/// @nodoc


class _CategoryStats implements CategoryStats {
  const _CategoryStats({required this.categoryId, required this.name, required this.type, required this.limit, required this.totalSpent, required this.totalPlanned, required this.remaining, required this.heatPercentage, required this.isOverBudget, required this.isDailyAllowance, this.dailyAllowanceAmount, this.expectedPurchaseFrequencyDays, this.expectedPurchaseAmount});
  

@override final  String categoryId;
@override final  String name;
@override final  CategoryType type;
@override final  double limit;
@override final  double totalSpent;
@override final  double totalPlanned;
@override final  double remaining;
@override final  double heatPercentage;
@override final  bool isOverBudget;
@override final  bool isDailyAllowance;
@override final  double? dailyAllowanceAmount;
@override final  int? expectedPurchaseFrequencyDays;
@override final  double? expectedPurchaseAmount;

/// Create a copy of CategoryStats
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CategoryStatsCopyWith<_CategoryStats> get copyWith => __$CategoryStatsCopyWithImpl<_CategoryStats>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CategoryStats&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.name, name) || other.name == name)&&(identical(other.type, type) || other.type == type)&&(identical(other.limit, limit) || other.limit == limit)&&(identical(other.totalSpent, totalSpent) || other.totalSpent == totalSpent)&&(identical(other.totalPlanned, totalPlanned) || other.totalPlanned == totalPlanned)&&(identical(other.remaining, remaining) || other.remaining == remaining)&&(identical(other.heatPercentage, heatPercentage) || other.heatPercentage == heatPercentage)&&(identical(other.isOverBudget, isOverBudget) || other.isOverBudget == isOverBudget)&&(identical(other.isDailyAllowance, isDailyAllowance) || other.isDailyAllowance == isDailyAllowance)&&(identical(other.dailyAllowanceAmount, dailyAllowanceAmount) || other.dailyAllowanceAmount == dailyAllowanceAmount)&&(identical(other.expectedPurchaseFrequencyDays, expectedPurchaseFrequencyDays) || other.expectedPurchaseFrequencyDays == expectedPurchaseFrequencyDays)&&(identical(other.expectedPurchaseAmount, expectedPurchaseAmount) || other.expectedPurchaseAmount == expectedPurchaseAmount));
}


@override
int get hashCode => Object.hash(runtimeType,categoryId,name,type,limit,totalSpent,totalPlanned,remaining,heatPercentage,isOverBudget,isDailyAllowance,dailyAllowanceAmount,expectedPurchaseFrequencyDays,expectedPurchaseAmount);

@override
String toString() {
  return 'CategoryStats(categoryId: $categoryId, name: $name, type: $type, limit: $limit, totalSpent: $totalSpent, totalPlanned: $totalPlanned, remaining: $remaining, heatPercentage: $heatPercentage, isOverBudget: $isOverBudget, isDailyAllowance: $isDailyAllowance, dailyAllowanceAmount: $dailyAllowanceAmount, expectedPurchaseFrequencyDays: $expectedPurchaseFrequencyDays, expectedPurchaseAmount: $expectedPurchaseAmount)';
}


}

/// @nodoc
abstract mixin class _$CategoryStatsCopyWith<$Res> implements $CategoryStatsCopyWith<$Res> {
  factory _$CategoryStatsCopyWith(_CategoryStats value, $Res Function(_CategoryStats) _then) = __$CategoryStatsCopyWithImpl;
@override @useResult
$Res call({
 String categoryId, String name, CategoryType type, double limit, double totalSpent, double totalPlanned, double remaining, double heatPercentage, bool isOverBudget, bool isDailyAllowance, double? dailyAllowanceAmount, int? expectedPurchaseFrequencyDays, double? expectedPurchaseAmount
});




}
/// @nodoc
class __$CategoryStatsCopyWithImpl<$Res>
    implements _$CategoryStatsCopyWith<$Res> {
  __$CategoryStatsCopyWithImpl(this._self, this._then);

  final _CategoryStats _self;
  final $Res Function(_CategoryStats) _then;

/// Create a copy of CategoryStats
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? categoryId = null,Object? name = null,Object? type = null,Object? limit = null,Object? totalSpent = null,Object? totalPlanned = null,Object? remaining = null,Object? heatPercentage = null,Object? isOverBudget = null,Object? isDailyAllowance = null,Object? dailyAllowanceAmount = freezed,Object? expectedPurchaseFrequencyDays = freezed,Object? expectedPurchaseAmount = freezed,}) {
  return _then(_CategoryStats(
categoryId: null == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as CategoryType,limit: null == limit ? _self.limit : limit // ignore: cast_nullable_to_non_nullable
as double,totalSpent: null == totalSpent ? _self.totalSpent : totalSpent // ignore: cast_nullable_to_non_nullable
as double,totalPlanned: null == totalPlanned ? _self.totalPlanned : totalPlanned // ignore: cast_nullable_to_non_nullable
as double,remaining: null == remaining ? _self.remaining : remaining // ignore: cast_nullable_to_non_nullable
as double,heatPercentage: null == heatPercentage ? _self.heatPercentage : heatPercentage // ignore: cast_nullable_to_non_nullable
as double,isOverBudget: null == isOverBudget ? _self.isOverBudget : isOverBudget // ignore: cast_nullable_to_non_nullable
as bool,isDailyAllowance: null == isDailyAllowance ? _self.isDailyAllowance : isDailyAllowance // ignore: cast_nullable_to_non_nullable
as bool,dailyAllowanceAmount: freezed == dailyAllowanceAmount ? _self.dailyAllowanceAmount : dailyAllowanceAmount // ignore: cast_nullable_to_non_nullable
as double?,expectedPurchaseFrequencyDays: freezed == expectedPurchaseFrequencyDays ? _self.expectedPurchaseFrequencyDays : expectedPurchaseFrequencyDays // ignore: cast_nullable_to_non_nullable
as int?,expectedPurchaseAmount: freezed == expectedPurchaseAmount ? _self.expectedPurchaseAmount : expectedPurchaseAmount // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}


}

/// @nodoc
mixin _$PeriodStats {

 double get totalMandatoryBudget; double get totalMandatorySpent; double get totalOptionalBudget; double get totalOptionalSpent; double get totalBudget; double get totalSpent; double get overallRemaining; double get remainingFreeBalance; double get totalIncome; double get totalFactIncome; List<CategoryStats> get categoryStats;
/// Create a copy of PeriodStats
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PeriodStatsCopyWith<PeriodStats> get copyWith => _$PeriodStatsCopyWithImpl<PeriodStats>(this as PeriodStats, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PeriodStats&&(identical(other.totalMandatoryBudget, totalMandatoryBudget) || other.totalMandatoryBudget == totalMandatoryBudget)&&(identical(other.totalMandatorySpent, totalMandatorySpent) || other.totalMandatorySpent == totalMandatorySpent)&&(identical(other.totalOptionalBudget, totalOptionalBudget) || other.totalOptionalBudget == totalOptionalBudget)&&(identical(other.totalOptionalSpent, totalOptionalSpent) || other.totalOptionalSpent == totalOptionalSpent)&&(identical(other.totalBudget, totalBudget) || other.totalBudget == totalBudget)&&(identical(other.totalSpent, totalSpent) || other.totalSpent == totalSpent)&&(identical(other.overallRemaining, overallRemaining) || other.overallRemaining == overallRemaining)&&(identical(other.remainingFreeBalance, remainingFreeBalance) || other.remainingFreeBalance == remainingFreeBalance)&&(identical(other.totalIncome, totalIncome) || other.totalIncome == totalIncome)&&(identical(other.totalFactIncome, totalFactIncome) || other.totalFactIncome == totalFactIncome)&&const DeepCollectionEquality().equals(other.categoryStats, categoryStats));
}


@override
int get hashCode => Object.hash(runtimeType,totalMandatoryBudget,totalMandatorySpent,totalOptionalBudget,totalOptionalSpent,totalBudget,totalSpent,overallRemaining,remainingFreeBalance,totalIncome,totalFactIncome,const DeepCollectionEquality().hash(categoryStats));

@override
String toString() {
  return 'PeriodStats(totalMandatoryBudget: $totalMandatoryBudget, totalMandatorySpent: $totalMandatorySpent, totalOptionalBudget: $totalOptionalBudget, totalOptionalSpent: $totalOptionalSpent, totalBudget: $totalBudget, totalSpent: $totalSpent, overallRemaining: $overallRemaining, remainingFreeBalance: $remainingFreeBalance, totalIncome: $totalIncome, totalFactIncome: $totalFactIncome, categoryStats: $categoryStats)';
}


}

/// @nodoc
abstract mixin class $PeriodStatsCopyWith<$Res>  {
  factory $PeriodStatsCopyWith(PeriodStats value, $Res Function(PeriodStats) _then) = _$PeriodStatsCopyWithImpl;
@useResult
$Res call({
 double totalMandatoryBudget, double totalMandatorySpent, double totalOptionalBudget, double totalOptionalSpent, double totalBudget, double totalSpent, double overallRemaining, double remainingFreeBalance, double totalIncome, double totalFactIncome, List<CategoryStats> categoryStats
});




}
/// @nodoc
class _$PeriodStatsCopyWithImpl<$Res>
    implements $PeriodStatsCopyWith<$Res> {
  _$PeriodStatsCopyWithImpl(this._self, this._then);

  final PeriodStats _self;
  final $Res Function(PeriodStats) _then;

/// Create a copy of PeriodStats
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? totalMandatoryBudget = null,Object? totalMandatorySpent = null,Object? totalOptionalBudget = null,Object? totalOptionalSpent = null,Object? totalBudget = null,Object? totalSpent = null,Object? overallRemaining = null,Object? remainingFreeBalance = null,Object? totalIncome = null,Object? totalFactIncome = null,Object? categoryStats = null,}) {
  return _then(_self.copyWith(
totalMandatoryBudget: null == totalMandatoryBudget ? _self.totalMandatoryBudget : totalMandatoryBudget // ignore: cast_nullable_to_non_nullable
as double,totalMandatorySpent: null == totalMandatorySpent ? _self.totalMandatorySpent : totalMandatorySpent // ignore: cast_nullable_to_non_nullable
as double,totalOptionalBudget: null == totalOptionalBudget ? _self.totalOptionalBudget : totalOptionalBudget // ignore: cast_nullable_to_non_nullable
as double,totalOptionalSpent: null == totalOptionalSpent ? _self.totalOptionalSpent : totalOptionalSpent // ignore: cast_nullable_to_non_nullable
as double,totalBudget: null == totalBudget ? _self.totalBudget : totalBudget // ignore: cast_nullable_to_non_nullable
as double,totalSpent: null == totalSpent ? _self.totalSpent : totalSpent // ignore: cast_nullable_to_non_nullable
as double,overallRemaining: null == overallRemaining ? _self.overallRemaining : overallRemaining // ignore: cast_nullable_to_non_nullable
as double,remainingFreeBalance: null == remainingFreeBalance ? _self.remainingFreeBalance : remainingFreeBalance // ignore: cast_nullable_to_non_nullable
as double,totalIncome: null == totalIncome ? _self.totalIncome : totalIncome // ignore: cast_nullable_to_non_nullable
as double,totalFactIncome: null == totalFactIncome ? _self.totalFactIncome : totalFactIncome // ignore: cast_nullable_to_non_nullable
as double,categoryStats: null == categoryStats ? _self.categoryStats : categoryStats // ignore: cast_nullable_to_non_nullable
as List<CategoryStats>,
  ));
}

}


/// Adds pattern-matching-related methods to [PeriodStats].
extension PeriodStatsPatterns on PeriodStats {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PeriodStats value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PeriodStats() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PeriodStats value)  $default,){
final _that = this;
switch (_that) {
case _PeriodStats():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PeriodStats value)?  $default,){
final _that = this;
switch (_that) {
case _PeriodStats() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double totalMandatoryBudget,  double totalMandatorySpent,  double totalOptionalBudget,  double totalOptionalSpent,  double totalBudget,  double totalSpent,  double overallRemaining,  double remainingFreeBalance,  double totalIncome,  double totalFactIncome,  List<CategoryStats> categoryStats)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PeriodStats() when $default != null:
return $default(_that.totalMandatoryBudget,_that.totalMandatorySpent,_that.totalOptionalBudget,_that.totalOptionalSpent,_that.totalBudget,_that.totalSpent,_that.overallRemaining,_that.remainingFreeBalance,_that.totalIncome,_that.totalFactIncome,_that.categoryStats);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double totalMandatoryBudget,  double totalMandatorySpent,  double totalOptionalBudget,  double totalOptionalSpent,  double totalBudget,  double totalSpent,  double overallRemaining,  double remainingFreeBalance,  double totalIncome,  double totalFactIncome,  List<CategoryStats> categoryStats)  $default,) {final _that = this;
switch (_that) {
case _PeriodStats():
return $default(_that.totalMandatoryBudget,_that.totalMandatorySpent,_that.totalOptionalBudget,_that.totalOptionalSpent,_that.totalBudget,_that.totalSpent,_that.overallRemaining,_that.remainingFreeBalance,_that.totalIncome,_that.totalFactIncome,_that.categoryStats);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double totalMandatoryBudget,  double totalMandatorySpent,  double totalOptionalBudget,  double totalOptionalSpent,  double totalBudget,  double totalSpent,  double overallRemaining,  double remainingFreeBalance,  double totalIncome,  double totalFactIncome,  List<CategoryStats> categoryStats)?  $default,) {final _that = this;
switch (_that) {
case _PeriodStats() when $default != null:
return $default(_that.totalMandatoryBudget,_that.totalMandatorySpent,_that.totalOptionalBudget,_that.totalOptionalSpent,_that.totalBudget,_that.totalSpent,_that.overallRemaining,_that.remainingFreeBalance,_that.totalIncome,_that.totalFactIncome,_that.categoryStats);case _:
  return null;

}
}

}

/// @nodoc


class _PeriodStats implements PeriodStats {
  const _PeriodStats({required this.totalMandatoryBudget, required this.totalMandatorySpent, required this.totalOptionalBudget, required this.totalOptionalSpent, required this.totalBudget, required this.totalSpent, required this.overallRemaining, required this.remainingFreeBalance, required this.totalIncome, required this.totalFactIncome, required final  List<CategoryStats> categoryStats}): _categoryStats = categoryStats;
  

@override final  double totalMandatoryBudget;
@override final  double totalMandatorySpent;
@override final  double totalOptionalBudget;
@override final  double totalOptionalSpent;
@override final  double totalBudget;
@override final  double totalSpent;
@override final  double overallRemaining;
@override final  double remainingFreeBalance;
@override final  double totalIncome;
@override final  double totalFactIncome;
 final  List<CategoryStats> _categoryStats;
@override List<CategoryStats> get categoryStats {
  if (_categoryStats is EqualUnmodifiableListView) return _categoryStats;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_categoryStats);
}


/// Create a copy of PeriodStats
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PeriodStatsCopyWith<_PeriodStats> get copyWith => __$PeriodStatsCopyWithImpl<_PeriodStats>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PeriodStats&&(identical(other.totalMandatoryBudget, totalMandatoryBudget) || other.totalMandatoryBudget == totalMandatoryBudget)&&(identical(other.totalMandatorySpent, totalMandatorySpent) || other.totalMandatorySpent == totalMandatorySpent)&&(identical(other.totalOptionalBudget, totalOptionalBudget) || other.totalOptionalBudget == totalOptionalBudget)&&(identical(other.totalOptionalSpent, totalOptionalSpent) || other.totalOptionalSpent == totalOptionalSpent)&&(identical(other.totalBudget, totalBudget) || other.totalBudget == totalBudget)&&(identical(other.totalSpent, totalSpent) || other.totalSpent == totalSpent)&&(identical(other.overallRemaining, overallRemaining) || other.overallRemaining == overallRemaining)&&(identical(other.remainingFreeBalance, remainingFreeBalance) || other.remainingFreeBalance == remainingFreeBalance)&&(identical(other.totalIncome, totalIncome) || other.totalIncome == totalIncome)&&(identical(other.totalFactIncome, totalFactIncome) || other.totalFactIncome == totalFactIncome)&&const DeepCollectionEquality().equals(other._categoryStats, _categoryStats));
}


@override
int get hashCode => Object.hash(runtimeType,totalMandatoryBudget,totalMandatorySpent,totalOptionalBudget,totalOptionalSpent,totalBudget,totalSpent,overallRemaining,remainingFreeBalance,totalIncome,totalFactIncome,const DeepCollectionEquality().hash(_categoryStats));

@override
String toString() {
  return 'PeriodStats(totalMandatoryBudget: $totalMandatoryBudget, totalMandatorySpent: $totalMandatorySpent, totalOptionalBudget: $totalOptionalBudget, totalOptionalSpent: $totalOptionalSpent, totalBudget: $totalBudget, totalSpent: $totalSpent, overallRemaining: $overallRemaining, remainingFreeBalance: $remainingFreeBalance, totalIncome: $totalIncome, totalFactIncome: $totalFactIncome, categoryStats: $categoryStats)';
}


}

/// @nodoc
abstract mixin class _$PeriodStatsCopyWith<$Res> implements $PeriodStatsCopyWith<$Res> {
  factory _$PeriodStatsCopyWith(_PeriodStats value, $Res Function(_PeriodStats) _then) = __$PeriodStatsCopyWithImpl;
@override @useResult
$Res call({
 double totalMandatoryBudget, double totalMandatorySpent, double totalOptionalBudget, double totalOptionalSpent, double totalBudget, double totalSpent, double overallRemaining, double remainingFreeBalance, double totalIncome, double totalFactIncome, List<CategoryStats> categoryStats
});




}
/// @nodoc
class __$PeriodStatsCopyWithImpl<$Res>
    implements _$PeriodStatsCopyWith<$Res> {
  __$PeriodStatsCopyWithImpl(this._self, this._then);

  final _PeriodStats _self;
  final $Res Function(_PeriodStats) _then;

/// Create a copy of PeriodStats
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? totalMandatoryBudget = null,Object? totalMandatorySpent = null,Object? totalOptionalBudget = null,Object? totalOptionalSpent = null,Object? totalBudget = null,Object? totalSpent = null,Object? overallRemaining = null,Object? remainingFreeBalance = null,Object? totalIncome = null,Object? totalFactIncome = null,Object? categoryStats = null,}) {
  return _then(_PeriodStats(
totalMandatoryBudget: null == totalMandatoryBudget ? _self.totalMandatoryBudget : totalMandatoryBudget // ignore: cast_nullable_to_non_nullable
as double,totalMandatorySpent: null == totalMandatorySpent ? _self.totalMandatorySpent : totalMandatorySpent // ignore: cast_nullable_to_non_nullable
as double,totalOptionalBudget: null == totalOptionalBudget ? _self.totalOptionalBudget : totalOptionalBudget // ignore: cast_nullable_to_non_nullable
as double,totalOptionalSpent: null == totalOptionalSpent ? _self.totalOptionalSpent : totalOptionalSpent // ignore: cast_nullable_to_non_nullable
as double,totalBudget: null == totalBudget ? _self.totalBudget : totalBudget // ignore: cast_nullable_to_non_nullable
as double,totalSpent: null == totalSpent ? _self.totalSpent : totalSpent // ignore: cast_nullable_to_non_nullable
as double,overallRemaining: null == overallRemaining ? _self.overallRemaining : overallRemaining // ignore: cast_nullable_to_non_nullable
as double,remainingFreeBalance: null == remainingFreeBalance ? _self.remainingFreeBalance : remainingFreeBalance // ignore: cast_nullable_to_non_nullable
as double,totalIncome: null == totalIncome ? _self.totalIncome : totalIncome // ignore: cast_nullable_to_non_nullable
as double,totalFactIncome: null == totalFactIncome ? _self.totalFactIncome : totalFactIncome // ignore: cast_nullable_to_non_nullable
as double,categoryStats: null == categoryStats ? _self._categoryStats : categoryStats // ignore: cast_nullable_to_non_nullable
as List<CategoryStats>,
  ));
}


}

// dart format on
