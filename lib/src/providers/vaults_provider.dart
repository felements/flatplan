import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/models.dart';
import '../storage/vault_registry_service.dart';
import '../storage/vault_secrets.dart';
import 'app_paths_provider.dart';

part 'vaults_provider.g.dart';

@Riverpod(keepAlive: true)
Future<VaultRegistryService> vaultRegistryService(Ref ref) async {
  final paths = await ref.watch(appPathsProvider.future);
  return VaultRegistryService.withSharedPreferences(paths);
}

/// Secret storage for remote vaults. In-memory until the first remote
/// provider brings the keychain implementation.
@Riverpod(keepAlive: true)
VaultSecrets vaultSecrets(Ref ref) => MemoryVaultSecrets();

/// The vault registry: every known vault and which one is selected.
@Riverpod(keepAlive: true)
class Vaults extends _$Vaults {
  @override
  Future<VaultRegistry> build() async {
    final service = await ref.watch(vaultRegistryServiceProvider.future);
    return service.loadOrCreate();
  }

  /// Makes [id] the open vault. Unknown ids are ignored.
  Future<void> select(String id) async {
    final registry = await future;
    if (registry.byId(id) == null || registry.selected?.id == id) return;
    await _save(registry.copyWith(lastSelectedVaultId: id));
  }

  /// Appends [vault] and selects it.
  Future<void> add(Vault vault) async {
    final registry = await future;
    await _save(
      registry.copyWith(
        vaults: [...registry.vaults, vault],
        lastSelectedVaultId: vault.id,
      ),
    );
  }

  /// Replaces the vault with the same id. Named `updateVault` because
  /// Riverpod's `AsyncNotifier.update` already owns the name `update`.
  Future<void> updateVault(Vault vault) async {
    final registry = await future;
    await _save(
      registry.copyWith(
        vaults: [
          for (final v in registry.vaults) v.id == vault.id ? vault : v,
        ],
      ),
    );
  }

  /// Forgets [id]: deletes its secrets and its app-private area, never the
  /// user's own files. Throws [StateError] for the last vault.
  Future<void> remove(String id) async {
    final registry = await future;
    if (registry.vaults.length <= 1) {
      throw StateError('The last vault cannot be removed.');
    }
    final vault = registry.byId(id);
    if (vault == null) return;

    if (vault.location case RemoteVaultLocation(:final secretNames)) {
      await ref.read(vaultSecretsProvider).deleteAll(id, secretNames);
    }
    final paths = await ref.read(appPathsProvider.future);
    final area = Directory(paths.privateAreaFor(id));
    if (await area.exists()) await area.delete(recursive: true);

    final remaining = registry.vaults.where((v) => v.id != id).toList();
    final selectedId = registry.selected?.id == id
        ? remaining.first.id
        : registry.lastSelectedVaultId;
    await _save(
      registry.copyWith(vaults: remaining, lastSelectedVaultId: selectedId),
    );
  }

  void dismissBrokenRegistryNotice() {
    final registry = state.value;
    if (registry == null) return;
    state = AsyncData(registry.copyWith(brokenRegistryFile: null));
  }

  Future<void> _save(VaultRegistry registry) async {
    final service = await ref.read(vaultRegistryServiceProvider.future);
    await service.save(registry);
    state = AsyncData(registry);
  }
}
