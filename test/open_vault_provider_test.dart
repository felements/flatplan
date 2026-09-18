import 'dart:convert';
import 'dart:io';

import 'package:flatplan/src/models/models.dart';
import 'package:flatplan/src/providers/all_periods_provider.dart';
import 'package:flatplan/src/providers/app_paths_provider.dart';
import 'package:flatplan/src/providers/current_period_provider.dart';
import 'package:flatplan/src/providers/open_vault_provider.dart';
import 'package:flatplan/src/providers/period_notifier_provider.dart';
import 'package:flatplan/src/providers/repository_provider.dart';
import 'package:flatplan/src/providers/vaults_provider.dart';
import 'package:flatplan/src/storage/app_paths.dart';
import 'package:flatplan/src/storage/period_repository.dart';
import 'package:flatplan/src/storage/vault_registry_service.dart';
import 'package:flatplan/src/storage/vault_resolver.dart';
import 'package:flatplan/src/storage/vault_secrets.dart';
import 'package:flatplan/src/storage/vault_workspace.dart';
import 'package:flatplan/src/sync/remote_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:path/path.dart' as p;

import 'support/fake_vaults.dart';
import 'sync/in_memory_remote_store.dart';

void main() {
  late Directory tempDir;
  late AppPaths paths;
  late RemoteStoreRegistry stores;
  late InMemoryRemoteStore remote;
  late MemoryVaultSecrets secrets;
  late FakeVaults fakeVaults;
  late ProviderContainer container;
  final created = DateTime.utc(2026, 1, 1);

  Vault localVault(String id) => Vault(
    id: id,
    name: id,
    location: VaultLocation.local(path: p.join(tempDir.path, id)),
    createdAt: created,
  );

  Vault remoteVault() => Vault(
    id: 'r',
    name: 'Remote',
    location: const VaultLocation.remote(kind: 'memory'),
    createdAt: created,
  );

  ProviderContainer makeContainer(VaultRegistry registry) {
    fakeVaults = FakeVaults(registry);
    return ProviderContainer(
      overrides: [
        appPathsProvider.overrideWith((ref) async => paths),
        remoteStoreRegistryProvider.overrideWith((ref) => stores),
        vaultsProvider.overrideWith(() => fakeVaults),
        vaultResolverProvider.overrideWith(
          (ref) async => VaultResolver(
            paths: paths,
            remoteStores: stores,
            secrets: MemoryVaultSecrets(),
            useBookmarks: false,
            idleDelay: const Duration(milliseconds: 20),
            switchTimeout: const Duration(milliseconds: 200),
          ),
        ),
      ],
    );
  }

  /// Like [makeContainer] but with the real [Vaults] notifier over a seeded
  /// `vaults.json`, so `remove` runs its real cleanup.
  ProviderContainer makeContainerWithRealVaults(VaultRegistry registry) {
    File(paths.registryFile).parent.createSync(recursive: true);
    File(paths.registryFile).writeAsStringSync(jsonEncode(registry.toJson()));
    return ProviderContainer(
      overrides: [
        appPathsProvider.overrideWith((ref) async => paths),
        remoteStoreRegistryProvider.overrideWith((ref) => stores),
        vaultSecretsProvider.overrideWith((ref) => secrets),
        vaultRegistryServiceProvider.overrideWith(
          (ref) async => VaultRegistryService(
            paths: paths,
            readLegacy: () async => null,
            clearLegacy: () async {},
          ),
        ),
        vaultResolverProvider.overrideWith(
          (ref) async => VaultResolver(
            paths: paths,
            remoteStores: stores,
            secrets: secrets,
            useBookmarks: false,
            idleDelay: const Duration(milliseconds: 20),
            switchTimeout: const Duration(milliseconds: 200),
          ),
        ),
      ],
    );
  }

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('flatplan_open_');
    paths = AppPaths(appSupportDir: p.join(tempDir.path, 'support'));
    stores = RemoteStoreRegistry();
    secrets = MemoryVaultSecrets();
    remote = InMemoryRemoteStore();
    stores.register('memory', (location, secrets) async => remote);
    Directory(p.join(tempDir.path, 'a')).createSync();
    Directory(p.join(tempDir.path, 'b')).createSync();
  });

  tearDown(() {
    container.dispose();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('opens the selected vault and builds a repository over it', () async {
    container = makeContainer(
      VaultRegistry(lastSelectedVaultId: 'a', vaults: [localVault('a'), localVault('b')]),
    );

    final open = await container.read(openVaultProvider.future);
    final repo = await container.read(periodRepositoryProvider.future);

    expect(open.vault.id, 'a');
    expect(repo.workspace.displayPath, p.join(tempDir.path, 'a'));
  });

  test('selecting another vault re-opens and rebuilds the repository',
      () async {
    container = makeContainer(
      VaultRegistry(lastSelectedVaultId: 'a', vaults: [localVault('a'), localVault('b')]),
    );
    container.listen(periodRepositoryProvider, (_, _) {});
    await container.read(periodRepositoryProvider.future);

    await container.read(vaultsProvider.notifier).select('b');

    final repo = await container.read(periodRepositoryProvider.future);
    expect(repo.workspace.displayPath, p.join(tempDir.path, 'b'));
  });

  test('a vault with an access error makes the repository unavailable',
      () async {
    final missing = Vault(
      id: 'm',
      name: 'Missing',
      location: VaultLocation.local(path: p.join(tempDir.path, 'gone')),
      createdAt: created,
    );
    container = makeContainer(VaultRegistry(lastSelectedVaultId: 'm', vaults: [missing]));

    final open = await container.read(openVaultProvider.future);

    expect(open.accessError, isNotNull);
    await expectLater(
      container.read(periodRepositoryProvider.future),
      throwsA(isA<VaultUnavailable>().having((e) => e.message, 'message', open.accessError)),
    );
  });

  test('a remote vault pulls on open and publishes its status', () async {
    remote.seed('x.yaml', 'x');
    container = makeContainer(VaultRegistry(lastSelectedVaultId: 'r', vaults: [remoteVault()]));

    final open = await container.read(openVaultProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(await open.workspace!.readString('x.yaml'), 'x');
    expect(container.read(currentSyncStatusProvider), isNotNull);
    expect(container.read(currentSyncStatusProvider)!.lastPullAt, isNotNull);
  });

  test('periods pulled after a remote vault opens show up without a switch', () async {
    // Serialise a real period the way the repository writes it.
    final scratch = MemoryWorkspace();
    await PeriodRepository(workspace: scratch).savePeriod(
      Period(
        id: 'p1',
        name: 'September 2026',
        startDate: DateTime(2026, 9, 1),
        baseCurrency: 'EUR',
        lastModified: DateTime(2026, 9, 1),
      ),
    );
    final fileName = (await scratch.listFiles()).single;
    remote.seed(fileName, await scratch.readString(fileName));
    container = makeContainer(VaultRegistry(lastSelectedVaultId: 'r', vaults: [remoteVault()]));

    // The UI holds these alive from the first frame, before the pull lands.
    container.listen(allPeriodsProvider, (_, _) {});
    container.listen(currentPeriodProvider, (_, _) {});
    await container.read(openVaultProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final periods = await container.read(allPeriodsProvider.future);
    expect(periods.map((p) => p.id), ['p1']);
    expect((await container.read(currentPeriodProvider.future))?.id, 'p1');
  });

  test('switching away from a remote vault flushes its pending changes',
      () async {
    container = makeContainer(
      VaultRegistry(lastSelectedVaultId: 'r', vaults: [remoteVault(), localVault('a')]),
    );
    container.listen(openVaultProvider, (_, _) {});
    final open = await container.read(openVaultProvider.future);
    await open.workspace!.writeString('new.yaml', 'n');

    await container.read(vaultsProvider.notifier).select('a');
    await container.read(openVaultProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect((await remote.listTree()).keys, contains('new.yaml'));
  });

  test('switching to a local vault clears the sync status', () async {
    container = makeContainer(
      VaultRegistry(
        lastSelectedVaultId: 'r',
        vaults: [remoteVault(), localVault('a')],
      ),
    );
    container.listen(openVaultProvider, (_, _) {});
    await container.read(openVaultProvider.future);
    expect(container.read(currentSyncStatusProvider), isNotNull);

    await container.read(vaultsProvider.notifier).select('a');
    await container.read(openVaultProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(container.read(currentSyncStatusProvider), isNull);
  });

  test('a debounced save lands in the vault that was open when it was made',
      () async {
    container = makeContainer(
      VaultRegistry(
        lastSelectedVaultId: 'a',
        vaults: [localVault('a'), localVault('b')],
      ),
    );
    container.listen(periodRepositoryProvider, (_, _) {});
    final repo = await container.read(periodRepositoryProvider.future);
    await repo.savePeriod(
      Period(
        id: 'p1',
        name: 'September 2026',
        startDate: DateTime(2026, 9, 1),
        baseCurrency: 'EUR',
        lastModified: DateTime(2026, 9, 1),
        categories: [
          Category(
            id: 'c1',
            name: 'Groceries',
            type: CategoryType.optionalExpense,
            limit: 500,
          ),
        ],
      ),
    );

    // The notifier must stay alive across the switch, like the open screen.
    container.listen(periodProvider('p1'), (_, _) {});
    await container.read(periodProvider('p1').future);

    container.read(periodProvider('p1').notifier).addFactExpense(
      'c1',
      FactExpense(id: 'f1', amount: 42, timestamp: DateTime(2026, 9, 10)),
    );
    // Switch vaults inside the 500 ms debounce window.
    await container.read(vaultsProvider.notifier).select('b');
    await Future<void>.delayed(const Duration(milliseconds: 800));

    final inA = Directory(p.join(tempDir.path, 'a'))
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.yaml'))
        .toList();
    final inB = Directory(p.join(tempDir.path, 'b'))
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.yaml'))
        .toList();

    expect(inA, hasLength(1));
    expect(inA.single.readAsStringSync(), contains('f1'));
    expect(inB, isEmpty, reason: 'the edit belongs to the vault it was made in');
  });

  test('removing the open remote vault pushes its pending change first',
      () async {
    container = makeContainerWithRealVaults(
      VaultRegistry(
        lastSelectedVaultId: 'r',
        vaults: [remoteVault(), localVault('a')],
      ),
    );
    container.listen(openVaultProvider, (_, _) {});
    final open = await container.read(openVaultProvider.future);
    await open.workspace!.writeString('new.yaml', 'n');

    await container.read(vaultsProvider.notifier).remove('r');
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect((await remote.listTree()).keys, contains('new.yaml'));
    expect(Directory(paths.privateAreaFor('r')).existsSync(), isFalse);
  });
}
