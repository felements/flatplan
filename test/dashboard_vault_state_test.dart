import 'package:flatplan/src/models/models.dart';
import 'package:flatplan/src/providers/open_vault_provider.dart';
import 'package:flatplan/src/providers/repository_provider.dart';
import 'package:flatplan/src/providers/vaults_provider.dart';
import 'package:flatplan/src/storage/period_repository.dart';
import 'package:flatplan/src/storage/vault_resolver.dart';
import 'package:flatplan/src/storage/vault_workspace.dart';
import 'package:flatplan/src/sync/sync_status.dart';
import 'package:flatplan/src/views/dashboard_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'support/fake_vaults.dart';

void main() {
  final vault = Vault(
    id: 'v',
    name: 'Home',
    location: const VaultLocation.local(path: '/gone'),
    createdAt: DateTime.utc(2026, 1, 1),
  );

  testWidgets('an unavailable vault shows its error and a settings button',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vaultsProvider.overrideWith(
            () => FakeVaults(VaultRegistry(lastSelectedVaultId: 'v', vaults: [vault])),
          ),
          openVaultProvider.overrideWith(
            (ref) async => OpenVault(vault: vault, accessError: 'Folder is gone.'),
          ),
          periodRepositoryProvider.overrideWith(
            (ref) => throw const VaultUnavailable('Folder is gone.'),
          ),
        ],
        child: const MaterialApp(home: DashboardView()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Vault unavailable'), findsOneWidget);
    expect(find.text('Folder is gone.'), findsOneWidget);
    expect(find.text('Open vault settings'), findsOneWidget);
  });

  testWidgets('a broken registry shows a dismissible banner', (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final fake = FakeVaults(
      VaultRegistry(
        lastSelectedVaultId: 'v',
        vaults: [vault],
        brokenRegistryFile: '/support/vaults.json.broken',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vaultsProvider.overrideWith(() => fake),
          openVaultProvider.overrideWith(
            (ref) async => OpenVault(vault: vault, workspace: MemoryWorkspace()),
          ),
          periodRepositoryProvider.overrideWith(
            (ref) => PeriodRepository(workspace: MemoryWorkspace()),
          ),
        ],
        child: const MaterialApp(home: DashboardView()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('vaults.json.broken'), findsOneWidget);

    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();

    expect(find.textContaining('vaults.json.broken'), findsNothing);
  });

  testWidgets('a sync failure that needs attention shows a bar leading to the vault settings',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final remote = Vault(
      id: 'g',
      name: 'Budget',
      location: const VaultLocation.remote(kind: 'gitlab'),
      createdAt: DateTime.utc(2026, 1, 1),
    );
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const DashboardView()),
        GoRoute(
          path: '/settings/vaults/:id/edit',
          builder: (_, state) => Text('EDIT ${state.pathParameters['id']}'),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vaultsProvider.overrideWith(
            () => FakeVaults(VaultRegistry(lastSelectedVaultId: 'g', vaults: [remote])),
          ),
          openVaultProvider.overrideWith(
            (ref) async => OpenVault(vault: remote, workspace: MemoryWorkspace()),
          ),
          periodRepositoryProvider.overrideWith(
            (ref) async => PeriodRepository(workspace: MemoryWorkspace()),
          ),
          currentSyncStatusProvider.overrideWith(
            () => _FixedStatus(
              const SyncStatus(
                state: SyncState.error,
                dirtyCount: 2,
                lastError: 'GitLab rejected the token: Token is expired. Replace it in the vault settings.',
                needsAttention: true,
              ),
            ),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Token is expired'), findsOneWidget);
    expect(find.textContaining('2 changes'), findsOneWidget);

    await tester.tap(find.text('Open vault settings'));
    await tester.pumpAndSettle();

    expect(find.text('EDIT g'), findsOneWidget);
  });

  testWidgets('an ordinary sync error shows no attention bar', (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final remote = Vault(
      id: 'g',
      name: 'Budget',
      location: const VaultLocation.remote(kind: 'gitlab'),
      createdAt: DateTime.utc(2026, 1, 1),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vaultsProvider.overrideWith(
            () => FakeVaults(VaultRegistry(lastSelectedVaultId: 'g', vaults: [remote])),
          ),
          openVaultProvider.overrideWith(
            (ref) async => OpenVault(vault: remote, workspace: MemoryWorkspace()),
          ),
          periodRepositoryProvider.overrideWith(
            (ref) async => PeriodRepository(workspace: MemoryWorkspace()),
          ),
          currentSyncStatusProvider.overrideWith(
            () => _FixedStatus(
              const SyncStatus(state: SyncState.error, dirtyCount: 0, lastError: 'boom'),
            ),
          ),
        ],
        child: const MaterialApp(home: DashboardView()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Open vault settings'), findsNothing);
  });
}

class _FixedStatus extends CurrentSyncStatus {
  _FixedStatus(this.fixed);
  final SyncStatus? fixed;

  @override
  SyncStatus? build() => fixed;
}
