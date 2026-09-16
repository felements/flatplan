import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'vault_secrets.dart';

/// [VaultSecrets] over the platform keychain or keystore. Keys are
/// `vault.<vaultId>.<name>`; nothing else in the app touches the plugin.
class SecureVaultSecrets implements VaultSecrets {
  final FlutterSecureStorage storage;

  SecureVaultSecrets([FlutterSecureStorage? storage])
    : storage = storage ?? const FlutterSecureStorage();

  @override
  Future<String?> read(String vaultId, String name) =>
      storage.read(key: vaultSecretKey(vaultId, name));

  @override
  Future<void> write(String vaultId, String name, String value) =>
      storage.write(key: vaultSecretKey(vaultId, name), value: value);

  @override
  Future<void> deleteAll(String vaultId, List<String> names) async {
    for (final name in names) {
      await storage.delete(key: vaultSecretKey(vaultId, name));
    }
  }
}
