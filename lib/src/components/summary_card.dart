import 'package:flutter/material.dart';

class SummaryCard extends StatelessWidget {
  final String title;
  final String amount;
  final String? subtitle;
  final Color? color;
  final IconData? icon;

  const SummaryCard({
    super.key,
    required this.title,
    required this.amount,
    this.subtitle,
    this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    return Card(
      elevation: 4,
      shadowColor: (color ?? theme.colorScheme.primary).withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (icon != null)
                  Icon(
                    icon,
                    color: color ?? theme.colorScheme.primary,
                    size: 28,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              amount,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
