import 'package:flatplan/src/models/models.dart';
import 'package:flatplan/src/providers/open_vault_provider.dart';
import 'package:flatplan/src/providers/repository_provider.dart';
import 'package:flatplan/src/providers/vaults_provider.dart';
import 'package:flatplan/src/storage/period_repository.dart';
import 'package:flatplan/src/storage/vault_resolver.dart';
import 'package:flatplan/src/storage/vault_workspace.dart';
import 'package:flatplan/src/views/dashboard_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
