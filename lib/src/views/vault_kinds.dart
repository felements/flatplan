import 'package:flutter/material.dart';

import '../models/models.dart';

/// How the UI presents one kind of vault. A provider spec adds one of
/// these (and a form) and nothing else in the UI changes.
class VaultKindDescriptor {
  /// `local`, or a remote kind such as `gitlab`.
  final String kind;
  final String label;
  final IconData icon;

  /// One line describing where a vault of this kind lives.
  final String Function(Vault vault) locationLine;

  const VaultKindDescriptor({
    required this.kind,
    required this.label,
    required this.icon,
    required this.locationLine,
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
);

/// A remote kind this build does not know.
VaultKindDescriptor unsupportedVaultKind(String kind) => VaultKindDescriptor(
  kind: kind,
  label: 'Unsupported ($kind)',
  icon: Icons.cloud_off_rounded,
  locationLine: (_) => 'This vault type is not supported in this version.',
);

/// Kinds a user can create. Providers append to this list.
List<VaultKindDescriptor> get vaultKinds => const [localVaultKind];

VaultKindDescriptor vaultKindFor(Vault vault) => switch (vault.location) {
  LocalVaultLocation() => localVaultKind,
  RemoteVaultLocation(:final kind) =>
    vaultKinds.where((d) => d.kind == kind).firstOrNull ??
        unsupportedVaultKind(kind),
};
