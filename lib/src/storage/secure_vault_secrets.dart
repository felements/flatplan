import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'vault_secrets.dart';

/// [VaultSecrets] over the platform keychain or keystore. Keys are
/// `vault.<vaultId>.<name>`; nothing else in the app touches the plugin.
class SecureVaultSecrets implements VaultSecrets {
  final FlutterSecureStorage storage;

  /// On macOS the classic login keychain is used rather than the
  /// data-protection keychain: the latter needs the `keychain-access-groups`
  /// entitlement, which Xcode refuses to ad-hoc sign, so a plain development
  /// build could not run at all.
  SecureVaultSecrets([FlutterSecureStorage? storage])
    : storage =
          storage ??
          const FlutterSecureStorage(
            mOptions: MacOsOptions(usesDataProtectionKeychain: false),
          );

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
