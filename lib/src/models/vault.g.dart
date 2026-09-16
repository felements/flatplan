// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vault.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Vault _$VaultFromJson(Map<String, dynamic> json) => _Vault(
  id: json['id'] as String,
  name: json['name'] as String,
  location: VaultLocation.fromJson(json['location'] as Map<String, dynamic>),
  createdAt: DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$VaultToJson(_Vault instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'location': instance.location.toJson(),
  'created_at': instance.createdAt.toIso8601String(),
};

LocalVaultLocation _$LocalVaultLocationFromJson(Map<String, dynamic> json) =>
    LocalVaultLocation(
      path: json['path'] as String,
      bookmark: json['bookmark'] as String?,
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$LocalVaultLocationToJson(LocalVaultLocation instance) =>
    <String, dynamic>{
      'path': instance.path,
      'bookmark': instance.bookmark,
      'type': instance.$type,
    };

RemoteVaultLocation _$RemoteVaultLocationFromJson(Map<String, dynamic> json) =>
    RemoteVaultLocation(
      kind: json['kind'] as String,
      settings: json['settings'] == null
          ? const {}
          : _settingsFromJson(json['settings']),
      secretNames:
          (json['secret_names'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$RemoteVaultLocationToJson(
  RemoteVaultLocation instance,
) => <String, dynamic>{
  'kind': instance.kind,
  'settings': instance.settings,
  'secret_names': instance.secretNames,
  'type': instance.$type,
};
