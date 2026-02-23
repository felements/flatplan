import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/category.dart';
import '../providers/current_period_provider.dart';

/// Shows a dialog or full-page editor for managing a category.
void showCategoryDialog(
  BuildContext context,
  WidgetRef ref,
  Category? existing,
) {
  final isEditing = existing != null;
  final nameCtrl = TextEditingController(text: existing?.name ?? '');
  final descCtrl = TextEditingController(text: existing?.description ?? '');
  final limitCtrl = TextEditingController(
    text: existing?.limit?.toStringAsFixed(2) ?? '',
  );
  var isMandatory = existing?.isMandatory ?? true;
  var isDailyAllowance = existing?.isDailyAllowance ?? false;

  showDialog(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setState) {
          final theme = Theme.of(context);
          final colorScheme = theme.colorScheme;

          return AlertDialog(
            title: Text(isEditing ? 'Edit Category' : 'New Category'),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Category Name',
                        hintText: 'e.g. Groceries, Rent',
                      ),
                      autofocus: true,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Description (optional)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: limitCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Spending Limit (optional)',
                        hintText: 'e.g. 500.00',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: Text(
                        'Mandatory',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface,
                        ),
                      ),
                      subtitle: Text(
                        'Mandatory expenses are deducted before calculating free budget.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      value: isMandatory,
                      onChanged: (v) => setState(() => isMandatory = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                    SwitchListTile(
                      title: Text(
                        'Daily Allowance',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface,
                        ),
                      ),
                      subtitle: Text(
                        'Show per-day remaining budget for this category.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      value: isDailyAllowance,
                      onChanged: (v) => setState(() => isDailyAllowance = v),
                      contentPadding: EdgeInsets.zero,
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
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;

                  final limit = double.tryParse(limitCtrl.text.trim());
                  final desc = descCtrl.text.trim();

                  final notifier = ref.read(currentPeriodProvider.notifier);

                  if (isEditing) {
                    notifier.updateCategory(
                      existing.copyWith(
                        name: name,
                        description: desc.isEmpty ? null : desc,
                        isMandatory: isMandatory,
                        limit: limit,
                        isDailyAllowance: isDailyAllowance,
                      ),
                    );
                  } else {
                    notifier.addCategory(
                      Category(
                        id: const Uuid().v4(),
                        name: name,
                        description: desc.isEmpty ? null : desc,
                        isMandatory: isMandatory,
                        limit: limit,
                        isDailyAllowance: isDailyAllowance,
                      ),
                    );
                  }

                  Navigator.pop(ctx);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isEditing
                            ? 'Category "$name" updated'
                            : 'Category "$name" added',
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
