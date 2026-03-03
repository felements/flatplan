import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../logic/period_extensions.dart';
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

    // Find the period that covers today.
    final allPeriods = periodsAsync.value ?? [];
    final now = DateTime.now();
    final todayPeriod = _findActivePeriod(allPeriods, now);

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

                // ─── Today (active period) ────────────────────────
                _SidebarItem(
                  icon: Icons.calendar_today_rounded,
                  label: 'Today',
                  isSelected: selectedIndex == 0 && activePeriodId == null,
                  onTap: () {
                    if (todayPeriod != null) {
                      context.go('/period/${todayPeriod.id}');
                    } else {
                      navigationShell.goBranch(
                        0,
                        initialLocation: selectedIndex == 0,
                      );
                    }
                  },
                ),

                // ─── Period links ───────────────────────────────────
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
                    final historyPeriods = periods.take(8).toList();

                    if (historyPeriods.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    return Column(
                      children: historyPeriods.map((period) {
                        final label = _formatPeriodLabel(period);
                        final isViewed = activePeriodId == period.id;
                        final isCurrent = todayPeriod?.id == period.id;
                        return _PeriodSubItem(
                          label: label,
                          isSelected: isViewed,
                          isCurrent: isCurrent,
                          onTap: () => context.go('/period/${period.id}'),
                        );
                      }).toList(),
                    );
                  },
                ),

                const Spacer(),

                // ─── Settings (anchored to bottom) ─────────────────
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _SidebarItem(
                    icon: Icons.settings_rounded,
                    label: 'Settings',
                    isSelected: selectedIndex == 1,
                    onTap: () => navigationShell.goBranch(
                      1,
                      initialLocation: selectedIndex == 1,
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

  /// Finds the period whose date range contains [date], or null.
  Period? _findActivePeriod(List<Period> allPeriods, DateTime date) {
    if (allPeriods.isEmpty) return null;
    for (final period in allPeriods) {
      final endDate = effectiveEndDate(period, allPeriods);
      final afterStart = date.isAfter(
        period.startDate.subtract(const Duration(days: 1)),
      );
      final beforeEnd = date.isBefore(endDate.add(const Duration(days: 1)));
      if (afterStart && beforeEnd) return period;
    }
    return null;
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
  final bool isCurrent;
  final VoidCallback onTap;

  const _PeriodSubItem({
    required this.label,
    required this.isSelected,
    this.isCurrent = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Gold accent for the active period.
    const currentColor = Color(0xFFD4A84B);

    final dotColor = isCurrent
        ? currentColor
        : isSelected
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant.withValues(alpha: 0.4);

    final textColor = isSelected
        ? colorScheme.primary
        : isCurrent
        ? colorScheme.onSurface
        : colorScheme.onSurfaceVariant;

    final fontWeight = (isSelected || isCurrent)
        ? FontWeight.w600
        : FontWeight.normal;

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
                    color: dotColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: textColor,
                      fontWeight: fontWeight,
                    ),
                  ),
                ),
                if (isCurrent)
                  Text('●', style: TextStyle(fontSize: 8, color: currentColor)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
