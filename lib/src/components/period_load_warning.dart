import 'package:flutter/material.dart';

import '../storage/period_repository.dart';

/// A one-line dashboard warning that some period files could not be read,
/// pointing the user at Settings for the per-file details.
///
/// Renders nothing when [failures] is empty.
class PeriodLoadBanner extends StatelessWidget {
  final List<PeriodLoadFailure> failures;

  /// Invoked when the user asks to see the full list, normally by navigating
  /// to the Settings page.
  final VoidCallback onViewDetails;

  const PeriodLoadBanner({
    super.key,
    required this.failures,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    if (failures.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final count = failures.length;
    final noun = count == 1 ? 'period file' : 'period files';

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 20,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$count $noun could not be read',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onErrorContainer,
              ),
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: onViewDetails,
            style: TextButton.styleFrom(
              foregroundColor: colorScheme.onErrorContainer,
            ),
            child: const Text('View details'),
          ),
        ],
      ),
    );
  }
}

/// The per-file breakdown of unreadable period files, shown in Settings
/// alongside the other storage problems.
///
/// Renders nothing when [failures] is empty.
class PeriodLoadFailureList extends StatelessWidget {
  final List<PeriodLoadFailure> failures;

  const PeriodLoadFailureList({super.key, required this.failures});

  @override
  Widget build(BuildContext context) {
    if (failures.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'These files are in the periods folder but could not be '
                  'read. They are left untouched — fix or remove them and '
                  'restart the app.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onErrorContainer,
                  ),
                ),
                for (final failure in failures) ...[
                  const SizedBox(height: 10),
                  Text(
                    failure.fileName,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                      color: colorScheme.onErrorContainer,
                    ),
                  ),
                  Text(
                    failure.message,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onErrorContainer.withValues(
                        alpha: 0.8,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
