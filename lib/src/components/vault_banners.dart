import 'package:flutter/material.dart';

/// Explains why the selected vault cannot be opened. Rendered by Settings
/// and by the dashboard's unavailable view.
class VaultAccessBanner extends StatelessWidget {
  final String message;

  const VaultAccessBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown once on the dashboard after a corrupt `vaults.json` was moved
/// aside and a fresh registry created.
class BrokenRegistryBanner extends StatelessWidget {
  final String brokenFile;
  final VoidCallback onDismiss;

  const BrokenRegistryBanner({
    super.key,
    required this.brokenFile,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 20,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Your vault list could not be read. It was moved to '
              '$brokenFile and a fresh list was created. Your period files '
              'are untouched.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onErrorContainer,
              ),
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: onDismiss,
            style: TextButton.styleFrom(
              foregroundColor: colorScheme.onErrorContainer,
            ),
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
  }
}

/// Shown on the dashboard when the open remote vault's sync failed for a
/// reason only the user can fix: a rejected or expired token, an untrusted
/// certificate. Leads straight to the vault's edit form.
class SyncAttentionBanner extends StatelessWidget {
  final String message;
  final int pendingChanges;
  final VoidCallback onOpenSettings;

  const SyncAttentionBanner({
    super.key,
    required this.message,
    required this.pendingChanges,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final pending = pendingChanges == 0
        ? null
        : pendingChanges == 1
            ? '1 change is waiting to sync.'
            : '$pendingChanges changes are waiting to sync.';
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.sync_problem_rounded,
            size: 20,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              pending == null ? message : '$message $pending',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onErrorContainer,
              ),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.tonalIcon(
            onPressed: onOpenSettings,
            icon: const Icon(Icons.settings_rounded, size: 18),
            label: const Text('Open vault settings'),
          ),
        ],
      ),
    );
  }
}
