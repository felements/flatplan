import 'package:flutter/material.dart';

/// A category list tile with a heat-indicator progress bar,
/// styled for the dark dashboard aesthetic.
class CategoryTile extends StatefulWidget {
  final String title;
  final String spentAmount;
  final String limitAmount;
  final double heatPercentage;
  final bool isOverBudget;
  final VoidCallback onTap;

  const CategoryTile({
    super.key,
    required this.title,
    required this.spentAmount,
    required this.limitAmount,
    required this.heatPercentage,
    required this.isOverBudget,
    required this.onTap,
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

    // Heat-based color
    Color heatColor;
    if (widget.isOverBudget) {
      heatColor = colorScheme.error;
    } else if (widget.heatPercentage > 0.85) {
      heatColor = const Color(0xFFE0A030);
    } else {
      heatColor = colorScheme.primary;
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
                            fontWeight: widget.isOverBudget
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: widget.isOverBudget
                                ? colorScheme.error
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
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
