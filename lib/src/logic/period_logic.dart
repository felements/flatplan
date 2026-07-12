import 'package:uuid/uuid.dart';

import '../models/models.dart';

/// Handles the rollover logic from a current period (or template) to a new period.
Period createNextPeriod({
  required Period currentPeriod,
  required DateTime newStartDate,
  required String newName,
}) {
  final newCategories = currentPeriod.categories.map((category) {
    // Copy recurring (day-of-month) planned expenses with the isCompleted
    // flag reset. Exact-date expenses are one-offs tied to the old period,
    // so they are not carried over.
    final newPlannedExpenses = category.plannedExpenses
        .where(
          (planned) => planned.dueDate.when(
            exact: (_) => false,
            dayOfMonth: (_) => true,
          ),
        )
        .map((planned) {
          return planned.copyWith(
            id: const Uuid().v4(), // generate new IDs for the new period
            isCompleted: false,
          );
        })
        .toList();

    return category.copyWith(
      id: const Uuid()
          .v4(), // generate new IDs so it's a completely detached copy
      plannedExpenses: newPlannedExpenses,
      factExpenses: const [], // Drop all fact expenses (spending)
    );
  }).toList();

  return Period(
    id: const Uuid().v4(),
    name: newName,
    startDate: newStartDate,

    baseCurrency: currentPeriod.baseCurrency,
    lastModified: DateTime.now(),
    categories: newCategories,
  );
}

/// Creates a brand-new empty period for cold-start bootstrapping when no
/// previous periods or templates exist.
Period createEmptyPeriod({
  required DateTime startDate,
  required String name,
  String baseCurrency = 'EUR',
}) {
  return Period(
    id: const Uuid().v4(),
    name: name,
    startDate: startDate,

    baseCurrency: baseCurrency,
    lastModified: DateTime.now(),
    categories: const [],
  );
}
