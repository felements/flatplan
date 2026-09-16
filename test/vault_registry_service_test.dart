import 'dart:convert';
import 'dart:io';

import 'package:flatplan/src/models/models.dart';
import 'package:flatplan/src/storage/app_paths.dart';
import 'package:flatplan/src/storage/vault_registry_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;
  late AppPaths paths;
  LegacyStorageSettings? legacy;
  var legacyCleared = 0;

  VaultRegistryService service() => VaultRegistryService(
    paths: paths,
    readLegacy: () async => legacy,
    clearLegacy: () async => legacyCleared++,
    newId: () => 'fixed-id',
  );

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('flatplan_registry_');
    paths = AppPaths(appSupportDir: tempDir.path);
    legacy = null;
    legacyCleared = 0;
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('AppPaths', () {
    test('derives every location from the app support directory', () {
      expect(paths.registryFile, p.join(tempDir.path, 'vaults.json'));
      expect(paths.defaultPeriodsDir, p.join(tempDir.path, 'periods'));
      expect(paths.vaultsDir, p.join(tempDir.path, 'vaults'));
      expect(paths.privateAreaFor('v1'), p.join(tempDir.path, 'vaults', 'v1'));
      expect(paths.mirrorFor('v1'), p.join(tempDir.path, 'vaults', 'v1', 'files'));
      expect(paths.journalFor('v1'), p.join(tempDir.path, 'vaults', 'v1', 'sync.json'));
    });
  });

  group('loadOrCreate', () {
    test('creates a default local vault at the old periods folder', () async {
      final registry = await service().loadOrCreate();

      expect(registry.vaults.length, 1);
      final vault = registry.vaults.single;
      expect(vault.id, 'fixed-id');
      expect(vault.name, 'My budget');
      expect(vault.location, VaultLocation.local(path: paths.defaultPeriodsDir));
      expect(registry.lastSelectedVaultId, 'fixed-id');
      expect(File(paths.registryFile).existsSync(), isTrue);
      expect(legacyCleared, 1);
    });

    test('migrates a configured folder and bookmark from the old settings',
        () async {
      legacy = const LegacyStorageSettings(
        path: '/Users/me/Documents/budget',
        bookmark: 'bm',
      );

      final registry = await service().loadOrCreate();

      final vault = registry.vaults.single;
      expect(vault.name, 'budget');
      expect(
        vault.location,
        const VaultLocation.local(path: '/Users/me/Documents/budget', bookmark: 'bm'),
      );
      expect(legacyCleared, 1);
    });

    test('reads an existing registry without touching legacy settings',
        () async {
      final first = await service().loadOrCreate();
      legacy = const LegacyStorageSettings(path: '/elsewhere');

      final second = await service().loadOrCreate();

      expect(second, first);
      expect(legacyCleared, 1);
    });

    test('moves a corrupt registry aside and reports it', () async {
      File(paths.registryFile).writeAsStringSync('{ not json');

      final registry = await service().loadOrCreate();

      expect(registry.vaults.single.name, 'My budget');
      // Stamped, so a second corruption never overwrites the first copy.
      expect(
        registry.brokenRegistryFile,
        startsWith('${paths.registryFile}.broken-'),
      );
      expect(
        File(registry.brokenRegistryFile!).readAsStringSync(),
        '{ not json',
      );
      expect(jsonDecode(File(paths.registryFile).readAsStringSync())['version'], 1);
    });

    test('a registry with the wrong shape counts as corrupt', () async {
      File(paths.registryFile).writeAsStringSync('[1, 2, 3]');

      final registry = await service().loadOrCreate();

      expect(registry.brokenRegistryFile, isNotNull);
    });
  });

  group('save', () {
    test('writes snake_case json and leaves no temp file behind', () async {
      final registry = VaultRegistry(
        lastSelectedVaultId: 'a',
        vaults: [
          Vault(
            id: 'a',
            name: 'A',
            location: const VaultLocation.local(path: '/a'),
            createdAt: DateTime.utc(2026, 1, 1),
          ),
        ],
      );

      await service().save(registry);

      final json = jsonDecode(File(paths.registryFile).readAsStringSync());
      expect(json['last_selected_vault_id'], 'a');
      expect(json['vaults'][0]['location']['type'], 'local');
      expect(File('${paths.registryFile}.tmp').existsSync(), isFalse);
      expect(await service().loadOrCreate(), registry);
    });
  });
}
