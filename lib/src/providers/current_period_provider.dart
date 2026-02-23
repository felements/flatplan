import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../logic/period_extensions.dart';
import '../models/models.dart';
import 'all_periods_provider.dart';
import 'repository_provider.dart';

part 'current_period_provider.g.dart';

@riverpod
class CurrentPeriod extends _$CurrentPeriod {
  Timer? _debounceTimer;

  @override
  FutureOr<Period?> build() async {
    final repo = ref.watch(periodRepositoryProvider);
    final periods = await repo.loadAllPeriods();

    if (periods.isEmpty) {
      return null; // Open setup or empty state
    }

    // Find the period whose date range contains today.
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final period in periods) {
      final start = DateTime(
        period.startDate.year,
        period.startDate.month,
        period.startDate.day,
      );
      final end = effectiveEndDate(period, periods);
      final endDay = DateTime(end.year, end.month, end.day);

      if (!today.isBefore(start) && !today.isAfter(endDay)) {
        return period;
      }
    }

    // Fallback: no period spans today — pick the latest by start date.
    periods.sort((a, b) => b.startDate.compareTo(a.startDate));
    return periods.first;
  }

  /// Sets a brand-new period (e.g. first period on cold start) and
  /// persists it immediately without debouncing.
  Future<void> setPeriod(Period newPeriod) async {
    state = AsyncData(newPeriod);
    final repo = ref.read(periodRepositoryProvider);
    await repo.savePeriod(newPeriod);
    ref.invalidate(allPeriodsProvider);
  }

  /// Mutates the state and triggers a debounced save.
  void updatePeriod(Period newPeriod) {
    if (state.value == null) return;

    final updatedPeriod = newPeriod.copyWith(lastModified: DateTime.now());
    state = AsyncData(updatedPeriod);
    _debouncedSave(updatedPeriod);
  }

  /// Adds a fact expense to a specific category
  void addFactExpense(String categoryId, FactExpense expense) {
    final current = state.value;
    if (current == null) return;

    final updatedCategories = current.categories.map((cat) {
      if (cat.id == categoryId) {
        return cat.copyWith(factExpenses: [...cat.factExpenses, expense]);
      }
      return cat;
    }).toList();

    updatePeriod(current.copyWith(categories: updatedCategories));
  }

  /// Toggles the isCompleted flag of a specific planned expense.
  /// On check → creates a linked FactExpense.
  /// On uncheck → removes the linked FactExpense.
  void togglePlannedExpense(String categoryId, String expenseId) {
    final current = state.value;
    if (current == null) return;

    final updatedCategories = current.categories.map((cat) {
      if (cat.id == categoryId) {
        final planned = cat.plannedExpenses
            .where((p) => p.id == expenseId)
            .firstOrNull;
        if (planned == null) return cat;

        final nowCompleted = !planned.isCompleted;

        final updatedPlanned = cat.plannedExpenses.map((p) {
          if (p.id == expenseId) {
            return p.copyWith(isCompleted: nowCompleted);
          }
          return p;
        }).toList();

        List<FactExpense> updatedFacts;
        if (nowCompleted) {
          // Create a linked fact expense
          updatedFacts = [
            ...cat.factExpenses,
            FactExpense(
              id: const Uuid().v4(),
              amount: planned.amount,
              description: planned.description,
              timestamp: DateTime.now(),
              linkedPlannedExpenseId: planned.id,
            ),
          ];
        } else {
          // Remove the linked fact expense
          updatedFacts = cat.factExpenses
              .where((f) => f.linkedPlannedExpenseId != planned.id)
              .toList();
        }

        return cat.copyWith(
          plannedExpenses: updatedPlanned,
          factExpenses: updatedFacts,
        );
      }
      return cat;
    }).toList();

    updatePeriod(current.copyWith(categories: updatedCategories));
  }

  /// Adds a planned expense to a specific category.
  void addPlannedExpense(String categoryId, PlannedExpense expense) {
    final current = state.value;
    if (current == null) return;

    final updatedCategories = current.categories.map((cat) {
      if (cat.id == categoryId) {
        return cat.copyWith(plannedExpenses: [...cat.plannedExpenses, expense]);
      }
      return cat;
    }).toList();

    updatePeriod(current.copyWith(categories: updatedCategories));
  }

  /// Replaces a planned expense by matching its `id` in the given category.
  void updatePlannedExpense(String categoryId, PlannedExpense updated) {
    final current = state.value;
    if (current == null) return;

    final updatedCategories = current.categories.map((cat) {
      if (cat.id == categoryId) {
        final updatedPlanned = cat.plannedExpenses.map((p) {
          return p.id == updated.id ? updated : p;
        }).toList();
        return cat.copyWith(plannedExpenses: updatedPlanned);
      }
      return cat;
    }).toList();

    updatePeriod(current.copyWith(categories: updatedCategories));
  }

  /// Removes a planned expense by `id` and cascade-deletes any linked fact
  /// expense.
  void removePlannedExpense(String categoryId, String expenseId) {
    final current = state.value;
    if (current == null) return;

    final updatedCategories = current.categories.map((cat) {
      if (cat.id == categoryId) {
        return cat.copyWith(
          plannedExpenses: cat.plannedExpenses
              .where((p) => p.id != expenseId)
              .toList(),
          factExpenses: cat.factExpenses
              .where((f) => f.linkedPlannedExpenseId != expenseId)
              .toList(),
        );
      }
      return cat;
    }).toList();

    updatePeriod(current.copyWith(categories: updatedCategories));
  }

  /// Appends a new category to the period.
  void addCategory(Category category) {
    final current = state.value;
    if (current == null) return;

    updatePeriod(
      current.copyWith(categories: [...current.categories, category]),
    );
  }

  /// Replaces a category by matching its `id`.
  void updateCategory(Category updated) {
    final current = state.value;
    if (current == null) return;

    final updatedCategories = current.categories.map((cat) {
      return cat.id == updated.id ? updated : cat;
    }).toList();

    updatePeriod(current.copyWith(categories: updatedCategories));
  }

  /// Removes a category by `id`.
  void removeCategory(String categoryId) {
    final current = state.value;
    if (current == null) return;

    final updatedCategories = current.categories
        .where((cat) => cat.id != categoryId)
        .toList();

    updatePeriod(current.copyWith(categories: updatedCategories));
  }

  /// Removes a fact expense by `expenseId` from the given category.
  /// If the removed fact has a `linkedPlannedExpenseId`, the corresponding
  /// planned expense is unchecked.
  void removeFactExpense(String categoryId, String expenseId) {
    final current = state.value;
    if (current == null) return;

    final updatedCategories = current.categories.map((cat) {
      if (cat.id == categoryId) {
        final removedFact = cat.factExpenses
            .where((e) => e.id == expenseId)
            .firstOrNull;

        final updatedFacts = cat.factExpenses
            .where((e) => e.id != expenseId)
            .toList();

        // If the removed fact was linked to a planned expense, uncheck it.
        var updatedPlanned = cat.plannedExpenses;
        if (removedFact?.linkedPlannedExpenseId != null) {
          final linkedId = removedFact!.linkedPlannedExpenseId;
          updatedPlanned = cat.plannedExpenses.map((p) {
            if (p.id == linkedId) {
              return p.copyWith(isCompleted: false);
            }
            return p;
          }).toList();
        }

        return cat.copyWith(
          factExpenses: updatedFacts,
          plannedExpenses: updatedPlanned,
        );
      }
      return cat;
    }).toList();

    updatePeriod(current.copyWith(categories: updatedCategories));
  }

  void _debouncedSave(Period period) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final repo = ref.read(periodRepositoryProvider);
        await repo.savePeriod(period);
      } catch (e) {
        print('Failed to auto-save period: $e');
        // Handle error visually via a separate notification provider if needed
      }
    });
  }
}
