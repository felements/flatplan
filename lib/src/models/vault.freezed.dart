// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'vault.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Vault {

 String get id; String get name; VaultLocation get location; DateTime get createdAt;
/// Create a copy of Vault
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VaultCopyWith<Vault> get copyWith => _$VaultCopyWithImpl<Vault>(this as Vault, _$identity);

  /// Serializes this Vault to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Vault&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.location, location) || other.location == location)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,location,createdAt);

@override
String toString() {
  return 'Vault(id: $id, name: $name, location: $location, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $VaultCopyWith<$Res>  {
  factory $VaultCopyWith(Vault value, $Res Function(Vault) _then) = _$VaultCopyWithImpl;
@useResult
$Res call({
 String id, String name, VaultLocation location, DateTime createdAt
});


$VaultLocationCopyWith<$Res> get location;

}
/// @nodoc
class _$VaultCopyWithImpl<$Res>
    implements $VaultCopyWith<$Res> {
  _$VaultCopyWithImpl(this._self, this._then);

  final Vault _self;
  final $Res Function(Vault) _then;

/// Create a copy of Vault
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? location = null,Object? createdAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,location: null == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as VaultLocation,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}
/// Create a copy of Vault
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VaultLocationCopyWith<$Res> get location {
  
  return $VaultLocationCopyWith<$Res>(_self.location, (value) {
    return _then(_self.copyWith(location: value));
  });
}
}


/// Adds pattern-matching-related methods to [Vault].
extension VaultPatterns on Vault {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Vault value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Vault() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Vault value)  $default,){
final _that = this;
switch (_that) {
case _Vault():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Vault value)?  $default,){
final _that = this;
switch (_that) {
case _Vault() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  VaultLocation location,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Vault() when $default != null:
return $default(_that.id,_that.name,_that.location,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  VaultLocation location,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _Vault():
return $default(_that.id,_that.name,_that.location,_that.createdAt);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  VaultLocation location,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _Vault() when $default != null:
return $default(_that.id,_that.name,_that.location,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Vault implements Vault {
  const _Vault({required this.id, required this.name, required this.location, required this.createdAt});
  factory _Vault.fromJson(Map<String, dynamic> json) => _$VaultFromJson(json);

@override final  String id;
@override final  String name;
@override final  VaultLocation location;
@override final  DateTime createdAt;

/// Create a copy of Vault
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VaultCopyWith<_Vault> get copyWith => __$VaultCopyWithImpl<_Vault>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VaultToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Vault&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.location, location) || other.location == location)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,location,createdAt);

@override
String toString() {
  return 'Vault(id: $id, name: $name, location: $location, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$VaultCopyWith<$Res> implements $VaultCopyWith<$Res> {
  factory _$VaultCopyWith(_Vault value, $Res Function(_Vault) _then) = __$VaultCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, VaultLocation location, DateTime createdAt
});


@override $VaultLocationCopyWith<$Res> get location;

}
/// @nodoc
class __$VaultCopyWithImpl<$Res>
    implements _$VaultCopyWith<$Res> {
  __$VaultCopyWithImpl(this._self, this._then);

  final _Vault _self;
  final $Res Function(_Vault) _then;

/// Create a copy of Vault
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? location = null,Object? createdAt = null,}) {
  return _then(_Vault(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,location: null == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as VaultLocation,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

/// Create a copy of Vault
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VaultLocationCopyWith<$Res> get location {
  
  return $VaultLocationCopyWith<$Res>(_self.location, (value) {
    return _then(_self.copyWith(location: value));
  });
}
}

VaultLocation _$VaultLocationFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'local':
          return LocalVaultLocation.fromJson(
            json
          );
                case 'remote':
          return RemoteVaultLocation.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'type',
  'VaultLocation',
  'Invalid union type "${json['type']}"!'
);
        }
      
}

/// @nodoc
mixin _$VaultLocation {



  /// Serializes this VaultLocation to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VaultLocation);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'VaultLocation()';
}


}

/// @nodoc
class $VaultLocationCopyWith<$Res>  {
$VaultLocationCopyWith(VaultLocation _, $Res Function(VaultLocation) __);
}


/// Adds pattern-matching-related methods to [VaultLocation].
extension VaultLocationPatterns on VaultLocation {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( LocalVaultLocation value)?  local,TResult Function( RemoteVaultLocation value)?  remote,required TResult orElse(),}){
final _that = this;
switch (_that) {
case LocalVaultLocation() when local != null:
return local(_that);case RemoteVaultLocation() when remote != null:
return remote(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( LocalVaultLocation value)  local,required TResult Function( RemoteVaultLocation value)  remote,}){
final _that = this;
switch (_that) {
case LocalVaultLocation():
return local(_that);case RemoteVaultLocation():
return remote(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( LocalVaultLocation value)?  local,TResult? Function( RemoteVaultLocation value)?  remote,}){
final _that = this;
switch (_that) {
case LocalVaultLocation() when local != null:
return local(_that);case RemoteVaultLocation() when remote != null:
return remote(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String path,  String? bookmark)?  local,TResult Function( String kind, @JsonKey(fromJson: _settingsFromJson)  Map<String, dynamic> settings,  List<String> secretNames)?  remote,required TResult orElse(),}) {final _that = this;
switch (_that) {
case LocalVaultLocation() when local != null:
return local(_that.path,_that.bookmark);case RemoteVaultLocation() when remote != null:
return remote(_that.kind,_that.settings,_that.secretNames);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String path,  String? bookmark)  local,required TResult Function( String kind, @JsonKey(fromJson: _settingsFromJson)  Map<String, dynamic> settings,  List<String> secretNames)  remote,}) {final _that = this;
switch (_that) {
case LocalVaultLocation():
return local(_that.path,_that.bookmark);case RemoteVaultLocation():
return remote(_that.kind,_that.settings,_that.secretNames);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String path,  String? bookmark)?  local,TResult? Function( String kind, @JsonKey(fromJson: _settingsFromJson)  Map<String, dynamic> settings,  List<String> secretNames)?  remote,}) {final _that = this;
switch (_that) {
case LocalVaultLocation() when local != null:
return local(_that.path,_that.bookmark);case RemoteVaultLocation() when remote != null:
return remote(_that.kind,_that.settings,_that.secretNames);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class LocalVaultLocation implements VaultLocation {
  const LocalVaultLocation({required this.path, this.bookmark, final  String? $type}): $type = $type ?? 'local';
  factory LocalVaultLocation.fromJson(Map<String, dynamic> json) => _$LocalVaultLocationFromJson(json);

 final  String path;
 final  String? bookmark;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of VaultLocation
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LocalVaultLocationCopyWith<LocalVaultLocation> get copyWith => _$LocalVaultLocationCopyWithImpl<LocalVaultLocation>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LocalVaultLocationToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LocalVaultLocation&&(identical(other.path, path) || other.path == path)&&(identical(other.bookmark, bookmark) || other.bookmark == bookmark));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,path,bookmark);

@override
String toString() {
  return 'VaultLocation.local(path: $path, bookmark: $bookmark)';
}


}

/// @nodoc
abstract mixin class $LocalVaultLocationCopyWith<$Res> implements $VaultLocationCopyWith<$Res> {
  factory $LocalVaultLocationCopyWith(LocalVaultLocation value, $Res Function(LocalVaultLocation) _then) = _$LocalVaultLocationCopyWithImpl;
@useResult
$Res call({
 String path, String? bookmark
});




}
/// @nodoc
class _$LocalVaultLocationCopyWithImpl<$Res>
    implements $LocalVaultLocationCopyWith<$Res> {
  _$LocalVaultLocationCopyWithImpl(this._self, this._then);

  final LocalVaultLocation _self;
  final $Res Function(LocalVaultLocation) _then;

/// Create a copy of VaultLocation
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? path = null,Object? bookmark = freezed,}) {
  return _then(LocalVaultLocation(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,bookmark: freezed == bookmark ? _self.bookmark : bookmark // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class RemoteVaultLocation implements VaultLocation {
  const RemoteVaultLocation({required this.kind, @JsonKey(fromJson: _settingsFromJson) final  Map<String, dynamic> settings = const {}, final  List<String> secretNames = const [], final  String? $type}): _settings = settings,_secretNames = secretNames,$type = $type ?? 'remote';
  factory RemoteVaultLocation.fromJson(Map<String, dynamic> json) => _$RemoteVaultLocationFromJson(json);

 final  String kind;
 final  Map<String, dynamic> _settings;
@JsonKey(fromJson: _settingsFromJson) Map<String, dynamic> get settings {
  if (_settings is EqualUnmodifiableMapView) return _settings;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_settings);
}

 final  List<String> _secretNames;
@JsonKey() List<String> get secretNames {
  if (_secretNames is EqualUnmodifiableListView) return _secretNames;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_secretNames);
}


@JsonKey(name: 'type')
final String $type;


/// Create a copy of VaultLocation
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RemoteVaultLocationCopyWith<RemoteVaultLocation> get copyWith => _$RemoteVaultLocationCopyWithImpl<RemoteVaultLocation>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RemoteVaultLocationToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RemoteVaultLocation&&(identical(other.kind, kind) || other.kind == kind)&&const DeepCollectionEquality().equals(other._settings, _settings)&&const DeepCollectionEquality().equals(other._secretNames, _secretNames));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,kind,const DeepCollectionEquality().hash(_settings),const DeepCollectionEquality().hash(_secretNames));

@override
String toString() {
  return 'VaultLocation.remote(kind: $kind, settings: $settings, secretNames: $secretNames)';
}


}

/// @nodoc
abstract mixin class $RemoteVaultLocationCopyWith<$Res> implements $VaultLocationCopyWith<$Res> {
  factory $RemoteVaultLocationCopyWith(RemoteVaultLocation value, $Res Function(RemoteVaultLocation) _then) = _$RemoteVaultLocationCopyWithImpl;
@useResult
$Res call({
 String kind,@JsonKey(fromJson: _settingsFromJson) Map<String, dynamic> settings, List<String> secretNames
});




}
/// @nodoc
class _$RemoteVaultLocationCopyWithImpl<$Res>
    implements $RemoteVaultLocationCopyWith<$Res> {
  _$RemoteVaultLocationCopyWithImpl(this._self, this._then);

  final RemoteVaultLocation _self;
  final $Res Function(RemoteVaultLocation) _then;

/// Create a copy of VaultLocation
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? kind = null,Object? settings = null,Object? secretNames = null,}) {
  return _then(RemoteVaultLocation(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,settings: null == settings ? _self._settings : settings // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,secretNames: null == secretNames ? _self._secretNames : secretNames // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

// dart format on
