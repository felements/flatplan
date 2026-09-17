import 'package:flutter/material.dart';

import '../models/models.dart';
import '../sync/gitlab/gitlab_settings.dart';
import 'gitlab_vault_form.dart';
import 'vault_form_view.dart';

/// A short line the vault list shows under a vault, such as a token that
/// is about to expire. [urgent] draws it in the error colour.
class VaultNotice {
  final String text;
  final bool urgent;

  const VaultNotice(this.text, {required this.urgent});

  @override
  bool operator ==(Object other) =>
      other is VaultNotice && other.text == text && other.urgent == urgent;

  @override
  int get hashCode => Object.hash(text, urgent);

  @override
  String toString() => 'VaultNotice($text, urgent: $urgent)';
}

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

  /// Something the user should know about this vault right now, or null.
  final VaultNotice? Function(Vault vault, DateTime now) notice;

  const VaultKindDescriptor({
    required this.kind,
    required this.label,
    required this.icon,
    required this.locationLine,
    required this.buildForm,
    this.notice = _noNotice,
  });
}

VaultNotice? _noNotice(Vault vault, DateTime now) => null;

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

/// Warns about the token's expiry: urgent within two weeks or once past,
/// informational otherwise, nothing when the expiry is unknown.
VaultNotice? _gitLabNotice(Vault vault, DateTime now) {
  if (vault.location case RemoteVaultLocation(:final settings)) {
    final expiresAt = GitLabSettings.parseExpiry(settings['token_expires_at']);
    if (expiresAt == null) return null;
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(expiresAt.year, expiresAt.month, expiresAt.day);
    final days = day.difference(today).inDays;
    final date = GitLabSettings.formatDate(day);
    if (days < 0) return VaultNotice('Token expired on $date', urgent: true);
    if (days == 0) return const VaultNotice('Token expires today', urgent: true);
    if (days == 1) return const VaultNotice('Token expires tomorrow', urgent: true);
    if (days <= 14) return VaultNotice('Token expires in $days days', urgent: true);
    return VaultNotice('Token expires on $date', urgent: false);
  }
  return null;
}

const gitLabVaultKind = VaultKindDescriptor(
  kind: GitLabSettings.kind,
  label: 'GitLab',
  icon: Icons.cloud_rounded,
  locationLine: _gitLabLocation,
  buildForm: _gitLabForm,
  notice: _gitLabNotice,
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
