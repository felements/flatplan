import 'package:freezed_annotation/freezed_annotation.dart';

import 'vault.dart';

part 'vault_registry.freezed.dart';
part 'vault_registry.g.dart';

/// The contents of `vaults.json`: every known vault and which one is open.
@freezed
sealed class VaultRegistry with _$VaultRegistry {
  const VaultRegistry._();

  const factory VaultRegistry({
    @Default(1) int version,
    String? lastSelectedVaultId,
    @Default([]) List<Vault> vaults,

    /// Set at runtime when the registry file was corrupt and moved aside.
    /// Never written to disk.
    @JsonKey(includeFromJson: false, includeToJson: false)
    String? brokenRegistryFile,
  }) = _VaultRegistry;

  factory VaultRegistry.fromJson(Map<String, dynamic> json) =>
      _$VaultRegistryFromJson(json);

  Vault? byId(String id) => vaults.where((v) => v.id == id).firstOrNull;

  /// The vault to open: the last selected one, or the first when that id
  /// no longer exists. Null only for an empty registry.
  Vault? get selected {
    final id = lastSelectedVaultId;
    if (id != null) {
      final match = byId(id);
      if (match != null) return match;
    }
    return vaults.firstOrNull;
  }
}
