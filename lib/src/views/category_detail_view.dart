import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../components/category_dialog.dart';
import '../components/planned_expense_dialog.dart';
import '../logic/period_extensions.dart';
import '../logic/period_stats.dart';
import '../models/models.dart';
import '../providers/all_periods_provider.dart';
import '../providers/period_notifier_provider.dart';

/// Detailed view for managing a single category's expenses.
///
/// Requires a [periodId] so that mutations target the correct period
/// rather than always operating on the latest one.
class CategoryDetailView extends HookConsumerWidget {
  final String categoryId;
  final String periodId;

  const CategoryDetailView({
    super.key,
    required this.categoryId,
    required this.periodId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Use the period-specific notifier instead of currentPeriodProvider.
    final periodAsync = ref.watch(periodProvider(periodId));
    // Needed to date this period and to read spending history from the
    // periods around it.
    final allPeriods = ref.watch(allPeriodsProvider).value ?? const <Period>[];

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
          context.go('/period/$periodId');
        }
      },
      child: Scaffold(
        body: periodAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err')),
          data: (period) {
            if (period == null) {
              return const Center(child: Text('Period not found.'));
            }

            final category = period.categories
                .where((c) => c.id == categoryId)
                .firstOrNull;
            if (category == null) {
              return const Center(child: Text('Category not found.'));
            }

            // Stats for this specific period, not whichever one is current.
            final catStats = categoryStatsFor(
              category: category,
              period: period,
              endDate: effectiveEndDate(period, allPeriods),
              allPeriods: allPeriods,
              now: DateTime.now(),
            );

            final format = NumberFormat.simpleCurrency(
              name: period.baseCurrency,
            );

            return Column(
              children: [
                // ─── Header ─────────────────────────────────────────
                _buildHeader(
                  context,
                  ref,
                  theme,
                  colorScheme,
                  period,
                  category,
                  catStats,
                  format,
                ),

                // ─── Content ────────────────────────────────────────
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Left: Planned Expenses
                      _buildPlannedExpensesPanel(
                        context,
                        ref,
                        theme,
                        colorScheme,
                        category,
                        format,
                      ),

                      // Right: Fact Expenses & Input
                      _buildFactExpensesPanel(
                        context,
                        ref,
                        theme,
                        colorScheme,
                        category,
                        format,
                        amountController,
                        commentController,
                        amountFocusNode,
                        factScrollController,
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

  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    ColorScheme colorScheme,
    Period period,
    Category category,
    CategoryStats catStats,
    NumberFormat format,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Back button
          Material(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: () => context.go('/period/$periodId'),
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
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      category.type == CategoryType.income
                          ? 'Received: ${format.format(catStats.totalSpent)} / Expected: ${format.format(catStats.limit)}'
                          : 'Spent: ${format.format(catStats.totalSpent)} / Limit: ${format.format(catStats.limit)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (catStats.plannedExceedsLimit) ...[
                      const SizedBox(width: 6),
                      const Tooltip(
                        message: 'Planned expenses exceed the limit',
                        child: Icon(
                          Icons.warning_amber_rounded,
                          size: 16,
                          color: Color(0xFFE0A030),
                        ),
                      ),
                    ],
                  ],
                ),
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
                      onTap: () => showCategoryDialog(
                        context,
                        ref,
                        category,
                        periodId: periodId,
                      ),
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
                  const SizedBox(width: 12),
                  _buildRemainingBadge(
                    theme,
                    colorScheme,
                    category,
                    catStats,
                    format,
                  ),
                ],
              ),
              if (catStats.isDailyAllowance &&
                  catStats.dailyAllowanceAmount != null) ...[
                const SizedBox(height: 8),
                _buildDailyAllowanceRow(theme, colorScheme, period, catStats),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRemainingBadge(
    ThemeData theme,
    ColorScheme colorScheme,
    Category category,
    CategoryStats catStats,
    NumberFormat format,
  ) {
    final isIncome = category.type == CategoryType.income;
    final isSuccess = isIncome && catStats.isOverBudget;
    final isCriticalExpense = !isIncome && catStats.heatPercentage >= 1.05;

    final badgeBgColor = isSuccess
        ? const Color(0xFF6ABF69).withValues(alpha: 0.15)
        : (isCriticalExpense
              ? colorScheme.errorContainer
              : colorScheme.primary.withValues(alpha: 0.15));

    final badgeTextColor = isSuccess
        ? const Color(0xFF6ABF69)
        : (isCriticalExpense
              ? colorScheme.onErrorContainer
              : colorScheme.primary);

    final text = isSuccess
        ? 'Extra: ${format.format(catStats.remaining.abs())}'
        : 'Remaining: ${format.format(catStats.remaining)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
  }

  Widget _buildDailyAllowanceRow(
    ThemeData theme,
    ColorScheme colorScheme,
    Period period,
    CategoryStats catStats,
  ) {
    final roundedFormat = NumberFormat.simpleCurrency(
      name: period.baseCurrency,
      decimalDigits: 0,
    );
    final basket = catStats.basket;
    final trend = catStats.trend;
    final typical = catStats.typical;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              basket != null
                  ? '${roundedFormat.format(basket.safeBasket)} safe per shop · ${roundedFormat.format(catStats.dailyAllowanceAmount)} / day left'
                  : '${roundedFormat.format(catStats.dailyAllowanceAmount)} / day left',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        if (basket != null) ...[
          const SizedBox(height: 6),
          Text(
            'Reserved for small purchases: '
            '${roundedFormat.format(basket.snackReserve)} '
            '(${(basket.stats.snackShare * 100).round()}% historically)',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            // One decimal, not a rounded count: this screen exists so the
            // safe-per-shop figure can be checked by hand, and the headline
            // divides by the unrounded trips left. Rounding here made the
            // two disagree by as much as 40%. A decimal count takes the
            // plural, so "1.0 shops" is correct; the stray singular only
            // ever came from the rounding.
            'Left for shops: ${roundedFormat.format(basket.basketBudget)} '
            'across ${basket.tripsLeft.toStringAsFixed(1)} shops, '
            '${_cadenceSentence(basket.stats.tripSpacingDays)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            'Usual shop ${roundedFormat.format(basket.stats.usualBasket)}, '
            'from the last ${basket.stats.periodsUsed} periods',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (basket == null && typical != null) ...[
          const SizedBox(height: 6),
          Text(
            'A typical purchase is ${roundedFormat.format(typical.amount)}; '
            'the budget left affords one every '
            '${typical.everyDays == 1 ? 'day' : '${typical.everyDays} days'} '
            '(from ${typical.purchasesUsed} past purchases)',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (trend != null) ...[
          const SizedBox(height: 6),
          Text(
            'Averaging ${roundedFormat.format(trend.recentDailyRate)} / day '
            'last period — projected ${roundedFormat.format(trend.projectedTotal)}'
            '${trend.isOverProjected ? ', ${roundedFormat.format(trend.overshoot)} over budget' : ', within budget'}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: trend.isOverProjected
                  ? colorScheme.error
                  : colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPlannedExpensesPanel(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    ColorScheme colorScheme,
    Category category,
    NumberFormat format,
  ) {
    return Expanded(
      flex: 1,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 20),
              child: Row(
                children: [
                  Icon(
                    Icons.checklist_rounded,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      category.type == CategoryType.income
                          ? 'Planned Incomes'
                          : 'Planned Expenses',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Material(
                    color: colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: () => showPlannedExpenseDialog(
                        context,
                        ref,
                        categoryId,
                        null,
                        periodId: periodId,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          Icons.add_rounded,
                          size: 18,
                          color: colorScheme.primary,
                        ),
                      ),
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
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: category.plannedExpenses.length,
                      itemBuilder: (context, index) {
                        final planned = category.plannedExpenses[index];
                        final periodicityLabel = formatDueDate(planned.dueDate);

                        return _buildPlannedExpenseRow(
                          context,
                          ref,
                          theme,
                          colorScheme,
                          planned,
                          periodicityLabel,
                          format,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlannedExpenseRow(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    ColorScheme colorScheme,
    PlannedExpense planned,
    String periodicityLabel,
    NumberFormat format,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: planned.isCompleted
            ? colorScheme.primary.withValues(alpha: 0.06)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            ref
                .read(periodProvider(periodId).notifier)
                .togglePlannedExpense(categoryId, planned.id);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: planned.isCompleted,
                    onChanged: (_) {
                      ref
                          .read(periodProvider(periodId).notifier)
                          .togglePlannedExpense(categoryId, planned.id);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        planned.description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                          decoration: planned.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            format.format(planned.amount),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.schedule_rounded,
                            size: 12,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.7,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              periodicityLabel,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Edit button
                IconButton(
                  icon: Icon(
                    Icons.edit_rounded,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  tooltip: 'Edit',
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: () => showPlannedExpenseDialog(
                    context,
                    ref,
                    categoryId,
                    planned,
                    periodId: periodId,
                  ),
                ),
                // Remove button
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: colorScheme.error.withValues(alpha: 0.7),
                  ),
                  tooltip: 'Remove',
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Remove Planned Expense?'),
                        content: Text(
                          'This will remove "${planned.description}" and any linked actual record.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Remove'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      ref
                          .read(periodProvider(periodId).notifier)
                          .removePlannedExpense(categoryId, planned.id);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFactExpensesPanel(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    ColorScheme colorScheme,
    Category category,
    NumberFormat format,
    TextEditingController amountController,
    TextEditingController commentController,
    FocusNode amountFocusNode,
    ScrollController factScrollController,
  ) {
    return Expanded(
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
                    style: theme.textTheme.titleMedium?.copyWith(
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
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: factScrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: category.factExpenses.length,
                    itemBuilder: (context, index) {
                      final fact = category.factExpenses[index];
                      return ListTile(
                        title: Text(
                          format.format(fact.amount),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          fact.description ?? 'No comment',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: colorScheme.error.withValues(alpha: 0.7),
                          ),
                          tooltip: category.type == CategoryType.income
                              ? 'Remove income'
                              : 'Remove expense',
                          onPressed: () {
                            ref
                                .read(periodProvider(periodId).notifier)
                                .removeFactExpense(categoryId, fact.id);
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
                top: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
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
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Amount'),
                    onSubmitted: (_) {
                      _submitExpense(
                        ref,
                        amountController,
                        commentController,
                        scrollController: factScrollController,
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
                      labelText: 'Comment / Merchant (Optional)',
                    ),
                    onSubmitted: (_) {
                      _submitExpense(
                        ref,
                        amountController,
                        commentController,
                        scrollController: factScrollController,
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
        .read(periodProvider(periodId).notifier)
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

/// "one every day", "one every 2 days", "one every 2.5 days" — a decimal
/// only when the cadence is not a whole number of days, so a one-day
/// cadence does not read as "one every 1.0 days".
String _cadenceSentence(double days) {
  if (days == 1) return 'one every day';
  final text = days == days.roundToDouble()
      ? days.toStringAsFixed(0)
      : days.toStringAsFixed(1);
  return 'one every $text days';
}
