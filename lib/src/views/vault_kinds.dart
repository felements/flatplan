import 'package:flutter/material.dart';

import '../models/models.dart';
import '../sync/gitlab/gitlab_settings.dart';
import 'gitlab_vault_form.dart';
import 'vault_form_view.dart';

/// How the UI presents one kind of vault. A provider spec adds one of
/// these (and a form) and nothing else in the UI changes.
class VaultKindDescriptor {
  /// `local`, or a remote kind such as `gitlab`.
  final String kind;
  final String label;
  final IconData icon;

  /// One line describing where a vault of this kind lives.
  final String Function(Vault vault) locationLine;

  /// Builds the form for creating or editing a vault of this kind. `null`
  /// existing means a new vault.
  final Widget Function(BuildContext context, Vault? existing) buildForm;

  const VaultKindDescriptor({
    required this.kind,
    required this.label,
    required this.icon,
    required this.locationLine,
    required this.buildForm,
  });
}

String _localPath(Vault vault) => switch (vault.location) {
  LocalVaultLocation(:final path) => path,
  RemoteVaultLocation() => '',
};

const localVaultKind = VaultKindDescriptor(
  kind: 'local',
  label: 'Local folder',
  icon: Icons.folder_rounded,
  locationLine: _localPath,
  buildForm: _localForm,
);

// Keyed by vault id so the form remounts (rather than keeping stale hook
// state) when `existing` changes identity, such as once the vault registry
// finishes its initial async load.
Widget _localForm(BuildContext context, Vault? existing) =>
    LocalVaultForm(key: ValueKey(existing?.id), existing: existing);

String _gitLabLocation(Vault vault) => switch (vault.location) {
  RemoteVaultLocation(:final settings) =>
    GitLabSettings.fromSettings(settings).locationLine,
  LocalVaultLocation() => '',
};

Widget _gitLabForm(BuildContext context, Vault? existing) =>
    GitLabVaultForm(key: ValueKey(existing?.id), existing: existing);

const gitLabVaultKind = VaultKindDescriptor(
  kind: GitLabSettings.kind,
  label: 'GitLab',
  icon: Icons.cloud_rounded,
  locationLine: _gitLabLocation,
  buildForm: _gitLabForm,
);

/// A remote kind this build does not know.
VaultKindDescriptor unsupportedVaultKind(String kind) => VaultKindDescriptor(
  kind: kind,
  label: 'Unsupported ($kind)',
  icon: Icons.cloud_off_rounded,
  locationLine: (_) => 'This vault type is not supported in this version.',
  buildForm: (context, existing) => const UnsupportedVaultNotice(),
);

/// Kinds a user can create. Providers append to this list.
List<VaultKindDescriptor> get vaultKinds => const [localVaultKind, gitLabVaultKind];

VaultKindDescriptor vaultKindFor(Vault vault) => switch (vault.location) {
  LocalVaultLocation() => localVaultKind,
  RemoteVaultLocation(:final kind) =>
    vaultKinds.where((d) => d.kind == kind).firstOrNull ??
        unsupportedVaultKind(kind),
};
