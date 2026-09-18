import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../models/models.dart';
import '../providers/vaults_provider.dart';

/// Asks before forgetting [vault], then removes it. Returns true when the
/// vault was removed; a refusal or a failure (shown as a snack bar)
/// returns false. Shared by the vault list and the edit page.
Future<bool> confirmRemoveVault(
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
  if (confirmed != true) return false;
  try {
    await ref.read(vaultsProvider.notifier).remove(vault.id);
    return true;
  } catch (e) {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not remove "${vault.name}": $e')),
    );
    return false;
  }
}
