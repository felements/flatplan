import 'package:flatplan/src/storage/secure_vault_secrets.dart';
import 'package:flatplan/src/storage/vault_secrets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'secrets_contract.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  runSecretsContract('MemoryVaultSecrets', () async => MemoryVaultSecrets());
  runSecretsContract('SecureVaultSecrets', () async {
    FlutterSecureStorage.setMockInitialValues({});
    return SecureVaultSecrets();
  });

  test('uses the classic macOS keychain so no signing entitlement is needed', () {
    // The data-protection keychain needs the keychain-access-groups
    // entitlement, which cannot be ad-hoc signed; the login keychain works
    // with the plain development build.
    final options = SecureVaultSecrets().storage.mOptions as MacOsOptions;
    expect(options.usesDataProtectionKeychain, isFalse);
  });
}
