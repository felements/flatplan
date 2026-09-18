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
    location: const VaultLocation.local(path: '/home'),
    createdAt: DateTime.utc(2026, 1, 1),
  );

  testWidgets('empty state opens the first-period dialog directly', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vaultsProvider.overrideWith(
            () => FakeVaults(
              VaultRegistry(lastSelectedVaultId: 'v', vaults: [vault]),
            ),
          ),
          openVaultProvider.overrideWith(
            (ref) async =>
                OpenVault(vault: vault, workspace: MemoryWorkspace()),
          ),
          periodRepositoryProvider.overrideWith(
            (ref) => PeriodRepository(workspace: MemoryWorkspace()),
          ),
        ],
        child: const MaterialApp(home: DashboardView()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Go to Settings to Generate Period'), findsNothing);
    await tester.tap(find.text('Create first period'));
    await tester.pumpAndSettle();

    expect(find.text('Create First Period'), findsOneWidget);
  });
}
