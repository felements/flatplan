import 'dart:async';
import 'dart:io' show HandshakeException;

import 'package:flatplan/src/components/wizard_steps.dart';
import 'package:flatplan/src/models/models.dart';
import 'package:flatplan/src/providers/gitlab_connect_controller.dart';
import 'package:flatplan/src/providers/vaults_provider.dart';
import 'package:flatplan/src/storage/vault_secrets.dart';
import 'package:flatplan/src/sync/gitlab/gitlab_api.dart';
import 'package:flatplan/src/views/gitlab_identicon.dart';
import 'package:flatplan/src/views/gitlab_vault_form.dart';
import 'package:flatplan/src/views/vault_kinds.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'support/fake_vaults.dart';
import 'sync/gitlab/fake_gitlab.dart';

/// A [VaultSecrets] whose [read] always fails, to prove the form surfaces
/// the failure instead of hanging on a blank token section forever.
class ThrowingVaultSecrets implements VaultSecrets {
  @override
  Future<String?> read(String vaultId, String name) => throw StateError('keychain locked');

  @override
  Future<void> write(String vaultId, String name, String value) async {}

  @override
  Future<void> deleteAll(String vaultId, List<String> names) async {}
}

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

  Widget app(Widget child, {CertificateRejected? offer, VaultSecrets? secretsOverride}) {
    fakeVaults = FakeVaults(VaultRegistry(lastSelectedVaultId: 'home', vaults: [home]));
    var offered = false;
    return ProviderScope(
      overrides: [
        vaultsProvider.overrideWith(() => fakeVaults),
        vaultSecretsProvider.overrideWith((ref) => secretsOverride ?? secrets),
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
    expect(find.textContaining('Avatar: Read'), findsOneWidget);
    expect(find.textContaining('api'), findsWidgets);
  });

  testWidgets('the step indicator follows the wizard and is absent when editing', (tester) async {
    await tester.pumpWidget(app(const GitLabVaultForm()));
    await tester.pumpAndSettle();
    WizardSteps steps() => tester.widget<WizardSteps>(find.byType(WizardSteps));
    expect(steps().labels, ['Token', 'Repository', 'Location']);
    expect(steps().current, 0);

    await connect(tester, url: FakeGitLab.baseUrl);
    expect(steps().current, 1);

    await tester.tap(find.text('group/repo'));
    await tester.pumpAndSettle();
    expect(steps().current, 2);

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(steps().current, 1);

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(steps().current, 0);
    expect(find.text('Back'), findsNothing);
  });

  testWidgets('each step shows only its own fields; earlier steps collapse to one line', (tester) async {
    gitlab.files['budget/2026-09-september.yaml'] = 'id: p\n';
    await tester.pumpWidget(app(const GitLabVaultForm()));
    await connect(tester, url: FakeGitLab.baseUrl);

    // Repository step: the token section is a summary line now.
    expect(find.text('gitlab.test · Token verified'), findsOneWidget);
    expect(find.byKey(const Key('gitlab-token')), findsNothing);
    expect(find.text('Self-hosted instance'), findsNothing);
    expect(find.byKey(const Key('gitlab-search')), findsOneWidget);
    expect(find.text('group/repo'), findsOneWidget);
    expect(find.byKey(const Key('gitlab-branch')), findsNothing);

    await tester.tap(find.text('group/repo'));
    await tester.pumpAndSettle();

    // Location step: the project list is gone, the chosen project is a line.
    expect(find.byKey(const Key('gitlab-search')), findsNothing);
    expect(find.byType(ListTile), findsNothing);
    expect(find.text('group/repo'), findsOneWidget);
    expect(find.text('gitlab.test · Token verified'), findsOneWidget);
    expect(find.text('1 period file found'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'repo'), findsOneWidget);
    expect(find.text('Create vault'), findsOneWidget);
  });

  testWidgets('Back walks the wizard backwards and the token step ends with Connect again', (tester) async {
    await tester.pumpWidget(app(const GitLabVaultForm()));
    await connect(tester, url: FakeGitLab.baseUrl);
    await tester.tap(find.text('group/repo'));
    await tester.pumpAndSettle();
    expect(find.text('Create vault'), findsOneWidget);

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Create vault'), findsNothing);
    expect(find.byKey(const Key('gitlab-search')), findsOneWidget);
    expect(find.text('group/repo'), findsOneWidget);

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('gitlab-token')), findsOneWidget);
    expect(find.text('Self-hosted instance'), findsOneWidget);
    expect(find.text('group/repo'), findsNothing);

    // The typed token is still in the field: Connect moves forward again.
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();
    expect(find.text('group/repo'), findsOneWidget);
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

    expect(find.text('gitlab.test · Token verified'), findsOneWidget);
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

  testWidgets('a folder typed and left with Tab is what gets saved', (tester) async {
    gitlab.files['finance/2026-09-september.yaml'] = 'id: p\n';
    await tester.pumpWidget(app(const GitLabVaultForm()));
    await connect(tester, url: FakeGitLab.baseUrl);
    await tester.tap(find.text('group/repo'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Create vault'));

    // Type the folder, then move on with the keyboard: no Enter, no click
    // in the field's surroundings.
    await tester.enterText(find.byKey(const Key('gitlab-folder')), 'finance');
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(find.text('1 period file found'), findsOneWidget, reason: 'losing focus runs the folder check');

    await tester.tap(find.text('Create vault'));
    await tester.pumpAndSettle();

    final location = fakeVaults.added.single.location as RemoteVaultLocation;
    expect(location.settings['folder'], 'finance');
  });

  testWidgets('the folder status sits in the field helper with an icon per state', (tester) async {
    gitlab.files['budget/2026-01-january.yaml'] = 'a';
    gitlab.files['budget/2026-11-november.yaml'] = 'c';
    await tester.pumpWidget(app(const GitLabVaultForm()));
    await connect(tester, url: FakeGitLab.baseUrl);

    // In flight: a progress indicator and "Checking folder…".
    final gate = Completer<void>();
    gitlab.pauseTree = gate;
    await tester.tap(find.text('group/repo'));
    // The branches request answers first; the tree request then blocks
    // on the gate, leaving the check in flight.
    for (var i = 0; i < 10 && find.text('Checking folder…').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(find.text('Checking folder…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    gate.complete();
    await tester.pumpAndSettle();

    // Found: green check, count, first … last.
    TextField folderField() => tester.widget<TextField>(find.byKey(const Key('gitlab-folder')));
    expect(folderField().decoration!.helper, isNotNull, reason: 'status aligns with the helper text');
    expect(find.text('2 period files found'), findsOneWidget);
    expect(find.text('2026-01-january … 2026-11-november'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is Icon && w.icon == Icons.check_circle_rounded && w.color == Colors.green.shade600,
      ),
      findsOneWidget,
    );

    // Missing: its own icon, not an error.
    await tester.enterText(find.byKey(const Key('gitlab-folder')), 'nowhere');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('Folder not found, it will be created on first sync'), findsOneWidget);
    expect(find.byIcon(Icons.create_new_folder_outlined), findsOneWidget);
    expect(find.byIcon(Icons.error_outline_rounded), findsNothing);

    // Error: the error icon.
    gitlab.failWith['/projects/42/repository/tree'] = 403;
    await tester.enterText(find.byKey(const Key('gitlab-folder')), 'other');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
  });

  testWidgets('a token that cannot read avatars gets a hint under the project list', (tester) async {
    gitlab.hasAvatar = true;
    gitlab.failWith['/projects/42/avatar'] = 403;
    await tester.pumpWidget(app(const GitLabVaultForm()));
    await connect(tester, url: FakeGitLab.baseUrl);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.textContaining('Avatar: Read'), findsOneWidget);
    expect(find.byType(GitLabIdenticon), findsOneWidget);
  });

  testWidgets('project rows are inset like the search field above them', (tester) async {
    await tester.pumpWidget(app(const GitLabVaultForm()));
    await connect(tester, url: FakeGitLab.baseUrl);

    final row = tester.widget<ListTile>(find.byType(ListTile).first);
    expect(row.contentPadding, const EdgeInsets.symmetric(horizontal: 16));
  });

  testWidgets('project rows show the GitLab avatar, or the initial when there is none', (tester) async {
    await tester.pumpWidget(app(const GitLabVaultForm()));
    await connect(tester, url: FakeGitLab.baseUrl);

    expect(find.descendant(of: find.byType(ListTile), matching: find.text('R')), findsOneWidget);
    expect(find.byType(GitLabIdenticon), findsOneWidget);
    expect(find.byType(Image), findsNothing);

    gitlab.hasAvatar = true;
    await tester.enterText(find.byKey(const Key('gitlab-search')), 'repo');
    await tester.pumpAndSettle();
    // The download starts on a zero-length timer, which the test clock only
    // fires when time passes; pumpAndSettle stops as soon as no frame is due.
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    final image = tester.widget<Image>(find.descendant(of: find.byType(ListTile), matching: find.byType(Image)));
    expect((image.image as MemoryImage).bytes, FakeGitLab.avatarPng);
    expect(find.descendant(of: find.byType(ListTile), matching: find.text('R')), findsNothing);
  });

  testWidgets('Back stays clickable while the folder check the click itself started runs', (tester) async {
    await tester.pumpWidget(app(const GitLabVaultForm()));
    await connect(tester, url: FakeGitLab.baseUrl);
    await tester.tap(find.text('group/repo'));
    await tester.pumpAndSettle();

    // Leaving the folder field (which a click on Back does, on pointer-down)
    // starts a check; Back must survive the busy flag it raises.
    final gate = Completer<void>();
    gitlab.pauseTree = gate;
    await tester.enterText(find.byKey(const Key('gitlab-folder')), 'budget');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.text('Checking folder…'), findsOneWidget);
    expect(
      tester.widget<TextButton>(find.widgetWithText(TextButton, 'Back')).onPressed,
      isNotNull,
      reason: 'a folder check in flight must not disable Back',
    );

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('gitlab-search')), findsOneWidget);
    expect(find.byKey(const Key('gitlab-folder')), findsNothing);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('gitlab-search')), findsOneWidget);
  });

  testWidgets('Create vault stays clickable while a folder check runs', (tester) async {
    await tester.pumpWidget(app(const GitLabVaultForm()));
    await connect(tester, url: FakeGitLab.baseUrl);
    await tester.tap(find.text('group/repo'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Create vault'));

    // Pause the folder check the way the folder field's onTapOutside
    // triggers one, then flip the controller busy without going through a
    // real pointer-down/up pair (which is what actually raced in the bug).
    final gate = Completer<void>();
    gitlab.pauseTree = gate;
    await tester.enterText(find.byKey(const Key('gitlab-folder')), 'reports');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    FilledButton createButton() =>
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Create vault'));
    expect(
      createButton().onPressed,
      isNotNull,
      reason: 'a folder check in flight must not disable Create vault',
    );

    gate.complete();
    await tester.pumpAndSettle();

    expect(createButton().onPressed, isNotNull);
  });

  Vault gitLabVault({String? fingerprint}) => Vault(
    id: 'g',
    name: 'Budget',
    location: VaultLocation.remote(
      kind: 'gitlab',
      settings: {
        'base_url': FakeGitLab.baseUrl,
        'project_id': 42,
        'project_path': 'group/repo',
        'branch': 'main',
        'folder': 'budget',
        'cert_fingerprint': ?fingerprint,
      },
      secretNames: const ['token'],
    ),
    createdAt: created,
  );

  testWidgets('the edit form shows the location read-only and a token replacement', (tester) async {
    await secrets.write('g', 'token', 'old');
    await tester.pumpWidget(app(GitLabVaultForm(existing: gitLabVault())));
    await tester.pumpAndSettle();

    expect(find.text('gitlab.test · group/repo/budget'), findsOneWidget);
    expect(find.byKey(const Key('gitlab-branch')), findsNothing);
    expect(find.text('Token stored'), findsOneWidget);
    expect(find.text('Replace token'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('replacing the token verifies it and saves the new secret', (tester) async {
    await secrets.write('g', 'token', 'old');
    gitlab.tokenExpiresAt = '2027-01-01';
    await tester.pumpWidget(app(GitLabVaultForm(existing: gitLabVault())));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Replace token'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('gitlab-token')), gitlab.validToken);
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();
    expect(find.text('Connected'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(fakeVaults.updated.single.name, 'Budget');
    expect(await secrets.read('g', 'token'), gitlab.validToken);
    final saved = fakeVaults.updated.single.location as RemoteVaultLocation;
    expect(saved.settings['token_expires_at'], '2027-01-01');
  });

  testWidgets('a missing secret makes the token field required', (tester) async {
    await tester.pumpWidget(app(GitLabVaultForm(existing: gitLabVault())));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('gitlab-token')), findsOneWidget);
    expect(find.text('Token stored'), findsNothing);
  });

  testWidgets('a self-hosted vault shows the trusted fingerprint and can trust again', (tester) async {
    await secrets.write('g', 'token', gitlab.validToken);
    await tester.pumpWidget(app(GitLabVaultForm(existing: gitLabVault(fingerprint: 'AA:BB'))));
    await tester.pumpAndSettle();

    expect(find.textContaining('AA:BB'), findsOneWidget);
    expect(find.text('Trust again'), findsOneWidget);
  });

  testWidgets('Save is disabled until a missing token is verified', (tester) async {
    await tester.pumpWidget(app(GitLabVaultForm(existing: gitLabVault())));
    await tester.pumpAndSettle();

    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save')).onPressed, isNull);

    await tester.enterText(find.byKey(const Key('gitlab-token')), gitlab.validToken);
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();

    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save')).onPressed, isNotNull);
  });

  testWidgets('Save stays disabled after Replace token until Connect succeeds', (tester) async {
    await secrets.write('g', 'token', 'old');
    await tester.pumpWidget(app(GitLabVaultForm(existing: gitLabVault())));
    await tester.pumpAndSettle();

    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save')).onPressed, isNotNull);

    await tester.tap(find.text('Replace token'));
    await tester.pumpAndSettle();

    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save')).onPressed, isNull);
  });

  testWidgets('a secret read failure shows an error and still requires a token', (tester) async {
    await tester.pumpWidget(app(GitLabVaultForm(existing: gitLabVault()), secretsOverride: ThrowingVaultSecrets()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not read the stored token'), findsOneWidget);
    expect(find.byKey(const Key('gitlab-token')), findsOneWidget);
  });

  testWidgets('Save is disabled while a Trust again is in flight', (tester) async {
    await secrets.write('g', 'token', gitlab.validToken);
    final gate = Completer<void>();
    gitlab.pauseSearch = gate;
    await tester.pumpWidget(app(GitLabVaultForm(existing: gitLabVault(fingerprint: 'AA:BB'))));
    await tester.pumpAndSettle();

    FilledButton saveButton() =>
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'));
    expect(saveButton().onPressed, isNotNull);

    await tester.tap(find.text('Trust again'));
    await tester.pump();

    expect(saveButton().onPressed, isNull, reason: 'the fingerprint is still being checked');

    gate.complete();
    await tester.pumpAndSettle();

    expect(saveButton().onPressed, isNotNull);
  });

  testWidgets('a failed re-trust shows the error next to the certificate', (tester) async {
    await secrets.write('g', 'token', gitlab.validToken);
    gitlab.throwOnRequest = socketDropped();
    await tester.pumpWidget(app(GitLabVaultForm(existing: gitLabVault(fingerprint: 'AA:BB'))));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Trust again'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not reach'), findsOneWidget);
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
  testWidgets('the edit form has no step indicator', (tester) async {
    await tester.pumpWidget(app(GitLabVaultForm(existing: gitLabVault())));
    await tester.pumpAndSettle();

    expect(find.byType(WizardSteps), findsNothing);
  });
}
