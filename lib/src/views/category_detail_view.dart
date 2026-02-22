import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import '../providers/current_period_provider.dart';
import '../providers/period_stats_provider.dart';

class CategoryDetailView extends HookConsumerWidget {
  final String categoryId;

  const CategoryDetailView({super.key, required this.categoryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var theme = Theme.of(context);
    
    final currentPeriodAsync = ref.watch(currentPeriodProvider);
    final statsAsync = ref.watch(periodStatsProvider);

    final amountController = useTextEditingController();
    final commentController = useTextEditingController();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Category Detail'),
        leading: BackButton(
          onPressed: () => context.go('/'),
        ),
      ),
      body: currentPeriodAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (period) {
          if (period == null) return const Center(child: Text('No active period.'));

          final category = period.categories.where((c) => c.id == categoryId).firstOrNull;
          if (category == null) return const Center(child: Text('Category not found.'));

          final stats = statsAsync.value;
          CategoryStats? catStats;
          if (stats != null) {
            catStats = stats.categoryStats.where((c) => c.categoryId == categoryId).firstOrNull;
          }

          final format = NumberFormat.simpleCurrency(name: period.baseCurrency);

          return Column(
            children: [
              // Top Summary
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(category.name, style: theme.textTheme.headlineLarge),
                          const SizedBox(height: 8),
                          if (catStats != null)
                             Text(
                               'Spent: ${format.format(catStats.totalSpent)} / Limit: ${format.format(catStats.limit)}',
                               style: theme.textTheme.titleMedium,
                             ),
                        ],
                      ),
                    ),
                    if (catStats != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: catStats.isOverBudget ? theme.colorScheme.errorContainer : theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Remaining: ${format.format(catStats.remaining)}',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: catStats.isOverBudget ? theme.colorScheme.onErrorContainer : theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Expanding layout for lists
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Left Column: Planned Expenses
                    Expanded(
                      flex: 1,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(right: BorderSide(color: theme.dividerColor)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text('Planned Expenses', style: theme.textTheme.titleLarge),
                            ),
                            Expanded(
                              child: category.plannedExpenses.isEmpty
                                ? const Center(child: Text('No planned expenses.'))
                                : ListView.builder(
                                    itemCount: category.plannedExpenses.length,
                                    itemBuilder: (context, index) {
                                      final planned = category.plannedExpenses[index];
                                      return CheckboxListTile(
                                        title: Text(planned.description),
                                        subtitle: Text(format.format(planned.amount)),
                                        value: planned.isCompleted,
                                        onChanged: (val) {
                                          ref.read(currentPeriodProvider.notifier).togglePlannedExpense(categoryId, planned.id);
                                        },
                                      );
                                    },
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Right Column: Fact Expenses & Input
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text('Actual Spending', style: theme.textTheme.titleLarge)
                            ),
                          ),
                          Expanded(
                            child: category.factExpenses.isEmpty
                              ? const Center(child: Text('No actual spending yet.'))
                              : ListView.builder(
                                  itemCount: category.factExpenses.length,
                                  itemBuilder: (context, index) {
                                    // Reverse order logic for visually newest at bottom, or sort if needed
                                    // For now iterate normally as they are added
                                    final fact = category.factExpenses[index];
                                    return ListTile(
                                      title: Text(format.format(fact.amount)),
                                      subtitle: Text(fact.description ?? 'No comment'),
                                      // Add swipe to delete feature if desired later
                                    );
                                  },
                                ),
                          ),

                          // Quick Action Row
                          Material(
                            elevation: 8,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 1,
                                    child: TextField(
                                      controller: amountController,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: const InputDecoration(
                                        labelText: 'Amount',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    flex: 2,
                                    child: TextField(
                                      controller: commentController,
                                      decoration: const InputDecoration(
                                        labelText: 'Comment / Merchant (Optional)',
                                        border: OutlineInputBorder(),
                                      ),
                                      onSubmitted: (_) => _submitExpense(ref, amountController, commentController),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  FloatingActionButton(
                                    onPressed: () => _submitExpense(ref, amountController, commentController),
                                    child: const Icon(Icons.add),
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
              ),
            ],
          );
        },
      ),
    );
  }

  void _submitExpense(WidgetRef ref, TextEditingController amountCtrl, TextEditingController commentCtrl) {
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

    ref.read(currentPeriodProvider.notifier).addFactExpense(categoryId, expense);

    amountCtrl.clear();
    commentCtrl.clear();
  }
}
