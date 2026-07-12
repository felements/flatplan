import 'dart:math' as math;

import 'category.dart';

/// Derived budget figures for a [Category].
///
/// [effectiveLimit] is the single figure all budget math keys off:
/// planned total when no limit is set, otherwise the max of the two —
/// a limit never hides a plan that has outgrown it.
extension CategoryBudget on Category {
  /// Sum of all planned expense amounts.
  double get plannedTotal =>
      plannedExpenses.fold<double>(0, (sum, e) => sum + e.amount);

  /// The effective budget figure for this category.
  double get effectiveLimit {
    final planned = plannedTotal;
    final hardLimit = limit;
    if (hardLimit == null) return planned;
    return math.max(planned, hardLimit);
  }

  /// True when a limit is set and planned expenses strictly exceed it.
  bool get plannedExceedsLimit {
    final hardLimit = limit;
    return hardLimit != null && plannedTotal > hardLimit;
  }
}
