import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../logic/period_extensions.dart';
import '../logic/period_logic.dart';
import '../models/models.dart';
import '../providers/current_period_provider.dart';
import '../providers/period_notifier_provider.dart';

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
    builder: (ctx) => _GeneratePeriodDialog(templateName: currentPeriod.name),
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

/// Opens the dialog renaming [period] and moving its start date.
///
/// [allPeriods] are the vault's periods: the picker keeps the start date off
/// any of their start days, and the dialog warns when the move would carry
/// [period] past one of them.
Future<void> showEditPeriodDialog(
  BuildContext context,
  WidgetRef ref, {
  required Period period,
  required List<Period> allPeriods,
}) async {
  // Nothing on the dashboard watches this period's notifier. Holding it
  // while the dialog is open lets it load, and keeps it from being
  // disposed under the save below.
  final subscription = ref.listenManual(periodProvider(period.id), (_, _) {});
  try {
    final result = await showDialog<({String name, DateTime startDate})>(
      context: context,
      builder: (ctx) =>
          _EditPeriodDialog(period: period, allPeriods: allPeriods),
    );
    if (result == null || !context.mounted) return;
    if (result.name == period.name &&
        result.startDate.isAtSameMomentAs(period.startDate)) {
      return;
    }

    await ref
        .read(periodProvider(period.id).notifier)
        .updateDetails(name: result.name, startDate: result.startDate);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Period "${result.name}" updated.')));
  } finally {
    subscription.close();
  }
}

/// Dialog collecting a new name and start date for an existing period.
///
/// Owns its [TextEditingController] so it is disposed only after the
/// dialog's exit animation completes.
class _EditPeriodDialog extends StatefulWidget {
  final Period period;
  final List<Period> allPeriods;

  const _EditPeriodDialog({required this.period, required this.allPeriods});

  @override
  State<_EditPeriodDialog> createState() => _EditPeriodDialogState();
}

class _EditPeriodDialogState extends State<_EditPeriodDialog> {
  late final _nameController = TextEditingController(text: widget.period.name);
  late DateTime _startDate = widget.period.startDate;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      // The day already shown stays selectable even if another period
      // shares it, or the picker would refuse to open on it.
      selectableDayPredicate: (day) =>
          wholeDaysBetween(day, _startDate) == 0 ||
          !isStartDateTaken(widget.period, day, widget.allPeriods),
    );
    if (picked == null) return;
    // Re-picking the original day keeps its stored time of day, so the
    // period does not count as changed.
    setState(
      () => _startDate = wholeDaysBetween(widget.period.startDate, picked) == 0
          ? widget.period.startDate
          : picked,
    );
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
    final passed = periodsPassedBy(
      widget.period,
      _startDate,
      widget.allPeriods,
    );

    return AlertDialog(
      title: const Text('Edit Period'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Period Name'),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Start Date: '),
              TextButton(
                onPressed: _pickStartDate,
                child: Text(DateFormat.yMMMd().format(_startDate)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'The previous period will end the day before this start '
                  'date.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          if (passed.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: colorScheme.error,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'This moves the period past ${_quotedNames(passed)}. '
                    'Periods run in start-date order, so the sidebar order '
                    'and the current period may change.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ValueListenableBuilder(
          valueListenable: _nameController,
          builder: (context, value, _) => ElevatedButton(
            onPressed: value.text.trim().isEmpty ? null : _submit,
            child: const Text('Save'),
          ),
        ),
      ],
    );
  }

  /// `"A"`, `"A" and "B"`, `"A", "B" and "C"`.
  static String _quotedNames(List<Period> periods) {
    final names = periods.map((p) => '"${p.name}"').toList();
    if (names.length == 1) return names.single;
    return '${names.sublist(0, names.length - 1).join(', ')} '
        'and ${names.last}';
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
  /// Name of the current period, whose categories and recurring planned
  /// payments seed the new one.
  final String templateName;

  const _GeneratePeriodDialog({required this.templateName});

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.copy_all_rounded,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Categories and recurring planned payments are carried '
                  'over from "${widget.templateName}". One-off payments and '
                  'spending are not.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
