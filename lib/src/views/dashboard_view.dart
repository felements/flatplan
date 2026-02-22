import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../components/category_tile.dart';
import '../components/summary_card.dart';
import '../providers/current_period_provider.dart';
import '../providers/period_stats_provider.dart';

class DashboardView extends ConsumerWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var theme = Theme.of(context);
    final currentPeriodAsync = ref.watch(currentPeriodProvider);
    final statsAsync = ref.watch(periodStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: currentPeriodAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (period) {
          if (period == null) {
            return const Center(child: Text('No active period. Setup required.'));
          }

          final stats = statsAsync.value;
          if (stats == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final currencyFormatter = NumberFormat.simpleCurrency(name: period.baseCurrency);

          // We filter the categoryStats by Mandatory flag
          final mandatoryCategories = stats.categoryStats.where((c) => c.isMandatory).toList();
          final optionalCategories = stats.categoryStats.where((c) => !c.isMandatory).toList();

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: ListView(
              children: [
                // Top header for period name
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        period.name,
                        style: theme.textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          // TODO: Implement trigger rollover
                        },
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('Next Period'),
                      ),
                    ],
                  ),
                ),

                // Summary Row (Using Wrap for responsiveness)
                Wrap(
                  spacing: 16.0,
                  runSpacing: 16.0,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    SizedBox(
                      width: 250,
                      child: SummaryCard(
                        title: 'Total Budget',
                        amount: currencyFormatter.format(stats.totalBudget),
                        icon: Icons.account_balance_wallet,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    SizedBox(
                      width: 250,
                      child: SummaryCard(
                        title: 'Total Spent',
                        amount: currencyFormatter.format(stats.totalSpent),
                        icon: Icons.shopping_cart,
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                    SizedBox(
                      width: 250,
                      child: SummaryCard(
                        title: 'Remaining',
                        amount: currencyFormatter.format(stats.overallRemaining.clamp(0, double.infinity)),
                        icon: Icons.savings,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Categories Layout
                LayoutBuilder(
                  builder: (context, constraints) {
                    final bool isWide = constraints.maxWidth > 800;

                    Widget mandatorySection = _buildCategorySection(
                      context, 'Mandatory Expenses', mandatoryCategories, currencyFormatter,
                    );
                    Widget optionalSection = _buildCategorySection(
                      context, 'Optional Living pool', optionalCategories, currencyFormatter,
                    );

                    if (isWide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: mandatorySection),
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

  Widget _buildCategorySection(
    BuildContext context,
    String title,
    List<CategoryStats> cats,
    NumberFormat formatter,
  ) {
    if (cats.isEmpty) {
       return const SizedBox.shrink();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0, left: 4.0),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        ...cats.map((c) => CategoryTile(
              title: c.name,
              spentAmount: formatter.format(c.totalSpent),
              limitAmount: formatter.format(c.limit),
              heatPercentage: c.heatPercentage,
              isOverBudget: c.isOverBudget,
              onTap: () {
                context.go('/category/${c.categoryId}');
              },
            )),
      ],
    );
  }
}
