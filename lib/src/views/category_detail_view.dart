import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../components/category_dialog.dart';
import '../models/models.dart';
import '../providers/current_period_provider.dart';
import '../providers/period_stats_provider.dart';

/// Detailed view for managing a single category's expenses.
class CategoryDetailView extends HookConsumerWidget {
  final String categoryId;

  const CategoryDetailView({super.key, required this.categoryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final currentPeriodAsync = ref.watch(currentPeriodProvider);
    final statsAsync = ref.watch(periodStatsProvider);

    final amountController = useTextEditingController();
    final commentController = useTextEditingController();
    final amountFocusNode = useFocusNode();
    final factScrollController = useScrollController();

    // Auto-focus the amount field when the page loads.
    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        amountFocusNode.requestFocus();
      });
      return null;
    }, const []);

    return KeyboardListener(
      focusNode: useFocusNode(),
      autofocus: false,
      onKeyEvent: (event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          context.go('/');
        }
      },
      child: Scaffold(
        body: currentPeriodAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err')),
          data: (period) {
            if (period == null) {
              return const Center(child: Text('No active period.'));
            }

            final category = period.categories
                .where((c) => c.id == categoryId)
                .firstOrNull;
            if (category == null) {
              return const Center(child: Text('Category not found.'));
            }

            final stats = statsAsync.value;
            CategoryStats? catStats;
            if (stats != null) {
              catStats = stats.categoryStats
                  .where((c) => c.categoryId == categoryId)
                  .firstOrNull;
            }

            final format = NumberFormat.simpleCurrency(
              name: period.baseCurrency,
            );

            return Column(
              children: [
                // ─── Header ─────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    border: Border(
                      bottom: BorderSide(
                        color: colorScheme.outlineVariant,
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Back button
                      Material(
                        color: colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          onTap: () => context.go('/'),
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Icon(
                              Icons.arrow_back_rounded,
                              size: 20,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Title & subtitle
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              category.name,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            if (catStats != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                category.type == CategoryType.income
                                    ? 'Received: ${format.format(catStats.totalSpent)} / Expected: ${format.format(catStats.limit)}'
                                    : 'Spent: ${format.format(catStats.totalSpent)} / Limit: ${format.format(catStats.limit)}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Actions & Remaining badge
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Edit button
                              Material(
                                color: colorScheme.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(10),
                                child: InkWell(
                                  onTap: () =>
                                      showCategoryDialog(context, ref, category),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Icon(
                                      Icons.edit_rounded,
                                      size: 20,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                              ),
                              if (catStats != null) ...[
                                const SizedBox(width: 12),
                                Builder(
                                  builder: (context) {
                                    final stats = catStats!;
                                    final isIncome = category.type == CategoryType.income;
                                    final isSuccess = isIncome && stats.isOverBudget;
                                    
                                    final badgeBgColor = isSuccess 
                                        ? const Color(0xFF6ABF69).withValues(alpha: 0.15)
                                        : (stats.isOverBudget
                                            ? colorScheme.errorContainer
                                            : colorScheme.primary.withValues(alpha: 0.15));
                                    
                                    final badgeTextColor = isSuccess
                                        ? const Color(0xFF6ABF69)
                                        : (stats.isOverBudget
                                            ? colorScheme.onErrorContainer
                                            : colorScheme.primary);
                                    
                                    final text = isSuccess
                                        ? 'Extra: ${format.format(stats.remaining.abs())}'
                                        : 'Remaining: ${format.format(stats.remaining)}';
                                    
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: badgeBgColor,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        text,
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          color: badgeTextColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ],
                          ),
                          if (catStats != null &&
                              catStats.isDailyAllowance &&
                              catStats.dailyAllowanceAmount != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.today_rounded,
                                  size: 14,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${format.format(catStats.dailyAllowanceAmount)} / day left',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // ─── Content ────────────────────────────────────────
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Left: Planned Expenses
                      Expanded(
                        flex: 1,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border(
                              right: BorderSide(
                                color: colorScheme.outlineVariant,
                                width: 0.5,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(20),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.checklist_rounded,
                                      size: 18,
                                      color: colorScheme.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      category.type == CategoryType.income
                                          ? 'Planned Incomes'
                                          : 'Planned Expenses',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: colorScheme.onSurface,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: category.plannedExpenses.isEmpty
                                    ? Center(
                                        child: Text(
                                          category.type == CategoryType.income
                                              ? 'No planned incomes.'
                                              : 'No planned expenses.',
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                color: colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                        ),
                                      )
                                    : ListView.builder(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        itemCount:
                                            category.plannedExpenses.length,
                                        itemBuilder: (context, index) {
                                          final planned =
                                              category.plannedExpenses[index];
                                          return CheckboxListTile(
                                            title: Text(planned.description),
                                            subtitle: Text(
                                              format.format(planned.amount),
                                            ),
                                            value: planned.isCompleted,
                                            onChanged: (val) {
                                              ref
                                                  .read(
                                                    currentPeriodProvider
                                                        .notifier,
                                                  )
                                                  .togglePlannedExpense(
                                                    categoryId,
                                                    planned.id,
                                                  );
                                            },
                                          );
                                        },
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Right: Fact Expenses & Input
                      Expanded(
                        flex: 2,
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.receipt_long_rounded,
                                      size: 18,
                                      color: colorScheme.secondary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      category.type == CategoryType.income
                                          ? 'Actual Income'
                                          : 'Actual Spending',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: colorScheme.onSurface,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Expanded(
                              child: category.factExpenses.isEmpty
                                  ? Center(
                                      child: Text(
                                        category.type == CategoryType.income
                                            ? 'No actual income yet.'
                                            : 'No actual spending yet.',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                      ),
                                    )
                                  : ListView.builder(
                                      controller: factScrollController,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      itemCount: category.factExpenses.length,
                                      itemBuilder: (context, index) {
                                        final fact =
                                            category.factExpenses[index];
                                        return ListTile(
                                          title: Text(
                                            format.format(fact.amount),
                                            style: theme.textTheme.bodyLarge
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                          subtitle: Text(
                                            fact.description ?? 'No comment',
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                          ),
                                          trailing: IconButton(
                                            icon: Icon(
                                              Icons.close_rounded,
                                              size: 18,
                                              color: colorScheme.error
                                                  .withValues(alpha: 0.7),
                                            ),
                                            tooltip:
                                                category.type ==
                                                    CategoryType.income
                                                ? 'Remove income'
                                                : 'Remove expense',
                                            onPressed: () {
                                              ref
                                                  .read(
                                                    currentPeriodProvider
                                                        .notifier,
                                                  )
                                                  .removeFactExpense(
                                                    categoryId,
                                                    fact.id,
                                                  );
                                            },
                                          ),
                                        );
                                      },
                                    ),
                            ),

                            // Quick action input row
                            Container(
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerLow,
                                border: Border(
                                  top: BorderSide(
                                    color: colorScheme.outlineVariant,
                                    width: 0.5,
                                  ),
                                ),
                              ),
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 1,
                                    child: TextField(
                                      controller: amountController,
                                      focusNode: amountFocusNode,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      decoration: const InputDecoration(
                                        labelText: 'Amount',
                                      ),
                                      onSubmitted: (_) {
                                        _submitExpense(
                                          ref,
                                          amountController,
                                          commentController,
                                          scrollController:
                                              factScrollController,
                                        );
                                        amountFocusNode.requestFocus();
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 2,
                                    child: TextField(
                                      controller: commentController,
                                      decoration: const InputDecoration(
                                        labelText:
                                            'Comment / Merchant (Optional)',
                                      ),
                                      onSubmitted: (_) {
                                        _submitExpense(
                                          ref,
                                          amountController,
                                          commentController,
                                          scrollController:
                                              factScrollController,
                                        );
                                        amountFocusNode.requestFocus();
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  FloatingActionButton.small(
                                    onPressed: () => _submitExpense(
                                      ref,
                                      amountController,
                                      commentController,
                                      scrollController: factScrollController,
                                    ),
                                    child: const Icon(Icons.add_rounded),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _submitExpense(
    WidgetRef ref,
    TextEditingController amountCtrl,
    TextEditingController commentCtrl, {
    ScrollController? scrollController,
  }) {
    final text = amountCtrl.text.replaceAll(',', '.');
    final amount = double.tryParse(text);
    if (amount == null || amount <= 0) return;

    final comment = commentCtrl.text.trim();

    final expense = FactExpense(
      id: const Uuid().v4(),
      amount: amount,
      description: comment.isEmpty ? null : comment,
      timestamp: DateTime.now(),
    );

    ref
        .read(currentPeriodProvider.notifier)
        .addFactExpense(categoryId, expense);

    amountCtrl.clear();
    commentCtrl.clear();

    // Scroll to the bottom after the list rebuilds.
    if (scrollController != null && scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      });
    }
  }
}
