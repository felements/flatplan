import 'package:flatplan/src/models/models.dart';
import 'package:flatplan/src/providers/vaults_provider.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// A [Vaults] notifier over a fixed registry that records mutations
/// instead of touching disk.
class FakeVaults extends Vaults {
  FakeVaults(this.registry);

  VaultRegistry registry;
  final List<String> selected = [];
  final List<Vault> added = [];
  final List<Vault> updated = [];
  final List<String> removed = [];

  @override
  Future<VaultRegistry> build() async => registry;

  @override
  Future<void> select(String id) async {
    selected.add(id);
    registry = registry.copyWith(lastSelectedVaultId: id);
    state = AsyncData(registry);
  }

  @override
  Future<void> add(Vault vault) async {
    added.add(vault);
    registry = registry.copyWith(
      vaults: [...registry.vaults, vault],
      lastSelectedVaultId: vault.id,
    );
    state = AsyncData(registry);
  }

  @override
  Future<void> updateVault(Vault vault) async {
    updated.add(vault);
    registry = registry.copyWith(
      vaults: [for (final v in registry.vaults) v.id == vault.id ? vault : v],
    );
    state = AsyncData(registry);
  }

  @override
  Future<void> remove(String id) async {
    removed.add(id);
    registry = registry.copyWith(
      vaults: registry.vaults.where((v) => v.id != id).toList(),
    );
    state = AsyncData(registry);
  }

  @override
  void dismissBrokenRegistryNotice() {
    registry = registry.copyWith(brokenRegistryFile: null);
    state = AsyncData(registry);
  }
}
