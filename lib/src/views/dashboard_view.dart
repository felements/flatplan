import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../app_theme.dart';
import '../components/category_tile.dart';
import '../components/summary_card.dart';
import '../providers/all_periods_provider.dart';
import '../providers/current_period_provider.dart';
import '../providers/period_stats_provider.dart';
import '../models/models.dart';

/// The main dashboard showing period summary and category breakdown.
class DashboardView extends ConsumerWidget {
  /// When non-null, displays a historical period rather than the current one.
  final String? periodId;

  const DashboardView({super.key, this.periodId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // When viewing a historical period, load it from allPeriodsProvider
    // instead of currentPeriodProvider.
    final AsyncValue<Period?> periodAsync;
    if (periodId != null) {
      periodAsync = ref
          .watch(allPeriodsProvider)
          .whenData(
            (periods) => periods.cast<Period?>().firstWhere(
              (p) => p!.id == periodId,
              orElse: () => null,
            ),
          );
    } else {
      periodAsync = ref.watch(currentPeriodProvider);
    }

    final statsAsync = ref.watch(periodStatsProvider);

    return Scaffold(
      body: periodAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (period) {
          if (period == null) {
            return _buildEmptyState(context);
          }

          // For current period use the existing stats provider;
          // for historical periods compute stats inline.
          final PeriodStats? stats;
          if (periodId != null) {
            stats = _computeStats(period);
          } else {
            stats = statsAsync.value;
          }
          if (stats == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final currencyFormatter = NumberFormat.simpleCurrency(
            name: period.baseCurrency,
          );

          final mandatoryCategories = stats.categoryStats
              .where((c) => c.type == CategoryType.mandatoryExpense)
              .toList();
          final optionalCategories = stats.categoryStats
              .where((c) => c.type == CategoryType.optionalExpense)
              .toList();
          final incomeCategories = stats.categoryStats
              .where((c) => c.type == CategoryType.income)
              .toList();

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
            child: ListView(
              children: [
                // ─── Header ───────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome Back',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            period.name,
                            style: theme.textTheme.headlineLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${DateFormat('MMM d').format(period.startDate)} - ${DateFormat('MMM d').format(period.endDate)} • ${period.endDate.difference(DateTime.now()).inDays + 1} days remaining',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          // TODO: Implement trigger rollover
                        },
                        icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                        label: const Text('Next Period'),
                      ),
                    ],
                  ),
                ),

                // ─── Summary Cards ────────────────────────────────
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    SizedBox(
                      width: 260,
                      child: SummaryCard(
                        title: 'Total Budget',
                        amount: currencyFormatter.format(stats.totalBudget),
                        icon: Icons.account_balance_wallet_rounded,
                        color: colorScheme.primary,
                        backgroundColor: AppTheme.cardGold,
                      ),
                    ),
                    SizedBox(
                      width: 260,
                      child: SummaryCard(
                        title: 'Total Spent',
                        amount: currencyFormatter.format(stats.totalSpent),
                        icon: Icons.shopping_cart_rounded,
                        color: colorScheme.secondary,
                        backgroundColor: AppTheme.cardTeal,
                      ),
                    ),
                    SizedBox(
                      width: 260,
                      child: SummaryCard(
                        title: 'Remaining',
                        amount: currencyFormatter.format(
                          stats.overallRemaining.clamp(0, double.infinity),
                        ),
                        icon: Icons.savings_rounded,
                        color: const Color(0xFF6ABF69),
                        backgroundColor: AppTheme.cardGreen,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 36),

                // ─── Categories ───────────────────────────────────
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 800;

                    final mandatorySection = _buildCategorySection(
                      context,
                      'Mandatory Expenses',
                      Icons.lock_rounded,
                      mandatoryCategories,
                      currencyFormatter,
                    );
                    final optionalSection = _buildCategorySection(
                      context,
                      'Optional Living Pool',
                      Icons.spa_rounded,
                      optionalCategories,
                      currencyFormatter,
                    );

                    final incomeSection = _buildCategorySection(
                      context,
                      'Incomes',
                      Icons.arrow_downward_rounded,
                      incomeCategories,
                      currencyFormatter,
                    );

                    if (isWide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                mandatorySection,
                                if (incomeCategories.isNotEmpty)
                                  const SizedBox(height: 24),
                                incomeSection,
                              ],
                            ),
                          ),
                          const SizedBox(width: 32),
                          Expanded(child: optionalSection),
                        ],
                      );
                    } else {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          mandatorySection,
                          const SizedBox(height: 24),
                          optionalSection,
                          if (incomeCategories.isNotEmpty)
                            const SizedBox(height: 24),
                          incomeSection,
                        ],
                      );
                    }
                  },
                ),

                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Empty-state when no period exists.
  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.account_balance_wallet_outlined,
              size: 40,
              color: colorScheme.primary.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Welcome to FlatPlan',
            style: theme.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'No active tracking period found.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => GoRouter.of(context).go('/settings'),
            icon: const Icon(Icons.settings_rounded),
            label: const Text('Go to Settings to Generate Period'),
          ),
        ],
      ),
    );
  }

  /// Builds a titled section of category tiles with a left accent icon.
  Widget _buildCategorySection(
    BuildContext context,
    String title,
    IconData sectionIcon,
    List<CategoryStats> cats,
    NumberFormat formatter,
  ) {
    if (cats.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16, left: 4),
          child: Row(
            children: [
              Icon(sectionIcon, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
        ...cats.map(
          (c) => CategoryTile(
            title: c.name,
            spentAmount: formatter.format(c.totalSpent),
            limitAmount: formatter.format(c.limit),
            heatPercentage: c.heatPercentage,
            isOverBudget: c.isOverBudget,
            isIncome: c.type == CategoryType.income,
            dailyAllowanceAmount:
                c.isDailyAllowance && c.dailyAllowanceAmount != null
                ? NumberFormat.simpleCurrency(
                    name: formatter.currencyName,
                    decimalDigits: 0,
                  ).format(c.dailyAllowanceAmount)
                : null,
            expectedPurchaseFrequencyDays: c.expectedPurchaseFrequencyDays,
            expectedPurchaseAmount: c.expectedPurchaseAmount != null
                ? NumberFormat.simpleCurrency(
                    name: formatter.currencyName,
                    decimalDigits: 0,
                  ).format(c.expectedPurchaseAmount!)
                : null,
            onTap: () => context.go('/category/${c.categoryId}'),
          ),
        ),
      ],
    );
  }

  /// Computes stats directly from a period (for historical periods).
  PeriodStats _computeStats(Period period) {
    double totalMandatoryBudget = 0;
    double totalMandatorySpent = 0;
    double totalOptionalBudget = 0;
    double totalOptionalSpent = 0;
    final categoryStatsList = <CategoryStats>[];

    for (final category in period.categories) {
      final spent = category.factExpenses.fold<double>(
        0,
        (prev, e) => prev + e.amount,
      );
      final planned = category.plannedExpenses.fold<double>(
        0,
        (prev, e) => prev + e.amount,
      );
      final limit = category.limit ?? planned;
      final remaining = limit - spent;
      final heat = limit > 0 ? (spent / limit) : 0.0;

      if (category.type == CategoryType.mandatoryExpense) {
        totalMandatoryBudget += limit;
        totalMandatorySpent += spent;
      } else if (category.type == CategoryType.optionalExpense) {
        totalOptionalBudget += limit;
        totalOptionalSpent += spent;
      }

      categoryStatsList.add(
        CategoryStats(
          categoryId: category.id,
          name: category.name,
          type: category.type,
          limit: limit,
          totalSpent: spent,
          totalPlanned: planned,
          remaining: remaining,
          heatPercentage: heat,
          isOverBudget: spent > limit,
          isDailyAllowance: category.isDailyAllowance,
        ),
      );
    }

    categoryStatsList.sort(
      (a, b) => b.heatPercentage.compareTo(a.heatPercentage),
    );

    final totalBudget = totalMandatoryBudget + totalOptionalBudget;
    final totalSpent = totalMandatorySpent + totalOptionalSpent;

    return PeriodStats(
      totalMandatoryBudget: totalMandatoryBudget,
      totalMandatorySpent: totalMandatorySpent,
      totalOptionalBudget: totalOptionalBudget,
      totalOptionalSpent: totalOptionalSpent,
      totalBudget: totalBudget,
      totalSpent: totalSpent,
      overallRemaining: totalBudget - totalSpent,
      categoryStats: categoryStatsList,
    );
  }
}
