import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../logic/payment_tags.dart';
import 'summary_card.dart';
import 'tag_chip.dart';

/// Dashboard card listing the most-spent `#tags` of a period, each with its
/// spending in the period and across every period.
///
/// Sized to sit in the summary-card row: at the 260 px card width and the
/// summary cards' height there is room for [maxTags] rows. Fewer tags leave
/// empty slots so the card keeps the row's height.
class TopTagsCard extends StatelessWidget {
  const TopTagsCard({super.key, required this.tags});

  /// How many tag rows fit at summary-card height.
  static const maxTags = 3;

  /// Ranked tag totals; only the first [maxTags] are shown.
  final List<TagTotal> tags;

  static const _amountWidth = 56.0;
  static const _columnGap = 8.0;
  static const _rowHeight = 24.0;
  static const _rowGap = 4.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final format = NumberFormat.decimalPatternDigits(decimalDigits: 0);
    final labelStyle = theme.textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );
    final shown = tags.take(maxTags).toList();

    Widget amount(double value, {required bool strong}) => SizedBox(
      width: _amountWidth,
      child: Align(
        alignment: Alignment.centerRight,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            format.format(value),
            maxLines: 1,
            style: strong
                ? theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  )
                : theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
          ),
        ),
      ),
    );

    Widget label(String text) => SizedBox(
      width: _amountWidth,
      child: Text(
        text,
        textAlign: TextAlign.right,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: labelStyle,
      ),
    );

    return Container(
      decoration: summaryCardDecoration(context),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 20,
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Top tags',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Tooltip(
                        message:
                            'Spending per #tag in payment comments: in this '
                            'period, and in total across every period. A '
                            'payment with several tags counts in full under '
                            'each of them.',
                        triggerMode: TooltipTriggerMode.tap,
                        child: Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                label('period'),
                const SizedBox(width: _columnGap),
                label('total'),
              ],
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < maxTags; i++) ...[
            if (i > 0) const SizedBox(height: _rowGap),
            SizedBox(
              height: _rowHeight,
              child: i < shown.length
                  ? Row(
                      children: [
                        Flexible(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: TagChip(shown[i].tag),
                          ),
                        ),
                        const SizedBox(width: _columnGap),
                        amount(shown[i].periodTotal, strong: true),
                        const SizedBox(width: _columnGap),
                        amount(shown[i].allPeriodsTotal, strong: false),
                      ],
                    )
                  : null,
            ),
          ],
        ],
      ),
    );
  }
}
