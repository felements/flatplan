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
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'support/fake_vaults.dart';

/// A [FakeVaults] whose registry is read-only: every mutation throws, so
/// tests can exercise the form's error path.
class _ThrowingVaults extends FakeVaults {
  _ThrowingVaults(super.registry);

  @override
  Future<void> add(Vault vault) async {
    throw StateError('registry is read-only');
  }
}

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

  testWidgets('a save failure shows a snack bar and re-enables the button', (
    tester,
  ) async {
    fakeVaults = _ThrowingVaults(
      VaultRegistry(lastSelectedVaultId: 'home', vaults: [home]),
    );
    await tester.pumpWidget(
      ProviderScope(
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
        child: const MaterialApp(
          home: Scaffold(body: LocalVaultForm(canPickFolder: false)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Travel');
    await tester.tap(find.text('Create vault'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not save the vault'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
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

  testWidgets('a new vault starts with the kind chooser', (tester) async {
    await tester.pumpWidget(app(const VaultFormView()));
    await tester.pumpAndSettle();

    expect(find.text('Local folder'), findsOneWidget);
    expect(find.text('GitLab'), findsOneWidget);
  });

  testWidgets('choosing local folder from the chooser opens the local form', (
    tester,
  ) async {
    await tester.pumpWidget(app(const VaultFormView()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Local folder'));
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

  testWidgets('Cancel on the new-vault page returns to the vault list', (tester) async {
    fakeVaults = FakeVaults(
      VaultRegistry(lastSelectedVaultId: 'home', vaults: [home]),
    );
    final router = GoRouter(
      initialLocation: '/settings/vaults/new',
      routes: [
        GoRoute(path: '/settings/vaults', builder: (_, _) => const Text('VAULT LIST')),
        GoRoute(path: '/settings/vaults/new', builder: (_, _) => const VaultFormView()),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vaultsProvider.overrideWith(() => fakeVaults),
          appPathsProvider.overrideWith((ref) async => paths),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('New vault'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('VAULT LIST'), findsOneWidget);
    expect(fakeVaults.added, isEmpty);
  });

  Widget routed(List<Vault> vaults, String location) {
    fakeVaults = FakeVaults(
      VaultRegistry(lastSelectedVaultId: 'home', vaults: vaults),
    );
    final router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(path: '/settings/vaults', builder: (_, _) => const Text('VAULT LIST')),
        GoRoute(path: '/settings/vaults/new', builder: (_, _) => const VaultFormView()),
        GoRoute(
          path: '/settings/vaults/:id/edit',
          builder: (_, state) => VaultFormView(vaultId: state.pathParameters['id']),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        vaultsProvider.overrideWith(() => fakeVaults),
        appPathsProvider.overrideWith((ref) async => paths),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  final travel = Vault(
    id: 'travel',
    name: 'Travel',
    location: const VaultLocation.local(path: '/Users/me/travel'),
    createdAt: created,
  );

  testWidgets('the new-vault page has no Remove button', (tester) async {
    await tester.pumpWidget(routed([home, travel], '/settings/vaults/new'));
    await tester.pumpAndSettle();

    expect(find.text('Remove'), findsNothing);
  });

  testWidgets('Remove on the edit page confirms, removes and returns to the list', (tester) async {
    await tester.pumpWidget(routed([home, travel], '/settings/vaults/travel/edit'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(find.text('Remove "Travel"?'), findsOneWidget);
    expect(fakeVaults.removed, isEmpty);

    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();

    expect(fakeVaults.removed, ['travel']);
    expect(find.text('VAULT LIST'), findsOneWidget);
  });

  testWidgets('cancelling the Remove dialog keeps the vault and stays on the page', (tester) async {
    await tester.pumpWidget(routed([home, travel], '/settings/vaults/travel/edit'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel').last);
    await tester.pumpAndSettle();

    expect(fakeVaults.removed, isEmpty);
    expect(find.text('Edit vault'), findsOneWidget);
  });

  testWidgets('Remove is disabled for the last vault', (tester) async {
    await tester.pumpWidget(routed([home], '/settings/vaults/home/edit'));
    await tester.pumpAndSettle();

    final button = tester.widget<TextButton>(find.widgetWithText(TextButton, 'Remove'));
    expect(button.onPressed, isNull);
    expect(find.byTooltip('The last vault cannot be removed.'), findsOneWidget);
  });
}
