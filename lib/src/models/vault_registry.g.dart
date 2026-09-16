// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vault_registry.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_VaultRegistry _$VaultRegistryFromJson(Map<String, dynamic> json) =>
    _VaultRegistry(
      version: (json['version'] as num?)?.toInt() ?? 1,
      lastSelectedVaultId: json['last_selected_vault_id'] as String?,
      vaults:
          (json['vaults'] as List<dynamic>?)
              ?.map((e) => Vault.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$VaultRegistryToJson(_VaultRegistry instance) =>
    <String, dynamic>{
      'version': instance.version,
      'last_selected_vault_id': instance.lastSelectedVaultId,
      'vaults': instance.vaults.map((e) => e.toJson()).toList(),
    };
