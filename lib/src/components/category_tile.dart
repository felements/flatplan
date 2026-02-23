import 'package:flutter/material.dart';

/// A category list tile with a heat-indicator progress bar,
/// styled for the dark dashboard aesthetic.
class CategoryTile extends StatefulWidget {
  final String title;
  final String spentAmount;
  final String limitAmount;
  final double heatPercentage;
  final bool isOverBudget;
  final bool isIncome;
  final VoidCallback onTap;
  final String? dailyAllowanceAmount;
  final int? expectedPurchaseFrequencyDays;
  final String? expectedPurchaseAmount;

  const CategoryTile({
    super.key,
    required this.title,
    required this.spentAmount,
    required this.limitAmount,
    required this.heatPercentage,
    required this.isOverBudget,
    this.isIncome = false,
    required this.onTap,
    this.dailyAllowanceAmount,
    this.expectedPurchaseFrequencyDays,
    this.expectedPurchaseAmount,
  });

  @override
  State<CategoryTile> createState() => _CategoryTileState();
}

class _CategoryTileState extends State<CategoryTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final bool showCriticalExpense =
        !widget.isIncome && widget.heatPercentage >= 1.05;
    final bool showSuccessIncome = widget.isIncome && widget.isOverBudget;

    // Heat-based color
    Color heatColor;
    if (widget.isIncome) {
      heatColor = showSuccessIncome
          ? const Color(0xFF6ABF69)
          : colorScheme.primary;
    } else {
      if (widget.heatPercentage >= 1.05) {
        heatColor = colorScheme.error;
      } else if (widget.heatPercentage >= 0.80) {
        heatColor = const Color(0xFFE0A030);
      } else {
        heatColor = const Color(0xFF6ABF69);
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: _isHovered
                ? (isDark
                      ? colorScheme.surfaceContainerHigh
                      : colorScheme.surfaceContainerHighest)
                : (isDark
                      ? colorScheme.surfaceContainerLow
                      : colorScheme.surfaceContainerLowest),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _isHovered
                  ? colorScheme.outline.withValues(alpha: 0.4)
                  : colorScheme.outlineVariant.withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            widget.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${widget.spentAmount} / ${widget.limitAmount}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight:
                                (showCriticalExpense || showSuccessIncome)
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                            color: showCriticalExpense
                                ? colorScheme.error
                                : (showSuccessIncome
                                    ? const Color(0xFF6ABF69)
                                    : colorScheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                    if (widget.dailyAllowanceAmount != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.today_rounded,
                            size: 14,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            widget.expectedPurchaseFrequencyDays != null
                                ? '${widget.dailyAllowanceAmount} / day left or spend ${widget.expectedPurchaseAmount!} every ${widget.expectedPurchaseFrequencyDays} days'
                                : '${widget.dailyAllowanceAmount} / day left',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (widget.expectedPurchaseFrequencyDays != null) ...[
                            const SizedBox(width: 6),
                            Tooltip(
                              message:
                                  'Calculated using a 20% Trimmed Mean (drops the 20% smallest expenses)\n'
                                  'to account for typical spend size and ignore small outliers.',
                              child: Icon(
                                Icons.info_outline_rounded,
                                size: 14,
                                color: colorScheme.onSurfaceVariant.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: widget.heatPercentage.clamp(0.0, 1.0),
                        minHeight: 6,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(heatColor),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
