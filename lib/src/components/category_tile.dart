import 'package:flutter/material.dart';

class CategoryTile extends StatelessWidget {
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
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    var colorScheme = theme.colorScheme;
    
    // Determine the color of the heat indicator
    Color heatColor;
    if (isOverBudget) {
      heatColor = colorScheme.error;
    } else if (heatPercentage > 0.85) {
      heatColor = Colors.orange;
    } else {
      heatColor = colorScheme.primary;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '\$ $spentAmount / \$ $limitAmount',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: isOverBudget ? FontWeight.bold : FontWeight.normal,
                      color: isOverBudget ? colorScheme.error : colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: heatPercentage.clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(heatColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
