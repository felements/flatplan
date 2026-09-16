import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../models/models.dart';
import '../providers/open_vault_provider.dart';
import '../providers/vaults_provider.dart';

/// The sidebar footer control: current vault name, a status line, and a
/// menu to switch vaults or open the manage screen.
class VaultSwitcher extends ConsumerWidget {
  static const manageValue = '__manage__';

  final VoidCallback onManage;

  const VaultSwitcher({super.key, required this.onManage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final registry = ref.watch(vaultsProvider).value;
    final open = ref.watch(openVaultProvider).value;
    final status = ref.watch(currentSyncStatusProvider);

    final current = open?.vault ?? registry?.selected;
    if (current == null) return const SizedBox.shrink();

    final String? subtitle;
    final bool attention;
    if (open?.accessError != null) {
      subtitle = 'Needs attention';
      attention = true;
    } else if (current.location is RemoteVaultLocation && status != null) {
      subtitle = status.describe(DateTime.now());
      attention = false;
    } else {
      subtitle = null;
      attention = false;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: PopupMenuButton<String>(
          tooltip: 'Switch vault',
          position: PopupMenuPosition.over,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onSelected: (value) {
            if (value == manageValue) {
              onManage();
            } else {
              ref.read(vaultsProvider.notifier).select(value);
            }
          },
          itemBuilder: (context) => [
            for (final vault in registry?.vaults ?? const <Vault>[])
              PopupMenuItem<String>(
                value: vault.id,
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      child: vault.id == current.id
                          ? Icon(
                              Icons.check_rounded,
                              size: 18,
                              color: colorScheme.primary,
                            )
                          : null,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(vault.name, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
            const PopupMenuDivider(),
            const PopupMenuItem<String>(
              value: manageValue,
              child: Text('Manage vaults…'),
            ),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        current.name,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: attention
                                ? colorScheme.error
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  Icons.unfold_more_rounded,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
