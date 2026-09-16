import 'package:flatplan/src/models/models.dart';
import 'package:flatplan/src/providers/app_paths_provider.dart';
import 'package:flatplan/src/providers/open_vault_provider.dart';
import 'package:flatplan/src/providers/vaults_provider.dart';
import 'package:flatplan/src/storage/app_paths.dart';
import 'package:flatplan/src/storage/vault_resolver.dart';
import 'package:flatplan/src/storage/vault_secrets.dart';
import 'package:flatplan/src/sync/remote_store.dart';
import 'package:flatplan/src/views/vault_form_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'support/fake_vaults.dart';

void main() {
  const paths = AppPaths(appSupportDir: '/support');
  final created = DateTime.utc(2026, 1, 1);
  final home = Vault(
    id: 'home',
    name: 'Home',
    location: const VaultLocation.local(path: '/Users/me/budget'),
    createdAt: created,
  );

  late FakeVaults fakeVaults;

  Widget app(Widget child, {List<Vault>? vaults}) {
    fakeVaults = FakeVaults(
      VaultRegistry(lastSelectedVaultId: 'home', vaults: vaults ?? [home]),
    );
    return ProviderScope(
      overrides: [
        vaultsProvider.overrideWith(() => fakeVaults),
        appPathsProvider.overrideWith((ref) async => paths),
        vaultResolverProvider.overrideWith(
          (ref) async => VaultResolver(
            paths: paths,
            remoteStores: RemoteStoreRegistry(),
            secrets: MemoryVaultSecrets(),
            useBookmarks: false,
          ),
        ),
      ],
      child: MaterialApp(home: child),
    );
  }

  testWidgets(
    'on mobile the folder row is absent and the vault is app-private',
    (tester) async {
      await tester.pumpWidget(app(const LocalVaultForm(canPickFolder: false)));
      await tester.pumpAndSettle();

      expect(find.text('Choose folder…'), findsNothing);
      expect(find.textContaining('stored inside the app'), findsOneWidget);
    },
  );

  testWidgets('on desktop the folder row is present', (tester) async {
    await tester.pumpWidget(app(const LocalVaultForm(canPickFolder: true)));
    await tester.pumpAndSettle();

    expect(find.text('Choose folder…'), findsOneWidget);
  });

  testWidgets('saving requires a name', (tester) async {
    await tester.pumpWidget(app(const LocalVaultForm(canPickFolder: false)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create vault'));
    await tester.pumpAndSettle();

    expect(find.text('Give the vault a name.'), findsOneWidget);
    expect(fakeVaults.added, isEmpty);
  });

  testWidgets('creating without a folder puts the vault in the private area', (
    tester,
  ) async {
    await tester.pumpWidget(app(const LocalVaultForm(canPickFolder: true)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Travel');
    await tester.tap(find.text('Create vault'));
    await tester.pumpAndSettle();

    final added = fakeVaults.added.single;
    expect(added.name, 'Travel');
    expect(
      added.location,
      VaultLocation.local(path: paths.mirrorFor(added.id)),
    );
  });

  testWidgets('editing renames and keeps the folder', (tester) async {
    await tester.pumpWidget(
      app(LocalVaultForm(existing: home, canPickFolder: true)),
    );
    await tester.pumpAndSettle();

    expect(find.text('/Users/me/budget'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Household');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final updated = fakeVaults.updated.single;
    expect(updated.id, 'home');
    expect(updated.name, 'Household');
    expect(updated.location, home.location);
  });

  testWidgets('VaultFormView opens the local form directly for a new vault', (
    tester,
  ) async {
    await tester.pumpWidget(app(const VaultFormView()));
    await tester.pumpAndSettle();

    expect(find.text('New vault'), findsOneWidget);
    expect(find.byType(LocalVaultForm), findsOneWidget);
  });

  testWidgets('VaultFormView edits an existing vault by id', (tester) async {
    await tester.pumpWidget(app(const VaultFormView(vaultId: 'home')));
    await tester.pumpAndSettle();

    expect(find.text('Edit vault'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('VaultFormView explains an unsupported remote kind', (
    tester,
  ) async {
    final future = Vault(
      id: 'f',
      name: 'Future',
      location: const VaultLocation.remote(kind: 'teleport'),
      createdAt: created,
    );
    await tester.pumpWidget(
      app(const VaultFormView(vaultId: 'f'), vaults: [home, future]),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('not supported in this version'),
      findsOneWidget,
    );
  });
}
