import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../logic/period_logic.dart';
import '../models/models.dart';
import '../providers/current_period_provider.dart';
import '../providers/storage_settings_provider.dart';

/// Settings page for period management and app configuration.
class SettingsView extends HookConsumerWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currentPeriodAsync = ref.watch(currentPeriodProvider);
    final storageDirAsync = ref.watch(storageSettingsProvider);

    return Scaffold(
      body: currentPeriodAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (period) {
          return ListView(
            padding: const EdgeInsets.all(32),
            children: [
              // ─── Page header ──────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(bottom: 28),
                child: Text(
                  'Settings',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),

              // ─── Data Storage ──────────────────────────────────
              _SectionHeader(icon: Icons.folder_rounded, title: 'Data Storage'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                    width: 0.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Period files location',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    storageDirAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text(
                        'Error loading path: $e',
                        style: TextStyle(color: colorScheme.error),
                      ),
                      data: (dirPath) => Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                dirPath,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontFamily: 'monospace',
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: () async {
                              final picked = await FilePicker.platform
                                  .getDirectoryPath(
                                    dialogTitle: 'Select periods folder',
                                  );
                              if (picked != null) {
                                await ref
                                    .read(storageSettingsProvider.notifier)
                                    .updateDirectory(picked);
                              }
                            },
                            icon: const Icon(Icons.folder_open_rounded),
                            label: const Text('Change Folder'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Defaults to the application directory. '
                      'Changing the folder takes effect immediately.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // ─── Category Management ───────────────────────────
              _SectionHeader(
                icon: Icons.category_rounded,
                title: 'Category Management',
              ),
              const SizedBox(height: 12),
              Container(
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
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            period != null
                                ? '${period.categories.length} categor${period.categories.length == 1 ? 'y' : 'ies'} configured'
                                : 'No active period',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Add, edit, or remove budget categories for the current period.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: period != null
                          ? () =>
                                GoRouter.of(context).go('/settings/categories')
                          : null,
                      icon: const Icon(Icons.edit_rounded),
                      label: const Text('Manage Categories'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // ─── Active Tracking Instance ─────────────────────
              _SectionHeader(
                icon: Icons.timer_rounded,
                title: 'Active Tracking Instance',
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                    width: 0.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (period != null) ...[
                      Text(
                        'Current Period: ${period.name}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _InfoRow(
                        label: 'Base Currency',
                        value: period.baseCurrency,
                      ),
                      const SizedBox(height: 4),
                      _InfoRow(
                        label: 'Total Categories',
                        value: '${period.categories.length}',
                      ),
                    ] else ...[
                      Text(
                        'No active period found.',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'You need to generate or load a period template to begin tracking.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // ─── Rollover & Initialization ────────────────────
              _SectionHeader(
                icon: Icons.auto_awesome_rounded,
                title: 'Rollover & Initialization',
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                    width: 0.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (period == null) ...[
                      Text(
                        'No tracking periods exist yet. Create your first period to start budgeting.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () =>
                            _showCreateFirstPeriodDialog(context, ref),
                        icon: const Icon(Icons.add_circle_outline_rounded),
                        label: const Text('Create First Period'),
                      ),
                    ] else ...[
                      Text(
                        'Start a new tracking period based on the current active configuration. '
                        'This preserves planned expenses and categories while resetting actual spending.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () =>
                            _showGenerateDialog(context, ref, period),
                        icon: const Icon(Icons.auto_awesome_rounded),
                        label: const Text('Generate Next Period'),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showCreateFirstPeriodDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final nameController = TextEditingController();
    final currencyController = TextEditingController(text: 'EUR');

    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime(
      startDate.year,
      startDate.month + 1,
      startDate.day,
    ).subtract(const Duration(days: 1));

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Create First Period'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Period Name (e.g. February 2026)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: currencyController,
                    decoration: const InputDecoration(
                      labelText: 'Base Currency (e.g. EUR, USD)',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Start Date: '),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: startDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() => startDate = picked);
                          }
                        },
                        child: Text(
                          '${startDate.year}-${startDate.month}-${startDate.day}',
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Text('End Date: '),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: endDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() => endDate = picked);
                          }
                        },
                        child: Text(
                          '${endDate.year}-${endDate.month}-${endDate.day}',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final newName = nameController.text.trim();
                    final currency = currencyController.text
                        .trim()
                        .toUpperCase();
                    if (newName.isEmpty) return;

                    final newPeriod = createEmptyPeriod(
                      startDate: startDate,
                      endDate: endDate,
                      name: newName,
                      baseCurrency: currency.isEmpty ? 'EUR' : currency,
                    );

                    ref
                        .read(currentPeriodProvider.notifier)
                        .setPeriod(newPeriod);

                    Navigator.pop(ctx);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Period "$newName" created!')),
                    );
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    currencyController.dispose();
  }

  Future<void> _showGenerateDialog(
    BuildContext context,
    WidgetRef ref,
    Period currentPeriod,
  ) async {
    final nameController = TextEditingController();

    DateTime startDate = currentPeriod.endDate.add(const Duration(days: 1));
    DateTime endDate = DateTime(startDate.year, startDate.month + 1, 0);

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Generate Next Period'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'New Period Name (e.g. March 2026)',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Start Date: '),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: startDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() => startDate = picked);
                          }
                        },
                        child: Text(
                          '${startDate.year}-${startDate.month}-${startDate.day}',
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Text('End Date: '),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: endDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() => endDate = picked);
                          }
                        },
                        child: Text(
                          '${endDate.year}-${endDate.month}-${endDate.day}',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final newName = nameController.text.trim();
                    if (newName.isEmpty) return;

                    final newPeriod = createNextPeriod(
                      currentPeriod: currentPeriod,
                      newStartDate: startDate,
                      newEndDate: endDate,
                      newName: newName,
                    );

                    ref
                        .read(currentPeriodProvider.notifier)
                        .updatePeriod(newPeriod);

                    Navigator.pop(ctx);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Successfully rolled over to $newName!'),
                      ),
                    );
                  },
                  child: const Text('Generate'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
  }
}

/// A section header with icon and title.
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Icon(icon, size: 18, color: colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

/// A simple label → value information row.
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Text(
          '$label: ',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
