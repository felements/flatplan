import 'dart:convert';

import 'package:flatplan/src/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final created = DateTime.utc(2026, 9, 16, 10, 0);

  test('local vault serialises snake_case with a type discriminator', () {
    final vault = Vault(
      id: 'v1',
      name: 'My budget',
      location: const VaultLocation.local(path: '/tmp/periods', bookmark: 'b'),
      createdAt: created,
    );

    final json = vault.toJson();

    expect(json['created_at'], created.toIso8601String());
    expect(json['location'], {
      'type': 'local',
      'path': '/tmp/periods',
      'bookmark': 'b',
    });
    expect(Vault.fromJson(jsonDecode(jsonEncode(json))), vault);
  });

  test('remote vault keeps settings and secret names', () {
    final vault = Vault(
      id: 'v2',
      name: 'Work',
      location: const VaultLocation.remote(
        kind: 'gitlab',
        settings: {'repo': 'group/budget', 'branch': 'main'},
        secretNames: ['token'],
      ),
      createdAt: created,
    );

    final json = vault.toJson();

    expect(json['location']['type'], 'remote');
    expect(json['location']['secret_names'], ['token']);
    expect(Vault.fromJson(jsonDecode(jsonEncode(json))), vault);
  });

  test('an unknown remote kind survives a round trip', () {
    final json = {
      'id': 'v3',
      'name': 'Future',
      'created_at': created.toIso8601String(),
      'location': {'type': 'remote', 'kind': 'teleport', 'settings': {}},
    };

    final vault = Vault.fromJson(json);

    expect((vault.location as RemoteVaultLocation).kind, 'teleport');
    expect(jsonDecode(jsonEncode(vault.toJson()))['location']['kind'], 'teleport');
  });

  group('VaultRegistry', () {
    final a = Vault(
      id: 'a',
      name: 'A',
      location: const VaultLocation.local(path: '/a'),
      createdAt: created,
    );
    final b = Vault(
      id: 'b',
      name: 'B',
      location: const VaultLocation.local(path: '/b'),
      createdAt: created,
    );

    test('selected returns the last selected vault', () {
      final registry = VaultRegistry(lastSelectedVaultId: 'b', vaults: [a, b]);
      expect(registry.selected, b);
    });

    test('selected falls back to the first vault when the id is stale', () {
      final registry = VaultRegistry(lastSelectedVaultId: 'gone', vaults: [a, b]);
      expect(registry.selected, a);
    });

    test('selected is null for an empty registry', () {
      expect(const VaultRegistry().selected, isNull);
    });

    test('brokenRegistryFile is not serialised', () {
      final registry = VaultRegistry(vaults: [a], brokenRegistryFile: '/x');
      expect(registry.toJson().containsKey('broken_registry_file'), isFalse);
      expect(registry.toJson()['version'], 1);
    });
  });
}
