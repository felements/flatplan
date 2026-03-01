import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../components/category_dialog.dart';
import '../models/models.dart';
import '../providers/period_notifier_provider.dart';

/// Full-page editor for managing a specific period's categories.
///
/// Requires a [periodId] so that mutations target the correct period.
class CategoryEditorView extends ConsumerWidget {
  final String periodId;

  const CategoryEditorView({super.key, required this.periodId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final periodAsync = ref.watch(periodProvider(periodId));

    return Scaffold(
      body: periodAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (period) {
          if (period == null) {
            return Center(
              child: Text(
                'Period not found.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }

          final categories = period.categories;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Header bar ─────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => context.go('/period/$periodId'),
                      icon: const Icon(Icons.arrow_back_rounded),
                      tooltip: 'Back to Period',
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Manage Categories',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            period.name,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => showCategoryDialog(
                        context,
                        ref,
                        null,
                        periodId: periodId,
                      ),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add Category'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  '${categories.length} categor${categories.length == 1 ? 'y' : 'ies'} configured',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ─── Category list ──────────────────────────────
              Expanded(
                child: categories.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.category_rounded,
                              size: 48,
                              color: colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.4,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No categories yet',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tap "Add Category" to get started.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                        itemCount: categories.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final cat = categories[index];
                          return _CategoryCard(
                            category: cat,
                            onEdit: () => showCategoryDialog(
                              context,
                              ref,
                              cat,
                              periodId: periodId,
                            ),
                            onDelete: () => _confirmDelete(context, ref, cat),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ─── Delete confirmation ────────────────────────────────────────

  void _confirmDelete(BuildContext context, WidgetRef ref, Category category) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Delete Category'),
          content: Text(
            'Are you sure you want to delete "${category.name}"? '
            'All planned and recorded ${category.type == CategoryType.income ? "incomes" : "expenses"} in this category will be lost.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: () {
                ref
                    .read(periodProvider(periodId).notifier)
                    .removeCategory(category.id);
                Navigator.pop(ctx);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Category "${category.name}" deleted'),
                  ),
                );
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}

// ─── Category card widget ──────────────────────────────────────────

class _CategoryCard extends StatelessWidget {
  final Category category;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CategoryCard({
    required this.category,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(16),
          hoverColor: colorScheme.primary.withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Scope badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: category.type == CategoryType.mandatoryExpense
                        ? colorScheme.error.withValues(alpha: 0.15)
                        : category.type == CategoryType.income
                        ? const Color(0xFF6ABF69).withValues(alpha: 0.15)
                        : colorScheme.secondary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    category.type == CategoryType.mandatoryExpense
                        ? 'Mandatory'
                        : category.type == CategoryType.income
                        ? 'Income'
                        : 'Optional',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: category.type == CategoryType.mandatoryExpense
                          ? colorScheme.error
                          : category.type == CategoryType.income
                          ? const Color(0xFF6ABF69)
                          : colorScheme.secondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // Name + description
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      if (category.description != null &&
                          category.description!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            category.description!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),

                // Limit badge
                if (category.limit != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${category.limit!.toStringAsFixed(0)} ${category.type == CategoryType.income ? "expected" : "limit"}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                // Daily allowance indicator
                if (category.isDailyAllowance) ...[
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Daily allowance enabled',
                    child: Icon(
                      Icons.today_rounded,
                      size: 18,
                      color: colorScheme.secondary,
                    ),
                  ),
                ],

                const SizedBox(width: 8),

                // Planned expense count
                Tooltip(
                  message:
                      '${category.plannedExpenses.length} planned ${category.type == CategoryType.income ? "income(s)" : "expense(s)"}',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.checklist_rounded,
                        size: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${category.plannedExpenses.length}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Delete button
                IconButton(
                  onPressed: onDelete,
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: colorScheme.error.withValues(alpha: 0.7),
                    size: 20,
                  ),
                  tooltip: 'Delete category',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
