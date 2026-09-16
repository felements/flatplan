import 'package:flatplan/src/storage/vault_secrets.dart';
import 'package:flutter_test/flutter_test.dart';

void runSecretsContract(String label, Future<VaultSecrets> Function() create) {
  group('$label contract', () {
    late VaultSecrets secrets;

    setUp(() async => secrets = await create());

    test('a missing secret reads as null', () async {
      expect(await secrets.read('v1', 'token'), isNull);
    });

    test('write then read round-trips per vault and name', () async {
      await secrets.write('v1', 'token', 'a');
      await secrets.write('v2', 'token', 'b');
      expect(await secrets.read('v1', 'token'), 'a');
      expect(await secrets.read('v2', 'token'), 'b');
      expect(await secrets.read('v1', 'other'), isNull);
    });

    test('overwrite replaces the value', () async {
      await secrets.write('v1', 'token', 'a');
      await secrets.write('v1', 'token', 'b');
      expect(await secrets.read('v1', 'token'), 'b');
    });

    test('deleteAll removes only the listed names of that vault', () async {
      await secrets.write('v1', 'token', 'a');
      await secrets.write('v1', 'other', 'o');
      await secrets.write('v2', 'token', 'b');
      await secrets.deleteAll('v1', ['token', 'missing']);
      expect(await secrets.read('v1', 'token'), isNull);
      expect(await secrets.read('v1', 'other'), 'o');
      expect(await secrets.read('v2', 'token'), 'b');
    });
  });
}
