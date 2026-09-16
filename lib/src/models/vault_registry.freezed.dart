// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'vault_registry.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$VaultRegistry {

 int get version; String? get lastSelectedVaultId; List<Vault> get vaults;/// Set at runtime when the registry file was corrupt and moved aside.
/// Never written to disk.
@JsonKey(includeFromJson: false, includeToJson: false) String? get brokenRegistryFile;
/// Create a copy of VaultRegistry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VaultRegistryCopyWith<VaultRegistry> get copyWith => _$VaultRegistryCopyWithImpl<VaultRegistry>(this as VaultRegistry, _$identity);

  /// Serializes this VaultRegistry to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VaultRegistry&&(identical(other.version, version) || other.version == version)&&(identical(other.lastSelectedVaultId, lastSelectedVaultId) || other.lastSelectedVaultId == lastSelectedVaultId)&&const DeepCollectionEquality().equals(other.vaults, vaults)&&(identical(other.brokenRegistryFile, brokenRegistryFile) || other.brokenRegistryFile == brokenRegistryFile));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,version,lastSelectedVaultId,const DeepCollectionEquality().hash(vaults),brokenRegistryFile);

@override
String toString() {
  return 'VaultRegistry(version: $version, lastSelectedVaultId: $lastSelectedVaultId, vaults: $vaults, brokenRegistryFile: $brokenRegistryFile)';
}


}

/// @nodoc
abstract mixin class $VaultRegistryCopyWith<$Res>  {
  factory $VaultRegistryCopyWith(VaultRegistry value, $Res Function(VaultRegistry) _then) = _$VaultRegistryCopyWithImpl;
@useResult
$Res call({
 int version, String? lastSelectedVaultId, List<Vault> vaults,@JsonKey(includeFromJson: false, includeToJson: false) String? brokenRegistryFile
});




}
/// @nodoc
class _$VaultRegistryCopyWithImpl<$Res>
    implements $VaultRegistryCopyWith<$Res> {
  _$VaultRegistryCopyWithImpl(this._self, this._then);

  final VaultRegistry _self;
  final $Res Function(VaultRegistry) _then;

/// Create a copy of VaultRegistry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? version = null,Object? lastSelectedVaultId = freezed,Object? vaults = null,Object? brokenRegistryFile = freezed,}) {
  return _then(_self.copyWith(
version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,lastSelectedVaultId: freezed == lastSelectedVaultId ? _self.lastSelectedVaultId : lastSelectedVaultId // ignore: cast_nullable_to_non_nullable
as String?,vaults: null == vaults ? _self.vaults : vaults // ignore: cast_nullable_to_non_nullable
as List<Vault>,brokenRegistryFile: freezed == brokenRegistryFile ? _self.brokenRegistryFile : brokenRegistryFile // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [VaultRegistry].
extension VaultRegistryPatterns on VaultRegistry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VaultRegistry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VaultRegistry() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VaultRegistry value)  $default,){
final _that = this;
switch (_that) {
case _VaultRegistry():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VaultRegistry value)?  $default,){
final _that = this;
switch (_that) {
case _VaultRegistry() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int version,  String? lastSelectedVaultId,  List<Vault> vaults, @JsonKey(includeFromJson: false, includeToJson: false)  String? brokenRegistryFile)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VaultRegistry() when $default != null:
return $default(_that.version,_that.lastSelectedVaultId,_that.vaults,_that.brokenRegistryFile);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int version,  String? lastSelectedVaultId,  List<Vault> vaults, @JsonKey(includeFromJson: false, includeToJson: false)  String? brokenRegistryFile)  $default,) {final _that = this;
switch (_that) {
case _VaultRegistry():
return $default(_that.version,_that.lastSelectedVaultId,_that.vaults,_that.brokenRegistryFile);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int version,  String? lastSelectedVaultId,  List<Vault> vaults, @JsonKey(includeFromJson: false, includeToJson: false)  String? brokenRegistryFile)?  $default,) {final _that = this;
switch (_that) {
case _VaultRegistry() when $default != null:
return $default(_that.version,_that.lastSelectedVaultId,_that.vaults,_that.brokenRegistryFile);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _VaultRegistry extends VaultRegistry {
  const _VaultRegistry({this.version = 1, this.lastSelectedVaultId, final  List<Vault> vaults = const [], @JsonKey(includeFromJson: false, includeToJson: false) this.brokenRegistryFile}): _vaults = vaults,super._();
  factory _VaultRegistry.fromJson(Map<String, dynamic> json) => _$VaultRegistryFromJson(json);

@override@JsonKey() final  int version;
@override final  String? lastSelectedVaultId;
 final  List<Vault> _vaults;
@override@JsonKey() List<Vault> get vaults {
  if (_vaults is EqualUnmodifiableListView) return _vaults;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_vaults);
}

/// Set at runtime when the registry file was corrupt and moved aside.
/// Never written to disk.
@override@JsonKey(includeFromJson: false, includeToJson: false) final  String? brokenRegistryFile;

/// Create a copy of VaultRegistry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VaultRegistryCopyWith<_VaultRegistry> get copyWith => __$VaultRegistryCopyWithImpl<_VaultRegistry>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VaultRegistryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VaultRegistry&&(identical(other.version, version) || other.version == version)&&(identical(other.lastSelectedVaultId, lastSelectedVaultId) || other.lastSelectedVaultId == lastSelectedVaultId)&&const DeepCollectionEquality().equals(other._vaults, _vaults)&&(identical(other.brokenRegistryFile, brokenRegistryFile) || other.brokenRegistryFile == brokenRegistryFile));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,version,lastSelectedVaultId,const DeepCollectionEquality().hash(_vaults),brokenRegistryFile);

@override
String toString() {
  return 'VaultRegistry(version: $version, lastSelectedVaultId: $lastSelectedVaultId, vaults: $vaults, brokenRegistryFile: $brokenRegistryFile)';
}


}

/// @nodoc
abstract mixin class _$VaultRegistryCopyWith<$Res> implements $VaultRegistryCopyWith<$Res> {
  factory _$VaultRegistryCopyWith(_VaultRegistry value, $Res Function(_VaultRegistry) _then) = __$VaultRegistryCopyWithImpl;
@override @useResult
$Res call({
 int version, String? lastSelectedVaultId, List<Vault> vaults,@JsonKey(includeFromJson: false, includeToJson: false) String? brokenRegistryFile
});




}
/// @nodoc
class __$VaultRegistryCopyWithImpl<$Res>
    implements _$VaultRegistryCopyWith<$Res> {
  __$VaultRegistryCopyWithImpl(this._self, this._then);

  final _VaultRegistry _self;
  final $Res Function(_VaultRegistry) _then;

/// Create a copy of VaultRegistry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? version = null,Object? lastSelectedVaultId = freezed,Object? vaults = null,Object? brokenRegistryFile = freezed,}) {
  return _then(_VaultRegistry(
version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,lastSelectedVaultId: freezed == lastSelectedVaultId ? _self.lastSelectedVaultId : lastSelectedVaultId // ignore: cast_nullable_to_non_nullable
as String?,vaults: null == vaults ? _self._vaults : vaults // ignore: cast_nullable_to_non_nullable
as List<Vault>,brokenRegistryFile: freezed == brokenRegistryFile ? _self.brokenRegistryFile : brokenRegistryFile // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
