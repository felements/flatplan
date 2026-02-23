import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import '../providers/period_notifier_provider.dart';

/// Helper to format a [DueDate] for display.
String formatDueDate(DueDate dueDate) {
  return dueDate.when(
    exact: (date) => '${date.day} ${_monthName(date.month)} ${date.year}',
    dayOfMonth: (day) => '${_ordinal(day)} of month',
    dayOfWeek: (weekday) => 'Every ${_weekdayName(weekday)}',
  );
}

String _monthName(int month) {
  const months = [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return months[month];
}

String _weekdayName(int weekday) {
  const days = [
    '',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  return days[weekday];
}

String _ordinal(int day) {
  if (day >= 11 && day <= 13) return '${day}th';
  return switch (day % 10) {
    1 => '${day}st',
    2 => '${day}nd',
    3 => '${day}rd',
    _ => '${day}th',
  };
}

enum _DueDateType { exact, dayOfMonth, dayOfWeek }

/// Shows a dialog for adding or editing a planned expense.
///
/// The [periodId] determines which period's notifier receives the mutation.
void showPlannedExpenseDialog(
  BuildContext context,
  WidgetRef ref,
  String categoryId,
  PlannedExpense? existing, {
  required String periodId,
}) {
  final isEditing = existing != null;
  final descCtrl = TextEditingController(text: existing?.description ?? '');
  final amountCtrl = TextEditingController(
    text: existing != null ? existing.amount.toStringAsFixed(2) : '',
  );

  // Determine initial due date type and value from existing.
  _DueDateType dueDateType = _DueDateType.dayOfMonth;
  DateTime? exactDate;
  int dayOfMonth = 1;
  int dayOfWeek = 1; // Monday

  if (existing != null) {
    existing.dueDate.when(
      exact: (date) {
        dueDateType = _DueDateType.exact;
        exactDate = date;
      },
      dayOfMonth: (day) {
        dueDateType = _DueDateType.dayOfMonth;
        dayOfMonth = day;
      },
      dayOfWeek: (weekday) {
        dueDateType = _DueDateType.dayOfWeek;
        dayOfWeek = weekday;
      },
    );
  }

  final dayOfMonthCtrl = TextEditingController(text: dayOfMonth.toString());

  showDialog(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setState) {
          final theme = Theme.of(context);
          final colorScheme = theme.colorScheme;

          return AlertDialog(
            title: Text(
              isEditing ? 'Edit Planned Expense' : 'New Planned Expense',
            ),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'e.g. Rent, Insurance',
                      ),
                      autofocus: true,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        hintText: 'e.g. 150.00',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Due Date',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<_DueDateType>(
                      segments: const [
                        ButtonSegment(
                          value: _DueDateType.dayOfMonth,
                          label: Text('Day of Month'),
                        ),
                        ButtonSegment(
                          value: _DueDateType.dayOfWeek,
                          label: Text('Day of Week'),
                        ),
                        ButtonSegment(
                          value: _DueDateType.exact,
                          label: Text('Exact Date'),
                        ),
                      ],
                      selected: {dueDateType},
                      onSelectionChanged: (sel) {
                        setState(() => dueDateType = sel.first);
                      },
                    ),
                    const SizedBox(height: 12),

                    // Due date value input
                    if (dueDateType == _DueDateType.dayOfMonth)
                      TextField(
                        controller: dayOfMonthCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Day (1-31)',
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (val) {
                          final parsed = int.tryParse(val);
                          if (parsed != null && parsed >= 1 && parsed <= 31) {
                            dayOfMonth = parsed;
                          }
                        },
                      ),
                    if (dueDateType == _DueDateType.dayOfWeek)
                      DropdownMenu<int>(
                        initialSelection: dayOfWeek,
                        label: const Text('Weekday'),
                        onSelected: (val) {
                          if (val != null) {
                            setState(() => dayOfWeek = val);
                          }
                        },
                        dropdownMenuEntries: const [
                          DropdownMenuEntry(value: 1, label: 'Monday'),
                          DropdownMenuEntry(value: 2, label: 'Tuesday'),
                          DropdownMenuEntry(value: 3, label: 'Wednesday'),
                          DropdownMenuEntry(value: 4, label: 'Thursday'),
                          DropdownMenuEntry(value: 5, label: 'Friday'),
                          DropdownMenuEntry(value: 6, label: 'Saturday'),
                          DropdownMenuEntry(value: 7, label: 'Sunday'),
                        ],
                      ),
                    if (dueDateType == _DueDateType.exact)
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: exactDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() => exactDate = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Date'),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                exactDate != null
                                    ? '${exactDate!.day}/${exactDate!.month}/${exactDate!.year}'
                                    : 'Select a date',
                                style: theme.textTheme.bodyLarge,
                              ),
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 18,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final description = descCtrl.text.trim();
                  if (description.isEmpty) return;

                  final amount = double.tryParse(
                    amountCtrl.text.replaceAll(',', '.'),
                  );
                  if (amount == null || amount <= 0) return;

                  // Build DueDate
                  final DueDate dueDate;
                  switch (dueDateType) {
                    case _DueDateType.exact:
                      if (exactDate == null) return;
                      dueDate = DueDate.exact(date: exactDate!);
                    case _DueDateType.dayOfMonth:
                      final d = int.tryParse(dayOfMonthCtrl.text) ?? dayOfMonth;
                      if (d < 1 || d > 31) return;
                      dueDate = DueDate.dayOfMonth(day: d);
                    case _DueDateType.dayOfWeek:
                      dueDate = DueDate.dayOfWeek(weekday: dayOfWeek);
                  }

                  final notifier = ref.read(
                    periodProvider(periodId).notifier,
                  );

                  if (isEditing) {
                    notifier.updatePlannedExpense(
                      categoryId,
                      existing.copyWith(
                        description: description,
                        amount: amount,
                        dueDate: dueDate,
                      ),
                    );
                  } else {
                    notifier.addPlannedExpense(
                      categoryId,
                      PlannedExpense(
                        id: const Uuid().v4(),
                        description: description,
                        amount: amount,
                        dueDate: dueDate,
                      ),
                    );
                  }

                  Navigator.pop(ctx);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isEditing
                            ? 'Planned expense "$description" updated'
                            : 'Planned expense "$description" added',
                      ),
                    ),
                  );
                },
                child: Text(isEditing ? 'Save' : 'Add'),
              ),
            ],
          );
        },
      );
    },
  );
}
