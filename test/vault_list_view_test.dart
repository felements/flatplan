import 'package:flatplan/src/models/models.dart';
import 'package:flatplan/src/providers/open_vault_provider.dart';
import 'package:flatplan/src/providers/vaults_provider.dart';
import 'package:flatplan/src/storage/vault_resolver.dart';
import 'package:flatplan/src/storage/vault_workspace.dart';
import 'package:flatplan/src/views/vault_kinds.dart';
import 'package:flatplan/src/views/vault_list_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'support/fake_vaults.dart';

void main() {
  final created = DateTime.utc(2026, 1, 1);
  final home = Vault(
    id: 'home',
    name: 'Home',
    location: const VaultLocation.local(path: '/Users/me/budget'),
    createdAt: created,
  );
  final future = Vault(
    id: 'f',
    name: 'Future',
    location: const VaultLocation.remote(kind: 'teleport'),
    createdAt: created,
  );

  late FakeVaults fakeVaults;

  Widget app(List<Vault> vaults, {String? accessError}) {
    fakeVaults = FakeVaults(
      VaultRegistry(lastSelectedVaultId: vaults.first.id, vaults: vaults),
    );
    return ProviderScope(
      overrides: [
        vaultsProvider.overrideWith(() => fakeVaults),
        openVaultProvider.overrideWith(
          (ref) async => OpenVault(
            vault: vaults.first,
            workspace: accessError == null ? MemoryWorkspace() : null,
            accessError: accessError,
          ),
        ),
      ],
      child: const MaterialApp(home: VaultListView()),
    );
  }

  test('vaultKindFor describes local, and unknown remote kinds', () {
    expect(vaultKindFor(home).label, 'Local folder');
    expect(vaultKindFor(home).locationLine(home), '/Users/me/budget');
    expect(vaultKindFor(future).label, 'Unsupported (teleport)');
  });

  Vault gitLab(String? expiresAt) => Vault(
    id: 'g',
    name: 'Budget',
    location: VaultLocation.remote(
      kind: 'gitlab',
      settings: {
        'base_url': 'https://gitlab.com',
        'project_id': 1,
        'project_path': 'me/budget',
        'branch': 'main',
        'folder': '',
        'token_expires_at': ?expiresAt,
      },
      secretNames: const ['token'],
    ),
    createdAt: created,
  );

  test('the GitLab kind reports the token expiry as a notice', () {
    final now = DateTime(2026, 9, 17, 10);
    VaultNotice? notice(String? at) => gitLabVaultKind.notice(gitLab(at), now);

    expect(notice(null), isNull);
    expect(notice('2026-09-22'), const VaultNotice('Token expires in 5 days', urgent: true));
    expect(notice('2026-09-18'), const VaultNotice('Token expires tomorrow', urgent: true));
    expect(notice('2026-09-17'), const VaultNotice('Token expires today', urgent: true));
    expect(notice('2026-09-01'), const VaultNotice('Token expired on 2026-09-01', urgent: true));
    expect(notice('2027-03-01'), const VaultNotice('Token expires on 2027-03-01', urgent: false));
    expect(localVaultKind.notice(home, now), isNull);
  });

  testWidgets('shows the token expiry notice on a GitLab vault card', (tester) async {
    await tester.pumpWidget(app([home, gitLab(DateTime.now().add(const Duration(days: 5)).toIso8601String().substring(0, 10))]));
    await tester.pumpAndSettle();

    expect(find.text('Token expires in 5 days'), findsOneWidget);
  });

  testWidgets('lists vaults with location, current chip and kind', (tester) async {
    await tester.pumpWidget(app([home, future]));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('/Users/me/budget'), findsOneWidget);
    expect(find.text('Current'), findsOneWidget);
    expect(find.text('Future'), findsOneWidget);
    expect(find.textContaining('not supported'), findsOneWidget);
    expect(find.text('New vault'), findsOneWidget);
  });

  testWidgets('shows a needs-attention chip when the current vault cannot open',
      (tester) async {
    await tester.pumpWidget(app([home, future], accessError: 'gone'));
    await tester.pumpAndSettle();

    expect(find.text('Needs attention'), findsOneWidget);
  });

  testWidgets('remove asks for confirmation and forgets the vault', (tester) async {
    await tester.pumpWidget(app([home, future]));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert_rounded).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(find.text('Remove "Future"?'), findsOneWidget);
    expect(find.textContaining('not deleted'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();

    expect(fakeVaults.removed, ['f']);
  });

  testWidgets('the last vault cannot be removed', (tester) async {
    await tester.pumpWidget(app([home]));
    await tester.pumpAndSettle();

    expect(find.text('The last vault cannot be removed.'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();

    final item = tester.widget<PopupMenuItem<String>>(
      find.widgetWithText(PopupMenuItem<String>, 'Remove'),
    );
    expect(item.enabled, isFalse);
  });

  testWidgets('shows an error snack bar when remove fails', (tester) async {
    final throwingVaults = _ThrowingVaults(
      VaultRegistry(lastSelectedVaultId: home.id, vaults: [home, future]),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vaultsProvider.overrideWith(() => throwingVaults),
          openVaultProvider.overrideWith(
            (ref) async =>
                OpenVault(vault: home, workspace: MemoryWorkspace()),
          ),
        ],
        child: const MaterialApp(home: VaultListView()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert_rounded).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not remove "Future"'), findsOneWidget);
  });
}

class _ThrowingVaults extends FakeVaults {
  _ThrowingVaults(super.registry);

  @override
  Future<void> remove(String id) async =>
      throw StateError('disk is read-only');
}
