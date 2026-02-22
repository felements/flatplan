import 'package:flutter/material.dart';

import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../logic/period_logic.dart';
import '../models/models.dart';
import '../providers/current_period_provider.dart';

class SettingsView extends HookConsumerWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var theme = Theme.of(context);
    final currentPeriodAsync = ref.watch(currentPeriodProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: currentPeriodAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (period) {
          return ListView(
            padding: const EdgeInsets.all(24.0),
            children: [
              // Section 1: Active Tracking Instance
              Text(
                'Active Tracking Instance',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (period != null) ...[
                        Text(
                          'Current Period: ${period.name}',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text('Base Currency: ${period.baseCurrency}'),
                        Text('Total Categories: ${period.categories.length}'),
                      ] else ...[
                        Text(
                          'No active period found.',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'You need to generate or load a period template to begin tracking.',
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Section 2: Rollover / Initialization
              Text(
                'Rollover & Initialization',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (period == null) ...[
                        const Text(
                          'No tracking periods exist yet. Create your first period to start budgeting.',
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () =>
                              _showCreateFirstPeriodDialog(context, ref),
                          icon: const Icon(Icons.add_circle_outline),
                          label: const Text('Create First Period'),
                        ),
                      ] else ...[
                        const Text(
                          'Start a new tracking period based on the current active configuration. This preserves planned expenses and categories while resetting actual factual spending.',
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () =>
                              _showGenerateDialog(context, ref, period),
                          icon: const Icon(Icons.auto_awesome),
                          label: const Text('Generate Next Period'),
                        ),
                      ],
                    ],
                  ),
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

    // Default dates
    DateTime startDate = currentPeriod.endDate.add(const Duration(days: 1));
    DateTime endDate = DateTime(
      startDate.year,
      startDate.month + 1,
      0,
    ); // Last day of next month roughly

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

                    // Push state
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
