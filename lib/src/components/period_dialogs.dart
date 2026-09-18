import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../logic/period_logic.dart';
import '../models/models.dart';
import '../providers/current_period_provider.dart';

/// Opens the period-creation flow for the open vault.
///
/// With no current period the vault is empty, so the first-period dialog
/// (name, currency, start date) is shown; otherwise the next period is
/// generated from the current one by rollover.
Future<void> showNewPeriodDialog(BuildContext context, WidgetRef ref) {
  final current = ref.read(currentPeriodProvider).value;
  return current == null
      ? _showCreateFirstPeriodDialog(context, ref)
      : _showGenerateDialog(context, ref, current);
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
