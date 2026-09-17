import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../models/models.dart';
import '../providers/open_vault_provider.dart';
import '../providers/vaults_provider.dart';
import 'vault_kinds.dart';

/// `/settings/vaults`: every vault, with edit, remove and sync actions.
class VaultListView extends ConsumerWidget {
  const VaultListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final registry = ref.watch(vaultsProvider).value;
    final open = ref.watch(openVaultProvider).value;
    final status = ref.watch(currentSyncStatusProvider);
    final vaults = registry?.vaults ?? const <Vault>[];
    final canRemove = vaults.length > 1;

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(32),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 28),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Vaults',
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => context.go('/settings/vaults/new'),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('New vault'),
                ),
              ],
            ),
          ),
          for (final vault in vaults) ...[
            _VaultCard(
              vault: vault,
              isCurrent: vault.id == open?.vault.id,
              accessError: vault.id == open?.vault.id ? open?.accessError : null,
              statusLine: vault.id == open?.vault.id &&
                      vault.location is RemoteVaultLocation
                  ? status?.describe(DateTime.now())
                  : null,
              canSyncNow: vault.id == open?.vault.id && open?.scheduler != null,
              canRemove: canRemove,
              onSyncNow: () => open?.scheduler?.syncNow(),
              onEdit: () => context.go('/settings/vaults/${vault.id}/edit'),
              onRemove: () => _confirmRemove(context, ref, vault),
            ),
            const SizedBox(height: 12),
          ],
          if (!canRemove)
            Text(
              'The last vault cannot be removed.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    Vault vault,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove "${vault.name}"?'),
        content: const Text(
          'FlatPlan will forget this vault. Your files are not deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(vaultsProvider.notifier).remove(vault.id);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not remove "${vault.name}": $e')),
      );
    }
  }
}

class _VaultCard extends StatelessWidget {
  final Vault vault;
  final bool isCurrent;
  final String? accessError;
  final String? statusLine;
  final bool canSyncNow;
  final bool canRemove;
  final VoidCallback onSyncNow;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  const _VaultCard({
    required this.vault,
    required this.isCurrent,
    required this.accessError,
    required this.statusLine,
    required this.canSyncNow,
    required this.canRemove,
    required this.onSyncNow,
    required this.onEdit,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final kind = vaultKindFor(vault);
    final notice = kind.notice(vault, DateTime.now());

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(kind.icon, color: colorScheme.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        vault.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCurrent) ...[
                      const SizedBox(width: 8),
                      _Chip(label: 'Current', color: colorScheme.primary),
                    ],
                    if (accessError != null) ...[
                      const SizedBox(width: 8),
                      _Chip(label: 'Needs attention', color: colorScheme.error),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  kind.locationLine(vault),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontFamily: 'monospace',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (statusLine != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    statusLine!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (notice != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    notice.text,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: notice.urgent
                          ? colorScheme.error
                          : colorScheme.onSurfaceVariant,
                      fontWeight: notice.urgent ? FontWeight.w600 : null,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (canSyncNow)
            TextButton.icon(
              onPressed: onSyncNow,
              icon: const Icon(Icons.sync_rounded, size: 18),
              label: const Text('Sync now'),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (value) => value == 'edit' ? onEdit() : onRemove(),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(
                value: 'remove',
                enabled: canRemove,
                child: const Text('Remove'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}
