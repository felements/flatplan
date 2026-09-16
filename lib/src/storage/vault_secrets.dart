/// Secret values (tokens, access keys) for remote vaults.
///
/// The keychain-backed implementation ships with the first remote provider.
/// Keys are `vault.<vaultId>.<name>`.
abstract interface class VaultSecrets {
  Future<String?> read(String vaultId, String name);
  Future<void> write(String vaultId, String name, String value);
  Future<void> deleteAll(String vaultId, List<String> names);
}

String vaultSecretKey(String vaultId, String name) => 'vault.$vaultId.$name';

/// In-memory secrets for tests and for builds without a keychain plugin.
class MemoryVaultSecrets implements VaultSecrets {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String vaultId, String name) async =>
      values[vaultSecretKey(vaultId, name)];

  @override
  Future<void> write(String vaultId, String name, String value) async {
    values[vaultSecretKey(vaultId, name)] = value;
  }

  @override
  Future<void> deleteAll(String vaultId, List<String> names) async {
    for (final name in names) {
      values.remove(vaultSecretKey(vaultId, name));
    }
  }
}
