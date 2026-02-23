import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../providers/all_periods_provider.dart';

/// The root shell widget providing a rich dark sidebar navigation.
class AppShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final selectedIndex = navigationShell.currentIndex;
    final periodsAsync = ref.watch(allPeriodsProvider);

    // Determine which period ID is currently being viewed via the URL.
    final uri = GoRouterState.of(context).uri.toString();
    final periodIdMatch = RegExp(r'/period/(.+)').firstMatch(uri);
    final activePeriodId = periodIdMatch?.group(1);

    return Scaffold(
      body: Row(
        children: [
          // ─── Sidebar ────────────────────────────────────────────
          Container(
            width: 220,
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(
                right: BorderSide(
                  color: colorScheme.outlineVariant,
                  width: 0.5,
                ),
              ),
            ),
            child: Column(
              children: [
                // App branding header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.account_balance_wallet_rounded,
                          color: colorScheme.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'FlatPlan',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),

                Divider(
                  color: colorScheme.outlineVariant,
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                ),

                const SizedBox(height: 16),

                // ─── Today (current period) ────────────────────────
                _SidebarItem(
                  icon: Icons.calendar_today_rounded,
                  label: 'Today',
                  isSelected: selectedIndex == 0 && activePeriodId == null,
                  onTap: () => navigationShell.goBranch(
                    0,
                    initialLocation: selectedIndex == 0,
                  ),
                ),

                // ─── Historical period links ───────────────────────
                periodsAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(16),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (periods) {
                    // Take up to 8, skip the first if it matches the current
                    // period (already shown as "Today").
                    final historyPeriods = periods.take(8).toList();

                    if (historyPeriods.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    return Column(
                      children: historyPeriods.map((period) {
                        final label = _formatPeriodLabel(period);
                        final isActive = activePeriodId == period.id;
                        return _PeriodSubItem(
                          label: label,
                          isSelected: isActive,
                          onTap: () => context.go('/period/${period.id}'),
                        );
                      }).toList(),
                    );
                  },
                ),

                const Spacer(),

                // ─── Settings (anchored to bottom) ─────────────────
                _SidebarItem(
                  icon: Icons.settings_rounded,
                  label: 'Settings',
                  isSelected: selectedIndex == 1,
                  onTap: () => navigationShell.goBranch(
                    1,
                    initialLocation: selectedIndex == 1,
                  ),
                ),

                const SizedBox(height: 8),

                // Bottom branding
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Budget Tracker',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ─── Main content ───────────────────────────────────────
          Expanded(child: navigationShell),
        ],
      ),
    );
  }

  /// Formats period start date as "Mon YY" (e.g. "Feb 26").
  String _formatPeriodLabel(Period period) {
    return DateFormat('MMM yy').format(period.startDate);
  }
}

/// A primary sidebar navigation item with icon and selected-state highlight.
class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Material(
        color: isSelected
            ? colorScheme.primary.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          hoverColor: colorScheme.primary.withValues(alpha: 0.06),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A sub-level period link in the sidebar — indented, compact, with a
/// small dot indicator instead of a full icon.
class _PeriodSubItem extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PeriodSubItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Material(
        color: isSelected
            ? colorScheme.primary.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          hoverColor: colorScheme.primary.withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.only(
              left: 34,
              right: 14,
              top: 8,
              bottom: 8,
            ),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
