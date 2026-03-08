import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../app_theme.dart';
import '../components/category_tile.dart';
import '../components/summary_card.dart';
import '../logic/period_extensions.dart';
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
    final allPeriodsAsync = ref.watch(allPeriodsProvider);

    return Scaffold(
      body: periodAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (period) {
          if (period == null) {
            return _buildEmptyState(context);
          }

          // Compute the effective end date from the full list of periods.
          final allPeriods = allPeriodsAsync.value ?? [];
          final endDate = effectiveEndDate(period, allPeriods);

          // For current period use the existing stats provider;
          // for historical periods compute stats inline.
          final PeriodStats? stats;
          if (periodId != null) {
            stats = _computeStats(period, endDate);
          } else {
            stats = statsAsync.value;
          }
          if (stats == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final currencyFormatter = NumberFormat.simpleCurrency(
            name: period.baseCurrency,
            decimalDigits: 0,
          );

          Color budgetColor;
          Color budgetBgColor;
          if (stats.totalIncome > 0) {
            if (stats.totalBudget > stats.totalIncome) {
              budgetColor = colorScheme.error;
              budgetBgColor = AppTheme.cardCoral;
            } else if (stats.totalBudget >= stats.totalIncome * 0.8) {
              budgetColor = colorScheme.primary;
              budgetBgColor = AppTheme.cardGold;
            } else {
              budgetColor = const Color(0xFF6ABF69);
              budgetBgColor = AppTheme.cardGreen;
            }
          } else {
            budgetColor = colorScheme.primary;
            budgetBgColor = AppTheme.cardGold;
          }

          Color spentColor;
          Color spentBgColor;
          if (stats.totalFactIncome > 0) {
            if (stats.totalSpent > stats.totalFactIncome) {
              spentColor = colorScheme.error;
              spentBgColor = AppTheme.cardCoral;
            } else if (stats.totalSpent >= stats.totalFactIncome * 0.8) {
              spentColor = colorScheme.primary;
              spentBgColor = AppTheme.cardGold;
            } else {
              spentColor = const Color(0xFF6ABF69);
              spentBgColor = AppTheme.cardGreen;
            }
          } else {
            spentColor = colorScheme.secondary;
            spentBgColor = AppTheme.cardTeal;
          }

          Color remainingColor;
          Color remainingBgColor;
          if (stats.totalFactIncome > 0 && stats.remainingFreeBalance >= stats.totalFactIncome * 0.2) {
            remainingColor = const Color(0xFF6ABF69);
            remainingBgColor = AppTheme.cardGreen;
          } else if (stats.remainingFreeBalance >= 0) {
            remainingColor = colorScheme.primary;
            remainingBgColor = AppTheme.cardGold;
          } else {
            remainingColor = colorScheme.error;
            remainingBgColor = AppTheme.cardCoral;
          }

          final mandatoryCategories = stats.categoryStats
              .where((c) => c.type == CategoryType.mandatoryExpense)
              .toList();
          final optionalCategories = stats.categoryStats
              .where((c) => c.type == CategoryType.optionalExpense)
              .toList();
          final incomeCategories = stats.categoryStats
              .where((c) => c.type == CategoryType.income)
              .toList();

          final now = DateTime.now();
          String greeting;
          if (now.hour < 12) {
            greeting = 'Good Morning';
          } else if (now.hour < 17) {
            greeting = 'Good Afternoon';
          } else {
            greeting = 'Good Evening';
          }
          final dateStr = DateFormat('MMMM d, h:mm a').format(period.lastModified);
          final headerPrefix = '$greeting • Last revised on $dateStr';

          final isActivePeriod =
              now.isAfter(period.startDate.subtract(const Duration(days: 1))) &&
              now.isBefore(endDate.add(const Duration(days: 1)));
          final periodLengthDays =
              endDate.difference(period.startDate).inDays + 1;
          final daysRemainingLabel = isActivePeriod
              ? '${endDate.difference(now).inDays + 1} days remaining'
              : '$periodLengthDays days';

          // The effective period ID for building routes.
          final effectivePeriodId = period.id;

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
                            headerPrefix,
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
                            '${DateFormat('MMM d').format(period.startDate)} – ${DateFormat('MMM d').format(endDate)} • $daysRemainingLabel',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      // Three-dots dropdown menu replacing the old
                      // "Next Period" button.
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert_rounded,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        tooltip: 'Period actions',
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        onSelected: (value) {
                          if (value == 'manage_categories') {
                            context.go('/period/$effectivePeriodId/categories');
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'manage_categories',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.category_rounded,
                                  size: 18,
                                  color: colorScheme.onSurface,
                                ),
                                const SizedBox(width: 10),
                                const Text('Manage Categories'),
                              ],
                            ),
                          ),
                        ],
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
                        title: 'Total Budget (plan)',
                        amount: currencyFormatter.format(stats.totalBudget),
                        subtitle:
                            'of ${currencyFormatter.format(stats.totalIncome)}',
                        tooltip:
                            'Your total planned expenses compared to your planned income. Colors indicate your planned budget safety margin.',
                        icon: Icons.account_balance_wallet_rounded,
                        color: budgetColor,
                        backgroundColor: budgetBgColor,
                      ),
                    ),
                    SizedBox(
                      width: 260,
                      child: SummaryCard(
                        title: 'Total Spent (fact)',
                        amount: currencyFormatter.format(stats.totalSpent),
                        subtitle:
                            'vs ${currencyFormatter.format(stats.totalFactIncome)} income',
                        tooltip:
                            'Your actual total spending so far compared to your actual income received. Colors indicate your current spending safety margin.',
                        icon: Icons.shopping_cart_rounded,
                        color: spentColor,
                        backgroundColor: spentBgColor,
                      ),
                    ),
                    SizedBox(
                      width: 260,
                      child: SummaryCard(
                        title: 'Free Money',
                        amount: currencyFormatter.format(
                          stats.remainingFreeBalance,
                        ),
                        subtitle: 'fact income – plan expenses',
                        tooltip:
                            'The absolute free balance strictly available to you right now. Calculated as actual income received minus total planned expenses required for the period.',
                        icon: Icons.savings_rounded,
                        color: remainingColor,
                        backgroundColor: remainingBgColor,
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
                      effectivePeriodId,
                    );
                    final optionalSection = _buildCategorySection(
                      context,
                      'Optional Living Pool',
                      Icons.spa_rounded,
                      optionalCategories,
                      currencyFormatter,
                      effectivePeriodId,
                    );

                    final incomeSection = _buildCategorySection(
                      context,
                      'Incomes',
                      Icons.arrow_downward_rounded,
                      incomeCategories,
                      currencyFormatter,
                      effectivePeriodId,
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
  ///
  /// The [effectivePeriodId] is used to build period-scoped navigation
  /// routes so that clicking a tile navigates to the correct period's
  /// category detail view.
  Widget _buildCategorySection(
    BuildContext context,
    String title,
    IconData sectionIcon,
    List<CategoryStats> cats,
    NumberFormat formatter,
    String effectivePeriodId,
  ) {
    if (cats.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final totalFact = cats.fold<double>(0, (sum, cat) => sum + cat.totalSpent);
    final totalPlanned = cats.fold<double>(0, (sum, cat) => sum + cat.limit);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16, left: 4, right: 8),
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
              const Spacer(),
              Text(
                '${formatter.format(totalFact)} / ${formatter.format(totalPlanned)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
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
            plannedExpenseStatuses: c.plannedExpenseStatuses,
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
            onTap: () => context.go(
              '/period/$effectivePeriodId/category/${c.categoryId}',
            ),
          ),
        ),
      ],
    );
  }

  /// Computes stats directly from a period (for historical periods).
  PeriodStats _computeStats(Period period, DateTime endDate) {
    double totalMandatoryBudget = 0;
    double totalMandatorySpent = 0;
    double totalOptionalBudget = 0;
    double totalOptionalSpent = 0;
    double totalIncome = 0;
    double totalFactIncome = 0;
    double effectiveTotalExpenseForFreeBalance = 0;
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
      
      final now = DateTime.now();
      final isActivePeriod =
          now.isAfter(period.startDate.subtract(const Duration(days: 1))) &&
          now.isBefore(endDate.add(const Duration(days: 1)));

      final plannedExpenseStatuses = <PlannedExpenseStatus>[];
      for (final exp in category.plannedExpenses) {
        if (exp.isCompleted) {
          plannedExpenseStatuses.add(PlannedExpenseStatus.completed);
        } else {
          bool isOverdue = false;
          if (isActivePeriod) {
            final expDate = exp.dueDate.when(
              exact: (d) => d,
              dayOfMonth: (day) {
                final d = DateTime(now.year, now.month, day);
                if (d.isBefore(period.startDate)) {
                  return DateTime(now.year, now.month + 1, day);
                }
                return d;
              },
            );
            if (now.isAfter(expDate.add(const Duration(days: 1)))) {
              isOverdue = true;
            }
          }
          plannedExpenseStatuses.add(
              isOverdue ? PlannedExpenseStatus.overdue : PlannedExpenseStatus.pending);
        }
      }

      if (category.type == CategoryType.mandatoryExpense) {
        totalMandatoryBudget += limit;
        totalMandatorySpent += spent;
        effectiveTotalExpenseForFreeBalance += spent > limit ? spent : limit;
      } else if (category.type == CategoryType.optionalExpense) {
        totalOptionalBudget += limit;
        totalOptionalSpent += spent;
        effectiveTotalExpenseForFreeBalance += spent > limit ? spent : limit;
      } else if (category.type == CategoryType.income) {
        totalIncome += limit;
        totalFactIncome += spent;
      }

      // Daily allowance metrics (daily spend & 20% trimmed-mean frequency).
      int daysLeft = endDate.difference(DateTime.now()).inDays;
      if (daysLeft < 1) daysLeft = 1;

      double? dailyAllowanceAmount;
      int? expectedPurchaseFrequencyDays;
      double? expectedPurchaseAmount;

      if (category.isDailyAllowance) {
        dailyAllowanceAmount = remaining > 0 ? remaining / daysLeft : 0.0;

        if (category.factExpenses.length >= 2 && remaining > 0) {
          // 20% Trimmed Mean — drop the lowest 20% of expenses.
          final sortedExpenses =
              category.factExpenses.map((e) => e.amount).toList()..sort();
          final dropCount = (sortedExpenses.length * 0.2).floor();
          final keptExpenses = sortedExpenses.sublist(dropCount);

          if (keptExpenses.isNotEmpty) {
            final keptSpent = keptExpenses.fold<double>(
              0,
              (prev, amount) => prev + amount,
            );
            final avgExpense = keptSpent / keptExpenses.length;

            if (avgExpense > 0) {
              final affordablePurchases = remaining / avgExpense;
              if (affordablePurchases > 0) {
                final frequencyDays = (daysLeft / affordablePurchases).round();
                final periodLengthDays = endDate.difference(period.startDate).inDays + 1;
                if (frequencyDays <= periodLengthDays / 2) {
                  expectedPurchaseFrequencyDays = frequencyDays;
                  expectedPurchaseAmount = avgExpense;
                }
              }
            }
          }
        }
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
          plannedExpenseStatuses: plannedExpenseStatuses,
          dailyAllowanceAmount: dailyAllowanceAmount,
          expectedPurchaseFrequencyDays: expectedPurchaseFrequencyDays,
          expectedPurchaseAmount: expectedPurchaseAmount,
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
      remainingFreeBalance:
          totalFactIncome - effectiveTotalExpenseForFreeBalance,
      totalIncome: totalIncome,
      totalFactIncome: totalFactIncome,
      categoryStats: categoryStatsList,
    );
  }
}
