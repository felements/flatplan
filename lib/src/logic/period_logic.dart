import 'package:uuid/uuid.dart';
import '../models/models.dart';

/// Handles the rollover logic from a current period (or template) to a new period.
Period createNextPeriod({
  required Period currentPeriod,
  required DateTime newStartDate,
  required DateTime newEndDate,
  required String newName,
}) {
  final newCategories = currentPeriod.categories.map((category) {
    // Copy planned expenses but reset the isCompleted flag
    final newPlannedExpenses = category.plannedExpenses.map((planned) {
      return planned.copyWith(
        id: const Uuid().v4(), // generate new IDs for the new period
        isCompleted: false,
      );
    }).toList();

    return category.copyWith(
      id: const Uuid().v4(), // generate new IDs so it's a completely detached copy
      plannedExpenses: newPlannedExpenses,
      factExpenses: const [], // Drop all fact expenses (spending)
    );
  }).toList();

  return Period(
    id: const Uuid().v4(),
    name: newName,
    startDate: newStartDate,
    endDate: newEndDate,
    baseCurrency: currentPeriod.baseCurrency,
    lastModified: DateTime.now(),
    categories: newCategories,
  );
}
