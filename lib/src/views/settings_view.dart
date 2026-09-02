import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../components/period_load_warning.dart';
import '../logic/period_logic.dart';
import '../models/models.dart';
import '../providers/ai_stats_settings_provider.dart';
import '../providers/all_periods_provider.dart';
import '../providers/current_period_provider.dart';
import '../providers/storage_settings_provider.dart';
import '../storage/period_repository.dart';

/// Settings page for period management and app configuration.
class SettingsView extends HookConsumerWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currentPeriodAsync = ref.watch(currentPeriodProvider);
    final storageDirAsync = ref.watch(storageSettingsProvider);
    final aiStatsEnabled = ref.watch(aiStatsSettingsProvider).value ?? true;
    final loadFailures =
        ref.watch(periodLoadFailuresProvider).value ??
        const <PeriodLoadFailure>[];

    // Storage controls must stay reachable even when period loading fails, so
    // the page is never gated on currentPeriodProvider. Period-dependent
    // sections handle their own empty/loading state inline below.
    final period = currentPeriodAsync.value;

    return Scaffold(
      body: ListView(
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
                  data: (storageDir) {
                    final displayPath =
                        storageDir.configuredPath ?? storageDir.path;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (storageDir.accessError != null) ...[
                          Container(
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
                                    storageDir.accessError!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onErrorContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (loadFailures.isNotEmpty) ...[
                          PeriodLoadFailureList(failures: loadFailures),
                          const SizedBox(height: 12),
                        ],
                        Row(
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
                                  displayPath,
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
                        if (storageDir.configuredPath != null) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () => ref
                                  .read(storageSettingsProvider.notifier)
                                  .resetToDefault(),
                              icon: const Icon(
                                Icons.restart_alt_rounded,
                                size: 18,
                              ),
                              label: const Text('Reset to default folder'),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 10),
                Text(
                  'Defaults to the system application data directory. '
                  'Changing the folder takes effect immediately.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // ─── AI Insights Data ─────────────────────────────
          _SectionHeader(
            icon: Icons.insights_rounded,
            title: 'AI Insights Data',
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Generate current period stats',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                    Switch(
                      value: aiStatsEnabled,
                      onChanged: (value) => ref
                          .read(aiStatsSettingsProvider.notifier)
                          .setEnabled(value),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Writes a current_stats.md snapshot next to your period '
                  'files on every change, ready to feed AI spending insights. '
                  'Disabling removes the file.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
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
                  _InfoRow(label: 'Base Currency', value: period.baseCurrency),
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
                    onPressed: () => _showCreateFirstPeriodDialog(context, ref),
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
                    onPressed: () => _showGenerateDialog(context, ref, period),
                    icon: const Icon(Icons.auto_awesome_rounded),
                    label: const Text('Generate Next Period'),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 32),

          // ─── About ────────────────────────────────────────
          _SectionHeader(icon: Icons.info_outline_rounded, title: 'About'),
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
                  'FlatPlan is a local-first budgeting application.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snapshot) {
                    final version = snapshot.hasData
                        ? '${snapshot.data!.version}+${snapshot.data!.buildNumber}'
                        : '...';
                    return Text(
                      'Version: $version',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => launchUrl(
                    Uri.parse('https://www.flaticon.com/free-icons/budget'),
                  ),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.open_in_new_rounded,
                          size: 14,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Budget icons created by Freepik - Flaticon',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.primary,
                            decoration: TextDecoration.underline,
                            decorationColor: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateFirstPeriodDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final result =
        await showDialog<({String name, String currency, DateTime startDate})>(
          context: context,
          builder: (ctx) => const _CreateFirstPeriodDialog(),
        );
    if (result == null || !context.mounted) return;

    final newPeriod = createEmptyPeriod(
      startDate: result.startDate,
      name: result.name,
      baseCurrency: result.currency,
    );

    ref.read(currentPeriodProvider.notifier).setPeriod(newPeriod);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Period "${result.name}" created!')));
  }

  Future<void> _showGenerateDialog(
    BuildContext context,
    WidgetRef ref,
    Period currentPeriod,
  ) async {
    final result = await showDialog<({String name, DateTime startDate})>(
      context: context,
      builder: (ctx) => const _GeneratePeriodDialog(),
    );
    if (result == null || !context.mounted) return;

    final newPeriod = createNextPeriod(
      currentPeriod: currentPeriod,
      newStartDate: result.startDate,
      newName: result.name,
    );

    ref.read(currentPeriodProvider.notifier).setPeriod(newPeriod);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Successfully rolled over to ${result.name}!')),
    );
  }
}

/// Dialog collecting the name, currency, and start date for the first period.
///
/// Owns its [TextEditingController]s so they are disposed only after the
/// dialog's exit animation completes (disposing them right after
/// `showDialog` returns crashes any rebuild during the closing transition).
class _CreateFirstPeriodDialog extends StatefulWidget {
  const _CreateFirstPeriodDialog();

  @override
  State<_CreateFirstPeriodDialog> createState() =>
      _CreateFirstPeriodDialogState();
}

class _CreateFirstPeriodDialogState extends State<_CreateFirstPeriodDialog> {
  final _nameController = TextEditingController();
  final _currencyController = TextEditingController(text: 'EUR');
  DateTime _startDate = DateTime.now();

  @override
  void dispose() {
    _nameController.dispose();
    _currencyController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final currency = _currencyController.text.trim().toUpperCase();
    if (name.isEmpty) return;

    Navigator.pop(context, (
      name: name,
      currency: currency.isEmpty ? 'EUR' : currency,
      startDate: _startDate,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: const Text('Create First Period'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Period Name (e.g. February 2026)',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _currencyController,
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
                    initialDate: _startDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setState(() => _startDate = picked);
                  }
                },
                child: Text(
                  '${_startDate.year}-${_startDate.month}-${_startDate.day}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'End date is computed automatically: 30 days from start, '
                  'or until the next period begins.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _submit, child: const Text('Create')),
      ],
    );
  }
}

/// Dialog collecting the name and start date for the next period.
///
/// Owns its [TextEditingController] so it is disposed only after the
/// dialog's exit animation completes.
class _GeneratePeriodDialog extends StatefulWidget {
  const _GeneratePeriodDialog();

  @override
  State<_GeneratePeriodDialog> createState() => _GeneratePeriodDialogState();
}

class _GeneratePeriodDialogState extends State<_GeneratePeriodDialog> {
  final _nameController = TextEditingController();
  DateTime _startDate = DateTime.now();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    Navigator.pop(context, (name: name, startDate: _startDate));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: const Text('Generate Next Period'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
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
                    initialDate: _startDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setState(() => _startDate = picked);
                  }
                },
                child: Text(
                  '${_startDate.year}-${_startDate.month}-${_startDate.day}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'The previous period will automatically end '
                  'the day before this start date.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _submit, child: const Text('Generate')),
      ],
    );
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
