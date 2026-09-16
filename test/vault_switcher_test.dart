import 'package:flatplan/src/components/vault_switcher.dart';
import 'package:flatplan/src/models/models.dart';
import 'package:flatplan/src/providers/open_vault_provider.dart';
import 'package:flatplan/src/providers/vaults_provider.dart';
import 'package:flatplan/src/storage/vault_resolver.dart';
import 'package:flatplan/src/storage/vault_workspace.dart';
import 'package:flatplan/src/sync/sync_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'support/fake_vaults.dart';

void main() {
  final created = DateTime.utc(2026, 1, 1);
  final home = Vault(
    id: 'home',
    name: 'Home',
    location: const VaultLocation.local(path: '/home'),
    createdAt: created,
  );
  final work = Vault(
    id: 'work',
    name: 'Work',
    location: const VaultLocation.remote(kind: 'gitlab'),
    createdAt: created,
  );

  late FakeVaults fakeVaults;
  var manageTaps = 0;

  Widget app({
    required Vault selected,
    SyncStatus? status,
    String? accessError,
  }) {
    fakeVaults = FakeVaults(
      VaultRegistry(lastSelectedVaultId: selected.id, vaults: [home, work]),
    );
    return ProviderScope(
      overrides: [
        vaultsProvider.overrideWith(() => fakeVaults),
        openVaultProvider.overrideWith(
          (ref) async => OpenVault(
            vault: selected,
            workspace: accessError == null ? MemoryWorkspace() : null,
            accessError: accessError,
          ),
        ),
        currentSyncStatusProvider.overrideWith(() => _FixedStatus(status)),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 220,
            child: VaultSwitcher(onManage: () => manageTaps++),
          ),
        ),
      ),
    );
  }

  setUp(() => manageTaps = 0);

  testWidgets('shows the selected vault name', (tester) async {
    await tester.pumpWidget(app(selected: home));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.byIcon(Icons.unfold_more_rounded), findsOneWidget);
  });

  testWidgets('shows the sync status line for a remote vault', (tester) async {
    await tester.pumpWidget(app(
      selected: work,
      status: const SyncStatus(state: SyncState.idle, dirtyCount: 3),
    ));
    await tester.pumpAndSettle();

    expect(find.text('3 changes pending'), findsOneWidget);
  });

  testWidgets('shows a needs-attention line when the vault cannot open',
      (tester) async {
    await tester.pumpWidget(app(selected: home, accessError: 'nope'));
    await tester.pumpAndSettle();

    expect(find.text('Needs attention'), findsOneWidget);
  });

  testWidgets('menu lists every vault, checks the current one, and selects',
      (tester) async {
    await tester.pumpWidget(app(selected: home));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();

    expect(find.text('Work'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.text('Manage vaults…'), findsOneWidget);

    await tester.tap(find.text('Work'));
    await tester.pumpAndSettle();

    expect(fakeVaults.selected, ['work']);
  });

  testWidgets('Manage vaults… calls onManage', (tester) async {
    await tester.pumpWidget(app(selected: home));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manage vaults…'));
    await tester.pumpAndSettle();

    expect(manageTaps, 1);
    expect(fakeVaults.selected, isEmpty);
  });
}

class _FixedStatus extends CurrentSyncStatus {
  _FixedStatus(this.fixed);
  final SyncStatus? fixed;

  @override
  SyncStatus? build() => fixed;
}
