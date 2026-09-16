import 'dart:io';

import 'package:flatplan/src/models/models.dart';
import 'package:flatplan/src/providers/app_paths_provider.dart';
import 'package:flatplan/src/providers/vaults_provider.dart';
import 'package:flatplan/src/storage/app_paths.dart';
import 'package:flatplan/src/storage/vault_registry_service.dart';
import 'package:flatplan/src/storage/vault_secrets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;
  late AppPaths paths;
  late MemoryVaultSecrets secrets;
  late ProviderContainer container;
  var ids = 0;

  Vault vault(String id, {VaultLocation? location}) => Vault(
    id: id,
    name: 'Vault $id',
    location: location ?? VaultLocation.local(path: '/tmp/$id'),
    createdAt: DateTime.utc(2026, 1, 1),
  );

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('flatplan_vaults_');
    paths = AppPaths(appSupportDir: tempDir.path);
    secrets = MemoryVaultSecrets();
    ids = 0;
    container = ProviderContainer(
      overrides: [
        appPathsProvider.overrideWith((ref) async => paths),
        vaultSecretsProvider.overrideWith((ref) => secrets),
        vaultRegistryServiceProvider.overrideWith(
          (ref) async => VaultRegistryService(
            paths: paths,
            readLegacy: () async => null,
            clearLegacy: () async {},
            newId: () => 'id-${++ids}',
          ),
        ),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('build creates the default vault on first launch', () async {
    final registry = await container.read(vaultsProvider.future);

    expect(registry.vaults.single.name, 'My budget');
    expect(registry.selected!.id, 'id-1');
  });

  test('add appends, selects, and persists', () async {
    await container.read(vaultsProvider.future);

    await container.read(vaultsProvider.notifier).add(vault('b'));

    final registry = await container.read(vaultsProvider.future);
    expect(registry.vaults.map((v) => v.id), ['id-1', 'b']);
    expect(registry.selected!.id, 'b');
    expect(File(paths.registryFile).readAsStringSync(), contains('"b"'));
  });

  test('select changes the selected vault and ignores unknown ids', () async {
    await container.read(vaultsProvider.future);
    await container.read(vaultsProvider.notifier).add(vault('b'));

    await container.read(vaultsProvider.notifier).select('id-1');
    expect((await container.read(vaultsProvider.future)).selected!.id, 'id-1');

    await container.read(vaultsProvider.notifier).select('nope');
    expect((await container.read(vaultsProvider.future)).selected!.id, 'id-1');
  });

  test('update replaces a vault by id', () async {
    await container.read(vaultsProvider.future);

    await container
        .read(vaultsProvider.notifier)
        .updateVault(vault('id-1').copyWith(name: 'Renamed'));

    expect((await container.read(vaultsProvider.future)).vaults.single.name, 'Renamed');
  });

  test('remove forgets the vault, its secrets and its private area only',
      () async {
    await container.read(vaultsProvider.future);
    final remote = vault(
      'r',
      location: const VaultLocation.remote(kind: 'x', secretNames: ['token']),
    );
    await container.read(vaultsProvider.notifier).add(remote);
    await secrets.write('r', 'token', 't');
    final area = Directory(paths.mirrorFor('r'))..createSync(recursive: true);
    File(p.join(area.path, 'a.yaml')).writeAsStringSync('x');
    final userFolder = Directory(p.join(tempDir.path, 'user'))..createSync();
    await container.read(vaultsProvider.notifier).updateVault(
      vault('id-1', location: VaultLocation.local(path: userFolder.path)),
    );

    await container.read(vaultsProvider.notifier).remove('r');

    final registry = await container.read(vaultsProvider.future);
    expect(registry.vaults.map((v) => v.id), ['id-1']);
    expect(registry.selected!.id, 'id-1');
    expect(await secrets.read('r', 'token'), isNull);
    expect(Directory(paths.privateAreaFor('r')).existsSync(), isFalse);
    expect(userFolder.existsSync(), isTrue);
  });

  test('removing a local vault never deletes its files, even inside the '
      'private area', () async {
    await container.read(vaultsProvider.future);
    final mirrorPath = paths.mirrorFor('local-in-area');
    Directory(mirrorPath).createSync(recursive: true);
    final periodFile = File(p.join(mirrorPath, '2026-01.yaml'))
      ..writeAsStringSync('start_date: 2026-01-01');
    await container.read(vaultsProvider.notifier).add(
      vault('local-in-area', location: VaultLocation.local(path: mirrorPath)),
    );

    await container.read(vaultsProvider.notifier).remove('local-in-area');

    final registry = await container.read(vaultsProvider.future);
    expect(registry.vaults.map((v) => v.id), ['id-1']);
    expect(periodFile.existsSync(), isTrue);
    expect(periodFile.readAsStringSync(), 'start_date: 2026-01-01');
    expect(Directory(paths.privateAreaFor('local-in-area')).existsSync(), isTrue);
  });

  test('removing the selected vault selects the first remaining one',
      () async {
    await container.read(vaultsProvider.future);
    await container.read(vaultsProvider.notifier).add(vault('b'));
    await container.read(vaultsProvider.notifier).add(vault('c'));

    await container.read(vaultsProvider.notifier).remove('c');

    expect((await container.read(vaultsProvider.future)).selected!.id, 'id-1');
  });

  test('the last vault cannot be removed', () async {
    await container.read(vaultsProvider.future);

    expect(
      () => container.read(vaultsProvider.notifier).remove('id-1'),
      throwsStateError,
    );
  });

  test('removing an unknown vault is a no-op, even with one vault left',
      () async {
    await container.read(vaultsProvider.future);

    await container.read(vaultsProvider.notifier).remove('unknown');

    final registry = await container.read(vaultsProvider.future);
    expect(registry.vaults.map((v) => v.id), ['id-1']);
    expect(registry.selected!.id, 'id-1');
  });

  test('dismissBrokenRegistryNotice clears the notice', () async {
    File(paths.registryFile).writeAsStringSync('{ nope');
    final registry = await container.read(vaultsProvider.future);
    expect(registry.brokenRegistryFile, isNotNull);

    container.read(vaultsProvider.notifier).dismissBrokenRegistryNotice();

    expect((await container.read(vaultsProvider.future)).brokenRegistryFile, isNull);
  });
}
