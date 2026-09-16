import 'dart:io' show HandshakeException;

import 'package:flatplan/src/models/models.dart';
import 'package:flatplan/src/providers/gitlab_connect_controller.dart';
import 'package:flatplan/src/providers/vaults_provider.dart';
import 'package:flatplan/src/storage/vault_secrets.dart';
import 'package:flatplan/src/sync/gitlab/gitlab_api.dart';
import 'package:flatplan/src/views/gitlab_vault_form.dart';
import 'package:flatplan/src/views/vault_kinds.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'support/fake_vaults.dart';
import 'sync/gitlab/fake_gitlab.dart';

void main() {
  late FakeGitLab gitlab;
  late FakeVaults fakeVaults;
  late MemoryVaultSecrets secrets;
  final created = DateTime.utc(2026, 1, 1);
  final home = Vault(
    id: 'home',
    name: 'Home',
    location: const VaultLocation.local(path: '/Users/me/budget'),
    createdAt: created,
  );

  Widget app(Widget child, {CertificateRejected? offer}) {
    fakeVaults = FakeVaults(VaultRegistry(lastSelectedVaultId: 'home', vaults: [home]));
    var offered = false;
    return ProviderScope(
      overrides: [
        vaultsProvider.overrideWith(() => fakeVaults),
        vaultSecretsProvider.overrideWith((ref) => secrets),
        gitLabApiFactoryProvider.overrideWith(
          (ref) => ({required settings, required token}) => GitLabApi(
            client: gitlab.client,
            baseUrl: settings.baseUrl,
            token: token,
            takeRejectedCertificate: () {
              if (offer == null || offered) return null;
              offered = true;
              gitlab.throwOnRequest = null;
              return offer;
            },
          ),
        ),
      ],
      child: MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child))),
    );
  }

  setUp(() {
    gitlab = FakeGitLab();
    secrets = MemoryVaultSecrets();
  });

  Future<void> connect(WidgetTester tester, {String? url}) async {
    if (url != null) {
      await tester.tap(find.text('Self-hosted instance'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('gitlab-url')), url);
    }
    await tester.enterText(find.byKey(const Key('gitlab-token')), gitlab.validToken);
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();
  }

  testWidgets('starts with the token step and no url field', (tester) async {
    await tester.pumpWidget(app(const GitLabVaultForm()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('gitlab-url')), findsNothing);
    expect(find.text('Connect'), findsOneWidget);
    expect(find.text('Create vault'), findsNothing);
  });

  testWidgets('the self-hosted checkbox reveals the url field', (tester) async {
    await tester.pumpWidget(app(const GitLabVaultForm()));
    await tester.tap(find.text('Self-hosted instance'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('gitlab-url')), findsOneWidget);
  });

  testWidgets('the token help lists the fine-grained permissions and the legacy scope', (tester) async {
    await tester.pumpWidget(app(const GitLabVaultForm()));
    await tester.tap(find.text('How to create a token'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Commit: Create'), findsOneWidget);
    expect(find.textContaining('Repository: Read'), findsOneWidget);
    expect(find.textContaining('api'), findsWidgets);
  });

  testWidgets('connecting reveals projects, selecting reveals branch, folder and name', (tester) async {
    gitlab.files['budget/2026-09-september.yaml'] = 'id: p\n';
    await tester.pumpWidget(app(const GitLabVaultForm()));
    await connect(tester, url: FakeGitLab.baseUrl);

    expect(find.text('Connected'), findsOneWidget);
    expect(find.text('group/repo'), findsOneWidget);

    await tester.tap(find.text('group/repo'));
    await tester.pumpAndSettle();

    expect(find.text('1 period file found'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'repo'), findsOneWidget);
    expect(find.text('Create vault'), findsOneWidget);
  });

  testWidgets('unchecking self-hosted after selecting a project resets the flow', (tester) async {
    await tester.pumpWidget(app(const GitLabVaultForm()));
    await connect(tester, url: FakeGitLab.baseUrl);
    await tester.tap(find.text('group/repo'));
    await tester.pumpAndSettle();

    expect(find.text('Create vault'), findsOneWidget);
    expect(find.text('group/repo'), findsOneWidget);

    await tester.tap(find.text('Self-hosted instance'));
    await tester.pumpAndSettle();

    expect(find.text('Create vault'), findsNothing);
    expect(find.text('group/repo'), findsNothing);
  });

  testWidgets('a rejected token shows the error and stays on the token step', (tester) async {
    gitlab.validToken = 'other';
    await tester.pumpWidget(app(const GitLabVaultForm()));
    await tester.enterText(find.byKey(const Key('gitlab-token')), 'wrong');
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();

    expect(find.textContaining('rejected'), findsOneWidget);
    expect(find.text('group/repo'), findsNothing);
  });

  testWidgets('an untrusted certificate opens the trust dialog and trusting continues', (tester) async {
    gitlab.throwOnRequest = const HandshakeException('untrusted');
    final offer = CertificateRejected(host: 'gitlab.test', subject: 'CN=gitlab.test', fingerprint: 'AA:BB:CC');
    await tester.pumpWidget(app(const GitLabVaultForm(), offer: offer));
    await connect(tester, url: FakeGitLab.baseUrl);

    expect(find.text('Trust this certificate?'), findsOneWidget);
    expect(find.textContaining('AA:BB:CC'), findsOneWidget);

    await tester.tap(find.text('Trust'));
    await tester.pumpAndSettle();

    expect(find.text('Connected'), findsOneWidget);
  });

  testWidgets('creating writes the secret first and then adds the vault', (tester) async {
    await tester.pumpWidget(app(const GitLabVaultForm()));
    await connect(tester, url: FakeGitLab.baseUrl);
    await tester.tap(find.text('group/repo'));
    await tester.pumpAndSettle();
    // The fully-expanded form is taller than the default 800x600 test
    // surface, so the button starts below the fold.
    await tester.ensureVisible(find.text('Create vault'));
    await tester.tap(find.text('Create vault'));
    await tester.pumpAndSettle();

    final vault = fakeVaults.added.single;
    expect(vault.name, 'repo');
    final location = vault.location as RemoteVaultLocation;
    expect(location.kind, 'gitlab');
    expect(location.secretNames, ['token']);
    expect(location.settings['project_id'], 42);
    expect(location.settings['folder'], 'budget');
    expect(await secrets.read(vault.id, 'token'), gitlab.validToken);
  });

  test('the descriptor renders the location line', () {
    final vault = Vault(
      id: 'g',
      name: 'G',
      location: const VaultLocation.remote(
        kind: 'gitlab',
        settings: {'base_url': 'https://gitlab.com', 'project_id': 1, 'project_path': 'me/budget', 'branch': 'main', 'folder': 'budget'},
        secretNames: ['token'],
      ),
      createdAt: created,
    );
    expect(vaultKindFor(vault), same(gitLabVaultKind));
    expect(gitLabVaultKind.locationLine(vault), 'GitLab · me/budget/budget');
    expect(vaultKinds.map((k) => k.kind), ['local', 'gitlab']);
  });
}
