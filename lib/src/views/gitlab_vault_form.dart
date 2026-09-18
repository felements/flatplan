import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../components/wizard_steps.dart';
import '../models/models.dart';
import '../providers/gitlab_connect_controller.dart';
import '../providers/vaults_provider.dart';
import '../sync/gitlab/gitlab_api.dart';
import '../sync/gitlab/gitlab_settings.dart';
import 'gitlab_identicon.dart';

/// Create or edit a GitLab vault. One scrolling column that reveals each
/// step as the previous one succeeds; nothing needs a wide screen.
class GitLabVaultForm extends HookConsumerWidget {
  final Vault? existing;

  const GitLabVaultForm({super.key, this.existing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final existingSettings = switch (existing?.location) {
      RemoteVaultLocation(:final settings) => GitLabSettings.fromSettings(settings),
      _ => null,
    };
    final controller = useMemoized(
      () => GitLabConnectController(
        apiFactory: ref.read(gitLabApiFactoryProvider),
        existing: existingSettings,
      ),
      [existing?.id],
    );
    useEffect(() => controller.dispose, [controller]);
    useListenable(controller);

    final name = useTextEditingController(text: existing?.name ?? '');
    final url = useTextEditingController(text: existingSettings?.baseUrl ?? '');
    final token = useTextEditingController();
    final search = useTextEditingController();
    final folder = useTextEditingController(text: controller.folder);
    final folderFocus = useFocusNode();
    // Tab and programmatic focus moves never fire onTapOutside or
    // onSubmitted, so the check also runs when the field loses focus.
    useEffect(() {
      void onFocus() {
        if (!folderFocus.hasFocus) controller.setFolder(folder.text);
      }
      folderFocus.addListener(onFocus);
      return () => folderFocus.removeListener(onFocus);
    }, [folderFocus, controller]);
    final nameError = useState<String?>(null);
    final saving = useState(false);
    final nameTouched = useState(existing != null);
    final storedToken = useState<String?>(null);
    final tokenLoaded = useState(false);
    final secretError = useState<String?>(null);
    final replacing = useState(false);
    useEffect(() {
      if (existing == null) return null;
      () async {
        try {
          final value = await ref.read(vaultSecretsProvider).read(existing!.id, GitLabSettings.secretName);
          if (!context.mounted) return;
          storedToken.value = value;
          tokenLoaded.value = true;
        } catch (e) {
          if (!context.mounted) return;
          storedToken.value = null;
          secretError.value = 'Could not read the stored token: $e';
          tokenLoaded.value = true;
        }
      }();
      return null;
    }, [existing?.id]);

    // Suggest the project name once, unless the user already typed one.
    useEffect(() {
      final suggested = controller.suggestedName;
      if (suggested != null && !nameTouched.value && name.text.isEmpty) {
        name.text = suggested;
      }
      return null;
    }, [controller.suggestedName]);

    // The trust dialog opens whenever the controller records an offer.
    useEffect(() {
      final offer = controller.pendingCertificate;
      if (offer == null) return null;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!context.mounted) return;
        final trusted = await showTrustCertificateDialog(context, offer);
        if (trusted) {
          await controller.trustCertificate();
        } else {
          controller.dismissCertificate();
        }
      });
      return null;
    }, [controller.pendingCertificate]);

    Future<void> save() async {
      final trimmed = name.text.trim();
      if (trimmed.isEmpty) {
        nameError.value = 'Give the vault a name.';
        return;
      }
      saving.value = true;
      try {
        final id = existing?.id ?? const Uuid().v4();
        final secrets = ref.read(vaultSecretsProvider);
        final newToken = controller.token;
        // Secret first: a crash between the two leaves an orphan secret,
        // never a vault without a token.
        if (newToken != null) {
          await secrets.write(id, GitLabSettings.secretName, newToken);
        }
        final settings = existing == null
            ? controller.toSettings()
            : existingSettings!.copyWith(
                certFingerprint: controller.certFingerprint,
                tokenExpiresAt: controller.tokenExpiresAt,
              );
        final vault = Vault(
          id: id,
          name: trimmed,
          location: VaultLocation.remote(
            kind: GitLabSettings.kind,
            settings: settings.toSettings(),
            secretNames: const [GitLabSettings.secretName],
          ),
          createdAt: existing?.createdAt ?? DateTime.now(),
        );
        final vaults = ref.read(vaultsProvider.notifier);
        if (existing == null) {
          await vaults.add(vault);
        } else {
          await vaults.updateVault(vault);
        }
        if (!context.mounted) return;
        final navigator = Navigator.of(context);
        if (navigator.canPop()) navigator.pop();
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save the vault: $e')),
        );
      } finally {
        if (context.mounted) saving.value = false;
      }
    }

    final isEdit = existing != null;
    final hint = theme.textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
    );
    final showTokenField = !isEdit || replacing.value || (tokenLoaded.value && storedToken.value == null);
    final tokenRequired = isEdit && (!tokenLoaded.value || replacing.value || storedToken.value == null);
    // `!controller.busy` matters on the edit form: a Save landing while a
    // "Trust again" is still in flight would store the pre-trust
    // fingerprint and lose the answer the user is waiting for. In create
    // mode gating on busy would swallow the first click on "Create vault":
    // the folder field's onTapOutside starts a folder check on
    // pointer-down, flipping busy true before pointer-up disables the
    // button.
    final canSubmit = !saving.value &&
        (isEdit
            ? (!controller.busy && (!tokenRequired || controller.token != null))
            : controller.canSave);

    final atToken = controller.step.index <= ConnectStep.token.index;
    final atProject = controller.step == ConnectStep.project;
    final atTarget = controller.step == ConnectStep.target;
    final host = Uri.tryParse(controller.baseUrl)?.host ?? controller.baseUrl;

    // The create flow is a wizard: one step's fields at a time, every
    // earlier step folded into one summary line. The edit form keeps
    // everything visible, because nothing there is sequential.
    final serverSection = <Widget>[
      CheckboxListTile(
        key: const Key('gitlab-self-hosted'),
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        title: const Text('Self-hosted instance'),
        value: controller.selfHosted,
        onChanged: isEdit
            ? null
            : (v) {
                final checked = v ?? false;
                controller.setSelfHosted(checked);
                // Re-checking must re-sync the controller with
                // whatever the (still-mounted) url field shows,
                // rather than leaving it on gitlab.com.
                if (checked) controller.setBaseUrl(url.text);
              },
      ),
      if (controller.selfHosted) ...[
        TextField(
          key: const Key('gitlab-url'),
          controller: url,
          enabled: !isEdit,
          decoration: const InputDecoration(
            labelText: 'Instance URL',
            hintText: 'https://gitlab.example.com',
            helperText: 'http:// is allowed for internal servers.',
          ),
          onChanged: controller.setBaseUrl,
        ),
        const SizedBox(height: 20),
      ],
    ];

    final tokenSection = <Widget>[
      if (showTokenField) ...[
        if (secretError.value != null) _ErrorLine(secretError.value!),
        _TokenField(
          controller: token,
          busy: controller.busy,
          onConnect: () => isEdit
              ? controller.verifyReplacementToken(token.text.trim())
              : controller.connect(token.text.trim()),
        ),
        const _TokenHelp(),
        if (controller.connectError != null) _ErrorLine(controller.connectError!),
        if (controller.token != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Connected', style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.primary)),
          ),
        const SizedBox(height: 20),
      ] else if (isEdit && tokenLoaded.value) ...[
        Row(
          children: [
            Expanded(child: Text('Token stored', style: theme.textTheme.bodyMedium)),
            TextButton(onPressed: () => replacing.value = true, child: const Text('Replace token')),
          ],
        ),
        const SizedBox(height: 20),
      ],
    ];

    final projectSection = <Widget>[
      TextField(
        key: const Key('gitlab-search'),
        controller: search,
        decoration: const InputDecoration(
          labelText: 'Project',
          hintText: 'Type to search, or paste group/repo',
        ),
        onChanged: controller.search,
      ),
      for (final p in controller.projects)
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          leading: _ProjectAvatar(project: p, load: controller.avatarFor),
          title: Text(p.name),
          subtitle: Text(p.pathWithNamespace),
          selected: controller.project?.id == p.id,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onTap: () => controller.selectProject(p),
        ),
      if (controller.avatarsForbidden)
        Padding(
          padding: const EdgeInsets.only(left: 16, top: 4),
          child: Text(
            'Project logos need the Avatar: Read permission on the token; '
            'initials are shown instead.',
            style: hint,
          ),
        ),
      const SizedBox(height: 20),
    ];

    final locationSection = <Widget>[
      if (isEdit) ...[
        Text('Location', style: theme.textTheme.labelLarge),
        Text(existingSettings!.locationLine, style: theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace')),
        Text('To use a different repository or folder, create a new vault.', style: hint),
        if (existingSettings.certFingerprint != null || controller.certFingerprint != null) ...[
          const SizedBox(height: 12),
          Text('Trusted certificate', style: theme.textTheme.labelLarge),
          Text(controller.certFingerprint ?? existingSettings.certFingerprint!, style: const TextStyle(fontFamily: 'monospace')),
          TextButton(
            onPressed: storedToken.value == null || controller.busy
                ? null
                : () => controller.fetchCurrentCertificate(storedToken.value!),
            child: const Text('Trust again'),
          ),
          if (!showTokenField && controller.connectError != null) _ErrorLine(controller.connectError!),
        ],
      ] else ...[
        DropdownButtonFormField<String>(
          key: const Key('gitlab-branch'),
          initialValue: controller.branch,
          decoration: const InputDecoration(labelText: 'Branch'),
          items: [for (final b in controller.branches) DropdownMenuItem(value: b, child: Text(b))],
          onChanged: (b) => b == null ? null : controller.selectBranch(b),
        ),
        const SizedBox(height: 20),
        TextField(
          key: const Key('gitlab-folder'),
          controller: folder,
          focusNode: folderFocus,
          // The check result replaces the helper text, so it sits exactly
          // where the helper does and inherits its inset.
          decoration: InputDecoration(
            labelText: 'Folder',
            helperText: controller.folderCheck == null ? 'Empty means the repository root.' : null,
            helper: controller.folderCheck == null ? null : _FolderStatus(controller.folderCheck!),
          ),
          onChanged: controller.updateFolder,
          onSubmitted: controller.setFolder,
          onTapOutside: (_) => controller.setFolder(folder.text),
        ),
      ],
      const SizedBox(height: 20),
      TextField(
        key: const Key('gitlab-name'),
        controller: name,
        decoration: InputDecoration(labelText: 'Name', errorText: nameError.value),
        onChanged: (_) {
          nameTouched.value = true;
          nameError.value = null;
        },
      ),
    ];

    final submit = FilledButton(
      onPressed: canSubmit ? save : null,
      child: Text(isEdit ? 'Save' : 'Create vault'),
    );

    return Material(
      type: MaterialType.transparency,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: isEdit
            ? [
                ...serverSection,
                ...tokenSection,
                ...locationSection,
                const SizedBox(height: 24),
                Align(alignment: Alignment.centerRight, child: submit),
              ]
            : [
                WizardSteps(
                  labels: const ['Token', 'Repository', 'Location'],
                  current: atToken ? 0 : (atProject ? 1 : 2),
                ),
                const SizedBox(height: 24),
                if (atToken) ...[
                  ...serverSection,
                  ...tokenSection,
                ] else
                  _DoneLine('$host · Token verified'),
                if (atProject)
                  ...projectSection
                else if (atTarget)
                  _DoneLine(controller.project!.pathWithNamespace),
                if (atTarget) ...[
                  const SizedBox(height: 12),
                  ...locationSection,
                ],
                if (!atToken) ...[
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      // Not gated on busy: a click on Back first blurs the
                      // folder field, which starts a check and would
                      // disable the button before the click completes.
                      TextButton.icon(
                        onPressed: controller.back,
                        icon: const Icon(Icons.arrow_back_rounded, size: 18),
                        label: const Text('Back'),
                      ),
                      const Spacer(),
                      if (atTarget) submit,
                    ],
                  ),
                ],
              ],
      ),
    );
  }
}

/// The folder check as the Folder field's helper: an icon per state so
/// "checking", "found", "nothing there" and "failed" read at a glance.
class _FolderStatus extends StatelessWidget {
  final FolderCheck check;

  const _FolderStatus(this.check);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final muted = colorScheme.onSurfaceVariant;
    final Widget icon;
    Color color = muted;
    switch (check.kind) {
      case FolderCheckKind.checking:
        icon = SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2, color: muted),
        );
      case FolderCheckKind.periodFiles:
        color = Colors.green.shade600;
        icon = Icon(Icons.check_circle_rounded, size: 16, color: color);
      case FolderCheckKind.empty:
        icon = Icon(Icons.folder_open_outlined, size: 16, color: muted);
      case FolderCheckKind.missing:
        icon = Icon(Icons.create_new_folder_outlined, size: 16, color: muted);
      case FolderCheckKind.newRepository:
        icon = Icon(Icons.fiber_new_outlined, size: 16, color: muted);
      case FolderCheckKind.error:
        color = colorScheme.error;
        icon = Icon(Icons.error_outline_rounded, size: 16, color: color);
    }
    final style = theme.textTheme.bodySmall?.copyWith(color: color);
    final detail = check.detail;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(top: 1), child: icon),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(check.describe(), style: style),
              if (detail != null)
                Text(
                  detail,
                  style: theme.textTheme.bodySmall?.copyWith(color: muted, fontFamily: 'monospace'),
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The project's GitLab avatar, or its initial while loading and when it
/// has none.
class _ProjectAvatar extends StatelessWidget {
  static const size = 32.0;

  final ProjectSummary project;
  final Future<Uint8List?> Function(ProjectSummary) load;

  const _ProjectAvatar({required this.project, required this.load});

  @override
  Widget build(BuildContext context) {
    final initial = GitLabIdenticon(id: project.id, name: project.name, size: size);
    if (project.avatarUrl == null) return initial;
    return FutureBuilder<Uint8List?>(
      future: load(project),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) return initial;
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => initial,
          ),
        );
      },
    );
  }
}

/// A completed wizard step folded into one line.
class _DoneLine extends StatelessWidget {
  final String text;

  const _DoneLine(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, size: 18, color: colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _TokenField extends StatelessWidget {
  final TextEditingController controller;
  final bool busy;
  final VoidCallback onConnect;

  const _TokenField({required this.controller, required this.busy, required this.onConnect});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            key: const Key('gitlab-token'),
            controller: controller,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(labelText: 'Personal access token'),
            onSubmitted: (_) => onConnect(),
          ),
        ),
        const SizedBox(width: 12),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: ElevatedButton(
            onPressed: busy ? null : onConnect,
            child: const Text('Connect'),
          ),
        ),
      ],
    );
  }
}

class _TokenHelp extends StatelessWidget {
  const _TokenHelp();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text('How to create a token', style: Theme.of(context).textTheme.bodyMedium),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Fine-grained token (recommended)', style: style?.copyWith(fontWeight: FontWeight.bold)),
              Text(
                'User settings → Access → Personal access tokens → Generate token → '
                'Fine-grained. Under "Group and project access" pick the vault '
                'repository, then grant Project: Read, Branch: Read, Repository: Read '
                'and Commit: Create; add Avatar: Read to see project logos. Under '
                'the User tab grant Project: Read. Available on every tier from '
                'GitLab 19.2.',
                style: style,
              ),
              const SizedBox(height: 8),
              Text('Legacy token', style: style?.copyWith(fontWeight: FontWeight.bold)),
              Text(
                'Scope "api". Needed on instances older than GitLab 18.10. Admins can '
                'block legacy tokens after a date they set; GitLab then answers with '
                'the fine-grained permissions to use instead.',
                style: style,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ErrorLine extends StatelessWidget {
  final String message;

  const _ErrorLine(this.message);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(message, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
    );
  }
}

/// Asks whether to trust [offer]. Returns true when the user chose Trust.
Future<bool> showTrustCertificateDialog(BuildContext context, CertificateRejected offer) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Trust this certificate?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${offer.host} presented a certificate your system does not trust.'),
          const SizedBox(height: 12),
          Text('Subject: ${offer.subject}'),
          const SizedBox(height: 4),
          SelectableText('SHA-256: ${offer.fingerprint}', style: const TextStyle(fontFamily: 'monospace')),
          const SizedBox(height: 12),
          const Text('Only this exact certificate will be accepted. Compare the fingerprint with your server before trusting it.'),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Trust')),
      ],
    ),
  );
  return result ?? false;
}
