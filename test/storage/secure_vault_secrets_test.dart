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
}
